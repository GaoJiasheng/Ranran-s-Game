import Foundation

// 国际象棋的规则：棋盘、走法（含王车易位、吃过路兵、升变）、将军、将死、逼和、和棋。
// 纯逻辑，只用 Foundation：电脑对手、教学判题、命令行测试（tools/chess）都用它。走法计数对照过标准 perft。
// 坐标：file = 0…7 是 a…h（白方从左到右），rank = 0…7 是 1…8（从白方底线往上）；格子下标 = rank * 8 + file。

enum ChessSide: Int8, Sendable, Codable, Hashable {
    case white = 1, black = -1

    var other: ChessSide { self == .white ? .black : .white }
    var name: String { self == .white ? "白方" : "黑方" }
    var short: String { self == .white ? "白" : "黑" }
}

enum ChessKind: Int8, CaseIterable, Sendable, Hashable {
    case king = 1, queen, rook, bishop, knight, pawn

    /// 中文名：王、后、车、象、马、兵
    var chinese: String {
        switch self {
        case .king: "王"
        case .queen: "后"
        case .rook: "车"
        case .bishop: "象"
        case .knight: "马"
        case .pawn: "兵"
        }
    }

    var letter: Character {
        switch self {
        case .king: "k"
        case .queen: "q"
        case .rook: "r"
        case .bishop: "b"
        case .knight: "n"
        case .pawn: "p"
        }
    }

    init?(letter c: Character) {
        switch c.lowercased() {
        case "k": self = .king
        case "q": self = .queen
        case "r": self = .rook
        case "b": self = .bishop
        case "n": self = .knight
        case "p": self = .pawn
        default: return nil
        }
    }

    /// 教学里说的子力：兵 1、马象 3、车 5、后 9（王不算）
    var points: Int {
        switch self {
        case .pawn: 1
        case .knight, .bishop: 3
        case .rook: 5
        case .queen: 9
        case .king: 0
        }
    }

    /// 升变可以选的子
    static let promotions: [ChessKind] = [.queen, .rook, .bishop, .knight]
}

struct ChessPiece: Hashable, Sendable {
    let side: ChessSide
    let kind: ChessKind

    init(_ side: ChessSide, _ kind: ChessKind) { self.side = side; self.kind = kind }

    init?(code: Int8) {
        guard code != 0, let k = ChessKind(rawValue: abs(code)) else { return nil }
        side = code > 0 ? .white : .black
        kind = k
    }

    var code: Int8 { kind.rawValue * side.rawValue }
    /// "白马"
    var name: String { side.short + kind.chinese }
    /// 棋子图片的名字：chess_wk … chess_bp
    var artName: String { "chess_" + (side == .white ? "w" : "b") + String(kind.letter) }
    /// 图片还没到时用的符号（实心的那一套，颜色由界面来涂）
    var glyph: String {
        switch kind {
        case .king: "♚"
        case .queen: "♛"
        case .rook: "♜"
        case .bishop: "♝"
        case .knight: "♞"
        case .pawn: "♟\u{FE0E}"
        }
    }
}

struct ChessSquare: Hashable, Sendable, Codable, Comparable {
    let index: Int

    init(index: Int) { self.index = index }
    init(_ file: Int, _ rank: Int) { index = rank * 8 + file }

    /// "e4" → (4, 3)
    init?(_ name: String) {
        let c = Array(name.unicodeScalars)
        guard c.count == 2, c[0].value >= 97, c[0].value <= 104, c[1].value >= 49, c[1].value <= 56 else { return nil }
        index = Int(c[1].value - 49) * 8 + Int(c[0].value - 97)
    }

    var file: Int { index & 7 }
    var rank: Int { index >> 3 }
    var name: String { "\(Character(UnicodeScalar(UInt8(97 + file))))\(rank + 1)" }
    /// a1 是深色格
    var isLight: Bool { (file + rank) % 2 == 1 }

    static func inside(_ f: Int, _ r: Int) -> Bool { f >= 0 && f < 8 && r >= 0 && r < 8 }
    static func < (a: Self, b: Self) -> Bool { a.index < b.index }
    static let all = (0..<64).map(ChessSquare.init(index:))
}

struct ChessMove: Hashable, Sendable {
    let from: ChessSquare
    let to: ChessSquare
    let promotion: ChessKind?

    init(_ from: ChessSquare, _ to: ChessSquare, promotion: ChessKind? = nil) {
        self.from = from; self.to = to; self.promotion = promotion
    }

    init(_ from: Int, _ to: Int, promotion: ChessKind? = nil) {
        self.init(ChessSquare(index: from), ChessSquare(index: to), promotion: promotion)
    }

    /// "e2e4"、"e7e8q"
    init?(_ uci: String) {
        guard uci.count == 4 || uci.count == 5,
              let f = ChessSquare(String(uci.prefix(2))),
              let t = ChessSquare(String(uci.dropFirst(2).prefix(2))) else { return nil }
        var p: ChessKind?
        if uci.count == 5 {
            guard let k = ChessKind(letter: uci.last!), ChessKind.promotions.contains(k) else { return nil }
            p = k
        }
        self.init(f, t, promotion: p)
    }

    var uci: String { from.name + to.name + (promotion.map { String($0.letter) } ?? "") }
}

/// 走一步时记下的东西，退回用
struct ChessUndo: Sendable {
    var captured: Int8
    var capturedAt: Int
    var castling: UInt8
    var ep: Int
    var halfmove: Int
    var hash: UInt64
}

/// 一盘棋怎么结束的
enum ChessOutcome: Hashable, Sendable {
    case checkmate(winner: ChessSide)
    case stalemate
    case insufficientMaterial
    case fiftyMoves
    case repetition

    var winner: ChessSide? {
        if case let .checkmate(w) = self { return w }
        return nil
    }

    /// 和棋的原因（给孩子看）
    var drawReason: String {
        switch self {
        case .checkmate: ""
        case .stalemate: "逼和：没被将军，却一步也走不了"
        case .insufficientMaterial: "双方剩下的子都将不死对方"
        case .fiftyMoves: "很久都没有吃子、也没有动兵"
        case .repetition: "同一个局面出现了三次"
        }
    }
}

struct ChessBoard: Sendable, Hashable {
    static let startFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    static let start = ChessBoard(fen: startFEN)!

    /// 64 格；正数白方，负数黑方，0 空。数值 = ChessKind.rawValue
    var cells = [Int8](repeating: 0, count: 64)
    var turn: ChessSide = .white
    /// 王车易位的权利：1 白短、2 白长、4 黑短、8 黑长
    var castling: UInt8 = 0
    /// 吃过路兵的目标格（刚刚冲两格的兵跳过的那一格），没有是 -1
    var ep = -1
    /// 多少步没有吃子、没有动兵（50 回合规则）
    var halfmove = 0
    var fullmove = 1
    /// 局面的 Zobrist 哈希（电脑搜索时认重复局面用）
    private(set) var hash: UInt64 = 0
    private(set) var whiteKing = -1
    private(set) var blackKing = -1

    init() { refresh() }

    /// 标准 FEN；后面几段可以省略（省略时没有易位权、没有过路兵）
    init?(fen: String) {
        let parts = fen.split(separator: " ").map(String.init)
        guard let placement = parts.first else { return nil }
        let rows = placement.split(separator: "/", omittingEmptySubsequences: false)
        guard rows.count == 8 else { return nil }
        for (r, row) in rows.enumerated() {
            let rank = 7 - r
            var f = 0
            for c in row {
                if let n = c.wholeNumberValue {
                    f += n
                } else if let k = ChessKind(letter: c) {
                    guard f < 8 else { return nil }
                    cells[rank * 8 + f] = ChessPiece(c.isUppercase ? .white : .black, k).code
                    f += 1
                } else {
                    return nil
                }
            }
            guard f == 8 else { return nil }
        }
        if parts.count > 1 {
            switch parts[1] {
            case "w": turn = .white
            case "b": turn = .black
            default: return nil
            }
        }
        if parts.count > 2, parts[2] != "-" {
            for c in parts[2] {
                switch c {
                case "K": castling |= 1
                case "Q": castling |= 2
                case "k": castling |= 4
                case "q": castling |= 8
                default: return nil
                }
            }
        }
        if parts.count > 3, parts[3] != "-" {
            guard let s = ChessSquare(parts[3]) else { return nil }
            ep = s.index
        }
        if parts.count > 4, let h = Int(parts[4]) { halfmove = h }
        if parts.count > 5, let n = Int(parts[5]) { fullmove = n }
        // 易位权要对得上棋盘上的王和车，否则去掉（免得写错的 FEN 让走法生成出错）
        let need: [(UInt8, Int, Int, Int8)] = [(1, 4, 7, 1), (2, 4, 0, 1), (4, 60, 63, -1), (8, 60, 56, -1)]
        for (bit, k, r, s) in need where castling & bit != 0 {
            if cells[k] != ChessKind.king.rawValue * s || cells[r] != ChessKind.rook.rawValue * s { castling &= ~bit }
        }
        refresh()
    }

    var fen: String { placementFEN + " " + stateFEN + " \(halfmove) \(fullmove)" }

    /// 只有子的摆法
    var placementFEN: String {
        var rows: [String] = []
        for rank in stride(from: 7, through: 0, by: -1) {
            var row = "", empty = 0
            for f in 0..<8 {
                if let p = ChessPiece(code: cells[rank * 8 + f]) {
                    if empty > 0 { row += "\(empty)"; empty = 0 }
                    let l = String(p.kind.letter)
                    row += p.side == .white ? l.uppercased() : l
                } else {
                    empty += 1
                }
            }
            if empty > 0 { row += "\(empty)" }
            rows.append(row)
        }
        return rows.joined(separator: "/")
    }

    /// FEN 中间的三段：谁走、易位权、过路兵
    private var stateFEN: String {
        var c = ""
        if castling & 1 != 0 { c += "K" }
        if castling & 2 != 0 { c += "Q" }
        if castling & 4 != 0 { c += "k" }
        if castling & 8 != 0 { c += "q" }
        return (turn == .white ? "w" : "b") + " " + (c.isEmpty ? "-" : c) + " " + (ep >= 0 ? ChessSquare(index: ep).name : "-")
    }

    /// 判断"同一个局面"用的钥匙：子的摆法、谁走、易位权，以及真的能吃过路兵时的那一格
    var repetitionKey: String {
        var c = ""
        if castling & 1 != 0 { c += "K" }
        if castling & 2 != 0 { c += "Q" }
        if castling & 4 != 0 { c += "k" }
        if castling & 8 != 0 { c += "q" }
        let epLegal = ep >= 0 && legalMoves().contains { $0.to.index == ep && abs(cells[$0.from.index]) == ChessKind.pawn.rawValue }
        return placementFEN + (turn == .white ? " w " : " b ") + c + (epLegal ? " " + ChessSquare(index: ep).name : "")
    }

    /// 改了 cells 以后重新算王的位置和哈希
    mutating func refresh() {
        whiteKing = cells.firstIndex(of: ChessKind.king.rawValue) ?? -1
        blackKing = cells.firstIndex(of: -ChessKind.king.rawValue) ?? -1
        var h: UInt64 = 0
        for i in 0..<64 where cells[i] != 0 { h ^= ChessZobrist.piece(cells[i], i) }
        h ^= ChessZobrist.castle[Int(castling)]
        if ep >= 0 { h ^= ChessZobrist.ep[ep & 7] }
        if turn == .black { h ^= ChessZobrist.side }
        hash = h
    }

    subscript(s: ChessSquare) -> ChessPiece? {
        get { ChessPiece(code: cells[s.index]) }
        set { cells[s.index] = newValue?.code ?? 0; refresh() }
    }

    subscript(file: Int, rank: Int) -> ChessPiece? { ChessPiece(code: cells[rank * 8 + file]) }

    func king(_ side: ChessSide) -> ChessSquare? {
        let k = side == .white ? whiteKing : blackKing
        return k >= 0 ? ChessSquare(index: k) : nil
    }

    var pieces: [(ChessSquare, ChessPiece)] {
        (0..<64).compactMap { i in ChessPiece(code: cells[i]).map { (ChessSquare(index: i), $0) } }
    }

    // MARK: 预先算好的走法表

    static let knightTargets: [[Int]] = (0..<64).map { s in
        [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)].compactMap { d in
            let f = (s & 7) + d.0, r = (s >> 3) + d.1
            return ChessSquare.inside(f, r) ? r * 8 + f : nil
        }
    }

    static let kingTargets: [[Int]] = (0..<64).map { s in
        [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)].compactMap { d in
            let f = (s & 7) + d.0, r = (s >> 3) + d.1
            return ChessSquare.inside(f, r) ? r * 8 + f : nil
        }
    }

    /// rays[s][d]：从 s 沿第 d 个方向走出去的格子（0…3 直线，4…7 斜线）
    static let rays: [[[Int]]] = (0..<64).map { s in
        [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)].map { d in
            var out: [Int] = []
            var f = (s & 7) + d.0, r = (s >> 3) + d.1
            while ChessSquare.inside(f, r) { out.append(r * 8 + f); f += d.0; r += d.1 }
            return out
        }
    }

    /// 走到或者离开这一格时，易位权还剩哪些
    static let castleMask: [UInt8] = (0..<64).map { s in
        switch s {
        case 0: 15 & ~2
        case 7: 15 & ~1
        case 4: 15 & ~3
        case 56: 15 & ~8
        case 63: 15 & ~4
        case 60: 15 & ~12
        default: 15
        }
    }

    // MARK: 攻击

    /// 格子 s 有没有被 by 这一方攻击（能被吃到）
    func attacked(_ s: Int, by: ChessSide) -> Bool {
        let sign = by.rawValue
        let f = s & 7
        let pawn = ChessKind.pawn.rawValue * sign
        if by == .white {
            if s >= 9, f > 0, cells[s - 9] == pawn { return true }
            if s >= 7, f < 7, cells[s - 7] == pawn { return true }
        } else {
            if s + 9 < 64, f < 7, cells[s + 9] == pawn { return true }
            if s + 7 < 64, f > 0, cells[s + 7] == pawn { return true }
        }
        let knight = ChessKind.knight.rawValue * sign
        for t in Self.knightTargets[s] where cells[t] == knight { return true }
        let king = ChessKind.king.rawValue * sign
        for t in Self.kingTargets[s] where cells[t] == king { return true }
        let queen = ChessKind.queen.rawValue * sign
        let rook = ChessKind.rook.rawValue * sign
        let bishop = ChessKind.bishop.rawValue * sign
        let rays = Self.rays[s]
        for d in 0..<8 {
            let straight = d < 4
            for t in rays[d] {
                let c = cells[t]
                if c == 0 { continue }
                if c == queen || (straight ? c == rook : c == bishop) { return true }
                break
            }
        }
        return false
    }

    func attacked(_ s: ChessSquare, by: ChessSide) -> Bool { attacked(s.index, by: by) }

    /// 攻击格子 s 的 by 方的全部棋子
    func attackers(_ s: Int, by: ChessSide) -> [Int] {
        var out: [Int] = []
        let sign = by.rawValue
        let f = s & 7
        let pawn = ChessKind.pawn.rawValue * sign
        if by == .white {
            if s >= 9, f > 0, cells[s - 9] == pawn { out.append(s - 9) }
            if s >= 7, f < 7, cells[s - 7] == pawn { out.append(s - 7) }
        } else {
            if s + 9 < 64, f < 7, cells[s + 9] == pawn { out.append(s + 9) }
            if s + 7 < 64, f > 0, cells[s + 7] == pawn { out.append(s + 7) }
        }
        for t in Self.knightTargets[s] where cells[t] == ChessKind.knight.rawValue * sign { out.append(t) }
        for t in Self.kingTargets[s] where cells[t] == ChessKind.king.rawValue * sign { out.append(t) }
        for d in 0..<8 {
            for t in Self.rays[s][d] {
                let c = cells[t]
                if c == 0 { continue }
                let k = abs(c), mine = (c > 0) == (sign > 0)
                if mine, k == ChessKind.queen.rawValue || k == (d < 4 ? ChessKind.rook.rawValue : ChessKind.bishop.rawValue) { out.append(t) }
                break
            }
        }
        return out
    }

    func inCheck(_ side: ChessSide) -> Bool {
        let k = side == .white ? whiteKing : blackKing
        return k >= 0 && attacked(k, by: side.other)
    }

    var inCheck: Bool { inCheck(turn) }

    // MARK: 走法

    /// 不管走完自己的王会不会被吃的走法。capturesOnly：只要吃子和升后（电脑的静态搜索用）
    func pseudoMoves(into out: inout [ChessMove], capturesOnly: Bool = false) {
        let mine: Int8 = turn.rawValue
        for s in 0..<64 {
            let c = cells[s]
            if c != 0, (c > 0) == (mine > 0) { pseudoMoves(from: s, into: &out, capturesOnly: capturesOnly) }
        }
    }

    func pseudoMoves(from s: Int, into out: inout [ChessMove], capturesOnly: Bool = false) {
        let c = cells[s]
        guard c != 0 else { return }
        let white = c > 0
        let kind = ChessKind(rawValue: abs(c))!
        @inline(__always) func enemy(_ t: Int) -> Bool { let x = cells[t]; return x != 0 && (x > 0) != white }

        switch kind {
        case .pawn:
            let dir = white ? 8 : -8
            let startRank = white ? 1 : 6
            let lastRank = white ? 7 : 0
            let f = s & 7
            func add(_ t: Int) {
                if t >> 3 == lastRank {
                    if capturesOnly {
                        out.append(ChessMove(s, t, promotion: .queen))
                    } else {
                        for k in ChessKind.promotions { out.append(ChessMove(s, t, promotion: k)) }
                    }
                } else {
                    out.append(ChessMove(s, t))
                }
            }
            let t = s + dir
            if t >= 0, t < 64, cells[t] == 0 {
                if !capturesOnly || t >> 3 == lastRank { add(t) }
                if !capturesOnly, s >> 3 == startRank, cells[t + dir] == 0 { out.append(ChessMove(s, t + dir)) }
            }
            for df in [-1, 1] {
                let nf = f + df
                guard nf >= 0, nf < 8 else { continue }
                let x = s + dir + df
                guard x >= 0, x < 64 else { continue }
                if enemy(x) { add(x) } else if x == ep, cells[x] == 0 { out.append(ChessMove(s, x)) }
            }
        case .knight:
            for t in Self.knightTargets[s] where cells[t] == 0 ? !capturesOnly : enemy(t) { out.append(ChessMove(s, t)) }
        case .king:
            for t in Self.kingTargets[s] where cells[t] == 0 ? !capturesOnly : enemy(t) { out.append(ChessMove(s, t)) }
            if !capturesOnly { castlingMoves(from: s, into: &out) }
        case .bishop, .rook, .queen:
            let dirs = kind == .bishop ? 4..<8 : kind == .rook ? 0..<4 : 0..<8
            for d in dirs {
                for t in Self.rays[s][d] {
                    let x = cells[t]
                    if x == 0 {
                        if !capturesOnly { out.append(ChessMove(s, t)) }
                    } else {
                        if (x > 0) != white { out.append(ChessMove(s, t)) }
                        break
                    }
                }
            }
        }
    }

    private func castlingMoves(from s: Int, into out: inout [ChessMove]) {
        let white = cells[s] > 0
        let home = white ? 4 : 60
        guard s == home else { return }
        let shortBit: UInt8 = white ? 1 : 4, longBit: UInt8 = white ? 2 : 8
        guard castling & (shortBit | longBit) != 0 else { return }
        let rook = ChessKind.rook.rawValue * (white ? 1 : -1)
        let enemy: ChessSide = white ? .black : .white
        guard !attacked(home, by: enemy) else { return }
        if castling & shortBit != 0, cells[home + 1] == 0, cells[home + 2] == 0, cells[home + 3] == rook,
           !attacked(home + 1, by: enemy), !attacked(home + 2, by: enemy) {
            out.append(ChessMove(home, home + 2))
        }
        if castling & longBit != 0, cells[home - 1] == 0, cells[home - 2] == 0, cells[home - 3] == 0, cells[home - 4] == rook,
           !attacked(home - 1, by: enemy), !attacked(home - 2, by: enemy) {
            out.append(ChessMove(home, home - 2))
        }
    }

    func pseudoMoves(from s: ChessSquare) -> [ChessMove] {
        var out: [ChessMove] = []
        pseudoMoves(from: s.index, into: &out)
        return out
    }

    func legalMoves() -> [ChessMove] {
        var out: [ChessMove] = []
        pseudoMoves(into: &out)
        var b = self
        let side = turn
        return out.filter { m in
            let u = b.make(m)
            let ok = !b.inCheck(side)
            b.unmake(m, u)
            return ok
        }
    }

    func legalMoves(from s: ChessSquare) -> [ChessMove] {
        guard let p = self[s], p.side == turn else { return [] }
        var out: [ChessMove] = []
        pseudoMoves(from: s.index, into: &out)
        var b = self
        let side = turn
        return out.filter { m in
            let u = b.make(m)
            let ok = !b.inCheck(side)
            b.unmake(m, u)
            return ok
        }
    }

    func isLegal(_ m: ChessMove) -> Bool { legalMoves(from: m.from).contains(m) }

    var hasLegalMove: Bool {
        var out: [ChessMove] = []
        pseudoMoves(into: &out)
        var b = self
        let side = turn
        for m in out {
            let u = b.make(m)
            let ok = !b.inCheck(side)
            b.unmake(m, u)
            if ok { return true }
        }
        return false
    }

    // MARK: 走子

    func isCastle(_ m: ChessMove) -> Bool {
        abs(cells[m.from.index]) == ChessKind.king.rawValue && abs(m.to.index - m.from.index) == 2
    }

    func isEnPassant(_ m: ChessMove) -> Bool {
        abs(cells[m.from.index]) == ChessKind.pawn.rawValue && m.to.index == ep && cells[m.to.index] == 0
            && m.from.file != m.to.file
    }

    func isCapture(_ m: ChessMove) -> Bool { cells[m.to.index] != 0 || isEnPassant(m) }

    /// 被吃掉的子（包括吃过路兵）
    func capturedPiece(_ m: ChessMove) -> ChessPiece? {
        if isEnPassant(m) { return ChessPiece(turn.other, .pawn) }
        return self[m.to]
    }

    /// 走一步（不检查合法）
    @discardableResult
    mutating func make(_ m: ChessMove) -> ChessUndo {
        let f = m.from.index, t = m.to.index
        let p = cells[f]
        let sign: Int8 = p > 0 ? 1 : -1
        let kind = abs(p)
        var u = ChessUndo(captured: cells[t], capturedAt: t, castling: castling, ep: ep, halfmove: halfmove, hash: hash)
        var h = hash ^ ChessZobrist.piece(p, f)
        if u.captured != 0 {
            h ^= ChessZobrist.piece(u.captured, t)
        } else if kind == ChessKind.pawn.rawValue, t == ep, (f & 7) != (t & 7) {
            let at = t - 8 * Int(sign)
            u.captured = cells[at]
            u.capturedAt = at
            h ^= ChessZobrist.piece(cells[at], at)
            cells[at] = 0
        }
        cells[f] = 0
        let placed = m.promotion.map { $0.rawValue * sign } ?? p
        cells[t] = placed
        h ^= ChessZobrist.piece(placed, t)
        if kind == ChessKind.king.rawValue {
            if sign > 0 { whiteKing = t } else { blackKing = t }
            if abs(t - f) == 2 {
                let (rf, rt) = t > f ? (f + 3, f + 1) : (f - 4, f - 1)
                let r = cells[rf]
                h ^= ChessZobrist.piece(r, rf) ^ ChessZobrist.piece(r, rt)
                cells[rt] = r
                cells[rf] = 0
            }
        }
        if u.captured == ChessKind.king.rawValue * -sign {
            // 只在不合法的试探里才会吃到王
            if sign > 0 { blackKing = -1 } else { whiteKing = -1 }
        }
        h ^= ChessZobrist.castle[Int(castling)]
        castling &= Self.castleMask[f] & Self.castleMask[t]
        h ^= ChessZobrist.castle[Int(castling)]
        if ep >= 0 { h ^= ChessZobrist.ep[ep & 7] }
        ep = -1
        if kind == ChessKind.pawn.rawValue, abs(t - f) == 16 {
            ep = (f + t) / 2
            h ^= ChessZobrist.ep[ep & 7]
        }
        halfmove = (kind == ChessKind.pawn.rawValue || u.captured != 0) ? 0 : halfmove + 1
        if turn == .black { fullmove += 1 }
        turn = turn.other
        hash = h ^ ChessZobrist.side
        return u
    }

    mutating func unmake(_ m: ChessMove, _ u: ChessUndo) {
        turn = turn.other
        if turn == .black { fullmove -= 1 }
        let f = m.from.index, t = m.to.index
        let placed = cells[t]
        let sign: Int8 = placed > 0 ? 1 : -1
        let original = m.promotion != nil ? ChessKind.pawn.rawValue * sign : placed
        cells[f] = original
        cells[t] = 0
        if u.captured != 0 { cells[u.capturedAt] = u.captured }
        if abs(original) == ChessKind.king.rawValue {
            if sign > 0 { whiteKing = f } else { blackKing = f }
            if abs(t - f) == 2 {
                let (rf, rt) = t > f ? (f + 3, f + 1) : (f - 4, f - 1)
                cells[rf] = cells[rt]
                cells[rt] = 0
            }
        }
        if u.captured == ChessKind.king.rawValue * -sign {
            if sign > 0 { blackKing = u.capturedAt } else { whiteKing = u.capturedAt }
        }
        castling = u.castling
        ep = u.ep
        halfmove = u.halfmove
        hash = u.hash
    }

    func applying(_ m: ChessMove) -> ChessBoard {
        var b = self
        b.make(m)
        return b
    }

    // MARK: 结局

    var isCheckmate: Bool { inCheck(turn) && !hasLegalMove }
    var isStalemate: Bool { !inCheck(turn) && !hasLegalMove }

    /// 双方都不可能将死对方：只剩王；王 + 一个马或象；或者只剩王和象、而且所有象都在同一种颜色的格子上
    var insufficientMaterial: Bool {
        var minors = 0, knights = 0
        var bishopColors = Set<Bool>()
        for i in 0..<64 {
            let c = abs(cells[i])
            switch c {
            case 0, ChessKind.king.rawValue: continue
            case ChessKind.knight.rawValue: minors += 1; knights += 1
            case ChessKind.bishop.rawValue: minors += 1; bishopColors.insert(ChessSquare(index: i).isLight)
            default: return false
            }
        }
        if minors <= 1 { return true }
        return knights == 0 && bishopColors.count == 1
    }

    /// 只看这一个局面能判出来的结局（三次重复要看整盘棋，见 ChessMatch）
    var outcome: ChessOutcome? {
        if !hasLegalMove { return inCheck(turn) ? .checkmate(winner: turn.other) : .stalemate }
        if insufficientMaterial { return .insufficientMaterial }
        if halfmove >= 100 { return .fiftyMoves }
        return nil
    }

    func givesCheck(_ m: ChessMove) -> Bool { applying(m).inCheck }
    func isMate(after m: ChessMove) -> Bool { applying(m).isCheckmate }
    func matesInOne() -> [ChessMove] { legalMoves().filter { isMate(after: $0) } }

    // MARK: 走法计数（对照标准 perft，测试用）

    func perft(_ depth: Int) -> Int {
        var b = self
        return b.perftInPlace(depth)
    }

    private mutating func perftInPlace(_ depth: Int) -> Int {
        if depth == 0 { return 1 }
        var moves: [ChessMove] = []
        pseudoMoves(into: &moves)
        let side = turn
        var n = 0
        for m in moves {
            let u = make(m)
            if !inCheck(side) { n += depth == 1 ? 1 : perftInPlace(depth - 1) }
            unmake(m, u)
        }
        return n
    }
}

// MARK: - 记谱

extension ChessBoard {
    /// 标准代数记谱（在走之前的局面上调用）：Nf3、exd5、O-O、e8=Q+、Qxf7#
    func san(_ m: ChessMove) -> String {
        guard let p = self[m.from] else { return m.uci }
        var s: String
        if isCastle(m) {
            s = m.to.file > m.from.file ? "O-O" : "O-O-O"
        } else {
            let cap = isCapture(m)
            if p.kind == .pawn {
                s = cap ? String(m.from.name.first!) + "x" : ""
            } else {
                s = String(p.kind.letter).uppercased() + disambiguation(m, p) + (cap ? "x" : "")
            }
            s += m.to.name
            if let k = m.promotion { s += "=" + String(k.letter).uppercased() }
        }
        let after = applying(m)
        if after.inCheck { s += after.hasLegalMove ? "+" : "#" }
        return s
    }

    private func disambiguation(_ m: ChessMove, _ p: ChessPiece) -> String {
        let others = legalMoves().filter { $0.to == m.to && $0.from != m.from && self[$0.from] == p }.map(\.from)
        guard !others.isEmpty else { return "" }
        let fileName = String(m.from.name.first!), rankName = String(m.from.name.last!)
        if !others.contains(where: { $0.file == m.from.file }) { return fileName }
        if !others.contains(where: { $0.rank == m.from.rank }) { return rankName }
        return fileName + rankName
    }

    /// 给家长和孩子看的中文记法：马f3、兵吃d5、短易位、兵e8升后、后吃f7 将死
    func chinese(_ m: ChessMove) -> String {
        guard let p = self[m.from] else { return m.uci }
        var s: String
        if isCastle(m) {
            s = m.to.file > m.from.file ? "短易位" : "长易位"
        } else {
            s = p.kind.chinese + (isCapture(m) ? "吃" : "") + m.to.name
            if let k = m.promotion { s += "升" + k.chinese }
        }
        let after = applying(m)
        if after.inCheck { s += after.hasLegalMove ? " 将军" : " 将死" }
        return s
    }
}

// MARK: - 一整盘棋：走过的每一步、重复局面、结局

struct ChessMatch: Sendable {
    let start: ChessBoard
    private(set) var board: ChessBoard
    private(set) var moves: [ChessMove] = []
    private(set) var undos: [ChessUndo] = []
    /// 每一步吃掉的子（没吃是 0）
    private(set) var captures: [Int8] = []
    private var keys: [String]
    /// 走过的局面的哈希（电脑认重复局面用）
    private(set) var hashes: [UInt64]

    init(_ start: ChessBoard = .start) {
        self.start = start
        board = start
        keys = [start.repetitionKey]
        hashes = [start.hash]
    }

    mutating func play(_ m: ChessMove) {
        let cap = board.capturedPiece(m)?.code ?? 0
        let u = board.make(m)
        moves.append(m)
        undos.append(u)
        captures.append(cap)
        keys.append(board.repetitionKey)
        hashes.append(board.hash)
    }

    @discardableResult
    mutating func takeBack() -> ChessMove? {
        guard let m = moves.popLast(), let u = undos.popLast() else { return nil }
        captures.removeLast()
        keys.removeLast()
        hashes.removeLast()
        board.unmake(m, u)
        return m
    }

    /// 这个局面一共出现了几次
    var repetitions: Int {
        guard let k = keys.last else { return 0 }
        return keys.filter { $0 == k }.count
    }

    var outcome: ChessOutcome? {
        if let o = board.outcome { return o }
        if repetitions >= 3 { return .repetition }
        return nil
    }

    /// 第 i 步之前的局面
    func position(before i: Int) -> ChessBoard {
        var b = start
        for m in moves.prefix(i) { b.make(m) }
        return b
    }
}

// MARK: - Zobrist 哈希

enum ChessZobrist {
    private static func table(_ n: Int, seed: UInt64) -> [UInt64] {
        var s = seed
        return (0..<n).map { _ in
            s &+= 0x9E37_79B9_7F4A_7C15
            var z = s
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    static let pieces = table(13 * 64, seed: 2024)
    static let castle = table(16, seed: 77)
    static let ep = table(8, seed: 99)
    static let side: UInt64 = table(1, seed: 5)[0]

    @inline(__always) static func piece(_ code: Int8, _ sq: Int) -> UInt64 { pieces[(Int(code) + 6) * 64 + sq] }
}
