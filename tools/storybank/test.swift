// 「加减乘除」逻辑的命令行测试：zsh tools/storybank/test.sh
// 1. 关的编号和老存档：大挑战前面插进两章以后，老存档里 22~24 号（大挑战）的星星、最好成绩、解锁、错题一样不差；
//    升级跑两遍和跑一遍一样；随便造的几百个老存档，1~24 号每一关开没开着都和升级前一样。
// 2. 先选算式：题库里每道读题关的题都能判对判错，提示按题型来。
// 3. 练一练：挑最弱的题型、只从开着的关里挑、尽量挑没拿过星星的、不重复。
import Foundation

let root = CommandLine.arguments[1]
var failures = 0
func expect(_ ok: Bool, _ msg: @autoclosure () -> String) {
    if !ok { failures += 1; print("  ✗", msg()) }
}

let bankData = try Data(contentsOf: URL(fileURLWithPath: root + "/RanranGame/Content/story_bank.json"))
let bank = try JSONDecoder().decode([String: [StoryProblem]].self, from: bankData)

// MARK: - 1. 关的编号和老存档

print("1. level identity and old saves")

/// 升级前的规则（照抄改之前的代码）：编号就是位置，每章三关，第 8 章是大挑战
enum Old {
    static func chapter(_ n: Int) -> Int { (n - 1) / 3 + 1 }
    static func mode(_ n: Int) -> StoryMode {
        let i = (n - 1) % 3
        if chapter(n) == 8 { return i == 0 ? .model : .read }
        return [.act, .model, .read][i]
    }
    static func cap(_ n: Int) -> Int {
        let i = (n - 1) % 3
        if chapter(n) == 8 { return [20, 50, 100][i] }
        return mode(n) == .act ? 10 : 20
    }
    static func unlocked(_ s: PlayerStore, _ n: Int) -> Bool {
        n == 1 || n <= s.count("wp.open") || s.count("wp.best.\(n - 1)") >= 2
    }
}

let oldChapterTitles = ["Altogether", "Part & Whole", "How Many More?", "More or Fewer?", "Giving",
                        "Equal Groups", "Sharing", "Challenge"]
for n in StoryLevel.legacy {
    let l = StoryLevel(n)
    expect(l.chapter.title == oldChapterTitles[Old.chapter(n) - 1], "L\(n) chapter \(l.chapter.title)")
    expect(l.mode == Old.mode(n), "L\(n) mode \(l.mode) ≠ \(Old.mode(n))")
    expect(l.cap == Old.cap(n), "L\(n) cap \(l.cap) ≠ \(Old.cap(n))")
    expect(l.problemCount == Old.mode(n).problemCount, "L\(n) problem count")
    expect(l.indexInChapter == (n - 1) % 3, "L\(n) index in chapter")
    expect(bank["\(n)"]?.count == 3 * l.problemCount, "bank L\(n) has \(bank["\(n)"]?.count ?? 0)")
}
expect(StoryLevel.all.count == 30 && Set(StoryLevel.all.map(\.number)) == Set(1...30), "30 distinct levels")
expect(StoryLevel.all.map(\.position) == Array(1...30), "positions 1...30 in order")
for ch in StoryChapter.allCases { expect(ch.levels.count == 3, "\(ch) has \(ch.levels.count) levels") }
expect(StoryChapter.challenge.levels.map(\.number) == [22, 23, 24], "challenge keeps 22-24")
expect(StoryChapter.challenge.levels.map(\.position) == [28, 29, 30], "challenge shown as 28-30")
expect(StoryLevel(22).previous?.number == 30 && StoryLevel(21).next?.number == 25, "order 21 → 25 … 30 → 22")
for l in StoryLevel.all where !StoryLevel.legacy.contains(l.number) {
    expect(bank["\(l.number)"]?.count == 3 * l.problemCount, "bank L\(l.number) has \(bank["\(l.number)"]?.count ?? 0)")
}

/// 一个老存档里能看到的一切（按关的编号）
struct Snapshot: Equatable {
    var stars: [Int: Int] = [:], best: [Int: Int] = [:], passed: [Int: Bool] = [:], unlocked: [Int: Bool] = [:]
    var hasStar: [String: Bool] = [:]
    var total = 0, totalStars = 0
    var openMistakes: [Int] = []
    var mistakeLevels: [String] = []
}

func oldView(_ s: PlayerStore, _ got: [(Int, StoryProblem)]) -> Snapshot {
    var v = Snapshot()
    for n in StoryLevel.legacy {
        v.stars[n] = s.count("wp.stars.\(n)")
        v.best[n] = s.count("wp.best.\(n)")
        v.passed[n] = s.count("wp.best.\(n)") >= 2
        v.unlocked[n] = Old.unlocked(s, n)
    }
    for (n, p) in got { v.hasStar["\(n)/\(p.starKey(level: n))"] = s.count("wp.got." + p.starKey(level: n)) > 0 }
    v.total = StoryLevel.legacy.reduce(0) { $0 + s.count("wp.stars.\($1)") }
    v.totalStars = s.totalStars
    v.openMistakes = s.storyMistakes.filter { !$0.fixed }.map(\.level)
    v.mistakeLevels = s.storyMistakes.map { "\($0.level):\(oldChapterTitles[Old.chapter($0.level) - 1])" }
    return v
}

func newView(_ s: PlayerStore, _ got: [(Int, StoryProblem)]) -> Snapshot {
    var v = Snapshot()
    for n in StoryLevel.legacy {
        let l = StoryLevel(n)
        v.stars[n] = s.storyStars(l)
        v.best[n] = s.storyBest(l)
        v.passed[n] = s.storyPassed(l)
        v.unlocked[n] = s.storyUnlocked(l, unlockAll: false)
    }
    for (n, p) in got {
        // storyHasStar 在关满星时也算拿过；这里只比"这道题记没记着"
        v.hasStar["\(n)/\(p.starKey(level: n))"] = s.count("wp.got." + p.starKey(level: n)) > 0
            && s.storyHasStar(p, level: StoryLevel(n))
    }
    v.total = s.storyStarTotal
    v.totalStars = s.totalStars
    v.openMistakes = s.storyMistakes.filter { !$0.fixed }.map(\.level)
    v.mistakeLevels = s.storyMistakes.map { "\($0.level):\(StoryLevel($0.level).chapter.title)" }
    return v
}

/// 造一个升级前的存档
func oldStore(open: Int?, best: [Int: Int], stars: [Int: Int], got: [(Int, StoryProblem)], mistakes: [Int]) -> PlayerStore {
    let s = PlayerStore()
    if let open { s.c["wp.open"] = open; s.c["wp.v2"] = 1 }
    for (n, b) in best { s.c["wp.best.\(n)"] = b }
    for (n, k) in stars { s.c["wp.stars.\(n)"] = k; s.totalStars += k }
    for (n, p) in got { s.c["wp.got." + p.starKey(level: n)] = 1 }
    for n in mistakes { s.storyMistakes.append(StoryMistake(level: n, problem: bank["\(n)"]![0], answer: 1)) }
    s.totalStars += 7 // 别的游戏的星星
    return s
}

let challengeGot: [(Int, StoryProblem)] = [22, 23, 24].flatMap { n in bank["\(n)"]!.prefix(5).map { (n, $0) } }
    + [(21, bank["21"]![0]), (3, bank["3"]![1])]
let scenarios: [(String, PlayerStore)] = [
    ("challenge open via wp.open, stars and mistakes on 22-24",
     oldStore(open: 23, best: [21: 2, 22: 3, 23: 2, 24: 1], stars: [21: 9, 22: 12, 23: 20, 24: 5, 3: 4],
              got: challengeGot, mistakes: [22, 23, 24, 24, 5])),
    ("22 open only because 21 is passed",
     oldStore(open: 4, best: [1: 3, 2: 2, 3: 2, 21: 2], stars: [21: 8, 22: 0],
              got: [(21, bank["21"]![0])], mistakes: [21])),
    ("22 locked (21 not passed)",
     oldStore(open: 21, best: [21: 1], stars: [21: 3], got: [], mistakes: [])),
    ("pre-rework save (no wp.v2) that played up to 23",
     oldStore(open: nil, best: [22: 1, 23: 1], stars: [22: 4, 23: 2], got: Array(challengeGot.prefix(6)), mistakes: [23])),
    ("empty save", oldStore(open: 0, best: [:], stars: [:], got: [], mistakes: [])),
]
for (name, s) in scenarios {
    if s.count("wp.v2") == 0 {
        // 升级前那一版自己也会先跑 v2（记下 wp.open），所以"升级前"的样子要在它跑完以后看
        s.c["wp.open"] = StoryLevel.legacy.filter { s.count("wp.best.\($0)") >= 1 || s.count("wp.stars.\($0)") > 0 }.max() ?? 0
        s.c["wp.v2"] = 1
    }
    let before = oldView(s, challengeGot)
    s.migrateStoryProgress()
    let once = s.c, onceTotal = s.totalStars
    let after = newView(s, challengeGot)
    s.migrateStoryProgress()
    expect(s.c == once && s.totalStars == onceTotal, "\(name): second migration changed something")
    expect(after == before, "\(name): differs after migration\n    before \(before)\n    after  \(after)")
    let l22 = s.storyUnlocked(StoryLevel(22), unlockAll: false), l25 = s.storyUnlocked(StoryLevel(25), unlockAll: false)
    print("  · \(name): 22 open \(l22), new chapter (25) open \(l25), stars \(after.total), total \(after.totalStars), keys \(s.c.count) — same before/after")
}

// 随便造 500 个老存档：1~24 号每一关开没开着、星星、成绩都和升级前一样；升级两遍不变
var rng = StoryRNG(seed: 42)
for _ in 0..<500 {
    let s = PlayerStore()
    s.c["wp.v2"] = 1
    s.c["wp.open"] = Int.random(in: 0...24, using: &rng)
    for n in StoryLevel.legacy where Bool.random(using: &rng) { s.c["wp.best.\(n)"] = Int.random(in: 1...3, using: &rng) }
    for n in StoryLevel.legacy where Bool.random(using: &rng) {
        let k = Int.random(in: 0...StoryLevel(n).maxStars, using: &rng); s.c["wp.stars.\(n)"] = k; s.totalStars += k
    }
    let before = oldView(s, [])
    s.migrateStoryProgress()
    let once = s.c
    let after = newView(s, [])
    s.migrateStoryProgress()
    expect(after == before && s.c == once, "random save differs: \(s.c)")
}
// 新玩家：过了 21 号只开第 22 关（"Numbers to 100" 第一关），大挑战要等两步题那一章过完
do {
    let s = PlayerStore()
    s.migrateStoryProgress()
    for n in 1...21 { s.c["wp.best.\(n)"] = 2 }
    expect(s.storyUnlocked(StoryLevel(25), unlockAll: false) && !s.storyUnlocked(StoryLevel(22), unlockAll: false),
           "new player: 21 passed → 25 open, 22 still locked")
    s.c["wp.best.30"] = 2
    expect(s.storyUnlocked(StoryLevel(22), unlockAll: false), "new player: 30 passed → 22 open")
    expect(s.storyRecommended(unlockAll: false).number == 25, "recommended after 21 is 25")
}
print("  migration checks done")

// MARK: - 2. 先选算式

print("2. operation choice")
var withChoice = 0, readProblems = 0
var nudgeBySchema: [StorySchema: Set<String>] = [:]
for l in StoryLevel.all where l.mode == .read {
    for p in bank["\(l.number)"]! {
        readProblems += 1
        guard let ch = p.choice, let key = p.keyCalc else {
            expect([.transfer, .equalize].contains(p.schema) || StoryLevel.legacy.contains(l.number),
                   "L\(l.number) \(p.schema) read problem without a choice: \(p.explain)")
            continue
        }
        withChoice += 1
        expect((2...3).contains(ch.options.count), "option count \(ch.options.count)")
        expect(ch.options.filter { $0 == key.calc }.count == 1, "exactly one right option")
        expect(ch.options[ch.correct] == key.calc && ch.options[ch.correct].isRight, "correct index")
        expect(p.choice == ch, "choice order is stable")
        // 选错的那几个真的是另一种算法，算出来的也不是答案
        for (i, o) in ch.options.enumerated() where i != ch.correct {
            expect(o.op != key.calc.op && o.isRight, "wrong option \(o.blank) for \(key.calc.blank)")
            if !key.first { expect(o.result != p.answer, "wrong option gives the answer: \(o.blank)") }
        }
        nudgeBySchema[p.schema, default: []].insert(p.choiceNudge)
        expect(StoryVoiceLines.all.contains(p.choiceNudge), "nudge is a recorded line")
        if key.first { expect(p.choiceNudge == StoryVoiceLines.nudgeFirst, "two-step nudge") }
        if p.schema == .combine { expect(p.choiceNudge == StoryVoiceLines.nudgeAltogether, "combine nudge") }
        if p.schema == .inverse {
            expect(p.choiceNudge == (key.calc.op == "+" ? StoryVoiceLines.nudgeIsMore : StoryVoiceLines.nudgeIsLess), "inverse nudge")
        }
    }
}
// 选算式的统计：第一下对 / 错分开记，按题型
do {
    let s = PlayerStore()
    s.recordStoryChoice(.inverse, correct: false)
    s.recordStoryChoice(.inverse, correct: true)
    s.recordStoryChoice(.compare, correct: true)
    expect(s.storyChoiceStats(.inverse) == (1, 1) && s.storyChoiceStats(.compare) == (1, 0), "choice stats per schema")
    expect(s.storyStats(.inverse) == (0, 0), "choice stats are separate from answer stats")
}
print("  \(withChoice) of \(readProblems) read-level problems ask 'What do we do?'; nudges: "
      + nudgeBySchema.keys.map(\.rawValue).sorted().map { "\($0) \(nudgeBySchema[StorySchema(rawValue: $0)!]!.count)" }.joined(separator: ", "))

// 十和一：100 以内那一章的画图关每道题都能数十和一
for id in [25, 26] {
    for p in bank["\(id)"]! {
        expect(p.tensOnes != nil && p.tensOnes!.isRight && p.tensOnes!.result == p.answer, "tens and ones for L\(id): \(p.explain)")
    }
}

// MARK: - 3. 练一练

print("3. practice mix")
func pool(_ levels: [StoryLevel]) -> [StoryMix.Entry] {
    levels.flatMap { l in bank["\(l.number)"]!.map { StoryMix.Entry(level: l, problem: $0) } }
}
let open = Array(StoryLevel.all.prefix(12)) // 前四章开着
let p12 = pool(open)
let stats: (StorySchema) -> (right: Int, wrong: Int, opWrong: Int) = { s in
    switch s {
    case .inverse:   (2, 8, 3)   // 最弱
    case .partWhole: (5, 4, 0)   // 第二弱
    default:         (20, 1, 0)
    }
}
var r1 = StoryRNG(seed: 7)
let pick = StoryMix.pick(pool: p12, stats: stats, hasStar: { _ in false }, using: &r1)!
expect(pick.entries.count == 8, "8 problems")
expect(pick.focus == [.inverse, .partWhole], "focus \(pick.focus)")
expect(pick.entries.filter { $0.problem.schema == .inverse }.count >= 3, "at least 3 of the weakest type")
expect(pick.entries.filter { $0.problem.schema == .partWhole }.count >= 2, "at least 2 of the second weakest")
expect(Set(pick.entries.map { $0.problem.starKey(level: $0.level.number) }).count == 8, "no repeats")
expect(pick.entries.allSatisfy { e in open.contains(e.level) }, "only unlocked levels")
expect(pick.tricky && StoryMix.headline(pick) == "More practice: Who has more? and Find the part", "headline \(StoryMix.headline(pick))")
print("  · \(StoryMix.headline(pick)) — \(StoryMix.reason(pick))")
print("    picked: " + pick.entries.map { "L\($0.level.position) \($0.problem.schema.rawValue)" }.joined(separator: ", "))
// 同一个种子挑出来一样（可复现）
var r2 = StoryRNG(seed: 7)
let again = StoryMix.pick(pool: p12, stats: stats, hasStar: { _ in false }, using: &r2)!
expect(again.entries == pick.entries, "same seed, same mix")
// 拿过星星的往后放：只有两道 inverse 没拿过星星，这两道一定被挑中
let inv = p12.filter { $0.problem.schema == .inverse }
let fresh = Set(inv.prefix(2).map { $0.problem.starKey(level: $0.level.number) })
var r3 = StoryRNG(seed: 9)
let starred = StoryMix.pick(pool: p12, stats: stats, hasStar: { !fresh.contains($0.problem.starKey(level: $0.level.number)) }, using: &r3)!
expect(fresh.isSubset(of: Set(starred.entries.map { $0.problem.starKey(level: $0.level.number) })), "unstarred problems first")
// 什么都没做过：每种都一样弱，照样挑满 8 道，说"混着练"
var r4 = StoryRNG(seed: 3)
let blank = StoryMix.pick(pool: pool(Array(StoryLevel.all.prefix(3))), stats: { _ in (0, 0, 0) }, hasStar: { _ in false }, using: &r4)!
expect(blank.entries.count == 8 && !blank.tricky, "fresh player mix")
expect(StoryMix.pick(pool: [], stats: stats, hasStar: { _ in false }, using: &r4) == nil, "empty pool → no mix")
// 星星记在题自己的那一关
do {
    let s = PlayerStore()
    let e = pick.entries[0]
    expect(s.collectStoryStar(e.problem, level: e.level) && s.storyStars(e.level) == 1 && s.storyStarTotal == 1,
           "a mix star lands on the problem's own level")
    expect(!s.collectStoryStar(e.problem, level: e.level), "and only once")
}

print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
