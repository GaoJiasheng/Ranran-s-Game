import Foundation

// 两步题。每道题都带着"藏在中间的那一步"（StoryMiddle）：
// "Step by step" 那一关先问它（课本里的 (a)），线段图跟着长出来，再问最后的问题 (b)；
// 后面两关（画线段图、只看文字）只问最后的问题，中间那一步要自己想到。

/// 两步题中间那一问
struct StoryMiddle: Codable, Hashable {
    /// 问题："How many sweets do they have altogether?"
    var text: String
    /// 答案句，"□" 是要填的空
    var answerTemplate: String
    var answer: Int
    /// 常见的错误答案 → 解释
    var hints: [Int: String]
    /// 第一步的算式
    var explain: String
    /// 问这一步时的线段图（"?" 在中间那个数上）
    var model: BarModel
    /// 这一步答出来以后的线段图（中间那个数写上了，"?" 在最后的答案上）
    var after: BarModel
}

extension StoryFactory {
    static func middle(_ text: String, answer template: String, value: Int, explain: String,
                       model: M, after: M, hints: (inout Hints) -> Void) -> StoryMiddle {
        var h = Hints(answer: value)
        hints(&h)
        return StoryMiddle(text: text, answerTemplate: template, answer: value, hints: h.map,
                           explain: explain, model: model, after: after)
    }

    /// 线段图里把某一段的数写上 / 换成 "?"
    private static func label(_ m: M, bar: Int, seg: Int, _ text: String) -> M {
        var m = m
        m.bars[bar].segs[seg].label = text
        return m
    }

    private static func brace(_ m: M, _ b: M.Brace) -> M {
        var m = m
        m.braces.append(b)
        return m
    }

    /// 两步题第二步最多加 / 减几个
    private static func step(_ c: StoryCtx) -> Int { max(5, c.cap / 5) }

    // MARK: 吃掉一些，又得到一些

    static func twoStepLoseGain(_ c: StoryCtx) -> StoryProblem {
        let a = solo()
        let t = thing(c, food: true)
        let top = step(c)
        let n = Int.r(in: 5...(c.cap - 2))
        // 一个人一次吃不了太多
        let k1 = Int.r(in: 2...min(n - 2, 6))
        let k2 = Int.r(in: 2...max(2, min(top, c.cap - (n - k1))))
        let left = n - k1, end = left + k2
        let giver = ["Mum", "Dad", "Grandma"].pick()
        let first = M.Bar(name: "At first", tint: .a, segs: [s(left, "", cap: "left"), s(k1, cap: "ate", .gone)])
        let now = M.Bar(name: "Now", tint: .a, segs: [s(left, "", cap: "left"), s(k2, cap: "more", .solid, .extra)])
        let atFirst = M.Brace(bar: 0, from: 0, to: 1, label: "\(n)")
        let m1 = M(bars: [first], braces: [atFirst])
        let m2 = M(bars: [first, now], braces: [atFirst])
        let m3 = brace(m2, .init(bar: 1, from: 0, to: 1, label: "?"))
        var p = make(.twoStep, a: a, b: nil, thing: t, [
            .init(text: "{a} had \(t.n(n)).", actions: [.appear(.a, n)]),
            .init(text: "{a} ate \(k1) of them.", actions: [.move(.a, .away, k1)]),
            .init(text: "Then \(giver) gave {a} \(k2) more.", actions: [.move(.supply, .a, k2)]),
            .init(text: "How many \(t.many) does {a} have now?"),
        ], ask: .count(.a), answer: "{a} has □ \(t.many) now.",
           explain: "\(n) − \(k1) = \(left)   \(left) + \(k2) = \(end)",
           models: [M(bars: [M.Bar(name: "At first", tint: .a, segs: [s(n)])]), m1, m2, m3],
           supply: "\(giver)'s basket") { h in
            h.add(left, "Then \(giver) gave {a} \(k2) more. Don't forget to add them.")
            h.add(n + k2, "Don't forget: {a} ate \(k1) first.")
            h.add(n + k1 + k2, "Eating makes fewer. Getting more makes more.")
            h.add(n - k1 - k2, "Eating makes fewer. Getting more makes more.")
        }
        p.middle = middle("How many \(t.many) did {a} have after eating?",
                          answer: "{a} had □ \(t.many) after eating.", value: left,
                          explain: "\(n) − \(k1) = \(left)",
                          model: label(m1, bar: 0, seg: 0, "?"),
                          after: label(label(m3, bar: 0, seg: 0, "\(left)"), bar: 1, seg: 0, "\(left)")) { h in
            h.add(n + k1, "Eating makes fewer, not more. Take away \(k1).")
            h.add(k1, "\(k1) is how many {a} ate. How many were left?")
            h.add(n, "Don't forget: {a} ate \(k1) of them.")
        }
        return p
    }

    // MARK: 求出剩下的部分，再比较

    /// "There are 15 children. 9 are boys. The rest are girls. How many more boys than girls?"
    static func restCompare(_ c: StoryCtx) -> StoryProblem {
        let r = (c.cap > 20 ? bigRests : restContexts).pick()
        let total = Int.r(in: 8...max(8, c.cap))
        let x = Int.r(in: (total / 2 + 1)...(total - 2)), y = total - x
        let t = StoryThing(one: r.whole, many: r.whole)
        let whole = M.Brace(bar: 0, from: 0, to: 1, label: "\(total)")
        let m1 = M(bars: [M.Bar(segs: [s(x, cap: r.one, .solid, .a), s(y, "", cap: r.two, .solid, .b)])], braces: [whole])
        let final = M(bars: [M.Bar(name: r.one, tint: .a, segs: [s(x)]),
                             M.Bar(name: r.two, tint: .b, segs: [s(y, ""), s(x - y, "?", .gap)])], total: "\(total)")
        var p = make(.twoStep, a: solo(), b: nil, thing: t, [
            .init(text: "There are \(total) \(r.whole) \(r.place).", actions: [.whole(total)]),
            .init(text: "\(x) of them are \(r.one). The rest are \(r.two).", actions: [.appear(.a, x), .appear(.b, y)]),
            .init(text: "How many more \(r.phrase(r.one)) than \(r.phrase(r.two)) are there?"),
        ], ask: .more(.a, .b), answer: "There are □ more \(r.phrase(r.one)) than \(r.phrase(r.two)).",
           explain: "\(total) − \(x) = \(y)   \(x) − \(y) = \(x - y)",
           models: [
            M(bars: [M.Bar(segs: [s(total, "", .solid, .neutral)])], braces: [.init(bar: 0, from: 0, to: 0, label: "\(total)")]),
            m1, final,
           ], actable: false) { h in
            h.add(y, "\(y) is how many \(r.phrase(r.two)) there are. Now compare: how many more \(r.phrase(r.one))?")
            h.add(x, "\(x) is how many \(r.phrase(r.one)) there are. Find the \(r.ones(r.two)) first, then compare.")
            h.add(total - y, "First find the \(r.ones(r.two)): \(total) − \(x) = \(y).")
        }
        p.middle = middle("How many \(r.phrase(r.two)) are there?", answer: "There are □ \(r.phrase(r.two)).",
                          value: y, explain: "\(total) − \(x) = \(y)",
                          model: label(m1, bar: 0, seg: 1, "?"),
                          after: label(final, bar: 1, seg: 0, "\(y)")) { h in
            h.add(total + x, "\(total) is all the \(r.whole). The \(r.ones(r.one)) are inside it, so take them away.")
            h.add(total, "\(total) is all the \(r.whole). We only want the \(r.ones(r.two)).")
            h.add(x, "\(x) is how many \(r.phrase(r.one)) there are. How many are the rest?")
        }
        return p
    }

    // MARK: 先求出另一个人的，再合起来

    /// "{b} has 3 more than {a}. How many do they have altogether?"
    static func moreThenTotal(_ c: StoryCtx) -> StoryProblem {
        let (a, b) = pair()
        let t = thing(c)
        let x = Int.r(in: 3...max(3, c.cap / 2 - 1))
        let d = Int.r(in: 2...max(2, min(step(c), c.cap - 2 * x)))
        let bv = x + d
        let barA = M.Bar(name: "{a}", tint: .a, segs: [s(x)])
        let barB = M.Bar(name: "{b}", tint: .b, segs: [s(x, ""), s(d, cap: "more", .solid, .extra)])
        let final = M(bars: [barA, barB], total: "?")
        var p = make(.twoStep, a: a, b: b, thing: t, [
            .init(text: "{a} has \(t.n(x)).", actions: [.appear(.a, x)]),
            .init(text: "{b} has \(d) more \(t.word(d)) than {a}.", actions: [.build(.b, bv)]),
            .init(text: "How many \(t.many) do they have altogether?"),
        ], ask: .total, answer: "They have □ \(t.many) altogether.",
           explain: "{b}: \(x) + \(d) = \(bv)   \(x) + \(bv) = \(x + bv)",
           models: [M(bars: [barA]), M(bars: [barA, barB]), final]) { h in
            h.add(bv, "\(bv) is only {b}'s. Add {a}'s \(x) too.")
            h.add(x + d, "First find {b}'s: \(x) + \(d) = \(bv). Then put them together.")
            h.add(2 * x, "Don't forget: {b} has \(d) more than {a}.")
            h.add(x, "\(x) is only {a}'s. Find {b}'s, then put them together.")
        }
        p.middle = middle("How many \(t.many) does {b} have?", answer: "{b} has □ \(t.many).",
                          value: bv, explain: "\(x) + \(d) = \(bv)",
                          model: M(bars: [barA, barB], braces: [.init(bar: 1, from: 0, to: 1, label: "?")]),
                          after: brace(final, .init(bar: 1, from: 0, to: 1, label: "\(bv)"))) { h in
            h.add(x - d, "{b} has MORE than {a}, so {b}'s number is bigger.")
            h.add(d, "\(d) is only the difference. Start from {a}'s \(x).")
            h.add(x, "{b} doesn't have the same number as {a}. {b} has \(d) more.")
        }
        return p
    }

    /// "{b} has 4 fewer than {a}. How many do they have altogether?"
    static func fewerThenTotal(_ c: StoryCtx) -> StoryProblem {
        let (a, b) = pair()
        let t = thing(c)
        let x = Int.r(in: 5...max(5, (c.cap + 2) / 2))
        let d = Int.r(in: 2...min(x - 2, step(c)))
        let bv = x - d, total = x + bv
        let barA = M.Bar(name: "{a}", tint: .a, segs: [s(x)])
        let barB = M.Bar(name: "{b}", tint: .b, segs: [s(bv, ""), s(d, cap: "fewer", .gap)])
        let final = M(bars: [barA, barB], total: "?")
        var p = make(.twoStep, a: a, b: b, thing: t, [
            .init(text: "{a} has \(t.n(x)).", actions: [.appear(.a, x)]),
            .init(text: "{b} has \(d) fewer \(t.word(d)) than {a}.", actions: [.build(.b, bv)]),
            .init(text: "How many \(t.many) do they have altogether?"),
        ], ask: .total, answer: "They have □ \(t.many) altogether.",
           explain: "{b}: \(x) − \(d) = \(bv)   \(x) + \(bv) = \(total)",
           models: [M(bars: [barA]), M(bars: [barA, barB]), final], actable: false) { h in
            h.add(bv, "\(bv) is only {b}'s. Add {a}'s \(x) too.")
            h.add(2 * x, "Don't forget: {b} has \(d) fewer than {a}.")
            h.add(2 * x + d, "{b} has FEWER than {a}. Take away to find {b}'s first.")
            h.add(x, "\(x) is only {a}'s. Find {b}'s, then put them together.")
        }
        p.middle = middle("How many \(t.many) does {b} have?", answer: "{b} has □ \(t.many).",
                          value: bv, explain: "\(x) − \(d) = \(bv)",
                          model: label(M(bars: [barA, barB]), bar: 1, seg: 0, "?"),
                          after: label(final, bar: 1, seg: 0, "\(bv)")) { h in
            h.add(x + d, "{b} has FEWER than {a}, so {b}'s number is smaller.")
            h.add(d, "\(d) is only the difference. Start from {a}'s \(x).")
            h.add(x, "{b} doesn't have the same number as {a}. {b} has \(d) fewer.")
        }
        return p
    }

    // MARK: 先合起来，再平均分

    static func totalThenShare(_ c: StoryCtx) -> StoryProblem {
        let (a, b) = pair()
        let t = thing(c)
        var g = 0, q = 0, x = 0
        repeat {
            g = Int.r(in: 2...(c.cap >= 50 ? 5 : 4))
            q = Int.r(in: 2...min(c.cap >= 50 ? 10 : 5, c.cap / g))
            x = Int.r(in: 2...(g * q - 2))
        } while g * q < 6 || 2 * x == g * q
        let total = g * q, y = total - x
        let box = t.food ? "plate" : ["bag", "box"].pick()
        let boxes = StoryText.plural(box)
        let put = box == "plate" ? "on \(g) plates" : "into \(g) \(boxes)"
        let each = box == "plate" ? "on each plate" : "in each \(box)"
        let together = M.Bar(name: "", tint: .a, segs: [s(x, cap: "{a}", .solid, .a), s(y, cap: "{b}", .solid, .b)])
        let shared = M.Bar(name: "", tint: .a, segs: (0..<g).map { _ in s(q, "", .solid, .neutral) })
        let m3 = label(M(bars: [together, shared]), bar: 1, seg: 0, "?")
        var p = make(.twoStep, a: a, b: b, thing: t, [
            .init(text: "{a} has \(t.n(x)).", actions: [.appear(.a, x)]),
            .init(text: "{b} has \(t.n(y)).", actions: [.appear(.b, y)]),
            .init(text: "They put all the \(t.many) equally \(put).", actions: [.move(.b, .a, y), .plates(g), .share]),
            .init(text: "How many \(t.many) are there \(each)?"),
        ], ask: .perPlate, answer: "There are □ \(t.many) \(each).",
           explain: "\(x) + \(y) = \(total)   \(total) ÷ \(g) = \(q)",
           models: [M(bars: [M.Bar(segs: [s(x, cap: "{a}", .solid, .a)])]), M(bars: [together]),
                    M(bars: [together, shared]), m3],
           plate: box, actable: false) { h in
            h.add(total, "\(total) is all of them. Now share them equally \(put).")
            h.add(g, "\(g) is how many \(boxes). How many go \(each)?")
            h.add(total - g, "Sharing equally means every \(box) gets the same number.")
            h.add(total + g, "When we share, each \(box) gets fewer, not more.")
        }
        p.middle = middle("How many \(t.many) do they have altogether?", answer: "They have □ \(t.many) altogether.",
                          value: total, explain: "\(x) + \(y) = \(total)",
                          model: M(bars: [together], braces: [.init(bar: 0, from: 0, to: 1, label: "?")]),
                          after: brace(m3, .init(bar: 0, from: 0, to: 1, label: "\(total)"))) { h in
            h.add(abs(x - y), "That is how many more one of them has. Altogether means we put both parts together.")
            h.add(x, "\(x) is only {a}'s part. Add {b}'s part too.")
            h.add(y, "\(y) is only {b}'s part. Add {a}'s part too.")
        }
        return p
    }

    // MARK: 先求几个几，再添上 / 拿走

    static func groupsThenMore(_ c: StoryCtx) -> StoryProblem {
        let a = solo()
        let t = thing(c)
        let g = Int.r(in: 2...(c.cap >= 50 ? 5 : 4))
        let n = Int.r(in: 2...min(c.cap >= 50 ? 10 : 5, (c.cap - 2) / g))
        let k = Int.r(in: 2...max(2, min(9, c.cap - g * n)))
        let inBoxes = g * n, total = inBoxes + k
        let box = ["bag", "box", "packet"].pick()
        let boxes = StoryText.plural(box)
        let giver = ["Mum", "Dad", "Grandma", "Grandpa"].pick()
        let units = M(bars: [M.Bar(segs: (0..<g).map { _ in s(n, "", .solid, .neutral) })])
        let groups = M(bars: [M.Bar(segs: (0..<g).map { _ in s(n, nil, .solid, .neutral) })])
        var plus = groups
        plus.bars[0].segs.append(s(k, cap: "more", .solid, .extra))
        let m3 = brace(plus, .init(bar: 0, from: 0, to: g, label: "?"))
        let skip = (1...g).map { "\($0 * n)" }.joined(separator: ", ")
        var p = make(.twoStep, a: a, b: nil, thing: t, [
            .init(text: "{a} has \(g) \(boxes) of \(t.many).", actions: [.plates(g)]),
            .init(text: "There are \(t.n(n)) in each \(box).", actions: [.fill(n)]),
            .init(text: "\(giver) gives {a} \(k) more \(t.many).", actions: [.gather, .move(.supply, .a, k)]),
            .init(text: "How many \(t.many) does {a} have now?"),
        ], ask: .count(.a), answer: "{a} has □ \(t.many) now.",
           explain: "\(g) × \(n) = \(inBoxes)   \(inBoxes) + \(k) = \(total)",
           models: [units, groups, plus, m3], supply: "\(giver)'s basket", plate: box, actable: false) { h in
            h.add(inBoxes, "\(inBoxes) is only the \(t.many) in the \(boxes). Don't forget the \(k) more from \(giver).")
            h.add(inBoxes - k, "Getting more makes more, not fewer.")
            h.add(n + k, "\(n) is just one \(box). There are \(g) \(boxes).")
            h.add(g + n + k, "There are \(n) in each \(box). Find how many are in the \(boxes) first.")
        }
        p.middle = middle("How many \(t.many) are there in the \(g) \(boxes)?",
                          answer: "There are □ \(t.many) in the \(g) \(boxes).", value: inBoxes,
                          explain: "\(g) × \(n) = \(inBoxes)",
                          model: brace(groups, .init(bar: 0, from: 0, to: g - 1, label: "?")),
                          after: brace(m3, .init(bar: 0, from: 0, to: g - 1, label: "\(inBoxes)", below: true))) { h in
            h.add(g + n, "Count \(n) for every \(box): \(skip).")
            h.add(n, "\(n) is just one \(box). There are \(g) \(boxes).")
            h.add(g, "\(g) is how many \(boxes). Count all the \(t.many).")
        }
        return p
    }

    static func groupsThenEaten(_ c: StoryCtx) -> StoryProblem {
        let a = solo()
        let food = Bool.r()
        let t = thing(c, food: food)
        let g = Int.r(in: 2...(c.cap >= 50 ? 5 : 4))
        let n = Int.r(in: 2...min(c.cap >= 50 ? 10 : 5, c.cap / g))
        let all = g * n
        let k = Int.r(in: 2...(food ? min(all - 2, 6) : all - 2))
        let left = all - k
        let (box, verb, away) = food ? ("plate", "ate", "Eaten") : ("box", "gave away", "Given away")
        let boxes = StoryText.plural(box)
        let lines = food
            ? ["There are \(g) plates.", "Each plate has \(t.n(n)).", "{a} eats \(k) of the \(t.many).",
               "How many \(t.many) are left?"]
            : ["{a} has \(g) boxes of \(t.many).", "There are \(t.n(n)) in each box.",
               "{a} gives away \(k) of the \(t.many).", "How many \(t.many) does {a} have left?"]
        let units = M(bars: [M.Bar(segs: (0..<g).map { _ in s(n, "", .solid, .neutral) })])
        let groups = M(bars: [M.Bar(segs: (0..<g).map { _ in s(n, nil, .solid, .neutral) })])
        var after = groups
        after.bars.append(M.Bar(name: "", tint: .a, segs: [s(left, "", cap: "left", .solid, .a), s(k, cap: verb, .gone)]))
        let m3 = label(after, bar: 1, seg: 0, "?")
        let skip = (1...g).map { "\($0 * n)" }.joined(separator: ", ")
        var p = make(.twoStep, a: a, b: nil, thing: t, [
            .init(text: lines[0], actions: [.plates(g)]),
            .init(text: lines[1], actions: [.fill(n)]),
            .init(text: lines[2], actions: [.gather, .move(.a, .away, k)]),
            .init(text: lines[3]),
        ], ask: .count(.a), answer: food ? "There are □ \(t.many) left." : "{a} has □ \(t.many) left.",
           explain: "\(g) × \(n) = \(all)   \(all) − \(k) = \(left)",
           models: [units, groups, after, m3], away: away, plate: box, actable: false) { h in
            h.add(all, "\(all) is how many there were at first. Then {a} \(food ? "ate" : "gave away") \(k).")
            h.add(all + k, food ? "Eating makes fewer, not more." : "Giving away makes fewer, not more.")
            h.add(k, "\(k) is how many {a} \(food ? "ate" : "gave away"). How many are left?")
            h.add(n - k, "\(n) is just one \(box). Find how many are in all \(g) \(boxes) first.")
        }
        p.middle = middle(food ? "How many \(t.many) are there on the \(g) plates?"
                               : "How many \(t.many) are there in the \(g) boxes?",
                          answer: food ? "There are □ \(t.many) on the \(g) plates." : "There are □ \(t.many) in the \(g) boxes.",
                          value: all, explain: "\(g) × \(n) = \(all)",
                          model: brace(groups, .init(bar: 0, from: 0, to: g - 1, label: "?")),
                          after: brace(m3, .init(bar: 0, from: 0, to: g - 1, label: "\(all)"))) { h in
            h.add(g + n, "Count \(n) for every \(box): \(skip).")
            h.add(n, "\(n) is just one \(box). There are \(g) \(boxes).")
            h.add(g, "\(g) is how many \(boxes). Count all the \(t.many).")
        }
        return p
    }

    // MARK: 买两样东西，还剩多少钱

    static func spendTwo(_ c: StoryCtx) -> StoryProblem {
        let a = solo()
        let money = c.cap >= 50 ? [20, 30, 40, 50].pick() : Int.r(in: 10...c.cap)
        let p1 = Int.r(in: 2...(money - 4))
        let p2 = Int.r(in: 2...(money - 2 - p1))
        let spent = p1 + p2, left = money - spent
        let items = Array(shopItems.mixed().prefix(2))
        let whole = M.Brace(bar: 0, from: 0, to: 2, label: "\(money)")
        let m1 = M(bars: [M.Bar(segs: [s(left, "", cap: "left"), s(p1, cap: items[0], .gone), s(p2, cap: items[1], .gone)])],
                   braces: [whole])
        let m2 = label(m1, bar: 0, seg: 0, "?")
        var p = make(.twoStep, a: a, b: nil, thing: dollars, [
            .init(text: "{a} has \(money) dollars.", actions: [.appear(.a, money)]),
            .init(text: "{a} buys a \(items[0]) for \(p1) dollars and a \(items[1]) for \(p2) dollars.",
                  actions: [.move(.a, .away, p1), .move(.a, .away, p2)]),
            .init(text: "How much money does {a} have left?"),
        ], ask: .count(.a), answer: "{a} has □ dollars left.",
           explain: "\(p1) + \(p2) = \(spent)   \(money) − \(spent) = \(left)",
           models: [M(bars: [M.Bar(segs: [s(money, "")])], braces: [.init(bar: 0, from: 0, to: 0, label: "\(money)")]), m1, m2],
           away: "Spent", actable: false) { h in
            h.add(spent, "\(spent) dollars is what {a} spends. How much is left?")
            h.add(money - p1, "Don't forget the \(items[1]) too.")
            h.add(money - p2, "Don't forget the \(items[0]) too.")
            h.add(money + spent, "Spending makes the money less, not more.")
        }
        p.generic = "First find how much {a} spends. Then take it away."
        p.middle = middle("How much does {a} spend?", answer: "{a} spends □ dollars.", value: spent,
                          explain: "\(p1) + \(p2) = \(spent)",
                          model: brace(m1, .init(bar: 0, from: 1, to: 2, label: "?", below: true)),
                          after: brace(m2, .init(bar: 0, from: 1, to: 2, label: "\(spent)", below: true))) { h in
            h.add(p1, "\(p1) dollars is only the \(items[0]). Add the \(items[1]) too.")
            h.add(p2, "\(p2) dollars is only the \(items[1]). Add the \(items[0]) too.")
            h.add(abs(p1 - p2), "We add the two prices to find how much {a} spends.")
        }
        return p
    }
}
