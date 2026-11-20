import SwiftUI
import Observation

/// 围棋十档：1–3 档是吃子棋（先吃到 1 / 3 / 5 颗子就赢），4–10 档是正式的九路对局（数子，黑贴 7.5）。
struct GoLevel: Hashable, Identifiable, Comparable {
    static let range = 1...10
    static let all = range.map(GoLevel.init)

    let number: Int

    init(_ number: Int) {
        self.number = min(max(number, Self.range.lowerBound), Self.range.upperBound)
    }

    var id: Int { number }
    static func < (a: Self, b: Self) -> Bool { a.number < b.number }

    var character: Opponent { Opponent.forLevel(number) }
    var next: GoLevel? { number < Self.range.upperBound ? GoLevel(number + 1) : nil }
    var previous: GoLevel? { number > Self.range.lowerBound ? GoLevel(number - 1) : nil }

    /// 吃子棋要吃几颗赢；nil = 正式对局
    var captureTarget: Int? {
        switch number {
        case 1: 1
        case 2: 3
        case 3: 5
        default: nil
        }
    }

    var thinkingTime: Duration { .milliseconds(450 + number * 40) }

    var blurb: String {
        switch number {
        case 1:  "吃子棋：先吃到 1 颗子就赢"
        case 2:  "吃子棋：先吃到 3 颗子就赢"
        case 3:  "吃子棋：先吃到 5 颗子就赢"
        case 4:  "第一盘正式围棋，比谁的地多"
        case 5:  "开始会做活、会围地了"
        case 6:  "攻守都不错"
        case 7:  "会算死活，小心被吃"
        case 8:  "真正的高手"
        case 9:  "会提前布局"
        default: "最强的对手，想得最深"
        }
    }

    var info: LevelInfo { LevelInfo(number: number, blurb: blurb) }
}

enum GoMode: Hashable {
    case vsAI(GoLevel)
    case twoPlayer

    var level: GoLevel? {
        if case let .vsAI(l) = self { return l }
        return nil
    }
}

struct GoConfig: Hashable, Identifiable {
    let mode: GoMode
    let humanBlack: Bool
    var id: String { "\(mode)-\(humanBlack)" }
}

/// 一局围棋：落子、停一手、悔棋、提示、电脑走棋、终局数子。
@Observable
@MainActor
final class GoGame {
    struct Score: Equatable {
        let black: Int
        let white: Int
        /// 每个点最后归谁（0 / 1 / 2），终局时画在棋盘上
        let owner: [Int8]
        let dead: Set<Int>
        var margin: Double { Double(black) - Double(white) - GoAI.komi }
    }

    let config: GoConfig
    let size = 9

    private(set) var board = GoBoard(size: 9)
    /// 每一步之前的棋盘（悔棋用），和 moves 一一对应
    private var snapshots: [GoBoard] = []
    /// 每一步下在哪里；nil = 停一手
    private(set) var moves: [Int?] = []
    private(set) var winner: GoStone?
    private(set) var score: Score?
    private(set) var aiThinking = false
    private(set) var hint: Int?
    private(set) var speech: String?
    private(set) var level: GoLevel?
    private(set) var usedUndo = false
    private(set) var usedHint = false
    private(set) var recordID = UUID()
    private(set) var round = 0
    /// 刚刚被提掉的子（画一个消失的动画）
    private(set) var justCaptured: [Int] = []
    private(set) var counting = false

    private var aiTask: Task<Void, Never>?
    private var speechTask: Task<Void, Never>?

    init(config: GoConfig) {
        self.config = config
        level = config.mode.level
    }

    // MARK: 查询

    var opponent: Opponent? { level?.character }
    var isTwoPlayer: Bool { opponent == nil }
    var humanColor: GoStone { config.humanBlack ? .black : .white }
    var turn: GoStone { board.turn }
    var isOver: Bool { winner != nil }
    var lastMove: Int? { moves.last ?? nil }
    var lastWasPass: Bool { !moves.isEmpty && moves.last! == nil }
    var humanWon: Bool { winner != nil && (isTwoPlayer || winner == humanColor) }
    var captureTarget: Int? { level?.captureTarget }

    var canHumanMove: Bool { !isOver && !aiThinking && !counting && (isTwoPlayer || turn == humanColor) }

    var canUndo: Bool {
        if isTwoPlayer { return !moves.isEmpty }
        return moves.indices.contains { color(ofMove: $0) == humanColor }
    }

    func color(ofMove i: Int) -> GoStone { i % 2 == 0 ? .black : .white }

    /// 黑棋 / 白棋提了对方几颗
    func prisoners(_ s: GoStone) -> Int { board.prisoners[s == .black ? 0 : 1] }

    var winStars: Int { 1 + (usedUndo ? 0 : 1) + (usedHint ? 0 : 1) }

    func makeRecord(stars: Int) -> GameRecord {
        GameRecord(id: recordID, game: "go", date: Date(), boardSize: size,
                   moves: moves.map { m in m.map { [$0 % size, $0 / size] } ?? [-1, -1] },
                   opponentLevel: level?.number,
                   playerColor: isTwoPlayer ? nil : Int(humanColor.rawValue),
                   winner: winner.map { Int($0.rawValue) },
                   stars: stars)
    }

    // MARK: 操作

    func begin() {
        if let opponent { say(captureTarget != nil ? opponent.goCaptureGreeting(captureTarget!) : opponent.goGreeting) }
        if !isTwoPlayer && turn != humanColor { scheduleAI() }
    }

    func humanPlay(_ i: Int) {
        guard canHumanMove else { return }
        guard board.isLegal(i) else {
            if board.cells[i] == 0 {
                say(i == board.ko ? "打劫：要先在别处下一手才能提回来" : "这里没有气，是禁入点")
                Sound.nope()
            }
            return
        }
        play(i)
        if !isOver && !isTwoPlayer { scheduleAI() }
    }

    func humanPass() {
        guard canHumanMove, captureTarget == nil else { return }
        pass()
        if !isOver && !isTwoPlayer { scheduleAI() }
    }

    func undo() {
        guard canUndo else { return }
        aiTask?.cancel()
        aiThinking = false
        withAnimation(.spring(duration: 0.3)) {
            if isTwoPlayer {
                pop()
            } else {
                while let last = moves.indices.last, color(ofMove: last) != humanColor { pop() }
                if !moves.isEmpty { pop() }
            }
            winner = nil
            score = nil
            hint = nil
            justCaptured = []
        }
        if !isTwoPlayer { usedUndo = true }
        Sound.undo()
    }

    func restart() {
        aiTask?.cancel()
        aiThinking = false
        counting = false
        withAnimation(.spring(duration: 0.4)) {
            board = GoBoard(size: size)
            snapshots = []
            moves = []
            winner = nil
            score = nil
            hint = nil
            justCaptured = []
            round += 1
        }
        usedUndo = false
        usedHint = false
        recordID = UUID()
        begin()
    }

    func changeLevel(_ l: GoLevel) {
        guard !isTwoPlayer else { return }
        level = l
        restart()
    }

    func showHint() {
        guard canHumanMove else { return }
        let snapshot = board
        let capture = captureTarget
        aiThinking = true
        Task { [weak self] in
            let m = await Task.detached(priority: .userInitiated) {
                capture != nil ? GoAI.captureGameMove(snapshot, level: 3) : GoAI(profile: .level(8)).bestMove(snapshot)
            }.value
            guard let self else { return }
            self.aiThinking = false
            withAnimation(.spring(duration: 0.35)) { self.hint = m }
            if m == nil { self.say("提示：可以停一手了") }
            if !self.isTwoPlayer { self.usedHint = true }
            Sound.hint()
        }
    }

    func stop() {
        aiTask?.cancel()
        speechTask?.cancel()
    }

    // MARK: 内部

    private func play(_ i: Int) {
        let mover = board.turn
        snapshots.append(board)
        var captured: [Int] = []
        withAnimation(.spring(duration: 0.3, bounce: 0.3)) {
            captured = board.play(i) ?? []
            moves.append(i)
            hint = nil
            justCaptured = captured
        }
        Sound.place(mover == .black ? .black : .white)
        if !captured.isEmpty { Sound.pop() }
        if let target = captureTarget, board.prisoners[mover == .black ? 0 : 1] >= target {
            finish(winner: mover)
            return
        }
        if let opponent, !captured.isEmpty, mover == humanColor, captureTarget == nil, captured.count >= 3 {
            say(opponent.goOuch)
        }
    }

    private func pass() {
        let mover = board.turn
        snapshots.append(board)
        withAnimation(.spring(duration: 0.3)) {
            board.pass()
            moves.append(nil)
            hint = nil
            justCaptured = []
        }
        if isTwoPlayer || mover != humanColor { say("\(mover.name)停一手") }
        if board.passes >= 2 { countGame() }
    }

    private func pop() {
        guard let prev = snapshots.popLast() else { return }
        board = prev
        moves.removeLast()
    }

    /// 双方都停一手：找出死子，数子
    private func countGame() {
        counting = true
        let snapshot = board
        Task { [weak self] in
            let s = await Task.detached(priority: .userInitiated) { () -> Score in
                let dead = GoAI.deadStones(snapshot)
                let a = snapshot.area(dead: dead)
                return Score(black: a.black, white: a.white, owner: a.owner, dead: dead)
            }.value
            guard let self else { return }
            self.counting = false
            withAnimation(.easeInOut(duration: 0.6)) { self.score = s }
            self.finish(winner: s.margin > 0 ? .black : .white)
        }
    }

    private func finish(winner w: GoStone) {
        withAnimation(.spring(duration: 0.4)) { winner = w }
        if let opponent {
            say(w == humanColor ? opponent.loseLine : opponent.goWinLine)
        }
    }

    private func scheduleAI() {
        guard let level else { return }
        aiThinking = true
        let snapshot = board
        let capture = level.captureTarget
        let humanPassed = lastWasPass
        let ai = humanColor.other
        aiTask = Task { [weak self] in
            let started = ContinuousClock.now
            let move: Int? = await Task.detached(priority: .userInitiated) {
                if capture != nil { return GoAI.captureGameMove(snapshot, level: level.number) }
                // 对方停了一手：如果现在数子自己已经赢了，也停一手结束
                if humanPassed {
                    let dead = GoAI.deadStones(snapshot, playouts: 160)
                    let a = snapshot.area(dead: dead)
                    let margin = Double(a.black) - Double(a.white) - GoAI.komi
                    if (ai == .black) == (margin > 0) { return nil }
                    // 已经没希望了：也停一手，直接数子，不再乱下拖时间
                    if GoAI(profile: .level(6)).winRate(snapshot, playouts: 800) < 0.1 { return nil }
                }
                return GoAI(profile: .level(level.number)).bestMove(snapshot)
            }.value
            let wait = level.thinkingTime + .milliseconds(Int.random(in: 0...300)) - (ContinuousClock.now - started)
            if wait > .zero { try? await Task.sleep(for: wait) }
            guard let self, !Task.isCancelled else { return }
            self.aiThinking = false
            if let move { self.play(move) } else if capture == nil { self.pass() } else {
                // 吃子棋里没地方下（极少见）：直接判输
                self.finish(winner: self.humanColor)
            }
        }
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
    var goGreeting: String {
        switch self {
        case .bunny:  "我们来下围棋吧～"
        case .panda:  "请多指教！比比谁的地多"
        case .owl:    "咕咕，小心你的棋子没有气哦"
        case .dragon: "我是围棋王，来挑战吧！"
        }
    }

    func goCaptureGreeting(_ n: Int) -> String { "吃子棋：谁先吃到 \(n) 颗子谁赢！" }

    var goOuch: String {
        switch self {
        case .bunny:  "哎呀，被你吃掉好多！"
        case .panda:  "好厉害的吃子！"
        case .owl:    "咕……没算到这一手"
        case .dragon: "哼，这只是小损失"
        }
    }

    var goWinLine: String {
        switch self {
        case .bunny:  "嘿嘿，这次我赢啦"
        case .panda:  "好险，被我赢了一局"
        case .owl:    "咕咕，再练练死活吧"
        case .dragon: "哼哼，围棋王可不是白当的"
        }
    }
}

/// 围棋的进度
extension PlayerStore {
    func goBest(_ l: GoLevel) -> Int { count("go.best.\(l.number)") }
    func goWins(_ l: GoLevel) -> Int { count("go.wins.\(l.number)") }
    func goStars(_ l: GoLevel) -> Int { count("go.stars.\(l.number)") }
    var goStarTotal: Int { GoLevel.all.reduce(0) { $0 + goStars($1) } }

    var goRecommended: GoLevel {
        let cleared = GoLevel.all.last { goBest($0) > 0 }?.number ?? 0
        return GoLevel(cleared + 1)
    }

    @discardableResult
    func recordGoWin(_ l: GoLevel, stars: Int) -> Bool {
        increment("go.wins.\(l.number)")
        earnStars(stars, key: "go.stars.\(l.number)")
        let isRecord = stars > goBest(l)
        if isRecord { setCount("go.best.\(l.number)", stars) }
        return isRecord
    }
}
