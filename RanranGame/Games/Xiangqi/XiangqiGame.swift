import SwiftUI
import Observation

/// 象棋的十档难度，和五子棋一样分给四位小伙伴。
struct XiangqiLevel: Hashable, Identifiable, Comparable {
    static let range = 1...10
    static let all = range.map(XiangqiLevel.init)

    let number: Int

    init(_ number: Int) {
        self.number = min(max(number, Self.range.lowerBound), Self.range.upperBound)
    }

    var id: Int { number }
    static func < (a: Self, b: Self) -> Bool { a.number < b.number }

    var character: Opponent { Opponent.forLevel(number) }
    var profile: XiangqiAI.Profile { .level(number) }
    var next: XiangqiLevel? { number < Self.range.upperBound ? XiangqiLevel(number + 1) : nil }
    var previous: XiangqiLevel? { number > Self.range.lowerBound ? XiangqiLevel(number - 1) : nil }

    /// 被将军、子要被吃时，会不会提醒冉冉
    var coaches: Bool { number <= 5 }

    var thinkingTime: Duration { .milliseconds(500 + number * 50) }

    var blurb: String {
        switch number {
        case 1:  "刚学会走棋，经常乱走"
        case 2:  "看到能吃的子就吃"
        case 3:  "开始保护自己的子啦"
        case 4:  "会想一想你下一步要干嘛"
        case 5:  "会抓你没保护的子"
        case 6:  "攻守都很稳"
        case 7:  "会算好几步，小心杀招"
        case 8:  "真正的高手"
        case 9:  "会提前布局，很难对付"
        default: "最强的对手，想得最深"
        }
    }

    var info: LevelInfo { LevelInfo(number: number, blurb: blurb) }
}

enum XiangqiMode: Hashable {
    case vsAI(XiangqiLevel)
    case twoPlayer

    var level: XiangqiLevel? {
        if case let .vsAI(l) = self { return l }
        return nil
    }
}

struct XiangqiConfig: Hashable, Identifiable {
    let mode: XiangqiMode
    /// 人机模式下冉冉执红（先走）
    let humanRed: Bool
    var id: String { "\(mode)-\(humanRed)" }
}

/// 一局象棋：棋盘、选子、走子、悔棋、提示、电脑走棋、胜负和和棋。
@Observable
@MainActor
final class XiangqiGame {
    struct Played: Hashable {
        let move: XMove
        let captured: Int8
        let capturedID: Int
    }

    let config: XiangqiConfig

    private(set) var board = XBoard(fen: XBoard.start)!
    /// 每个格子上棋子的编号（0 = 空），走子时编号跟着子走，界面才能画出"滑过去"的动画
    private(set) var ids = XBoard.initialIDs(XBoard(fen: XBoard.start)!)
    private(set) var history: [Played] = []
    private(set) var selected: XSquare?
    private(set) var winner: XSide?
    private(set) var isDraw = false
    private(set) var drawReason = ""
    private(set) var aiThinking = false
    private(set) var hint: XMove?
    private(set) var speech: String?
    /// 正在将军的那些子（低档位会圈出来提醒）
    private(set) var checkers: [XSquare] = []
    private(set) var level: XiangqiLevel?
    private(set) var usedUndo = false
    private(set) var usedHint = false
    private(set) var recordID = UUID()
    private(set) var round = 0
    /// 一闪一闪的"将军！"
    private(set) var checkFlash = 0

    private var positions: [String: Int] = [:]
    private var quietPlies = 0
    private var aiTask: Task<Void, Never>?
    private var speechTask: Task<Void, Never>?

    init(config: XiangqiConfig) {
        self.config = config
        level = config.mode.level
        positions[board.fen] = 1
    }

    // MARK: 查询

    var opponent: Opponent? { level?.character }
    var isTwoPlayer: Bool { opponent == nil }
    var humanSide: XSide { config.humanRed ? .red : .black }
    var turn: XSide { board.turn }
    var isOver: Bool { winner != nil || isDraw }
    var lastMove: XMove? { history.last?.move }
    var humanWon: Bool { winner != nil && (isTwoPlayer || winner == humanSide) }
    var inCheck: Bool { !isOver && board.inCheck(board.turn) }
    /// 棋盘下方是哪一方（自己这边在下面）
    var bottomSide: XSide { isTwoPlayer ? .red : humanSide }

    var canHumanMove: Bool { !isOver && !aiThinking && (isTwoPlayer || turn == humanSide) }

    var canUndo: Bool {
        if isTwoPlayer { return !history.isEmpty }
        return history.indices.contains { side(ofPly: $0) == humanSide }
    }

    func side(ofPly i: Int) -> XSide { i % 2 == 0 ? .red : .black }

    /// 选中的子能走到哪些地方
    var targets: [XMove] {
        guard let selected, canHumanMove else { return [] }
        return board.legalMoves(from: selected)
    }

    /// 双方被吃掉的子（显示在旁边）
    func captured(by who: XSide) -> [XPiece] {
        history.enumerated().compactMap { i, p in
            side(ofPly: i) == who ? XPiece(code: p.captured) : nil
        }
    }

    var winStars: Int { 1 + (usedUndo ? 0 : 1) + (usedHint ? 0 : 1) }

    func makeRecord(stars: Int) -> GameRecord {
        GameRecord(id: recordID, game: "xiangqi", date: Date(), boardSize: 9,
                   moves: history.map { [$0.move.from.x, $0.move.from.y, $0.move.to.x, $0.move.to.y] },
                   opponentLevel: level?.number,
                   playerColor: isTwoPlayer ? nil : (humanSide == .red ? 1 : 2),
                   winner: winner.map { $0 == .red ? 1 : 2 },
                   stars: stars)
    }

    // MARK: 操作

    func begin() {
        if let opponent { say(opponent.xiangqiGreeting) }
        if !isTwoPlayer && turn != humanSide { scheduleAI() }
    }

    /// 点了棋盘上的一个点：选子、换子，或者走到那里
    func tap(_ s: XSquare) {
        guard canHumanMove else { return }
        if let p = board[s], p.side == turn {
            withAnimation(.spring(duration: 0.25, bounce: 0.4)) { selected = selected == s ? nil : s }
            Sound.pick()
            return
        }
        guard let from = selected else { return }
        let move = XMove(from, s)
        if board.legalMoves(from: from).contains(move) {
            play(move)
            if !isOver && !isTwoPlayer { scheduleAI() }
        } else {
            // 走不到那里：把为什么告诉她（比如会被将军）
            if board.pseudoMoves(from: from).contains(move) {
                say("不能这样走，走了帅会被吃掉")
            }
            Sound.nope()
            withAnimation(.spring(duration: 0.25)) { selected = nil }
        }
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
            winner = nil
            isDraw = false
            hint = nil
            selected = nil
        }
        if !isTwoPlayer { usedUndo = true }
        Sound.undo()
        updateCheckers()
    }

    func restart() {
        aiTask?.cancel()
        aiThinking = false
        withAnimation(.spring(duration: 0.4)) {
            board = XBoard(fen: XBoard.start)!
            ids = XBoard.initialIDs(board)
            history = []
            winner = nil
            isDraw = false
            hint = nil
            selected = nil
            checkers = []
            round += 1
        }
        positions = [board.fen: 1]
        quietPlies = 0
        usedUndo = false
        usedHint = false
        recordID = UUID()
        begin()
    }

    func changeLevel(_ l: XiangqiLevel) {
        guard !isTwoPlayer else { return }
        level = l
        restart()
    }

    func showHint() {
        guard canHumanMove else { return }
        let snapshot = board
        aiThinking = true
        Task { [weak self] in
            let m = await Task.detached(priority: .userInitiated) {
                XiangqiAI(profile: .level(7)).bestMove(snapshot)
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
    /// 调试截图用：直接算冉冉赢了这一盘，好看结果页（启动参数 -winDemo）
    func debugWin() {
        stop()
        aiThinking = false
        winner = humanSide
    }
    #endif

    // MARK: 内部

    private func play(_ m: XMove) {
        let mover = board.turn
        withAnimation(.spring(duration: 0.38, bounce: 0.25)) {
            let capID = ids[m.to.index]
            let cap = board.make(m)
            ids[m.to.index] = ids[m.from.index]
            ids[m.from.index] = 0
            history.append(Played(move: m, captured: cap, capturedID: capID))
            selected = nil
            hint = nil
            quietPlies = cap == 0 ? quietPlies + 1 : 0
            let key = board.fen
            positions[key, default: 0] += 1
            if board.isLost {
                winner = mover
            } else if positions[key, default: 0] >= 3 {
                isDraw = true
                drawReason = "同一个局面出现了三次"
            } else if quietPlies >= 120 {
                isDraw = true
                drawReason = "很久都没有吃子了"
            }
        }
        let captured = history.last!.captured != 0
        Sound.place(captured ? .white : .black)
        if board.inCheck(board.turn), !isOver {
            checkFlash += 1
            Sound.sparkle()
        }
        if let opponent {
            if let winner { say(winner == humanSide ? opponent.loseLine : opponent.xiangqiWinLine) }
            else if mover != humanSide, board.inCheck(board.turn) { say("将军！") }
        }
        updateCheckers()
    }

    private func pop() {
        guard let last = history.popLast() else { return }
        let key = board.fen
        positions[key, default: 1] -= 1
        board.unmake(last.move, captured: last.captured)
        ids[last.move.from.index] = ids[last.move.to.index]
        ids[last.move.to.index] = last.capturedID
        quietPlies = max(0, quietPlies - 1)
    }

    private func scheduleAI() {
        guard let level else { return }
        aiThinking = true
        let snapshot = board
        let profile = level.profile
        aiTask = Task { [weak self] in
            let started = ContinuousClock.now
            let move = await Task.detached(priority: .userInitiated) {
                XiangqiAI(profile: profile).bestMove(snapshot)
            }.value
            let wait = level.thinkingTime + .milliseconds(Int.random(in: 0...300)) - (ContinuousClock.now - started)
            if wait > .zero { try? await Task.sleep(for: wait) }
            guard let self, !Task.isCancelled else { return }
            self.aiThinking = false
            if let move { self.play(move) }
        }
    }

    /// 低档位：轮到冉冉、她被将军时，把将军的子圈出来
    private func updateCheckers() {
        guard !isOver, isTwoPlayer || turn == humanSide, (level?.coaches ?? true),
              let k = board.king(turn), board.inCheck(turn) else {
            if !checkers.isEmpty { withAnimation { checkers = [] } }
            return
        }
        let enemy = turn.other
        let found = board.pieces.filter { sq, p in
            p.side == enemy && attacks(from: sq, to: k)
        }.map(\.0)
        withAnimation(.spring(duration: 0.4)) { checkers = found }
        if !isTwoPlayer { say("被将军了！快想办法保护帅") }
    }

    /// 这个子是不是正在将军（含帅将照面）
    private func attacks(from s: XSquare, to k: XSquare) -> Bool {
        var b = board
        b.turn = b[s]!.side
        if b.pseudoMoves(from: s).contains(XMove(s, k)) { return true }
        if b[s]?.kind == .king, s.x == k.x {
            let lo = min(s.y, k.y) + 1, hi = max(s.y, k.y) - 1
            return lo > hi || (lo...hi).allSatisfy { b[s.x, $0] == nil }
        }
        return false
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
    var xiangqiGreeting: String {
        switch self {
        case .bunny:  "我们来下象棋吧～"
        case .panda:  "请多指教！红先黑后哦"
        case .owl:    "咕咕，小心我的马"
        case .dragon: "我是象棋王，来挑战吧！"
        }
    }

    var xiangqiWinLine: String {
        switch self {
        case .bunny:  "嘿嘿，将死你啦"
        case .panda:  "好险，被我赢了一局"
        case .owl:    "咕咕，再练练杀法吧"
        case .dragon: "哼哼，象棋王可不是白当的"
        }
    }
}

/// 象棋的进度：每档赢了几次、最好成绩、一共拿到的星星
extension PlayerStore {
    func xiangqiBest(_ l: XiangqiLevel) -> Int { count("xiangqi.best.\(l.number)") }
    func xiangqiWins(_ l: XiangqiLevel) -> Int { count("xiangqi.wins.\(l.number)") }
    /// 这一档赢棋拿到的星星（不算第一次赢的加奖）
    func xiangqiStars(_ l: XiangqiLevel) -> Int { count("xiangqi.stars.\(l.number)") }

    var xiangqiRecommended: XiangqiLevel {
        let cleared = XiangqiLevel.all.last { xiangqiBest($0) > 0 }?.number ?? 0
        return XiangqiLevel(cleared + 1)
    }

    /// 记一次胜利，星星按 RewardRules 发（见 recordGomokuWin）
    @discardableResult
    func recordXiangqiWin(_ l: XiangqiLevel, stars: Int) -> WinResult {
        recordWin(game: "xiangqi", level: l.number, earned: stars)
    }
}
