import Foundation

// 编程的程序：积木、程序、文字写法（解析 / 打印）、积木数、套法的规矩、编辑（放进去 / 拿出来）、左右上下翻。只用 Foundation。
//
// 文字写法（关卡数据、测试、调试参数都用它，见 docs/tutorial-coding.md）：
//   U D L R           往上 / 往下 / 往左 / 往右走一格
//   3[R U]            重复 3 次（2–9）
//   S  T              用绝招 ★ / 绝招 ◆
//   ?b[U]  ?y[D]      如果踩着蓝花 / 黄花
//   *[R ?b[U]]        一直重复
//   各栏用分号隔开：   S 2[S R] ; S=R R U ; T=D D

enum CodingDir: Character, CaseIterable, Hashable {
    case up = "U", down = "D", left = "L", right = "R"

    var dx: Int { self == .left ? -1 : self == .right ? 1 : 0 }
    var dy: Int { self == .up ? -1 : self == .down ? 1 : 0 }

    /// 左右翻
    var flippedX: CodingDir { self == .left ? .right : self == .right ? .left : self }
    /// 上下翻
    var flippedY: CodingDir { self == .up ? .down : self == .down ? .up : self }
}

/// 绝招 ★（S）、绝招 ◆（T）
enum CodingProc: Int, CaseIterable, Hashable {
    case star = 1, diamond = 2

    var letter: Character { self == .star ? "S" : "T" }
    /// 在程序里是第几栏（0 是主程序）
    var track: Int { rawValue }
    init?(letter: Character) {
        switch letter {
        case "S": self = .star
        case "T": self = .diamond
        default: return nil
        }
    }
}

/// 蓝花、黄花
enum CodingFlower: Character, CaseIterable, Hashable {
    case blue = "b", yellow = "y"
}

indirect enum CodingBlock: Hashable {
    case move(CodingDir)
    case call(CodingProc)
    case loop(Int, [CodingBlock])
    case when(CodingFlower, [CodingBlock])
    case forever([CodingBlock])

    var piece: CodingPiece {
        switch self {
        case let .move(d): .arrow(d)
        case let .call(p): .call(p)
        case .loop: .loop
        case let .when(f, _): .when(f)
        case .forever: .forever
        }
    }

    var body: [CodingBlock]? {
        switch self {
        case let .loop(_, b), let .when(_, b), let .forever(b): b
        default: nil
        }
    }

    func withBody(_ b: [CodingBlock]) -> CodingBlock {
        switch self {
        case let .loop(n, _): .loop(n, b)
        case let .when(f, _): .when(f, b)
        case .forever: .forever(b)
        default: self
        }
    }

    /// 积木数：自己 1 块，加上里面的
    var size: Int { 1 + (body?.reduce(0) { $0 + $1.size } ?? 0) }

    func mapDirs(_ f: (CodingDir) -> CodingDir) -> CodingBlock {
        switch self {
        case let .move(d): .move(f(d))
        case .call: self
        case let .loop(n, b): .loop(n, b.map { $0.mapDirs(f) })
        case let .when(c, b): .when(c, b.map { $0.mapDirs(f) })
        case let .forever(b): .forever(b.map { $0.mapDirs(f) })
        }
    }
}

/// 积木盒里的一种积木（放进程序以前，没有次数、没有里面的东西）
enum CodingPiece: Hashable {
    case arrow(CodingDir)
    case call(CodingProc)
    case loop
    case when(CodingFlower)
    case forever

    var isContainer: Bool {
        switch self {
        case .loop, .when, .forever: true
        default: false
        }
    }

    /// 刚放进去时的样子：重复默认 2 次
    var fresh: CodingBlock {
        switch self {
        case let .arrow(d): .move(d)
        case let .call(p): .call(p)
        case .loop: .loop(2, [])
        case let .when(f): .when(f, [])
        case .forever: .forever([])
        }
    }

    /// 积木盒的文字写法：U D L R rep S T ?b ?y *
    var token: String {
        switch self {
        case let .arrow(d): String(d.rawValue)
        case let .call(p): String(p.letter)
        case .loop: "rep"
        case let .when(f): "?\(f.rawValue)"
        case .forever: "*"
        }
    }

    init?(token: String) {
        switch token {
        case "U", "D", "L", "R": self = .arrow(CodingDir(rawValue: token.first!)!)
        case "S", "T": self = .call(CodingProc(letter: token.first!)!)
        case "rep": self = .loop
        case "?b": self = .when(.blue)
        case "?y": self = .when(.yellow)
        case "*": self = .forever
        default: return nil
        }
    }

    /// 积木盒里摆的顺序
    var order: Int {
        switch self {
        case .arrow(.up): 0
        case .arrow(.down): 1
        case .arrow(.left): 2
        case .arrow(.right): 3
        case .loop: 4
        case .call(.star): 5
        case .call(.diamond): 6
        case .when(.blue): 7
        case .when(.yellow): 8
        case .forever: 9
        }
    }

    static func palette(_ s: String) -> [CodingPiece] {
        s.split(separator: " ").compactMap { CodingPiece(token: String($0)) }.sorted { $0.order < $1.order }
    }
}

/// 一个程序：第 0 栏是主程序，第 1 栏是绝招 ★，第 2 栏是绝招 ◆（没有的就是空的）
struct CodingProgram: Hashable, CustomStringConvertible {
    var tracks: [[CodingBlock]] = [[], [], []]

    init(tracks: [[CodingBlock]] = [[], [], []]) {
        var t = tracks
        while t.count < 3 { t.append([]) }
        self.tracks = Array(t.prefix(3))
    }

    var main: [CodingBlock] { tracks[0] }
    func body(of p: CodingProc) -> [CodingBlock] { tracks[p.track] }

    /// 积木数：所有栏里的所有积木，包括壳
    var size: Int { tracks.reduce(0) { $0 + $1.reduce(0) { $0 + $1.size } } }
    var isEmpty: Bool { tracks.allSatisfy(\.isEmpty) }

    /// 用到的积木种类（四个方向分开算）
    var pieces: Set<CodingPiece> {
        var s = Set<CodingPiece>()
        func walk(_ l: [CodingBlock]) { for b in l { s.insert(b.piece); if let x = b.body { walk(x) } } }
        tracks.forEach(walk)
        return s
    }

    func mapDirs(_ f: (CodingDir) -> CodingDir) -> CodingProgram {
        CodingProgram(tracks: tracks.map { $0.map { $0.mapDirs(f) } })
    }

    /// 练一练的四种样子：0 原样，1 左右翻，2 上下翻，3 都翻
    func flipped(_ k: Int) -> CodingProgram {
        mapDirs { d in
            var e = d
            if k & 1 != 0 { e = e.flippedX }
            if k & 2 != 0 { e = e.flippedY }
            return e
        }
    }

    // MARK: 文字写法

    var description: String { text }

    var text: String {
        var parts = [Self.text(tracks[0])]
        for p in CodingProc.allCases where !tracks[p.track].isEmpty {
            parts.append("\(p.letter)=" + Self.text(tracks[p.track]))
        }
        return parts.joined(separator: " ; ")
    }

    static func text(_ list: [CodingBlock]) -> String { list.map(text).joined(separator: " ") }

    static func text(_ b: CodingBlock) -> String {
        switch b {
        case let .move(d): String(d.rawValue)
        case let .call(p): String(p.letter)
        case let .loop(n, x): "\(n)[\(text(x))]"
        case let .when(f, x): "?\(f.rawValue)[\(text(x))]"
        case let .forever(x): "*[\(text(x))]"
        }
    }

    /// 解析文字写法；写错了返回 nil
    init?(text: String) {
        var t: [[CodingBlock]] = [[], [], []]
        for (i, raw) in text.split(separator: ";", omittingEmptySubsequences: false).enumerated() {
            var s = raw.trimmingCharacters(in: .whitespaces)
            var track = 0
            if s.count >= 2, let p = CodingProc(letter: s.first!), s.dropFirst().first == "=" {
                track = p.track
                s = String(s.dropFirst(2))
            } else if i > 0, !s.isEmpty {
                return nil
            }
            guard let list = Self.parseList(Array(s)) else { return nil }
            if i > 0 && track == 0 { if list.isEmpty { continue } else { return nil } }
            t[track] = list
        }
        self.init(tracks: t)
    }

    private static func parseList(_ c: [Character]) -> [CodingBlock]? {
        var i = 0
        guard let l = parseSeq(c, &i), i == c.count else { return nil }
        return l
    }

    private static func parseSeq(_ c: [Character], _ i: inout Int) -> [CodingBlock]? {
        var out: [CodingBlock] = []
        while true {
            while i < c.count, c[i] == " " { i += 1 }
            guard i < c.count, c[i] != "]" else { return out }
            let ch = c[i]
            if let d = CodingDir(rawValue: ch) {
                out.append(.move(d)); i += 1
            } else if let p = CodingProc(letter: ch) {
                out.append(.call(p)); i += 1
            } else if ch.isNumber, let n = ch.wholeNumberValue {
                i += 1
                guard i < c.count, c[i] == "[" else { return nil }
                i += 1
                guard let b = parseSeq(c, &i), i < c.count, c[i] == "]" else { return nil }
                i += 1
                out.append(.loop(n, b))
            } else if ch == "?" {
                guard i + 2 < c.count, let f = CodingFlower(rawValue: c[i + 1]), c[i + 2] == "[" else { return nil }
                i += 3
                guard let b = parseSeq(c, &i), i < c.count, c[i] == "]" else { return nil }
                i += 1
                out.append(.when(f, b))
            } else if ch == "*" {
                guard i + 1 < c.count, c[i + 1] == "[" else { return nil }
                i += 2
                guard let b = parseSeq(c, &i), i < c.count, c[i] == "]" else { return nil }
                i += 1
                out.append(.forever(b))
            } else {
                return nil
            }
        }
    }
}

// MARK: - 位置

/// 程序里一块积木在哪儿：第几栏，然后一层一层往里的序号。[2, 0] = 这一栏第 3 块（一个壳）里的第 1 块
struct CodingRef: Hashable, CustomStringConvertible {
    var track: Int
    var path: [Int]

    var description: String { "\(track):" + path.map(String.init).joined(separator: ".") }

    /// 装着它的那一层（栏本身，或者外面的壳）
    var parent: CodingSlot { CodingSlot(track: track, container: Array(path.dropLast()), index: path.last ?? 0) }
}

/// 一个空位：放在哪一层（container 是那个壳的路径，[] 是栏本身）的第几个位置前面
struct CodingSlot: Hashable {
    var track: Int
    var container: [Int]
    var index: Int

    var ref: CodingRef { CodingRef(track: track, path: container + [index]) }
    /// 装着这一层的那个壳（栏本身就是 nil）
    var containerRef: CodingRef? { container.isEmpty ? nil : CodingRef(track: track, path: container) }
}

extension CodingProgram {
    func block(at r: CodingRef) -> CodingBlock? {
        guard tracks.indices.contains(r.track), let first = r.path.first, tracks[r.track].indices.contains(first) else { return nil }
        var b = tracks[r.track][first]
        for i in r.path.dropFirst() {
            guard let body = b.body, body.indices.contains(i) else { return nil }
            b = body[i]
        }
        return b
    }

    /// 某一层里的积木（栏本身或者一个壳的里面）
    func list(track: Int, container: [Int]) -> [CodingBlock]? {
        guard tracks.indices.contains(track) else { return nil }
        if container.isEmpty { return tracks[track] }
        return block(at: CodingRef(track: track, path: container))?.body
    }

    private static func edit(_ list: inout [CodingBlock], _ path: ArraySlice<Int>, _ f: (inout [CodingBlock]) -> Bool) -> Bool {
        guard let i = path.first else { return f(&list) }
        guard list.indices.contains(i), var body = list[i].body else { return false }
        let ok = edit(&body, path.dropFirst(), f)
        if ok { list[i] = list[i].withBody(body) }
        return ok
    }

    /// 改某一层（栏或者壳里面）
    mutating func editList(track: Int, container: [Int], _ f: (inout [CodingBlock]) -> Bool) -> Bool {
        guard tracks.indices.contains(track) else { return false }
        return Self.edit(&tracks[track], container[...], f)
    }

    mutating func insert(_ b: CodingBlock, at s: CodingSlot) -> Bool {
        editList(track: s.track, container: s.container) { l in
            guard s.index >= 0, s.index <= l.count else { return false }
            l.insert(b, at: s.index)
            return true
        }
    }

    @discardableResult
    mutating func remove(at r: CodingRef) -> CodingBlock? {
        guard let old = block(at: r) else { return nil }
        let s = r.parent
        _ = editList(track: s.track, container: s.container) { l in
            guard l.indices.contains(s.index) else { return false }
            l.remove(at: s.index)
            return true
        }
        return old
    }

    mutating func replace(at r: CodingRef, with b: CodingBlock) -> Bool {
        let s = r.parent
        return editList(track: s.track, container: s.container) { l in
            guard l.indices.contains(s.index) else { return false }
            l[s.index] = b
            return true
        }
    }

    /// 全部积木的位置（先外后里、从左到右，一栏一栏来）
    var allRefs: [CodingRef] {
        var out: [CodingRef] = []
        func walk(_ l: [CodingBlock], _ t: Int, _ p: [Int]) {
            for (i, b) in l.enumerated() {
                out.append(CodingRef(track: t, path: p + [i]))
                if let x = b.body { walk(x, t, p + [i]) }
            }
        }
        for t in tracks.indices { walk(tracks[t], t, []) }
        return out
    }
}

// MARK: - 一关给的格子和积木

/// 一关（或者一道题）规定的东西：积木盒里有什么、每一层有几格
struct CodingLimits: Hashable {
    var palette: [CodingPiece]
    /// 主程序几格
    var main: Int
    /// 重复、一直重复里面几格
    var loop: Int = 3
    /// 绝招那一栏几格
    var proc: Int = 4
    /// 如果里面几格（最多 2）
    var when: Int = 1

    var hasProc: Bool { palette.contains(.call(.star)) || palette.contains(.call(.diamond)) }
    /// 程序有几栏：主程序、★、◆
    var trackCount: Int { palette.contains(.call(.diamond)) ? 3 : hasProc ? 2 : 1 }

    /// 这一层最多几格
    func capacity(track: Int, container: CodingBlock?) -> Int {
        switch container {
        case nil: track == 0 ? main : proc
        case .loop?, .forever?: loop
        case .when?: when
        default: 0
        }
    }

    /// 写法 "main=6 loop=3 proc=4 when=1 | U D L R rep S"
    init(palette: [CodingPiece], main: Int, loop: Int = 3, proc: Int = 4, when: Int = 1) {
        self.palette = palette
        self.main = main
        self.loop = loop
        self.proc = proc
        self.when = when
    }

    init?(spec: String) {
        let halves = spec.split(separator: "|", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard halves.count == 2 else { return nil }
        var v: [String: Int] = [:]
        for kv in halves[0].split(separator: " ") {
            let p = kv.split(separator: "=")
            guard p.count == 2, let n = Int(p[1]) else { return nil }
            v[String(p[0])] = n
        }
        guard let m = v["main"] else { return nil }
        self.init(palette: CodingPiece.palette(halves[1]), main: m, loop: v["loop"] ?? 3, proc: v["proc"] ?? 4, when: v["when"] ?? 1)
    }

    var spec: String {
        "main=\(main) loop=\(loop) proc=\(proc) when=\(when) | " + palette.map(\.token).joined(separator: " ")
    }
}

/// 套法的规矩（docs/tutorial-coding.md「积木」一节）：
///   重复里面可以放箭头、绝招、如果，不能再放重复（一直重复也不行）；
///   绝招里面可以放箭头、重复、如果，不能放绝招；
///   如果里面只能放箭头或绝招；
///   一直重复只能放在主程序里，而且是最后一块。
enum CodingRules {
    enum Refusal: Equatable {
        /// 这一层满了
        case full
        /// 这一块不能放在这里
        case notHere
        /// 积木盒里没有
        case notInPalette
    }

    /// 在 slot 这个位置能不能放进 piece
    static func check(_ piece: CodingPiece, at slot: CodingSlot, in program: CodingProgram, limits: CodingLimits) -> Refusal? {
        guard limits.palette.contains(piece) else { return .notInPalette }
        guard let list = program.list(track: slot.track, container: slot.container) else { return .notHere }
        // 一路往外的壳
        var shells: [CodingBlock] = []
        for k in 0..<slot.container.count {
            if let b = program.block(at: CodingRef(track: slot.track, path: Array(slot.container.prefix(k + 1)))) { shells.append(b) }
        }
        let inProc = slot.track != 0
        let inLoop = shells.contains { if case .loop = $0 { return true }; if case .forever = $0 { return true }; return false }
        let inWhen = shells.contains { if case .when = $0 { return true }; return false }
        // 主程序里一直重复后面不能再放东西
        if slot.container.isEmpty, slot.track == 0,
           list.prefix(slot.index).contains(where: { if case .forever = $0 { return true }; return false }) {
            return .notHere
        }
        switch piece {
        case .arrow:
            break
        case .call:
            if inProc { return .notHere }
        case .loop:
            if inLoop || inWhen { return .notHere }
        case .when:
            if inWhen { return .notHere }
        case .forever:
            if inProc || !shells.isEmpty || slot.index != list.count { return .notHere }
            if list.contains(where: { if case .forever = $0 { return true }; return false }) { return .notHere }
        }
        let cap = limits.capacity(track: slot.track, container: shells.last)
        if list.count >= cap { return .full }
        return nil
    }

    /// 整个程序合不合规矩、放不放得进格子（关卡数据、参考答案、调试参数里的程序都要过这一关）
    static func fits(_ p: CodingProgram, _ limits: CodingLimits) -> Bool {
        for t in p.tracks.indices where t >= limits.trackCount && !p.tracks[t].isEmpty { return false }
        func ok(_ l: [CodingBlock], track: Int, shells: [CodingBlock]) -> Bool {
            if l.count > limits.capacity(track: track, container: shells.last) { return false }
            let inProc = track != 0
            let inLoop = shells.contains { if case .loop = $0 { return true }; if case .forever = $0 { return true }; return false }
            let inWhen = shells.contains { if case .when = $0 { return true }; return false }
            for (i, b) in l.enumerated() {
                guard limits.palette.contains(b.piece) else { return false }
                switch b {
                case .move: break
                case .call: if inProc { return false }
                case let .loop(n, _): if inLoop || inWhen || !(2...9).contains(n) { return false }
                case .when: if inWhen { return false }
                case .forever: if inProc || !shells.isEmpty || i != l.count - 1 { return false }
                }
                if let x = b.body, !ok(x, track: track, shells: shells + [b]) { return false }
            }
            return true
        }
        return p.tracks.indices.allSatisfy { ok(p.tracks[$0], track: $0, shells: []) }
    }
}
