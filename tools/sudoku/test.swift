import Foundation

// 数独的命令行测试：zsh tools/sudoku/test.sh
//   1. 解题器：随机盘面合法、数解的个数对、经典题解得出来、每一步"能确定"的都和答案一致
//   2. 关卡：每一关只有一个解、只用这一组允许的几招就能解完、组内难度不降、没有重复（换数字 / 换行列 / 翻转以后也不算）、
//      id 和题目不变（校验和）
//   3. 教学：每一课 4–8 步、至少 2 道题；每道题按 SudokuLessonLogic 都有答案（"随便填一个"的题每一种填法都往下走一遍），
//      提示讲的那一招确实能想出答案、提示里说的行列宫对得上；练习的每一段 × 每一种变换都还有答案，说法跟着规则变
//   4. 配音：固定台词和 tools/voice/extra_sudoku.json 一模一样；多音字有修正；练习说法不提位置

setvbuf(stdout, nil, _IONBF, 0)
let root = CommandLine.arguments[1]
var failures = 0
var checks = 0

func expect(_ ok: Bool, _ msg: @autoclosure () -> String) {
    checks += 1
    if !ok { failures += 1; print("  ❌ " + msg()) }
}

func section(_ name: String) { print("[\(name)]") }

// MARK: - 1. 解题器

section("解题器")
var rng = SudokuRNG(seed: 2024)
for n in SudokuGrid.sizes {
    for _ in 0..<25 {
        let g = SudokuSolver.randomSolution(n: n, using: &rng)
        expect(g.isSolved, "random \(n)x\(n) solution is valid")
        expect(SudokuSolver.countSolutions(g) == 1, "a full grid has one solution")
        // 每个变换都保持合法
        for k in 0..<8 {
            let t = SudokuTransform.variant(n: n, k: k)
            expect(t.grid(g).isSolved, "transform \(k) keeps a \(n)x\(n) solution valid")
        }
    }
}
expect(SudokuSolver.countSolutions(SudokuGrid(n: 4), limit: 1000) == 288, "there are 288 4x4 sudoku grids")
let classic = SudokuGrid(spec: "9:53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79")!
let classicSol = "9:534678912672195348198342567859761423426853791713924856961537284287419635345286179"
expect(SudokuSolver.solve(classic)?.spec == classicSol, "classic puzzle solves to the known answer")
expect(SudokuSolver.countSolutions(classic) == 1, "classic puzzle has one solution")
let classicTrace = SudokuSolver.logicSolve(classic)
expect(classicTrace.solved, "classic puzzle is solvable with singles")
var replay = classic
for m in classicTrace.steps { replay[m.cell] = m.value }
expect(replay.spec == classicSol, "logic steps reproduce the answer")
expect(SudokuSolver.countSolutions(SudokuGrid(spec: "9:" + String(repeating: ".", count: 81))!) == 2, "empty grid: many solutions")
// 两个解的题：一个"矩形"（两行两列四个格子，a b / b a）挖空就有两个解
do {
    var found = false
    let s = SudokuSolver.randomSolution(n: 9, using: &rng)
    outer: for r1 in 0..<9 { for r2 in (r1 + 1)..<9 where r1 / 3 == r2 / 3 {
        for c1 in 0..<9 { for c2 in (c1 + 1)..<9 where c1 / 3 != c2 / 3 {
            let a = s[r1 * 9 + c1], b = s[r1 * 9 + c2]
            if s[r2 * 9 + c1] == b, s[r2 * 9 + c2] == a {
                var g = s
                for i in [r1 * 9 + c1, r1 * 9 + c2, r2 * 9 + c1, r2 * 9 + c2] { g[i] = 0 }
                expect(SudokuSolver.countSolutions(g) == 2, "deadly rectangle has two solutions")
                expect(SudokuSolver.uniqueSolution(g) == nil, "uniqueSolution is nil when there are two")
                found = true
                break outer
            }
        } }
    } }
    if !found { print("  (no rectangle in this grid; skipped)") }
}
// 每一种"能确定"的步骤都和答案一致；clash 能找到重复
for n in SudokuGrid.sizes {
    for _ in 0..<15 {
        let sol = SudokuSolver.randomSolution(n: n, using: &rng)
        var g = sol
        for i in (0..<g.count).shuffled(using: &rng).prefix(g.count / 2) { g[i] = 0 }
        for m in SudokuSolver.moves(g) {
            expect(sol[m.cell] == m.value, "\(n)x\(n) move \(m.via) at \(g.name(m.cell)) agrees with the solution")
            expect(SudokuLessonLogic.supports(via: m.via, g, cell: m.cell, value: m.value), "move \(m.via) is supported")
        }
        var bad = sol
        let i = Int.random(in: 0..<bad.count, using: &rng)
        bad[i] = bad[i] % n + 1
        expect(bad.conflicts().contains(i), "a changed cell shows up as a conflict")
    }
}

// MARK: - 2. 关卡

section("关卡")
// 关卡数据定了就不能变：题目改了，存档里的星星就对不上了。真要加关卡，加新的组 / 新的 id，再更新这里。
let frozenChecksum = "8f6f19735fc5ac8b"
let frozenIDs = ["f4": 10, "n4": 12, "s6": 15, "e9": 15, "h9": 18]
let data = SudokuLevelData.puzzles
expect(sudokuChecksum(data) == frozenChecksum, "level data checksum \(sudokuChecksum(data)) matches the frozen one")
expect(SudokuCatalog.info.map(\.id) == ["f4", "n4", "s6", "e9", "h9"], "pack ids are stable")
expect(SudokuCatalog.passPacks == 4, "passPacks = through 九宫格·入门")
var allIDs: [String] = []
var prints: [String: String] = [:]
for (pi, p) in SudokuCatalog.info.enumerated() {
    let pack = SudokuCatalog.packs[pi]
    expect(pack.id == p.id && pack.levels == p.levels && pack.art == "pack_sudoku_\(p.id)", "\(p.id): PuzzlePack matches")
    expect(frozenIDs[p.id] == p.count, "\(p.id): level count is stable")
    expect(p.count <= 20, "\(p.id): at most 20 levels")
    var lastScore = -1.0
    var line: [String] = []
    for (k, id) in p.levels.enumerated() {
        allIDs.append(id)
        expect(id == "\(p.id)-\(k + 1)", "\(id): id format")
        guard let spec = data[id], let g = SudokuGrid(spec: spec) else { expect(false, "\(id): missing or unreadable"); continue }
        expect(g.n == p.n && g.fruit == p.fruit, "\(id): size and display match the pack")
        expect(g.conflicts().isEmpty, "\(id): givens don't clash")
        let sol = SudokuSolver.uniqueSolution(g)
        expect(sol != nil, "\(id): exactly one solution")
        let tr = SudokuSolver.logicSolve(g, allowed: p.allowed)
        expect(tr.solved, "\(id): solvable with \(p.allowed.map(\.rawValue).sorted()) only")
        var r = g
        for m in tr.steps { r[m.cell] = m.value }
        if let sol { expect(r == sol, "\(id): logic answer = the solution") }
        expect(tr.score >= lastScore, "\(id): difficulty \(Int(tr.score)) not below the previous level (\(Int(lastScore)))")
        lastScore = tr.score
        expect(SudokuCatalog.level(id)?.solution == sol, "\(id): catalog has the solution")
        let fp = sudokuFingerprint(g)
        if let other = prints[fp] { expect(false, "\(id) duplicates \(other) (up to symmetry)") }
        prints[fp] = id
        line.append("\(g.blankCount)")
        if p.id == "e9" { expect(g.count - g.blankCount >= 40, "\(id): 九宫格·入门 has at least 40 givens") }
    }
    print("  \(p.id) \(p.name): \(p.count) levels, blanks \(line.joined(separator: " "))")
}
expect(Set(allIDs).count == allIDs.count, "level ids are unique")
expect(Set(data.keys) == Set(allIDs), "no extra or missing level data")
// 后面的关卡一定要用上这一组新学的那一招（第几关起：更简单的几招解不完）
let needsNew: [(pack: String, from: Int, weaker: Set<SudokuTechnique>)] = [
    ("n4", 5, [.full]), ("s6", 4, [.full]), ("e9", 5, [.full]), ("h9", 10, [.full, .hidden]),
]
for r in needsNew {
    let p = SudokuCatalog.info.first { $0.id == r.pack }!
    for k in r.from...p.count {
        let g = SudokuGrid(spec: data["\(r.pack)-\(k)"]!)!
        expect(!SudokuSolver.logicSolve(g, allowed: r.weaker).solved, "\(r.pack)-\(k): needs more than \(r.weaker.map(\.rawValue).sorted())")
    }
}
// 前面的关卡一眼能看出来：四宫格·水果的第一关只有 3 个空格，九宫格·入门的第一关至少 48 个数
expect(SudokuGrid(spec: data["f4-1"]!)!.blankCount <= 4, "f4-1 is tiny")
expect(SudokuGrid(spec: data["e9-1"]!)!.blankCount <= 33, "e9-1 has at least 48 givens")
// 解锁规则：后一组要前一组过三分之二
for p in SudokuCatalog.packs { expect(PuzzleRules.needed(toOpenAfter: p) <= p.levels.count, "\(p.id): unlock threshold reachable") }

// MARK: - 3. 教学

section("教学")
let course = loadCourse(root, "sudoku")
let kit = TutorialKits.find("sudoku")
expect(kit != nil, "sudoku kit is registered")
expect(course.tracks.first?.id == "basic", "first track is basic")
expect(course.lessons.count >= 14, "at least 14 lessons (\(course.lessons.count))")
expect(Set(course.lessons.map(\.id)).count == course.lessons.count, "lesson ids are unique")
expect(course.tracks.count >= 3 && course.tracks.count <= 4, "3–4 tracks")
for t in course.tracks {
    expect(t.art == "tutor_sudoku_\(t.id)", "\(t.id): cover art name")
    if let n = kit?.playLevels[t.id] { expect(n >= 1 && n <= SudokuCatalog.packs.count, "\(t.id): playLevels in range") } else { expect(false, "\(t.id): playLevels missing") }
}
expect(kit?.goPlayLine == "这一组学完啦，去闯关吧！" && kit?.goPlayTitle == "去闯关", "go-play line and title")

let markKinds: Set<String> = ["row", "col", "box", "cell", "val", "cross", "ban", "notes"]
func checkMarks(_ marks: [String]?, _ g: SudokuGrid, _ where_: String) {
    for m in marks ?? [] {
        let p = m.split(separator: ":").map(String.init)
        guard let head = p.first, markKinds.contains(head) else { expect(false, "\(where_): unknown mark \(m)"); continue }
        switch head {
        case "row", "col", "box": expect(SudokuUnit(m).map(g.isValid) == true, "\(where_): bad mark \(m)")
        case "ban": expect(p.count == 3 && SudokuUnit("\(p[1]):\(p[2])").map(g.isValid) == true, "\(where_): bad mark \(m)")
        case "cell", "cross": expect(p.count == 2 && g.cell(named: p[1]) != nil, "\(where_): bad mark \(m)")
        case "val": expect(p.count == 2 && (Int(p[1]).map { $0 >= 1 && $0 <= g.n } ?? false), "\(where_): bad mark \(m)")
        case "notes":
            expect(p.count == 3 && g.cell(named: p[1]) != nil && p[2].allSatisfy { ($0.wholeNumberValue ?? 0) >= 1 && ($0.wholeNumberValue ?? 0) <= g.n },
                   "\(where_): bad mark \(m)")
        default: break
        }
    }
}

func kindWord(_ k: String) -> String? { SudokuUnit.Kind(rawValue: k).map { SudokuUnit($0, 0).word } }

/// 一段步骤从头走到尾；"随便填一个"的题，每一种填法都往下走（最多 maxPaths 条路）
var paths = 0
func walk(_ steps: [TutorialStep], from i: Int, grid: SudokuGrid?, name: String, lessonText: Bool) {
    guard i < steps.count else { paths += 1; return }
    let s = steps[i]
    var g = grid
    let here = "\(name) step \(i + 1)"
    if let b = s.board {
        g = SudokuGrid(spec: b)
        expect(g != nil, "\(here): unreadable board \(b)")
    }
    guard let grid = g else { expect(false, "\(here): no board"); return }
    checkMarks(s.marks, grid, here)
    guard let t = s.task else { walk(steps, from: i + 1, grid: grid, name: name, lessonText: lessonText); return }
    let rule = t.rule ?? ""
    let p = rule.split(separator: ":").map(String.init)
    let via = t.extra?["via"]
    if lessonText {
        expect(s.hint != nil, "\(here): task has a hint")
        // 提示里说的行 / 列 / 宫，要和这一招、这道题对得上
        let hint = s.hint ?? ""
        if let via {
            let vp = via.split(separator: ":").map(String.init)
            if vp.count == 2, let w = kindWord(vp[1]) { expect(hint.contains(w), "\(here): hint for \(via) mentions「\(w)」: \(hint)") }
            if vp.first == "naked" { expect(hint.contains("格子"), "\(here): naked-single hint talks about the cell: \(hint)") }
        }
        if ["missing", "oneBlank", "fullest"].contains(p.first ?? ""), p.count >= 2, let w = kindWord(p[1]) {
            expect(hint.contains(w), "\(here): hint for \(rule) mentions「\(w)」: \(hint)")
        }
    }
    switch SudokuLessonLogic.input(t) {
    case .fill:
        let ans = SudokuLessonLogic.fillAnswers(t, grid)
        expect(!ans.isEmpty, "\(here): \(rule) has an answer")
        var perCell: [Int: Set<Int>] = [:]
        for a in ans { perCell[a.cell, default: []].insert(a.value) }
        expect(perCell.values.allSatisfy { $0.count == 1 }, "\(here): each cell has one right value")
        if let via, let a = ans.first, p.first == "cell" {
            expect(SudokuLessonLogic.supports(via: via, grid, cell: a.cell, value: a.value),
                   "\(here): \(via) explains \(grid.name(a.cell)) = \(a.value)")
        }
        if p.first == "single" {
            // 至少有一个能用三招确定的格子（不能只靠猜）
            expect(!SudokuSolver.moves(grid).isEmpty, "\(here): something can be worked out")
        }
        let branches = p.first == "single" ? Array(ans.prefix(6)) : Array(ans.prefix(1))
        for a in branches where paths < 4000 {
            var next = grid
            next[a.cell] = a.value
            walk(steps, from: i + 1, grid: next, name: name, lessonText: lessonText)
        }
        return
    case .pick:
        let ans = SudokuLessonLogic.pickAnswers(t, grid)
        expect(!ans.isEmpty, "\(here): \(rule) has an answer")
        if p.first == "where", let via, let v = Int(p[1]), let c = ans.first {
            expect(ans.count == 1, "\(here): where has one cell")
            expect(SudokuLessonLogic.supports(via: via, grid, cell: c, value: v), "\(here): \(via) explains \(rule)")
            if let sol = SudokuSolver.uniqueSolution(grid) { expect(sol[c] == v, "\(here): where answer agrees with the solution") }
        }
        if p.first == "clash" { expect(ans.count < grid.count / 2, "\(here): clash is a small set") }
    case .value:
        let ans = SudokuLessonLogic.valueAnswers(t, grid)
        expect(ans.count == 1, "\(here): \(rule) has exactly one answer")
    case .cands:
        let ans = SudokuLessonLogic.candAnswers(t, grid)
        expect(!ans.isEmpty, "\(here): \(rule) has candidates")
    }
    walk(steps, from: i + 1, grid: grid, name: name, lessonText: lessonText)
}

let banned = ["左", "右", "上面", "下面", "上边", "下边", "往上", "往下", "横", "竖", "第", "上方", "下方"]
var practisable = 0, tasks = 0
for l in course.lessons {
    let taskSteps = l.steps.filter { $0.task != nil }
    tasks += taskSteps.count
    expect(taskSteps.count >= 2, "\(l.id): at least 2 tasks")
    expect(l.steps.count >= 4 && l.steps.count <= 8, "\(l.id): 4–8 steps (\(l.steps.count))")
    expect(l.steps.first?.board != nil, "\(l.id): starts with a board")
    expect(!l.learned.isEmpty, "\(l.id): has learned")
    paths = 0
    walk(l.steps, from: 0, grid: nil, name: l.id, lessonText: true)
    // 练一练：每一段 × 每一种变换
    for (si, seg) in LessonPractice.segments(l, game: "sudoku").enumerated() {
        practisable += LessonPractice.taskCount(seg)
        for k in 0..<(kit?.practiceVariants ?? 1) {
            let v = k == 0 ? seg : (kit?.practiceTransform?(seg, k) ?? seg)
            expect(v.count == seg.count && v.first?.board != nil, "\(l.id) practice \(si + 1)#\(k): shape")
            for (j, s) in v.enumerated() {
                expect(s.hint == nil && s.ok == nil, "\(l.id) practice: lesson text removed")
                if s.drill == nil, let r = s.task?.rule {
                    expect(s.say == SudokuTutorial.prompt(for: r), "\(l.id) practice \(si + 1)#\(k) step \(j + 1): prompt follows rule \(r): \(s.say)")
                }
                for w in banned where s.say.contains(w) { expect(false, "\(l.id) practice: prompt mentions「\(w)」: \(s.say)") }
                expect(!s.say.contains(where: { $0.isASCII && $0.isNumber }), "\(l.id) practice: prompt mentions a number: \(s.say)")
            }
            paths = 0
            walk(v, from: 0, grid: nil, name: "\(l.id)~练习\(si + 1)~变换\(k)", lessonText: false)
        }
    }
}
print("  \(course.lessons.count) lessons, \(tasks) tasks, \(practisable) practisable")
// 规则的通用说法都在
for l in course.lessons { for s in l.steps { if let r = s.task?.rule, !r.hasPrefix("inUnit") {
    expect(SudokuTutorial.prompt(for: r) != nil, "\(l.id): rule \(r) has a practice prompt")
} } }
// 复习能出题
var rr = SudokuRNG(seed: 9)
var cups: [String: LessonCup] = [:]
for l in course.lessons { cups[l.id] = .bronze }
for _ in 0..<20 {
    let r = LessonPractice.reviewLesson(course, cups: cups, using: &rr)
    expect(r != nil && r!.steps.filter { $0.task != nil }.count == 5, "review has 5 tasks")
}

// MARK: - 4. 配音

section("配音")
let extraURL = URL(fileURLWithPath: root + "/tools/voice/extra_sudoku.json")
let extra = try! JSONSerialization.jsonObject(with: Data(contentsOf: extraURL)) as! [String: Any]
let extraLines = extra["lines"] as? [String] ?? []
expect(extraLines == SudokuTutorial.kit.fixedLines, "extra_sudoku.json lines = SudokuTutorial.kit.fixedLines")
expect(Set(SudokuTutorial.prompts.values).isSubset(of: Set(SudokuTutorial.kit.fixedLines)), "practice prompts are recorded")
for line in SudokuTutorial.prompts.values {
    for w in banned where line.contains(w) { expect(false, "prompt mentions「\(w)」: \(line)") }
}
let replace = (extra["replace"] as? [[String]]) ?? []
let regex = (extra["regex"] as? [[String]]) ?? []
func spoken(_ t: String) -> String {
    var s = t
    for r in replace where r.count == 2 { s = s.replacingOccurrences(of: r[0], with: r[1]) }
    for r in regex where r.count == 2 { s = s.replacingOccurrences(of: r[0], with: r[1], options: .regularExpression) }
    return s
}
var voiced: [String] = SudokuTutorial.kit.fixedLines
for l in course.lessons {
    voiced.append(TutorLines.lessonDone(l.learned))
    for s in l.steps { voiced += [s.say, s.hint, s.ok, s.after, s.drill].compactMap { $0 } }
}
// 会读错的词：这些意思的字在数独的话里不该出现（行只当"一行"用，数只读 shù）
let risky = ["不行", "行不", "进行", "行走", "银行", "可行", "数一数", "数数", "往下数", "往右数", "数出", "长大", "还给"]
for t in Set(voiced) {
    for w in risky where t.contains(w) { expect(false, "risky reading「\(w)」in: \(t)") }
    let s = spoken(t)
    expect(!s.contains("行"), "行 is respelled for háng: \(t) → \(s)")
    expect(!s.contains("重复"), "重复 is respelled for chóng: \(t) → \(s)")
    expect(!s.contains("空格") && !s.contains("空着"), "空 in 空格 / 空着 is respelled for kòng: \(t) → \(s)")
    expect(TutorLines.common.contains(t) || s == t || !TutorLines.common.contains(t), "")
}
// 通用台词不能被数独的读音修正改掉（清单里先收的是数独这边）
for t in TutorLines.common where Set(voiced).contains(t) { expect(spoken(t) == t, "common line changed by sudoku fixes: \(t)") }
print("  \(Set(voiced).count) sudoku lines")

print("\(checks) checks, \(failures) failed")
if failures == 0 { print("ALL PASSED") } else { exit(1) }
