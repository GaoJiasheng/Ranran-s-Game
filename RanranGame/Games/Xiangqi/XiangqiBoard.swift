import Foundation

// 象棋的规则：棋盘、走法、将军、将死。纯逻辑，不依赖界面，电脑对手和教学都用它。
// 坐标：x = 0…8 从左到右（a…i），y = 0…9 从红方底线往上（和 ICCS 记谱法一致，比如 "h2e2" 是炮二平五）。

enum XSide: Int8, Sendable, Codable {
    case red = 1, black = -1

    var other: XSide { self == .red ? .black : .red }
    var name: String { self == .red ? "红方" : "黑方" }
}

enum XKind: Int8, CaseIterable, Sendable {
    case king = 1, advisor, elephant, horse, rook, cannon, pawn

    /// 棋子上写的字：红方用"帅仕相傌俥炮兵"里常见的简体写法，黑方用"将士象马车砲卒"
    func glyph(_ side: XSide) -> String {
        switch (self, side) {
        case (.king, .red): "帅"
        case (.king, .black): "将"
        case (.advisor, .red): "仕"
        case (.advisor, .black): "士"
        case (.elephant, .red): "相"
        case (.elephant, .black): "象"
        case (.horse, _): "马"
        case (.rook, _): "车"
        case (.cannon, _): "炮"
        case (.pawn, .red): "兵"
        case (.pawn, .black): "卒"
        }
    }

    var fenLetter: Character {
        switch self {
        case .king: "k"
        case .advisor: "a"
        case .elephant: "b"
        case .horse: "n"
        case .rook: "r"
        case .cannon: "c"
        case .pawn: "p"
        }
    }

    init?(fen c: Character) {
        switch c.lowercased() {
        case "k": self = .king
        case "a": self = .advisor
        case "b", "e": self = .elephant
        case "n", "h": self = .horse
        case "r": self = .rook
        case "c": self = .cannon
        case "p": self = .pawn
        default: return nil
        }
    }
}

struct XPiece: Hashable, Sendable {
    let side: XSide
    let kind: XKind

    init(_ side: XSide, _ kind: XKind) { self.side = side; self.kind = kind }

    init?(code: Int8) {
        guard code != 0, let k = XKind(rawValue: abs(code)) else { return nil }
        side = code > 0 ? .red : .black
        kind = k
    }

    var code: Int8 { kind.rawValue * side.rawValue }
    var glyph: String { kind.glyph(side) }
}

struct XSquare: Hashable, Sendable, Codable {
    let x: Int
    let y: Int

    init(_ x: Int, _ y: Int) { self.x = x; self.y = y }

    /// "e0" → (4, 0)
    init?(_ name: String) {
        let c = Array(name)
        guard c.count == 2, let a = c[0].asciiValue, let d = c[1].wholeNumberValue,
              a >= 97, a <= 105 else { return nil }
        x = Int(a) - 97
        y = d
    }

    var name: String { "\(Character(UnicodeScalar(UInt8(97 + x))))\(y)" }
    var index: Int { y * 9 + x }
    static func inside(_ x: Int, _ y: Int) -> Bool { x >= 0 && x < 9 && y >= 0 && y < 10 }
}

struct XMove: Hashable, Sendable {
    let from: XSquare
    let to: XSquare

    init(_ from: XSquare, _ to: XSquare) { self.from = from; self.to = to }

    /// "h2e2"
    init?(_ iccs: String) {
        guard iccs.count == 4,
              let f = XSquare(String(iccs.prefix(2))), let t = XSquare(String(iccs.suffix(2))) else { return nil }
        from = f; to = t
    }

    var iccs: String { from.name + to.name }
}

struct XBoard: Sendable, Hashable {
    static let start = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w"

    /// 90 格，下标 = y * 9 + x；正数红方，负数黑方，0 空
    var cells = [Int8](repeating: 0, count: 90)
    var turn: XSide = .red

    init() {}

    /// 标准象棋 FEN（从黑方底线写起）；后面的 "w"/"r" 表示红方走，"b" 表示黑方走
    init?(fen: String) {
        let parts = fen.split(separator: " ")
        guard let rows = parts.first?.split(separator: "/", omittingEmptySubsequences: false), rows.count == 10 else { return nil }
        for (r, row) in rows.enumerated() {
            let y = 9 - r
            var x = 0
            for c in row {
                if let n = c.wholeNumberValue {
                    x += n
                } else if let k = XKind(fen: c) {
                    guard x < 9 else { return nil }
                    cells[y * 9 + x] = XPiece(c.isUppercase ? .red : .black, k).code
                    x += 1
                } else {
                    return nil
                }
            }
            guard x == 9 else { return nil }
        }
        if parts.count > 1, parts[1] == "b" { turn = .black }
    }

    var fen: String {
        var rows: [String] = []
        for y in stride(from: 9, through: 0, by: -1) {
            var row = "", empty = 0
            for x in 0..<9 {
                if let p = self[x, y] {
                    if empty > 0 { row += "\(empty)"; empty = 0 }
                    let l = String(p.kind.fenLetter)
                    row += p.side == .red ? l.uppercased() : l
                } else {
                    empty += 1
                }
            }
            if empty > 0 { row += "\(empty)" }
            rows.append(row)
        }
        return rows.joined(separator: "/") + (turn == .red ? " w" : " b")
    }

    subscript(x: Int, y: Int) -> XPiece? {
        get { XPiece(code: cells[y * 9 + x]) }
        set { cells[y * 9 + x] = newValue?.code ?? 0 }
    }

    subscript(s: XSquare) -> XPiece? {
        get { self[s.x, s.y] }
        set { self[s.x, s.y] = newValue }
    }

    func code(_ x: Int, _ y: Int) -> Int8 { cells[y * 9 + x] }

    func king(_ side: XSide) -> XSquare? {
        let target = XKind.king.rawValue * side.rawValue
        // 帅只会在九宫里
        let ys = side == .red ? 0...2 : 7...9
        for y in ys { for x in 3...5 where cells[y * 9 + x] == target { return XSquare(x, y) } }
        return nil
    }

    var pieces: [(XSquare, XPiece)] {
        cells.indices.compactMap { i in XPiece(code: cells[i]).map { (XSquare(i % 9, i / 9), $0) } }
    }

    // MARK: 走法

    static func inPalace(_ x: Int, _ y: Int, _ side: XSide) -> Bool {
        x >= 3 && x <= 5 && (side == .red ? (0...2).contains(y) : (7...9).contains(y))
    }

    static func ownHalf(_ y: Int, _ side: XSide) -> Bool { side == .red ? y <= 4 : y >= 5 }

    /// 不管会不会被将军的走法
    func pseudoMoves(from s: XSquare) -> [XMove] {
        var out: [XMove] = []
        pseudoMoves(from: s, into: &out, capturesOnly: false)
        return out
    }

    func pseudoMoves(from s: XSquare, into out: inout [XMove], capturesOnly: Bool) {
        let c = cells[s.index]
        guard c != 0 else { return }
        let side: XSide = c > 0 ? .red : .black
        let kind = XKind(rawValue: abs(c))!
        func add(_ x: Int, _ y: Int) {
            let t = cells[y * 9 + x]
            if t == 0 {
                if !capturesOnly { out.append(XMove(s, XSquare(x, y))) }
            } else if (t > 0) != (c > 0) {
                out.append(XMove(s, XSquare(x, y)))
            }
        }
        switch kind {
        case .king:
            for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let x = s.x + dx, y = s.y + dy
                if Self.inPalace(x, y, side) { add(x, y) }
            }
        case .advisor:
            for (dx, dy) in [(1, 1), (1, -1), (-1, 1), (-1, -1)] {
                let x = s.x + dx, y = s.y + dy
                if Self.inPalace(x, y, side) { add(x, y) }
            }
        case .elephant:
            for (dx, dy) in [(2, 2), (2, -2), (-2, 2), (-2, -2)] {
                let x = s.x + dx, y = s.y + dy
                guard XSquare.inside(x, y), Self.ownHalf(y, side),
                      cells[(s.y + dy / 2) * 9 + s.x + dx / 2] == 0 else { continue }
                add(x, y)
            }
        case .horse:
            for (dx, dy) in [(1, 2), (-1, 2), (1, -2), (-1, -2), (2, 1), (2, -1), (-2, 1), (-2, -1)] {
                let x = s.x + dx, y = s.y + dy
                guard XSquare.inside(x, y) else { continue }
                // 马腿：沿着长的那个方向紧挨着的一格
                let lx = abs(dx) == 2 ? s.x + dx / 2 : s.x
                let ly = abs(dy) == 2 ? s.y + dy / 2 : s.y
                guard cells[ly * 9 + lx] == 0 else { continue }
                add(x, y)
            }
        case .rook, .cannon:
            for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                var x = s.x + dx, y = s.y + dy
                var jumped = false
                while XSquare.inside(x, y) {
                    let t = cells[y * 9 + x]
                    if kind == .rook {
                        if t == 0 {
                            if !capturesOnly { out.append(XMove(s, XSquare(x, y))) }
                        } else {
                            if (t > 0) != (c > 0) { out.append(XMove(s, XSquare(x, y))) }
                            break
                        }
                    } else if !jumped {
                        if t == 0 {
                            if !capturesOnly { out.append(XMove(s, XSquare(x, y))) }
                        } else {
                            jumped = true
                        }
                    } else if t != 0 {
                        if (t > 0) != (c > 0) { out.append(XMove(s, XSquare(x, y))) }
                        break
                    }
                    x += dx; y += dy
                }
            }
        case .pawn:
            let f = side == .red ? 1 : -1
            if XSquare.inside(s.x, s.y + f) { add(s.x, s.y + f) }
            if !Self.ownHalf(s.y, side) {
                if s.x > 0 { add(s.x - 1, s.y) }
                if s.x < 8 { add(s.x + 1, s.y) }
            }
        }
    }

    // MARK: 将军

    /// side 的帅现在有没有被将军（包括帅将照面）
    func inCheck(_ side: XSide) -> Bool {
        guard let k = king(side) else { return true }
        return attacked(k, by: side.other)
    }

    /// 格子 s 会不会被 by 这一方吃到
    func attacked(_ s: XSquare, by: XSide) -> Bool {
        let sign = by.rawValue
        func isP(_ x: Int, _ y: Int, _ k: XKind) -> Bool { cells[y * 9 + x] == k.rawValue * sign }

        // 直线：车、帅（照面）、炮（隔一个）
        for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
            var x = s.x + dx, y = s.y + dy
            var screens = 0
            while XSquare.inside(x, y) {
                let t = cells[y * 9 + x]
                if t != 0 {
                    if screens == 0 {
                        if t == XKind.rook.rawValue * sign { return true }
                        // 帅将照面：只沿竖线
                        if dx == 0, t == XKind.king.rawValue * sign { return true }
                        // 紧挨着的兵 / 帅
                        if abs(x - s.x) + abs(y - s.y) == 1 {
                            if t == XKind.king.rawValue * sign, Self.inPalace(s.x, s.y, by) { return true }
                            if t == XKind.pawn.rawValue * sign {
                                let f = by == .red ? 1 : -1
                                // 兵往前一步吃到 s；或者过了河横着吃
                                if dy == -f { return true }
                                if dy == 0, !Self.ownHalf(y, by) { return true }
                            }
                        }
                    } else if screens == 1 {
                        if t == XKind.cannon.rawValue * sign { return true }
                        break
                    }
                    screens += 1
                }
                x += dx; y += dy
            }
        }
        // 马
        for (dx, dy) in [(1, 2), (-1, 2), (1, -2), (-1, -2), (2, 1), (2, -1), (-2, 1), (-2, -1)] {
            let hx = s.x + dx, hy = s.y + dy
            guard XSquare.inside(hx, hy), isP(hx, hy, .horse) else { continue }
            // 马在 (hx, hy)，往 s 走：腿在马身边、沿着长的方向
            let mx = -dx, my = -dy
            let lx = abs(mx) == 2 ? hx + mx / 2 : hx
            let ly = abs(my) == 2 ? hy + my / 2 : hy
            if cells[ly * 9 + lx] == 0 { return true }
        }
        // 仕、相只在自己那边活动，攻击帅时只有仕在九宫里可能（对方的仕进不了我方九宫），不用看
        return false
    }

    // MARK: 合法走法

    func legalMoves(from s: XSquare) -> [XMove] {
        guard let p = self[s], p.side == turn else { return [] }
        return pseudoMoves(from: s).filter { isLegal($0) }
    }

    func legalMoves() -> [XMove] {
        var out: [XMove] = []
        for i in 0..<90 where cells[i] != 0 && (cells[i] > 0) == (turn == .red) {
            pseudoMoves(from: XSquare(i % 9, i / 9), into: &out, capturesOnly: false)
        }
        return out.filter { isLegal($0) }
    }

    /// 走完以后自己的帅不能被将军，帅将不能照面
    func isLegal(_ m: XMove) -> Bool {
        var b = self
        let side = turn
        b.cells[m.to.index] = b.cells[m.from.index]
        b.cells[m.from.index] = 0
        return !b.inCheck(side)
    }

    /// 走一步（不检查合法），返回被吃掉的子
    @discardableResult
    mutating func make(_ m: XMove) -> Int8 {
        let captured = cells[m.to.index]
        cells[m.to.index] = cells[m.from.index]
        cells[m.from.index] = 0
        turn = turn.other
        return captured
    }

    mutating func unmake(_ m: XMove, captured: Int8) {
        cells[m.from.index] = cells[m.to.index]
        cells[m.to.index] = captured
        turn = turn.other
    }

    /// 给每个子一个编号（界面动画用）
    static func initialIDs(_ b: XBoard) -> [Int] {
        b.cells.indices.map { b.cells[$0] == 0 ? 0 : $0 + 1 }
    }

    func applying(_ m: XMove) -> XBoard {
        var b = self
        b.make(m)
        return b
    }

    /// 轮到走的一方没有合法着法 = 输了（被将死，或者被困毙）
    var isLost: Bool { legalMoves().isEmpty }
    var isCheckmate: Bool { inCheck(turn) && isLost }

    func isMate(after m: XMove) -> Bool { applying(m).isCheckmate }
    func gives_check(_ m: XMove) -> Bool { let b = applying(m); return b.inCheck(b.turn) }

    /// 有没有一步就能将死对方的着法
    func matesInOne() -> [XMove] { legalMoves().filter { isMate(after: $0) } }

    /// 这一步走完以后，不管对方怎么应，都能一步将死（两步杀）
    func isMateInTwo(_ m: XMove) -> Bool {
        let b = applying(m)
        let replies = b.legalMoves()
        // 对方已经无棋可走（被将死或困毙），也算赢
        if replies.isEmpty { return true }
        return replies.allSatisfy { !b.applying($0).matesInOne().isEmpty }
    }
}

// MARK: - 中文记谱（炮二平五、马8进7……）

extension XBoard {
    private static let redNumbers = ["一", "二", "三", "四", "五", "六", "七", "八", "九"]

    /// 这一步的中文记法（在走之前的局面上调用）。红方用中文数字、从红方右边数；黑方用阿拉伯数字、从黑方右边数。
    func notation(_ m: XMove) -> String {
        guard let p = self[m.from] else { return m.iccs }
        let red = p.side == .red
        func file(_ x: Int) -> String { red ? Self.redNumbers[8 - x] : "\(x + 1)" }
        func count(_ n: Int) -> String { red ? Self.redNumbers[n - 1] : "\(n)" }

        // 同一条竖线上有两个一样的子：用"前 / 后"
        let twins = (0..<10).filter { y in y != m.from.y && self[m.from.x, y] == p }
        var head = p.glyph + file(m.from.x)
        if let other = twins.first {
            let ahead = red ? m.from.y > other : m.from.y < other
            head = (ahead ? "前" : "后") + p.glyph
        }

        let dy = m.to.y - m.from.y
        let forward = red ? dy > 0 : dy < 0
        if dy == 0 { return head + "平" + file(m.to.x) }
        let action = forward ? "进" : "退"
        switch p.kind {
        case .horse, .elephant, .advisor:
            return head + action + file(m.to.x)
        default:
            return head + action + count(abs(dy))
        }
    }
}
