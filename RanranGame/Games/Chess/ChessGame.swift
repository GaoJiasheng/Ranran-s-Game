import SwiftUI
import Observation

/// 国际象棋的十档难度，和五子棋、象棋一样分给四位小伙伴（小兔 1–3、熊猫 4–6、猫头鹰 7–9、龙宝宝 10）。
struct ChessLevel: Hashable, Identifiable, Comparable {
    static let range = 1...10
    static let all = range.map(ChessLevel.init)

    let number: Int

    init(_ number: Int) {
        self.number = min(max(number, Self.range.lowerBound), Self.range.upperBound)
    }

    var id: Int { number }
    static func < (a: Self, b: Self) -> Bool { a.number < b.number }

    var character: Opponent { Opponent.forLevel(number) }
    var profile: ChessAI.Profile { .level(number) }
    var next: ChessLevel? { number < Self.range.upperBound ? ChessLevel(number + 1) : nil }
    var previous: ChessLevel? { number > Self.range.lowerBound ? ChessLevel(number - 1) : nil }

    /// 被将军时圈出将军的子
    var coaches: Bool { number <= 5 }
    /// 要走一步送子 / 送杀的棋时，先提醒一下（再点一次才真的走）
    var warnsBlunders: Bool { number <= 3 }

    var thinkingTime: Duration { .milliseconds(500 + number * 50) }

    var blurb: String {
        switch number {
        case 1:  "刚学会走棋，经常乱走"
        case 2:  "看到能吃的子就吃"
        case 3:  "开始保护自己的子啦"
        case 4:  "会想一想你下一步要干嘛"
        case 5:  "会抓你没保护的子"
        case 6:  "攻守都很稳"
        case 7:  "会算好几步，小心捉双"
        case 8:  "真正的高手"
        case 9:  "会提前布局，很难对付"
        default: "最强的对手，想得最深"
        }
    }

    var info: LevelInfo { LevelInfo(number: number, blurb: blurb) }
}

enum ChessMode: Hashable {
    case vsAI(ChessLevel)
    case twoPlayer

    var level: ChessLevel? {
        if case let .vsAI(l) = self { return l }
        return nil
    }
}

struct ChessConfig: Hashable, Identifiable {
    let mode: ChessMode
    /// 人机模式下冉冉执白（先走）
    let humanWhite: Bool
    /// 调试用：从这个局面开始（正式对局都是 nil = 标准开局）
    var startFEN: String? = nil
    var id: String { "\(mode)-\(humanWhite)-\(startFEN ?? "")" }
}

/// 一局国际象棋：选子、走子（含升变选子）、悔棋、提示、电脑走棋、低档提醒、胜负与和棋。
@Observable
@MainActor
final class ChessGame {
    struct Played: Hashable {
        let move: ChessMove
        /// 被吃掉的子（编号、在哪一格）
        let capturedID: Int
        let capturedAt: Int
    }

    let config: ChessConfig

    private(set) var match: ChessMatch
    /// 每个格子上棋子的编号（0 = 空），走子时编号跟着子走，界面才能画出"滑过去"的动画
    private(set) var ids: [Int]
    private(set) var history: [Played] = []
    private(set) var selected: ChessSquare?
    private(set) var outcome: ChessOutcome?
    private(set) var aiThinking = false
    private(set) var hint: ChessMove?
    private(set) var speech: String?
    /// 正在将军的那些子（低档位会圈出来）
    private(set) var checkers: [ChessSquare] = []
    /// 低档位提醒过的那一步：会被吃掉的格子，再点一次同一步就真的走
    private(set) var warned: ChessMove?
    private(set) var warnSquares: [ChessSquare] = []
    /// 兵走到最后一排，等她选升变成什么
    private(set) var pendingPromotion: (from: ChessSquare, to: ChessSquare)?
    private(set) var level: ChessLevel?
    private(set) var usedUndo = false
    private(set) var usedHint = false
    private(set) var recordID = UUID()
    private(set) var round = 0
    /// 一闪一闪的"将军！"
    private(set) var checkFlash = 0

    private var aiTask: Task<Void, Never>?
    private var speechTask: Task<Void, Never>?

    init(config: ChessConfig) {
        self.config = config
        let start = config.startFEN.flatMap(ChessBoard.init(fen:)) ?? .start
        match = ChessMatch(start)
        ids = ChessPieceIDs.initial(start)
        level = config.mode.level
    }

    // MARK: 查询

    var board: ChessBoard { match.board }
    var opponent: Opponent? { level?.character }
    var isTwoPlayer: Bool { opponent == nil }
    var humanSide: ChessSide { config.humanWhite ? .white : .black }
    var turn: ChessSide { board.turn }
    var isOver: Bool { outcome != nil }
    var winner: ChessSide? { outcome?.winner }
    var isDraw: Bool { outcome != nil && outcome?.winner == nil }
    var lastMove: ChessMove? { history.last?.move }
    var humanWon: Bool { winner != nil && (isTwoPlayer || winner == humanSide) }
    var inCheck: Bool { !isOver && board.inCheck }
    /// 棋盘下方是哪一方（自己这边在下面）
    var bottomSide: ChessSide { isTwoPlayer ? .white : humanSide }

    var canHumanMove: Bool { !isOver && !aiThinking && pendingPromotion == nil && (isTwoPlayer || turn == humanSide) }

    var canUndo: Bool {
        if isTwoPlayer { return !history.isEmpty }
        return history.indices.contains { side(ofPly: $0) == humanSide }
    }

    func side(ofPly i: Int) -> ChessSide { (i % 2 == 0) == (match.start.turn == .white) ? .white : .black }

    /// 选中的子能走到哪些地方
    var targets: [ChessSquare] {
        guard let selected, canHumanMove else { return [] }
        return Array(Set(board.legalMoves(from: selected).map(\.to)))
    }

    /// 某一方吃掉的子（显示在旁边），按价值从大到小
    func captured(by who: ChessSide) -> [ChessPiece] {
        match.captures.enumerated().compactMap { i, c in
            side(ofPly: i) == who ? ChessPiece(code: c) : nil
        }.sorted { $0.kind.points > $1.kind.points }
    }

    var winStars: Int { 1 + (usedUndo ? 0 : 1) + (usedHint ? 0 : 1) }

    /// 存棋谱：每一步 [从 file, 从 rank, 到 file, 到 rank]，升变的再加一个数（后 2、车 3、象 4、马 5，就是 ChessKind 的值）
    func makeRecord(stars: Int) -> GameRecord {
        GameRecord(id: recordID, game: "chess", date: Date(), boardSize: 8,
                   moves: match.moves.map { m in
                       [m.from.file, m.from.rank, m.to.file, m.to.rank] + (m.promotion.map { [Int($0.rawValue)] } ?? [])
                   },
                   opponentLevel: level?.number,
                   playerColor: isTwoPlayer ? nil : (humanSide == .white ? 1 : 2),
                   winner: winner.map { $0 == .white ? 1 : 2 },
                   stars: stars)
    }

    /// 从标准开局开始的棋才存棋谱（调试用的残局不存）
    var savesRecord: Bool { config.startFEN == nil }

    // MARK: 操作

    func begin() {
        if let opponent { say(opponent.chessGreeting) }
        updateOutcome()
        if !isTwoPlayer && turn != humanSide && !isOver { scheduleAI() }
    }

    /// 点了棋盘上的一个格子：选子、换子，或者走到那里
    func tap(_ s: ChessSquare) {
        guard canHumanMove else { return }
        if let p = board[s], p.side == turn {
            withAnimation(.spring(duration: 0.25, bounce: 0.4)) {
                selected = selected == s ? nil : s
                clearWarning()
            }
            Sound.pick()
            return
        }
        guard let from = selected else { return }
        let legal = board.legalMoves(from: from).filter { $0.to == s }
        if legal.count > 1 {
            // 升变：先问升成什么
            withAnimation(.spring(duration: 0.3)) { pendingPromotion = (from, s) }
            Sound.pick()
        } else if let m = legal.first {
            attempt(m)
        } else {
            // 走不到那里：告诉她为什么（比如走了王会被吃）
            if board.pseudoMoves(from: from).contains(where: { $0.to == s }) {
                say(board[from]?.kind == .king ? "王不能走到会被吃掉的地方" : "不能这样走，走了王会被吃掉")
            }
            Sound.nope()
            withAnimation(.spring(duration: 0.25)) { selected = nil; clearWarning() }
        }
    }

    func choosePromotion(_ k: ChessKind) {
        guard let p = pendingPromotion else { return }
        withAnimation(.spring(duration: 0.25)) { pendingPromotion = nil }
        attempt(ChessMove(p.from, p.to, promotion: k))
    }

    func cancelPromotion() {
        withAnimation(.spring(duration: 0.25)) { pendingPromotion = nil; selected = nil }
    }

    /// 真的走之前：低档位先看看这一步是不是在送子 / 送杀，第一次只提醒
    private func attempt(_ m: ChessMove) {
        if !isTwoPlayer, level?.warnsBlunders == true, warned != m, let w = blunder(m) {
            withAnimation(.spring(duration: 0.3)) {
                warned = m
                warnSquares = w.squares
            }
            say(w.line)
            Sound.nope()
            return
        }
        play(m)
        if !isOver && !isTwoPlayer { scheduleAI() }
    }

    /// 这一步会不会白白丢掉一个马、象、车、后，或者让对方一步将死
    private func blunder(_ m: ChessMove) -> (line: String, squares: [ChessSquare])? {
        let after = board.applying(m)
        if after.outcome != nil { return nil }
        if let mate = after.matesInOne().first {
            return ("小心！走这里，对方下一步就能将死你。再点一次就走", [mate.from])
        }
        guard let p = board[m.from], p.kind != .pawn, p.kind != .king else { return nil }
        // 走过去的子被吃，而且吃回来也不够本
        let attackers = after.attackers(m.to.index, by: after.turn)
        guard !attackers.isEmpty else { return nil }
        let defended = after.attacked(m.to.index, by: p.side)
        let cheapest = attackers.compactMap { ChessPiece(code: after.cells[$0])?.kind.points }.min() ?? 0
        let captured = board.capturedPiece(m)?.kind.points ?? 0
        let loss = defended ? p.kind.points - cheapest : p.kind.points
        guard loss - captured >= 2 else { return nil }
        return ("小心！你的\(p.kind.chinese)走到这里会被吃掉。再点一次就走", attackers.map(ChessSquare.init(index:)))
    }

    private func clearWarning() {
        warned = nil
        warnSquares = []
    }

    func undo() {
        guard canUndo else { return }
        aiTask?.cancel()
        aiThinking = false
        withAnimation(.spring(duration: 0.3)) {
            if isTwoPlayer {
                pop()
            } else {
                while let last = history.indices.last, side(ofPly: last) != humanSide { pop() }
                if !history.isEmpty { pop() }
            }
            outcome = nil
            hint = nil
            selected = nil
            pendingPromotion = nil
            clearWarning()
        }
        if !isTwoPlayer { usedUndo = true }
        Sound.undo()
        updateCheckers()
    }

    func restart() {
        aiTask?.cancel()
        aiThinking = false
        withAnimation(.spring(duration: 0.4)) {
            match = ChessMatch(match.start)
            ids = ChessPieceIDs.initial(match.start)
            history = []
            outcome = nil
            hint = nil
            selected = nil
            checkers = []
            pendingPromotion = nil
            clearWarning()
            round += 1
        }
        usedUndo = false
        usedHint = false
        recordID = UUID()
        begin()
    }

    func changeLevel(_ l: ChessLevel) {
        guard !isTwoPlayer else { return }
        level = l
        restart()
    }

    func showHint() {
        guard canHumanMove else { return }
        let snapshot = board
        let hashes = match.hashes
        aiThinking = true
        Task { [weak self] in
            let m = await Task.detached(priority: .userInitiated) {
                ChessAI(profile: .level(7)).bestMove(snapshot, history: hashes)
            }.value
            guard let self else { return }
            self.aiThinking = false
            withAnimation(.spring(duration: 0.35)) {
                self.hint = m
                self.selected = m?.from
            }
            if !self.isTwoPlayer { self.usedHint = true }
            Sound.hint()
        }
    }

    func stop() {
        aiTask?.cancel()
        speechTask?.cancel()
    }

    #if DEBUG
    /// 调试截图用：直接算出这一盘的结果，好看结果页（启动参数 -winDemo，或者 -chessResult lose / draw）
    func debugFinish(_ result: String) {
        stop()
        aiThinking = false
        switch result {
        case "lose": outcome = .checkmate(winner: humanSide.other)
        case "draw": outcome = .stalemate
        default: outcome = .checkmate(winner: humanSide)
        }
    }

    /// 调试截图用：打开升变选子窗口（启动参数 -chessPromo YES，配合一个有兵在第七排的 -chessFEN）
    func debugPromotion() {
        guard let m = board.legalMoves().first(where: { $0.promotion != nil }) else { return }
        pendingPromotion = (m.from, m.to)
    }
    #endif

    // MARK: 内部

    private func play(_ m: ChessMove) {
        let mover = board.turn
        let before = board
        let captured = before.isCapture(m)
        withAnimation(.spring(duration: 0.38, bounce: 0.25)) {
            var newIDs = ids
            let cap = ChessPieceIDs.apply(m, on: before, &newIDs)
            ids = newIDs
            match.play(m)
            history.append(Played(move: m, capturedID: cap.id, capturedAt: cap.at))
            selected = nil
            hint = nil
            clearWarning()
            updateOutcome()
        }
        Sound.place(captured ? .white : .black)
        if board.inCheck, !isOver {
            checkFlash += 1
            Sound.sparkle()
        }
        if let opponent {
            if let winner { say(winner == humanSide ? opponent.loseLine : opponent.chessWinLine) }
            else if mover != humanSide, board.inCheck { say("将军！") }
        }
        updateCheckers()
    }

    private func updateOutcome() {
        outcome = match.outcome
    }

    private func pop() {
        guard let last = history.popLast() else { return }
        match.takeBack()
        var newIDs = ids
        ChessPieceIDs.revert(last.move, on: board, captured: (last.capturedID, last.capturedAt), &newIDs)
        ids = newIDs
    }

    private func scheduleAI() {
        guard let level else { return }
        aiThinking = true
        let snapshot = board
        let hashes = match.hashes
        let profile = level.profile
        aiTask = Task { [weak self] in
            let started = ContinuousClock.now
            let move = await Task.detached(priority: .userInitiated) {
                ChessAI(profile: profile).bestMove(snapshot, history: hashes)
            }.value
            let wait = level.thinkingTime + .milliseconds(Int.random(in: 0...300)) - (ContinuousClock.now - started)
            if wait > .zero { try? await Task.sleep(for: wait) }
            guard let self, !Task.isCancelled else { return }
            self.aiThinking = false
            if let move, self.board.isLegal(move) { self.play(move) }
        }
    }

    /// 低档位：轮到冉冉、她被将军时，把将军的子圈出来
    private func updateCheckers() {
        guard !isOver, isTwoPlayer || turn == humanSide, (level?.coaches ?? true),
              let k = board.king(turn), board.inCheck else {
            if !checkers.isEmpty { withAnimation { checkers = [] } }
            return
        }
        let found = board.attackers(k.index, by: turn.other).map(ChessSquare.init(index:))
        withAnimation(.spring(duration: 0.4)) { checkers = found }
        if !isTwoPlayer { say("被将军了！快保护你的王") }
    }

    private func say(_ text: String) {
        guard !text.isEmpty else { return }
        speechTask?.cancel()
        withAnimation(.spring(duration: 0.35, bounce: 0.3)) { speech = text }
        speechTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { self?.speech = nil }
        }
    }
}

extension Opponent {
    var chessGreeting: String {
        switch self {
        case .bunny:  "我们来下国际象棋吧～"
        case .panda:  "请多指教！白方先走哦"
        case .owl:    "咕咕，小心我的马会捉双"
        case .dragon: "我是国际象棋王，来挑战吧！"
        }
    }

    var chessWinLine: String {
        switch self {
        case .bunny:  "嘿嘿，将死你啦"
        case .panda:  "好险，被我赢了一局"
        case .owl:    "咕咕，再练练杀法吧"
        case .dragon: "哼哼，国际象棋王可不是白当的"
        }
    }
}

/// 国际象棋的进度：每档赢了几次、最好成绩、一共拿到的星星（计数规矩和别的棋一样，见 RewardStore）
extension PlayerStore {
    func chessBest(_ l: ChessLevel) -> Int { count("chess.best.\(l.number)") }
    func chessWins(_ l: ChessLevel) -> Int { count("chess.wins.\(l.number)") }
    /// 这一档赢棋拿到的星星（不算第一次赢的加奖）
    func chessStars(_ l: ChessLevel) -> Int { count("chess.stars.\(l.number)") }

    var chessRecommended: ChessLevel {
        let cleared = ChessLevel.all.last { chessBest($0) > 0 }?.number ?? 0
        return ChessLevel(cleared + 1)
    }

    /// 记一次胜利，星星按 RewardRules 发
    @discardableResult
    func recordChessWin(_ l: ChessLevel, stars: Int) -> WinResult {
        recordWin(game: "chess", level: l.number, earned: stars)
    }
}
