import Foundation

// 编程关卡的穷举求解器（只给测试用，App 里不需要）：
// 在这一关允许的积木和格子里，找积木数最少的程序（所有花园都要过）。
//
// 做法：主程序是一块一块从头做到尾的，所以把"主程序最外层的一块积木（连同它里面的东西）"当成一步，
// 小兔们（每个花园一只）的样子当成地图上的点，积木数当成路的长短，做一次最短路（Dijkstra）。
// 一直重复只能是最后一块，所以它是"终点前的最后一步"。
// 绝招那一栏是共用的：先把绝招的写法一个一个列出来，每一种写法各做一次最短路。
// 只找积木数 ≤ budget 的程序；budget = par - 1 时找不到，就证明了 par 是最少的。

struct CodingSolver {
    let gardens: [CodingGarden]
    let limits: CodingLimits
    /// 超过这个时间就放弃（complete = false）
    var deadline = Date.distantFuture

    /// 列出来的积木记下来（同一关里，绝招换了写法，主程序能放的积木还是那些）
    private final class Cache { var items: [String: ([CodingBlock], [CodingBlock])] = [:] }
    private let cache = Cache()

    struct Result {
        var program: CodingProgram?
        /// 在 budget 以内全部试完了（false = 时间到了，没试完）
        var complete: Bool
        /// 一共试了多少种（最短路展开的次数）
        var expanded: Int
    }

    private var has: (CodingPiece) -> Bool { { limits.palette.contains($0) } }
    private var arrows: [CodingBlock] { CodingDir.allCases.filter { has(.arrow($0)) }.map { .move($0) } }

    // MARK: 列出积木

    /// 长度 1…maxLen、积木数 ≤ maxCost 的串，每一格从 options 里挑（options 按积木数分好）
    private func lists(_ options: [CodingBlock], maxLen: Int, maxCost: Int) -> [[CodingBlock]] {
        var out: [[CodingBlock]] = []
        var cur: [CodingBlock] = []
        func go(_ cost: Int) {
            if !cur.isEmpty { out.append(cur) }
            guard cur.count < maxLen else { return }
            for o in options where cost + o.size <= maxCost {
                cur.append(o); go(cost + o.size); cur.removeLast()
            }
        }
        go(0)
        return out
    }

    private func whens(calls: [CodingBlock], maxCost: Int) -> [CodingBlock] {
        guard maxCost >= 2 else { return [] }
        var out: [CodingBlock] = []
        for f in CodingFlower.allCases where has(.when(f)) {
            for b in lists(arrows + calls, maxLen: limits.when, maxCost: maxCost - 1) { out.append(.when(f, b)) }
        }
        return out
    }

    /// 重复、一直重复里面能放的一格
    private func loopCells(calls: [CodingBlock], maxCost: Int) -> [CodingBlock] {
        arrows + calls + whens(calls: calls, maxCost: maxCost)
    }

    private func loops(calls: [CodingBlock], maxCost: Int) -> [CodingBlock] {
        guard has(.loop), maxCost >= 2 else { return [] }
        let bodies = lists(loopCells(calls: calls, maxCost: maxCost - 1), maxLen: limits.loop, maxCost: maxCost - 1)
        // n[R R] 和 (2n)[R] 一样，积木还多一块：不列
        return bodies.flatMap { b in (2...9).compactMap { n -> CodingBlock? in
            if b.count >= 2, case .move = b[0], b.allSatisfy({ $0 == b[0] }), n * b.count <= 9 { return nil }
            return CodingBlock.loop(n, b)
        } }
    }

    /// 主程序最外层能放的积木（不含一直重复），积木数 ≤ maxCost
    private func mainItems(calls: [CodingBlock], maxCost: Int) -> [CodingBlock] {
        (arrows + calls + loops(calls: calls, maxCost: maxCost) + whens(calls: calls, maxCost: maxCost))
            .filter { $0.size <= maxCost }
            .sorted { $0.size < $1.size }
    }

    private func foreverItems(calls: [CodingBlock], maxCost: Int) -> [CodingBlock] {
        guard has(.forever), maxCost >= 2 else { return [] }
        return lists(loopCells(calls: calls, maxCost: maxCost - 1), maxLen: limits.loop, maxCost: maxCost - 1).map { .forever($0) }
    }

    /// 绝招那一栏的写法（里面不能叫绝招）。只有一个箭头的绝招和直接放箭头一样，不列。
    func procBodies(maxCost: Int) -> [[CodingBlock]] {
        guard maxCost >= 1 else { return [] }
        let cells = (arrows + loops(calls: [], maxCost: maxCost) + whens(calls: [], maxCost: maxCost)).filter { $0.size <= maxCost }
        return lists(cells, maxLen: limits.proc, maxCost: maxCost).filter { !($0.count == 1 && $0[0].size == 1) && !wasteful($0) }
    }

    /// 一个只重复同一个箭头的重复：n[R] → (R, n)
    private func run(_ b: CodingBlock) -> (CodingDir, Int)? {
        switch b {
        case let .move(d): return (d, 1)
        case let .loop(n, body) where !body.isEmpty:
            guard case let .move(d) = body[0], body.allSatisfy({ $0 == body[0] }) else { return nil }
            return (d, n * body.count)
        default: return nil
        }
    }

    /// 绝招那一栏里，明显能换成更省的写法的串（换了以后积木更少、格子不更多，最少的程序里不会出现它，不用列）：
    /// 挨着的两块都只是在往同一个方向走（R R R、R 3[R]、2[R] 3[R]……），而且合起来能用一个重复写完、积木更少
    private func wasteful(_ l: [CodingBlock]) -> Bool {
        guard has(.loop) else { return false }
        var i = 0
        while i < l.count {
            guard let (d, _) = run(l[i]) else { i += 1; continue }
            var j = i, steps = 0, cost = 0
            while j < l.count, let (e, k) = run(l[j]), e == d { steps += k; cost += l[j].size; j += 1 }
            if j - i >= 2, steps <= 9, cost > 2 { return true }
            i = max(j, i + 1)
        }
        return false
    }

    // MARK: 最短路

    private struct Joint: Hashable {
        var states: [CodingState]
        /// 哪几个花园已经过关了
        var done: UInt8
    }

    private struct Key: Hashable {
        var joint: Joint
        var slots: Int
    }

    /// 一块积木在每个还没过关的花园里做一遍。nil = 有花园撞到了 / 转晕了
    private func apply(_ b: CodingBlock, _ j: Joint, _ program: CodingProgram) -> Joint? {
        var out = j
        for (i, g) in gardens.enumerated() where j.done & (1 << i) == 0 {
            let (s, o) = CodingMachine.exec([b], program: program, garden: g, from: j.states[i])
            switch o {
            case .bump?, .dizzy?: return nil
            case .success?: out.done |= 1 << i
            default: break
            }
            out.states[i] = s
        }
        return out
    }

    private var allDone: UInt8 { UInt8((1 << gardens.count) - 1) }

    /// 绝招定好了（procs），找主程序：积木数 ≤ budget（不算绝招那几栏）
    private func searchMain(procs: CodingProgram, budget: Int, expanded: inout Int, timedOut: inout Bool) -> [CodingBlock]? {
        var calls: [CodingBlock] = []
        for p in CodingProc.allCases where !procs.tracks[p.track].isEmpty && has(.call(p)) { calls.append(.call(p)) }
        let key = "\(calls):\(budget)"
        let items: [CodingBlock], forevers: [CodingBlock]
        if let c = cache.items[key] {
            (items, forevers) = c
        } else {
            items = mainItems(calls: calls, maxCost: budget)
            forevers = foreverItems(calls: calls, maxCost: budget)
            cache.items[key] = (items, forevers)
        }
        let start = Joint(states: gardens.map(CodingState.start), done: 0)
        var best: [Key: Int] = [Key(joint: start, slots: 0): 0]
        var parent: [Key: (Key, CodingBlock)] = [:]
        var buckets: [[Key]] = Array(repeating: [], count: budget + 1)
        buckets[0] = [Key(joint: start, slots: 0)]
        func path(_ k: Key) -> [CodingBlock] {
            var out: [CodingBlock] = []
            var c = k
            while let (p, b) = parent[c] { out.append(b); c = p }
            return out.reversed()
        }
        var found: (cost: Int, blocks: [CodingBlock])?
        for cost in 0...budget {
            if let f = found, f.cost <= cost { return f.blocks }
            var bi = 0
            while bi < buckets[cost].count {
                let k = buckets[cost][bi]
                bi += 1
                guard best[k] == cost else { continue }
                expanded += 1
                if expanded & 1023 == 0, Date() > deadline { timedOut = true; return nil }
                guard k.slots < limits.main else { continue }
                // 最后一块是一直重复
                for f in forevers where cost + f.size <= budget && cost + f.size < (found?.cost ?? .max) {
                    if let j = apply(f, k.joint, procs), j.done == allDone { found = (cost + f.size, path(k) + [f]) }
                }
                for it in items {
                    let c2 = cost + it.size
                    if c2 > budget { break }
                    guard let j = apply(it, k.joint, procs) else { continue }
                    if j.done == allDone {
                        if c2 < (found?.cost ?? .max) { found = (c2, path(k) + [it]) }
                        continue
                    }
                    if j == k.joint { continue }
                    let nk = Key(joint: j, slots: k.slots + 1)
                    if let b = best[nk], b <= c2 { continue }
                    best[nk] = c2
                    parent[nk] = (k, it)
                    buckets[c2].append(nk)
                }
            }
        }
        return found?.blocks
    }

    /// 积木数 ≤ budget 的最少的程序
    func minimal(budget: Int) -> Result {
        var expanded = 0
        var timedOut = false
        var bestProgram: CodingProgram?
        var bestCost = budget + 1
        // 不用绝招
        if let m = searchMain(procs: CodingProgram(), budget: budget, expanded: &expanded, timedOut: &timedOut) {
            bestProgram = CodingProgram(tracks: [m, [], []])
            bestCost = bestProgram!.size
        }
        if timedOut { return Result(program: bestProgram, complete: false, expanded: expanded) }
        let useS = has(.call(.star)), useT = has(.call(.diamond))
        if useS {
            // 至少要叫一次绝招（1 块），所以绝招本身最多 bestCost - 2 块
            let sBodies = procBodies(maxCost: bestCost - 2)
            let tBodies = useT ? procBodies(maxCost: bestCost - 2) : []
            func trial(_ s: [CodingBlock], _ t: [CodingBlock]) -> Bool {
                let defCost = s.reduce(0) { $0 + $1.size } + t.reduce(0) { $0 + $1.size }
                let room = bestCost - 1 - defCost
                guard room >= 1 else { return true }
                let procs = CodingProgram(tracks: [[], s, t])
                if let m = searchMain(procs: procs, budget: room, expanded: &expanded, timedOut: &timedOut) {
                    let p = CodingProgram(tracks: [m, s, t])
                    if p.size < bestCost { bestCost = p.size; bestProgram = p }
                }
                return !timedOut
            }
            for (si, s) in sBodies.enumerated() {
                if !trial(s, []) { return Result(program: bestProgram, complete: false, expanded: expanded) }
                // 两个绝招都用：★ 和 ◆ 换一换是一样的，只试一种排法
                for t in tBodies.dropFirst(si) {
                    if !trial(s, t) { return Result(program: bestProgram, complete: false, expanded: expanded) }
                }
            }
        }
        return Result(program: bestProgram, complete: true, expanded: expanded)
    }
}
