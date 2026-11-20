import Foundation

// 读题关里，算之前先选"怎么列式"（What do we do?）；100 以内的加减还能"数十和一"；
// 以及首页上的"练一练"（Practice mix）怎么挑题。都是纯逻辑，命令行里能测（tools/storybank/test.swift）。

/// 一个算式：a op b = result
struct StoryCalc: Hashable {
    let a: Int
    let op: Character
    let b: Int
    let result: Int

    var isRight: Bool {
        switch op {
        case "+": a + b == result
        case "−": a - b == result
        case "×": a * b == result
        case "÷": b != 0 && a == b * result
        default:  false
        }
    }

    /// "12 − 5 = ?"
    var blank: String { "\(a) \(op) \(b) = ?" }

    /// 从 "12 − 5 = 7" 读出来；"3 + 3 + 3 = 9"、"because …"、"Half of 4 is 2." 这些不算
    static func parse(_ s: String) -> StoryCalc? {
        let parts = s.split(separator: " ").map(String.init)
        guard parts.count == 5, parts[3] == "=", let op = parts[1].first, parts[1].count == 1, "+−×÷".contains(op),
              let a = Int(parts[0]), let b = Int(parts[2]), let r = Int(parts[4]) else { return nil }
        return StoryCalc(a: a, op: op, b: b, result: r)
    }
}

/// 算之前先选一个算式
struct StoryChoice: Hashable {
    /// 两步题：问的是"先算什么"
    let first: Bool
    let options: [StoryCalc]
    let correct: Int
}

extension StoryProblem {
    /// explain 里的算式，按顺序
    var calcs: [StoryCalc] {
        explain.components(separatedBy: "   ").compactMap { seg in
            var seg = seg.trimmingCharacters(in: .whitespaces)
            // "{a}: 6 − 2 = 4" 前面写了是谁的
            if seg.hasPrefix("{"), let colon = seg.range(of: ": ") { seg = String(seg[colon.upperBound...]) }
            return StoryCalc.parse(seg)
        }
    }

    /// 这道题要选的那一步算式：一步题就是那一个算式，两步题是第一步。
    /// 好几步混在一起的（给来给去以后比较、变成一样多）不问。
    var keyCalc: (calc: StoryCalc, first: Bool)? {
        var cs = calcs
        // "4 + 4 = 8   2 × 4 = 8"：乘法题只看乘法那一个
        if schema == .multiply { cs = cs.filter { $0.op == "×" } }
        if schema == .twoStep {
            guard cs.count == 2, cs[1].result == answer, cs[1].a == cs[0].result || cs[1].b == cs[0].result else { return nil }
            return (cs[0], true)
        }
        guard cs.count == 1, cs[0].result == answer else { return nil }
        return (cs[0], false)
    }

    /// "What do we do?"：对的算式和一两个常见的错法，顺序每道题固定（按题的钥匙打乱）
    var choice: StoryChoice? {
        guard let (calc, first) = keyCalc else { return nil }
        let (x, y) = (calc.a, calc.b)
        var wrong: [StoryCalc]
        switch calc.op {
        case "+": wrong = [StoryCalc(a: max(x, y), op: "−", b: min(x, y), result: max(x, y) - min(x, y))]
        case "−": wrong = [StoryCalc(a: x, op: "+", b: y, result: x + y)]
        case "×": wrong = [StoryCalc(a: x, op: "+", b: y, result: x + y)]
        case "÷": wrong = [StoryCalc(a: x, op: "−", b: y, result: x - y), StoryCalc(a: x, op: "×", b: y, result: x * y)]
        default:  return nil
        }
        // 2 × 2 和 2 + 2、4 ÷ 2 和 4 − 2 算出来一样：这种错法看不出来，不放
        wrong = wrong.filter { $0.result != calc.result && $0.result >= 0 }
        guard !wrong.isEmpty else { return nil }
        var options = [calc] + wrong
        // 用题的钥匙决定顺序：同一道题每次都一样，不同的题对的那个不总在第一个
        var seed: UInt64 = 0
        for b in starKey(level: 0).utf8 { seed = seed &* 31 &+ UInt64(b) }
        var rng = StoryRNG(seed: seed)
        options.shuffle(using: &rng)
        return StoryChoice(first: first, options: options, correct: options.firstIndex(of: calc)!)
    }

    /// 选错算式时说的话（固定的几句，都录了音）
    var choiceNudge: String {
        guard let (calc, first) = keyCalc else { return StoryVoiceLines.nudgeFirst }
        if first { return StoryVoiceLines.nudgeFirst }
        switch schema {
        case .combine:   return StoryVoiceLines.nudgeAltogether
        case .partWhole: return StoryVoiceLines.nudgePart
        case .compare:   return StoryVoiceLines.nudgeCompare
        case .multiply:  return StoryVoiceLines.nudgeTimes
        case .divide:    return ask == .plates ? StoryVoiceLines.nudgeGroups : StoryVoiceLines.nudgeShare
        case .inverse:   return calc.op == "+" ? StoryVoiceLines.nudgeIsMore : StoryVoiceLines.nudgeIsLess
        case .change, .transfer, .equalize, .twoStep:
            return calc.op == "+" ? StoryVoiceLines.nudgeGain : StoryVoiceLines.nudgeLose
        }
    }

    /// 能不能"数十和一"：一步的 100 以内加减，至少有一个两位数
    var tensOnes: StoryCalc? {
        guard let (calc, first) = keyCalc, !first, calc.op == "+" || calc.op == "−",
              max(calc.a, calc.b, calc.result) >= 20, calc.result <= 100 else { return nil }
        return calc
    }
}

// MARK: - 题型的名字（给孩子看的）

extension StorySchema {
    /// 练一练里告诉她这次多练哪几种
    var kidName: String {
        switch self {
        case .combine:   "Altogether"
        case .partWhole: "Find the part"
        case .change:    "Add and take away"
        case .compare:   "How many more?"
        case .inverse:   "Who has more?"
        case .transfer:  "Giving"
        case .equalize:  "Make them equal"
        case .multiply:  "Equal groups"
        case .divide:    "Sharing"
        case .twoStep:   "Two steps"
        }
    }
}

// MARK: - 新题的检查：线段图里每一段都不能太细

enum StoryCheck {
    /// 每张线段图里，最细的一段至少是最长那条的 1/14（大数目时还看得清、写得下数）
    static func proportional(_ p: StoryProblem) -> Bool {
        var models = p.models
        if let m = p.middle { models += [m.model, m.after] }
        for m in models {
            let longest = m.bars.map(\.total).max() ?? 0
            for bar in m.bars { for sg in bar.segs where sg.value * 14 < longest { return false } }
        }
        return true
    }
}

// MARK: - 练一练：多练做得不好的题型

enum StoryMix {
    static let size = 8

    struct Entry: Hashable {
        let level: StoryLevel
        let problem: StoryProblem
    }

    struct Pick {
        var entries: [Entry]
        /// 这次重点练的题型（最多两种）
        var focus: [StorySchema]
        /// 重点题型以前错过（"These were tricky before"）；没错过就是随便混着练
        var tricky: Bool
    }

    /// 一种题型有多弱：第一次就答错的、列式选错的（算半个）越多越弱；没做过的算一半
    static func weakness(right: Int, wrong: Int, opWrong: Int) -> Double {
        (Double(wrong) + 0.5 * Double(opWrong) + 1) / Double(right + wrong + 2)
    }

    /// pool：开着的关里题库的题；stats：每种题型 (第一下对, 第一下错, 选错算式)；hasStar：这道题的星星拿过了没有
    static func pick<R: RandomNumberGenerator>(pool: [Entry],
                                               stats: (StorySchema) -> (right: Int, wrong: Int, opWrong: Int),
                                               hasStar: (Entry) -> Bool,
                                               size: Int = size,
                                               using rng: inout R) -> Pick? {
        guard !pool.isEmpty else { return nil }
        let bySchema = Dictionary(grouping: pool, by: \.problem.schema)
        let weak: [StorySchema: Double] = bySchema.keys.reduce(into: [:]) { d, s in
            let st = stats(s)
            d[s] = weakness(right: st.right, wrong: st.wrong, opWrong: st.opWrong)
        }
        let tried: [StorySchema: Int] = bySchema.keys.reduce(into: [:]) { d, s in d[s] = stats(s).right + stats(s).wrong }
        let tries = { (s: StorySchema) in tried[s] ?? 0 }
        // 最弱的在前；一样弱的，做得少的在前；再一样就按题型的顺序（结果可以复现）
        let ranked = bySchema.keys.sorted {
            if weak[$0]! != weak[$1]! { return weak[$0]! > weak[$1]! }
            if tries($0) != tries($1) { return tries($0) < tries($1) }
            return StorySchema.allCases.firstIndex(of: $0)! < StorySchema.allCases.firstIndex(of: $1)!
        }
        let focus = Array(ranked.prefix(2))
        // 每种题型的候选：没拿过星星的在前（各自打乱），拿过的在后
        // 按固定的顺序打乱（字典的顺序每次运行都不一样，同一个种子要挑出同样的题）
        var queues: [StorySchema: [Entry]] = [:]
        for s in ranked {
            let list = bySchema[s]!
            let fresh = list.filter { !hasStar($0) }.shuffled(using: &rng)
            let had = list.filter(hasStar).shuffled(using: &rng)
            queues[s] = fresh + had
        }
        var chosen: [Entry] = []
        var keys = Set<String>()
        func take(_ s: StorySchema) -> Bool {
            while var q = queues[s], !q.isEmpty {
                let e = q.removeFirst()
                queues[s] = q
                if keys.insert(e.problem.starKey(level: e.level.number)).inserted { chosen.append(e); return true }
            }
            return false
        }
        // 重点：最弱的 3 道，第二弱的 2 道
        for (s, n) in zip(focus, [3, 2]) { for _ in 0..<n where chosen.count < size { _ = take(s) } }
        // 剩下的按弱的程度抽题型
        var guardCount = 0
        while chosen.count < size, guardCount < 200 {
            guardCount += 1
            let open = ranked.filter { !(queues[$0]?.isEmpty ?? true) }
            guard !open.isEmpty else { break }
            let total = open.reduce(0) { $0 + weak[$1]! }
            var x = Double.random(in: 0..<total, using: &rng)
            var s = open[open.count - 1]
            for o in open { if x < weak[o]! { s = o; break }; x -= weak[o]! }
            _ = take(s)
        }
        guard !chosen.isEmpty else { return nil }
        var tricky = false
        for s in focus where stats(s).wrong + stats(s).opWrong > 0 { tricky = true }
        return Pick(entries: chosen.shuffled(using: &rng), focus: focus, tricky: tricky)
    }

    /// "More practice: Who has more? and Sharing"
    static func headline(_ pick: Pick) -> String {
        let names = pick.focus.map(\.kidName)
        guard !names.isEmpty else { return "Practice mix" }
        return "More practice: " + names.joined(separator: " and ")
    }

    static func reason(_ pick: Pick) -> String {
        pick.tricky ? "These were tricky before. Let's practise them!" : "A mix of the stories you know."
    }
}
