import Foundation

// 解题：一个是"像孩子一样一步一步想"的逻辑解法（只用最简单的几招），一个是穷举（数一数有几个解）。
// 关卡、提示、教学判题都用这里——出题器和测试编译的也是同一份代码。

/// 孩子会的几招，从易到难
enum SudokuTechnique: String, CaseIterable, Comparable {
    /// 一行 / 一列 / 一宫只剩一个空格：缺谁填谁
    case full
    /// 排除法：某个数在这一宫（行、列）里只能放在一个格子
    case hidden
    /// 唯一法：这一格看看同行、同列、同宫，只剩一个能填
    case naked

    static func < (a: Self, b: Self) -> Bool { a.order < b.order }

    private var order: Int {
        switch self {
        case .full: 0
        case .hidden: 1
        case .naked: 2
        }
    }
}

/// 能确定的一步：哪一格、填几、用的哪一招、看的是哪一行 / 列 / 宫
struct SudokuMove: Hashable {
    let cell: Int
    let value: Int
    let technique: SudokuTechnique
    /// 唯一法没有
    let unit: SudokuUnit?

    /// 难度：只剩一个空格 1，宫里排除 2，行列排除 3，唯一法 4
    var rank: Int {
        switch technique {
        case .full: 1
        case .hidden: unit?.kind == .box ? 2 : 3
        case .naked: 4
        }
    }

    /// "full:row"、"hidden:box"、"naked"（教学里 task.extra["via"] 用的写法）
    var via: String {
        if let unit { return "\(technique.rawValue):\(unit.kind.rawValue)" }
        return technique.rawValue
    }
}

/// 一道题按"每次挑最简单的一步"解下来的过程
struct SudokuTrace {
    var solved: Bool
    var steps: [SudokuMove]
    /// 难度分：每一步的难度 × 10，再加上"这一步能走的地方少"的分（只有一个地方能走就更难找）
    var score: Double
    /// 用到的最难的一招
    var hardest: Int { steps.map(\.rank).max() ?? 0 }
}

enum SudokuSolver {
    static let allTechniques = Set(SudokuTechnique.allCases)

    /// 现在能确定的全部步骤（同一格同一个数只留最简单的那一招），按从易到难排
    static func moves(_ g: SudokuGrid, allowed: Set<SudokuTechnique> = allTechniques) -> [SudokuMove] {
        let cands = (0..<g.count).map { g.candidates($0) }
        var best: [Int: SudokuMove] = [:]   // key = cell * 16 + value
        func add(_ m: SudokuMove) {
            let k = m.cell * 16 + m.value
            if let old = best[k], old.rank <= m.rank { return }
            best[k] = m
        }
        if allowed.contains(.full) {
            for u in g.units {
                let blanks = g.blanks(in: u)
                guard blanks.count == 1 else { continue }
                let miss = g.missing(in: u)
                if miss.count == 1, cands[blanks[0]].contains(miss[0]) {
                    add(SudokuMove(cell: blanks[0], value: miss[0], technique: .full, unit: u))
                }
            }
        }
        if allowed.contains(.hidden) {
            for u in g.units {
                let blanks = g.blanks(in: u)
                guard !blanks.isEmpty else { continue }
                for v in g.missing(in: u) {
                    let spots = blanks.filter { cands[$0].contains(v) }
                    if spots.count == 1 { add(SudokuMove(cell: spots[0], value: v, technique: .hidden, unit: u)) }
                }
            }
        }
        if allowed.contains(.naked) {
            for i in 0..<g.count where g[i] == 0 && cands[i].count == 1 {
                add(SudokuMove(cell: i, value: cands[i][0], technique: .naked, unit: nil))
            }
        }
        return best.values.sorted { ($0.rank, $0.cell, $0.value) < ($1.rank, $1.cell, $1.value) }
    }

    /// 最简单的下一步
    static func easiest(_ g: SudokuGrid, allowed: Set<SudokuTechnique> = allTechniques) -> SudokuMove? {
        moves(g, allowed: allowed).first
    }

    /// 有没有哪个空格一个数都填不了（说明前面填错了）
    static func stuck(_ g: SudokuGrid) -> Bool {
        (0..<g.count).contains { g[$0] == 0 && g.candidates($0).isEmpty }
    }

    /// 只用 allowed 里的几招，每次挑最简单的一步，能不能解完
    static func logicSolve(_ start: SudokuGrid, allowed: Set<SudokuTechnique> = allTechniques) -> SudokuTrace {
        var g = start
        var trace = SudokuTrace(solved: false, steps: [], score: 0)
        guard g.conflicts().isEmpty else { return trace }
        while !g.isFull {
            let ms = moves(g, allowed: allowed)
            guard let m = ms.first, !stuck(g) else { return trace }
            let easyCount = ms.filter { $0.rank == m.rank }.count
            trace.score += Double(m.rank) * 10 + 12 / Double(easyCount)
            trace.steps.append(m)
            g[m.cell] = m.value
        }
        trace.solved = g.conflicts().isEmpty
        return trace
    }

    // MARK: 穷举

    /// 数一数有几个解（数到 limit 就停）
    static func countSolutions(_ g: SudokuGrid, limit: Int = 2) -> Int {
        guard g.conflicts().isEmpty else { return 0 }
        var count = 0
        var work = g
        var found: SudokuGrid?
        search(&work, limit: limit, count: &count, found: &found)
        return count
    }

    /// 第一个解；没有解是 nil
    static func solve(_ g: SudokuGrid) -> SudokuGrid? {
        guard g.conflicts().isEmpty else { return nil }
        var count = 0
        var work = g
        var found: SudokuGrid?
        search(&work, limit: 1, count: &count, found: &found)
        return found
    }

    /// 唯一的解；没有解或者不止一个解是 nil
    static func uniqueSolution(_ g: SudokuGrid) -> SudokuGrid? {
        guard g.conflicts().isEmpty else { return nil }
        var count = 0
        var work = g
        var found: SudokuGrid?
        search(&work, limit: 2, count: &count, found: &found)
        return count == 1 ? found : nil
    }

    private static func search(_ g: inout SudokuGrid, limit: Int, count: inout Int, found: inout SudokuGrid?) {
        if count >= limit { return }
        // 挑候选最少的空格
        var bestCell = -1
        var bestCands: [Int] = []
        for i in 0..<g.count where g[i] == 0 {
            let c = g.candidates(i)
            if c.isEmpty { return }
            if bestCell < 0 || c.count < bestCands.count {
                bestCell = i
                bestCands = c
                if c.count == 1 { break }
            }
        }
        if bestCell < 0 {
            count += 1
            if found == nil { found = g }
            return
        }
        for v in bestCands {
            g[bestCell] = v
            search(&g, limit: limit, count: &count, found: &found)
            if count >= limit { break }
        }
        g[bestCell] = 0
    }

    /// 随机的一个填满的盘面（出题器用）
    static func randomSolution<R: RandomNumberGenerator>(n: Int, using rng: inout R) -> SudokuGrid {
        var g = SudokuGrid(n: n)
        _ = fillRandom(&g, using: &rng)
        return g
    }

    private static func fillRandom<R: RandomNumberGenerator>(_ g: inout SudokuGrid, using rng: inout R) -> Bool {
        guard let i = (0..<g.count).first(where: { g[$0] == 0 }) else { return true }
        for v in g.candidates(i).shuffled(using: &rng) {
            g[i] = v
            if fillRandom(&g, using: &rng) { return true }
        }
        g[i] = 0
        return false
    }
}
