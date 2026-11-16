import SwiftUI
import Observation

/// 一局五子棋的全部状态：棋盘、轮到谁、悔棋、提示、电脑落子。
@Observable
@MainActor
final class GomokuGame {
    let config: GomokuConfig

    private(set) var board = Board()
    private(set) var moves: [Point] = []
    private(set) var turn: Stone = .black
    private(set) var winner: Stone?
    private(set) var winLine: [Point] = []
    private(set) var isDraw = false
    private(set) var aiThinking = false
    private(set) var hint: Point?
    private(set) var threats: [Point] = []
    private(set) var speech: String?
    /// 人机模式的难度（双人模式为 nil）
    private(set) var level: GomokuLevel?
    /// 这一局有没有悔棋、用提示——决定赢了能拿几颗星
    private(set) var usedUndo = false
    private(set) var usedHint = false
    /// 这一局棋谱的 id；悔棋后再下完会覆盖同一条记录
    private(set) var recordID = UUID()
    /// 每次重新开始都会变，界面用它来重置动画
    private(set) var round = 0

    private var aiTask: Task<Void, Never>?
    private var speechTask: Task<Void, Never>?

    init(config: GomokuConfig) {
        self.config = config
        self.level = config.mode.level
    }

    // MARK: - 查询

    var opponent: Opponent? { level?.character }
    var isTwoPlayer: Bool { opponent == nil }
    /// 人机模式下然然执的颜色
    var humanColor: Stone { config.humanFirst ? .black : .white }
    var isOver: Bool { winner != nil || isDraw }
    var lastMove: Point? { moves.last }
    var humanWon: Bool { winner != nil && (isTwoPlayer || winner == humanColor) }

    var canHumanMove: Bool {
        !isOver && !aiThinking && (isTwoPlayer || turn == humanColor)
    }

    var canUndo: Bool {
        if isTwoPlayer { return !moves.isEmpty }
        return moves.indices.contains { color(ofMove: $0) == humanColor }
    }

    func color(ofMove index: Int) -> Stone { index % 2 == 0 ? .black : .white }

    /// 赢了能拿几颗星：赢下比赛 + 没悔棋 + 没用提示
    var winStars: Int { 1 + (usedUndo ? 0 : 1) + (usedHint ? 0 : 1) }

    /// 把这一局存成棋谱
    func makeRecord(stars: Int) -> GameRecord {
        GameRecord(id: recordID, game: "gomoku", date: Date(), boardSize: Board.size,
                   moves: moves.map { [$0.x, $0.y] },
                   opponentLevel: level?.number,
                   playerColor: isTwoPlayer ? nil : Int(humanColor.rawValue),
                   winner: winner.map { Int($0.rawValue) },
                   stars: stars)
    }

    // MARK: - 操作

    func begin() {
        if let opponent { say(opponent.greeting) }
        if !isTwoPlayer && turn != humanColor { scheduleAI() }
    }

    @discardableResult
    func humanPlay(_ p: Point) -> Bool {
        guard canHumanMove, board[p] == nil else { return false }
        place(p)
        if !isOver && !isTwoPlayer { scheduleAI() }
        return true
    }

    func undo() {
        guard canUndo else { return }
        aiTask?.cancel()
        aiThinking = false
        withAnimation(.spring(duration: 0.3)) {
            if isTwoPlayer {
                popMove()
            } else {
                while let last = moves.indices.last, color(ofMove: last) != humanColor { popMove() }
                if !moves.isEmpty { popMove() }
            }
            winner = nil
            winLine = []
            isDraw = false
            hint = nil
        }
        if !isTwoPlayer { usedUndo = true }
        Sound.undo()
        updateThreats()
    }

    func restart() {
        aiTask?.cancel()
        aiThinking = false
        withAnimation(.spring(duration: 0.4)) {
            board = Board()
            moves = []
            turn = .black
            winner = nil
            winLine = []
            isDraw = false
            hint = nil
            threats = []
            round += 1
        }
        usedUndo = false
        usedHint = false
        recordID = UUID()
        begin()
    }

    /// 换一档难度，马上开新的一局
    func changeLevel(_ newLevel: GomokuLevel) {
        guard !isTwoPlayer else { return }
        level = newLevel
        restart()
    }

    func showHint() {
        guard canHumanMove else { return }
        let p = GomokuAI.bestMove(board: board, color: turn, level: 8)
        withAnimation(.spring(duration: 0.35)) { hint = p }
        if !isTwoPlayer { usedHint = true }
        Sound.hint()
    }

    func stop() {
        aiTask?.cancel()
        speechTask?.cancel()
    }

    // MARK: - 内部

    private func place(_ p: Point) {
        let color = turn
        withAnimation(.spring(duration: 0.32, bounce: 0.35)) {
            board[p] = color
            moves.append(p)
            hint = nil
            if let line = board.winningLine(at: p) {
                winner = color
                winLine = line
            } else if board.isFull {
                isDraw = true
            } else {
                turn = color.opponent
            }
        }
        Sound.place(color)
        if let opponent, let winner {
            say(winner == humanColor ? opponent.loseLine : opponent.winLine)
        }
        updateThreats()
    }

    private func popMove() {
        let p = moves.removeLast()
        board[p] = nil
        turn = moves.count % 2 == 0 ? .black : .white
    }

    private func scheduleAI() {
        guard let level else { return }
        aiThinking = true
        let snapshot = board
        let color = turn
        let profile = level.profile
        aiTask = Task { [weak self] in
            let started = ContinuousClock.now
            let move = await Task.detached(priority: .userInitiated) {
                GomokuAI.bestMove(board: snapshot, color: color, profile: profile)
            }.value
            let wait = level.thinkingTime + .milliseconds(Int.random(in: 0...350)) - (ContinuousClock.now - started)
            if wait > .zero { try? await Task.sleep(for: wait) }
            guard let self, !Task.isCancelled else { return }
            self.aiThinking = false
            self.place(move)
        }
    }

    /// 轮到然然下时，如果电脑下一步就能连五，把那些点标出来并提醒她。
    private func updateThreats() {
        guard let opponent, let level, level.coaches, !isOver, turn == humanColor else {
            if !threats.isEmpty { withAnimation { threats = [] } }
            return
        }
        let t = GomokuAI.winningPoints(board: board, color: humanColor.opponent)
        withAnimation(.spring(duration: 0.4)) { threats = t }
        if !t.isEmpty { say(opponent.warning) }
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
