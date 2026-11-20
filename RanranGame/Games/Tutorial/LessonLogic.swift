import Foundation

// 教学题的判断：只认规则上真正对的答案，而不是只认一个格子。界面和测试共用这一份。

// MARK: - 五子棋

/// 教学用的小棋盘（默认 9 路）。坐标写法 "c3"：第 c 列、从上往下第 3 行。
struct GLessonBoard: Hashable {
    let size: Int
    private(set) var cells: [Stone?]

    init(size: Int) {
        self.size = size
        cells = Array(repeating: nil, count: size * size)
    }

    /// "size=9;b=c3,d4;w=e5"
    init?(spec: String) {
        var size = 9
        var black: [String] = [], white: [String] = []
        for part in spec.split(separator: ";") {
            let kv = part.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            guard kv.count == 2 else { continue }
            let list = kv[1].split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            switch kv[0] {
            case "size": size = Int(kv[1]) ?? 9
            case "b": black = list
            case "w": white = list
            default: break
            }
        }
        self.init(size: size)
        for (names, stone) in [(black, Stone.black), (white, Stone.white)] {
            for n in names {
                guard let p = Self.point(n, size: size), self[p] == nil else { return nil }
                self[p] = stone
            }
        }
    }

    static func point(_ name: String, size: Int) -> Point? {
        guard let first = name.unicodeScalars.first, first.value >= 97, first.value < 97 + UInt32(size),
              let row = Int(name.dropFirst()), row >= 1, row <= size else { return nil }
        return Point(x: Int(first.value) - 97, y: row - 1)
    }

    func name(_ p: Point) -> String { "\(Character(UnicodeScalar(UInt8(97 + p.x))))\(p.y + 1)" }

    func inside(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < size && y < size }

    subscript(p: Point) -> Stone? {
        get { cells[p.y * size + p.x] }
        set { cells[p.y * size + p.x] = newValue }
    }

    var empties: [Point] {
        (0..<size * size).compactMap { cells[$0] == nil ? Point(x: $0 % size, y: $0 / size) : nil }
    }

    var stones: [(Point, Stone)] {
        (0..<size * size).compactMap { i in cells[i].map { (Point(x: i % size, y: i / size), $0) } }
    }

    /// p 上的子连成五个时，返回那一排
    func line(at p: Point) -> [Point]? {
        guard let c = self[p] else { return nil }
        for (dx, dy) in Board.directions {
            var line = [p]
            var x = p.x + dx, y = p.y + dy
            while inside(x, y), self[Point(x: x, y: y)] == c { line.append(Point(x: x, y: y)); x += dx; y += dy }
            x = p.x - dx; y = p.y - dy
            while inside(x, y), self[Point(x: x, y: y)] == c { line.insert(Point(x: x, y: y), at: 0); x -= dx; y -= dy }
            if line.count >= 5 { return line }
        }
        return nil
    }

    func placing(_ p: Point, _ s: Stone) -> GLessonBoard {
        var b = self
        b[p] = s
        return b
    }

    func makesFive(_ p: Point, _ s: Stone) -> Bool {
        self[p] == nil && placing(p, s).line(at: p) != nil
    }

    /// 下一颗就能连成五的空点
    func winningPoints(_ s: Stone) -> [Point] { empties.filter { makesFive($0, s) } }

    /// 黑棋下在 p 之后，靠连续冲四 / 活四在 depth 步内一定能赢（白棋只能一直堵）
    func winsByThreats(_ p: Point, depth: Int) -> Bool {
        guard self[p] == nil, depth >= 1 else { return false }
        if makesFive(p, .black) { return true }
        let b = placing(p, .black)
        // 白棋自己先连五就不算
        if !b.winningPoints(.white).isEmpty { return false }
        let wins = b.winningPoints(.black)
        if wins.count >= 2 { return true }
        guard wins.count == 1, depth > 1 else { return false }
        let after = b.placing(wins[0], .white)
        if after.line(at: wins[0]) != nil { return false }
        return after.empties.contains { after.winsByThreats($0, depth: depth - 1) }
    }

    /// 下在 p 是不是做出了一个活三（再下一颗就能变成活四），而且这个活三离不开 p
    func makesOpenThree(_ p: Point) -> Bool {
        guard self[p] == nil else { return false }
        let b = placing(p, .black)
        guard b.winningPoints(.black).isEmpty else { return false }
        return b.empties.contains { q in
            b.placing(q, .black).winningPoints(.black).count >= 2
                && placing(q, .black).winningPoints(.black).count < 2
        }
    }
}

extension GLessonBoard {
    /// q 上有黑棋时，沿 (dx,dy) 方向连成五个吗
    private func fiveAlong(_ q: Point, _ dx: Int, _ dy: Int) -> Bool {
        var n = 1
        var x = q.x + dx, y = q.y + dy
        while inside(x, y), self[Point(x: x, y: y)] == .black { n += 1; x += dx; y += dy }
        x = q.x - dx; y = q.y - dy
        while inside(x, y), self[Point(x: x, y: y)] == .black { n += 1; x -= dx; y -= dy }
        return n >= 5
    }

    /// 经过 p、沿 (dx,dy) 这一条线上，下一颗就能连成五的空点
    private func fivePoints(through p: Point, _ dx: Int, _ dy: Int) -> [Point] {
        (-8...8).compactMap { k -> Point? in
            let x = p.x + k * dx, y = p.y + k * dy
            guard inside(x, y) else { return nil }
            let q = Point(x: x, y: y)
            return self[q] == nil && placing(q, .black).fiveAlong(q, dx, dy) ? q : nil
        }
    }

    /// 黑棋下在 p 之后，有几条线上多出了一个活三（只算这一条线自己，而且离不开 p）
    func openThreeLines(_ p: Point) -> Int {
        guard self[p] == nil else { return 0 }
        let b = placing(p, .black)
        var n = 0
        for (dx, dy) in Board.directions {
            guard b.fivePoints(through: p, dx, dy).isEmpty else { continue }
            let live = { (bd: GLessonBoard, q: Point) -> Bool in
                (-4...4).contains { k in
                    let x = q.x + k * dx, y = q.y + k * dy
                    guard bd.inside(x, y), bd[Point(x: x, y: y)] == nil else { return false }
                    return bd.placing(Point(x: x, y: y), .black).fivePoints(through: q, dx, dy).count >= 2
                }
            }
            if live(b, p) && !live(self, p) { n += 1 }
        }
        return n
    }

    /// 下在 p 是不是做出了「四」（下一颗就能连五），而且自己这颗还没有连成五、白棋也没有马上赢的点
    func makesFour(_ p: Point) -> Bool {
        guard self[p] == nil, !makesFive(p, .black) else { return false }
        let b = placing(p, .black)
        return !b.winningPoints(.black).isEmpty && b.winningPoints(.white).isEmpty
    }
}

enum GomokuLessonLogic {
    /// 这一手（黑棋下在 p）对不对
    static func check(_ task: TutorialTask, _ p: Point, on b: GLessonBoard) -> Bool {
        if task.type == "pick" {
            return (task.accept ?? []).compactMap { GLessonBoard.point($0, size: b.size) }.contains(p)
        }
        guard b[p] == nil else { return false }
        if let accept = task.accept {
            return accept.compactMap { GLessonBoard.point($0, size: b.size) }.contains(p)
        }
        let rule = task.rule ?? "any"
        if rule == "any" { return true }
        if rule == "five" { return b.makesFive(p, .black) }
        if rule == "block" {
            return b.placing(p, .black).winningPoints(.white).isEmpty
        }
        if rule == "openThree" { return b.makesOpenThree(p) }
        // 冲四（或活四）：这一手做出了「四」，对手必须马上堵
        if rule == "four" { return b.makesFour(p) }
        // 三三：一步同时做出两个活三，而且这一步本身还不是四
        if rule == "doubleThree" {
            return b.openThreeLines(p) >= 2 && !b.makesFour(p) && b.placing(p, .black).winningPoints(.white).isEmpty
        }
        if rule == "stopOpenFour" {
            // 堵完以后，白棋再下一颗也做不出活四（两个连五点）
            let after = b.placing(p, .black)
            return after.winningPoints(.white).isEmpty
                && !after.empties.contains { after.placing($0, .white).winningPoints(.white).count >= 2 }
        }
        if rule.hasPrefix("winIn:"), let n = Int(rule.dropFirst(6)) { return b.winsByThreats(p, depth: n) }
        return false
    }

    /// 所有正确答案（演示答案、自检用）
    static func answers(_ task: TutorialTask, on b: GLessonBoard) -> [Point] {
        if task.type == "pick" || task.accept != nil {
            return (task.accept ?? []).compactMap { GLessonBoard.point($0, size: b.size) }
        }
        return b.empties.filter { check(task, $0, on: b) }
    }

    /// 白棋接着下的点
    static func reply(_ spec: [String], on b: GLessonBoard) -> [Point] {
        var board = b
        var out: [Point] = []
        for s in spec {
            if s == "block" {
                // 堵住黑棋马上能连五的点；没有就不下
                if let p = board.winningPoints(.black).first {
                    out.append(p)
                    board[p] = .white
                }
            } else {
                // "d6|f6"：第一个空着的点
                let options = s.split(separator: "|").compactMap { GLessonBoard.point(String($0), size: b.size) }
                if let p = options.first(where: { board[$0] == nil }) {
                    out.append(p)
                    board[p] = .white
                }
            }
        }
        return out
    }
}

// MARK: - 象棋

enum XiangqiLessonLogic {
    static func value(_ k: XKind) -> Int {
        switch k {
        case .king: 1000
        case .rook: 9
        case .cannon: 5
        case .horse: 4
        case .advisor, .elephant: 2
        case .pawn: 1
        }
    }

    /// 这一步（红方走 m）对不对
    static func check(_ task: TutorialTask, _ m: XMove, on b: XBoard) -> Bool {
        if let piece = task.piece, let sq = XSquare(piece), m.from != sq { return false }
        guard b.legalMoves(from: m.from).contains(m) else { return false }
        if let accept = task.accept {
            return accept.contains { a in
                a.count == 4 ? a == m.iccs : XSquare(a) == m.to
            }
        }
        let rule = task.rule ?? "any"
        switch rule {
        case "any": return true
        case "capture": return b[m.to] != nil
        case "check": return b.gives_check(m)
        case "mate": return b.isMate(after: m)
        case "mate2": return b.isMate(after: m) || b.isMateInTwo(m)
        case "escape": return b.inCheck(b.turn)
        case "escape:king": return b[m.from]?.kind == .king
        case "escape:capture": return b[m.to] != nil && b[m.from]?.kind != .king
        case "escape:block": return b[m.to] == nil && b[m.from]?.kind != .king
        case "bestCapture":
            let best = bestCaptures(b)
            return best.contains(m)
        case "develop":
            // 开局：把还没动过的车、马、炮放出来
            let starts: Set<String> = ["a0", "b0", "h0", "i0", "b2", "h2"]
            guard let k = b[m.from]?.kind, [.rook, .horse, .cannon].contains(k) else { return false }
            // 炮往回退到底线不算出子
            if k == .cannon, m.to.y < 2 { return false }
            return starts.contains(m.from.name) && !isHanging(m, b)
        case "safe":
            // 走完不会马上被对方白白吃掉
            return !isHanging(m, b)
        case "hold":
            // 走完以后，不管对方怎么应，都不会丢子（换子不吃亏也算）
            return gain(m, on: b) >= 0
        default:
            if rule.hasPrefix("gain"), let n = Int(rule.dropFirst(5)) ?? (rule == "gain" ? 2 : nil) {
                // 得子："gain:4" = 走完以后，对方怎么应都挡不住，至少净赚 4 分子力（马 4、炮 5、车 9）
                return gain(m, on: b) >= n
            }
            if rule.hasPrefix("mateIn:") || rule.hasPrefix("winIn:") {
                // 连杀："mateIn:3" = 走完以后，不管对方怎么应，红方 3 步之内（算上这一步）一定将死；
                // "mateIn:3:check" = 而且每一步都要将军（连将杀，比如双车错）；
                // "winIn:3" = 将死或者困毙（让对方无棋可走）都算赢（单兵杀将常常是困毙）
                let parts = rule.split(separator: ":")
                guard parts.count >= 2, let n = Int(parts[1]) else { return false }
                let goal: MateGoal = parts[0] == "winIn" ? .win : parts.count > 2 && parts[2] == "check" ? .checks : .mate
                return matesWithin(m, n, on: b, goal)
            }
            return false
        }
    }

    // MARK: 得子、连杀

    /// 子力：红方减黑方（帅不算）
    static func material(_ b: XBoard) -> Int {
        b.cells.reduce(0) { s, c in
            guard c != 0, let k = XKind(rawValue: abs(c)), k != .king else { return s }
            return s + (c > 0 ? value(k) : -value(k))
        }
    }

    /// 红方走 m 以后能稳稳赚到多少子力：黑方先应一步（任何走法），之后双方把能吃的子吃完
    /// （被将军时什么都可以走）。黑方被将死算赚很多。
    static func gain(_ m: XMove, on b: XBoard) -> Int {
        let after = b.applying(m)
        let red = -materialSearch(after, depth: 1, alpha: -100_000, beta: 100_000, q: 0)
        return red - material(b)
    }

    /// 只数子力的小搜索，返回轮到走的一方看的分数
    static func materialSearch(_ b: XBoard, depth: Int, alpha: Int, beta: Int, q: Int) -> Int {
        let moves = b.legalMoves()
        if moves.isEmpty { return -10_000 }
        let sign = b.turn == .red ? 1 : -1
        let checked = b.inCheck(b.turn)
        var a = alpha
        var candidates = moves
        if depth <= 0 && !checked {
            // 不吃子也可以（站着不动），所以分数至少是现在的子力
            let stand = sign * material(b)
            if stand >= beta || q >= 8 { return stand }
            a = max(a, stand)
            candidates = moves.filter { b[$0.to] != nil }
        } else if depth <= 0 && q >= 8 {
            return sign * material(b)
        }
        candidates.sort { (b[$0.to].map { value($0.kind) } ?? 0) > (b[$1.to].map { value($0.kind) } ?? 0) }
        for mv in candidates {
            let s = -materialSearch(b.applying(mv), depth: depth - 1, alpha: -beta, beta: -a, q: depth <= 0 ? q + 1 : 0)
            if s >= beta { return s }
            a = max(a, s)
        }
        return a
    }

    enum MateGoal { case mate, checks, win }

    /// 红方走 m 以后，黑方怎么应都没用，红方 n 步之内（包括 m）赢下来。
    /// .mate：最后一步要将死；.checks：每一步都要将军；.win：困毙（不将军、对方却无棋可走）也算赢。
    static func matesWithin(_ m: XMove, _ n: Int, on b: XBoard, _ goal: MateGoal = .mate) -> Bool {
        let after = b.applying(m)
        let checking = after.inCheck(after.turn)
        if goal == .checks && !checking { return false }
        let replies = after.legalMoves()
        if replies.isEmpty { return checking || goal == .win }
        guard n > 1 else { return false }
        return replies.allSatisfy { r in
            let b2 = after.applying(r)
            // 先试将军的着法，通常更快找到
            let all = b2.legalMoves()
            let checks = all.filter { b2.gives_check($0) }
            return checks.contains { matesWithin($0, n - 1, on: b2, goal) }
                || (goal != .checks && all.contains { !checks.contains($0) && matesWithin($0, n - 1, on: b2, goal) })
        }
    }

    /// 所有正确着法
    static func answers(_ task: TutorialTask, on b: XBoard) -> [XMove] {
        var moves = b.legalMoves()
        if let piece = task.piece, let sq = XSquare(piece) { moves = moves.filter { $0.from == sq } }
        return moves.filter { check(task, $0, on: b) }
    }

    /// pick 题：点对了没有
    static func checkPick(_ task: TutorialTask, _ s: XSquare) -> Bool {
        (task.accept ?? []).compactMap(XSquare.init).contains(s)
    }

    /// 能吃的子里面，吃完最划算（吃到的减去会被吃回去的）的那些
    static func bestCaptures(_ b: XBoard) -> [XMove] {
        let caps = b.legalMoves().filter { b[$0.to] != nil }
        guard !caps.isEmpty else { return [] }
        func net(_ m: XMove) -> Int {
            let gain = value(b[m.to]!.kind)
            return gain - (isHanging(m, b) ? value(b[m.from]!.kind) : 0)
        }
        let top = caps.map(net).max()!
        return caps.filter { net($0) == top }
    }

    /// 走完以后，走过去的那个子会不会被对方吃掉
    static func isHanging(_ m: XMove, _ b: XBoard) -> Bool {
        let after = b.applying(m)
        return after.legalMoves().contains { $0.to == m.to }
    }

    /// 黑方接着走的棋
    static func reply(_ spec: [String], on b: XBoard) -> [XMove] {
        var board = b
        var out: [XMove] = []
        for s in spec {
            let m: XMove?
            if s == "engine" {
                m = XiangqiAI(profile: .level(8)).bestMove(board)
            } else {
                // "h9g7|b9c7"：第一个能走的
                m = s.split(separator: "|").compactMap { XMove(String($0)) }
                    .first { board.legalMoves(from: $0.from).contains($0) }
            }
            guard let m else { break }
            out.append(m)
            board.make(m)
        }
        return out
    }
}

// MARK: - 围棋

/// 围棋教学题：冉冉执黑。规则里的 P 是棋盘上的一个点，指那颗子所在的整块棋。
enum GoLessonLogic {
    static func point(_ s: String, _ b: GoBoard) -> Int? { b.index(s) }

    static func check(_ task: TutorialTask, _ m: Int, on b: GoBoard) -> Bool {
        if task.type == "pick" || task.type == "pickAll" {
            return (task.accept ?? []).compactMap { b.index($0) }.contains(m)
        }
        guard b.isLegal(m), let after = b.playing(m) else { return false }
        if let accept = task.accept { return accept.compactMap { b.index($0) }.contains(m) }
        let parts = (task.rule ?? "any").split(separator: ":").map(String.init)
        let arg = { (k: Int) in parts.count > k ? b.index(parts[k]) : nil }
        let caught = after.prisoners[0] - b.prisoners[0]
        switch parts[0] {
        case "any":
            return true
        case "capture":
            return caught >= (parts.count > 1 ? Int(parts[1]) ?? 1 : 1)
        case "atari":
            // 叫吃，而且自己这颗不能只剩一口气（不往对方嘴里送）
            return ataris(after).count >= 1 && after.libertyCount(m, limit: 2) >= 2
        case "doubleAtari":
            return ataris(after).count >= 2 && after.libertyCount(m, limit: 2) >= 2
        case "escape":
            // 走完以后，这块黑棋怎么也不会被吃
            guard let p = arg(1) else { return false }
            return after[p] == .black && after.libertyCount(p, limit: 2) >= 2 && !after.canCapture(p, attackerToMove: true)
        case "kill":
            // 走完以后，这块白棋已经被提掉，或者不管白棋怎么逃都会被吃
            guard let p = arg(1) else { return false }
            return after[p] != .white || after.canCapture(p, attackerToMove: false)
        case "chase":
            // 征子追杀：每一步都要叫吃（或者直接提掉），而且一直追得死
            guard let p = arg(1) else { return false }
            if after[p] != .white { return true }
            return after.libertyCount(m, limit: 2) >= 2
                && after.libertyCount(p, limit: 2) == 1 && after.canCapture(p, attackerToMove: false)
        case "netChase":
            // 枷住以后关门：白棋最多两口气，而且跑不掉
            guard let p = arg(1) else { return false }
            if after[p] != .white { return true }
            return after.libertyCount(m, limit: 2) >= 2
                && after.libertyCount(p, limit: 3) <= 2 && after.canCapture(p, attackerToMove: false, wide: true)
        case "net":
            // 枷：要算得更宽（白棋冲出来有三口气时也接着算）
            guard let p = arg(1) else { return false }
            return after[p] != .white || after.canCapture(p, attackerToMove: false, wide: true)
        case "corner":
            // 布局：下在一个还空着的角上（离两边三、四路）
            return isCornerPoint(m, b) && cornerEmpty(m, b)
        case "connect":
            guard let p = arg(1), let q = arg(2) else { return false }
            return after.group(p).stones.contains(q)
        case "dame":
            // 单官：这个空点挨着黑白两边，谁也围不到（下完以后自己这颗子也不会只剩一口气）
            return isDame(m, b) && after.libertyCount(m, limit: 2) >= 2
        case "safe":
            // 不是自己往对方嘴里送
            return after.libertyCount(m, limit: 2) >= 2
        default:
            return false
        }
    }

    static func isCornerPoint(_ m: Int, _ b: GoBoard) -> Bool {
        let s = b.size, x = b.x(m), y = b.y(m)
        let near = { (v: Int) in v == 2 || v == 3 || v == s - 3 || v == s - 4 }
        return near(x) && near(y)
    }

    /// 这个点所在的角还没有任何棋子（大棋盘看靠边 5 路以内；9 路看不含中线的四分之一块）
    static func cornerEmpty(_ m: Int, _ b: GoBoard) -> Bool {
        let s = b.size, left = b.x(m) < s / 2, top = b.y(m) < s / 2, r = s >= 13 ? 5 : s / 2
        for i in b.cells.indices where b.cells[i] != 0 {
            let x = b.x(i), y = b.y(i)
            let inX = left ? x < r : x >= s - r, inY = top ? y < r : y >= s - r
            if inX && inY { return false }
        }
        return true
    }

    /// 单官：m 所在的那片空地，同时挨着黑子和白子
    static func isDame(_ m: Int, _ b: GoBoard) -> Bool {
        guard b.cells[m] == 0 else { return false }
        var region = [m], seen: Set<Int> = [m], border = Set<Int8>()
        var k = 0
        while k < region.count {
            for n in b.neighbors(region[k]) {
                if b.cells[n] == 0 { if seen.insert(n).inserted { region.append(n) } } else { border.insert(b.cells[n]) }
            }
            k += 1
        }
        return border.count == 2
    }

    /// 只剩一口气的白棋块（每块取一颗代表）
    static func ataris(_ b: GoBoard) -> [Int] {
        var seen = Set<Int>(), out: [Int] = []
        for i in b.cells.indices where b.cells[i] == GoStone.white.rawValue && !seen.contains(i) {
            let g = b.group(i)
            seen.formUnion(g.stones)
            if g.liberties.count == 1 { out.append(i) }
        }
        return out
    }

    static func answers(_ task: TutorialTask, on b: GoBoard) -> [Int] {
        if task.type == "pick" || task.type == "pickAll" {
            return (task.accept ?? []).compactMap { b.index($0) }
        }
        if task.accept != nil {
            return (task.accept ?? []).compactMap { b.index($0) }.filter { b.isLegal($0) }
        }
        return b.cells.indices.filter { check(task, $0, on: b) }
    }

    /// 白棋接着下："e5"、"d6|f6"（第一个能下的）、"escape:P"（救 P 这块）、"capture:P"（提掉 P 这块黑棋）、"pass"
    static func reply(_ spec: [String], on start: GoBoard) -> [Int?] {
        var b = start
        var out: [Int?] = []
        for s in spec {
            let parts = s.split(separator: ":").map(String.init)
            var m: Int?
            switch parts[0] {
            case "pass":
                b.pass(); out.append(nil); continue
            case "escape":
                if let p = b.index(parts[1]) { m = b.rescueMoves(p).first { b.isLegal($0) } }
            case "extend":
                // 只往外长（不吃子），挑长完以后气最多的那一点：征子、枷的标准逃法
                if let p = b.index(parts[1]), b[p] != nil {
                    m = b.group(p).liberties.compactMap { l in b.playing(l).map { (l, $0.libertyCount(p, limit: 9)) } }
                        .max { $0.1 < $1.1 }?.0
                }
            case "capture":
                if let p = b.index(parts[1]), b[p] != nil {
                    m = b.group(p).liberties.first { b.libertyCount(p, limit: 2) == 1 && b.isLegal($0) }
                }
            default:
                m = s.split(separator: "|").compactMap { b.index(String($0)) }.first { b.isLegal($0) }
            }
            guard let mv = m else { break }
            b.play(mv)
            out.append(mv)
        }
        return out
    }
}
