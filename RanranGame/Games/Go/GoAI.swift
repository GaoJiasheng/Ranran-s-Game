import Foundation

/// 围棋电脑对手。
/// - 吃子棋（第 1–3 档）：按"能吃就吃、被叫吃就逃、别送子"打分，低档会走神。
/// - 正式对局（第 4–10 档）：蒙特卡洛树搜索（UCT + RAVE），档位越高模拟的盘数越多。
struct GoAI: Sendable {
    static let komi = 7.5

    struct Profile: Sendable {
        var playouts: Int
        var timeLimit: Double
        /// 从最好的几步里随便挑一步的概率（低档会犯错）
        var slip: Double

        static func level(_ n: Int) -> Profile {
            switch n {
            case ...4: Profile(playouts: 400, timeLimit: 1, slip: 0.25)
            case 5:  Profile(playouts: 1000, timeLimit: 1.2, slip: 0.12)
            case 6:  Profile(playouts: 2000, timeLimit: 1.5, slip: 0.05)
            case 7:  Profile(playouts: 4000, timeLimit: 2, slip: 0)
            case 8:  Profile(playouts: 8000, timeLimit: 2.5, slip: 0)
            case 9:  Profile(playouts: 15000, timeLimit: 3, slip: 0)
            default: Profile(playouts: 30000, timeLimit: 4, slip: 0)
            }
        }
    }

    // MARK: - 吃子棋

    /// 吃子棋：给每个点打分。level 1 最随便，3 会多看一步
    static func captureGameMove(_ b: GoBoard, level: Int) -> Int? {
        let moves = b.legalMoves
        guard !moves.isEmpty else { return nil }
        if level <= 1, Double.random(in: 0..<1) < 0.45 { return moves.randomElement() }
        let me = b.turn
        func score(_ m: Int) -> Double {
            guard let next = b.playing(m) else { return -1e9 }
            var s = 0.0
            let captured = next.prisoners[me == .black ? 0 : 1] - b.prisoners[me == .black ? 0 : 1]
            s += Double(captured) * 100
            // 自己这块只剩一口气：送子
            let myLibs = next.liberties(m)
            if myLibs == 1 { s -= 80 }
            s += Double(min(myLibs, 4)) * 4
            // 救自己被叫吃的子
            for n in b.neighbors(m) where b.cells[n] == me.rawValue && b.liberties(n) == 1 { s += 70 }
            // 叫吃对方
            for n in next.neighbors(m) where next.cells[n] == me.other.rawValue && next.liberties(n) == 1 { s += 30 }
            // 第 3 档：看一步，对方下一手能不能吃到我
            if level >= 3 {
                let threat = next.legalMoves.contains { r in
                    guard let after = next.playing(r) else { return false }
                    return after.prisoners[me == .black ? 1 : 0] > next.prisoners[me == .black ? 1 : 0]
                }
                if threat { s -= 60 }
            }
            // 开局别下到一线
            let x = b.x(m), y = b.y(m)
            if min(x, y, b.size - 1 - x, b.size - 1 - y) == 0 { s -= 6 }
            return s + Double.random(in: 0..<(level <= 1 ? 40 : level == 2 ? 15 : 4))
        }
        return moves.max { score($0) < score($1) }
    }

    // MARK: - 正式对局：蒙特卡洛树搜索

    let profile: Profile

    /// 返回 nil 表示停一手
    func bestMove(_ board: GoBoard) -> Int? {
        let candidates = Self.candidates(board)
        if candidates.isEmpty { return nil }
        let root = Node(move: -2, board: board)
        let deadline = Date().addingTimeInterval(profile.timeLimit)
        var n = 0
        while n < profile.playouts {
            if n & 63 == 0, Date() > deadline { break }
            iterate(root)
            n += 1
        }
        let ranked = root.children.sorted { $0.visits > $1.visits }
        guard let best = ranked.first else { return candidates.randomElement() }
        if profile.slip > 0, Double.random(in: 0..<1) < profile.slip {
            return ranked.prefix(4).randomElement()?.moveOrNil
        }
        return best.moveOrNil
    }

    /// 最好的一步胜率（站在轮到走的一方看）
    func winRate(_ board: GoBoard, playouts: Int) -> Double {
        let root = Node(move: -2, board: board)
        for _ in 0..<playouts { iterate(root) }
        guard let best = root.children.max(by: { $0.visits < $1.visits }), best.visits > 0 else { return 0.5 }
        return best.wins / Double(best.visits)
    }

    /// 合理的候选：合法、不往自己眼里填
    static func candidates(_ b: GoBoard) -> [Int] {
        (0..<b.cells.count).filter { b.cells[$0] == 0 && b.isLegal($0) && !b.isEye($0, for: b.turn) }
    }

    private final class Node {
        let move: Int          // -1 停一手，-2 根
        var board: GoBoard
        var children: [Node] = []
        var untried: [Int]
        var visits = 0
        var wins = 0.0         // 站在"走这一步的一方"看
        var amafVisits = 0
        var amafWins = 0.0

        init(move: Int, board: GoBoard) {
            self.move = move
            self.board = board
            var u = GoAI.candidates(board).shuffled()
            // 盘面够满时才考虑停一手
            if board.stoneCount > board.cells.count / 2 || u.isEmpty { u.append(-1) }
            untried = u
        }

        var moveOrNil: Int? { move >= 0 ? move : nil }
    }

    private func iterate(_ root: Node) {
        var path = [root]
        var node = root
        // 选择
        while node.untried.isEmpty, !node.children.isEmpty {
            node = select(node)
            path.append(node)
        }
        // 扩展
        if !node.untried.isEmpty, node.board.passes < 2 {
            let m = node.untried.removeLast()
            var b = node.board
            if m < 0 { b.pass() } else { b.play(m) }
            let child = Node(move: m, board: b)
            node.children.append(child)
            node = child
            path.append(node)
        }
        // 模拟
        var b = node.board
        var played: [(Int, GoStone)] = []
        Self.playout(&b, record: &played)
        let (black, white, _) = b.area()
        let blackWins = Double(black) > Double(white) + Self.komi
        // 回传
        for (k, n) in path.enumerated() {
            n.visits += 1
            // n 这一步是谁走的：n.board.turn 的对手
            let mover = n.board.turn.other
            if (mover == .black) == blackWins { n.wins += 1 }
            // RAVE：这一层之后出现过的着法，算作这一层孩子的"所有着法都先走"统计
            guard k < path.count else { continue }
            let toMove = n.board.turn
            var seen = Set<Int>()
            for (mv, c) in played where c == toMove { seen.insert(mv) }
            for child in n.children where child.move >= 0 && seen.contains(child.move) {
                child.amafVisits += 1
                if (toMove == .black) == blackWins { child.amafWins += 1 }
            }
        }
    }

    private func select(_ n: Node) -> Node {
        let logN = log(Double(max(n.visits, 1)))
        var best = n.children[0], bestScore = -Double.infinity
        for c in n.children {
            let q = c.visits > 0 ? c.wins / Double(c.visits) : 0.5
            let qa = c.amafVisits > 0 ? c.amafWins / Double(c.amafVisits) : 0.5
            let beta = sqrt(500.0 / (3.0 * Double(c.visits) + 500.0))
            let explore = 0.4 * sqrt(logN / Double(c.visits + 1))
            let s = (1 - beta) * q + beta * qa + explore
            if s > bestScore { bestScore = s; best = c }
        }
        return best
    }

    /// 随机下完一盘：能提就提，自己被叫吃就逃，不填自己的眼
    static func playout(_ b: inout GoBoard, record: inout [(Int, GoStone)]) {
        let limit = b.cells.count * 3
        var last = -1
        var steps = 0
        while b.passes < 2, steps < limit {
            steps += 1
            var move: Int?
            if last >= 0 {
                // 刚下的子旁边：能提的子提掉；自己只剩一口气的跑出来
                for k in 0..<4 {
                    let n = b.geo.nb[last * 4 + k]
                    guard n >= 0, b.cells[n] != 0, b.libertyCount(n, limit: 2) == 1 else { continue }
                    if b.cells[n] == b.turn.other.rawValue || Int.random(in: 0..<2) == 0 {
                        if let l = b.group(n).liberties.first, b.isLegal(l) { move = l; break }
                    }
                }
            }
            if move == nil {
                let n = b.cells.count
                var tries = 0
                while tries < 2 * n {
                    let i = Int.random(in: 0..<n)
                    tries += 1
                    if b.cells[i] == 0, !b.isEye(i, for: b.turn), b.isLegal(i) { move = i; break }
                }
                if move == nil {
                    move = (0..<n).first { b.cells[$0] == 0 && !b.isEye($0, for: b.turn) && b.isLegal($0) }
                }
            }
            if let m = move {
                record.append((m, b.turn))
                b.play(m)
                last = m
            } else {
                b.pass()
                last = -1
            }
        }
    }

    // MARK: - 终局：哪些子是死子

    /// 下很多盘随机棋，看每个点最后归谁；一颗子多半会被对方占掉，就当死子
    static func deadStones(_ board: GoBoard, playouts: Int = 240) -> Set<Int> {
        var own = [Int](repeating: 0, count: board.cells.count) // 正数黑多，负数白多
        for _ in 0..<playouts {
            var b = board
            var rec: [(Int, GoStone)] = []
            b.passes = 0
            playout(&b, record: &rec)
            let (_, _, owner) = b.area()
            for i in owner.indices { own[i] += owner[i] == 1 ? 1 : owner[i] == 2 ? -1 : 0 }
        }
        var dead = Set<Int>()
        let cut = Int(Double(playouts) * 0.4)
        for i in board.cells.indices {
            if board.cells[i] == 1, own[i] < -cut { dead.insert(i) }
            if board.cells[i] == 2, own[i] > cut { dead.insert(i) }
        }
        return dead
    }
}
