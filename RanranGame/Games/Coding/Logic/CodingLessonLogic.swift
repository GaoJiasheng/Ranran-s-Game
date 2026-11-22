import Foundation

// 编程教学的判题。只用 Foundation。每道题都由解释器判，不认写死的答案。
//
// 一步（TutorialStep）里写的东西：
//   board            花园，好几个用 | 隔开（写法见 CodingGarden）
//   extra.program    程序里一开始摆着什么（文字写法见 CodingProgram；没写就是空的）
//   extra.limits     积木盒和格子（写法见 CodingLimits(spec:)）
//   extra.run        "yes"：这一步一进来就让小兔照着 program 跑一遍（演示）
//   marks            glow:c2（格子发光）· ring:c2（格子画圈）· block:0:1.0（程序里的一块发光：第几栏:一层一层的序号）
// 题目（task.type，task.rule 和 type 一样，练一练时按它配通用说法）：
//   build    排一个程序让小兔过关（每个花园都过）。extra.need = rep / S / T / ?b / ?y / *（必须用到）；extra.max = 积木最多几块
//   fix      程序已经排好了、有一处错，改到过关。extra.need / max 同上
//   predict  看着程序点小兔最后站在哪一格（不让跑）。答案 = 解释器在第一个花园里算出的终点
//   spot     点出程序里错的那一块。答案 = 换掉这一块（换成积木盒里的另一块，或者改一个次数）就能过关的那些块
//   choose   extra.options = 几个程序，用 | 隔开；点能过关的那个。正好只有一个能过
//   count    extra.template = 程序，里面的 # 是要填的数（"#[R]"，或者 "R#" = 连着几个 R）；extra.counts = 几个数，用 | 隔开。
//            正好只有一个数能过
// build / fix 的 extra.answer = 参考程序（错两次时用影子摆出来；测试证明它能过、合规矩）。
// extra.claim = 课文里说到的、要测试核对的事实，用 , 隔开：
//   outcome=bump|end|dizzy|success（program 跑出来的结果）· culprit=0:2（program 出错停在哪一块）· answer=4（count 的答案）
//   option=2（choose 的答案，从 1 数）· cell=c1（predict 的答案）· size=5（参考答案几块）· eats=3（program 吃到几根）

enum CodingLessonLogic {
    struct Setup {
        var gardens: [CodingGarden]
        var limits: CodingLimits
        var program: CodingProgram
    }

    static let defaultLimits = CodingLimits(palette: CodingPiece.palette("U D L R"), main: 8)

    static func gardens(_ step: TutorialStep) -> [CodingGarden]? { step.board.flatMap(CodingGardens.parse) }

    static func extra(_ step: TutorialStep, _ key: String) -> String? { step.task?.extra?[key] ?? step.extra?[key] }

    static func limits(_ step: TutorialStep) -> CodingLimits {
        extra(step, "limits").flatMap(CodingLimits.init(spec:)) ?? defaultLimits
    }

    static func program(_ step: TutorialStep) -> CodingProgram {
        extra(step, "program").flatMap(CodingProgram.init(text:)) ?? CodingProgram()
    }

    static func answer(_ step: TutorialStep) -> CodingProgram? { extra(step, "answer").flatMap(CodingProgram.init(text:)) }

    static func options(_ step: TutorialStep) -> [CodingProgram] {
        (extra(step, "options") ?? "").split(separator: "|").compactMap { CodingProgram(text: $0.trimmingCharacters(in: .whitespaces)) }
    }

    static func counts(_ step: TutorialStep) -> [Int] {
        (extra(step, "counts") ?? "").split(separator: "|").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// 把 # 换成 n："#[R]" → "3[R]"；"R#" → "R R R"
    static func fill(_ template: String, _ n: Int) -> CodingProgram? {
        var out = ""
        let c = Array(template)
        var i = 0
        while i < c.count {
            if i + 1 < c.count, c[i + 1] == "#", CodingDir(rawValue: c[i]) != nil {
                out += Array(repeating: String(c[i]), count: n).joined(separator: " ")
                i += 2
            } else if c[i] == "#" {
                out += String(n)
                i += 1
            } else {
                out.append(c[i])
                i += 1
            }
        }
        return CodingProgram(text: out)
    }

    static func countProgram(_ step: TutorialStep, _ n: Int) -> CodingProgram? { extra(step, "template").flatMap { fill($0, n) } }

    // MARK: 判

    enum Verdict: Equatable {
        case pass
        /// 跑完没过关（哪个花园、为什么）
        case fail(garden: Int, CodingOutcome)
        /// 过关了，但没做到题目要求（必须用到某块积木 / 积木太多）
        case needs(String)
        case tooMany(Int)
    }

    static func judge(_ p: CodingProgram, _ step: TutorialStep) -> Verdict {
        guard let gs = gardens(step) else { return .fail(garden: 0, .end) }
        let r = CodingRunResult.run(p, gs)
        if let i = r.failedGarden { return .fail(garden: i, r.traces[i].outcome) }
        if let need = extra(step, "need"), let piece = CodingPiece(token: need), !p.pieces.contains(piece) { return .needs(need) }
        if let m = extra(step, "max").flatMap(Int.init), p.size > m { return .tooMany(m) }
        return .pass
    }

    /// predict 的答案：程序在第一个花园里跑完，小兔站在哪一格
    static func predictCell(_ step: TutorialStep) -> CodingCell? {
        guard let g = gardens(step)?.first else { return nil }
        return CodingMachine.trace(program(step), in: g).final.cell
    }

    /// spot 的答案：换掉这一块就能过关的那些块
    static func spotRefs(_ step: TutorialStep) -> Set<CodingRef> {
        guard let gs = gardens(step) else { return [] }
        let p = program(step), lim = limits(step)
        var out = Set<CodingRef>()
        let simple = lim.palette.filter { !$0.isContainer }
        for r in p.allRefs {
            guard let b = p.block(at: r) else { continue }
            var tries: [CodingBlock] = []
            if case let .loop(n, body) = b { tries = (2...9).filter { $0 != n }.map { .loop($0, body) } }
            else if b.body == nil { tries = simple.map(\.fresh).filter { $0 != b } }
            for t in tries {
                var q = p
                if q.replace(at: r, with: t), CodingRules.fits(q, lim), CodingMachine.passes(q, gs) { out.insert(r); break }
            }
        }
        return out
    }

    /// choose 的答案（从 0 数）：正好只有一个能过；不是正好一个就是 nil
    static func chooseIndex(_ step: TutorialStep) -> Int? {
        guard let gs = gardens(step) else { return nil }
        let ok = options(step).indices.filter { CodingMachine.passes(options(step)[$0], gs) }
        return ok.count == 1 ? ok[0] : nil
    }

    /// count 的答案：正好只有一个数能过
    static func countAnswer(_ step: TutorialStep) -> Int? {
        guard let gs = gardens(step) else { return nil }
        let ok = counts(step).filter { n in countProgram(step, n).map { CodingMachine.passes($0, gs) } ?? false }
        return ok.count == 1 ? ok[0] : nil
    }

    // MARK: 标记

    /// 程序里的一块："0:1.0" → 第 0 栏，路径 [1, 0]
    static func ref(_ s: String) -> CodingRef? {
        let p = s.split(separator: ":")
        guard p.count == 2, let t = Int(p[0]) else { return nil }
        let path = p[1].split(separator: ".").compactMap { Int($0) }
        return path.isEmpty ? nil : CodingRef(track: t, path: path)
    }

    static func refText(_ r: CodingRef) -> String { "\(r.track):" + r.path.map(String.init).joined(separator: ".") }

    // MARK: 练一练：四种样子

    /// 0 原样，1 左右翻，2 上下翻，3 都翻。花园、程序里的箭头、标记的格子一起翻（答案都是解释器算的，跟着就对了）
    static func flip(_ steps: [TutorialStep], _ k: Int) -> [TutorialStep] {
        guard k != 0 else { return steps }
        // 标记的格子按这一段的花园翻（一段里花园一样大）
        var size: (w: Int, h: Int)?
        return steps.map { s in
            var t = s
            if let b = s.board, let gs = CodingGardens.parse(b) {
                size = (gs[0].width, gs[0].height)
                t.board = CodingGardens.text(gs.map { $0.flipped(k) })
            }
            func prog(_ x: String) -> String { CodingProgram(text: x).map { $0.flipped(k).text } ?? x }
            func template(_ x: String) -> String {
                String(x.map { ch -> Character in
                    guard let d = CodingDir(rawValue: ch) else { return ch }
                    var e = d
                    if k & 1 != 0 { e = e.flippedX }
                    if k & 2 != 0 { e = e.flippedY }
                    return e.rawValue
                })
            }
            func mapExtra(_ e: [String: String]?) -> [String: String]? {
                guard var e else { return nil }
                for key in ["program", "answer"] { if let v = e[key] { e[key] = prog(v) } }
                if let v = e["options"] { e["options"] = v.split(separator: "|").map { prog($0.trimmingCharacters(in: .whitespaces)) }.joined(separator: "|") }
                if let v = e["template"] { e["template"] = template(v) }
                // 积木盒里的箭头也跟着翻（"main=4 | R U" → "main=4 | L U"）
                if let v = e["limits"], let bar = v.firstIndex(of: "|") {
                    e["limits"] = String(v[..<bar]) + template(String(v[bar...]))
                }
                if let v = e["claim"], let size {
                    e["claim"] = v.split(separator: ",").map { c -> String in
                        let kv = c.split(separator: "=").map(String.init)
                        if kv.count == 2, kv[0] == "cell", let cell = CodingCell(name: kv[1]) {
                            return "cell=" + flipCell(cell, k, size).name
                        }
                        return String(c)
                    }.joined(separator: ",")
                }
                return e
            }
            t.extra = mapExtra(s.extra)
            if var task = s.task {
                task.extra = mapExtra(task.extra)
                t.task = task
            }
            if let size {
                t.marks = s.marks?.map { m in
                    let p = m.split(separator: ":", maxSplits: 1).map(String.init)
                    guard p.count == 2, p[0] == "glow" || p[0] == "ring", let c = CodingCell(name: p[1]) else { return m }
                    return p[0] + ":" + flipCell(c, k, size).name
                }
            }
            return t
        }
    }

    static func flipCell(_ c: CodingCell, _ k: Int, _ size: (w: Int, h: Int)) -> CodingCell {
        CodingCell(x: k & 1 != 0 ? size.w - 1 - c.x : c.x, y: k & 2 != 0 ? size.h - 1 - c.y : c.y)
    }
}
