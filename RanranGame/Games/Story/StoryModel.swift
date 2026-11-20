import SwiftUI

// MARK: - 随机数

/// 出题用的随机数。App 里现场出题时随便播种；题库生成器（tools/storybank）按"关 + 第几套"播种，
/// 这样同一关每次生成都一模一样，可以只补缺的关、不动已经录好音的题。
struct StoryRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    /// SplitMix64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    static var shared = StoryRNG(seed: UInt64.random(in: 0 ... .max))

    static func reseed(_ seed: UInt64) { shared = StoryRNG(seed: seed) }

    /// 用同一串随机数做一个 UUID（题库里的题 id 也要每次一样）
    static func uuid() -> UUID {
        var b = [UInt8](repeating: 0, count: 16)
        for i in 0..<16 { b[i] = UInt8.random(in: 0 ... .max, using: &shared) }
        b[6] = (b[6] & 0x0F) | 0x40
        b[8] = (b[8] & 0x3F) | 0x80
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }
}

extension Int {
    static func r(in range: ClosedRange<Int>) -> Int { random(in: range, using: &StoryRNG.shared) }
}

extension Bool {
    static func r() -> Bool { random(using: &StoryRNG.shared) }
}

extension Array {
    func pick() -> Element { randomElement(using: &StoryRNG.shared)! }
    func mixed() -> [Element] { shuffled(using: &StoryRNG.shared) }
}

// 「加减乘除」里的英文应用题，按新加坡数学的思路出题：
// 先用实物演（Concrete）→ 再画线段图（Pictorial，bar model）→ 最后只看文字（Abstract）。
//
// 一道题由几句话组成，每句话可以带"动作"（谁有几个、谁给了谁几个、每个盘子放几个……）。
// 舞台上的物品按这些动作摆出来，线段图也跟着每一句一步步画出来。

/// 故事里的人物。`me` 就是玩家自己（中文名自动转成拼音，比如 Ranran）。猫头鹰是老师，不进故事。
enum StoryCast: String, Codable, CaseIterable, Hashable {
    case me, bunny, panda, dragon

    func name(_ player: String) -> String {
        switch self {
        case .me:     StoryText.englishName(player)
        case .bunny:  "Bunny"
        case .panda:  "Panda"
        case .dragon: "Dragon"
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

/// 有插画、能在舞台上拖来拖去的物品
enum StoryItem: String, Codable, CaseIterable, Hashable {
    case apple, strawberry, carrot, candy, cookie, balloon, sticker, pencil

    var image: String { "item_\(rawValue)" }

    var emoji: String {
        switch self {
        case .apple:      "🍎"
        case .strawberry: "🍓"
        case .carrot:     "🥕"
        case .candy:      "🍬"
        case .cookie:     "🍪"
        case .balloon:    "🎈"
        case .sticker:    "⭐️"
        case .pencil:     "✏️"
        }
    }

    var thing: StoryThing {
        switch self {
        case .apple:      StoryThing(one: "apple", many: "apples", art: self, food: true)
        case .strawberry: StoryThing(one: "strawberry", many: "strawberries", art: self, food: true)
        case .carrot:     StoryThing(one: "carrot", many: "carrots", art: self, food: true)
        // 新加坡课本里说 sweets
        case .candy:      StoryThing(one: "sweet", many: "sweets", art: self, food: true)
        case .cookie:     StoryThing(one: "cookie", many: "cookies", art: self, food: true)
        case .balloon:    StoryThing(one: "balloon", many: "balloons", art: self)
        case .sticker:    StoryThing(one: "sticker", many: "stickers", art: self)
        case .pencil:     StoryThing(one: "pencil", many: "pencils", art: self)
        }
    }
}

/// 题目里数的东西。有插画的才能上舞台演；没有插画的只在"画线段图 / 只看文字"里出现。
struct StoryThing: Codable, Hashable {
    var one: String
    var many: String
    var art: StoryItem? = nil
    var food = false

    func word(_ k: Int) -> String { k == 1 ? one : many }
    /// "1 apple"、"5 apples"
    func n(_ k: Int) -> String { "\(k) \(word(k))" }

    /// 只出现在文字题里的东西，让题目更多样
    static let extras: [StoryThing] = [
        StoryThing(one: "marble", many: "marbles"),
        StoryThing(one: "storybook", many: "storybooks"),
        StoryThing(one: "stamp", many: "stamps"),
        StoryThing(one: "bead", many: "beads"),
        StoryThing(one: "seashell", many: "seashells"),
        StoryThing(one: "crayon", many: "crayons"),
        StoryThing(one: "egg", many: "eggs"),
        StoryThing(one: "muffin", many: "muffins", food: true),
        StoryThing(one: "orange", many: "oranges", food: true),
    ]
}

/// 物品可以在的地方：两位小伙伴、"用掉的"盘子、篮子，以及分东西用的几个盘子。
enum Spot: String, Codable, Hashable {
    case a, b, away, supply
    case p1, p2, p3, p4, p5, p6

    static let plates: [Spot] = [.p1, .p2, .p3, .p4, .p5, .p6]
    var isPlate: Bool { Spot.plates.contains(self) }
    var plateIndex: Int? { Spot.plates.firstIndex(of: self) }
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
    /// 告诉我们两个人"一共"有几个（舞台上显示一个目标牌子）
    case whole(Int)
    /// 摆出几个空盘子
    case plates(Int)
    /// 从篮子里往每个盘子放几个（乘法）
    case fill(Int)
    /// 把手里的平均分到盘子里（除法：平均分）
    case share
    /// 每个盘子放几个，看能放几盘（除法：包含除）
    case group(Int)
    /// 把所有盘子（袋子）里的都倒回给 {a}（两步题：先算几个几，再添上或拿走）
    case gather

    var needsChild: Bool {
        switch self {
        case .appear, .whole, .plates, .gather: false
        default: true
        }
    }
}

struct StorySentence: Codable, Hashable {
    /// 文本里 {a} {b} 是人名
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
    /// 每个盘子几个
    case perPlate
    /// 几个盘子
    case plates
    /// 盘子里一共几个
    case inPlates
}

/// 题型。错题本按题型统计，方便家长看出孩子哪一类不熟。
enum StorySchema: String, Codable, CaseIterable, Hashable {
    case combine, partWhole, change, compare, inverse, transfer, equalize, multiply, divide, twoStep

    var title: String {
        switch self {
        case .combine:   "Altogether"
        case .partWhole: "Part & Whole"
        case .change:    "Add & Take Away"
        case .compare:   "How Many More"
        case .inverse:   "More / Fewer Than"
        case .transfer:  "Giving"
        case .equalize:  "Make Them Equal"
        case .multiply:  "Equal Groups"
        case .divide:    "Sharing"
        case .twoStep:   "Two Steps"
        }
    }

    /// 给家长看的中文名
    var zh: String {
        switch self {
        case .combine:   "合起来"
        case .partWhole: "求部分"
        case .change:    "添上和拿走"
        case .compare:   "比多少"
        case .inverse:   "多几 / 少几求数"
        case .transfer:  "给来给去"
        case .equalize:  "变成一样多"
        case .multiply:  "乘法：几个几"
        case .divide:    "除法：平均分"
        case .twoStep:   "两步题"
        }
    }

    var tint: Color {
        switch self {
        case .combine, .change: Palette.sky
        case .partWhole:        Palette.sage
        case .compare:          Palette.honey
        case .inverse:          Palette.lilac
        case .transfer:         Palette.coral
        case .equalize:         Palette.blush
        case .multiply:         Palette.sky
        case .divide:           Palette.blush
        case .twoStep:          Palette.sage
        }
    }
}

struct StoryProblem: Codable, Hashable, Identifiable {
    var id = UUID()
    var schema: StorySchema
    var a: StoryCast
    var b: StoryCast?
    var thing: StoryThing
    /// 最后一句是问题
    var sentences: [StorySentence]
    var ask: StoryAsk
    /// 答案句（answer statement），"□" 是要填的空
    var answerTemplate: String
    var answer: Int
    /// 常见的错误答案 → 针对这种想法的解释
    var hints: [Int: String]
    /// 算式（equation），答对或揭晓时显示
    var explain: String
    /// 每一句读完后的线段图，和 sentences 一一对应
    var models: [BarModel]
    /// 能不能在舞台上用实物演（东西有插画、数量摆得下）
    var canAct: Bool
    var awayLabel = "Eaten"
    var supplyLabel = "Basket"
    var plateWord = "plate"
    /// 两步题中间那一问（"Step by step" 关里先问它）；以前的题没有
    var middle: StoryMiddle? = nil
    /// 答错了又没有对应解释时说的话；不给就按问的是什么来说（以前的题都没给）
    var generic: String? = nil

    var item: StoryItem { thing.art ?? .apple }

    /// "plates"、"boxes"
    var plateWords: String { StoryText.plural(plateWord) }

    private var allActions: [StoryAction] { sentences.flatMap(\.actions) }

    var usesPlates: Bool {
        allActions.contains { if case .plates = $0 { return true }; if case .group = $0 { return true }; return false }
    }

    /// 舞台上的人物那一排
    var lanes: [Spot] {
        if usesPlates {
            return allActions.contains { if case .appear(.a, _) = $0 { return true }; return false } ? [.a] : []
        }
        return b == nil ? [.a] : [.a, .b]
    }

    var sides: [Spot] {
        var s: [Spot] = []
        if allActions.contains(where: { if case let .move(_, to, _) = $0 { return to == .away }; return false }) { s.append(.away) }
        if allActions.contains(where: {
            switch $0 {
            case let .move(from, _, _): from == .supply
            case .build, .fill: true
            default: false
            }
        }) { s.append(.supply) }
        return s
    }

    /// 最多会用到几个盘子
    var plateSlots: Int {
        var c: [Spot: Int] = [:]
        for act in allActions { Self.apply(act, to: &c) }
        return Spot.plates.filter { c[$0] != nil }.count
    }

    /// 一开始没告诉我们有几个的人（要从篮子里摆出来的）
    var unknown: Spot? {
        for act in allActions { if case let .build(s, _) = act { return s } }
        return nil
    }

    /// "一共"的目标数
    var whole: Int? {
        for act in allActions { if case let .whole(n) = act { return n } }
        return nil
    }

    /// 故事过程中每一排最多有几个，用来决定物品画多大
    var capacity: Int {
        var c: [Spot: Int] = [:]
        var top = 0
        for act in allActions {
            Self.apply(act, to: &c)
            top = max(top, c[.a, default: 0], c[.b, default: 0])
        }
        return top
    }

    var platePeak: Int {
        var c: [Spot: Int] = [:]
        for act in allActions { Self.apply(act, to: &c) }
        return Spot.plates.map { c[$0, default: 0] }.max() ?? 0
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
        case .whole:
            break
        case let .plates(g):
            for p in Spot.plates.prefix(g) { c[p] = c[p] ?? 0 }
        case let .fill(n):
            for p in Spot.plates where c[p] != nil { c[p] = n }
        case .share:
            let ps = Spot.plates.filter { c[$0] != nil }
            guard !ps.isEmpty else { return }
            let each = c[.a, default: 0] / ps.count
            for p in ps { c[p, default: 0] += each }
            c[.a] = 0
        case let .group(n):
            guard n > 0 else { return }
            let k = c[.a, default: 0] / n
            for p in Spot.plates.prefix(k) { c[p] = n }
            c[.a] = 0
        case .gather:
            for p in Spot.plates where c[p] != nil {
                c[.a, default: 0] += c[p, default: 0]
                c[p] = nil
            }
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
        case .perPlate:         return c[.p1, default: 0]
        case .plates:           return Spot.plates.filter { c[$0, default: 0] > 0 }.count
        case .inPlates:         return Spot.plates.reduce(0) { $0 + c[$1, default: 0] }
        }
    }

    /// 答错了但没有对应的解释时，用这句
    var genericHint: String {
        if let generic { return generic }
        return switch ask {
        case .total:          "Altogether means we count both parts together."
        case .count:          "Follow the story one step at a time. How many are there at the end?"
        case .more, .less:    "Line them up one to one. How many are extra?"
        case .moved:          "Count the ones that were given."
        case .perPlate:
            switch plateWord {
            case "plate":  "Every plate gets the same number. How many on one plate?"
            case "friend": "Every friend gets the same number. How many does one friend get?"
            default:       "Every \(plateWord) gets the same number. How many are in one \(plateWord)?"
            }
        case .plates:         "How many \(plateWords) can we fill?"
        case .inPlates:       "Count all of them, \(plateWord) by \(plateWord)."
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

    static func plural(_ w: String) -> String { w.hasSuffix("x") ? w + "es" : w + "s" }

    /// 中文名转成拼音，英文题里用（"冉冉" → "Ranran"）
    static func englishName(_ s: String) -> String {
        if s.allSatisfy({ $0.isASCII }) { return s }
        guard let latin = s.applyingTransform(.toLatin, reverse: false)?
            .applyingTransform(.stripDiacritics, reverse: false) else { return s }
        let joined = latin.filter { !$0.isWhitespace }
        guard let first = joined.first else { return s }
        return first.uppercased() + joined.dropFirst().lowercased()
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

    static func plain(_ template: String, _ p: StoryProblem, player: String, blank: String = "?") -> String {
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
                return text + Text(filled ?? "?").foregroundColor(Palette.honey).fontWeight(.black)
            }
        }
    }

    /// 给朗读用：把算式里的符号读出来
    static func spoken(_ s: String) -> String {
        var out = s
        for (sym, word) in [("□", " how many "), ("−", " minus "), ("+", " plus "), ("×", " times "),
                            ("÷", " divided by "), ("=", " equals "), ("?", "? ")] {
            out = out.replacingOccurrences(of: sym, with: word)
        }
        return out.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - 出题

/// 出题时的设置：每一排最多几个，要不要能用实物演
struct StoryCtx {
    var cap: Int
    var act: Bool
    /// 100 以内的加减：true = 要进位 / 退位，false = 不进位不退位，nil = 都行
    var regroup: Bool? = nil
}

/// 按题型随机出题。句子和说法参照新加坡小学一、二年级的数学课本。
enum StoryFactory {
    typealias Make = (StoryCtx) -> StoryProblem
    typealias M = BarModel

    static func pair() -> (StoryCast, StoryCast) {
        let two = StoryCast.allCases.mixed()
        return (two[0], two[1])
    }

    static func solo() -> StoryCast { StoryCast.allCases.pick() }

    /// 实物演的题只用有插画的东西；文字题里再加一些别的东西
    static func thing(_ c: StoryCtx, food: Bool = false) -> StoryThing {
        var pool = StoryItem.allCases.map(\.thing)
        if !c.act { pool += StoryThing.extras }
        if food { pool = pool.filter(\.food) }
        return pool.pick()
    }

    static func ph(_ s: Spot) -> String { s == .a ? "{a}" : "{b}" }

    /// 一段线段；label 为 nil 时写上它的数
    static func s(_ v: Int, _ label: String? = nil, cap caption: String = "",
                          _ style: M.Style = .solid, _ tint: M.Tint? = nil) -> M.Seg {
        M.Seg(value: v, label: label ?? "\(v)", caption: caption, style: style, tint: tint)
    }

    struct Hints {
        let answer: Int
        var map: [Int: String] = [:]
        mutating func add(_ k: Int, _ msg: String) {
            guard k >= 0, k != answer, map[k] == nil else { return }
            map[k] = msg
        }
    }

    static func make(_ schema: StorySchema, a: StoryCast, b: StoryCast?, thing: StoryThing,
                             _ sentences: [StorySentence], ask: StoryAsk, answer template: String,
                             explain: String, models: [M], away: String = "Eaten", supply: String = "Basket",
                             plate: String = "plate", actable: Bool = true,
                             hints: (inout Hints) -> Void) -> StoryProblem {
        let answer = StoryProblem.solve(sentences, ask)
        var h = Hints(answer: answer)
        hints(&h)
        var steps = Array(models.prefix(sentences.count))
        while steps.count < sentences.count, let last = steps.last { steps.append(last) }
        var p = StoryProblem(schema: schema, a: a, b: b, thing: thing, sentences: sentences, ask: ask,
                             answerTemplate: template, answer: answer, hints: h.map, explain: explain,
                             models: steps, canAct: false, awayLabel: away, supplyLabel: supply, plateWord: plate)
        p.canAct = actable && thing.art != nil && p.capacity <= 20 && p.platePeak <= 6 && p.plateSlots <= 6
        return p
    }

    // MARK: 部分-整体：合起来

    static func combine(_ c: StoryCtx) -> StoryProblem {
        let (a, b) = pair()
        let t = thing(c)
        let total = Int.r(in: 4...c.cap)
        let x = Int.r(in: 1...(total - 1)), y = total - x
        let m1 = M(bars: [M.Bar(segs: [s(x, cap: "{a}", .solid, .a), s(y, cap: "{b}", .solid, .b)])])
        var m2 = m1
        m2.braces = [.init(bar: 0, from: 0, to: 1, label: "?")]
        return make(.combine, a: a, b: b, thing: t, [
            .init(text: "{a} has \(t.n(x)).", actions: [.appear(.a, x)]),
            .init(text: "{b} has \(t.n(y)).", actions: [.appear(.b, y)]),
            .init(text: "How many \(t.many) do they have altogether?"),
        ], ask: .total, answer: "They have □ \(t.many) altogether.",
           explain: "\(x) + \(y) = \(total)",
           models: [M(bars: [M.Bar(segs: [s(x, cap: "{a}", .solid, .a)])]), m1, m2]) { h in
            h.add(abs(x - y), "That is how many more one of them has. Altogether means we put both parts together.")
            h.add(x, "\(x) is only {a}'s part. Add {b}'s part too.")
            h.add(y, "\(y) is only {b}'s part. Add {a}'s part too.")
        }
    }

    // MARK: 部分-整体：求一部分

    static func partWhole(_ c: StoryCtx) -> StoryProblem {
        if !c.act, Bool.r() { return partWholeRest(c) }
        let (a, b) = pair()
        let t = thing(c)
        let total = Int.r(in: 5...c.cap)
        let x = Int.r(in: 1...(total - 1)), y = total - x
        let whole = M.Brace(bar: 0, from: 0, to: 1, label: "\(total)")
        return make(.partWhole, a: a, b: b, thing: t, [
            .init(text: "{a} and {b} have \(t.n(total)) altogether.", actions: [.whole(total)]),
            .init(text: "{a} has \(t.n(x)).", actions: [.appear(.a, x)]),
            .init(text: "How many \(t.many) does {b} have?", actions: [.build(.b, y)]),
        ], ask: .count(.b), answer: "{b} has □ \(t.many).",
           explain: "\(total) − \(x) = \(y)",
           models: [
            M(bars: [M.Bar(segs: [s(total, "", .solid, .neutral)])], braces: [.init(bar: 0, from: 0, to: 0, label: "\(total)")]),
            M(bars: [M.Bar(segs: [s(x, cap: "{a}", .solid, .a), s(y, "", cap: "{b}", .solid, .b)])], braces: [whole]),
            M(bars: [M.Bar(segs: [s(x, cap: "{a}", .solid, .a), s(y, "?", cap: "{b}", .solid, .b)])], braces: [whole]),
           ], supply: "Basket") { h in
            h.add(total + x, "\(total) is all of them together. {a}'s \(x) are already inside it, so take them away.")
            h.add(total, "\(total) is for both of them. We only want {b}'s part.")
            h.add(x, "\(x) is {a}'s part. How many are left for {b}?")
        }
    }

    /// "There are 15 children. 8 are boys. The rest are girls."
    struct RestContext {
        let whole: String, place: String, one: String, two: String
        /// one / two 是颜色（要说 "yellow flowers"）还是名词（"girls"）
        let adjective: Bool
        func phrase(_ part: String) -> String { adjective ? "\(part) \(whole)" : part }
        /// "the red ones"、"the boys"
        func ones(_ part: String) -> String { adjective ? "\(part) ones" : part }
    }

    static let restContexts: [RestContext] = [
        RestContext(whole: "children", place: "at the playground", one: "boys", two: "girls", adjective: false),
        RestContext(whole: "children", place: "in the class", one: "girls", two: "boys", adjective: false),
        RestContext(whole: "flowers", place: "in a vase", one: "red", two: "yellow", adjective: true),
        RestContext(whole: "marbles", place: "in a bag", one: "blue", two: "green", adjective: true),
        RestContext(whole: "balloons", place: "at the party", one: "pink", two: "white", adjective: true),
        RestContext(whole: "fish", place: "in the pond", one: "orange", two: "black", adjective: true),
    ]

    private static func partWholeRest(_ c: StoryCtx) -> StoryProblem {
        let r = restContexts.pick()
        let total = Int.r(in: 6...max(6, c.cap))
        let x = Int.r(in: 1...(total - 1)), y = total - x
        let whole = M.Brace(bar: 0, from: 0, to: 1, label: "\(total)")
        let t = StoryThing(one: r.whole, many: r.whole)
        return make(.partWhole, a: solo(), b: nil, thing: t, [
            .init(text: "There are \(total) \(r.whole) \(r.place).", actions: [.whole(total)]),
            .init(text: "\(x) of them are \(r.one). The rest are \(r.two).", actions: [.appear(.a, x)]),
            .init(text: "How many \(r.phrase(r.two)) are there?", actions: [.build(.b, y)]),
        ], ask: .count(.b), answer: "There are □ \(r.phrase(r.two)).",
           explain: "\(total) − \(x) = \(y)",
           models: [
            M(bars: [M.Bar(segs: [s(total, "", .solid, .neutral)])], braces: [.init(bar: 0, from: 0, to: 0, label: "\(total)")]),
            M(bars: [M.Bar(segs: [s(x, cap: r.one, .solid, .a), s(y, "", cap: r.two, .solid, .b)])], braces: [whole]),
            M(bars: [M.Bar(segs: [s(x, cap: r.one, .solid, .a), s(y, "?", cap: r.two, .solid, .b)])], braces: [whole]),
           ], actable: false) { h in
            h.add(total + x, "\(total) is all the \(r.whole). The \(r.one) ones are inside it, so take them away.")
            h.add(total, "\(total) is all the \(r.whole). We only want the \(r.two) ones.")
            h.add(x, "\(x) is the \(r.one) ones. How many are the rest?")
        }
    }

    // MARK: 添上和拿走

    static func changeLose(_ c: StoryCtx) -> StoryProblem {
        let a = solo()
        let t = thing(c)
        let n = Int.r(in: 4...c.cap)
        let k = Int.r(in: 1...min(n - 1, max(3, c.cap / 2)))
        var verbs: [(String, String, String)] = [("gave away", "gave away", "Given away"), ("lost", "lost", "Lost")]
        if t.food { verbs += [("ate", "ate", "Eaten"), ("ate", "ate", "Eaten")] }
        let (verb, caption, away) = verbs.pick()
        let whole = M.Brace(bar: 0, from: 0, to: 1, label: "\(n)")
        return make(.change, a: a, b: nil, thing: t, [
            .init(text: "{a} had \(t.n(n)).", actions: [.appear(.a, n)]),
            .init(text: "{a} \(verb) \(k) of them.", actions: [.move(.a, .away, k)]),
            .init(text: "How many \(t.many) did {a} have left?"),
        ], ask: .count(.a), answer: "{a} had □ \(t.many) left.",
           explain: "\(n) − \(k) = \(n - k)",
           models: [
            M(bars: [M.Bar(segs: [s(n, "", .solid, .a)])], braces: [.init(bar: 0, from: 0, to: 0, label: "\(n)")]),
            M(bars: [M.Bar(segs: [s(n - k, "", cap: "left"), s(k, cap: caption, .gone)])], braces: [whole]),
            M(bars: [M.Bar(segs: [s(n - k, "?", cap: "left"), s(k, cap: caption, .gone)])], braces: [whole]),
           ], away: away) { h in
            h.add(n + k, "Some \(t.many) went away, so {a} has fewer now, not more. Take away \(k).")
            h.add(k, "\(k) is how many went away. We want how many are left.")
            h.add(n, "Don't forget: {a} \(verb) \(k) of them.")
        }
    }

    static func changeGain(_ c: StoryCtx) -> StoryProblem {
        let a = solo()
        let t = thing(c)
        let total = Int.r(in: 4...c.cap)
        let k = Int.r(in: 1...min(total - 1, max(3, c.cap / 2)))
        let n = total - k
        let giver = ["Mum", "Dad", "Grandma", "Grandpa"].pick()
        let m1 = M(bars: [M.Bar(segs: [s(n, cap: "at first"), s(k, cap: "more", .solid, .extra)])])
        var m2 = m1
        m2.braces = [.init(bar: 0, from: 0, to: 1, label: "?")]
        return make(.change, a: a, b: nil, thing: t, [
            .init(text: "{a} had \(t.n(n)).", actions: [.appear(.a, n)]),
            .init(text: "\(giver) gave {a} \(k) more.", actions: [.move(.supply, .a, k)]),
            .init(text: "How many \(t.many) does {a} have now?"),
        ], ask: .count(.a), answer: "{a} has □ \(t.many) now.",
           explain: "\(n) + \(k) = \(total)",
           models: [M(bars: [M.Bar(segs: [s(n, cap: "at first")])]), m1, m2],
           supply: "\(giver)'s basket") { h in
            h.add(n - k, "{a} got more, so {a} has more now. Add them together.")
            h.add(k, "\(k) is the new ones. Add the \(n) {a} had at first.")
            h.add(n, "Don't forget the \(k) more from \(giver).")
        }
    }

    // MARK: 比较

    static func compare(_ c: StoryCtx) -> StoryProblem {
        let (a, b) = pair()
        let t = thing(c)
        let big = Int.r(in: 3...c.cap), small = Int.r(in: 1...(big - 1))
        let aBig = Bool.r()
        let (x, y) = aBig ? (big, small) : (small, big)
        let (bs, ss): (Spot, Spot) = aBig ? (.a, .b) : (.b, .a)
        let askFewer = Bool.r()
        let question = askFewer
            ? "How many fewer \(t.many) does \(ph(ss)) have than \(ph(bs))?"
            : "How many more \(t.many) does \(ph(bs)) have than \(ph(ss))?"
        let template = askFewer
            ? "\(ph(ss)) has □ fewer \(t.many) than \(ph(bs))."
            : "\(ph(bs)) has □ more \(t.many) than \(ph(ss))."
        let barA = M.Bar(name: "{a}", tint: .a, segs: [s(x)])
        let barB = M.Bar(name: "{b}", tint: .b, segs: [s(y)])
        var withGap = [barA, barB]
        withGap[aBig ? 1 : 0].segs.append(s(big - small, "?", .gap))
        return make(.compare, a: a, b: b, thing: t, [
            .init(text: "{a} has \(t.n(x)).", actions: [.appear(.a, x)]),
            .init(text: "{b} has \(t.n(y)).", actions: [.appear(.b, y)]),
            .init(text: question),
        ], ask: askFewer ? .less(ss, bs) : .more(bs, ss), answer: template,
           explain: "\(big) − \(small) = \(big - small)",
           models: [M(bars: [barA]), M(bars: [barA, barB]), M(bars: withGap)]) { h in
            h.add(x + y, "We are comparing, not putting together. Line them up and look at the extra ones.")
            h.add(big, "\(big) is how many \(ph(bs)) has. We want the difference.")
            h.add(small, "\(small) is how many \(ph(ss)) has. We want the difference.")
        }
    }

    // MARK: 多几 / 少几，求一个数

    enum Relation { case aMore, aFewer, bFewer, bMore }

    static func moreThan(_ c: StoryCtx) -> StoryProblem { relation(c, .aMore) }
    static func fewerThan(_ c: StoryCtx) -> StoryProblem { relation(c, .aFewer) }
    /// "{b} has 3 fewer than {a}" —— 看到 fewer 就想减，是最常见的坑
    static func trapFewer(_ c: StoryCtx) -> StoryProblem { relation(c, .bFewer) }
    static func trapMore(_ c: StoryCtx) -> StoryProblem { relation(c, .bMore) }

    private static func relation(_ c: StoryCtx, _ r: Relation) -> StoryProblem {
        let (a, b) = pair()
        let t = thing(c)
        let aBigger = r == .aMore || r == .bFewer
        let y: Int, d: Int
        if aBigger {
            y = Int.r(in: 2...(c.cap - 2))
            d = Int.r(in: 1...min(5, c.cap - y))
        } else {
            y = Int.r(in: 4...c.cap)
            d = Int.r(in: 1...min(5, y - 1))
        }
        let av = aBigger ? y + d : y - d
        let text: String
        switch r {
        case .aMore:  text = "{a} has \(d) more \(t.word(d)) than {b}."
        case .aFewer: text = "{a} has \(d) fewer \(t.word(d)) than {b}."
        case .bFewer: text = "{b} has \(d) fewer \(t.word(d)) than {a}."
        case .bMore:  text = "{b} has \(d) more \(t.word(d)) than {a}."
        }
        let barB = M.Bar(name: "{b}", tint: .b, segs: [s(y)])
        let aBar1 = aBigger
            ? M.Bar(name: "{a}", tint: .a, segs: [s(y, ""), s(d, cap: "more", .solid, .extra)])
            : M.Bar(name: "{a}", tint: .a, segs: [s(av, ""), s(d, cap: "fewer", .gap)])
        var aBar2 = aBar1
        if !aBigger { aBar2.segs[0].label = "?" }
        let braces2: [M.Brace] = aBigger ? [.init(bar: 1, from: 0, to: 1, label: "?")] : []
        return make(.inverse, a: a, b: b, thing: t, [
            .init(text: "{b} has \(t.n(y)).", actions: [.appear(.b, y)]),
            .init(text: text, actions: [.build(.a, av)]),
            .init(text: "How many \(t.many) does {a} have?"),
        ], ask: .count(.a), answer: "{a} has □ \(t.many).",
           explain: aBigger ? "\(y) + \(d) = \(av)" : "\(y) − \(d) = \(av)",
           models: [M(bars: [barB]), M(bars: [barB, aBar1]), M(bars: [barB, aBar2], braces: braces2)]) { h in
            switch r {
            case .aMore:  h.add(y - d, "{a} has MORE than {b}, so {a}'s number is bigger. Don't take away!")
            case .bFewer: h.add(y - d, "Read it again: {b} has fewer than {a}. So {a} has MORE. Add!")
            case .aFewer: h.add(y + d, "{a} has FEWER than {b}, so {a}'s number is smaller.")
            case .bMore:  h.add(y + d, "Read it again: {b} has more than {a}. So {a} has FEWER. Take away!")
            }
            h.add(d, "\(d) is only the difference. Start from {b}'s \(y).")
            h.add(y, "{a} and {b} don't have the same number. They are \(d) apart.")
        }
    }

    // MARK: 给来给去

    /// 一样多，一个给另一个几个，问差几个 —— 这是最容易错的一类
    static func transferEqual(_ c: StoryCtx) -> StoryProblem {
        let (a, b) = pair()
        let t = thing(c)
        let n = Int.r(in: 3...min(c.cap, 10))
        let k = Int.r(in: 1...min(n - 1, 4))
        let askFewer = Int.r(in: 0...2) == 0
        let before = [M.Bar(name: "{a}", tint: .a, segs: [s(n)]), M.Bar(name: "{b}", tint: .b, segs: [s(n)])]
        let after = [M.Bar(name: "{a}", tint: .a, segs: [s(n - k), s(k, cap: "gave", .gone)]),
                     M.Bar(name: "{b}", tint: .b, segs: [s(n), s(k, cap: "got", .solid, .a)])]
        let diff = [M.Bar(name: "{a}", tint: .a, segs: [s(n - k), s(2 * k, "?", .gap)]),
                    M.Bar(name: "{b}", tint: .b, segs: [s(n), s(k, cap: "from {a}", .solid, .a)])]
        return make(.transfer, a: a, b: b, thing: t, [
            .init(text: "{a} and {b} have \(t.n(n)) each.", actions: [.appear(.a, n), .appear(.b, n)]),
            .init(text: "{a} gives {b} \(k) of them.", actions: [.move(.a, .b, k)]),
            .init(text: askFewer ? "How many fewer \(t.many) does {a} have than {b} now?"
                                 : "How many more \(t.many) does {b} have than {a} now?"),
        ], ask: askFewer ? .less(.a, .b) : .more(.b, .a),
           answer: askFewer ? "{a} has □ fewer \(t.many) than {b}." : "{b} has □ more \(t.many) than {a}.",
           explain: "{a}: \(n) − \(k) = \(n - k)   {b}: \(n) + \(k) = \(n + k)   \(n + k) − \(n - k) = \(2 * k)",
           models: [M(bars: before), M(bars: after), M(bars: diff)]) { h in
            h.add(k, "{a} gave \(k) away, so {a} has \(k) fewer. {b} got \(k), so {b} has \(k) more. The difference is \(k) + \(k) = \(2 * k).")
            h.add(n + k, "\(n + k) is how many {b} has now. We want the difference.")
            h.add(n - k, "\(n - k) is how many {a} has now. We want the difference.")
            h.add(0, "After giving, they don't have the same number any more.")
        }
    }

    /// 本来就不一样多，再给来给去
    static func transferUnequal(_ c: StoryCtx) -> StoryProblem {
        let (a, b) = pair()
        let t = thing(c)
        let top = min(c.cap, 12)
        var x = 0, y = 0, k = 0
        repeat {
            x = Int.r(in: 4...top)
            y = Int.r(in: 1...top)
            k = Int.r(in: 1...min(x - 1, 4))
        } while x - k == y + k || x == y
        let fa = x - k, fb = y + k
        let (bs, ss): (Spot, Spot) = fa > fb ? (.a, .b) : (.b, .a)
        var final = [M.Bar(name: "{a}", tint: .a, segs: [s(fa)]),
                     M.Bar(name: "{b}", tint: .b, segs: [s(y), s(k, cap: "from {a}", .solid, .a)])]
        final[fa > fb ? 1 : 0].segs.append(s(abs(fa - fb), "?", .gap))
        return make(.transfer, a: a, b: b, thing: t, [
            .init(text: "{a} has \(t.n(x)). {b} has \(t.n(y)).", actions: [.appear(.a, x), .appear(.b, y)]),
            .init(text: "{a} gives {b} \(k) of them.", actions: [.move(.a, .b, k)]),
            .init(text: "How many more \(t.many) does \(ph(bs)) have than \(ph(ss)) now?"),
        ], ask: .more(bs, ss), answer: "\(ph(bs)) has □ more \(t.many) than \(ph(ss)).",
           explain: "{a}: \(x) − \(k) = \(fa)   {b}: \(y) + \(k) = \(fb)   \(max(fa, fb)) − \(min(fa, fb)) = \(abs(fa - fb))",
           models: [
            M(bars: [M.Bar(name: "{a}", tint: .a, segs: [s(x)]), M.Bar(name: "{b}", tint: .b, segs: [s(y)])]),
            M(bars: [M.Bar(name: "{a}", tint: .a, segs: [s(fa), s(k, cap: "gave", .gone)]),
                     M.Bar(name: "{b}", tint: .b, segs: [s(y), s(k, cap: "got", .solid, .a)])]),
            M(bars: final),
           ]) { h in
            h.add(abs(x - y), "\(abs(x - y)) was the difference before giving. Both of them changed, so compare again.")
            h.add(k, "\(k) is how many were given. Compare them after giving.")
            h.add(fa + fb, "We are comparing, not putting together.")
        }
    }

    /// 给来给去以后，问某个人有几个
    static func transferCount(_ c: StoryCtx) -> StoryProblem {
        let (a, b) = pair()
        let t = thing(c)
        let n = Int.r(in: 3...min(c.cap, 10))
        let k = Int.r(in: 1...min(n - 1, 4))
        let askB = Bool.r()
        let before = [M.Bar(name: "{a}", tint: .a, segs: [s(n)]), M.Bar(name: "{b}", tint: .b, segs: [s(n)])]
        var after = [M.Bar(name: "{a}", tint: .a, segs: [s(n - k, ""), s(k, cap: "gave", .gone)]),
                     M.Bar(name: "{b}", tint: .b, segs: [s(n), s(k, cap: "got", .solid, .a)])]
        var braces: [M.Brace] = []
        if askB { braces = [.init(bar: 1, from: 0, to: 1, label: "?")] } else { after[0].segs[0].label = "?" }
        return make(.transfer, a: a, b: b, thing: t, [
            .init(text: "{a} and {b} have \(t.n(n)) each.", actions: [.appear(.a, n), .appear(.b, n)]),
            .init(text: "{a} gives {b} \(k) of them.", actions: [.move(.a, .b, k)]),
            .init(text: askB ? "How many \(t.many) does {b} have now?" : "How many \(t.many) does {a} have left?"),
        ], ask: .count(askB ? .b : .a),
           answer: askB ? "{b} has □ \(t.many) now." : "{a} has □ \(t.many) left.",
           explain: askB ? "\(n) + \(k) = \(n + k)" : "\(n) − \(k) = \(n - k)",
           models: [M(bars: before), M(bars: after), M(bars: after, braces: braces)]) { h in
            if askB {
                h.add(n - k, "{b} is the one who got them, so {b} has more now.")
            } else {
                h.add(n + k, "{a} gave them away, so {a} has fewer now.")
            }
            h.add(k, "\(k) is how many were given. Start from the \(n) at first.")
            h.add(n, "After giving, it is not \(n) any more.")
        }
    }

    // MARK: 变成一样多

    static func equalize(_ c: StoryCtx) -> StoryProblem {
        let (a, b) = pair()
        let t = thing(c)
        let half = Int.r(in: 1...max(1, min(4, c.cap / 4)))
        let d = 2 * half
        let y = Int.r(in: 1...(c.cap - d)), x = y + d
        let barA = M.Bar(name: "{a}", tint: .a, segs: [s(y, ""), s(half, ""), s(half, "")])
        let barB = M.Bar(name: "{b}", tint: .b, segs: [s(y, "")])
        var a2 = barA
        a2.segs[1] = s(half, "?", cap: "give", .solid, .extra)
        var b2 = barB
        b2.segs.append(s(half, "", cap: "gets", .gap))
        return make(.equalize, a: a, b: b, thing: t, [
            .init(text: "{a} has \(t.n(x)).", actions: [.appear(.a, x)]),
            .init(text: "{b} has \(t.n(y)).", actions: [.appear(.b, y)]),
            .init(text: "How many \(t.many) must {a} give {b} so that they have the same number?", actions: [.balance(.a, .b)]),
        ], ask: .moved, answer: "{a} must give {b} □ \(t.many).",
           explain: "\(x) − \(y) = \(d)   Half of \(d) is \(half).",
           models: [
            M(bars: [M.Bar(name: "{a}", tint: .a, segs: [s(x)])]),
            M(bars: [barA, barB], braces: [.init(bar: 0, from: 1, to: 2, label: "\(d) more")]),
            M(bars: [a2, b2], braces: [.init(bar: 0, from: 1, to: 2, label: "\(d) more")]),
           ]) { h in
            h.add(d, "If {a} gives \(d), {b} gets \(x) and {a} has only \(y). Now it's the other way round! When {a} gives, {a} also gets fewer.")
        }
    }

    // 两步题在 StoryTwoStep.swift

    // MARK: 乘法：几个几

    static func multiply(_ c: StoryCtx) -> StoryProblem {
        let a = solo()
        // 放在盘子上的只用吃的东西
        let t = thing(c, food: c.act)
        let g: Int, n: Int
        if c.act {
            g = Int.r(in: 2...4); n = Int.r(in: 2...4)
        } else {
            g = Int.r(in: 2...5); n = [2, 3, 4, 5, 5, 10].pick()
        }
        let total = g * n
        let units = M(bars: [M.Bar(segs: (0..<g).map { _ in s(n, "", .solid, .neutral) })])
        let labelled = M(bars: [M.Bar(segs: (0..<g).map { _ in s(n, nil, .solid, .neutral) })])
        var asked = labelled
        asked.braces = [.init(bar: 0, from: 0, to: g - 1, label: "?")]
        let adds = Array(repeating: "\(n)", count: g).joined(separator: " + ")
        let explain = "\(adds) = \(total)   \(g) × \(n) = \(total)"
        let skip = (1...g).map { "\($0 * n)" }.joined(separator: ", ")
        let hints: (inout Hints) -> Void = { h in
            h.add(g + n, "Count \(n) for every group: \(skip).")
            h.add(n, "\(n) is just one group. There are \(g) groups.")
            h.add(g, "\(g) is how many groups. Count all the \(t.many).")
        }
        let actions: [[StoryAction]] = [[.plates(g)], [.fill(n)], []]
        if c.act || (t.food && Bool.r()) {
            return make(.multiply, a: a, b: nil, thing: t, [
                .init(text: "There are \(g) plates.", actions: actions[0]),
                .init(text: "Each plate has \(t.n(n)).", actions: actions[1]),
                .init(text: "How many \(t.many) are there in all?"),
            ], ask: .inPlates, answer: "There are □ \(t.many) in all.", explain: explain,
               models: [units, labelled, asked], hints: hints)
        }
        let box = ["bag", "box", "packet"].pick()
        return make(.multiply, a: a, b: nil, thing: t, [
            .init(text: "{a} has \(g) \(StoryText.plural(box)) of \(t.many).", actions: actions[0]),
            .init(text: "There are \(t.n(n)) in each \(box).", actions: actions[1]),
            .init(text: "How many \(t.many) does {a} have?"),
        ], ask: .inPlates, answer: "{a} has □ \(t.many).", explain: explain,
           models: [units, labelled, asked], plate: box, actable: false, hints: hints)
    }

    // MARK: 除法：平均分、包含除

    static func sharing(_ c: StoryCtx) -> StoryProblem {
        let a = solo()
        let t = thing(c, food: c.act)
        let g: Int, q: Int
        if c.act {
            g = Int.r(in: 2...4); q = Int.r(in: 2...4)
        } else {
            g = Int.r(in: 2...5); q = Int.r(in: 2...(c.cap >= 50 ? 10 : 5))
        }
        let total = g * q
        let wholeOnly = M(bars: [M.Bar(segs: [s(total, "", .solid, .neutral)])],
                          braces: [.init(bar: 0, from: 0, to: 0, label: "\(total)")])
        let split = M(bars: [M.Bar(segs: (0..<g).map { _ in s(q, "", .solid, .neutral) })],
                      braces: [.init(bar: 0, from: 0, to: g - 1, label: "\(total)")])
        var asked = split
        asked.bars[0].segs[0].label = "?"
        let hints: (inout Hints) -> Void = { h in
            h.add(total - g, "Sharing equally means every group gets the same number.")
            h.add(g, "\(g) is how many groups. How many in each group?")
            h.add(total, "\(total) is all of them. Share them out equally.")
            h.add(total * g, "When we share, each one gets fewer, not more.")
        }
        let explain = "\(total) ÷ \(g) = \(q)   because \(g) × \(q) = \(total)"
        if c.act || (t.food && Bool.r()) {
            return make(.divide, a: a, b: nil, thing: t, [
                .init(text: "{a} has \(t.n(total)).", actions: [.appear(.a, total)]),
                .init(text: "{a} puts them equally on \(g) plates.", actions: [.plates(g), .share]),
                .init(text: "How many \(t.many) are there on each plate?"),
            ], ask: .perPlate, answer: "There are □ \(t.many) on each plate.", explain: explain,
               models: [wholeOnly, split, asked], hints: hints)
        }
        return make(.divide, a: a, b: nil, thing: t, [
            .init(text: "{a} has \(t.n(total)).", actions: [.appear(.a, total)]),
            .init(text: "{a} shares them equally among \(g) friends.", actions: [.plates(g), .share]),
            .init(text: "How many \(t.many) does each friend get?"),
        ], ask: .perPlate, answer: "Each friend gets □ \(t.many).", explain: explain,
           models: [wholeOnly, split, asked], plate: "friend", actable: false, hints: hints)
    }

    static func grouping(_ c: StoryCtx) -> StoryProblem {
        let a = solo()
        let t = thing(c, food: c.act)
        let q: Int, k: Int
        if c.act {
            q = Int.r(in: 2...5); k = Int.r(in: 2...(q >= 5 ? 4 : 5))
        } else {
            q = [2, 3, 4, 5, 5, 10].pick(); k = Int.r(in: 2...5)
        }
        let total = q * k
        let box = c.act ? "plate" : (t.food ? ["bag", "box", "plate"] : ["bag", "box"]).pick()
        let boxes = StoryText.plural(box)
        let verb = box == "plate" ? "on each plate" : "in each \(box)"
        let wholeOnly = M(bars: [M.Bar(segs: [s(total, "", .solid, .neutral)])],
                          braces: [.init(bar: 0, from: 0, to: 0, label: "\(total)")])
        let split = M(bars: [M.Bar(segs: (0..<k).map { _ in s(q, nil, .solid, .neutral) })],
                      braces: [.init(bar: 0, from: 0, to: k - 1, label: "\(total)")])
        var asked = split
        asked.braces.append(.init(bar: 0, from: 0, to: k - 1, label: "? \(boxes)", below: true))
        return make(.divide, a: a, b: nil, thing: t, [
            .init(text: "{a} has \(t.n(total)).", actions: [.appear(.a, total)]),
            .init(text: "{a} puts \(t.n(q)) \(verb).", actions: [.group(q)]),
            .init(text: "How many \(boxes) does {a} need?"),
        ], ask: .plates, answer: "{a} needs □ \(boxes).",
           explain: "\(total) ÷ \(q) = \(k)   because \(k) × \(q) = \(total)",
           models: [wholeOnly, split, asked], plate: box) { h in
            h.add(total - q, "Each \(box) gets \(q). How many \(boxes) can we fill?")
            h.add(q, "\(q) is how many go \(verb). Count the \(boxes).")
            h.add(total, "\(total) is all the \(t.many). We want the number of \(boxes).")
        }
    }
}

// MARK: - 关卡

/// 三种玩法 = 新加坡数学的 C-P-A：先用实物演，再画线段图，最后只看文字。
/// 两步题那一章第一关多一种：先问藏在中间的那一步（steps），再问最后的问题。
enum StoryMode: String, Hashable {
    case act, model, read, steps

    var title: String {
        switch self {
        case .act:   "Act it out"
        case .model: "Draw a model"
        case .read:  "Just read"
        case .steps: "Step by step"
        }
    }

    var icon: String {
        switch self {
        case .act:   "hand.draw.fill"
        case .model: "rectangle.split.3x1.fill"
        case .read:  "text.alignleft"
        case .steps: "list.number"
        }
    }

    /// 关卡圆圈下面的短名字
    var short: String {
        switch self {
        case .act:   "Act"
        case .model: "Model"
        case .read:  "Read"
        case .steps: "Steps"
        }
    }

    var problemCount: Int {
        switch self {
        case .act, .steps: 6
        case .model:       8
        case .read:        10
        }
    }
}

/// 十章，每章三关。章的编号（rawValue）就是首页上的顺序，不存档。
enum StoryChapter: Int, CaseIterable, Identifiable, Hashable {
    case together = 1, partWhole, compare, moreFewer, giving, groups, sharing, hundred, twoSteps, challenge

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .together:  "Altogether"
        case .partWhole: "Part & Whole"
        case .compare:   "How Many More?"
        case .moreFewer: "More or Fewer?"
        case .giving:    "Giving"
        case .groups:    "Equal Groups"
        case .sharing:   "Sharing"
        case .hundred:   "Numbers to 100"
        case .twoSteps:  "Two Steps"
        case .challenge: "Challenge"
        }
    }

    var subtitle: String {
        switch self {
        case .together:  "Put together, take away"
        case .partWhole: "Find the missing part"
        case .compare:   "Line up and compare"
        case .moreFewer: "Who has more? Read carefully!"
        case .giving:    "I give, I have fewer"
        case .groups:    "Same number in each group"
        case .sharing:   "Share equally"
        case .hundred:   "Tens and ones, dollars, cm and m"
        case .twoSteps:  "Find the hidden step first"
        case .challenge: "Two steps, every type"
        }
    }

    var tint: Color {
        switch self {
        case .together:  Palette.sky
        case .partWhole: Palette.sage
        case .compare:   Palette.honey
        case .moreFewer: Palette.lilac
        case .giving:    Palette.coral
        case .groups:    Color(hex: 0x7DB8C9)
        case .sharing:   Palette.blush
        case .hundred:   Color(hex: 0x6FB39B)
        case .twoSteps:  Color(hex: 0xE0996A)
        case .challenge: Color(hex: 0xC9A15B)
        }
    }

    var icon: String {
        switch self {
        case .together:  "plus"
        case .partWhole: "square.split.2x1.fill"
        case .compare:   "equal"
        case .moreFewer: "arrow.up.arrow.down"
        case .giving:    "arrow.left.arrow.right"
        case .groups:    "multiply"
        case .sharing:   "divide"
        case .hundred:   "textformat.123"
        case .twoSteps:  "stairs"
        case .challenge: "flag.checkered"
        }
    }

    var levels: [StoryLevel] { StoryLevel.all.filter { $0.chapter == self } }
}

/// 一关。`number` 是这一关的编号：存档里所有和关有关的东西（wp.best.N、wp.stars.N、wp.set.N、
/// wp.got.<含 N 的哈希>、错题的 level、题库的键）都用它，所以它永远不变。
/// `position` 是它在首页上排第几（孩子看到的 "Level 22"）。
/// 1~24 号是最早的八章；后来在"大挑战"前面插进两章（25~30 号），大挑战还是 22~24 号，只是排到了最后。
struct StoryLevel: Hashable, Identifiable {
    /// 按首页顺序排的编号
    static let order: [Int] = Array(1...21) + Array(25...30) + [22, 23, 24]
    /// 所有编号
    static let range = 1...30
    /// 最早那八章的编号（老存档里的 wp.open 只管它们）
    static let legacy = 1...24
    static let all = order.map { StoryLevel($0) }

    let number: Int

    init(_ number: Int) {
        self.number = min(max(number, Self.range.lowerBound), Self.range.upperBound)
    }

    /// 首页上的第几关（1~30）
    init(position: Int) {
        self.init(Self.order[min(max(position, 1), Self.order.count) - 1])
    }

    var id: Int { number }
    /// 首页上的第几关，从 1 开始
    var position: Int { (Self.order.firstIndex(of: number) ?? 0) + 1 }
    var chapter: StoryChapter { StoryChapter(rawValue: (position - 1) / 3 + 1) ?? .together }
    var indexInChapter: Int { (position - 1) % 3 }
    var next: StoryLevel? { position < Self.order.count ? StoryLevel(position: position + 1) : nil }
    var previous: StoryLevel? { position > 1 ? StoryLevel(position: position - 1) : nil }

    var mode: StoryMode {
        switch chapter {
        case .challenge: return indexInChapter == 0 ? .model : .read
        // 大数目没法一个一个摆出来：两关画线段图（先不进位退位，再进位退位），再只看文字
        case .hundred:   return indexInChapter == 2 ? .read : .model
        case .twoSteps:  return [.steps, .model, .read][indexInChapter]
        default:         return [.act, .model, .read][indexInChapter]
        }
    }

    /// 关卡圆圈下面的短名字
    var short: String {
        if chapter == .hundred { return ["Tens", "Regroup", "Read"][indexInChapter] }
        return mode.short
    }

    var problemCount: Int { mode.problemCount }

    /// 数的范围：用手演的在 10 以内，画图和读题到 20；100 以内那一章到 100；两步题读题关到 50；大挑战到 50、100
    var cap: Int {
        switch chapter {
        case .challenge: return [20, 50, 100][indexInChapter]
        case .hundred:   return 100
        case .twoSteps:  return [20, 20, 50][indexInChapter]
        default:         return mode == .act ? 10 : 20
        }
    }

    /// 100 以内那一章：第一关不进位不退位，第二关都要进位或退位，读题关混着来
    var regroup: Bool? {
        guard chapter == .hundred else { return nil }
        return [false, true, nil][indexInChapter]
    }

    /// 这一章的主角题型
    private var main: [StoryFactory.Make] {
        typealias F = StoryFactory
        switch chapter {
        case .together:  return [F.combine, F.changeLose, F.changeGain]
        case .partWhole: return [F.partWhole, F.partWhole, F.changeLose]
        case .compare:   return [F.compare, F.compare, F.compare]
        case .moreFewer:
            return indexInChapter == 0 ? [F.moreThan, F.fewerThan]
                                       : [F.moreThan, F.fewerThan, F.trapFewer, F.trapMore]
        case .giving:    return [F.transferEqual, F.transferCount, F.transferUnequal, F.equalize]
        case .groups:    return [F.multiply]
        case .sharing:   return [F.sharing, F.grouping]
        case .hundred:
            let base: [StoryFactory.Make] = [F.bigCombine, F.bigChangeLose, F.bigChangeGain,
                                             F.bigPartWhole, F.bigCompare, F.bigMoreFewer]
            return mode == .read ? base + [F.bigTrap] : base
        case .twoSteps:
            return [F.totalThenShare, F.groupsThenMore, F.groupsThenEaten, F.fewerThenTotal,
                    F.moreThenTotal, F.twoStepLoseGain, F.restCompare, F.spendTwo]
        case .challenge:
            return [F.twoStepLoseGain, F.restCompare, F.moreThenTotal, F.trapFewer, F.partWhole,
                    F.multiply, F.sharing, F.transferEqual, F.grouping, F.trapMore]
        }
    }

    /// 前面几章的题，读题关里混进来，逼着先认清是哪一种
    private var review: [StoryFactory.Make] {
        typealias F = StoryFactory
        switch chapter {
        case .together, .challenge: return []
        case .partWhole: return [F.combine, F.changeGain]
        case .compare:   return [F.combine, F.partWhole, F.changeLose]
        case .moreFewer: return [F.compare, F.partWhole]
        case .giving:    return [F.compare, F.trapFewer]
        case .groups:    return [F.combine, F.compare]
        case .sharing:   return [F.multiply, F.partWhole]
        case .hundred:   return [F.multiply, F.grouping, F.trapFewer]
        case .twoSteps:  return [F.trapMore, F.sharing, F.equalize]
        }
    }

    func makeProblems() -> [StoryProblem] {
        let ctx = StoryCtx(cap: cap, act: mode == .act, regroup: regroup)
        // 复习题用以前那几章的数目（20 以内）
        let reviewCtx = StoryCtx(cap: min(cap, 20), act: false)
        var plan: [(StoryFactory.Make, StoryCtx)] = []
        while plan.count < problemCount { plan += main.mixed().map { ($0, ctx) } }
        plan = Array(plan.prefix(problemCount))
        if mode == .read, !review.isEmpty {
            for (i, make) in zip([2, 5, 8], review.mixed()) where i < plan.count { plan[i] = (make, reviewCtx) }
        }
        var used = Set<String>()
        // 后来加的两章，线段图每一段都要看得清
        let strict = chapter == .hundred || chapter == .twoSteps
        return plan.map { make, ctx in
            // 同一关里别出两道一模一样的题
            // 答案至少是 2：答案句里的名词是复数（"□ apples"）
            for _ in 0..<(strict ? 200 : 30) {
                let p = make(ctx)
                let key = p.sentences.map(\.text).joined()
                guard p.answer >= 2, !strict || StoryCheck.proportional(p) else { continue }
                // 分两问的时候，两问的答案一样会让她以为没变
                if strict, let m = p.middle, m.answer == p.answer { continue }
                // 读题关要先选算式：2 × 2 这种看不出错法的题不要
                if strict, mode == .read, p.choice == nil, p.schema != .transfer, p.schema != .equalize { continue }
                if used.insert(key).inserted { return p }
            }
            return make(ctx)
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
    /// 两步题分两问做时，错在哪一问：0 = 中间那一问（answer 是那一问答的数），nil = 最后的问题
    var step: Int? = nil
}

extension StoryProblem {
    /// 认一道题用的钥匙：关 + 每一句的原文。题库重新生成时 id 会变，文字不会变。
    /// 用 FNV-1a 自己算，不用 Hasher（Hasher 每次启动都不一样）。
    func starKey(level: Int) -> String {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in "\(level)|\(sentences.map(\.text).joined(separator: "|"))".utf8 {
            h ^= UInt64(b)
            h = h &* 0x0000_0100_0000_01B3
        }
        return String(h, radix: 36)
    }
}

extension StoryLevel {
    /// 家长在「我的」里打开"全部解锁"（跟着存档走，见 PlayerStore.settingKeys）
    static let unlockAllKey = "story.unlockAll"

    /// 这一关最多拿几颗星：题库里这一关有几道题（每道题一颗）；没有题库时按 3 套题算
    var maxStars: Int { StoryBank.problemCount(for: self) ?? 3 * problemCount }

    /// 过关要第一下就答对几道（75%，和 StorySession.stars 的 2 星线一样）
    var passMark: Int { (problemCount * 3 + 3) / 4 }
}

/// 一关里哪些题要在最后再做一遍：第一次答错的，按原来的顺序
enum StoryRetry {
    static func indices(_ firstTry: [Bool]) -> [Int] { firstTry.indices.filter { !firstTry[$0] } }
}

extension PlayerStore {
    /// 这一关最好的一次做得怎么样（1~3，3 = 全对）；用来判断过没过关、有没有皇冠，不当星星显示
    func storyBest(_ level: StoryLevel) -> Int { count("wp.best.\(level.number)") }
    func storyPerfect(_ level: StoryLevel) -> Bool { storyBest(level) >= 3 }
    /// 过关 = 有一次第一下就答对了 75% 以上
    func storyPassed(_ level: StoryLevel) -> Bool { storyBest(level) >= 2 }

    // MARK: 星星：每道题一颗，第一次"第一下就答对"时拿到

    /// 这一关拿到的星星（不会超过 level.maxStars）
    func storyStars(_ level: StoryLevel) -> Int { count("wp.stars.\(level.number)") }
    func storyStars(_ chapter: StoryChapter) -> Int { chapter.levels.reduce(0) { $0 + storyStars($1) } }
    func storyMaxStars(_ chapter: StoryChapter) -> Int { chapter.levels.reduce(0) { $0 + $1.maxStars } }
    var storyStarTotal: Int { StoryLevel.all.reduce(0) { $0 + storyStars($1) } }

    private func starKey(_ p: StoryProblem, _ level: StoryLevel) -> String { "wp.got." + p.starKey(level: level.number) }

    /// 这道题的星星已经拿过了
    func storyHasStar(_ p: StoryProblem, level: StoryLevel) -> Bool {
        count(starKey(p, level)) > 0 || storyStars(level) >= level.maxStars
    }

    /// 第一下就答对了一道题：这道题的星星还没拿过就给一颗，返回 true；拿过了返回 false
    @discardableResult
    func collectStoryStar(_ p: StoryProblem, level: StoryLevel) -> Bool {
        guard !storyHasStar(p, level: level) else { return false }
        setCount(starKey(p, level), 1)
        earnStars(1, key: "wp.stars.\(level.number)")
        return true
    }

    // MARK: 解锁

    /// 第 1 关一直开着；后面的关要（按首页顺序的）前一关过关。
    /// 老存档里已经玩到的关（wp.open，只管最早的 1~24 号）和升级时已经开着的关（wp.keep.N）保持打开。
    func storyUnlocked(_ level: StoryLevel,
                       unlockAll: Bool = UserDefaults.standard.bool(forKey: StoryLevel.unlockAllKey)) -> Bool {
        if unlockAll { return true }
        guard let prev = level.previous else { return true }
        if StoryLevel.legacy.contains(level.number), level.number <= count("wp.open") { return true }
        return count("wp.keep.\(level.number)") > 0 || storyPassed(prev)
    }

    /// 推荐的关：第一个开着、还没过关的关
    func storyRecommended(unlockAll: Bool = UserDefaults.standard.bool(forKey: StoryLevel.unlockAllKey)) -> StoryLevel {
        StoryLevel.all.first { storyUnlocked($0, unlockAll: unlockAll) && !storyPassed($0) }
            ?? StoryLevel.all[StoryLevel.all.count - 1]
    }

    /// 老存档升级（每次启动、导入存档后都跑，可以重复跑）：
    /// 1. 以前重玩也能拿星星，超过上限的砍到上限，总数同样减掉，这样各关加起来还是等于总数；
    /// 2. 以前没有过关这回事，已经玩到的最远那一关和它前面的关都保持打开（只在第一次升级时记一下）。
    func migrateStoryProgress() {
        var excess = 0
        for level in StoryLevel.all where storyStars(level) > level.maxStars {
            excess += storyStars(level) - level.maxStars
            setCount("wp.stars.\(level.number)", level.maxStars)
        }
        if excess > 0 { addStars(-min(excess, totalStars)) }
        if count("wp.v2") == 0 {
            let played = StoryLevel.all.filter { storyBest($0) >= 1 || storyStars($0) > 0 }.map(\.number)
                .filter(StoryLevel.legacy.contains).max() ?? 0
            setCount("wp.open", played)
            setCount("wp.v2", 1)
        }
        // 3. 大挑战（22~24 号）前面插进了两章：22 号的"前一关"从 21 号变成了 30 号。
        //    升级前 22 号已经开着的（因为 21 号过关了），记下来让它继续开着；别的关的前一关都没变。
        if count("wp.v3") == 0 {
            for id in StoryLevel.legacy {
                let old = id - 1
                let level = StoryLevel(id)
                guard old >= 1, level.previous?.number != old else { continue }
                let wasOpen = id <= count("wp.open") || storyPassed(StoryLevel(old))
                if wasOpen { setCount("wp.keep.\(id)", 1) }
            }
            setCount("wp.v3", 1)
        }
    }

    // MARK: 列式（读题关里先选算式）

    /// 读题关里"先选算式"第一下选得对不对，按题型统计（和算错分开，家长页上分开显示）
    func recordStoryChoice(_ schema: StorySchema, correct: Bool) {
        increment("wp.op\(correct ? "right" : "wrong").\(schema.rawValue)")
    }

    func storyChoiceStats(_ schema: StorySchema) -> (right: Int, wrong: Int) {
        (count("wp.opright.\(schema.rawValue)"), count("wp.opwrong.\(schema.rawValue)"))
    }

    // MARK: 错题

    /// 还没练会的错题；同一道题错过几次只算一道，最新的在前
    var storyOpenMistakes: [StoryMistake] {
        var seen = Set<String>()
        return storyMistakes.filter { !$0.fixed && seen.insert($0.problem.starKey(level: $0.level)).inserted }
    }

    /// 这道题会做了：错题本里这道题（错过几次就有几条）都标成练会了
    func markStoryProblemFixed(_ p: StoryProblem, level: Int) {
        let key = p.starKey(level: level)
        for m in storyMistakes where !m.fixed && m.level == level && m.problem.starKey(level: level) == key {
            markMistakeFixed(m.id)
        }
    }

    /// 一共做对了多少道题
    var storySolved: Int { count("wp.solved") }

    @discardableResult
    func recordStoryLevel(_ level: StoryLevel, stars: Int) -> Bool {
        let isRecord = stars > storyBest(level)
        if isRecord { setCount("wp.best.\(level.number)", stars) }
        return isRecord
    }

    /// 每道题第一次答对还是答错，按题型统计
    func recordStoryAnswer(_ schema: StorySchema, correct: Bool) {
        increment("wp.\(correct ? "right" : "wrong").\(schema.rawValue)")
    }

    func recordStorySolved() { increment("wp.solved") }

    func storyStats(_ schema: StorySchema) -> (right: Int, wrong: Int) {
        (count("wp.right.\(schema.rawValue)"), count("wp.wrong.\(schema.rawValue)"))
    }
}
