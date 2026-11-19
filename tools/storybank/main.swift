// 生成「加减乘除」的题库（RanranGame/Content/story_bank.json）和英文配音清单（tools/voice/manifest_en.json）。
// 每关出 3 套题（每套 = 一关的题量），三套之间不重复；每道题都要通过和以前一样的检查。
import Foundation
import CryptoKit

let root = CommandLine.arguments[1]
let sets = 3
let player = "冉冉" // 配音按 "Ranran" 录；改了名字的话，带名字的句子会用系统语音读

var issues = 0
func check(_ ok: Bool, _ msg: @autoclosure () -> String) { if !ok { issues += 1; if issues < 40 { print("✗", msg()) } } }
func render(_ t: String, _ p: StoryProblem, blank: String = "?") -> String { StoryText.plain(t, p, player: player, blank: blank) }

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
    check(text.range(of: #"(?<![\d])1 (apples|strawberries|carrots|sweets|cookies|balloons|stickers|pencils|marbles|storybooks|stamps|beads|seashells|crayons|eggs|muffins|oranges)"#, options: .regularExpression) == nil, "plural \(tag)")
    check(p.models.count == p.sentences.count, "models count \(tag)")
    let last = p.models.last!
    var found = 0
    for bar in last.bars { for sg in bar.segs where sg.label == "?" { found += 1; check(sg.value == p.answer, "model ? \(tag)") } }
    for b in last.braces where b.label.contains("?") {
        found += 1
        let segs = last.bars[b.bar].segs[b.from...b.to]
        let v = b.label == "?" ? segs.reduce(0) { $0 + $1.value } : segs.count
        check(v == p.answer, "brace ? \(tag)")
    }
    if last.total == "?" { found += 1 }
    check(found == 1, "\(found) question marks: \(tag)")
}

var bank: [String: [StoryProblem]] = [:]
for level in StoryLevel.all {
    var seen = Set<String>()
    var all: [StoryProblem] = []
    for _ in 0..<sets {
        // 一套题里不能和前面几套重复，最多重出 200 次
        var best: [StoryProblem] = []
        for _ in 0..<200 {
            let ps = level.makeProblems()
            let keys = ps.map { $0.sentences.map(\.text).joined() }
            if Set(keys).count == keys.count, seen.isDisjoint(with: keys) { best = ps; break }
            if best.isEmpty { best = ps }
        }
        for p in best { seen.insert(p.sentences.map(\.text).joined()); validate(p, level) }
        all += best
    }
    let dupes = all.count - Set(all.map { $0.sentences.map(\.text).joined() }).count
    check(dupes == 0, "L\(level.number) has \(dupes) duplicates")
    bank["\(level.number)"] = all
}

let enc = JSONEncoder()
enc.outputFormatting = [.sortedKeys]
try! enc.encode(bank).write(to: URL(fileURLWithPath: root + "/RanranGame/Content/story_bank.json"))

// 配音清单：每道题读的句子、答案句、提示；再加上固定的短句
func fileName(_ text: String) -> String {
    "en_" + Insecure.SHA1.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined().prefix(10)
}
var lines: [String] = []
for (_, ps) in bank {
    for p in ps {
        lines += p.sentences.map { render($0.text, p) }
        lines.append(render(p.answerTemplate, p, blank: "\(p.answer)"))
        lines += p.hints.values.map { render($0, p) }
        lines.append(render(p.genericHint, p))
    }
}
lines += StoryVoiceLines.all
var manifest: [[String: String]] = []
var used = Set<String>()
for t in lines where !t.isEmpty && used.insert(t).inserted {
    // 全大写的强调词（FEWER、MORE）给语音合成时改成小写，免得被一个字母一个字母地念
    var speak = StoryText.spoken(t)
    let caps = try! NSRegularExpression(pattern: #"\b[A-Z]{3,}\b"#)
    for m in caps.matches(in: speak, range: NSRange(speak.startIndex..., in: speak)).reversed() {
        let r = Range(m.range, in: speak)!
        speak.replaceSubrange(r, with: speak[r].lowercased())
    }
    manifest.append(["file": fileName(t), "text": t, "speak": speak])
}
manifest.sort { $0["file"]! < $1["file"]! }
let mdata = try! JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
try! mdata.write(to: URL(fileURLWithPath: root + "/tools/voice/manifest_en.json"))

let total = bank.values.reduce(0) { $0 + $1.count }
print("levels \(bank.count), problems \(total), voice lines \(manifest.count), issues \(issues)")
