import Foundation

// 数独教学的判题：每道题都按规则算出所有正确答案，不是只认写死的一个格子。
//
// 题目（task.type / task.rule，格子 "r3c4"、行列宫 "row:3"，都从 1 数起）：
//   fill   cell:r3c4          把这一格填对（答案 = 唯一解里的数；盘面不唯一时 = 用三招能确定的数）
//   fill   single             找任意一个能确定的空格填对
//   pick   where:7:box:5      7 在这一宫里只能放在哪一格（排除法）
//   pick   oneBlank[:row]     点出只剩一个空格的那一行 / 列 / 宫（点这一行里任意一格）
//   pick   fullest[:row]      点出空格最少的那一行 / 列 / 宫
//   pick   clash              点出重复了的格子
//   pick   inUnit:row:2       点这一行（列、宫）里任意一格（认识行列宫用，不进练习）
//   value  missing:row:3      这一行只剩一个空格，缺的是哪一个（在按钮上选）
//   cands  cands:r3c4         把这一格能填的全部点出来（小笔记）
// task.extra["via"]：这道题提示里讲的是哪一招（"full:row"、"hidden:box"、"naked"），测试会检查答案确实能这样想出来。
//
// 标记（step.marks）：row:3 / col:4 / box:5 圈出来；cell:r3c4 发光；val:7 所有的 7 亮起来；
// cross:r3c4 打叉（不能放）；ban:row:3 整行打叉；notes:r3c4:127 小笔记。

enum SudokuLessonLogic {
    enum Input { case fill, pick, value, cands }

    static func input(_ t: TutorialTask) -> Input {
        switch t.type {
        case "pick": .pick
        case "value": .value
        case "cands": .cands
        default: .fill
        }
    }

    static func parts(_ rule: String?) -> [String] { (rule ?? "").split(separator: ":").map(String.init) }

    /// "where:7:box:5" 里的行列宫
    static func unit(_ p: [String], from k: Int) -> SudokuUnit? {
        guard p.count >= k + 2 else { return nil }
        return SudokuUnit("\(p[k]):\(p[k + 1])")
    }

    /// 这一格应该填几：盘面只有一个解就是解里的数；不止一个解时，用三招能确定的数；都不行是 nil
    static func forcedValue(_ g: SudokuGrid, _ cell: Int) -> Int? {
        guard g[cell] == 0, g.conflicts().isEmpty else { return nil }
        if let sol = SudokuSolver.uniqueSolution(g) { return sol[cell] }
        return SudokuSolver.moves(g).first { $0.cell == cell }?.value
    }

    /// fill 题的全部正确答案（格子, 数）
    static func fillAnswers(_ t: TutorialTask, _ g: SudokuGrid) -> [(cell: Int, value: Int)] {
        let p = parts(t.rule)
        switch p.first {
        case "cell":
            guard p.count == 2, let c = g.cell(named: p[1]), let v = forcedValue(g, c) else { return [] }
            return [(c, v)]
        case "single":
            guard g.conflicts().isEmpty else { return [] }
            if let sol = SudokuSolver.uniqueSolution(g) {
                return (0..<g.count).filter { g[$0] == 0 }.map { ($0, sol[$0]) }
            }
            var seen = Set<Int>()
            return SudokuSolver.moves(g).filter { seen.insert($0.cell * 16 + $0.value).inserted }.map { ($0.cell, $0.value) }
        default:
            return []
        }
    }

    /// pick 题的全部正确格子
    static func pickAnswers(_ t: TutorialTask, _ g: SudokuGrid) -> Set<Int> {
        let p = parts(t.rule)
        let kinds: [SudokuUnit.Kind] = p.count >= 2 ? [SudokuUnit.Kind(rawValue: p[1])].compactMap { $0 } : SudokuUnit.Kind.allCases
        switch p.first {
        case "where":
            guard p.count == 4, let v = Int(p[1]), let u = unit(p, from: 2), g.isValid(u),
                  !g.values(in: u).contains(v) else { return [] }
            let spots = g.blanks(in: u).filter { g.candidates($0).contains(v) }
            return spots.count == 1 ? [spots[0]] : []
        case "oneBlank":
            var out = Set<Int>()
            for k in kinds { for i in 0..<g.n where g.blanks(in: SudokuUnit(k, i)).count == 1 { out.formUnion(g.cells(SudokuUnit(k, i))) } }
            return out
        case "fullest":
            let us = kinds.flatMap { k in (0..<g.n).map { SudokuUnit(k, $0) } }.filter { !g.blanks(in: $0).isEmpty }
            guard let least = us.map({ g.blanks(in: $0).count }).min() else { return [] }
            return Set(us.filter { g.blanks(in: $0).count == least }.flatMap { g.cells($0) })
        case "clash":
            return g.conflicts()
        case "inUnit":
            guard let u = unit(p, from: 1), g.isValid(u) else { return [] }
            return Set(g.cells(u))
        default:
            return []
        }
    }

    /// value 题的正确答案
    static func valueAnswers(_ t: TutorialTask, _ g: SudokuGrid) -> Set<Int> {
        let p = parts(t.rule)
        guard p.first == "missing", let u = unit(p, from: 1), g.isValid(u), g.blanks(in: u).count == 1 else { return [] }
        return Set(g.missing(in: u))
    }

    /// cands 题：这一格能填的全部
    static func candAnswers(_ t: TutorialTask, _ g: SudokuGrid) -> Set<Int> {
        let p = parts(t.rule)
        guard p.first == "cands", p.count == 2, let c = g.cell(named: p[1]) else { return [] }
        return Set(g.candidates(c))
    }

    /// 这道题有没有答案（测试用；fill 题还要求每一格的答案只有一个）
    static func hasAnswer(_ t: TutorialTask, _ g: SudokuGrid) -> Bool {
        switch input(t) {
        case .fill: !fillAnswers(t, g).isEmpty
        case .pick: !pickAnswers(t, g).isEmpty
        case .value: valueAnswers(t, g).count == 1
        case .cands: !candAnswers(t, g).isEmpty
        }
    }

    /// 题目自己要圈出来的地方（练习时课文的标记可能不够，按规则补上）
    static func focus(_ t: TutorialTask, _ g: SudokuGrid) -> (units: [SudokuUnit], cells: [Int], value: Int?) {
        let p = parts(t.rule)
        switch p.first {
        case "cell", "cands":
            if p.count == 2, let c = g.cell(named: p[1]) { return ([], [c], nil) }
        case "where":
            if p.count == 4, let v = Int(p[1]), let u = unit(p, from: 2) { return ([u], [], v) }
        case "missing":
            if let u = unit(p, from: 1) { return ([u], [], nil) }
        default: break
        }
        return ([], [], nil)
    }

    // MARK: 为什么是这个答案

    /// 这一格填 value，能不能用 via 这一招想出来（"full:row"、"hidden:box"、"naked"）
    static func supports(via: String, _ g: SudokuGrid, cell: Int, value: Int) -> Bool {
        guard g[cell] == 0 else { return false }
        let p = via.split(separator: ":").map(String.init)
        switch p.first {
        case "naked":
            return g.candidates(cell) == [value]
        case "full":
            guard p.count == 2, let k = SudokuUnit.Kind(rawValue: p[1]) else { return false }
            let u = g.unit(k, of: cell)
            return g.blanks(in: u) == [cell] && g.missing(in: u) == [value] && g.candidates(cell).contains(value)
        case "hidden":
            guard p.count == 2, let k = SudokuUnit.Kind(rawValue: p[1]) else { return false }
            let u = g.unit(k, of: cell)
            return !g.values(in: u).contains(value) && g.blanks(in: u).filter { g.candidates($0).contains(value) } == [cell]
        default:
            return false
        }
    }

    /// 把一步讲给她看：圈哪里、哪些格子打叉、哪个数亮起来
    struct Explain {
        var units: [SudokuUnit] = []
        /// 不能放的格子（排除法里被挡住的）
        var crossed: [Int] = []
        /// 同行同列同宫轻轻亮起来（唯一法）
        var peers: [Int] = []
        var value: Int?
    }

    static func explain(_ m: SudokuMove, _ g: SudokuGrid) -> Explain {
        var e = Explain()
        switch m.technique {
        case .full:
            if let u = m.unit { e.units = [u] }
        case .hidden:
            guard let u = m.unit else { break }
            e.units = [u]
            e.value = m.value
            e.crossed = g.blanks(in: u).filter { $0 != m.cell }
        case .naked:
            e.peers = g.peers(m.cell)
        }
        return e
    }

    /// via 写法 → 一步（教学里"错了两次亮答案"时用来讲）
    static func move(via: String, _ g: SudokuGrid, cell: Int, value: Int) -> SudokuMove? {
        guard supports(via: via, g, cell: cell, value: value) else { return nil }
        let p = via.split(separator: ":").map(String.init)
        guard let t = SudokuTechnique(rawValue: p[0]) else { return nil }
        let unit = p.count == 2 ? SudokuUnit.Kind(rawValue: p[1]).map { g.unit($0, of: cell) } : nil
        return SudokuMove(cell: cell, value: value, technique: t, unit: unit)
    }
}

// MARK: - 练习时换个样子

/// 不改变解法的一种变换：换数字（水果）、行在自己那一条里换位置、整条换位置、列也一样，宫是正方形时还可以沿对角线翻过来。
/// 盘面、标记、题目、提示用的那一招——写着格子、行列宫、数字的地方一起变。
struct SudokuTransform {
    let n: Int
    let boxRows: Int
    let boxCols: Int
    /// 原来的第 r 行 → 新的第几行
    let rowMap: [Int]
    let colMap: [Int]
    let transpose: Bool
    /// 原来的数 v → 新的数（下标 0 不用）
    let valueMap: [Int]

    static func identity(n: Int) -> SudokuTransform {
        let (br, bc) = SudokuGrid.boxShape(n)
        return SudokuTransform(n: n, boxRows: br, boxCols: bc, rowMap: Array(0..<n), colMap: Array(0..<n),
                               transpose: false, valueMap: Array(0...n))
    }

    /// 第 k 种（k = 0 不变；同一个 k 永远是同一种）
    static func variant(n: Int, k: Int) -> SudokuTransform {
        guard k > 0 else { return identity(n: n) }
        let (br, bc) = SudokuGrid.boxShape(n)
        var rng = SudokuRNG(seed: UInt64(k) &* 0x2545_F491_4F6C_DD1D &+ UInt64(n))
        func blocks(count: Int, size: Int) -> [Int] {
            // 整条换位置，条里面再换
            let order = Array(0..<count).shuffled(using: &rng)
            var map = Array(repeating: 0, count: count * size)
            for (newBand, oldBand) in order.enumerated() {
                let inner = Array(0..<size).shuffled(using: &rng)
                for (newPos, oldPos) in inner.enumerated() { map[oldBand * size + oldPos] = newBand * size + newPos }
            }
            return map
        }
        let rows = blocks(count: n / br, size: br)
        let cols = blocks(count: n / bc, size: bc)
        var values = [0] + Array(1...n).shuffled(using: &rng)
        if values == Array(0...n) { values = [0] + Array(2...n) + [1] }
        let flip = br == bc && Bool.random(using: &rng)
        return SudokuTransform(n: n, boxRows: br, boxCols: bc, rowMap: rows, colMap: cols, transpose: flip, valueMap: values)
    }

    func cell(_ i: Int) -> Int {
        let r = rowMap[i / n], c = colMap[i % n]
        return transpose ? c * n + r : r * n + c
    }

    func value(_ v: Int) -> Int { v >= 1 && v <= n ? valueMap[v] : v }

    func kind(_ k: SudokuUnit.Kind) -> SudokuUnit.Kind {
        guard transpose else { return k }
        switch k {
        case .row: return .col
        case .col: return .row
        case .box: return .box
        }
    }

    func unit(_ u: SudokuUnit) -> SudokuUnit {
        let g = SudokuGrid(n: n)
        let first = g.cells(u)[0]
        return g.unit(kind(u.kind), of: cell(first))
    }

    func grid(_ g: SudokuGrid) -> SudokuGrid {
        var out = SudokuGrid(n: n, fruit: g.fruit)
        for i in 0..<g.count { out[cell(i)] = value(g[i]) }
        return out
    }

    func board(_ spec: String) -> String {
        guard let g = SudokuGrid(spec: spec), g.n == n else { return spec }
        return grid(g).spec
    }

    private func cellName(_ s: String) -> String {
        let g = SudokuGrid(n: n)
        guard let c = g.cell(named: s) else { return s }
        return g.name(cell(c))
    }

    private func unitName(_ k: String, _ i: String) -> String {
        guard let u = SudokuUnit("\(k):\(i)"), u.index < n else { return "\(k):\(i)" }
        return unit(u).description
    }

    private func kindName(_ k: String) -> String {
        SudokuUnit.Kind(rawValue: k).map { kind($0).rawValue } ?? k
    }

    private func digits(_ s: String) -> String {
        String(s.compactMap { $0.wholeNumberValue }.map(value).sorted().map { Character(String($0)) })
    }

    /// 一个标记
    func mark(_ m: String) -> String {
        var p = m.split(separator: ":").map(String.init)
        guard let head = p.first else { return m }
        switch head {
        case "row", "col", "box":
            if p.count == 2 { return unitName(p[0], p[1]) }
        case "ban":
            if p.count == 3 { return "ban:" + unitName(p[1], p[2]) }
        case "cell", "cross":
            if p.count == 2 { p[1] = cellName(p[1]) }
        case "val":
            if p.count == 2, let v = Int(p[1]) { p[1] = String(value(v)) }
        case "notes":
            if p.count == 3 { p[1] = cellName(p[1]); p[2] = digits(p[2]) }
        default: break
        }
        return p.joined(separator: ":")
    }

    /// 题目的规则
    func rule(_ r: String) -> String {
        var p = r.split(separator: ":").map(String.init)
        guard let head = p.first else { return r }
        switch head {
        case "cell", "cands":
            if p.count == 2 { p[1] = cellName(p[1]) }
        case "where":
            if p.count == 4, let v = Int(p[1]) { return "where:\(value(v)):" + unitName(p[2], p[3]) }
        case "missing", "inUnit":
            if p.count == 3 { return "\(head):" + unitName(p[1], p[2]) }
        case "oneBlank", "fullest":
            if p.count == 2 { p[1] = kindName(p[1]) }
        default: break
        }
        return p.joined(separator: ":")
    }

    /// "full:row" → "full:col"（翻过来时）
    func via(_ v: String) -> String {
        var p = v.split(separator: ":").map(String.init)
        if p.count == 2 { p[1] = kindName(p[1]) }
        return p.joined(separator: ":")
    }

    /// 一整步。练习时 say 是按规则配的通用说法，规则变了（行变成列）说法跟着换。
    func step(_ s: TutorialStep) -> TutorialStep {
        var t = s
        t.board = s.board.map(board)
        t.marks = s.marks?.map(mark)
        if var task = s.task {
            if let r = task.rule {
                let newRule = rule(r)
                if s.drill == nil, let old = SudokuTutorial.prompt(for: r), s.say == old,
                   let new = SudokuTutorial.prompt(for: newRule) { t.say = new }
                task.rule = newRule
            }
            if let via = task.extra?["via"] { task.extra?["via"] = self.via(via) }
            t.task = task
        }
        return t
    }
}
