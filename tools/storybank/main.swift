// 生成「加减乘除」的题库（RanranGame/Content/story_bank.json）和英文配音清单（tools/voice/manifest_en.json）。
//
// 只补缺的关：题库里已经有的关一个字都不动（那些题都录好了音，孩子在上面拿的星星也按题的文字记着），
// 只给题库里还没有的关出题。出题按"关的编号 + 第几套"播种，所以同一关每次生成都一模一样；
// 再跑一遍什么都不会变。配音清单 = 原来清单里的每一句 + 现在题库里要读的每一句。
//
// 每关出 3 套题（每套 = 一关的题量），三套之间不重复；每道题都要通过 validate 的检查。
import Foundation
import CryptoKit

let root = CommandLine.arguments[1]
let sampleLevels = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] == "--samples" : false
let sets = 3
let player = "冉冉" // 配音按 "Ranran" 录；改了名字的话，带名字的句子会用系统语音读
let bankURL = URL(fileURLWithPath: root + "/RanranGame/Content/story_bank.json")
let manifestURL = URL(fileURLWithPath: root + "/tools/voice/manifest_en.json")

let enc = JSONEncoder()
enc.outputFormatting = [.sortedKeys]

var issues = 0
var legacyNotes = 0
/// 这一关是新出的（严格检查）还是题库里原来就有的（只报告，不能改：改了就对不上录音和星星）
var strict = true
func check(_ ok: Bool, _ msg: @autoclosure () -> String) {
    guard !ok else { return }
    if strict {
        issues += 1
        if issues < 60 { print("✗", msg()) }
    } else {
        legacyNotes += 1
        if legacyNotes < 15 { print("· (legacy)", msg()) }
    }
}
func render(_ t: String, _ p: StoryProblem, blank: String = "?") -> String { StoryText.plain(t, p, player: player, blank: blank) }

/// 线段图里的 "?" 要正好一个，而且就是 value
func checkModel(_ m: BarModel, value: Int, _ tag: String) {
    var found = 0
    for bar in m.bars { for sg in bar.segs where sg.label == "?" { found += 1; check(sg.value == value, "model ? = \(sg.value) ≠ \(value): \(tag)") } }
    for b in m.braces where b.label.contains("?") {
        found += 1
        let segs = m.bars[b.bar].segs[b.from...b.to]
        let v = b.label == "?" ? segs.reduce(0) { $0 + $1.value } : segs.count
        check(v == value, "brace ? = \(v) ≠ \(value): \(tag)")
    }
    if m.total == "?" {
        found += 1
        let v = m.bars.flatMap(\.segs).filter { $0.style != .gap }.reduce(0) { $0 + $1.value }
        check(v == value, "total ? = \(v) ≠ \(value): \(tag)")
    }
    check(found == 1, "\(found) question marks in a model: \(tag)")
}

let plurals = "apples|strawberries|carrots|sweets|cookies|balloons|stickers|pencils|marbles|storybooks|stamps|beads|seashells|crayons|eggs|muffins|oranges|dollars"

func numbers(_ s: String) -> [Int] {
    let re = try! NSRegularExpression(pattern: #"\d+"#)
    return re.matches(in: s, range: NSRange(s.startIndex..., in: s)).map { Int(s[Range($0.range, in: s)!])! }
}

func validate(_ p: StoryProblem, _ level: StoryLevel) {
    let text = p.sentences.map { render($0.text, p) }.joined(separator: " ")
    let tag = "L\(level.number) \(p.schema): \(text)"
    check(p.answer >= 2, "answer \(p.answer): \(tag)")
    if level.mode == .act { check(p.canAct, "not actable: \(tag)") }
    check(p.hints[p.answer] == nil && p.hints.keys.allSatisfy { $0 >= 0 }, "hints \(tag)")
    var c: [Spot: Int] = [:]
    for act in p.sentences.flatMap(\.actions) {
        StoryProblem.apply(act, to: &c)
        check(c.filter { $0.key != .supply }.values.allSatisfy { $0 >= 0 }, "neg \(tag)")
    }
    check(!text.contains("{") && !render(p.answerTemplate, p).contains("{"), "placeholder \(tag)")
    let allText = text + " " + render(p.answerTemplate, p, blank: "\(p.answer)") + " " + p.hints.values.map { render($0, p) }.joined(separator: " ")
    check(allText.range(of: #"(?<![\d])1 (\#(plurals))\b"#, options: .regularExpression) == nil, "plural \(tag)")
    check(p.models.count == p.sentences.count, "models count \(tag)")
    checkModel(p.models.last!, value: p.answer, tag)
    // 句子：前面几句是陈述句，最后一句是问题；答案句里正好一个空
    check(p.sentences.dropLast().allSatisfy { $0.text.hasSuffix(".") } && p.sentences.last!.text.hasSuffix("?"), "punctuation \(tag)")
    check(p.answerTemplate.filter { $0 == "□" }.count == 1, "answer blank \(tag)")
    // 算式：每一个都算得对，最后一个就是答案，中间没有负数
    let cs = p.calcs
    check(!cs.isEmpty && cs.allSatisfy(\.isRight), "explain arithmetic '\(p.explain)': \(tag)")
    check(cs.allSatisfy { $0.result >= 0 }, "negative step \(tag)")
    if p.schema != .equalize { check(cs.last?.result == p.answer, "explain ≠ answer '\(p.explain)': \(tag)") }
    if let ch = p.choice {
        check(Set(ch.options).count == ch.options.count && ch.options.allSatisfy { $0.result >= 0 }, "choice options \(tag)")
        check(ch.options[ch.correct] == p.keyCalc!.calc, "choice correct \(tag)")
    }
    guard strict else { return }
    // —— 下面这些只查新出的关 ——
    check(StoryCheck.proportional(p), "a bar segment is too thin: \(tag)")
    // 数的大小：题里、答案、每一步都不超过这一关的范围
    let cap = max(level.cap, 20)
    check(numbers(text).allSatisfy { $0 <= cap } && cs.allSatisfy { $0.result <= cap && $0.a <= cap }, "too big for cap \(cap): \(tag)")
    // 单位：说钱的每个数后面都是 dollars；说长度的每个数后面都是 cm / m
    let units = ["dollars": "dollars", "cm": "cm", "m": "m"]
    if let u = units[p.thing.many] {
        var t = (p.sentences.map(\.text) + [p.answerTemplate.replacingOccurrences(of: "□", with: "0")]).joined(separator: " ")
        if let m = p.middle { t += " " + m.text + " " + m.answerTemplate.replacingOccurrences(of: "□", with: "0") }
        let re = try! NSRegularExpression(pattern: #"(?<!\d)\d+(?!\d)(?! \#(u)\b)"#)
        check(re.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) == nil, "units (\(u)) \(tag)")
        check(!t.contains(u == "dollars" ? " cm" : " dollars"), "mixed units \(tag)")
    }
    // 100 以内那一章：第一关不进位退位，第二关都要进位或退位
    if let rg = level.regroup, let (k, _) = p.keyCalc, p.schema != .multiply, p.schema != .divide, level.mode != .read {
        let carry = k.op == "+" ? k.a % 10 + k.b % 10 >= 10 : k.a % 10 < k.b % 10
        check(carry == rg, "regroup should be \(rg): \(p.explain) \(tag)")
    }
    if level.mode == .read { check(p.choice != nil || [.transfer, .equalize].contains(p.schema), "no choice: \(tag)") }
    if level.chapter == .hundred { check(level.mode == .read || p.tensOnes != nil, "no tens and ones: \(tag)") }
    // 两步题那一章：每道两步题都要有中间那一问
    if level.chapter == .twoSteps, p.schema == .twoStep {
        guard let m = p.middle else { check(false, "no middle step: \(tag)"); return }
        check(m.answer >= 2, "middle answer \(m.answer): \(tag)")
        check(cs.count == 2 && cs[0].result == m.answer && StoryCalc.parse(m.explain) == cs[0], "middle ≠ first step: \(tag)")
        check(m.hints[m.answer] == nil && m.hints.keys.allSatisfy { $0 >= 0 }, "middle hints \(tag)")
        check(m.text.hasSuffix("?") && m.answerTemplate.filter { $0 == "□" }.count == 1, "middle text \(tag)")
        check(!render(m.text, p).contains("{") && !render(m.answerTemplate, p).contains("{"), "middle placeholder \(tag)")
        checkModel(m.model, value: m.answer, "middle " + tag)
        checkModel(m.after, value: p.answer, "after " + tag)
    }
    if level.mode == .steps { check(p.middle != nil, "steps level without middle: \(tag)") }
}

// MARK: 题库：已有的关原样留着，只补缺的

let original = try? Data(contentsOf: bankURL)
var bank: [String: [StoryProblem]] = [:]
if let original {
    bank = try JSONDecoder().decode([String: [StoryProblem]].self, from: original)
    // 读进来再写出去必须一字不差，否则就会动到已经录好音的题
    guard try enc.encode(bank) == original else {
        print("✗ the existing bank does not round-trip byte for byte; refusing to touch it")
        exit(1)
    }
}
let existing = Set(bank.keys)
var added: [StoryLevel] = []

func seed(_ level: StoryLevel, _ set: Int, _ attempt: Int) -> UInt64 {
    UInt64(level.number) &* 1_000_003 &+ UInt64(set) &* 7_919 &+ UInt64(attempt) &* 104_729 &+ 0x5EED
}

for level in StoryLevel.all where bank["\(level.number)"] == nil {
    var seen = Set<String>()
    var all: [StoryProblem] = []
    for set in 0..<sets {
        // 一套题里不能和前面几套重复，最多重出 200 次
        var best: [StoryProblem] = []
        for attempt in 0..<200 {
            StoryRNG.reseed(seed(level, set, attempt))
            let ps = level.makeProblems()
            let keys = ps.map { $0.sentences.map(\.text).joined() }
            if Set(keys).count == keys.count, seen.isDisjoint(with: keys) { best = ps; break }
            if best.isEmpty { best = ps }
        }
        for i in best.indices {
            best[i].id = StoryRNG.uuid()
            seen.insert(best[i].sentences.map(\.text).joined())
        }
        all += best
    }
    bank["\(level.number)"] = all
    added.append(level)
}

for level in StoryLevel.all {
    strict = !existing.contains("\(level.number)")
    let all = bank["\(level.number)"]!
    for p in all { validate(p, level) }
    let dupes = all.count - Set(all.map { $0.sentences.map(\.text).joined() }).count
    check(dupes == 0, "L\(level.number) has \(dupes) duplicates")
}

let out = try enc.encode(bank)
// 有问题就什么都不写：写进去的题下次就成了"已有的题"，再也不会重出
let writing = issues == 0
if writing, out != original { try out.write(to: bankURL) }

// MARK: 配音清单：原来的每一句 + 现在要读的每一句

func fileName(_ text: String) -> String {
    "en_" + Insecure.SHA1.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined().prefix(10)
}
var lines: [String] = []
for level in StoryLevel.all {
    for p in bank["\(level.number)"]! {
        lines += p.sentences.map { render($0.text, p) }
        lines.append(render(p.answerTemplate, p, blank: "\(p.answer)"))
        lines += p.hints.values.map { render($0, p) }
        lines.append(render(p.genericHint, p))
        // 分两问做的关：中间那一问、它的答案句和提示也要读
        if level.mode == .steps, let m = p.middle {
            lines.append(render(m.text, p))
            lines.append(render(m.answerTemplate, p, blank: "\(m.answer)"))
            lines += m.hints.values.map { render($0, p) }
        }
    }
}
lines += StoryVoiceLines.all

let oldManifest = (try? Data(contentsOf: manifestURL))
    .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [[String: String]] } ?? []
var manifest: [[String: String]] = oldManifest
var used = Set(oldManifest.compactMap { $0["text"] })
var needed = Set<String>()
var fresh = 0
for t in lines where !t.isEmpty {
    needed.insert(t)
    guard used.insert(t).inserted else { continue }
    // 全大写的强调词（FEWER、MORE）给语音合成时改成小写，免得被一个字母一个字母地念
    var speak = StoryText.spoken(t)
    let caps = try! NSRegularExpression(pattern: #"\b[A-Z]{3,}\b"#)
    for m in caps.matches(in: speak, range: NSRange(speak.startIndex..., in: speak)).reversed() {
        let r = Range(m.range, in: speak)!
        speak.replaceSubrange(r, with: speak[r].lowercased())
    }
    manifest.append(["file": fileName(t), "text": t, "speak": speak])
    fresh += 1
}
manifest.sort { $0["file"]! < $1["file"]! }
let mdata = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
if writing, mdata != (try? Data(contentsOf: manifestURL)) { try mdata.write(to: manifestURL) }
if !writing { print("✗ nothing written: fix the issues above first") }

let unusedOld = oldManifest.compactMap { $0["text"] }.filter { !needed.contains($0) }
let total = bank.values.reduce(0) { $0 + $1.count }
print("levels \(bank.count) (new: \(added.map(\.number))), problems \(total)")
print("voice lines \(manifest.count): \(manifest.count - fresh) already in the manifest, \(fresh) new this run; \(needed.count) needed now")
if !unusedOld.isEmpty { print("lines in the manifest no longer spoken: \(unusedOld.count) — \(unusedOld.prefix(5))") }
print("issues \(issues) (new levels), legacy notes \(legacyNotes) (existing levels, left as recorded)")

// MARK: 样题：新那几章每关 5 道

if sampleLevels {
    for level in StoryLevel.all where !StoryLevel.legacy.contains(level.number) {
        print("\n=== Level \(level.position) (#\(level.number)) · \(level.chapter.title) · \(level.mode.title) · cap \(level.cap) ===")
        for p in bank["\(level.number)"]!.prefix(5) {
            print("• [\(p.schema)] " + p.sentences.dropLast().map { render($0.text, p) }.joined(separator: " "))
            if level.mode == .steps, let m = p.middle {
                print("   (a) \(render(m.text, p))  →  \(render(m.answerTemplate, p, blank: "\(m.answer)"))")
                print("   (b) \(render(p.sentences.last!.text, p))  →  \(render(p.answerTemplate, p, blank: "\(p.answer)"))")
            } else {
                print("   \(render(p.sentences.last!.text, p))  →  \(render(p.answerTemplate, p, blank: "\(p.answer)"))")
            }
            var extra = "   = \(render(p.explain, p))"
            if level.mode == .read, let ch = p.choice {
                let opts: [String] = ch.options.indices.map { i in i == ch.correct ? "[" + ch.options[i].blank + "]" : ch.options[i].blank }
                extra += "   choose: " + opts.joined(separator: " / ")
            }
            print(extra)
        }
    }
}
if issues > 0 { exit(2) }
