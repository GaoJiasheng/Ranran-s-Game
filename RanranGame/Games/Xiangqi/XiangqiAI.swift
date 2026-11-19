import Foundation

/// 象棋电脑对手：α-β 搜索 + 只看吃子的静态搜索 + 子力和位置分。
/// 低档位会"走神"（随机走、少想几步），高档位按时间想得更深。
struct XiangqiAI: Sendable {
    struct Profile: Sendable {
        var depth: Int
        /// 有多大概率随便走一步（只在最低几档）
        var randomChance: Double
        /// 给每个候选着法的分数加上多大的随机扰动
        var noise: Int
        var quiescence: Bool
        var timeLimit: Double

        static func level(_ n: Int) -> Profile {
            switch n {
            // 第 1 档大多数时候乱走，看到子也常常不吃；第 2 档开始会吃
            case 1:  Profile(depth: 1, randomChance: 0.7, noise: 220, quiescence: false, timeLimit: 0.5)
            case 2:  Profile(depth: 1, randomChance: 0.4, noise: 160, quiescence: true, timeLimit: 0.5)
            case 3:  Profile(depth: 2, randomChance: 0.08, noise: 90, quiescence: true, timeLimit: 0.8)
            case 4:  Profile(depth: 2, randomChance: 0, noise: 45, quiescence: true, timeLimit: 1)
            case 5:  Profile(depth: 3, randomChance: 0, noise: 30, quiescence: true, timeLimit: 1.2)
            case 6:  Profile(depth: 3, randomChance: 0, noise: 0, quiescence: true, timeLimit: 1.5)
            case 7:  Profile(depth: 4, randomChance: 0, noise: 0, quiescence: true, timeLimit: 2)
            case 8:  Profile(depth: 5, randomChance: 0, noise: 0, quiescence: true, timeLimit: 2.5)
            case 9:  Profile(depth: 6, randomChance: 0, noise: 0, quiescence: true, timeLimit: 3)
            default: Profile(depth: 8, randomChance: 0, noise: 0, quiescence: true, timeLimit: 4)
            }
        }
    }

    static let mate = 30000

    let profile: Profile

    /// 给 board.turn 这一方挑一步
    func bestMove(_ board: XBoard) -> XMove? {
        let moves = board.legalMoves()
        guard !moves.isEmpty else { return nil }
        if moves.count == 1 { return moves[0] }
        if profile.randomChance > 0, Double.random(in: 0..<1) < profile.randomChance {
            // 随便走也别送帅：只挑"不会被马上将死"的走法
            let safe = moves.filter { board.applying($0).matesInOne().isEmpty }
            return (safe.isEmpty ? moves : safe).randomElement()
        }
        var search = Search(deadline: Date().addingTimeInterval(profile.timeLimit), quiescence: profile.quiescence)
        return search.root(board, moves: moves, maxDepth: profile.depth, noise: profile.noise)
    }

    /// 复盘用：这个局面对轮到走的一方有多好（分数越大越好），想 depth 步
    func evaluate(_ board: XBoard, depth: Int) -> Int {
        var b = board
        var search = Search(deadline: Date().addingTimeInterval(profile.timeLimit), quiescence: true)
        if b.legalMoves().isEmpty { return -XiangqiAI.mate }
        return search.negamax(&b, depth: depth, alpha: -Search.inf, beta: Search.inf, ply: 0)
    }

    // MARK: - 搜索

    private struct Search {
        let deadline: Date
        let quiescence: Bool
        var nodes = 0
        var stopped = false
        var killers = [[XMove?]](repeating: [nil, nil], count: 64)
        var history = [Int](repeating: 0, count: 90 * 90)

        init(deadline: Date, quiescence: Bool) {
            self.deadline = deadline
            self.quiescence = quiescence
        }

        mutating func root(_ start: XBoard, moves: [XMove], maxDepth: Int, noise: Int) -> XMove {
            var board = start
            var order = moves.sorted { Eval.mvvLva($0, board) > Eval.mvvLva($1, board) }
            var best = order[0]
            for depth in 1...maxDepth {
                var scored: [(XMove, Int)] = []
                var alpha = -Self.inf
                for m in order {
                    let cap = board.make(m)
                    // 扰动档位要每步都算准确分，不能用窗口剪掉
                    let a = noise > 0 ? -Self.inf : alpha
                    let s = -negamax(&board, depth: depth - 1, alpha: -Self.inf, beta: -a, ply: 1)
                    board.unmake(m, captured: cap)
                    if stopped { break }
                    scored.append((m, s))
                    if s > alpha { alpha = s }
                }
                if stopped && scored.isEmpty { break }
                let jittered = scored.map { ($0.0, $0.1 + (noise > 0 ? Int.random(in: -noise...noise) : 0)) }
                if let top = jittered.max(by: { $0.1 < $1.1 }) { best = top.0 }
                // 下一层先搜这一层最好的
                let rank = Dictionary(scored.map { ($0.0, $0.1) }, uniquingKeysWith: max)
                order.sort { (rank[$0] ?? -Self.inf) > (rank[$1] ?? -Self.inf) }
                if stopped { break }
                // 找到杀棋就不用再想了
                if let s = scored.map(\.1).max(), s > XiangqiAI.mate - 100 { break }
                if Date() > deadline { break }
            }
            return best
        }

        static let inf = 1_000_000

        mutating func negamax(_ b: inout XBoard, depth: Int, alpha: Int, beta: Int, ply: Int) -> Int {
            nodes += 1
            if nodes & 1023 == 0, Date() > deadline { stopped = true }
            if stopped { return 0 }

            let checked = b.inCheck(b.turn)
            // 被将军时多想一步，避免看不见杀棋
            let d = checked ? depth + 1 : depth
            if d <= 0 {
                return quiescence ? quiesce(&b, alpha: alpha, beta: beta, ply: ply, qdepth: 0) : Eval.score(b)
            }

            var moves: [XMove] = []
            for i in 0..<90 where b.cells[i] != 0 && (b.cells[i] > 0) == (b.turn == .red) {
                b.pseudoMoves(from: XSquare(i % 9, i / 9), into: &moves, capturesOnly: false)
            }
            let k = ply < 64 ? killers[ply] : [nil, nil]
            let board = b
            let hist = history
            moves.sort { score($0, board, k, hist) > score($1, board, k, hist) }

            var a = alpha
            var legal = 0
            let side = b.turn
            for m in moves {
                let cap = b.make(m)
                if b.inCheck(side) { b.unmake(m, captured: cap); continue }
                legal += 1
                let s = -negamax(&b, depth: d - 1, alpha: -beta, beta: -a, ply: ply + 1)
                b.unmake(m, captured: cap)
                if stopped { return 0 }
                if s >= beta {
                    if cap == 0, ply < 64 {
                        if killers[ply][0] != m { killers[ply][1] = killers[ply][0]; killers[ply][0] = m }
                        history[m.from.index * 90 + m.to.index] += d * d
                    }
                    return s
                }
                if s > a { a = s }
            }
            // 没有合法着法：被将死或困毙，都算输
            if legal == 0 { return -XiangqiAI.mate + ply }
            return a
        }

        mutating func quiesce(_ b: inout XBoard, alpha: Int, beta: Int, ply: Int, qdepth: Int) -> Int {
            nodes += 1
            let stand = Eval.score(b)
            if stand >= beta { return stand }
            var a = max(alpha, stand)
            if qdepth >= 6 { return a }
            var moves: [XMove] = []
            for i in 0..<90 where b.cells[i] != 0 && (b.cells[i] > 0) == (b.turn == .red) {
                b.pseudoMoves(from: XSquare(i % 9, i / 9), into: &moves, capturesOnly: true)
            }
            let board = b
            moves.sort { Eval.mvvLva($0, board) > Eval.mvvLva($1, board) }
            let side = b.turn
            for m in moves {
                let cap = b.make(m)
                if b.inCheck(side) { b.unmake(m, captured: cap); continue }
                // 吃到帅就是赢
                if abs(cap) == XKind.king.rawValue { b.unmake(m, captured: cap); return XiangqiAI.mate - ply }
                let s = -quiesce(&b, alpha: -beta, beta: -a, ply: ply + 1, qdepth: qdepth + 1)
                b.unmake(m, captured: cap)
                if s >= beta { return s }
                if s > a { a = s }
            }
            return a
        }

        private func score(_ m: XMove, _ b: XBoard, _ k: [XMove?], _ hist: [Int]) -> Int {
            let mv = Eval.mvvLva(m, b)
            if mv > 0 { return 1_000_000 + mv }
            if k[0] == m { return 900_000 }
            if k[1] == m { return 800_000 }
            return hist[m.from.index * 90 + m.to.index]
        }
    }
}

// MARK: - 局面评估

enum Eval {
    static let value: [Int] = [0, 0, 120, 120, 270, 600, 285, 30] // 下标 = XKind.rawValue（帅不算子力）

    /// 吃子排序：先吃大子，用小子吃
    static func mvvLva(_ m: XMove, _ b: XBoard) -> Int {
        let t = abs(b.cells[m.to.index])
        guard t != 0 else { return 0 }
        let a = abs(b.cells[m.from.index])
        let victim = t == XKind.king.rawValue ? 10000 : value[Int(t)]
        return victim * 10 - value[Int(a)] / 10 + 1
    }

    /// 站在轮到走的一方看的分数
    static func score(_ b: XBoard) -> Int {
        var s = 0
        for i in 0..<90 {
            let c = b.cells[i]
            guard c != 0 else { continue }
            let kind = Int(abs(c))
            let red = c > 0
            let x = i % 9
            // 从这个子自己的方向看：y = 0 是自己的底线
            let y = red ? i / 9 : 9 - i / 9
            let v = value[kind] + positional(kind, x: x, y: y)
            s += red ? v : -v
        }
        return b.turn == .red ? s : -s
    }

    private static func positional(_ kind: Int, x: Int, y: Int) -> Int {
        let center = 4 - abs(x - 4) // 0…4，越靠中路越大
        switch XKind(rawValue: Int8(kind))! {
        case .pawn:
            // 过河的兵价值翻倍，越靠近对方九宫越值钱；底线的兵（老兵）没那么有用
            if y <= 4 { return y == 4 ? 6 : 0 }
            if y == 9 { return 20 }
            let palace = (x >= 3 && x <= 5) ? 22 : 0
            return 45 + (y - 5) * 10 + palace + center * 3
        case .horse:
            // 马在中间、往前走更活；窝在底线角上最差
            let forward = min(y, 7) * 6
            return center * 8 + forward - (y == 0 ? 20 : 0) - ((x == 0 || x == 8) ? 15 : 0)
        case .rook:
            // 车要出动：在对方阵地、在中间几路的车更好
            return (y >= 5 ? 20 : 0) + center * 4 + (y == 0 && (x == 0 || x == 8) ? -10 : 0)
        case .cannon:
            // 中炮最常见；炮在自己阵地中路有威胁
            return (x == 4 ? 18 : 0) + (y >= 2 && y <= 3 ? 6 : 0) + center * 2
        case .advisor, .elephant:
            return 0
        case .king:
            // 帅待在九宫中间那条线上最安全
            return x == 4 ? 6 : 0
        }
    }
}
