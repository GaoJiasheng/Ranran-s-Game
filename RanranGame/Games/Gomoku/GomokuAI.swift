import Foundation

/// 一档难度对应的电脑"性格"。数值越往后越强。
struct AIProfile: Sendable {
    /// 自己能连五时，有多大概率看见
    var takeWin: Double = 1
    /// 对方能连五时，有多大概率去堵
    var blockFive: Double = 1
    /// 有多大概率"走神"，在前几个好点里随便挑一个
    var blunder: Double = 0
    var poolSize = 1
    /// 在分数不低于最好点 tolerance 倍的点里随机挑
    var tolerance: Double = 1
    /// 向后看几步（0 = 不搜索，只凭棋型打分）
    var depth = 0
    var rootWidth = 12
    var innerWidth = 9
    /// 会不会算"连续冲四"的杀棋
    var vcf = false

    static func level(_ n: Int) -> AIProfile {
        switch n {
        case ...1: AIProfile(takeWin: 0.5, blockFive: 0.35, blunder: 0.7, poolSize: 8, tolerance: 0.55)
        case 2:    AIProfile(takeWin: 0.7, blockFive: 0.55, blunder: 0.55, poolSize: 7, tolerance: 0.65)
        case 3:    AIProfile(takeWin: 0.85, blockFive: 0.75, blunder: 0.42, poolSize: 6, tolerance: 0.75)
        case 4:    AIProfile(takeWin: 1, blockFive: 0.92, blunder: 0.3, poolSize: 5, tolerance: 0.82)
        case 5:    AIProfile(blunder: 0.18, poolSize: 4, tolerance: 0.88)
        case 6:    AIProfile(blunder: 0.06, poolSize: 3, tolerance: 0.94)
        case 7:    AIProfile(depth: 2, rootWidth: 10, innerWidth: 7)
        case 8:    AIProfile(depth: 3, rootWidth: 11, innerWidth: 8)
        case 9:    AIProfile(depth: 4, rootWidth: 12, innerWidth: 9)
        default:   AIProfile(depth: 6, rootWidth: 12, innerWidth: 8, vcf: true)
        }
    }
}

/// 基于棋型打分的五子棋 AI，十档难度共用一套引擎：
/// 低档靠"走神"和"看漏"变弱；中档贪心；高档用 negamax + alpha-beta 往后看；最高档再加连续冲四（VCF）杀棋。
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

    static func bestMove(board: Board, color: Stone, level: Int) -> Point {
        bestMove(board: board, color: color, profile: .level(level))
    }

    static func bestMove(board: Board, color: Stone, profile: AIProfile) -> Point {
        if board.isEmpty { return Board.center }

        let scored = scoredCandidates(board, color, jitter: true)
        guard let top = scored.first else { return Board.center }

        func chance(_ p: Double) -> Bool { p >= 1 || Double.random(in: 0..<1) < p }

        // 1. 自己能直接赢
        let wins = scored.filter { attack(board, $0.point, color) >= five }
        let seesWin = !wins.isEmpty && chance(profile.takeWin)
        if seesWin { return wins[0].point }

        // 2. 对方下一步能连五，必须堵
        let blocks = scored.filter { attack(board, $0.point, color.opponent) >= five }
        let seesBlock = !blocks.isEmpty && chance(profile.blockFive)
        if seesBlock { return blocks[0].point }

        // 低档"看漏了"的点，从候选里拿掉，免得碰巧又选中
        var pool = scored
        if !wins.isEmpty { pool.removeAll { w in wins.contains { $0.point == w.point } } }
        if !blocks.isEmpty { pool.removeAll { b in blocks.contains { $0.point == b.point } } }
        if pool.isEmpty { pool = scored }

        // 3. 连续冲四杀棋
        if profile.vcf, blocks.isEmpty {
            var budget = 6_000
            if let p = vcf(board, color, depth: 12, budget: &budget) { return p }
        }

        // 4. 往后看几步
        if profile.depth > 0 {
            return search(board, color, pool: pool, profile: profile) ?? top.point
        }

        // 5. 凭感觉
        if chance(profile.blunder) {
            return pool.prefix(profile.poolSize).randomElement()!.point
        }
        let best = pool[0].score
        let threshold = Double(best) * profile.tolerance
        return pool.prefix { Double($0.score) >= threshold }.randomElement()!.point
    }

    private static func search(_ board: Board, _ color: Stone, pool: [Scored], profile: AIProfile) -> Point? {
        var b = board
        var bestPoint: Point?
        var bestValue = Int.min
        var alpha = -Int.max
        for cand in pool.prefix(profile.rootWidth) {
            b[cand.point] = color
            let v = -negamax(&b, side: color.opponent, depth: profile.depth, width: profile.innerWidth,
                             alpha: -Int.max, beta: -alpha)
            b[cand.point] = nil
            if v > bestValue { bestValue = v; bestPoint = cand.point }
            alpha = max(alpha, v)
        }
        return bestPoint
    }

    // MARK: - 连续冲四（VCF）

    /// 找一步能靠连续冲四一路逼到连五的棋。找不到返回 nil。
    private static func vcf(_ board: Board, _ color: Stone, depth: Int, budget: inout Int) -> Point? {
        guard depth > 0 else { return nil }
        var b = board
        for p in candidates(b) where attack(b, p, color) >= four {
            budget -= 1
            if budget <= 0 { return nil }
            b[p] = color
            if b.winningLine(at: p) != nil { return p }
            let threats = fivePoints(b, around: p, color)
            defer { b[p] = nil }
            if threats.count >= 2 { return p }
            guard let d = threats.first else { continue }
            // 对方只能堵这一个点；堵完要是对方自己冲出了四，这条线就不算
            b[d] = color.opponent
            let counter = !fivePoints(b, around: d, color.opponent).isEmpty
            let ok = !counter && vcf(b, color, depth: depth - 1, budget: &budget) != nil
            b[d] = nil
            if ok { return p }
        }
        return nil
    }

    /// 穿过 p 的四条线上，color 再下一子就能连五的空点。
    private static func fivePoints(_ b: Board, around p: Point, _ color: Stone) -> [Point] {
        var out: [Point] = []
        for (dx, dy) in Board.directions {
            for k in -4...4 where k != 0 {
                let q = Point(x: p.x + dx * k, y: p.y + dy * k)
                guard Board.inside(q.x, q.y), b[q] == nil, !out.contains(q) else { continue }
                var run = 1
                var x = q.x + dx, y = q.y + dy
                while Board.inside(x, y), b[x, y] == color { run += 1; x += dx; y += dy }
                x = q.x - dx; y = q.y - dy
                while Board.inside(x, y), b[x, y] == color { run += 1; x -= dx; y -= dy }
                if run >= 5 { out.append(q) }
            }
        }
        return out
    }

    /// 对方（color）落在哪些点上就能直接连成五个。用来提醒小朋友"小心！"
    static func winningPoints(board: Board, color: Stone) -> [Point] {
        candidates(board).filter { attack(board, $0, color) >= five }
    }

    // MARK: - 搜索

    private static func negamax(_ b: inout Board, side: Stone, depth: Int, width: Int, alpha: Int, beta: Int) -> Int {
        if depth == 0 { return staticEval(b, side: side) }
        var alpha = alpha
        var best = -Int.max
        for cand in scoredCandidates(b, side).prefix(depth >= 3 ? width : width - 2) {
            b[cand.point] = side
            let v: Int
            if b.winningLine(at: cand.point) != nil {
                v = 50_000_000 + depth
            } else {
                v = -negamax(&b, side: side.opponent, depth: depth - 1, width: width, alpha: -beta, beta: -alpha)
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

    private struct Scored { let point: Point; let score: Int; var tie = 0 }

    /// jitter：同分的点随机排序，这样电脑每局下法不会一模一样。
    private static func scoredCandidates(_ b: Board, _ color: Stone, jitter: Bool = false) -> [Scored] {
        candidates(b).map { p in
            let atk = attack(b, p, color)
            let def = attack(b, p, color.opponent)
            let centerBias = 7 - max(abs(p.x - 7), abs(p.y - 7))
            return Scored(point: p, score: atk * 11 / 10 + def + centerBias, tie: jitter ? Int.random(in: 0..<1000) : 0)
        }
        .sorted { $0.score != $1.score ? $0.score > $1.score : $0.tie > $1.tie }
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

// MARK: - 复盘分析

/// 对一步棋的点评。
struct MoveReview: Sendable, Hashable {
    enum Kind: Sendable, Hashable {
        /// 连成五子
        case win
        /// 形成活四 / 四三 / 双活三
        case brilliant
        /// 和电脑推荐的一样
        case best
        case good
        /// 被迫防守（堵住了对方的连五）
        case forced
        /// 疑问手：有明显更好的下法
        case inaccuracy
        /// 失误：让局面变差很多，或者没堵住对方的连五
        case mistake
        /// 错过了能赢的棋
        case missedWin
    }

    let index: Int
    let color: Stone
    let played: Point
    /// 电脑推荐的下法（和实际下的不同、并且值得提醒时才有）
    let suggestion: Point?
    /// 下完这一步后黑棋的优势，-1（白棋大优）… 1（黑棋大优）
    let advantage: Double
    let kind: Kind
    let note: String

    var isBad: Bool { kind == .inaccuracy || kind == .mistake || kind == .missedWin }
}

extension GomokuAI {
    /// 把一整盘棋逐手点评。每手几毫秒到十几毫秒，请放在后台调用。
    static func review(moves: [Point], progress: ((Int) -> Void)? = nil) -> [MoveReview] {
        var board = Board()
        var out: [MoveReview] = []
        for (i, p) in moves.enumerated() {
            let color: Stone = i % 2 == 0 ? .black : .white
            var r = reviewMove(board: board, color: color, played: p, index: i)
            board[p] = color
            r = r.with(advantage: blackAdvantage(&board, lastMove: p, lastColor: color))
            out.append(r)
            progress?(i + 1)
        }
        // 一方做出威胁、另一方马上挡住，数值会一上一下；相邻两手取平均，曲线更好读
        let raw = out.map(\.advantage)
        for i in out.indices where i > 0 && abs(raw[i]) < 0.95 {
            out[i] = out[i].with(advantage: (raw[i] + raw[i - 1]) / 2)
        }
        return out
    }

    /// 局面里黑棋的优势（-1…1）：比较双方手里的进攻潜力；谁有必胜的连续冲四就直接判定。
    static func blackAdvantage(_ board: inout Board, lastMove: Point, lastColor: Stone) -> Double {
        if board.winningLine(at: lastMove) != nil { return lastColor == .black ? 1 : -1 }
        let toMove = lastColor.opponent
        func sign(_ c: Stone) -> Double { c == .black ? 1 : -1 }
        let pts = candidates(board)
        // 轮到的一方能直接连五
        if pts.contains(where: { attack(board, $0, toMove) >= five }) { return sign(toMove) }
        // 刚下完的一方有两个连五点，挡不住
        if pts.filter({ attack(board, $0, lastColor) >= five }).count >= 2 { return sign(lastColor) }
        var budget = 2_000
        if fivePointsAll(board, lastColor).isEmpty, vcf(board, toMove, depth: 8, budget: &budget) != nil {
            return sign(toMove) * 0.95
        }
        func potential(_ c: Stone) -> Double {
            var a = 0, b = 0, d = 0
            for p in pts {
                let s = min(attack(board, p, c), openFour)
                if s > a { d = b; b = a; a = s } else if s > b { d = b; b = s } else if s > d { d = s }
            }
            return Double(a) + Double(b) / 2 + Double(d) / 4
        }
        let e = potential(.black) - potential(.white) + sign(toMove) * 3_000
        return tanh(e / 160_000)
    }

    private static func fivePointsAll(_ b: Board, _ c: Stone) -> [Point] {
        candidates(b).filter { attack(b, $0, c) >= five }
    }

    /// 站在 color 的角度，下在 p 之后局面有多好（往后看两步）
    private static func value(after p: Point, on board: inout Board, _ color: Stone) -> Int {
        board[p] = color
        defer { board[p] = nil }
        if board.winningLine(at: p) != nil { return 50_000_000 }
        return -negamax(&board, side: color.opponent, depth: 2, width: 8, alpha: -Int.max, beta: Int.max)
    }

    private static func maxAttack(_ b: Board, _ color: Stone) -> (point: Point?, score: Int) {
        var best: (Point?, Int) = (nil, 0)
        for p in candidates(b) {
            let s = attack(b, p, color)
            if s > best.1 { best = (p, s) }
        }
        return best
    }

    static func reviewMove(board: Board, color: Stone, played: Point, index: Int) -> MoveReview {
        func make(_ kind: MoveReview.Kind, _ note: String, suggestion: Point? = nil) -> MoveReview {
            MoveReview(index: index, color: color, played: played, suggestion: suggestion,
                       advantage: 0, kind: kind, note: note)
        }

        if board.isEmpty { return make(.good, "第一手下在中间附近，是很好的开局") }

        // 1. 自己能直接连五
        let wins = candidates(board).filter { attack(board, $0, color) >= five }
        if wins.contains(played) { return make(.win, "连成五个，赢啦！") }
        if let w = wins.first { return make(.missedWin, "这里本来能直接连成五个赢的！", suggestion: w) }

        // 2. 对方下一步能连五
        let blocks = candidates(board).filter { attack(board, $0, color.opponent) >= five }
        if !blocks.isEmpty {
            if blocks.contains(played) {
                return blocks.count > 1
                    ? make(.forced, "对方有两个地方能连五，已经挡不住了")
                    : make(.forced, "及时堵住了对方的连五，必须这么下")
            }
            return make(.mistake, "对方只差一个就连成五了，要先堵住这里", suggestion: blocks[0])
        }

        // 3. 错过了一套连续冲四的杀棋
        var budget = 3_000
        if let kill = vcf(board, color, depth: 10, budget: &budget), kill != played,
           attack(board, played, color) < four {
            return make(.missedWin, "这里有一套连续冲四的杀棋，可以一路逼到赢", suggestion: kill)
        }

        // 4. 自己下出的棋形
        let shape = attack(board, played, color)
        if shape >= openFour { return make(.brilliant, "妙手！做出了「活四」，对方挡不住了") }
        if shape >= four * 2 { return make(.brilliant, "妙手！一下冲出两个四") }
        if shape >= four + openThree { return make(.brilliant, "妙手！冲四的同时还活三") }

        // 5. 对方有活三（下一步能变活四）
        let threat = maxAttack(board, color.opponent)
        if threat.score >= openFour {
            if shape >= four { return make(.good, "冲四抢先手，对方只能先挡") }
            var after = board
            after[played] = color
            if maxAttack(after, color.opponent).score >= openFour {
                let defend = scoredCandidates(board, color).first?.point ?? threat.point
                return make(.mistake, "对方有「活三」，不挡住下一步就变活四了", suggestion: defend)
            }
            return make(.good, "挡住了对方的活三")
        }

        if shape >= openThree * 2 && shape < four { return make(.brilliant, "妙手！一下做出两个活三") }

        // 6. 和推荐的几个点比一比
        var b = board
        let pool = scoredCandidates(board, color).prefix(10).map(\.point)
        var bestPoint = played
        var bestValue = Int.min
        for p in pool {
            let v = value(after: p, on: &b, color)
            if v > bestValue { bestValue = v; bestPoint = p }
        }
        let playedValue = bestPoint == played ? bestValue : value(after: played, on: &b, color)
        if playedValue >= bestValue { return make(.best, shape >= openThree ? "做出了「活三」，和电脑想的一样！" : "和电脑想的一样，好棋！") }
        // 错过了一个实打实的强招（自己的棋形明显差很多）
        let bestShape = attack(board, bestPoint, color)
        if bestShape >= openThree * 2 && shape < openThree && bestValue - playedValue > 20_000 {
            let what = bestShape >= openFour ? "活四" : (bestShape >= four + openThree ? "冲四活三" : "两个活三")
            return make(.inaccuracy, "这里能做出「\(what)」，进攻更厉害", suggestion: bestPoint)
        }
        if bestValue - playedValue > 40_000 {
            return make(.inaccuracy, "有更好的下法，可以看看发光的位置", suggestion: bestPoint)
        }
        if shape >= openThree { return make(.good, "做出了「活三」，很有威胁") }
        return make(.good, "不错的一步")
    }
}

extension MoveReview {
    func with(advantage: Double) -> MoveReview {
        MoveReview(index: index, color: color, played: played, suggestion: suggestion,
                   advantage: advantage, kind: kind, note: note)
    }
}
