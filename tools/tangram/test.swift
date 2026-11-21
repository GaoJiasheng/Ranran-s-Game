// 七巧板的命令行测试：zsh tools/tangram/test.sh
// 几何（面积、转和翻）、每个图形（七块、不重叠、连成一片、在格子上）、判断拼好没有（参考拼法和别的拼法都算对，差一点的都不算）、
// 吸附（吸到的位置是精确的）、关卡分组、教学（每道题和每种练习变换都有答案）、配音台词。
import Foundation

let root = CommandLine.arguments[1]
var failed = 0
var checks = 0
func check(_ ok: Bool, _ what: @autoclosure () -> String, line: Int = #line) {
    checks += 1
    if !ok { failed += 1; print("✗ \(what())  (test.swift:\(line))") }
}
func section(_ s: String) { print("[\(s)]") }

let r2 = 2.0.squareRoot()

// MARK: - 几何

section("几何")
let total = TangramKind.set.reduce(0.0) { $0 + TangramGeo.area(TangramPose(kind: $1).vertices) }
check(abs(total - 16) < 1e-12, "七块的面积加起来 = 16（大正方形边长 4），实际 \(total)")
for k in TangramKind.allCases {
    check(abs(TangramGeo.area(k.canonical) - k.area) < 1e-12, "\(k) 面积")
    for f in [false, true] {
        for r in 0..<8 {
            let p = TangramPose(kind: k, rotation: r, flipped: f, x: 1.5, y: -0.5 + r2)
            check(abs(TangramGeo.area(p.vertices) - k.area) < 1e-9, "\(k) r\(r) f\(f) 面积不变")
            for v in TangramPose.shape(k, rotation: r, flipped: f) {
                check(TangramNum.near(v.x) != nil && TangramNum.near(v.y) != nil, "\(k) r\(r) f\(f) 顶点在格子上")
            }
            var q = p
            for _ in 0..<8 { q = q.turned(1) }
            check(q.sameSpot(p), "\(k) 转 8 次回到原样")
            check(p.turned(4).turned(4).sameSpot(p), "\(k) 转两次半圈回到原样")
            check(p.mirrored().mirrored().sameSpot(p.normalized()), "\(k) 翻两次回到原样")
            check(p.centroid.distance(p.turned(3).centroid) < 1e-9, "\(k) 转的时候重心不动")
            check(p.centroid.distance(p.mirrored().centroid) < 1e-9, "\(k) 翻的时候重心不动")
            let n = p.normalized()
            if !k.chiral { check(!n.flipped && n.sameSpot(p), "\(k) 翻面等于转一下") }
        }
    }
}
// 平行四边形翻过来和任何一种转法都不一样
let pa = TangramPose(kind: .parallelogram)
check((0..<8).allSatisfy { r in
    let m = pa.mirrored()
    var q = pa
    q.rotation = r
    q.offset = .init(0, 0)
    q.offset = m.centroid - q.centroid
    return !q.sameSpot(m)
}, "平行四边形翻面以后转不回来")
check(TangramNum(3, -2).value == (3 - 2 * r2) / 2, "格子坐标的值")
check(TangramNum.near(TangramNum(7, -5).value) == TangramNum(7, -5), "找回格子坐标")

// MARK: - 图形

section("图形")
check(TangramFigure.all.count >= 40, "至少 40 个图形（现在 \(TangramFigure.all.count) 个）")
check(Set(TangramFigure.all.map(\.id)).count == TangramFigure.all.count, "图形 id 不重复")
for f in TangramFigure.all {
    let kinds = f.pieces.map(\.kind)
    check(f.pieces.count == 7, "\(f.id) 有 7 块")
    for k in TangramKind.allCases { check(kinds.filter { $0 == k }.count == k.count, "\(f.id) 的 \(k) 用了 \(kinds.filter { $0 == k }.count) 块") }
    let polys = f.polygons
    check(abs(polys.reduce(0) { $0 + TangramGeo.area($1) } - 16) < 1e-9, "\(f.id) 面积 16")
    for i in polys.indices { for j in polys.indices where j > i {
        check(TangramGeo.overlap(polys[i], polys[j]) < 1e-9, "\(f.id) 第 \(i + 1)、\(j + 1) 块重叠")
    } }
    // 连成一片：挨着（共边或者共点）的连起来
    var seen: Set<Int> = [0], stack = [0]
    while let i = stack.popLast() {
        for j in polys.indices where !seen.contains(j) && TangramGeo.touching(polys[i], polys[j]) { seen.insert(j); stack.append(j) }
    }
    check(seen.count == 7, "\(f.id) 连成一片")
    for v in polys.joined() { check(TangramNum.near(v.x) != nil && TangramNum.near(v.y) != nil, "\(f.id) 顶点在格子上 \(v)") }
    check(!f.name.isEmpty, "\(f.id) 有名字")
}

// MARK: - 判断拼好没有

section("判断")
var alternativesChecked = 0
let altURL = URL(fileURLWithPath: root + "/tools/tangram/alternatives.json")
let alternatives = (try? JSONSerialization.jsonObject(with: Data(contentsOf: altURL))) as? [String: [[String]]] ?? [:]
check(!alternatives.isEmpty, "alternatives.json 读得出来")
for f in TangramFigure.all {
    let ref = f.poses
    check(TangramChecker.solved(ref, target: ref), "\(f.id) 参考拼法算拼好")
    check(TangramChecker.solved(ref.reversed(), target: ref), "\(f.id) 顺序不影响")
    // 两个大三角互换、两个小三角互换（同种板子谁放哪里都一样）
    var swapped = ref
    for kind in [TangramKind.large, .small] {
        let idx = swapped.indices.filter { swapped[$0].kind == kind }
        swapped.swapAt(idx[0], idx[1])
    }
    check(TangramChecker.solved(swapped, target: ref), "\(f.id) 两个大三角、两个小三角互换也算对")
    // 别的拼法（solve.py 找出来的另外几种盖满影子的拼法）
    for alt in alternatives[f.id] ?? [] {
        let poses = alt.compactMap(TangramLessonBoard.decode)
        check(poses.count == 7, "\(f.id) 别的拼法读得出来")
        check(TangramChecker.solved(poses, target: ref), "\(f.id) 另一种拼法 \(alt.joined(separator: " ")) 也算对")
        alternativesChecked += 1
    }
    for i in ref.indices {
        // 差一点：挪一小格（半格、半个对角线）
        for d in [TangramPoint(0.5, 0), TangramPoint(0, -0.5), TangramPoint(r2 / 2, 0), TangramPoint(1e-3, 0)] {
            var near = ref
            near[i].offset = near[i].offset + d
            check(!TangramChecker.solved(near, target: ref), "\(f.id) 第 \(i + 1) 块挪了 \(d) 不该算对")
        }
        // 转了 45°
        var turned = ref
        turned[i] = turned[i].turned(1)
        check(!TangramChecker.solved(turned, target: ref), "\(f.id) 第 \(i + 1) 块转歪了不该算对")
        // 少一块
        var missing = ref
        missing.remove(at: i)
        check(!TangramChecker.solved(missing, target: ref), "\(f.id) 少了第 \(i + 1) 块不该算对")
        // 和别的板子叠在一起
        var stacked = ref
        stacked[i].offset = ref[(i + 1) % 7].offset
        stacked[i].rotation = ref[(i + 1) % 7].rotation
        if !stacked[i].sameSpot(ref[i]) {
            check(!TangramChecker.solved(stacked, target: ref), "\(f.id) 第 \(i + 1) 块叠到别的板子上不该算对")
        }
    }
    // 整个挪了一点
    let shifted = ref.map { p -> TangramPose in var q = p; q.offset = q.offset + TangramPoint(0.25, 0.25); return q }
    check(!TangramChecker.solved(shifted, target: ref), "\(f.id) 整个挪开了不该算对")
    // 换成别的图形
    if let other = TangramFigure.all.first(where: { $0.id != f.id }) {
        check(!TangramChecker.solved(other.poses, target: ref), "\(f.id) 用 \(other.id) 的拼法不该算对")
    }
}
print("  别的拼法：\(alternativesChecked) 种")
check(alternativesChecked >= 20, "至少验证 20 种别的拼法")

// MARK: - 吸附

section("吸附")
var snaps = 0
for f in TangramFigure.all {
    let ref = f.poses
    let target = f.polygons
    let anchors = TangramSnapper.anchors(target)
    for i in ref.indices {
        let others = ref.indices.filter { $0 != i }.map { ref[$0].vertices }
        for d in [TangramPoint(0.3, -0.2), TangramPoint(-0.45, 0.4), TangramPoint(0.1, 0.6)] {
            var p = ref[i]
            p.offset = p.offset + d
            let r = TangramSnapper.snap(p, anchors: anchors + TangramSnapper.anchors(others), target: target, others: others)
            check(r?.fits == true, "\(f.id) 第 \(i + 1) 块（\(ref[i].kind)）挪开 \(d) 能吸回去")
            if let r {
                var placed = ref
                placed[i] = r.pose
                check(TangramChecker.solved(placed, target: ref), "\(f.id) 第 \(i + 1) 块吸回去以后拼好了")
                check(TangramNum.near(r.pose.x) != nil && TangramNum.near(r.pose.y) != nil, "\(f.id) 吸到的位置在格子上")
                // 吸到的顶点和参考拼法里的某一块顶点完全重合（误差只有浮点的 1e-12）
                let exact = r.pose.vertices.allSatisfy { v in ref.contains { $0.vertices.contains { $0.distance(v) < 1e-9 } } }
                check(exact, "\(f.id) 吸到的位置是精确的")
                snaps += 1
            }
        }
        // 离得太远不吸
        var far = ref[i]
        far.offset = far.offset + TangramPoint(30, 30)
        check(TangramSnapper.snap(far, anchors: anchors, target: target, others: others) == nil, "\(f.id) 离得很远不吸")
    }
    // 空板子上放第一块：吸到的位置一定在影子里
    for k in Set(ref.map(\.kind)) {
        guard let c = ref.first(where: { $0.kind == k }) else { continue }
        var p = c
        p.offset = p.offset + TangramPoint(0.2, 0.2)
        if let r = TangramSnapper.snap(p, anchors: anchors, target: target, others: []), r.fits {
            check(TangramChecker.inside(r.pose.vertices, target: target), "\(f.id) 吸到的合适位置在影子里")
        }
    }
}
// 别的拼法里的位置也吸得到
for f in TangramFigure.all {
    for alt in alternatives[f.id] ?? [] {
        let poses = alt.compactMap(TangramLessonBoard.decode)
        for i in poses.indices {
            let others = poses.indices.filter { $0 != i }.map { poses[$0].vertices }
            var p = poses[i]
            p.offset = p.offset + TangramPoint(0.25, -0.3)
            let r = TangramSnapper.snap(p, target: f.polygons, others: others)
            check(r?.fits == true && r.map { $0.pose.sameSpot(poses[i]) } == true, "\(f.id) 别的拼法第 \(i + 1) 块吸得到")
        }
    }
}
print("  吸附：\(snaps) 次")

// MARK: - 关卡

section("关卡")
let packs = TangramCatalog.packs
check((3...5).contains(packs.count), "3–5 组")
check(Array(packs.map(\.id).prefix(4)) == Array(["start", "turn", "shadow", "master"].prefix(packs.count)), "组的 id")
check(TangramCatalog.passPacks >= 1 && TangramCatalog.passPacks <= packs.count, "passPacks 在范围里")
var used = Set<String>()
for (pi, p) in packs.enumerated() {
    check(p.levels.count >= 6 && p.levels.count <= 20, "\(p.id) 有 \(p.levels.count) 关（6–20）")
    check(p.art == "pack_tangram_\(p.id)", "\(p.id) 的图名")
    for l in p.levels {
        check(used.insert(l).inserted, "\(l) 只出现一次")
        guard let lv = TangramCatalog.level(l) else { check(false, "\(l) 没有这个图形"); continue }
        check(lv.pack == pi, "\(l) 在第 \(pi + 1) 组")
        check(lv.trayStart.map(\.kind) == TangramKind.set, "\(l) 托盘是一整套")
        if lv.preRotated {
            // 托盘里转好的板子直接平移就能拼好
            var refs = lv.figure.poses
            let placed = lv.trayStart.map { t -> TangramPose in
                let i = refs.firstIndex { $0.kind == t.kind && $0.rotation == t.rotation && $0.flipped == t.flipped }!
                return refs.remove(at: i)
            }
            check(TangramChecker.solved(placed, target: lv.figure.poses), "\(l) 转好的板子能直接拼")
        }
    }
}
check(TangramCatalog.level("start-nope") == nil, "没有的关卡")
print("  " + packs.map { "\($0.name) \($0.levels.count) 关" }.joined(separator: "，") + "；一共 \(used.count) 个图形用在关卡里")

// MARK: - 教学

section("教学")
let course = try! JSONDecoder().decode(TutorialCourse.self, from: Data(contentsOf: URL(fileURLWithPath: root + "/RanranGame/Tutorials/tangram.json")))
check(course.game == "tangram", "game")
check(course.tracks.first?.id == "basic", "第一组叫 basic")
check(course.tracks.count >= 3, "至少 3 组")
check(course.lessons.count >= 12, "至少 12 课（现在 \(course.lessons.count) 课）")
check(Set(course.lessons.map(\.id)).count == course.lessons.count, "课的 id 不重复")
let kit = TangramTutorial.kit
let banned = ["左", "右", "上面", "下面", "上边", "下边", "往上", "往下", "上方", "下方", "横", "竖", "顶上", "底下"]
for t in course.tracks {
    check(t.art == "tutor_tangram_\(t.id)", "\(t.id) 的封面图名")
    check(kit.playLevels[t.id] != nil, "\(t.id) 学完去第几组")
}

/// 一步的题有没有答案（board 是这一步看到的局面）
func solvable(_ s: TutorialStep, board: TangramLessonBoard, _ ctx: String) {
    guard let task = s.task else { return }
    switch task.type {
    case "fill":
        check(task.rule == "fill", "\(ctx) fill 题的 rule")
        guard let ans = TangramLessonLogic.answer(board) else { check(false, "\(ctx) 托盘里的板子和影子对不上"); return }
        check(TangramLessonLogic.filled(ans, board: board), "\(ctx) 标准答案能拼好")
        check(!board.tray.isEmpty, "\(ctx) 托盘里有板子")
        // 每一块都能从附近吸到答案的位置
        let target = board.target.map(\.vertices)
        for i in ans.indices {
            var p = ans[i]
            p.offset = p.offset + TangramPoint(0.3, 0.2)
            let others = board.fixed.map(\.vertices) + ans.indices.filter { $0 != i }.map { ans[$0].vertices }
            let r = TangramSnapper.snap(p, target: target, others: others)
            check(r?.fits == true, "\(ctx) 第 \(i + 1) 块能吸到答案")
        }
        // 托盘里的朝向不算答案：答案要么就是托盘里的朝向，要么转一转、翻一翻能得到
        for (t, a) in zip(board.tray, ans) {
            check(t.kind == a.kind, "\(ctx) 托盘配答案")
        }
    case "pick":
        guard let k = TangramLessonLogic.pickKind(task.rule) else { check(false, "\(ctx) pick 题的 rule \(task.rule ?? "")"); return }
        check(board.tray.contains { $0.kind == k } || (board.show && board.target.contains { $0.kind == k }), "\(ctx) 有可以点的 \(k)")
        check(TangramLessonLogic.picked(k, rule: task.rule), "\(ctx) 点对了算对")
        for o in TangramKind.allCases where o != k { check(!TangramLessonLogic.picked(o, rule: task.rule), "\(ctx) 点错了不算对") }
    default:
        check(false, "\(ctx) 不认识的题型 \(task.type)")
    }
}

var taskCount = 0, variantCount = 0
for l in course.lessons {
    let tasks = l.steps.filter { $0.task != nil }.count
    taskCount += tasks
    check(tasks >= 2, "\(l.id) 至少 2 道题（现在 \(tasks)）")
    check((4...9).contains(l.steps.count), "\(l.id) 4–9 步（现在 \(l.steps.count)）")
    check(!l.learned.isEmpty, "\(l.id) 有 learned")
    check(l.steps.first?.board != nil, "\(l.id) 第一步有局面")
    var board = TangramLessonBoard()
    for (i, s) in l.steps.enumerated() {
        let ctx = "\(l.id) 第 \(i + 1) 步"
        if let spec = s.board {
            guard let b = TangramLessonBoard(spec: spec) else { check(false, "\(ctx) 局面读不出来：\(spec)"); continue }
            board = b
            check(TangramLessonBoard(spec: b.spec) == b, "\(ctx) 局面写回去一样")
            // 影子不重叠
            let t = b.target.map(\.vertices)
            for x in t.indices { for y in t.indices where y > x { check(TangramGeo.overlap(t[x], t[y]) < 1e-9, "\(ctx) 影子的块重叠") } }
        }
        solvable(s, board: board, ctx)
        if s.task != nil { check(s.hint != nil, "\(ctx) 有提示") }
        if let d = s.drill { for w in banned where d.contains(w) { check(false, "\(ctx) drill 提到方向「\(w)」") } }
        if s.task?.type == "fill" { check(!board.show, "\(ctx) 题目的局面不是演示") }
    }
    // 练习：每一段 × 每一种变换都有答案
    for (si, seg) in LessonPractice.segments(l, game: "tangram").enumerated() {
        for k in 0..<kit.practiceVariants {
            let steps = kit.practiceTransform!(seg, k)
            var b = TangramLessonBoard()
            for (i, s) in steps.enumerated() {
                if let spec = s.board, let nb = TangramLessonBoard(spec: spec) { b = nb }
                solvable(s, board: b, "\(l.id) 练习 \(si + 1) 变换 \(k) 第 \(i + 1) 题")
                for w in banned where s.say.contains(w) { check(false, "\(l.id) 练习说法提到方向「\(w)」：\(s.say)") }
                variantCount += 1
            }
        }
    }
    check(LessonPractice.canPractice(l, game: "tangram"), "\(l.id) 能练一练")
}
// 练习变换真的变了样子（转 90° 以后影子不一样）
if let l = course.lessons.first(where: { $0.steps.contains { $0.task?.type == "fill" } }),
   let s = l.steps.first(where: { $0.task?.type == "fill" && $0.board != nil }), let b = TangramLessonBoard(spec: s.board!) {
    let t1 = b.transformed(quarter: 1, mirror: false)
    check(!zip(t1.target, b.target).allSatisfy { $0.sameSpot($1) }, "转 90° 以后局面变了")
    let back = t1.transformed(quarter: 3, mirror: false)
    check(zip(back.target, b.target).allSatisfy { $0.sameSpot($1) }, "转 4 次 90° 回到原样")
    let mm = b.transformed(quarter: 0, mirror: true).transformed(quarter: 0, mirror: true)
    check(zip(mm.target, b.target).allSatisfy { $0.sameSpot($1) }, "翻两次回到原样")
}
for (rule, text) in kit.practicePrompts { for w in banned where text.contains(w) { check(false, "通用说法 \(rule) 提到方向") } }
print("  \(course.lessons.count) 课，\(taskCount) 道题，练习变换 \(variantCount) 题")

// MARK: - 配音

section("配音")
let extra = try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: root + "/tools/voice/extra_tangram.json"))) as! [String: Any]
let lines = extra["lines"] as? [String] ?? []
check(lines == kit.fixedLines, "extra_tangram.json 的 lines 和 TangramTutorial.kit.fixedLines 一模一样")
check(kit.goPlayLine == "这一组学完啦，去闯关吧！" && kit.goPlayTitle == "去闯关", "去闯关")
var spoken: [String] = kit.fixedLines + Array(kit.practicePrompts.values)
for l in course.lessons {
    spoken.append(TutorLines.lessonDone(l.learned))
    for s in l.steps { spoken += [s.say, s.hint, s.ok, s.after, s.drill].compactMap { $0 } }
}
// 读音：这些字在七巧板的台词里容易读错，出现了就要在 extra_tangram.json 里有替换
let replace = (extra["replace"] as? [[String]] ?? []).map { ($0[0], $0[1]) }
let regex = (extra["regex"] as? [[String]] ?? []).map { ($0[0], $0[1]) }
func speakForm(_ t: String) -> String {
    var s = t
    for (a, b) in replace { s = s.replacingOccurrences(of: a, with: b) }
    for (p, r) in regex { s = s.replacingOccurrences(of: p, with: r, options: .regularExpression) }
    return s
}
for t in Set(spoken) {
    let s = speakForm(t)
    for risky in ["重叠", "长方形", "空着", "空隙", "得先", "转一转"] where s.contains(risky) {
        check(false, "「\(t)」里的「\(risky)」没有读音替换")
    }
}
print("  \(Set(spoken).count) 句台词")

print("\(checks) checks, \(failed) failed")
print(failed == 0 ? "ALL PASSED" : "FAILED")
exit(failed == 0 ? 0 : 1)
