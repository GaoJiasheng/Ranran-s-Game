import Foundation

// 围棋规则（中国规则）：落子、提子、禁入点（不能自杀）、打劫（不能马上提回）、数子。
// 坐标和五子棋教学一样："c3" = 第 c 列、从上往下第 3 行。格子下标 i = y * size + x。

enum GoStone: Int8, Sendable, Codable {
    case black = 1, white = 2
    var other: GoStone { self == .black ? .white : .black }
    var name: String { self == .black ? "黑棋" : "白棋" }
}

/// 每种棋盘大小的邻点表，所有棋盘共用（只读）
final class GoGeometry: @unchecked Sendable {
    let size: Int
    /// 每个点 4 个邻点，没有的填 -1
    let nb: [Int]

    private init(_ size: Int) {
        self.size = size
        var nb = [Int](repeating: -1, count: size * size * 4)
        for i in 0..<(size * size) {
            let x = i % size, y = i / size
            if x > 0 { nb[i * 4] = i - 1 }
            if x < size - 1 { nb[i * 4 + 1] = i + 1 }
            if y > 0 { nb[i * 4 + 2] = i - size }
            if y < size - 1 { nb[i * 4 + 3] = i + size }
        }
        self.nb = nb
    }

    private static let shared: [Int: GoGeometry] = Dictionary(uniqueKeysWithValues: (5...19).map { ($0, GoGeometry($0)) })
    static func of(_ size: Int) -> GoGeometry { shared[size] ?? GoGeometry(size) }
}

struct GoBoard: Sendable, Hashable {
    let size: Int
    let geo: GoGeometry
    /// 0 空，1 黑，2 白
    var cells: [Int8]
    var turn: GoStone = .black
    /// 打劫：这一手不能下的点
    var ko: Int?
    /// 双方提掉的对方棋子数：[黑提的, 白提的]
    var prisoners = [0, 0]
    /// 连着停了几手（两次就终局）
    var passes = 0

    init(size: Int) {
        self.size = size
        geo = GoGeometry.of(size)
        cells = Array(repeating: 0, count: size * size)
    }

    static func == (a: GoBoard, b: GoBoard) -> Bool {
        a.size == b.size && a.cells == b.cells && a.turn == b.turn && a.ko == b.ko
    }

    func hash(into h: inout Hasher) {
        h.combine(size); h.combine(cells); h.combine(turn); h.combine(ko)
    }

    /// "size=9;b=c3,d4;w=e5;turn=w"
    init?(spec: String) {
        var size = 9
        var black: [String] = [], white: [String] = [], turn = GoStone.black
        for part in spec.split(separator: ";") {
            let kv = part.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            guard kv.count == 2 else { continue }
            let list = kv[1].split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            switch kv[0] {
            case "size": size = Int(kv[1]) ?? 9
            case "b": black = list
            case "w": white = list
            case "turn": turn = kv[1] == "w" ? .white : .black
            default: break
            }
        }
        self.init(size: size)
        self.turn = turn
        for (names, s) in [(black, GoStone.black), (white, GoStone.white)] {
            for n in names {
                guard let i = index(n), cells[i] == 0 else { return nil }
                cells[i] = s.rawValue
            }
        }
    }

    // MARK: 坐标

    func index(_ name: String) -> Int? {
        guard let f = name.unicodeScalars.first, f.value >= 97, f.value < 97 + UInt32(size),
              let row = Int(name.dropFirst()), row >= 1, row <= size else { return nil }
        return (row - 1) * size + Int(f.value) - 97
    }

    func name(_ i: Int) -> String { "\(Character(UnicodeScalar(UInt8(97 + i % size))))\(i / size + 1)" }
    func x(_ i: Int) -> Int { i % size }
    func y(_ i: Int) -> Int { i / size }

    func neighbors(_ i: Int) -> [Int] {
        (0..<4).compactMap { let n = geo.nb[i * 4 + $0]; return n >= 0 ? n : nil }
    }

    /// 快速数气：数到 limit 就停（判断合法、提子时只关心"有没有 / 是不是只剩一口"）
    func libertyCount(_ i: Int, limit: Int) -> Int {
        let c = cells[i]
        let n = cells.count
        return withUnsafeTemporaryAllocation(of: Int.self, capacity: n) { stack in
            withUnsafeTemporaryAllocation(of: UInt8.self, capacity: n) { mark in
                mark.initialize(repeating: 0)
                var top = 0, libs = 0
                stack[0] = i; top = 1; mark[i] = 1
                let nb = geo.nb
                while top > 0 {
                    top -= 1
                    let s = stack[top]
                    for k in 0..<4 {
                        let m = nb[s * 4 + k]
                        if m < 0 || mark[m] != 0 { continue }
                        if cells[m] == 0 {
                            mark[m] = 2
                            libs += 1
                            if libs >= limit { return libs }
                        } else if cells[m] == c {
                            mark[m] = 1
                            stack[top] = m; top += 1
                        }
                    }
                }
                return libs
            }
        }
    }

    /// 把 i 所在的整块拿掉，返回拿掉了几颗
    private mutating func removeGroup(_ i: Int) -> [Int] {
        let c = cells[i]
        var out = [i]
        cells[i] = 0
        var k = 0
        while k < out.count {
            let s = out[k]
            for j in 0..<4 {
                let m = geo.nb[s * 4 + j]
                if m >= 0, cells[m] == c { cells[m] = 0; out.append(m) }
            }
            k += 1
        }
        return out
    }

    subscript(i: Int) -> GoStone? {
        get { GoStone(rawValue: cells[i]) }
        set { cells[i] = newValue?.rawValue ?? 0 }
    }

    var stoneCount: Int { cells.filter { $0 != 0 }.count }

    /// 星位
    var starPoints: [Int] {
        let s = size
        let edge = s >= 13 ? 3 : 2
        guard s >= 9 else { return [] }
        var pts = [(edge, edge), (s - 1 - edge, edge), (edge, s - 1 - edge), (s - 1 - edge, s - 1 - edge), (s / 2, s / 2)]
        if s >= 19 { pts += [(s / 2, edge), (s / 2, s - 1 - edge), (edge, s / 2), (s - 1 - edge, s / 2)] }
        return pts.map { $0.1 * s + $0.0 }
    }

    // MARK: 块和气

    /// 和 i 连在一起的同色棋子，以及它们的气
    func group(_ i: Int) -> (stones: [Int], liberties: Set<Int>) {
        let c = cells[i]
        guard c != 0 else { return ([], []) }
        var stones = [i], libs = Set<Int>(), seen: Set<Int> = [i]
        var k = 0
        while k < stones.count {
            for n in neighbors(stones[k]) {
                if cells[n] == 0 { libs.insert(n) }
                else if cells[n] == c, seen.insert(n).inserted { stones.append(n) }
            }
            k += 1
        }
        return (stones, libs)
    }

    func liberties(_ i: Int) -> Int { libertyCount(i, limit: Int.max) }

    /// 这一步合不合法（空点、不是打劫、不是自杀）
    func isLegal(_ i: Int) -> Bool {
        guard i >= 0, i < cells.count, cells[i] == 0, i != ko else { return false }
        let me = turn.rawValue, opp = turn.other.rawValue
        for k in 0..<4 {
            let n = geo.nb[i * 4 + k]
            if n < 0 { continue }
            if cells[n] == 0 { return true }
            if cells[n] == opp, libertyCount(n, limit: 2) == 1 { return true } // 能提子
            if cells[n] == me, libertyCount(n, limit: 2) > 1 { return true }   // 连上自己有气的子
        }
        return false
    }

    var legalMoves: [Int] { (0..<cells.count).filter(isLegal) }

    /// 落一子（不合法返回 nil），返回提掉的子
    @discardableResult
    mutating func play(_ i: Int) -> [Int]? {
        guard isLegal(i) else { return nil }
        let me = turn
        cells[i] = me.rawValue
        var captured: [Int] = []
        for k in 0..<4 {
            let n = geo.nb[i * 4 + k]
            if n >= 0, cells[n] == me.other.rawValue, libertyCount(n, limit: 1) == 0 {
                captured += removeGroup(n)
            }
        }
        prisoners[me == .black ? 0 : 1] += captured.count
        // 提掉一颗、自己这颗是单独一颗而且只剩一口气（就是那颗的位置）→ 对方不能马上提回
        var alone = true
        for k in 0..<4 { let n = geo.nb[i * 4 + k]; if n >= 0, cells[n] == me.rawValue { alone = false } }
        ko = (captured.count == 1 && alone && libertyCount(i, limit: 2) == 1) ? captured[0] : nil
        turn = me.other
        passes = 0
        return captured
    }

    mutating func pass() {
        turn = turn.other
        ko = nil
        passes += 1
    }

    func playing(_ i: Int) -> GoBoard? {
        var b = self
        return b.play(i) == nil ? nil : b
    }

    /// 单点眼：四周都是自己的子（随机走子时不往自己眼里填）
    func isEye(_ i: Int, for s: GoStone) -> Bool {
        guard cells[i] == 0 else { return false }
        for k in 0..<4 { let n = geo.nb[i * 4 + k]; if n >= 0, cells[n] != s.rawValue { return false } }
        // 斜角：中间要 3 个以上是自己的；边角上要全部是自己的
        let x = i % size, y = i / size
        var own = 0, total = 0
        for (dx, dy) in [(-1, -1), (1, -1), (-1, 1), (1, 1)] {
            let nx = x + dx, ny = y + dy
            guard nx >= 0, ny >= 0, nx < size, ny < size else { continue }
            total += 1
            if cells[ny * size + nx] == s.rawValue { own += 1 }
        }
        return total == 4 ? own >= 3 : own == total
    }

    // MARK: 数子（中国规则：子 + 地）

    /// 空地只挨着一种颜色就算那一方的地；dead 里的子当作被提掉
    func area(dead: Set<Int> = []) -> (black: Int, white: Int, owner: [Int8]) {
        var b = self
        for d in dead { b.cells[d] = 0 }
        var owner = b.cells
        var seen = Set<Int>()
        for i in 0..<b.cells.count where b.cells[i] == 0 && !seen.contains(i) {
            var region = [i], border = Set<Int8>()
            seen.insert(i)
            var k = 0
            while k < region.count {
                for n in b.neighbors(region[k]) {
                    if b.cells[n] == 0 { if seen.insert(n).inserted { region.append(n) } } else { border.insert(b.cells[n]) }
                }
                k += 1
            }
            let o: Int8 = border.count == 1 ? border.first! : 0
            for r in region { owner[r] = o }
        }
        return (owner.filter { $0 == 1 }.count, owner.filter { $0 == 2 }.count, owner)
    }

    // MARK: 吃子计算（战术搜索）

    /// i 所在的这块棋能不能被吃掉。attackerToMove：现在是不是攻击方走。depth：最多再算几手。
    /// 只在这块棋的气和"能救它的提子点"上找着法，所以很快，征子这种很长的变化也算得出来。
    /// wide：防守方有三口气时也继续算（判断"枷"要这样算；平时三口气就算逃掉，免得算得太乐观）
    func canCapture(_ i: Int, attackerToMove: Bool, depth: Int = 24, wide: Bool = false) -> Bool {
        guard let target = self[i] else { return true } // 已经被提了
        var b = self
        let mover = attackerToMove ? target.other : target
        if b.turn != mover { b.turn = mover; b.ko = nil }
        var budget = 30_000
        return b.capture(i, target: target, depth: depth, wide: wide, budget: &budget)
    }

    private func capture(_ i: Int, target: GoStone, depth: Int, wide: Bool, budget: inout Int) -> Bool {
        guard self[i] == target else { return true }
        budget -= 1
        if budget <= 0 { return false } // 算不清就当吃不掉
        let libs = group(i).liberties
        if turn == target.other {
            // 攻击方：只剩一口气直接提；气太多吃不掉
            if libs.count == 1, isLegal(libs.first!) { return true }
            if libs.count > 3 || depth <= 0 { return false }
            // 三口气时只在还有很多步可算时才试（枷、对杀），免得算太久
            if libs.count == 3, depth < 6 { return false }
            for m in libs.sorted() {
                guard let next = playing(m) else { continue }
                if next[i] != target { return true }
                // 往对方嘴里送一颗（倒扑）也要算，所以这里不排除"自己只剩一口气"的着法
                if next.capture(i, target: target, depth: depth - 1, wide: wide, budget: &budget) { return true }
            }
            return false
        } else {
            // 防守方：每一种应法都被吃，才算吃得掉。四口气算逃掉；三口气时还能算得深就接着算（枷）
            if libs.count >= 4 || (libs.count == 3 && (!wide || depth < 10)) { return false }
            if depth <= 0 { return libs.count <= 1 }
            var moves = Set(libs)
            // 提掉贴着自己、只剩一口气的对方棋子也是一种救法
            for s in group(i).stones {
                for n in neighbors(s) where cells[n] == target.other.rawValue {
                    let g = group(n)
                    if g.liberties.count == 1 { moves.insert(g.liberties.first!) }
                }
            }
            var anyLegal = false
            for m in moves.sorted() {
                guard let next = playing(m) else { continue }
                anyLegal = true
                let after = next.group(i).liberties.count
                if after >= 4 || (after == 3 && (!wide || depth < 10)) { return false }
                if !next.capture(i, target: target, depth: depth - 1, wide: wide, budget: &budget) { return false }
            }
            if !anyLegal {
                // 没地方下：等于停一手，让攻击方接着走
                var p = self
                p.pass()
                return p.capture(i, target: target, depth: depth - 1, wide: wide, budget: &budget)
            }
            return true
        }
    }

    /// 能救 i 这块棋的着法（吃子计算里防守方的候选），按气多到气少排
    func rescueMoves(_ i: Int) -> [Int] {
        guard let target = self[i] else { return [] }
        var b = self
        b.turn = target
        var moves = Set(b.group(i).liberties)
        for s in b.group(i).stones {
            for n in b.neighbors(s) where b.cells[n] == target.other.rawValue {
                let g = b.group(n)
                if g.liberties.count == 1 { moves.insert(g.liberties.first!) }
            }
        }
        return moves.compactMap { m in b.playing(m).map { (m, $0.group(i).liberties.count) } }
            .sorted { $0.1 > $1.1 }.map(\.0)
    }
}
