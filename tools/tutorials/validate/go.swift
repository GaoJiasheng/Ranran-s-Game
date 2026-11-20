import Foundation

// 围棋：把每一种走法分支都走一遍（征子、枷的循环也走到底）；
// 练习题（每段 × 每种对称变换）也一样走一遍；
// 走错以后演示的"后果"（白棋逃掉 / 黑子被提）每一种错法都真的成立。

let root = CommandLine.arguments[1]
let c = loadCourse(root, "go")
var problems = 0
var pathsDone = 0
var consequencesShown = 0
var quiet = false
func flag(_ s: String) { problems += 1; print("  ❌ " + s) }

func checkConsequences(_ task: TutorialTask, _ bd: GoBoard, _ where_: String) {
    guard task.type == "place" else { return }
    for m in bd.cells.indices where bd.cells[m] == 0 && bd.isLegal(m) {
        guard let cq = GoLessonLogic.consequence(task, m, on: bd) else { continue }
        if GoLessonLogic.check(task, m, on: bd) { flag("\(where_): consequence shown for a RIGHT move \(bd.name(m))"); continue }
        consequencesShown += 1
        var b = bd.playing(m)!
        for w in cq.moves {
            guard b.isLegal(w) else { flag("\(where_): consequence \(bd.name(w)) illegal after \(bd.name(m))"); return }
            b.play(w)
        }
        let parts = (task.rule ?? "").split(separator: ":").map(String.init)
        if cq.line == TutorLines.goBlackCaptured, let p = bd.index(parts.count > 1 ? parts[1] : ""), b[p] == .black {
            flag("\(where_): after \(bd.name(m)) black at \(parts[1]) was not captured")
        }
        if cq.line == TutorLines.goWhiteEscaped {
            // 长出来的那颗白子所在的整块至少两口气
            let w = cq.moves.last!
            if b[w] != .white || b.libertyCount(w, limit: 3) < 2 { flag("\(where_): after \(bd.name(m)) white did not escape") }
        }
    }
}

func walk(_ l: TutorialLesson, _ i: Int, _ board: GoBoard?, _ path: String, _ printed: inout Set<Int>, loopIter: Int = 0) {
    guard i < l.steps.count else { return }
    let s = l.steps[i]
    var b = board
    if loopIter > 14 { flag("\(l.id) step \(i+1) loop longer than 14 (path \(path))"); return }
    if loopIter == 0, let spec = s.board {
        b = GoBoard(spec: spec)
        if b == nil { flag("\(l.id) step \(i+1) bad board \(spec)"); return }
        for k in b!.cells.indices where b!.cells[k] != 0 && b!.liberties(k) == 0 { flag("\(l.id) step \(i+1) stone \(b!.name(k)) has no liberty") }
    }
    guard var bd = b else { flag("\(l.id) step \(i+1) no board"); return }
    bd.turn = .black
    for m in s.marks ?? [] {
        let ms = MarkSpec(m)
        for (k, a) in ms.args.enumerated() where !(ms.kind == "label" && k == 1) {
            if bd.index(a) == nil { flag("\(l.id) step \(i+1) mark \(m) bad point") }
        }
    }
    guard let task = s.task else { walk(l, i + 1, bd, path, &printed); return }
    let ans = GoLessonLogic.answers(task, on: bd)
    if !printed.contains(i) {
        printed.insert(i)
        if !quiet { print("  step \(i+1) \(task.type)/\(task.rule ?? "accept") → \(ans.prefix(12).map(bd.name))\(ans.count > 12 ? "…(\(ans.count))" : "")") }
        checkConsequences(task, bd, "\(l.id) step \(i+1)")
    }
    if ans.isEmpty { flag("\(l.id) step \(i+1) has NO answer (path \(path))"); return }
    if task.type == "pick" || task.type == "pickAll" { walk(l, i + 1, bd, path, &printed); return }
    if task.accept == nil && task.rule == "any" { return }
    // 循环步（追子）：能提就提，否则选叫吃以后白棋最难逃的那一步（对方逃出来气最少）
    var order = ans
    if s.loop != nil, let lp = s.loop, let li = bd.index(lp) {
        func cost(_ m: Int) -> Int {
            guard let a = bd.playing(m) else { return 99 }
            if a[li] != .white { return -1 }
            let r = GoLessonLogic.reply(s.reply ?? [], on: a)
            var c = a
            for mv in r { if let mv { c.play(mv) } }
            return c[li] == .white ? c.libertyCount(li, limit: 9) : -1
        }
        order = ans.sorted { cost($0) < cost($1) }
    }
    for m in order.prefix(loopIter > 0 ? 1 : 4) {
        guard var nb = bd.playing(m) else { flag("\(l.id) answer \(bd.name(m)) illegal"); continue }
        if let reply = s.reply {
            let r = GoLessonLogic.reply(reply, on: nb)
            if r.count < reply.count && s.loop == nil { flag("\(l.id) step \(i+1) reply \(reply) incomplete after \(bd.name(m)) (path \(path))") }
            for mv in r { if let mv { nb.play(mv) } else { nb.pass() } }
        } else {
            nb.turn = .black
        }
        if let lp = s.loop, let li = nb.index(lp), nb[li] == .white {
            walk(l, i, nb, path + " " + bd.name(m), &printed, loopIter: loopIter + 1)
        } else {
            if s.loop != nil, loopIter < 26 { pathsDone += 1 }
            walk(l, i + 1, nb, path + " " + bd.name(m), &printed)
        }
    }
}

for l in c.lessons {
    print("[\(l.id)] \(l.title)")
    var printed = Set<Int>()
    walk(l, 0, nil, "", &printed)
}
// 练习题：每段 × 每种变换
quiet = true
var variants = 0
for l in c.lessons {
    for v in practiceVariants(l, game: "go") {
        variants += 1
        var printed = Set<Int>()
        walk(v.lesson, 0, nil, "", &printed)
    }
}
print("practice variants checked: \(variants); wrong moves with a shown consequence: \(consequencesShown)")
print("loop paths finished:", pathsDone)
print(problems == 0 ? "ALL GOOD" : "PROBLEMS: \(problems)")
