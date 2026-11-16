import Foundation

enum AILevel: Sendable {
    case easy, normal, hard
}

/// 基于棋型打分的五子棋 AI。
/// 简单：经常"走神"；普通：贪心最佳点；困难：在贪心基础上向后看三步（negamax + alpha-beta）。
enum GomokuAI {
    // 棋型分数
    private static let five       = 1_000_000
    private static let openFour   = 100_000
    private static let four       = 12_000
    private static let openThree  = 6_000
    private static let splitThree = 4_000
    private static let closedThree = 600
    private static let openTwo    = 400
    private static let closedTwo  = 60
    private static let single     = 10

    static func bestMove(board: Board, color: Stone, level: AILevel) -> Point {
        if board.isEmpty { return Board.center }

        var scored = scoredCandidates(board, color)
        guard let top = scored.first else { return Board.center }

        // 自己能直接赢就赢
        if attack(board, top.point, color) >= five { return top.point }

        switch level {
        case .easy:
            // 小兔：45% 的时候随便在前几个好点里挑一个，所以会漏掉防守
            if Double.random(in: 0..<1) < 0.45 {
                return scored.prefix(6).randomElement()!.point
            }
            return top.point

        case .normal:
            let threshold = Double(top.score) * 0.92
            return scored.prefix { Double($0.score) >= threshold }.randomElement()!.point

        case .hard:
            // 对方下一步能连五，必须堵
            if let block = scored.first(where: { attack(board, $0.point, color.opponent) >= five }) {
                return block.point
            }
            scored = Array(scored.prefix(12))
            var b = board
            var bestPoint = top.point
            var bestValue = Int.min
            var alpha = -Int.max
            for cand in scored {
                b[cand.point] = color
                let v = -negamax(&b, side: color.opponent, depth: 4, alpha: -Int.max, beta: -alpha)
                b[cand.point] = nil
                if v > bestValue { bestValue = v; bestPoint = cand.point }
                alpha = max(alpha, v)
            }
            return bestPoint
        }
    }

    /// 对方（color）落在哪些点上就能直接连成五个。用来提醒小朋友"小心！"
    static func winningPoints(board: Board, color: Stone) -> [Point] {
        candidates(board).filter { attack(board, $0, color) >= five }
    }

    // MARK: - 搜索

    private static func negamax(_ b: inout Board, side: Stone, depth: Int, alpha: Int, beta: Int) -> Int {
        if depth == 0 { return staticEval(b, side: side) }
        var alpha = alpha
        var best = -Int.max
        for cand in scoredCandidates(b, side).prefix(depth >= 3 ? 9 : 7) {
            b[cand.point] = side
            let v: Int
            if b.winningLine(at: cand.point) != nil {
                v = 50_000_000 + depth
            } else {
                v = -negamax(&b, side: side.opponent, depth: depth - 1, alpha: -beta, beta: -alpha)
            }
            b[cand.point] = nil
            best = max(best, v)
            alpha = max(alpha, v)
            if alpha >= beta { break }
        }
        return best == -Int.max ? 0 : best
    }

    /// 站在 side（轮到它走）的角度评估局面。
    private static func staticEval(_ b: Board, side: Stone) -> Int {
        let pts = candidates(b)
        func top3(_ c: Stone) -> Int {
            var a = 0, b2 = 0, c3 = 0
            for p in pts {
                let s = attack(b, p, c)
                if s > a { c3 = b2; b2 = a; a = s } else if s > b2 { c3 = b2; b2 = s } else if s > c3 { c3 = s }
            }
            return a + b2 / 2 + c3 / 4
        }
        let mine = top3(side), theirs = top3(side.opponent)
        if mine >= five { return 40_000_000 }
        return mine * 12 / 10 - theirs
    }

    // MARK: - 打分

    private struct Scored { let point: Point; let score: Int }

    private static func scoredCandidates(_ b: Board, _ color: Stone) -> [Scored] {
        candidates(b).map { p in
            let atk = attack(b, p, color)
            let def = attack(b, p, color.opponent)
            let centerBias = 7 - max(abs(p.x - 7), abs(p.y - 7))
            return Scored(point: p, score: atk * 11 / 10 + def + centerBias)
        }
        .sorted { $0.score > $1.score }
    }

    /// 已有棋子周围 2 格内的空点。
    private static func candidates(_ b: Board) -> [Point] {
        let n = Board.size
        var mark = [Bool](repeating: false, count: n * n)
        var out: [Point] = []
        for y in 0..<n {
            for x in 0..<n where b[x, y] != nil {
                for dy in -2...2 {
                    for dx in -2...2 {
                        let nx = x + dx, ny = y + dy
                        guard Board.inside(nx, ny), b[nx, ny] == nil, !mark[ny * n + nx] else { continue }
                        mark[ny * n + nx] = true
                        out.append(Point(x: nx, y: ny))
                    }
                }
            }
        }
        return out
    }

    /// 假设 color 下在 p，四个方向上形成的棋型总分。
    private static func attack(_ b: Board, _ p: Point, _ color: Stone) -> Int {
        var total = 0
        for (dx, dy) in Board.directions {
            total += lineScore(b, p, dx, dy, color)
        }
        return total
    }

    private enum Cell { case mine, empty, blocked }

    private static func lineScore(_ b: Board, _ p: Point, _ dx: Int, _ dy: Int, _ color: Stone) -> Int {
        func cell(_ k: Int) -> Cell {
            let x = p.x + dx * k, y = p.y + dy * k
            guard Board.inside(x, y) else { return .blocked }
            guard let s = b[x, y] else { return .empty }
            return s == color ? .mine : .blocked
        }

        /// 沿 sign 方向扫描：连续己方子数、端点是否空、空位后面的己方子数、那之后是否空、端点后一格是否空
        func scan(_ sign: Int) -> (run: Int, open: Bool, gap: Int, gapOpen: Bool, far: Bool) {
            var i = 1
            while cell(sign * i) == .mine { i += 1 }
            let run = i - 1
            let open = cell(sign * i) == .empty
            var gap = 0, gapOpen = false, far = false
            if open {
                var j = i + 1
                while cell(sign * j) == .mine { gap += 1; j += 1 }
                gapOpen = cell(sign * j) == .empty
                far = gap == 0 && cell(sign * (i + 1)) == .empty
            }
            return (run, open, gap, gapOpen, far)
        }

        let f = scan(1), r = scan(-1)
        let count = 1 + f.run + r.run
        let opens = (f.open ? 1 : 0) + (r.open ? 1 : 0)

        if count >= 5 { return five }

        switch count {
        case 4:
            return opens == 2 ? openFour : (opens == 1 ? four : 0)
        case 3:
            if f.gap >= 1 || r.gap >= 1 { return four }          // ●●●_●
            if opens == 2 { return (f.far || r.far) ? openThree : closedThree * 2 }
            return opens == 1 ? closedThree : 0
        case 2:
            if f.gap >= 2 || r.gap >= 2 { return four }          // ●●_●●
            var best = 0
            if f.gap == 1 { best = max(best, (r.open && f.gapOpen) ? splitThree : closedThree) }  // ●●_●
            if r.gap == 1 { best = max(best, (f.open && r.gapOpen) ? splitThree : closedThree) }
            if best > 0 { return best }
            return opens == 2 ? openTwo : (opens == 1 ? closedTwo : 0)
        default: // 1
            if f.gap >= 3 || r.gap >= 3 { return four }          // ●_●●●
            var best = 0
            if f.gap == 2 { best = max(best, (r.open && f.gapOpen) ? splitThree : closedThree) }
            if r.gap == 2 { best = max(best, (f.open && r.gapOpen) ? splitThree : closedThree) }
            if best > 0 { return best }
            if f.gap == 1 || r.gap == 1 { return opens == 2 ? openTwo / 2 : closedTwo }
            return opens == 2 ? single : 0
        }
    }
}
