import Foundation

// 「Numbers to 100」那一章：100 以内的加减应用题（新加坡二年级）。
// 题型都是前面学过的（合起来、添上拿走、求部分、比多少、多几少几），只是数变大了：
// 数东西、钱（dollars）、长度（cm、m）。第一关不进位不退位，第二关都要进位或退位，读题关混着来。
// 这么大的数没法一个一个摆出来，所以没有"演一演"：先画线段图，再"数十和一"（tens and ones）。

extension StoryFactory {
    /// 题目里说的是什么：数东西、钱、长度（cm）、距离（m）
    enum BigKind { case things, money, length, distance }

    /// 数大的时候常用的东西（都是不吃的，几十个也说得通）
    static let bigThings: [StoryThing] = [
        StoryThing(one: "marble", many: "marbles"),
        StoryThing(one: "stamp", many: "stamps"),
        StoryThing(one: "bead", many: "beads"),
        StoryThing(one: "seashell", many: "seashells"),
        StoryItem.sticker.thing,
        StoryThing(one: "crayon", many: "crayons"),
    ]

    /// 买得起的东西：一样一样都在 100 块钱以内
    static let shopItems = ["storybook", "doll", "kite", "bag", "cap", "puzzle", "toy car",
                            "water bottle", "teddy bear", "board game", "lunch box", "skipping rope"]

    static let dollars = StoryThing(one: "dollar", many: "dollars")
    static let cm = StoryThing(one: "cm", many: "cm")
    static let metres = StoryThing(one: "m", many: "m")

    static func capitalized(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }

    private static func bigKind(distance: Bool = false) -> BigKind {
        // 数东西多一点（和前面几章接得上），钱和长度各占一份
        var kinds: [BigKind] = [.things, .things, .money, .length]
        if distance { kinds.append(.distance) }
        return kinds.pick()
    }

    // MARK: 数

    /// 这道加法 / 减法要不要进位 / 退位，和这一关要的一样
    static func fits(_ x: Int, _ op: Character, _ y: Int, _ regroup: Bool?) -> Bool {
        // 两个都是整十（40 + 30）太简单了，不要
        if x % 10 == 0 && y % 10 == 0 { return false }
        guard let regroup else { return true }
        let carry = op == "+" ? x % 10 + y % 10 >= 10 : x % 10 < y % 10
        return carry == regroup
    }

    /// 两个加数，都至少是 lo，和不超过 cap
    static func addends(_ c: StoryCtx, lo: Int = 10) -> (Int, Int) {
        while true {
            let total = Int.r(in: (2 * lo)...c.cap)
            let x = Int.r(in: lo...(total - lo)), y = total - x
            if fits(x, "+", y, c.regroup) { return (x, y) }
        }
    }

    /// 被减数和减数：差和减数都至少是 lo，被减数不超过 99
    static func minuend(_ c: StoryCtx, lo: Int = 10) -> (Int, Int) {
        while true {
            let big = Int.r(in: (2 * lo)...min(c.cap, 99))
            let small = Int.r(in: lo...(big - lo))
            if fits(big, "−", small, c.regroup) { return (big, small) }
        }
    }

    /// 进位、退位最容易错的地方：加法忘了把满十的进上去；减法个位"大减小"倒过来减
    static func carryHints(_ h: inout Hints, _ x: Int, _ op: Character, _ y: Int) {
        if op == "+", x % 10 + y % 10 >= 10 {
            let ones = x % 10 + y % 10
            let rest = ones - 10 == 0 ? "" : ones - 10 == 1 ? " and 1 one" : " and \(ones - 10) ones"
            h.add(x + y - 10, "Did you add the ten from the ones? \(x % 10) + \(y % 10) = \(ones) ones. That is 1 ten\(rest).")
        }
        if op == "−", x % 10 < y % 10 {
            let flipped = (x / 10 - y / 10) * 10 + (y % 10 - x % 10)
            h.add(flipped, "Look at the ones: \(x % 10) is less than \(y % 10). Change 1 ten into 10 ones first: \(x % 10 + 10) − \(y % 10) = \(x % 10 + 10 - y % 10).")
            h.add(x - y + 10, "You changed 1 ten into 10 ones, so there is 1 ten fewer now.")
        }
    }

    // MARK: 合起来

    static func bigCombine(_ c: StoryCtx) -> StoryProblem {
        let (a, b) = pair()
        let (x, y) = addends(c)
        let total = x + y
        let kind = bigKind(distance: true)
        var t = bigThings.pick()
        var lines: [String], answer: String, caps: (String, String)
        var partHint: (Int, String) -> String
        var diffHint: String
        var generic: String? = nil
        switch kind {
        case .things:
            lines = ["{a} has \(t.n(x)).", "{b} has \(t.n(y)).", "How many \(t.many) do they have altogether?"]
            answer = "They have □ \(t.many) altogether."
            caps = ("{a}", "{b}")
            partHint = { v, who in "\(v) is only \(who)'s part. Add the other part too." }
            diffHint = "That is how many more one of them has. Altogether means we put both parts together."
        case .money:
            t = dollars
            let two = Array(shopItems.mixed().prefix(2))
            lines = ["A \(two[0]) costs \(x) dollars.", "A \(two[1]) costs \(y) dollars.",
                     "How much do the \(two[0]) and the \(two[1]) cost altogether?"]
            answer = "They cost □ dollars altogether."
            caps = (two[0], two[1])
            partHint = { v, item in "\(v) dollars is only the \(item). Add the other price too." }
            diffHint = "That is how much more one of them costs. Altogether means we add both prices."
            generic = "Altogether means we add the two prices."
        case .length:
            t = cm
            lines = ["{a}'s ribbon is \(x) cm long.", "{b}'s ribbon is \(y) cm long.",
                     "What is the total length of the two ribbons?"]
            answer = "The total length is □ cm."
            caps = ("{a}", "{b}")
            partHint = { v, who in "\(v) cm is only \(who)'s ribbon. Add the other ribbon too." }
            diffHint = "That is how much longer one ribbon is. The total length means we add both lengths."
            generic = "The total length means we add the two lengths."
        case .distance:
            t = metres
            lines = ["{a} ran \(x) m in the morning.", "{a} ran \(y) m in the afternoon.",
                     "How far did {a} run altogether?"]
            answer = "{a} ran □ m altogether."
            caps = ("morning", "afternoon")
            partHint = { v, part in "\(v) m is only the \(part) run. Add the other run too." }
            diffHint = "That is how much farther one run was. Altogether means we add both parts."
            generic = "Altogether means we add the two parts."
        }
        let tints: (M.Tint, M.Tint) = kind == .distance ? (.a, .extra) : (.a, .b)
        let m0 = M(bars: [M.Bar(segs: [s(x, cap: caps.0, .solid, tints.0)])])
        let m1 = M(bars: [M.Bar(segs: [s(x, cap: caps.0, .solid, tints.0), s(y, cap: caps.1, .solid, tints.1)])])
        var m2 = m1
        m2.braces = [.init(bar: 0, from: 0, to: 1, label: "?")]
        let whoX = kind == .things || kind == .length ? "{a}" : caps.0
        let whoY = kind == .things || kind == .length ? "{b}" : caps.1
        var p = make(.combine, a: a, b: kind == .distance ? nil : b, thing: t, [
            .init(text: lines[0], actions: [.appear(.a, x)]),
            .init(text: lines[1], actions: [.appear(kind == .distance ? .a : .b, y)]),
            .init(text: lines[2]),
        ], ask: kind == .distance ? .count(.a) : .total, answer: answer,
           explain: "\(x) + \(y) = \(total)", models: [m0, m1, m2], actable: false) { h in
            h.add(abs(x - y), diffHint)
            h.add(x, partHint(x, whoX))
            h.add(y, partHint(y, whoY))
            carryHints(&h, x, "+", y)
        }
        p.generic = generic
        return p
    }

    // MARK: 拿走

    static func bigChangeLose(_ c: StoryCtx) -> StoryProblem {
        let a = solo()
        let (n, k) = minuend(c)
        let left = n - k
        let kind = bigKind()
        var t = bigThings.pick()
        let lines: [String], answer: String, caption: String, away: String
        let more: String, part: String, forgot: String
        var generic: String? = nil
        switch kind {
        case .things, .distance:
            let (verb, cap, box) = [("gave away", "gave away", "Given away"), ("lost", "lost", "Lost")].pick()
            lines = ["{a} had \(t.n(n)).", "{a} \(verb) \(k) of them.", "How many \(t.many) did {a} have left?"]
            answer = "{a} had □ \(t.many) left."
            caption = cap; away = box
            more = "Some \(t.many) went away, so {a} has fewer now, not more. Take away \(k)."
            part = "\(k) is how many went away. We want how many are left."
            forgot = "Don't forget: {a} \(verb) \(k) of them."
        case .money:
            t = dollars
            let item = shopItems.pick()
            lines = ["{a} had \(n) dollars.", "{a} spent \(k) dollars on a \(item).", "How much money did {a} have left?"]
            answer = "{a} had □ dollars left."
            caption = "spent"; away = "Spent"
            more = "Spending makes the money less, not more. Take away \(k)."
            part = "\(k) dollars is what {a} spent. We want what is left."
            forgot = "Don't forget: {a} spent \(k) dollars."
            generic = "Start with the money {a} had, then take away what {a} spent."
        case .length:
            t = cm
            lines = ["{a} had a ribbon \(n) cm long.", "{a} cut off \(k) cm of it.", "How long is the ribbon now?"]
            answer = "The ribbon is □ cm long now."
            caption = "cut off"; away = "Cut off"
            more = "Cutting makes the ribbon shorter, not longer. Take away \(k) cm."
            part = "\(k) cm is the part that was cut off. We want the part that is left."
            forgot = "Don't forget: {a} cut off \(k) cm."
            generic = "Start with the whole ribbon, then take away the part that was cut off."
        }
        let whole = M.Brace(bar: 0, from: 0, to: 1, label: "\(n)")
        var p = make(.change, a: a, b: nil, thing: t, [
            .init(text: lines[0], actions: [.appear(.a, n)]),
            .init(text: lines[1], actions: [.move(.a, .away, k)]),
            .init(text: lines[2]),
        ], ask: .count(.a), answer: answer, explain: "\(n) − \(k) = \(left)",
           models: [
            M(bars: [M.Bar(segs: [s(n, "", .solid, .a)])], braces: [.init(bar: 0, from: 0, to: 0, label: "\(n)")]),
            M(bars: [M.Bar(segs: [s(left, "", cap: "left"), s(k, cap: caption, .gone)])], braces: [whole]),
            M(bars: [M.Bar(segs: [s(left, "?", cap: "left"), s(k, cap: caption, .gone)])], braces: [whole]),
           ], away: away, actable: false) { h in
            h.add(n + k, more)
            h.add(k, part)
            h.add(n, forgot)
            carryHints(&h, n, "−", k)
        }
        p.generic = generic
        return p
    }

    // MARK: 添上

    /// "There were 46 children in the hall. 28 more children came in."
    private struct Crowd { let many: String, place: String, came: String }
    private static let crowds = [
        Crowd(many: "children", place: "in the hall", came: "came in"),
        Crowd(many: "people", place: "on the bus", came: "got on"),
        Crowd(many: "birds", place: "in the tree", came: "flew in"),
        Crowd(many: "ducks", place: "in the pond", came: "joined them"),
    ]

    static func bigChangeGain(_ c: StoryCtx) -> StoryProblem {
        let a = solo()
        let (n, k) = addends(c)
        let total = n + k
        let kind = bigKind()
        var t = bigThings.pick()
        let lines: [String], answer: String
        let less: String, newPart: String, forgot: String
        var generic: String? = nil
        switch kind {
        case .things, .distance:
            let cr = crowds.pick()
            t = StoryThing(one: cr.many, many: cr.many)
            lines = ["There were \(n) \(cr.many) \(cr.place).", "\(k) more \(cr.many) \(cr.came).",
                     "How many \(cr.many) are \(cr.place) now?"]
            answer = "There are □ \(cr.many) \(cr.place) now."
            less = "More \(cr.many) came, so there are more now. Add them together."
            newPart = "\(k) is how many more came. Don't forget the \(n) at first."
            forgot = "Don't forget the \(k) more \(cr.many)."
            generic = "Start with the \(cr.many) at first, then add the ones who came."
        case .money:
            t = dollars
            let giver = ["Mum", "Dad", "Grandma", "Grandpa"].pick()
            lines = ["{a} had \(n) dollars.", "\(giver) gave {a} \(k) dollars more.", "How much money does {a} have now?"]
            answer = "{a} has □ dollars now."
            less = "{a} got more money, so {a} has more now. Add them together."
            newPart = "\(k) dollars is the new money. Add the \(n) dollars {a} had at first."
            forgot = "Don't forget the \(k) dollars from \(giver)."
        case .length:
            t = cm
            lines = ["{a} made a paper chain \(n) cm long.", "{a} added \(k) cm more to it.", "How long is the paper chain now?"]
            answer = "The paper chain is □ cm long now."
            less = "Adding makes the chain longer, not shorter. Add the two lengths."
            newPart = "\(k) cm is the new part. Add the \(n) cm at first."
            forgot = "Don't forget the \(k) cm that {a} added."
            generic = "Start with the chain at first, then add the new part."
        }
        let m1 = M(bars: [M.Bar(segs: [s(n, cap: "at first"), s(k, cap: "more", .solid, .extra)])])
        var m2 = m1
        m2.braces = [.init(bar: 0, from: 0, to: 1, label: "?")]
        var p = make(.change, a: a, b: nil, thing: t, [
            .init(text: lines[0], actions: [.appear(.a, n)]),
            .init(text: lines[1], actions: [.move(.supply, .a, k)]),
            .init(text: lines[2]),
        ], ask: .count(.a), answer: answer, explain: "\(n) + \(k) = \(total)",
           models: [M(bars: [M.Bar(segs: [s(n, cap: "at first")])]), m1, m2], actable: false) { h in
            h.add(n - k, less)
            h.add(k, newPart)
            h.add(n, forgot)
            carryHints(&h, n, "+", k)
        }
        p.generic = generic
        return p
    }

    // MARK: 求部分

    static let bigRests: [RestContext] = [
        RestContext(whole: "children", place: "at the playground", one: "boys", two: "girls", adjective: false),
        RestContext(whole: "children", place: "at the swimming pool", one: "girls", two: "boys", adjective: false),
        RestContext(whole: "flowers", place: "in the garden", one: "red", two: "yellow", adjective: true),
        RestContext(whole: "marbles", place: "in a jar", one: "blue", two: "green", adjective: true),
        RestContext(whole: "balloons", place: "at the party", one: "pink", two: "white", adjective: true),
        RestContext(whole: "fish", place: "in the pond", one: "orange", two: "black", adjective: true),
        RestContext(whole: "cars", place: "in the car park", one: "red", two: "blue", adjective: true),
    ]

    static func bigPartWhole(_ c: StoryCtx) -> StoryProblem {
        let (a, b) = pair()
        let (total, x) = minuend(c)
        let y = total - x
        let kind = bigKind()
        var t = bigThings.pick()
        let lines: [String], answer: String, caps: (String, String)
        let inside: String, both: String, onePart: String
        var generic: String? = nil
        var twoPeople = true
        switch kind {
        case .things, .distance:
            let r = bigRests.pick()
            t = StoryThing(one: r.whole, many: r.whole)
            twoPeople = false
            lines = ["There are \(total) \(r.whole) \(r.place).", "\(x) of them are \(r.one). The rest are \(r.two).",
                     "How many \(r.phrase(r.two)) are there?"]
            answer = "There are □ \(r.phrase(r.two))."
            caps = (r.one, r.two)
            inside = "\(total) is all the \(r.whole). The \(r.ones(r.one)) are inside it, so take them away."
            both = "\(total) is all the \(r.whole). We only want the \(r.ones(r.two))."
            onePart = "\(x) is how many \(r.phrase(r.one)) there are. How many are the rest?"
        case .money:
            t = dollars
            lines = ["{a} and {b} have \(total) dollars altogether.", "{a} has \(x) dollars.", "How much money does {b} have?"]
            answer = "{b} has □ dollars."
            caps = ("{a}", "{b}")
            inside = "\(total) dollars is all the money. {a}'s \(x) dollars are inside it, so take them away."
            both = "\(total) dollars is for both of them. We only want {b}'s part."
            onePart = "\(x) dollars is {a}'s part. How much is left for {b}?"
            generic = "Start with all the money, then take away {a}'s part."
        case .length:
            t = cm
            twoPeople = false
            lines = ["A ribbon is \(total) cm long.", "{a} cuts it into two pieces. One piece is \(x) cm long.",
                     "How long is the other piece?"]
            answer = "The other piece is □ cm long."
            caps = ("one piece", "other piece")
            inside = "\(total) cm is the whole ribbon. The \(x) cm piece is part of it, so take it away."
            both = "\(total) cm is the whole ribbon. We only want the other piece."
            onePart = "\(x) cm is one piece. How long is the other piece?"
            generic = "Start with the whole ribbon, then take away the piece we know."
        }
        let whole = M.Brace(bar: 0, from: 0, to: 1, label: "\(total)")
        var p = make(.partWhole, a: a, b: twoPeople ? b : nil, thing: t, [
            .init(text: lines[0], actions: [.whole(total)]),
            .init(text: lines[1], actions: [.appear(.a, x)]),
            .init(text: lines[2], actions: [.build(.b, y)]),
        ], ask: .count(.b), answer: answer, explain: "\(total) − \(x) = \(y)",
           models: [
            M(bars: [M.Bar(segs: [s(total, "", .solid, .neutral)])], braces: [.init(bar: 0, from: 0, to: 0, label: "\(total)")]),
            M(bars: [M.Bar(segs: [s(x, cap: caps.0, .solid, .a), s(y, "", cap: caps.1, .solid, .b)])], braces: [whole]),
            M(bars: [M.Bar(segs: [s(x, cap: caps.0, .solid, .a), s(y, "?", cap: caps.1, .solid, .b)])], braces: [whole]),
           ], actable: false) { h in
            h.add(total + x, inside)
            h.add(total, both)
            h.add(x, onePart)
            carryHints(&h, total, "−", x)
        }
        p.generic = generic
        return p
    }

    // MARK: 比多少

    static func bigCompare(_ c: StoryCtx) -> StoryProblem {
        let (a, b) = pair()
        let (big, small) = minuend(c)
        let d = big - small
        let aBig = Bool.r()
        let (x, y) = aBig ? (big, small) : (small, big)
        let (bs, ss): (Spot, Spot) = aBig ? (.a, .b) : (.b, .a)
        let askFewer = Bool.r()
        let kind = bigKind(distance: true)
        var t = bigThings.pick()
        var names = ("{a}", "{b}")
        let lines: [String], question: String, answer: String
        var generic: String? = nil
        var unit: (Int) -> String = { "\($0)" }
        switch kind {
        case .things:
            lines = ["{a} has \(t.n(x)).", "{b} has \(t.n(y))."]
            question = askFewer ? "How many fewer \(t.many) does \(ph(ss)) have than \(ph(bs))?"
                                : "How many more \(t.many) does \(ph(bs)) have than \(ph(ss))?"
            answer = askFewer ? "\(ph(ss)) has □ fewer \(t.many) than \(ph(bs))."
                              : "\(ph(bs)) has □ more \(t.many) than \(ph(ss))."
        case .money:
            t = dollars
            let two = Array(shopItems.mixed().prefix(2))
            names = (capitalized(two[0]), capitalized(two[1]))
            let item = { (s: Spot) in s == .a ? two[0] : two[1] }
            lines = ["A \(two[0]) costs \(x) dollars.", "A \(two[1]) costs \(y) dollars."]
            question = askFewer ? "How much cheaper is the \(item(ss)) than the \(item(bs))?"
                                : "How much more does the \(item(bs)) cost than the \(item(ss))?"
            answer = askFewer ? "The \(item(ss)) is □ dollars cheaper than the \(item(bs))."
                              : "The \(item(bs)) costs □ dollars more than the \(item(ss))."
            generic = "Compare the two prices: take away the smaller one from the bigger one."
            unit = { "\($0) dollars" }
        case .length:
            t = cm
            lines = ["{a}'s ribbon is \(x) cm long.", "{b}'s ribbon is \(y) cm long."]
            question = askFewer ? "How much shorter is \(ph(ss))'s ribbon than \(ph(bs))'s?"
                                : "How much longer is \(ph(bs))'s ribbon than \(ph(ss))'s?"
            answer = askFewer ? "\(ph(ss))'s ribbon is □ cm shorter than \(ph(bs))'s."
                              : "\(ph(bs))'s ribbon is □ cm longer than \(ph(ss))'s."
            generic = "Compare the two lengths: take away the shorter one from the longer one."
            unit = { "\($0) cm" }
        case .distance:
            t = metres
            lines = ["{a} ran \(x) m.", "{b} ran \(y) m."]
            question = "How much farther did \(ph(bs)) run than \(ph(ss))?"
            answer = "\(ph(bs)) ran □ m farther than \(ph(ss))."
            generic = "Compare the two distances: take away the shorter one from the longer one."
            unit = { "\($0) m" }
        }
        let barA = M.Bar(name: names.0, tint: .a, segs: [s(x)])
        let barB = M.Bar(name: names.1, tint: .b, segs: [s(y)])
        var withGap = [barA, barB]
        withGap[aBig ? 1 : 0].segs.append(s(d, "?", .gap))
        let isFewer = askFewer && kind != .distance
        var p = make(.compare, a: a, b: b, thing: t, [
            .init(text: lines[0], actions: [.appear(.a, x)]),
            .init(text: lines[1], actions: [.appear(.b, y)]),
            .init(text: question),
        ], ask: isFewer ? .less(ss, bs) : .more(bs, ss), answer: answer,
           explain: "\(big) − \(small) = \(d)",
           models: [M(bars: [barA]), M(bars: [barA, barB]), M(bars: withGap)], actable: false) { h in
            h.add(x + y, "We are comparing, not putting together. Take away to find the difference.")
            h.add(big, "\(unit(big)) is the bigger one. We want the difference.")
            h.add(small, "\(unit(small)) is the smaller one. We want the difference.")
            carryHints(&h, big, "−", small)
        }
        p.generic = generic
        return p
    }

    // MARK: 多几、少几，求一个数

    static func bigMoreFewer(_ c: StoryCtx) -> StoryProblem { bigRelation(c, [Relation.aMore, .aFewer].pick()) }
    /// "{b}'s ribbon is 15 cm shorter than {a}'s" —— 看到 shorter 就想减
    static func bigTrap(_ c: StoryCtx) -> StoryProblem { bigRelation(c, [Relation.bFewer, .bMore].pick()) }

    static func bigRelation(_ c: StoryCtx, _ r: Relation) -> StoryProblem {
        let (a, b) = pair()
        let aBigger = r == .aMore || r == .bFewer
        // 差别太大（"10 个，比它多 89 个"）不像真的：差最多 40
        var y = 0, d = 99
        while d > 40 {
            if aBigger { (y, d) = addends(c) } else { (y, d) = minuend(c) }
        }
        let av = aBigger ? y + d : y - d
        let kind = bigKind()
        var t = bigThings.pick()
        var names = ("{a}", "{b}")
        var words = ("more", "fewer")
        let lines: [String], answer: String
        var generic: String? = nil
        // 提示里的说法
        let bigger: String, smaller: String, readMore: String, readFewer: String, start: String, apart: String
        switch kind {
        case .things, .distance:
            let rel: String
            switch r {
            case .aMore:  rel = "{a} has \(d) more \(t.many) than {b}."
            case .aFewer: rel = "{a} has \(d) fewer \(t.many) than {b}."
            case .bFewer: rel = "{b} has \(d) fewer \(t.many) than {a}."
            case .bMore:  rel = "{b} has \(d) more \(t.many) than {a}."
            }
            lines = ["{b} has \(t.n(y)).", rel, "How many \(t.many) does {a} have?"]
            answer = "{a} has □ \(t.many)."
            bigger = "{a} has MORE than {b}, so {a}'s number is bigger. Don't take away!"
            smaller = "{a} has FEWER than {b}, so {a}'s number is smaller."
            readMore = "Read it again: {b} has fewer than {a}. So {a} has MORE. Add!"
            readFewer = "Read it again: {b} has more than {a}. So {a} has FEWER. Take away!"
            start = "\(d) is only the difference. Start from {b}'s \(y)."
            apart = "{a} and {b} don't have the same number. They are \(d) apart."
        case .money:
            t = dollars
            let two = Array(shopItems.mixed().prefix(2))
            let (ia, ib) = (two[0], two[1])
            names = (capitalized(ia), capitalized(ib))
            words = ("more", "less")
            let rel: String
            switch r {
            case .aMore:  rel = "A \(ia) costs \(d) dollars more than the \(ib)."
            case .aFewer: rel = "A \(ia) costs \(d) dollars less than the \(ib)."
            case .bFewer: rel = "The \(ib) costs \(d) dollars less than a \(ia)."
            case .bMore:  rel = "The \(ib) costs \(d) dollars more than a \(ia)."
            }
            lines = ["A \(ib) costs \(y) dollars.", rel, "How much does the \(ia) cost?"]
            answer = "The \(ia) costs □ dollars."
            bigger = "The \(ia) costs MORE than the \(ib), so its price is bigger. Don't take away!"
            smaller = "The \(ia) costs LESS than the \(ib), so its price is smaller."
            readMore = "Read it again: the \(ib) costs less than the \(ia). So the \(ia) costs MORE. Add!"
            readFewer = "Read it again: the \(ib) costs more than the \(ia). So the \(ia) costs LESS. Take away!"
            start = "\(d) dollars is only the difference. Start from the \(ib)'s \(y) dollars."
            apart = "The two prices are not the same. They are \(d) dollars apart."
            generic = "Start from the price we know. Is the other price more or less?"
        case .length:
            t = cm
            words = ("longer", "shorter")
            let rel: String
            switch r {
            case .aMore:  rel = "{a}'s ribbon is \(d) cm longer than {b}'s."
            case .aFewer: rel = "{a}'s ribbon is \(d) cm shorter than {b}'s."
            case .bFewer: rel = "{b}'s ribbon is \(d) cm shorter than {a}'s."
            case .bMore:  rel = "{b}'s ribbon is \(d) cm longer than {a}'s."
            }
            lines = ["{b}'s ribbon is \(y) cm long.", rel, "How long is {a}'s ribbon?"]
            answer = "{a}'s ribbon is □ cm long."
            bigger = "{a}'s ribbon is LONGER, so its length is bigger. Don't take away!"
            smaller = "{a}'s ribbon is SHORTER, so its length is smaller."
            readMore = "Read it again: {b}'s ribbon is shorter than {a}'s. So {a}'s ribbon is LONGER. Add!"
            readFewer = "Read it again: {b}'s ribbon is longer than {a}'s. So {a}'s ribbon is SHORTER. Take away!"
            start = "\(d) cm is only the difference. Start from {b}'s \(y) cm."
            apart = "The two ribbons are not the same length. They are \(d) cm apart."
            generic = "Start from the length we know. Is the other ribbon longer or shorter?"
        }
        let barB = M.Bar(name: names.1, tint: .b, segs: [s(y)])
        let aBar1 = aBigger
            ? M.Bar(name: names.0, tint: .a, segs: [s(y, ""), s(d, cap: words.0, .solid, .extra)])
            : M.Bar(name: names.0, tint: .a, segs: [s(av, ""), s(d, cap: words.1, .gap)])
        var aBar2 = aBar1
        if !aBigger { aBar2.segs[0].label = "?" }
        let braces2: [M.Brace] = aBigger ? [.init(bar: 1, from: 0, to: 1, label: "?")] : []
        var p = make(.inverse, a: a, b: b, thing: t, [
            .init(text: lines[0], actions: [.appear(.b, y)]),
            .init(text: lines[1], actions: [.build(.a, av)]),
            .init(text: lines[2]),
        ], ask: .count(.a), answer: answer,
           explain: aBigger ? "\(y) + \(d) = \(av)" : "\(y) − \(d) = \(av)",
           models: [M(bars: [barB]), M(bars: [barB, aBar1]), M(bars: [barB, aBar2], braces: braces2)],
           actable: false) { h in
            switch r {
            case .aMore:  h.add(y - d, bigger)
            case .bFewer: h.add(y - d, readMore)
            case .aFewer: h.add(y + d, smaller)
            case .bMore:  h.add(y + d, readFewer)
            }
            h.add(d, start)
            h.add(y, apart)
            carryHints(&h, y, aBigger ? "+" : "−", d)
        }
        p.generic = generic
        return p
    }
}
