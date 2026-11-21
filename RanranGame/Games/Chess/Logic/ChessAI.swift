import Foundation

/// 国际象棋电脑对手：α-β 搜索（逐层加深）+ 只看吃子的静态搜索 + 子力和位置分 + 走法排序（吃子、杀手着、历史分）。
/// 低档位会"走神"（随便走、只想一步、给每步的分数加随机扰动），高档位在时间限制内想得更深。
/// 搜索很快，但还是要放在后台线程里跑（界面那边用 Task.detached），iPad 上不卡。
struct ChessAI: Sendable {
    struct Profile: Sendable {
        var depth: Int
        /// 有多大概率随便走一步（只在最低几档）
        var randomChance: Double
        /// 给每个候选着法的分数加上多大的随机扰动（单位：百分之一个兵）
        var noise: Int
        var quiescence: Bool
        var timeLimit: Double

        static func level(_ n: Int) -> Profile {
            switch n {
            // 第 1 档大多数时候乱走；第 2 档看到子就吃（不管有没有保护）；第 3 档会看对方能不能吃回来
            case 1:  Profile(depth: 1, randomChance: 0.75, noise: 250, quiescence: false, timeLimit: 0.5)
            case 2:  Profile(depth: 1, randomChance: 0.4, noise: 150, quiescence: false, timeLimit: 0.5)
            case 3:  Profile(depth: 1, randomChance: 0.15, noise: 100, quiescence: true, timeLimit: 0.6)
            case 4:  Profile(depth: 2, randomChance: 0, noise: 50, quiescence: true, timeLimit: 1)
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

    /// 给 board.turn 这一方挑一步。history：这盘棋走过的局面哈希（避免傻傻地重复局面）
    func bestMove(_ board: ChessBoard, history: [UInt64] = []) -> ChessMove? {
        let moves = board.legalMoves()
        guard !moves.isEmpty else { return nil }
        if moves.count == 1 { return moves[0] }
        if profile.randomChance > 0, Double.random(in: 0..<1) < profile.randomChance {
            // 随便走也别送对方一步杀
            let safe = moves.filter { board.applying($0).matesInOne().isEmpty }
            return (safe.isEmpty ? moves : safe).randomElement()
        }
        var candidates = moves
        if profile.depth <= 1 {
            // 只想一步的档位看不见对方的杀棋：先把会被一步杀的走法去掉
            let safe = moves.filter { board.applying($0).matesInOne().isEmpty }
            if !safe.isEmpty { candidates = safe }
        }
        var search = Search(deadline: Date().addingTimeInterval(profile.timeLimit), quiescence: profile.quiescence,
                            history: Set(history.dropLast()))
        return search.root(board, moves: candidates, maxDepth: profile.depth, noise: profile.noise)
    }

    /// 复盘用：这个局面对轮到走的一方有多好（分数越大越好），想 depth 步
    func evaluate(_ board: ChessBoard, depth: Int) -> Int {
        if let o = board.outcome {
            return o.winner == nil ? 0 : -ChessAI.mate
        }
        var b = board
        var search = Search(deadline: Date().addingTimeInterval(profile.timeLimit), quiescence: true, history: [])
        return search.negamax(&b, depth: depth, alpha: -Search.inf, beta: Search.inf, ply: 0)
    }

    // MARK: - 搜索

    private struct Search {
        let deadline: Date
        let quiescence: Bool
        let history: Set<UInt64>
        var nodes = 0
        var stopped = false
        var path: [UInt64] = []
        var killers = [[ChessMove?]](repeating: [nil, nil], count: 64)
        var historyScore = [Int](repeating: 0, count: 64 * 64)

        init(deadline: Date, quiescence: Bool, history: Set<UInt64>) {
            self.deadline = deadline
            self.quiescence = quiescence
            self.history = history
        }

        static let inf = 1_000_000

        mutating func root(_ start: ChessBoard, moves: [ChessMove], maxDepth: Int, noise: Int) -> ChessMove {
            var board = start
            var order = moves.sorted { ChessEval.order($0, board) > ChessEval.order($1, board) }
            var best = order[0]
            path = [board.hash]
            for depth in 1...maxDepth {
                var scored: [(ChessMove, Int)] = []
                var alpha = -Self.inf
                for m in order {
                    let u = board.make(m)
                    // 扰动档位要每步都算准确分，不能用窗口剪掉
                    let a = noise > 0 ? -Self.inf : alpha
                    let s = -child(&board, depth: depth - 1, alpha: -Self.inf, beta: -a, ply: 1)
                    board.unmake(m, u)
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
                if let s = scored.map(\.1).max(), s > ChessAI.mate - 100 { break }
                if Date() > deadline { break }
            }
            return best
        }

        /// 走完一步以后的局面：先看是不是重复局面 / 50 步，再往下搜
        private mutating func child(_ b: inout ChessBoard, depth: Int, alpha: Int, beta: Int, ply: Int) -> Int {
            if b.halfmove >= 100 || history.contains(b.hash) || path.contains(b.hash) { return 0 }
            path.append(b.hash)
            defer { path.removeLast() }
            return negamax(&b, depth: depth, alpha: alpha, beta: beta, ply: ply)
        }

        mutating func negamax(_ b: inout ChessBoard, depth: Int, alpha: Int, beta: Int, ply: Int) -> Int {
            nodes += 1
            if nodes & 1023 == 0, Date() > deadline { stopped = true }
            if stopped { return 0 }

            let checked = b.inCheck
            // 被将军时多想一步，免得看不见杀棋
            let d = checked && ply < 24 ? depth + 1 : depth
            if d <= 0 {
                return quiescence ? quiesce(&b, alpha: alpha, beta: beta, ply: ply, qdepth: 0) : ChessEval.score(b)
            }

            var moves: [ChessMove] = []
            moves.reserveCapacity(48)
            b.pseudoMoves(into: &moves)
            let k = ply < 64 ? killers[ply] : [nil, nil]
            let board = b
            let hist = historyScore
            moves.sort { score($0, board, k, hist) > score($1, board, k, hist) }

            var a = alpha
            var legal = 0
            let side = b.turn
            for m in moves {
                let u = b.make(m)
                if b.inCheck(side) { b.unmake(m, u); continue }
                legal += 1
                let s = -child(&b, depth: d - 1, alpha: -beta, beta: -a, ply: ply + 1)
                b.unmake(m, u)
                if stopped { return 0 }
                if s >= beta {
                    if u.captured == 0, m.promotion == nil, ply < 64 {
                        if killers[ply][0] != m { killers[ply][1] = killers[ply][0]; killers[ply][0] = m }
                        historyScore[m.from.index * 64 + m.to.index] += d * d
                    }
                    return s
                }
                if s > a { a = s }
            }
            if legal == 0 { return checked ? -ChessAI.mate + ply : 0 }
            return a
        }

        mutating func quiesce(_ b: inout ChessBoard, alpha: Int, beta: Int, ply: Int, qdepth: Int) -> Int {
            nodes += 1
            if nodes & 1023 == 0, Date() > deadline { stopped = true }
            if stopped { return 0 }
            let stand = ChessEval.score(b)
            if stand >= beta { return stand }
            var a = max(alpha, stand)
            if qdepth >= 8 { return a }
            var moves: [ChessMove] = []
            b.pseudoMoves(into: &moves, capturesOnly: true)
            let board = b
            moves.sort { ChessEval.order($0, board) > ChessEval.order($1, board) }
            let side = b.turn
            for m in moves {
                // 吃到的子加上最多的位置分也追不上 alpha：不用试了
                let gain = ChessEval.value[Int(abs(board.cells[m.to.index]))] + (m.promotion != nil ? 800 : 0)
                if stand + gain + 200 < a, m.promotion == nil { continue }
                let u = b.make(m)
                if b.inCheck(side) { b.unmake(m, u); continue }
                let s = -quiesce(&b, alpha: -beta, beta: -a, ply: ply + 1, qdepth: qdepth + 1)
                b.unmake(m, u)
                if s >= beta { return s }
                if s > a { a = s }
            }
            return a
        }

        private func score(_ m: ChessMove, _ b: ChessBoard, _ k: [ChessMove?], _ hist: [Int]) -> Int {
            let mv = ChessEval.order(m, b)
            if mv > 0 { return 1_000_000 + mv }
            if k[0] == m { return 900_000 }
            if k[1] == m { return 800_000 }
            return hist[m.from.index * 64 + m.to.index]
        }
    }
}

// MARK: - 局面评估

enum ChessEval {
    /// 下标 = ChessKind.rawValue：王不算子力
    static let value: [Int] = [0, 0, 900, 500, 330, 320, 100]

    /// 吃子排序：先吃大子、用小子吃；升变排在最前面
    static func order(_ m: ChessMove, _ b: ChessBoard) -> Int {
        var s = 0
        if let p = m.promotion { s += p == .queen ? 9000 : 100 }
        let t = Int(abs(b.cells[m.to.index]))
        if t != 0 {
            s += value[t] * 10 - value[Int(abs(b.cells[m.from.index]))] / 10 + 1
        } else if b.isEnPassant(m) {
            s += 1000 - 10 + 1
        }
        return s
    }

    /// 站在轮到走的一方看的分数（百分之一个兵）
    static func score(_ b: ChessBoard) -> Int {
        var mg = 0, eg = 0, phase = 0
        var material = [0, 0]   // 白、黑（不算兵和王）
        var pawns = [0, 0]
        for i in 0..<64 {
            let c = b.cells[i]
            guard c != 0 else { continue }
            let kind = Int(abs(c))
            let white = c > 0
            // 表是按白方从上往下写的（第 0 行是第 8 横线）：白方要上下翻过来
            let t = white ? (7 - (i >> 3)) * 8 + (i & 7) : i
            let v = value[kind]
            let m: Int, e: Int
            switch kind {
            case 6: m = v + pawnTable[t]; e = v + pawnEnd[t]; pawns[white ? 0 : 1] += 1
            case 5: m = v + knightTable[t]; e = v + knightTable[t]; phase += 1
            case 4: m = v + bishopTable[t]; e = v + bishopTable[t]; phase += 1
            case 3: m = v + rookTable[t]; e = v + rookTable[t]; phase += 2
            case 2: m = v + queenTable[t]; e = v + queenTable[t]; phase += 4
            default: m = kingMid[t]; e = kingEnd[t]
            }
            if kind >= 2, kind <= 5 { material[white ? 0 : 1] += v }
            mg += white ? m : -m
            eg += white ? e : -e
        }
        phase = min(phase, 24)
        var s = (mg * phase + eg * (24 - phase)) / 24
        s += mopUp(b, material: material, pawns: pawns)
        return b.turn == .white ? s : -s
    }

    /// 残局里一方多出很多子（比如王后对单王）：把对方的王往角上赶，自己的王靠过去
    private static func mopUp(_ b: ChessBoard, material: [Int], pawns: [Int]) -> Int {
        let diff = material[0] - material[1]
        guard abs(diff) >= 400 else { return 0 }
        let strong: ChessSide = diff > 0 ? .white : .black
        let weakIdx = strong == .white ? 1 : 0
        guard material[weakIdx] == 0, pawns[weakIdx] == 0,
              let wk = b.king(strong.other), let sk = b.king(strong) else { return 0 }
        let center = max(3 - wk.file, wk.file - 4) + max(3 - wk.rank, wk.rank - 4)
        let dist = abs(wk.file - sk.file) + abs(wk.rank - sk.rank)
        let bonus = center * 10 + (14 - dist) * 4
        return strong == .white ? bonus : -bonus
    }

    // 位置分（简化评估函数里的表，从白方看，第一行是第 8 横线）
    static let pawnTable = [
        0, 0, 0, 0, 0, 0, 0, 0,
        50, 50, 50, 50, 50, 50, 50, 50,
        10, 10, 20, 30, 30, 20, 10, 10,
        5, 5, 10, 25, 25, 10, 5, 5,
        0, 0, 0, 20, 20, 0, 0, 0,
        5, -5, -10, 0, 0, -10, -5, 5,
        5, 10, 10, -20, -20, 10, 10, 5,
        0, 0, 0, 0, 0, 0, 0, 0,
    ]
    static let pawnEnd = [
        0, 0, 0, 0, 0, 0, 0, 0,
        80, 80, 80, 80, 80, 80, 80, 80,
        50, 50, 50, 50, 50, 50, 50, 50,
        30, 30, 30, 30, 30, 30, 30, 30,
        20, 20, 20, 20, 20, 20, 20, 20,
        10, 10, 10, 10, 10, 10, 10, 10,
        5, 5, 5, 5, 5, 5, 5, 5,
        0, 0, 0, 0, 0, 0, 0, 0,
    ]
    static let knightTable = [
        -50, -40, -30, -30, -30, -30, -40, -50,
        -40, -20, 0, 0, 0, 0, -20, -40,
        -30, 0, 10, 15, 15, 10, 0, -30,
        -30, 5, 15, 20, 20, 15, 5, -30,
        -30, 0, 15, 20, 20, 15, 0, -30,
        -30, 5, 10, 15, 15, 10, 5, -30,
        -40, -20, 0, 5, 5, 0, -20, -40,
        -50, -40, -30, -30, -30, -30, -40, -50,
    ]
    static let bishopTable = [
        -20, -10, -10, -10, -10, -10, -10, -20,
        -10, 0, 0, 0, 0, 0, 0, -10,
        -10, 0, 5, 10, 10, 5, 0, -10,
        -10, 5, 5, 10, 10, 5, 5, -10,
        -10, 0, 10, 10, 10, 10, 0, -10,
        -10, 10, 10, 10, 10, 10, 10, -10,
        -10, 5, 0, 0, 0, 0, 5, -10,
        -20, -10, -10, -10, -10, -10, -10, -20,
    ]
    static let rookTable = [
        0, 0, 0, 0, 0, 0, 0, 0,
        5, 10, 10, 10, 10, 10, 10, 5,
        -5, 0, 0, 0, 0, 0, 0, -5,
        -5, 0, 0, 0, 0, 0, 0, -5,
        -5, 0, 0, 0, 0, 0, 0, -5,
        -5, 0, 0, 0, 0, 0, 0, -5,
        -5, 0, 0, 0, 0, 0, 0, -5,
        0, 0, 0, 5, 5, 0, 0, 0,
    ]
    static let queenTable = [
        -20, -10, -10, -5, -5, -10, -10, -20,
        -10, 0, 0, 0, 0, 0, 0, -10,
        -10, 0, 5, 5, 5, 5, 0, -10,
        -5, 0, 5, 5, 5, 5, 0, -5,
        0, 0, 5, 5, 5, 5, 0, -5,
        -10, 5, 5, 5, 5, 5, 0, -10,
        -10, 0, 5, 0, 0, 0, 0, -10,
        -20, -10, -10, -5, -5, -10, -10, -20,
    ]
    static let kingMid = [
        -30, -40, -40, -50, -50, -40, -40, -30,
        -30, -40, -40, -50, -50, -40, -40, -30,
        -30, -40, -40, -50, -50, -40, -40, -30,
        -30, -40, -40, -50, -50, -40, -40, -30,
        -20, -30, -30, -40, -40, -30, -30, -20,
        -10, -20, -20, -20, -20, -20, -20, -10,
        20, 20, 0, 0, 0, 0, 20, 20,
        20, 30, 10, 0, 0, 10, 30, 20,
    ]
    static let kingEnd = [
        -50, -40, -30, -20, -20, -30, -40, -50,
        -30, -20, -10, 0, 0, -10, -20, -30,
        -30, -10, 20, 30, 30, 20, -10, -30,
        -30, -10, 30, 40, 40, 30, -10, -30,
        -30, -10, 30, 40, 40, 30, -10, -30,
        -30, -10, 20, 30, 30, 20, -10, -30,
        -30, -30, 0, 0, 0, 0, -30, -30,
        -50, -30, -30, -30, -30, -30, -30, -50,
    ]
}
