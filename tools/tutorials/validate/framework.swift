import Foundation

// 教学框架本身：对称变换、练习 / 复习出题、小奖杯、解锁不倒退、练习说法不提方向。

let root = CommandLine.arguments[1]
var problems = 0
func flag(_ s: String) { problems += 1; print("  ❌ " + s) }
func expect(_ ok: Bool, _ what: String) { if !ok { flag(what) } }

struct SplitMix: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: 对称变换

print("[对称变换]")
for size in [9, 13, 19] {
    let names = (0..<size).flatMap { y in (0..<size).map { x in "\(Character(UnicodeScalar(UInt8(97 + x))))\(y + 1)" } }
    for sym in LessonSymmetry.all("go", size: size) {
        let mapped = names.compactMap(sym.square)
        expect(mapped.count == names.count && Set(mapped).count == names.count, "size \(size) kind \(sym.kind) is not a bijection")
    }
    // 8 种变换互不相同
    let images = LessonSymmetry.all("gomoku", size: size).map { s in ["b1", "a3", "c2"].compactMap(s.square) }
    expect(Set(images.map { $0.joined() }).count == 8, "size \(size): the 8 transforms are not all different")
}
let xs = LessonSymmetry.all("xiangqi", size: 9)
expect(xs.count == 2, "xiangqi should only mirror")
expect(xs[1].square("a0") == "i0" && xs[1].square("e9") == "e9" && xs[1].square("h2") == "b2", "xiangqi mirror squares")
expect(xs[1].token("h2e2") == "b2e2", "xiangqi move token")
expect(xs[1].spec("h9g7|b9c7") == "b9c7|h9g7", "xiangqi reply alternatives")
for fen in [XBoard.start, "3akab2/9/4b4/p3p3p/2p6/9/P1P5P/1C2B1N2/4A4/2BAK1R2 w"] {
    let m = xs[1].board(fen)
    expect(xs[1].board(m) == fen, "FEN mirror twice is not identity: \(fen)")
    if let a = XBoard(fen: fen), let b = XBoard(fen: m) {
        for x in 0..<9 { for y in 0..<10 { expect(a[x, y] == b[8 - x, y], "FEN mirror moves a piece wrongly at \(x),\(y)") } }
        expect(a.turn == b.turn, "FEN mirror keeps side to move")
    } else { flag("mirrored FEN does not parse: \(m)") }
}
let g = LessonSymmetry(game: "go", size: 9, kind: 4) // 沿对角线翻转
expect(g.board("size=9;b=c3,d4;w=e5;turn=w") == "size=9;b=c3,d4;w=e5;turn=w", "diagonal keeps diagonal points")
expect(g.board("size=9;b=a2;w=b9") == "size=9;b=b1;w=i2", "diagonal flips points")
expect(g.spec("connect:a2:b9") == "connect:b1:i2" && g.spec("capture:2") == "capture:2" && g.spec("label:a2:A") == "label:b1:A", "rule / mark args")
expect(LessonSymmetry(game: "gomoku", size: 9, kind: 1).spec("winIn:2") == "winIn:2", "winIn count is not a point")

// MARK: 小奖杯

print("[小奖杯]")
expect(LessonCup.earned(tasks: 4, firstTry: 4) == .gold, "4/4 gold")
expect(LessonCup.earned(tasks: 4, firstTry: 3) == .silver, "3/4 silver")
expect(LessonCup.earned(tasks: 4, firstTry: 2) == .bronze, "2/4 bronze")
expect(LessonCup.earned(tasks: 3, firstTry: 2) == .silver, "2/3 silver")
expect(LessonCup.earned(tasks: 1, firstTry: 0) == .bronze, "0/1 bronze")
expect(LessonCup.earned(tasks: 0, firstTry: 0) == .gold, "no tasks gold")
do {
    let s = PlayerStore()
    expect(s.lessonCup("gomoku", "g1") == nil, "not done → no cup")
    s.markLessonDone("gomoku", "g1") // 老存档：学完了，没有奖杯记录
    expect(s.lessonCup("gomoku", "g1") == .bronze, "old save → bronze")
    expect(s.recordLesson("gomoku", "g1", cup: .silver), "silver improves bronze")
    expect(!s.recordLesson("gomoku", "g1", cup: .bronze), "bronze does not improve silver")
    expect(s.lessonCup("gomoku", "g1") == .silver, "best kept")
    s.recordLesson("gomoku", "g1", cup: .gold)
    s.recordLesson("gomoku", "g1", cup: .silver)
    expect(s.lessonCup("gomoku", "g1") == .gold, "gold stays")
    expect(s.count("tutor.gomoku.g1") == 5, "every finish counted")
    s.recordPractice("gomoku", "g1")
    expect(s.practiceCount("gomoku", "g1") == 1 && s.lessonCup("gomoku", "g1") == .gold, "practice does not touch cups")
    expect(s.daysSinceReview("gomoku") == nil, "never reviewed")
    s.recordReview("gomoku")
    expect(s.daysSinceReview("gomoku") == 0 && s.reviewCount("gomoku") == 1, "reviewed today")
    expect(!s.counts.keys.contains { $0.contains("stars") }, "lesson cups never touch star keys")
}

// MARK: 解锁不倒退

print("[解锁]")
do {
    var course = loadCourse(root, "gomoku")
    let s = PlayerStore()
    expect(s.trackUnlocked(course, 0) && !s.trackUnlocked(course, 1), "fresh: only the first track")
    for l in course.tracks[0].lessons { s.markLessonDone("gomoku", l.id) }
    expect(s.trackUnlocked(course, 1) && !s.trackUnlocked(course, 2), "track 1 opens after track 0")
    s.rememberOpenTracks(course)
    // 内容更新：第一组多了一课
    var extra = course.tracks[0].lessons[0]
    extra.id = "g_new"
    course.tracks[0].lessons.append(extra)
    expect(!s.trackDone(course, course.tracks[0]), "new lesson makes track 0 unfinished")
    expect(s.trackUnlocked(course, 1), "track 1 stays open after a lesson is added before it")
    expect(s.nextLesson(course)?.id == "g_new" || s.nextLesson(course) != nil, "next lesson exists")

    // 老存档：只有后面一组里有学完的课（没有 open 记录）
    let s2 = PlayerStore()
    s2.markLessonDone("gomoku", course.tracks[2].lessons[0].id)
    expect(s2.trackUnlocked(course, 1) && s2.trackUnlocked(course, 2) && !s2.trackUnlocked(course, 3),
           "a finished lesson opens its track and all before it")
}

// MARK: 练习、复习

print("[练习 / 复习]")
let banAll = ["左", "右"]
let banSquare = ["横", "竖", "上面", "下面", "上边", "下边", "往上", "往下", "上方", "下方", "上下"]
var rng = SplitMix(state: 7)
for game in ["gomoku", "xiangqi", "go"] {
    let course = loadCourse(root, game)
    var tasks = 0, practisable = 0
    var unknownRules = Set<String>()
    var skipped: [String] = []
    for l in course.lessons {
        let segs = LessonPractice.segments(l, game: game)
        let inSegs = segs.reduce(0) { $0 + LessonPractice.taskCount($1) }
        practisable += inSegs
        for (i, s) in l.steps.enumerated() where s.task != nil {
            tasks += 1
            if LessonPractice.prompt(s, game: game) == nil {
                skipped.append("\(l.id)#\(i + 1)")
                if let r = s.task?.rule, r != "any", s.drill == nil { unknownRules.insert(r) }
            }
            if let d = s.drill {
                for w in banAll + (game == "xiangqi" ? [] : banSquare) where d.contains(w) {
                    flag("\(l.id) step \(i + 1) drill mentions a direction「\(w)」: \(d)")
                }
                if d.unicodeScalars.contains(where: { $0.value >= 65 && $0.value <= 90 }) {
                    flag("\(l.id) step \(i + 1) drill mentions a label letter: \(d)")
                }
            }
        }
        for seg in segs {
            expect(seg.first?.board != nil, "\(l.id): a practice segment starts without a board")
            for s in seg { expect(s.task != nil && s.hint == nil && s.ok == nil && s.after == nil, "\(l.id): practice step keeps lesson text") }
        }
        if let p = LessonPractice.practiceLesson(l, game: game, using: &rng) {
            expect(p.steps.count == inSegs, "\(l.id): practice lesson has every practisable task")
        }
    }
    for r in unknownRules.sorted() { print("  ⚠️ \(game): rule \(r) has no generic practice prompt (add a drill or a PracticePrompts entry)") }
    print("  \(game): \(practisable)/\(tasks) tasks practisable; skipped (no rule, no drill): \(skipped.joined(separator: " "))")

    var all: [String: LessonCup] = [:]
    for l in course.lessons { all[l.id] = .gold }
    for _ in 0..<40 {
        guard let r = LessonPractice.reviewLesson(course, cups: all, using: &rng) else { flag("\(game): no review lesson"); break }
        let n = r.steps.filter { $0.task != nil }.count
        expect(n == min(5, practisable), "\(game): review has \(n) tasks")
        expect(r.steps.first?.board != nil, "\(game): review starts without a board")
    }
    // 只学了一课：复习只从这一课里出
    if let first = course.lessons.first(where: { LessonPractice.canPractice($0, game: game) }) {
        let r = LessonPractice.reviewLesson(course, cups: [first.id: .bronze], using: &rng)
        expect(r != nil, "\(game): review from one lesson")
        let prompts = Set(LessonPractice.segments(first, game: game).flatMap { $0.map(\.say) })
        expect(r?.steps.allSatisfy { prompts.contains($0.say) } == true, "\(game): review draws only from finished lessons")
    }
    expect(LessonPractice.reviewLesson(course, cups: [:], using: &rng) == nil, "\(game): nothing finished → no review")
}

// MARK: 去下一盘

print("[去下一盘]")
for game in ["gomoku", "xiangqi", "go"] {
    let course = loadCourse(root, game)
    let levels = course.tracks.map { course.playLevel(after: $0) }
    expect(levels.allSatisfy { (1...10).contains($0) }, "\(game): levels in range")
    expect(levels == levels.sorted(), "\(game): later tracks never pick an easier level \(levels)")
    print("  \(game): " + zip(course.tracks, levels).map { "\($0.title)→\($1)档" }.joined(separator: "  "))
}

print(problems == 0 ? "ALL GOOD" : "PROBLEMS: \(problems)")
