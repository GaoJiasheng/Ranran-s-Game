import Foundation

final class PlayerStore { func count(_ k: String) -> Int { 0 }; func increment(_ k: String) {} }

let root = CommandLine.arguments[1]
var problems = 0
func flag(_ s: String) { problems += 1; print("  ❌ " + s) }

func load(_ g: String) -> TutorialCourse {
    let data = try! Data(contentsOf: URL(fileURLWithPath: root + "/RanranGame/Tutorials/\(g).json"))
    return try! JSONDecoder().decode(TutorialCourse.self, from: data)
}

// MARK: gomoku
let gc = load("gomoku")
for t in gc.tracks { for l in t.lessons {
    print("[\(l.id)] \(l.title)")
    var b: GLessonBoard? = nil
    for (i, s) in l.steps.enumerated() {
        if let spec = s.board { b = GLessonBoard(spec: spec); if b == nil { flag("step \(i+1) bad board \(spec)") } }
        guard var board = b else { flag("step \(i+1) no board"); continue }
        for m in s.marks ?? [] {
            let ms = MarkSpec(m)
            for a in ms.args where a.count >= 2 && a.first!.isLetter && GLessonBoard.point(a, size: board.size) == nil && ms.kind != "label" { flag("mark \(m) bad point") }
        }
        if !board.winningPoints(.white).isEmpty, s.task?.rule != "block", s.task?.rule != "five" {
            print("  ⚠️ step \(i+1): white already has a winning point \(board.winningPoints(.white).map(board.name))")
        }
        guard let task = s.task else { continue }
        let ans = GomokuLessonLogic.answers(task, on: board)
        print("  step \(i+1) \(task.type)/\(task.rule ?? "accept") → \(ans.map(board.name))")
        if ans.isEmpty { flag("step \(i+1) has NO answer") }
        if task.type == "pick" {
            for p in ans where board[p] == nil { flag("pick answer \(board.name(p)) is empty") }
            continue
        }
        // 显式答案也要满足规则（如果有规则）
        let p = ans[0]
        board[p] = .black
        if let reply = s.reply {
            let r = GomokuLessonLogic.reply(reply, on: board)
            print("     reply \(reply) → \(r.map(board.name))")
            if r.isEmpty { flag("step \(i+1) reply produced nothing") }
            for q in r { board[q] = .white }
            if r.contains(where: { board.line(at: $0) != nil }) { flag("white wins with reply!") }
        }
        b = board
    }
}}

// MARK: gomoku: 每一种正确答案都走一遍（答案不止一个时，后面的步骤也必须接得上、白棋不能抢先赢）
func exploreGomoku(_ lid: String, _ steps: [TutorialStep], _ start: Int, _ board0: GLessonBoard?, _ path: String) {
    var i = start
    var board = board0
    while i < steps.count {
        let s = steps[i]
        if let spec = s.board { board = GLessonBoard(spec: spec) }
        guard let cur = board else { return }
        guard let task = s.task else { i += 1; continue }
        if task.type == "pick" { i += 1; continue }
        let ans = GomokuLessonLogic.answers(task, on: cur)
        // 答案很多（如 block）时只试头尾两个
        let tries = ans.count <= 6 ? ans : [ans[0], ans[ans.count - 1]]
        for a in tries {
            var b = cur
            b[a] = .black
            let tag = "\(path)\(lid)#\(i + 1)=\(cur.name(a))"
            if task.rule == "doubleThree" {
                // 三三：白棋无论怎么下（只要自己没有先连成四），黑棋接着都能靠活四 / 连续冲四赢
                var bad: [String] = []
                for w in b.empties {
                    let after = b.placing(w, .white)
                    if !after.winningPoints(.white).isEmpty { continue }
                    if !after.empties.contains(where: { after.winsByThreats($0, depth: 2) }) { bad.append(b.name(w)) }
                }
                if !bad.isEmpty { flag("\(tag) 三三 can be defended by white at \(bad)") }
                else { print("     \(tag): 三三 holds against every white reply") }
            }
            var after = b
            if let reply = s.reply {
                let r = GomokuLessonLogic.reply(reply, on: b)
                if r.isEmpty { flag("\(tag) reply produced nothing") }
                for q in r { after[q] = .white }
                if r.contains(where: { after.line(at: $0) != nil }) { flag("\(tag) white wins with reply") }
                // 对手被迫堵的那一手，不能顺手做出四（活四）：那样这一课就教错了
                if !after.winningPoints(.white).isEmpty { flag("\(tag) after the reply white has a winning point \(after.winningPoints(.white).map(after.name))") }
            }
            if ans.count > 1 { print("     branch \(tag) ok") }
            exploreGomoku(lid, steps, i + 1, after, path + "\(lid)#\(i + 1)=\(cur.name(a)) ")
            if ans.count > 1 && tries.count > 1 { /* 继续试下一个答案 */ }
        }
        return
    }
}
for t in gc.tracks { for l in t.lessons { exploreGomoku(l.id, l.steps, 0, nil, "") } }

// MARK: xiangqi
let xc = load("xiangqi")
for t in xc.tracks { for l in t.lessons {
    print("[\(l.id)] \(l.title)")
    var b: XBoard? = nil
    for (i, s) in l.steps.enumerated() {
        if let f = s.board { b = XBoard(fen: f); if b == nil { flag("step \(i+1) bad FEN \(f)") } }
        guard var board = b else { flag("step \(i+1) no board"); continue }
        if board.king(.red) == nil || board.king(.black) == nil { flag("step \(i+1) missing king") }
        if board.inCheck(board.turn.other) { flag("step \(i+1) side not to move is in check (illegal position) \(board.fen)") }
        for m in s.marks ?? [] {
            let ms = MarkSpec(m)
            for a in ms.args where ms.kind != "label" || a.count == 2 {
                if ms.kind == "palace" { continue }
                if ms.kind == "label" && a.count != 2 { continue }
                if XSquare(a) == nil && !(ms.kind == "label" && a.count == 1) { flag("mark \(m) bad square \(a)") }
            }
        }
        guard let task = s.task else { continue }
        if task.type == "pick" {
            let ok = (task.accept ?? []).compactMap(XSquare.init)
            print("  step \(i+1) pick → \(ok.map(\.name))")
            if ok.isEmpty { flag("pick has no answers") }
            continue
        }
        if let pc = task.piece, let sq = XSquare(pc), board[sq]?.side != .red { flag("step \(i+1) piece \(pc) not a red piece") }
        let ans = XiangqiLessonLogic.answers(task, on: board)
        print("  step \(i+1) move/\(task.rule ?? "accept") → \(ans.map(\.iccs)) \(board.inCheck(.red) ? "(red in check)" : "")")
        if ans.isEmpty { flag("step \(i+1) has NO answer  fen=\(board.fen)") }
        if task.rule == "mate2" {
            let m1 = board.matesInOne()
            if !m1.isEmpty { print("     ⚠️ mate in one exists too: \(m1.map(\.iccs))") }
        }
        if task.rule == "mate", ans.count > 3 { print("     ⚠️ many mates") }
        let m = ans[0]
        board.make(m)
        if let reply = s.reply {
            let r = XiangqiLessonLogic.reply(reply, on: board)
            print("     reply \(reply) → \(r.map(\.iccs))")
            if r.count != reply.count { flag("step \(i+1) reply \(reply) not all legal (got \(r.map(\.iccs)))") }
            for q in r { board.make(q) }
        } else {
            // 没有对手应着时，轮回红方继续（教学里红方连走）
            board.turn = .red
        }
        b = board
    }
}}
print(problems == 0 ? "ALL GOOD" : "PROBLEMS: \(problems)")
