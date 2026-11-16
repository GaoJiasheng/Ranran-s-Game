import SwiftUI

// 「小伙伴的故事」：用演一演、比一比来读懂应用题。
//
// 一道题由几句话组成，每句话可以带"动作"（谁有几个、谁给了谁几个……）。
// 场景里的物品就是按这些动作摆出来的，所以孩子能亲手把故事演一遍，再回答问题。

/// 故事里的人物。`me` 就是玩家自己（用她起的名字）。猫头鹰是老师，不进故事。
enum StoryCast: String, Codable, CaseIterable, Hashable {
    case me, bunny, panda, dragon

    func name(_ player: String) -> String {
        switch self {
        case .me:     player
        case .bunny:  "小兔"
        case .panda:  "熊猫"
        case .dragon: "龙宝宝"
        }
    }

    var image: String { self == .me ? "avatar_ranran" : "avatar_\(rawValue)" }

    var emoji: String {
        switch self {
        case .me:     "👧"
        case .bunny:  "🐰"
        case .panda:  "🐼"
        case .dragon: "🐲"
        }
    }

    var tint: Color {
        switch self {
        case .me:     Palette.coral
        case .bunny:  Palette.blush
        case .panda:  Palette.sage
        case .dragon: Palette.lilac
        }
    }

    /// 名字用的深一点的颜色，放在文字里看得清
    var ink: Color {
        switch self {
        case .me:     Color(hex: 0xD2604F)
        case .bunny:  Color(hex: 0xC9727B)
        case .panda:  Color(hex: 0x4E8A5C)
        case .dragon: Color(hex: 0x7D68B8)
        }
    }
}

enum StoryItem: String, Codable, CaseIterable, Hashable {
    case apple, strawberry, carrot, candy

    var name: String {
        switch self {
        case .apple:      "苹果"
        case .strawberry: "草莓"
        case .carrot:     "胡萝卜"
        case .candy:      "糖果"
        }
    }

    /// 量词
    var measure: String {
        switch self {
        case .apple:      "个"
        case .strawberry: "颗"
        case .carrot:     "根"
        case .candy:      "颗"
        }
    }

    var image: String { "item_\(rawValue)" }

    var emoji: String {
        switch self {
        case .apple:      "🍎"
        case .strawberry: "🍓"
        case .carrot:     "🥕"
        case .candy:      "🍬"
        }
    }
}

/// 物品可以在的地方：两位小伙伴，"吃掉的"盘子，篮子（从外面拿来的）。
enum Spot: String, Codable, Hashable {
    case a, b, away, supply
}

enum StoryAction: Codable, Hashable {
    /// 一开始谁有几个（自动摆出来）
    case appear(Spot, Int)
    /// 从一处拿几个到另一处（孩子来演）
    case move(Spot, Spot, Int)
    /// 从篮子里给某人摆出目标个数（目标就是要求的答案，所以要孩子自己说"摆好了"）
    case build(Spot, Int)
    /// 从一人给另一人，直到一样多
    case balance(Spot, Spot)

    var needsChild: Bool {
        if case .appear = self { return false }
        return true
    }
}

struct StorySentence: Codable, Hashable {
    /// 文本里 {a} {b} 是人名，{i} 是物品，{m} 是量词
    var text: String
    var actions: [StoryAction] = []
}

/// 问题问的是什么
enum StoryAsk: Codable, Hashable {
    case total
    case count(Spot)
    /// 前者比后者多几个
    case more(Spot, Spot)
    /// 前者比后者少几个
    case less(Spot, Spot)
    /// 给了几个才一样多
    case moved
}

/// 题型。错题本按题型统计，方便家长看出孩子哪一类不熟。
enum StorySchema: String, Codable, CaseIterable, Hashable {
    case combine, change, compare, transfer, inverse, equalize, twoStep

    var title: String {
        switch self {
        case .combine:  "合起来"
        case .change:   "变一变"
        case .compare:  "比多少"
        case .transfer: "给来给去"
        case .inverse:  "反过来想"
        case .equalize: "变成一样多"
        case .twoStep:  "两步题"
        }
    }

    var tint: Color {
        switch self {
        case .combine, .change: Palette.sky
        case .compare:          Palette.honey
        case .transfer:         Palette.coral
        case .inverse:          Palette.lilac
        case .equalize:         Palette.blush
        case .twoStep:          Palette.sage
        }
    }
}

struct StoryProblem: Codable, Hashable, Identifiable {
    var id = UUID()
    var schema: StorySchema
    var a: StoryCast
    var b: StoryCast?
    var item: StoryItem
    /// 最后一句是问题
    var sentences: [StorySentence]
    var ask: StoryAsk
    /// 答案句，"□" 是要填的空
    var answerTemplate: String
    var answer: Int
    /// 常见的错误答案 → 针对这种想法的解释
    var hints: [Int: String]
    /// 揭晓答案时的算式和解释
    var explain: String
    var awayLabel: String = "吃掉的"
    var supplyLabel: String = "妈妈的篮子"

    /// 场景里要用到的地方
    var lanes: [Spot] { b == nil ? [.a] : [.a, .b] }

    var sides: [Spot] {
        var s: [Spot] = []
        let all = sentences.flatMap(\.actions)
        if all.contains(where: { if case let .move(_, to, _) = $0 { return to == .away }; return false }) { s.append(.away) }
        if all.contains(where: {
            switch $0 {
            case let .move(from, _, _): from == .supply
            case .build: true
            default: false
            }
        }) { s.append(.supply) }
        return s
    }

    /// 一开始没告诉我们有几个的人（反过来想的题）
    var unknown: Spot? {
        for act in sentences.flatMap(\.actions) { if case let .build(s, _) = act { return s } }
        return nil
    }

    /// 故事过程中每一排最多有几个，用来决定物品画多大
    var capacity: Int {
        var c: [Spot: Int] = [:]
        var top = 0
        for act in sentences.flatMap(\.actions) {
            Self.apply(act, to: &c)
            top = max(top, c[.a, default: 0], c[.b, default: 0])
        }
        return top
    }

    static func apply(_ act: StoryAction, to c: inout [Spot: Int], moved: inout Int) {
        switch act {
        case let .appear(s, n): c[s, default: 0] += n
        case let .move(f, t, n):
            if f != .supply { c[f, default: 0] -= n }
            c[t, default: 0] += n
        case let .build(s, n): c[s] = n
        case let .balance(f, t):
            let d = (c[f, default: 0] - c[t, default: 0]) / 2
            c[f, default: 0] -= d
            c[t, default: 0] += d
            moved = d
        }
    }

    static func apply(_ act: StoryAction, to c: inout [Spot: Int]) {
        var m = 0
        apply(act, to: &c, moved: &m)
    }

    /// 按故事演完后的答案
    static func solve(_ sentences: [StorySentence], _ ask: StoryAsk) -> Int {
        var c: [Spot: Int] = [:]
        var moved = 0
        for act in sentences.flatMap(\.actions) { apply(act, to: &c, moved: &moved) }
        switch ask {
        case .total:            return c[.a, default: 0] + c[.b, default: 0]
        case let .count(s):     return c[s, default: 0]
        case let .more(x, y):   return c[x, default: 0] - c[y, default: 0]
        case let .less(x, y):   return c[y, default: 0] - c[x, default: 0]
        case .moved:            return moved
        }
    }

    /// 答错了但没有对应的解释时，用这句
    var genericHint: String {
        switch ask {
        case .total:          "「一共」要把两边的都数进去哦。"
        case let .count(s):   "跟着故事一步一步想，\(s == .a ? "{a}" : "{b}")最后有几{m}？"
        case .more, .less:    "把两排一个对一个排好，数数多出来的是几{m}。"
        case .moved:          "数一数给出去的那几{m}。"
        }
    }
}

// MARK: - 文字

/// 把模板变成能显示、能朗读的文字。
enum StoryText {
    enum Segment {
        case plain(String)
        case name(StoryCast)
        case number(String)
        case blank
    }

    static func segments(_ template: String, _ p: StoryProblem) -> [Segment] {
        var out: [Segment] = []
        var plain = ""
        var digits = ""
        func flushPlain() { if !plain.isEmpty { out.append(.plain(plain)); plain = "" } }
        func flushDigits() { if !digits.isEmpty { out.append(.number(digits)); digits = "" } }

        var chars = Array(template)[...]
        while let c = chars.first {
            if c.isASCII, c.isNumber {
                flushPlain()
                digits.append(c)
                chars = chars.dropFirst()
                continue
            }
            flushDigits()
            if c == "{", chars.count >= 3, chars[chars.startIndex + 2] == "}" {
                let key = chars[chars.startIndex + 1]
                chars = chars.dropFirst(3)
                switch key {
                case "a": flushPlain(); out.append(.name(p.a))
                case "b": flushPlain(); out.append(.name(p.b ?? p.a))
                case "i": plain += p.item.name
                case "m": plain += p.item.measure
                default: break
                }
                continue
            }
            if c == "□" {
                flushPlain()
                out.append(.blank)
            } else {
                plain.append(c)
            }
            chars = chars.dropFirst()
        }
        flushPlain()
        flushDigits()
        return out
    }

    static func plain(_ template: String, _ p: StoryProblem, player: String, blank: String = "几") -> String {
        segments(template, p).map { seg in
            switch seg {
            case let .plain(s):  s
            case let .name(c):   c.name(player)
            case let .number(n): n
            case .blank:         blank
            }
        }.joined()
    }

    /// 带颜色的文字：人名用人物的颜色，数字加粗变色
    static func styled(_ template: String, _ p: StoryProblem, player: String,
                       numberColor: Color = Palette.coral, filled: String? = nil) -> Text {
        segments(template, p).reduce(Text("")) { text, seg in
            switch seg {
            case let .plain(s):
                return text + Text(s)
            case let .name(c):
                return text + Text(c.name(player)).foregroundColor(c.ink).fontWeight(.heavy)
            case let .number(n):
                return text + Text(n).foregroundColor(numberColor).fontWeight(.black)
            case .blank:
                return text + Text(filled ?? "？").foregroundColor(Palette.honey).fontWeight(.black)
            }
        }
    }

    /// 给朗读用：数字换成中文（"2 个"读成"两个"），符号读出来
    static func spoken(_ s: String) -> String {
        var out = ""
        var digits = ""
        let measures: Set<Character> = ["个", "颗", "根"]
        var chars = Array(s)
        chars.append(" ")
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c.isASCII, c.isNumber { digits.append(c); i += 1; continue }
            if !digits.isEmpty {
                let n = Int(digits) ?? 0
                var j = i
                while j < chars.count, chars[j] == " " { j += 1 }
                let beforeMeasure = j < chars.count && measures.contains(chars[j])
                out += (n == 2 && beforeMeasure) ? "两" : chinese(n)
                digits = ""
            }
            switch c {
            case "+": out += "加"
            case "−", "-": out += "减"
            case "=": out += "等于"
            case "□": out += "几"
            case " ": break
            default: out.append(c)
            }
            i += 1
        }
        return out
    }

    static func chinese(_ n: Int) -> String {
        let d = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
        guard n >= 0, n < 100 else { return "\(n)" }
        if n < 10 { return d[n] }
        let tens = n / 10, ones = n % 10
        return (tens == 1 ? "" : d[tens]) + "十" + (ones == 0 ? "" : d[ones])
    }
}

// MARK: - 出题

/// 按题型随机出题。cap 是每一排最多的个数（10 或 20）。
enum StoryFactory {
    typealias Make = (Int) -> StoryProblem

    private static func pair() -> (StoryCast, StoryCast) {
        let two = StoryCast.allCases.shuffled()
        return (two[0], two[1])
    }

    private static func ph(_ s: Spot) -> String { s == .a ? "{a}" : "{b}" }

    private struct Hints {
        let answer: Int
        var map: [Int: String] = [:]
        mutating func add(_ k: Int, _ msg: String) {
            guard k >= 0, k != answer, map[k] == nil else { return }
            map[k] = msg
        }
    }

    private static func make(_ schema: StorySchema, a: StoryCast, b: StoryCast?, item: StoryItem,
                             _ sentences: [StorySentence], ask: StoryAsk, answer template: String,
                             explain: String, away: String = "吃掉的", supply: String = "妈妈的篮子",
                             hints: (inout Hints) -> Void) -> StoryProblem {
        let answer = StoryProblem.solve(sentences, ask)
        var h = Hints(answer: answer)
        hints(&h)
        return StoryProblem(schema: schema, a: a, b: b, item: item, sentences: sentences, ask: ask,
                            answerTemplate: template, answer: answer, hints: h.map, explain: explain,
                            awayLabel: away, supplyLabel: supply)
    }

    // MARK: 合起来

    static func combine(_ cap: Int) -> StoryProblem {
        let (a, b) = pair()
        let total = Int.random(in: 4...cap)
        let x = Int.random(in: 1...(total - 1)), y = total - x
        return make(.combine, a: a, b: b, item: .allCases.randomElement()!, [
            .init(text: "{a}有 \(x) {m}{i}。", actions: [.appear(.a, x)]),
            .init(text: "{b}有 \(y) {m}{i}。", actions: [.appear(.b, y)]),
            .init(text: "{a}和{b}一共有几{m}{i}？"),
        ], ask: .total, answer: "{a}和{b}一共有 □ {m}{i}",
           explain: "把两边合起来：\(x) + \(y) = \(total)") { h in
            h.add(abs(x - y), "这是两个人差几{m}。「一共」要把两边合起来数哦。")
            h.add(x, "\(x) {m}只是{a}的，「一共」要把{b}的也算上。")
            h.add(y, "\(y) {m}只是{b}的，「一共」要把{a}的也算上。")
        }
    }

    // MARK: 变一变

    static func changeLose(_ cap: Int) -> StoryProblem {
        let a = StoryCast.allCases.randomElement()!
        let item = StoryItem.allCases.randomElement()!
        let n = Int.random(in: 4...cap)
        let k = Int.random(in: 1...min(n - 1, max(3, cap / 2)))
        let verbs: [(String, String)] = item == .carrot
            ? [("喂给小马", "喂掉的"), ("送给邻居", "送出去的")]
            : [("吃掉了", "吃掉的"), ("送给邻居", "送出去的"), ("不小心弄丢了", "弄丢的")]
        let (verb, away) = verbs.randomElement()!
        return make(.change, a: a, b: nil, item: item, [
            .init(text: "{a}有 \(n) {m}{i}。", actions: [.appear(.a, n)]),
            .init(text: "{a}\(verb) \(k) {m}。", actions: [.move(.a, .away, k)]),
            .init(text: "{a}还剩几{m}{i}？"),
        ], ask: .count(.a), answer: "{a}还剩 □ {m}{i}",
           explain: "原来 \(n) {m}，拿走 \(k) {m}：\(n) − \(k) = \(n - k)", away: away) { h in
            h.add(n + k, "{i}是变少了，不是变多了。要从 \(n) {m}里拿走 \(k) {m}。")
            h.add(k, "\(k) {m}是拿走的，题目问的是还剩下的。")
            h.add(n, "别忘了拿走了 \(k) {m}哦。")
        }
    }

    static func changeGain(_ cap: Int) -> StoryProblem {
        let a = StoryCast.allCases.randomElement()!
        let total = Int.random(in: 4...cap)
        let k = Int.random(in: 1...min(total - 1, max(3, cap / 2)))
        let n = total - k
        return make(.change, a: a, b: nil, item: .allCases.randomElement()!, [
            .init(text: "{a}有 \(n) {m}{i}。", actions: [.appear(.a, n)]),
            .init(text: "妈妈又给了{a} \(k) {m}。", actions: [.move(.supply, .a, k)]),
            .init(text: "{a}现在有几{m}{i}？"),
        ], ask: .count(.a), answer: "{a}现在有 □ {m}{i}",
           explain: "原来 \(n) {m}，又来了 \(k) {m}：\(n) + \(k) = \(total)") { h in
            h.add(n - k, "妈妈给了{a}，{i}是变多了，要用加法。")
            h.add(k, "\(k) {m}是妈妈给的，还要加上{a}原来的 \(n) {m}。")
            h.add(n, "别忘了妈妈又给了 \(k) {m}。")
        }
    }

    // MARK: 比多少

    static func compare(_ cap: Int) -> StoryProblem {
        let (a, b) = pair()
        let big = Int.random(in: 3...cap), small = Int.random(in: 1...(big - 1))
        let aBig = Bool.random()
        let (x, y) = aBig ? (big, small) : (small, big)
        let (bs, ss): (Spot, Spot) = aBig ? (.a, .b) : (.b, .a)
        let askLess = Bool.random()
        let question = askLess ? "\(ph(ss))比\(ph(bs))少几{m}{i}？" : "\(ph(bs))比\(ph(ss))多几{m}{i}？"
        let template = askLess ? "\(ph(ss))比\(ph(bs))少 □ {m}" : "\(ph(bs))比\(ph(ss))多 □ {m}"
        return make(.compare, a: a, b: b, item: .allCases.randomElement()!, [
            .init(text: "{a}有 \(x) {m}{i}，{b}有 \(y) {m}{i}。", actions: [.appear(.a, x), .appear(.b, y)]),
            .init(text: question),
        ], ask: askLess ? .less(ss, bs) : .more(bs, ss), answer: template,
           explain: "一个对一个比，多出来的就是差：\(big) − \(small) = \(big - small)") { h in
            h.add(x + y, "比多少不是合起来。把两排一个对一个排好，看多出来几{m}。")
            h.add(big, "\(big) 是\(ph(bs))有的个数，题目问的是差几{m}。")
            h.add(small, "\(small) 是\(ph(ss))有的个数，题目问的是差几{m}。")
        }
    }

    // MARK: 给来给去

    /// 一样多，一个给另一个几个，问差几个 —— 这是最容易错的一类
    static func transferEqual(_ cap: Int) -> StoryProblem {
        let (a, b) = pair()
        let n = Int.random(in: 3...min(cap, 10))
        let k = Int.random(in: 1...min(n - 1, 4))
        let askLess = Int.random(in: 0..<3) == 0
        return make(.transfer, a: a, b: b, item: .allCases.randomElement()!, [
            .init(text: "{a}和{b}各有 \(n) {m}{i}。", actions: [.appear(.a, n), .appear(.b, n)]),
            .init(text: "{a}给了{b} \(k) {m}。", actions: [.move(.a, .b, k)]),
            .init(text: askLess ? "现在{a}比{b}少几{m}？" : "现在{b}比{a}多几{m}？"),
        ], ask: askLess ? .less(.a, .b) : .more(.b, .a),
           answer: askLess ? "{a}比{b}少 □ {m}" : "{b}比{a}多 □ {m}",
           explain: "{a}剩 \(n) − \(k) = \(n - k) {m}，{b}有 \(n) + \(k) = \(n + k) {m}，差 \(n + k) − \(n - k) = \(2 * k) {m}") { h in
            h.add(k, "{a}给出去 \(k) {m}，自己少了 \(k) {m}；{b}拿到 \(k) {m}，又多了 \(k) {m}。一边少、一边多，一共差了 \(k) + \(k) = \(2 * k) {m}。")
            h.add(n + k, "\(n + k) 是{b}现在有的个数，题目问的是差几{m}。")
            h.add(n - k, "\(n - k) 是{a}现在有的个数，题目问的是差几{m}。")
            h.add(0, "给了以后，两个人就不一样多啦。")
        }
    }

    /// 本来就不一样多，再给来给去
    static func transferUnequal(_ cap: Int) -> StoryProblem {
        let (a, b) = pair()
        let top = min(cap, 12)
        var x = 0, y = 0, k = 0
        repeat {
            x = Int.random(in: 4...top)
            y = Int.random(in: 1...top)
            k = Int.random(in: 1...min(x - 1, 4))
        } while x - k == y + k || x == y
        let fa = x - k, fb = y + k
        let (bs, ss): (Spot, Spot) = fa > fb ? (.a, .b) : (.b, .a)
        return make(.transfer, a: a, b: b, item: .allCases.randomElement()!, [
            .init(text: "{a}有 \(x) {m}{i}，{b}有 \(y) {m}{i}。", actions: [.appear(.a, x), .appear(.b, y)]),
            .init(text: "{a}给了{b} \(k) {m}。", actions: [.move(.a, .b, k)]),
            .init(text: "现在\(ph(bs))比\(ph(ss))多几{m}？"),
        ], ask: .more(bs, ss), answer: "\(ph(bs))比\(ph(ss))多 □ {m}",
           explain: "{a}剩 \(x) − \(k) = \(fa) {m}，{b}有 \(y) + \(k) = \(fb) {m}，差 \(max(fa, fb)) − \(min(fa, fb)) = \(abs(fa - fb)) {m}") { h in
            h.add(abs(x - y), "\(abs(x - y)) 是给之前差的。给了以后两边都变了，要重新比一比。")
            h.add(k, "\(k) {m}是给出去的，要看给完以后两边差多少。")
            h.add(fa + fb, "比多少不是合起来哦。")
        }
    }

    /// 给来给去以后，问某个人有几个
    static func transferCount(_ cap: Int) -> StoryProblem {
        let (a, b) = pair()
        let n = Int.random(in: 3...min(cap, 10))
        let k = Int.random(in: 1...min(n - 1, 4))
        let askB = Bool.random()
        return make(.transfer, a: a, b: b, item: .allCases.randomElement()!, [
            .init(text: "{a}和{b}各有 \(n) {m}{i}。", actions: [.appear(.a, n), .appear(.b, n)]),
            .init(text: "{a}给了{b} \(k) {m}。", actions: [.move(.a, .b, k)]),
            .init(text: askB ? "现在{b}有几{m}{i}？" : "现在{a}还剩几{m}{i}？"),
        ], ask: .count(askB ? .b : .a), answer: askB ? "{b}现在有 □ {m}{i}" : "{a}还剩 □ {m}{i}",
           explain: askB ? "{b}拿到了 \(k) {m}，变多了：\(n) + \(k) = \(n + k)"
                         : "{a}给出去 \(k) {m}，变少了：\(n) − \(k) = \(n - k)") { h in
            if askB {
                h.add(n - k, "{b}是拿到{i}的那个，会变多哦。")
            } else {
                h.add(n + k, "{a}是把{i}给出去的那个，会变少哦。")
            }
            h.add(k, "\(k) {m}是给的个数，还要算上原来的 \(n) {m}。")
            h.add(n, "给来给去以后就变了，不是原来的 \(n) {m}了。")
        }
    }

    // MARK: 变成一样多

    static func equalize(_ cap: Int) -> StoryProblem {
        let (a, b) = pair()
        let half = Int.random(in: 1...max(1, min(4, cap / 4)))
        let d = 2 * half
        let y = Int.random(in: 1...(cap - d)), x = y + d
        return make(.equalize, a: a, b: b, item: .allCases.randomElement()!, [
            .init(text: "{a}有 \(x) {m}{i}，{b}有 \(y) {m}{i}。", actions: [.appear(.a, x), .appear(.b, y)]),
            .init(text: "{a}要给{b}几{m}，两个人就一样多了？", actions: [.balance(.a, .b)]),
        ], ask: .moved, answer: "{a}要给{b} □ {m}",
           explain: "{a}比{b}多 \(d) {m}，多出来的要分成两半，给出去一半：\(d) 的一半是 \(half)") { h in
            h.add(d, "给 \(d) {m}的话，{b}就变成 \(x) {m}，{a}只剩 \(y) {m}，反过来了！给出去的时候，自己也会变少哦。")
        }
    }

    // MARK: 反过来想

    static func inverseMore(_ cap: Int) -> StoryProblem { inverse(cap, aSays: true) }
    static func inverseLess(_ cap: Int) -> StoryProblem { inverse(cap, aSays: false) }

    /// aSays: true 是"{a}比{b}多"，false 是"{b}比{a}少"（看到"少"就想用减法，是常见的坑）
    private static func inverse(_ cap: Int, aSays: Bool) -> StoryProblem {
        let (a, b) = pair()
        let y = Int.random(in: 2...(cap - 2))
        let d = Int.random(in: 1...min(5, cap - y))
        let relation = aSays ? "{a}比{b}多 \(d) {m}。" : "{b}比{a}少 \(d) {m}。"
        return make(.inverse, a: a, b: b, item: .allCases.randomElement()!, [
            .init(text: "{b}有 \(y) {m}{i}。", actions: [.appear(.b, y)]),
            .init(text: relation, actions: [.build(.a, y + d)]),
            .init(text: "{a}有几{m}{i}？"),
        ], ask: .count(.a), answer: "{a}有 □ {m}{i}",
           explain: "{a}的 = 和{b}一样多的 \(y) {m} + 多出来的 \(d) {m}：\(y) + \(d) = \(y + d)",
           supply: "篮子") { h in
            if aSays {
                h.add(y - d, "「{a}比{b}多」，说明{a}的更多，不能用减法哦。")
            } else {
                h.add(y - d, "看清楚：是{b}比{a}少，那{a}就比{b}多，要用加法！")
            }
            h.add(d, "\(d) {m}只是多出来的那部分，还要加上和{b}一样多的 \(y) {m}。")
            h.add(y, "{a}和{b}不是一样多哦，差了 \(d) {m}。")
        }
    }

    // MARK: 两步题

    static func twoStepLoseGain(_ cap: Int) -> StoryProblem {
        let a = StoryCast.allCases.randomElement()!
        let n = Int.random(in: 4...(cap - 3))
        let k1 = Int.random(in: 1...min(n - 1, 5))
        let k2 = Int.random(in: 1...min(cap - (n - k1), 5))
        let end = n - k1 + k2
        return make(.twoStep, a: a, b: nil, item: [.apple, .strawberry, .candy].randomElement()!, [
            .init(text: "{a}有 \(n) {m}{i}。", actions: [.appear(.a, n)]),
            .init(text: "{a}吃掉了 \(k1) {m}。", actions: [.move(.a, .away, k1)]),
            .init(text: "妈妈又给了{a} \(k2) {m}。", actions: [.move(.supply, .a, k2)]),
            .init(text: "{a}现在有几{m}{i}？"),
        ], ask: .count(.a), answer: "{a}现在有 □ {m}{i}",
           explain: "先吃掉 \(k1) {m}：\(n) − \(k1) = \(n - k1)，妈妈又给 \(k2) {m}：\(n - k1) + \(k2) = \(end)") { h in
            h.add(n - k1, "后来妈妈又给了 \(k2) {m}，别忘了加上。")
            h.add(n + k2, "别忘了{a}先吃掉了 \(k1) {m}。")
            h.add(n + k1 + k2, "吃掉是变少，妈妈给是变多。")
            h.add(n - k1 - k2, "吃掉是变少，妈妈给是变多。")
        }
    }

    static func twoStepTransferEat(_ cap: Int) -> StoryProblem {
        let (a, b) = pair()
        let n = Int.random(in: 4...min(cap, 10))
        let k = Int.random(in: 1...min(n - 1, 4))
        let j = Int.random(in: 1...(2 * k - 1))
        return make(.twoStep, a: a, b: b, item: [.apple, .strawberry, .candy].randomElement()!, [
            .init(text: "{a}和{b}各有 \(n) {m}{i}。", actions: [.appear(.a, n), .appear(.b, n)]),
            .init(text: "{a}给了{b} \(k) {m}。", actions: [.move(.a, .b, k)]),
            .init(text: "{b}吃掉了 \(j) {m}。", actions: [.move(.b, .away, j)]),
            .init(text: "现在{b}比{a}多几{m}？"),
        ], ask: .more(.b, .a), answer: "{b}比{a}多 □ {m}",
           explain: "{a}剩 \(n - k) {m}，{b}有 \(n) + \(k) − \(j) = \(n + k - j) {m}，差 \(n + k - j) − \(n - k) = \(2 * k - j)") { h in
            h.add(2 * k, "别忘了{b}后来吃掉了 \(j) {m}。")
            h.add(k - j, "{a}给出去的时候，自己也少了 \(k) {m}哦。")
            h.add(k, "一边少、一边多，差的不只是给出去的 \(k) {m}。")
        }
    }
}

// MARK: - 关卡

/// 三种玩法，表示方式一步步"褪"掉：先用手演，再先猜后演，最后只看文字。
enum StoryMode: String, Hashable {
    case act, guess, read

    var title: String {
        switch self {
        case .act:   "演一演"
        case .guess: "先猜再演"
        case .read:  "只看文字"
        }
    }

    var icon: String {
        switch self {
        case .act:   "hand.draw.fill"
        case .guess: "lightbulb.fill"
        case .read:  "text.alignleft"
        }
    }
}

enum StoryChapter: Int, CaseIterable, Identifiable, Hashable {
    case changes = 1, compare, transfer, inverse, challenge

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .changes:   "合起来，变一变"
        case .compare:   "比一比"
        case .transfer:  "给来给去"
        case .inverse:   "反过来想"
        case .challenge: "大挑战"
        }
    }

    var subtitle: String {
        switch self {
        case .changes:   "一共有几个？还剩几个？"
        case .compare:   "谁多？多几个？一个对一个比"
        case .transfer:  "我给你，我就少了，你就多了"
        case .inverse:   "「谁比谁少」，到底谁多？"
        case .challenge: "什么题都有，先想想是哪一种"
        }
    }

    var tint: Color {
        switch self {
        case .changes:   Palette.sky
        case .compare:   Palette.honey
        case .transfer:  Palette.coral
        case .inverse:   Palette.lilac
        case .challenge: Palette.sage
        }
    }

    var icon: String {
        switch self {
        case .changes:   "plus.forwardslash.minus"
        case .compare:   "equal.circle.fill"
        case .transfer:  "arrow.left.arrow.right"
        case .inverse:   "arrow.uturn.backward"
        case .challenge: "flag.checkered"
        }
    }

    var levels: [StoryLevel] { StoryLevel.all.filter { $0.chapter == self } }
}

struct StoryLevel: Hashable, Identifiable {
    static let range = 1...15
    static let all = range.map(StoryLevel.init)
    static let problemsPerLevel = 5

    let number: Int

    init(_ number: Int) {
        self.number = min(max(number, Self.range.lowerBound), Self.range.upperBound)
    }

    var id: Int { number }
    var chapter: StoryChapter { StoryChapter(rawValue: (number - 1) / 3 + 1) ?? .changes }
    var indexInChapter: Int { (number - 1) % 3 }
    var next: StoryLevel? { number < Self.range.upperBound ? StoryLevel(number + 1) : nil }

    var mode: StoryMode {
        if chapter == .challenge { return indexInChapter == 0 ? .guess : .read }
        return [.act, .guess, .read][indexInChapter]
    }

    /// 每一排最多几个
    var cap: Int {
        switch number {
        case 3, 6, 12, 13, 14, 15: 20
        default: 10
        }
    }

    /// 这一关的 5 道题。排在前面的是这一章的主角题型，后面会混进别的题型，逼着先认清是哪种题。
    func makeProblems() -> [StoryProblem] {
        typealias F = StoryFactory
        let plan: [StoryFactory.Make]
        switch number {
        case 1:  plan = [F.combine, F.changeLose, F.changeGain, F.combine, F.changeLose]
        case 2:  plan = [F.changeGain, F.combine, F.changeLose, F.changeGain, F.combine]
        case 3:  plan = [F.combine, F.changeLose, F.changeGain, F.changeLose, F.changeGain].shuffled()
        case 4, 5: plan = Array(repeating: F.compare, count: 5)
        case 6:  plan = [F.compare, F.compare, F.compare, F.combine, F.changeLose].shuffled()
        case 7:  plan = [F.transferEqual, F.transferEqual, F.transferCount, F.transferEqual, F.transferUnequal]
        case 8:  plan = [F.transferEqual, F.transferUnequal, F.transferCount, F.equalize, F.transferEqual]
        case 9:  plan = [F.transferEqual, F.transferUnequal, F.equalize, F.transferCount, F.transferEqual].shuffled()
        case 10: plan = [F.inverseMore, F.inverseLess, F.inverseMore, F.inverseLess, F.inverseLess]
        case 11: plan = [F.inverseLess, F.inverseMore, F.inverseLess, F.inverseMore, F.inverseLess].shuffled()
        case 12: plan = [F.inverseLess, F.inverseMore, F.compare, F.inverseLess, F.compare].shuffled()
        case 13: plan = [F.compare, F.transferEqual, F.inverseLess, F.changeLose, F.equalize].shuffled()
        case 14: plan = [F.transferUnequal, F.inverseMore, F.combine, F.transferEqual, F.inverseLess].shuffled()
        default: plan = [F.twoStepLoseGain, F.transferEqual, F.inverseLess, F.twoStepTransferEat, F.equalize].shuffled()
        }
        var used = Set<String>()
        return plan.map { make in
            // 同一关里别出两道一模一样的题
            for _ in 0..<12 {
                let p = make(cap)
                let key = p.sentences.map(\.text).joined()
                if used.insert(key).inserted { return p }
            }
            return make(cap)
        }
    }
}

// MARK: - 进度和错题

/// 做错过的题，存下来给家长看、给孩子再练。
struct StoryMistake: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date()
    var level: Int
    var problem: StoryProblem
    /// 第一次答的错答案
    var answer: Int
    /// 后来在错题本里重新做对了
    var fixed = false
}

extension PlayerStore {
    func storyBest(_ level: StoryLevel) -> Int { count("story.best.\(level.number)") }

    /// 推荐的关：第一个还没拿到星星的关
    var storyRecommended: StoryLevel {
        StoryLevel.all.first { storyBest($0) == 0 } ?? StoryLevel(StoryLevel.range.upperBound)
    }

    var storyStars: Int { StoryLevel.all.reduce(0) { $0 + storyBest($1) } }

    @discardableResult
    func recordStoryLevel(_ level: StoryLevel, stars: Int) -> Bool {
        let isRecord = stars > storyBest(level)
        if isRecord { setCount("story.best.\(level.number)", stars) }
        return isRecord
    }

    /// 每道题第一次答对还是答错，按题型统计
    func recordStoryAnswer(_ schema: StorySchema, correct: Bool) {
        increment("story.\(correct ? "right" : "wrong").\(schema.rawValue)")
    }

    func storyStats(_ schema: StorySchema) -> (right: Int, wrong: Int) {
        (count("story.right.\(schema.rawValue)"), count("story.wrong.\(schema.rawValue)"))
    }
}
