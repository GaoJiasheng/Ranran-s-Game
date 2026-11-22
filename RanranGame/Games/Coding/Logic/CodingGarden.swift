import Foundation

// 编程的花园：格子、石头、胡萝卜、家、两种花。只用 Foundation。
//
// 写法：一行一行，用 / 隔开，最大 7 列 × 6 行。
//   .  草地        #  石头（走不上去）   C  胡萝卜
//   B  小兔出发的地方（一个花园一个）     H  小兔的家（可以没有）
//   b  蓝花地砖    y  黄花地砖
// 格子的名字（教学的标记用）：列 a b c …（从左到右），行 1 2 3 …（从上到下），"b3" 是第 2 列第 3 行。

struct CodingCell: Hashable, Comparable, CustomStringConvertible {
    var x: Int
    var y: Int

    static func < (a: Self, b: Self) -> Bool { (a.y, a.x) < (b.y, b.x) }

    var name: String { "\(Character(UnicodeScalar(UInt8(97 + x))))\(y + 1)" }
    var description: String { name }

    init(x: Int, y: Int) { self.x = x; self.y = y }

    init?(name: String) {
        let s = Array(name.unicodeScalars)
        guard s.count >= 2, s[0].value >= 97, s[0].value <= 122, let row = Int(String(name.dropFirst())), row >= 1 else { return nil }
        x = Int(s[0].value) - 97
        y = row - 1
    }
}

struct CodingGarden: Hashable {
    static let maxWidth = 7
    static let maxHeight = 6

    let width: Int
    let height: Int
    /// 一行一行的格子（B、C、H 也照原样存着）
    let cells: [Character]
    let start: CodingCell
    let home: CodingCell?
    /// 胡萝卜，按从上到下、从左到右的顺序（吃没吃记在一个二进制数里，第 i 位是第 i 根）
    let carrots: [CodingCell]

    init?(layout: String) {
        let rows = layout.split(separator: "/", omittingEmptySubsequences: false).map { Array($0) }
        guard let w = rows.first?.count, w >= 1, w <= Self.maxWidth, rows.count <= Self.maxHeight,
              rows.allSatisfy({ $0.count == w }) else { return nil }
        var start: CodingCell?, home: CodingCell?
        var carrots: [CodingCell] = []
        for (y, r) in rows.enumerated() {
            for (x, c) in r.enumerated() {
                switch c {
                case ".", "#", "b", "y": break
                case "C": carrots.append(CodingCell(x: x, y: y))
                case "B": if start != nil { return nil }; start = CodingCell(x: x, y: y)
                case "H": if home != nil { return nil }; home = CodingCell(x: x, y: y)
                default: return nil
                }
            }
        }
        guard let start, !carrots.isEmpty, carrots.count <= 16 else { return nil }
        width = w
        height = rows.count
        cells = rows.flatMap { $0 }
        self.start = start
        self.home = home
        self.carrots = carrots
    }

    var layout: String {
        (0..<height).map { y in String(cells[(y * width)..<((y + 1) * width)]) }.joined(separator: "/")
    }

    var area: Int { width * height }
    var allEaten: UInt32 { UInt32((1 << carrots.count) - 1) }

    func inside(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < width && y < height }

    func char(_ x: Int, _ y: Int) -> Character { cells[y * width + x] }

    /// 能不能走上去（花园外面、石头都不行）
    func open(_ x: Int, _ y: Int) -> Bool { inside(x, y) && char(x, y) != "#" }

    func flower(_ x: Int, _ y: Int) -> CodingFlower? { inside(x, y) ? CodingFlower(rawValue: char(x, y)) : nil }

    func carrotIndex(_ x: Int, _ y: Int) -> Int? { carrots.firstIndex { $0.x == x && $0.y == y } }

    var flowers: Set<CodingFlower> { Set(cells.compactMap { CodingFlower(rawValue: $0) }) }

    /// 练一练的四种样子：0 原样，1 左右翻，2 上下翻，3 都翻
    func flipped(_ k: Int) -> CodingGarden {
        var rows = (0..<height).map { y in Array(cells[(y * width)..<((y + 1) * width)]) }
        if k & 1 != 0 { rows = rows.map { $0.reversed() } }
        if k & 2 != 0 { rows.reverse() }
        return CodingGarden(layout: rows.map { String($0) }.joined(separator: "/"))!
    }

    func flip(_ c: CodingCell, _ k: Int) -> CodingCell {
        CodingCell(x: k & 1 != 0 ? width - 1 - c.x : c.x, y: k & 2 != 0 ? height - 1 - c.y : c.y)
    }
}

/// 一关可以有好几个花园（「如果」那一组）：写法是几个花园用 | 隔开
enum CodingGardens {
    static func parse(_ s: String) -> [CodingGarden]? {
        let g = s.split(separator: "|").map { CodingGarden(layout: $0.trimmingCharacters(in: .whitespaces)) }
        guard !g.isEmpty, g.allSatisfy({ $0 != nil }) else { return nil }
        return g.map { $0! }
    }

    static func text(_ g: [CodingGarden]) -> String { g.map(\.layout).joined(separator: "|") }
}
