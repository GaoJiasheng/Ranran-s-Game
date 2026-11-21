import Foundation

// 华容道的盘面、走法和最少步数（只用 Foundation，命令行测试和关卡生成工具也编译它）。
//
// 木盘 4 格宽、5 格高。木块四种：
//   B 小兔（2×2）  V 竖块（1 宽 2 高）  H 横块（2 宽 1 高）  S 小方块（1×1）
// 出口在最下面一排的正中间：小兔的左上角走到第 1 列第 3 行（从 0 数），就能从出口出去。
//
// 「一步」的定义（计步、最少步数、提示、星星全都用这一条）：
//   把一块木块沿着一个方向直直地滑过 1 格、2 格或 3 格，只要路上的格子都是空的，就算一步。
//   不能拐弯：同一块木块先往右再往下，是两步。
// 盘面的写法（layout）：5 行，每行 4 个字母，行与行之间用 / 隔开，. 是空格，例如
//   "VBBV/VBBV/VHHV/VSSV/S..S"（横刀立马）。

enum KlotskiKind: Int, Hashable {
    case big = 1, tall, wide, small

    /// 占几格宽、几格高
    var w: Int { self == .big || self == .wide ? 2 : 1 }
    var h: Int { self == .big || self == .tall ? 2 : 1 }

    var letter: Character {
        switch self {
        case .big: "B"
        case .tall: "V"
        case .wide: "H"
        case .small: "S"
        }
    }

    init?(letter: Character) {
        switch letter {
        case "B": self = .big
        case "V": self = .tall
        case "H": self = .wide
        case "S": self = .small
        default: return nil
        }
    }
}

struct KlotskiPiece: Hashable {
    var kind: KlotskiKind
    /// 左上角
    var x: Int
    var y: Int
}

enum KlotskiDir: Int, CaseIterable, Hashable {
    case up, down, left, right

    var dx: Int { self == .left ? -1 : self == .right ? 1 : 0 }
    var dy: Int { self == .up ? -1 : self == .down ? 1 : 0 }
    var letter: Character { ["u", "d", "l", "r"][rawValue] }
    var opposite: KlotskiDir { [.down, .up, .right, .left][rawValue] }
    var mirrored: KlotskiDir { self == .left ? .right : self == .right ? .left : self }

    init?(letter: Character) {
        guard let d = Self.allCases.first(where: { $0.letter == letter }) else { return nil }
        self = d
    }
}

/// 一步：第 piece 块木块（盘面里的序号）朝 dir 滑 dist 格
struct KlotskiMove: Hashable {
    var piece: Int
    var dir: KlotskiDir
    var dist: Int

    var dx: Int { dir.dx * dist }
    var dy: Int { dir.dy * dist }
}

struct KlotskiBoard: Hashable {
    static let cols = 4
    static let rows = 5
    /// 小兔左上角走到这里就能出去
    static let goal = (x: 1, y: 3)

    /// 木块在数组里的序号一直不变（动画、颜色、悔棋都靠它）；找最少步数时才按位置重新排
    var pieces: [KlotskiPiece]

    init(pieces: [KlotskiPiece]) { self.pieces = pieces }

    /// 从盘面字符串读；格式不对、木块摆不下就是 nil
    init?(layout: String) {
        let rows = layout.split(separator: "/", omittingEmptySubsequences: false).map(Array.init)
        guard rows.count == Self.rows, rows.allSatisfy({ $0.count == Self.cols }) else { return nil }
        var used = Array(repeating: false, count: Self.cols * Self.rows)
        var out: [KlotskiPiece] = []
        for y in 0..<Self.rows {
            for x in 0..<Self.cols where !used[y * Self.cols + x] {
                let c = rows[y][x]
                if c == "." { continue }
                guard let kind = KlotskiKind(letter: c) else { return nil }
                guard x + kind.w <= Self.cols, y + kind.h <= Self.rows else { return nil }
                for dy in 0..<kind.h {
                    for dx in 0..<kind.w {
                        guard rows[y + dy][x + dx] == c, !used[(y + dy) * Self.cols + x + dx] else { return nil }
                        used[(y + dy) * Self.cols + x + dx] = true
                    }
                }
                out.append(KlotskiPiece(kind: kind, x: x, y: y))
            }
        }
        pieces = out
    }

    /// 字母盘面（和 init(layout:) 互逆）
    var layout: String {
        var g = Array(repeating: Array(repeating: Character("."), count: Self.cols), count: Self.rows)
        for p in pieces {
            for dy in 0..<p.kind.h { for dx in 0..<p.kind.w { g[p.y + dy][p.x + dx] = p.kind.letter } }
        }
        return g.map { String($0) }.joined(separator: "/")
    }

    // MARK: 格子

    /// 每一格有没有被占（第 y 行第 x 列是第 y*4+x 位）
        var occupancy: UInt32 { pieces.reduce(0) { $0 | Self.mask($1) } }

        static func mask(_ p: KlotskiPiece) -> UInt32 { mask(p.kind, p.x, p.y) }

        static func mask(_ k: KlotskiKind, _ x: Int, _ y: Int) -> UInt32 {
        var m: UInt32 = 0
        for dy in 0..<k.h { for dx in 0..<k.w { m |= 1 << UInt32((y + dy) * cols + x + dx) } }
        return m
    }

    func pieceAt(x: Int, y: Int) -> Int? {
        pieces.firstIndex { x >= $0.x && x < $0.x + $0.kind.w && y >= $0.y && y < $0.y + $0.kind.h }
    }

    func isEmpty(x: Int, y: Int) -> Bool { pieceAt(x: x, y: y) == nil }

    var emptyCells: [(x: Int, y: Int)] {
        (0..<Self.rows).flatMap { y in (0..<Self.cols).compactMap { x in isEmpty(x: x, y: y) ? (x, y) : nil } }
    }

    /// 小兔是第几块；盘面里没有小兔就是 nil
    var bunny: Int? { pieces.firstIndex { $0.kind == .big } }

    /// 小兔到出口了
    var solved: Bool {
        guard let b = bunny else { return false }
        return pieces[b].x == Self.goal.x && pieces[b].y == Self.goal.y
    }

    /// 左右镜像（出口在正中间，所以镜像以后规则一模一样）。木块的序号不变。
    var mirrored: KlotskiBoard {
        KlotskiBoard(pieces: pieces.map { KlotskiPiece(kind: $0.kind, x: Self.cols - $0.kind.w - $0.x, y: $0.y) })
    }

    // MARK: 走法

    /// 这块木块朝这个方向最多能滑几格
        func maxSlide(_ piece: Int, _ dir: KlotskiDir) -> Int {
        Self.maxSlide(pieces[piece], dir, occupied: occupancy & ~Self.mask(pieces[piece]))
    }

        static func maxSlide(_ p: KlotskiPiece, _ dir: KlotskiDir, occupied: UInt32) -> Int {
        var n = 0
        while true {
            let nx = p.x + dir.dx * (n + 1), ny = p.y + dir.dy * (n + 1)
            if nx < 0 || ny < 0 || nx + p.kind.w > cols || ny + p.kind.h > rows { break }
            if mask(p.kind, nx, ny) & occupied != 0 { break }
            n += 1
        }
        return n
    }

    /// 这块木块所有能走的步（每个方向滑 1 格、2 格……都是不同的一步）
        func moves(of piece: Int) -> [KlotskiMove] {
        let occ = occupancy & ~Self.mask(pieces[piece])
        var out: [KlotskiMove] = []
        for d in KlotskiDir.allCases {
            let n = Self.maxSlide(pieces[piece], d, occupied: occ)
            if n > 0 { for k in 1...n { out.append(KlotskiMove(piece: piece, dir: d, dist: k)) } }
        }
        return out
    }

        var allMoves: [KlotskiMove] { pieces.indices.flatMap { moves(of: $0) } }

        func canApply(_ m: KlotskiMove) -> Bool {
        guard pieces.indices.contains(m.piece), m.dist >= 1 else { return false }
        return maxSlide(m.piece, m.dir) >= m.dist
    }

        func applying(_ m: KlotskiMove) -> KlotskiBoard {
        var b = self
        b.pieces[m.piece].x += m.dx
        b.pieces[m.piece].y += m.dy
        return b
    }

    // MARK: 把盘面压成一个数（找最少步数用）

    /// 每格 3 位：0 空、1 小兔、2 竖块、3 横块、4 小方块。形状一样的木块互换位置，数是同一个。
        var key: UInt64 {
        var k: UInt64 = 0
        for p in pieces {
            for dy in 0..<p.kind.h {
                for dx in 0..<p.kind.w {
                    k |= UInt64(p.kind.rawValue) << UInt64(3 * ((p.y + dy) * Self.cols + p.x + dx))
                }
            }
        }
        return k
    }

    /// key 的逆运算（木块按从上到下、从左到右排）
        init(key: UInt64) {
        var used: UInt32 = 0
        var out: [KlotskiPiece] = []
        for i in 0..<(Self.cols * Self.rows) where used & (1 << UInt32(i)) == 0 {
            guard let kind = KlotskiKind(rawValue: Int((key >> UInt64(3 * i)) & 7)) else { continue }
            let p = KlotskiPiece(kind: kind, x: i % Self.cols, y: i / Self.cols)
            used |= Self.mask(p)
            out.append(p)
        }
        pieces = out
    }

    /// 镜像以后的 key；镜像对称的两个盘面算同一个
    var canonicalKey: UInt64 { min(key, mirrored.key) }

    /// 这个 key 是不是已经到出口
        static func isGoal(key: UInt64) -> Bool {
        // 全盘只有一只小兔：第 1 列第 3 行和第 2 列第 4 行都是小兔的格子，左上角就只能是 (1,3)
        (key >> UInt64(3 * (3 * cols + 1))) & 7 == 1 && (key >> UInt64(3 * (4 * cols + 2))) & 7 == 1
    }

    /// 这个 key 走一步能到的全部 key（不重复）
    static func neighbors(of key: UInt64) -> [UInt64] {
        var out: [UInt64] = []
        KlotskiFast.expand(key, into: &out)
        return Array(Set(out))
    }
}

/// 找最少步数时用的快速展开：直接在 key 的位上走，不建木块数组，不分配内存。
/// （iPad 上点「提示」要立刻有答案，调试版本里也不能卡太久；结果和 KlotskiBoard.allMoves 一模一样，tools/klotski/test.sh 会逐个盘面对照。）
enum KlotskiFast {
    /// [种类 * 20 + 左上角位置]：木块盖住哪些格子（放不下是 0）
    private static let cellMask: [UInt32] = table { k, pos in
        let kind = KlotskiKind(rawValue: k)!
        return KlotskiBoard.mask(kind, pos % 4, pos / 4)
    } fits: { k, pos in
        let kind = KlotskiKind(rawValue: k)!
        return pos % 4 + kind.w <= 4 && pos / 4 + kind.h <= 5
    }
    /// 同上：key 里这块木块的位
    private static let bits: [UInt64] = {
        var t = [UInt64](repeating: 0, count: 5 * 20)
        for k in 1...4 {
            let kind = KlotskiKind(rawValue: k)!
            for pos in 0..<20 where pos % 4 + kind.w <= 4 && pos / 4 + kind.h <= 5 {
                var v: UInt64 = 0
                for dy in 0..<kind.h { for dx in 0..<kind.w { v |= UInt64(k) << UInt64(3 * ((pos / 4 + dy) * 4 + pos % 4 + dx)) } }
                t[k * 20 + pos] = v
            }
        }
        return t
    }()
    private static let clear: [UInt64] = {
        var t = [UInt64](repeating: 0, count: 5 * 20)
        for k in 1...4 {
            let kind = KlotskiKind(rawValue: k)!
            for pos in 0..<20 where pos % 4 + kind.w <= 4 && pos / 4 + kind.h <= 5 {
                var v: UInt64 = 0
                for dy in 0..<kind.h { for dx in 0..<kind.w { v |= UInt64(7) << UInt64(3 * ((pos / 4 + dy) * 4 + pos % 4 + dx)) } }
                t[k * 20 + pos] = v
            }
        }
        return t
    }()

    private static func table(_ value: (Int, Int) -> UInt32, fits: (Int, Int) -> Bool) -> [UInt32] {
        var t = [UInt32](repeating: 0, count: 5 * 20)
        for k in 1...4 { for pos in 0..<20 where fits(k, pos) { t[k * 20 + pos] = value(k, pos) } }
        return t
    }

    /// 走一步能到的全部 key（可能有重复：形状一样的木块走到同一个盘面）
    static func expand(_ key: UInt64, into out: inout [UInt64]) {
        var occ: UInt32 = 0
        for i in 0..<20 where (key >> UInt64(3 * i)) & 7 != 0 { occ |= 1 << UInt32(i) }
        var seen: UInt32 = 0
        for i in 0..<20 {
            let bit: UInt32 = 1 << UInt32(i)
            if occ & bit == 0 || seen & bit != 0 { continue }
            let k = Int((key >> UInt64(3 * i)) & 7)
            let pm = cellMask[k * 20 + i]
            seen |= pm
            let base = key & ~clear[k * 20 + i]
            let free = occ & ~pm
            let x = i % 4, y = i / 4
            let w = k == 1 || k == 3 ? 2 : 1, h = k == 1 || k == 2 ? 2 : 1
            for d in 0..<4 {
                let dx = d == 2 ? -1 : d == 3 ? 1 : 0, dy = d == 0 ? -1 : d == 1 ? 1 : 0
                var n = 1
                while true {
                    let nx = x + dx * n, ny = y + dy * n
                    if nx < 0 || ny < 0 || nx + w > 4 || ny + h > 5 { break }
                    let np = ny * 4 + nx
                    if cellMask[k * 20 + np] & free != 0 { break }
                    out.append(base | bits[k * 20 + np])
                    n += 1
                }
            }
        }
    }
}

// MARK: - 最少步数

enum KlotskiSolver {
    /// 从这个盘面走到小兔出口的最少步数的一条走法（每一步的木块序号对应走这一步之前的盘面，序号一路不变）。
    /// 已经在出口是空数组；无解是 nil。
        static func solve(_ start: KlotskiBoard) -> [KlotskiMove]? {
        let s = start.key
        if KlotskiBoard.isGoal(key: s) { return [] }
        var parent: [UInt64: UInt64] = [s: s]
        var frontier = [s]
        var goal: UInt64?
        var scratch: [UInt64] = []
        search: while !frontier.isEmpty {
            var next: [UInt64] = []
            for k in frontier {
                scratch.removeAll(keepingCapacity: true)
                KlotskiFast.expand(k, into: &scratch)
                for nk in scratch {
                    if parent[nk] != nil { continue }
                    parent[nk] = k
                    if KlotskiBoard.isGoal(key: nk) { goal = nk; break search }
                    next.append(nk)
                }
            }
            frontier = next
        }
        guard let goal else { return nil }
        var keys = [goal]
        while let p = parent[keys.last!], p != keys.last! { keys.append(p) }
        keys.reverse()
        // 把一串 key 变回真正的走法：在真实盘面上找哪一步到下一个 key
        var out: [KlotskiMove] = []
        var board = start
        for next in keys.dropFirst() {
            guard let m = board.allMoves.first(where: { board.applying($0).key == next }) else { return nil }
            out.append(m)
            board = board.applying(m)
        }
        return out
    }

    static func minMoves(_ start: KlotskiBoard) -> Int? { solve(start)?.count }

    /// 提示：现在最好的下一步
    static func bestMove(_ board: KlotskiBoard) -> KlotskiMove? { solve(board)?.first }

    /// 从这个盘面出发能走到的所有盘面（按 key 算，形状一样的木块互换算同一个）
        static func component(of start: KlotskiBoard) -> Set<UInt64> {
        var seen: Set<UInt64> = [start.key]
        var frontier = [start.key]
        var scratch: [UInt64] = []
        while !frontier.isEmpty {
            var next: [UInt64] = []
            for k in frontier {
                scratch.removeAll(keepingCapacity: true)
                KlotskiFast.expand(k, into: &scratch)
                for n in scratch where seen.insert(n).inserted { next.append(n) }
            }
            frontier = next
        }
        return seen
    }

    /// 一个连通块里每个盘面离出口最少几步（走不到出口的不在里面）。走法可以倒着走，所以从所有出口盘面一起往外搜。
        static func distancesToGoal(in states: Set<UInt64>) -> [UInt64: Int] {
        var dist: [UInt64: Int] = [:]
        var scratch: [UInt64] = []
        var frontier = Array(states.filter(KlotskiBoard.isGoal(key:)))
        for k in frontier { dist[k] = 0 }
        var d = 0
        while !frontier.isEmpty {
            d += 1
            var next: [UInt64] = []
            for k in frontier {
                scratch.removeAll(keepingCapacity: true)
                KlotskiFast.expand(k, into: &scratch)
                for n in scratch where dist[n] == nil {
                    dist[n] = d
                    next.append(n)
                }
            }
            frontier = next
        }
        return dist
    }
}

// MARK: - 格子的名字

/// 列用 a b c d（从左到右），行用 1 2 3 4 5（从上到下），"b3" 是第 2 列第 3 行
enum KlotskiCellName {
    static let letters = Array("abcd")

    static func name(_ x: Int, _ y: Int) -> String { "\(letters[x])\(y + 1)" }

    static func parse(_ s: String) -> (x: Int, y: Int)? {
        let c = Array(s)
        guard c.count == 2, let x = letters.firstIndex(of: c[0]), let n = Int(String(c[1])), n >= 1, n <= KlotskiBoard.rows else { return nil }
        return (x, n - 1)
    }

    static func mirror(_ s: String) -> String? {
        parse(s).map { name(KlotskiBoard.cols - 1 - $0.x, $0.y) }
    }
}

