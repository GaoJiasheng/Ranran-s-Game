import Foundation

enum Stone: Int8, Sendable {
    case black = 1, white = 2

    var opponent: Stone { self == .black ? .white : .black }
    var name: String { self == .black ? "黑棋" : "白棋" }
}

struct Point: Hashable, Sendable {
    let x: Int
    let y: Int
}

/// 15×15 的棋盘。
struct Board: Sendable {
    static let size = 15
    static let center = Point(x: 7, y: 7)
    static let directions = [(1, 0), (0, 1), (1, 1), (1, -1)]

    private(set) var cells = [Stone?](repeating: nil, count: size * size)
    private(set) var stoneCount = 0

    static func inside(_ x: Int, _ y: Int) -> Bool {
        x >= 0 && y >= 0 && x < size && y < size
    }

    subscript(x: Int, y: Int) -> Stone? {
        get { cells[y * Self.size + x] }
        set {
            let i = y * Self.size + x
            if cells[i] == nil, newValue != nil { stoneCount += 1 }
            if cells[i] != nil, newValue == nil { stoneCount -= 1 }
            cells[i] = newValue
        }
    }

    subscript(p: Point) -> Stone? {
        get { self[p.x, p.y] }
        set { self[p.x, p.y] = newValue }
    }

    var isEmpty: Bool { stoneCount == 0 }
    var isFull: Bool { stoneCount == Self.size * Self.size }

    /// 如果 p 上的棋子连成了五个（或更多），返回这条线上的所有点（按顺序）。
    func winningLine(at p: Point) -> [Point]? {
        guard let c = self[p] else { return nil }
        for (dx, dy) in Self.directions {
            var line = [p]
            var x = p.x + dx, y = p.y + dy
            while Self.inside(x, y), self[x, y] == c {
                line.append(Point(x: x, y: y)); x += dx; y += dy
            }
            x = p.x - dx; y = p.y - dy
            while Self.inside(x, y), self[x, y] == c {
                line.insert(Point(x: x, y: y), at: 0); x -= dx; y -= dy
            }
            if line.count >= 5 { return line }
        }
        return nil
    }
}
