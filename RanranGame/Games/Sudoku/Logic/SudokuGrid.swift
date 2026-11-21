import Foundation

// 数独的盘面。只用 Foundation：App、命令行出题器和测试（tools/sudoku）都编译这个文件夹。
//
// 写法（关卡数据和教学都用它）："<边长>[f]:<格子>"，格子按行从左到右、从上到下，"." 是空格。
//   "4f:12.43..." 四宫格、用水果图案显示；"6:..." 六宫格（宫是 2 行 3 列）；"9:..." 九宫格。
// 格子的名字 "r3c4"：第 3 行第 4 列，从 1 数起。行、列、宫的名字 "row:3"、"col:4"、"box:5"，宫按从左到右、从上到下数。

/// 一行、一列或者一宫
struct SudokuUnit: Hashable, CustomStringConvertible {
    enum Kind: String, CaseIterable { case row, col, box }

    let kind: Kind
    /// 从 0 数起
    let index: Int

    init(_ kind: Kind, _ index: Int) {
        self.kind = kind
        self.index = index
    }

    /// "row:3"（从 1 数起）
    init?(_ s: String) {
        let p = s.split(separator: ":").map(String.init)
        guard p.count == 2, let k = Kind(rawValue: p[0]), let i = Int(p[1]), i >= 1 else { return nil }
        self.init(k, i - 1)
    }

    var description: String { "\(kind.rawValue):\(index + 1)" }

    /// 给孩子看的字：行、列、宫
    var word: String {
        switch kind {
        case .row: "行"
        case .col: "列"
        case .box: "宫"
        }
    }
}

struct SudokuGrid: Hashable {
    /// 边长：4、6 或 9
    let n: Int
    /// 一宫几行、几列（4 → 2×2，6 → 2×3，9 → 3×3）
    let boxRows: Int
    let boxCols: Int
    /// 按行存，0 是空格
    var cells: [Int]
    /// 用水果图案代替 1–4（只影响显示）
    var fruit: Bool

    static func boxShape(_ n: Int) -> (rows: Int, cols: Int) {
        switch n {
        case 4: (2, 2)
        case 6: (2, 3)
        default: (3, 3)
        }
    }

    static let sizes = [4, 6, 9]

    init(n: Int, cells: [Int]? = nil, fruit: Bool = false) {
        self.n = n
        (boxRows, boxCols) = Self.boxShape(n)
        self.cells = cells ?? Array(repeating: 0, count: n * n)
        self.fruit = fruit
    }

    init?(spec: String) {
        let parts = spec.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        var head = parts[0]
        let fruit = head.hasSuffix("f")
        if fruit { head.removeLast() }
        guard let n = Int(head), Self.sizes.contains(n) else { return nil }
        var cells: [Int] = []
        for ch in parts[1] {
            if ch == "." || ch == "0" { cells.append(0) } else if let v = ch.wholeNumberValue, v >= 1, v <= n { cells.append(v) } else { return nil }
        }
        guard cells.count == n * n else { return nil }
        self.init(n: n, cells: cells, fruit: fruit)
    }

    var spec: String {
        "\(n)\(fruit ? "f" : ""):" + cells.map { $0 == 0 ? "." : String($0) }.joined()
    }

    var count: Int { n * n }

    subscript(_ i: Int) -> Int {
        get { cells[i] }
        set { cells[i] = newValue }
    }

    func row(_ i: Int) -> Int { i / n }
    func col(_ i: Int) -> Int { i % n }
    func index(_ r: Int, _ c: Int) -> Int { r * n + c }

    /// 第几宫（从 0 数）
    func box(_ i: Int) -> Int {
        let bandsAcross = n / boxCols
        return (row(i) / boxRows) * bandsAcross + col(i) / boxCols
    }

    func unit(_ kind: SudokuUnit.Kind, of i: Int) -> SudokuUnit {
        switch kind {
        case .row: SudokuUnit(.row, row(i))
        case .col: SudokuUnit(.col, col(i))
        case .box: SudokuUnit(.box, box(i))
        }
    }

    func units(of i: Int) -> [SudokuUnit] { SudokuUnit.Kind.allCases.map { unit($0, of: i) } }

    func cells(_ u: SudokuUnit) -> [Int] {
        switch u.kind {
        case .row: return (0..<n).map { index(u.index, $0) }
        case .col: return (0..<n).map { index($0, u.index) }
        case .box:
            let bandsAcross = n / boxCols
            let r0 = (u.index / bandsAcross) * boxRows, c0 = (u.index % bandsAcross) * boxCols
            var out: [Int] = []
            for r in r0..<(r0 + boxRows) { for c in c0..<(c0 + boxCols) { out.append(index(r, c)) } }
            return out
        }
    }

    func isValid(_ u: SudokuUnit) -> Bool { u.index >= 0 && u.index < n }

    /// 全部行、列、宫
    var units: [SudokuUnit] {
        SudokuUnit.Kind.allCases.flatMap { k in (0..<n).map { SudokuUnit(k, $0) } }
    }

    func contains(_ u: SudokuUnit, _ i: Int) -> Bool { unit(u.kind, of: i) == u }

    /// 和这一格同行、同列、同宫的其他格子
    func peers(_ i: Int) -> [Int] { Self.peerTable[n]![i] }

    private static let peerTable: [Int: [[Int]]] = Dictionary(uniqueKeysWithValues: sizes.map { n in
        let g = SudokuGrid(n: n)
        return (n, (0..<n * n).map { i in
            var seen = Set<Int>()
            for u in g.units(of: i) { for j in g.cells(u) where j != i { seen.insert(j) } }
            return seen.sorted()
        })
    })

    /// 这一格还能填什么（看同行、同列、同宫已经有了谁）。已经填了的格子没有候选。
    func candidates(_ i: Int) -> [Int] {
        guard cells[i] == 0 else { return [] }
        var used = Set<Int>()
        for j in peers(i) where cells[j] != 0 { used.insert(cells[j]) }
        return (1...n).filter { !used.contains($0) }
    }

    func values(in u: SudokuUnit) -> [Int] { cells(u).map { cells[$0] }.filter { $0 != 0 } }

    func blanks(in u: SudokuUnit) -> [Int] { cells(u).filter { cells[$0] == 0 } }

    /// 这一行 / 列 / 宫里还缺哪些
    func missing(in u: SudokuUnit) -> [Int] {
        let have = Set(values(in: u))
        return (1...n).filter { !have.contains($0) }
    }

    /// 和别的格子重复了的格子（同一行 / 列 / 宫里有两个一样的）
    func conflicts() -> Set<Int> {
        var out = Set<Int>()
        for u in units {
            var byValue: [Int: [Int]] = [:]
            for i in cells(u) where cells[i] != 0 { byValue[cells[i], default: []].append(i) }
            for (_, list) in byValue where list.count > 1 { out.formUnion(list) }
        }
        return out
    }

    var blankCount: Int { cells.filter { $0 == 0 }.count }
    var isFull: Bool { !cells.contains(0) }
    var isSolved: Bool { isFull && conflicts().isEmpty }

    // MARK: 格子的名字

    func name(_ i: Int) -> String { "r\(row(i) + 1)c\(col(i) + 1)" }

    /// "r3c4" → 格子
    func cell(named s: String) -> Int? {
        guard s.hasPrefix("r"), let ci = s.firstIndex(of: "c"),
              let r = Int(s[s.index(after: s.startIndex)..<ci]), let c = Int(s[s.index(after: ci)...]),
              r >= 1, r <= n, c >= 1, c <= n else { return nil }
        return index(r - 1, c - 1)
    }
}

/// 固定种子的随机数（出题器、练习变换用；同一个种子永远出一样的东西）
struct SudokuRNG: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
