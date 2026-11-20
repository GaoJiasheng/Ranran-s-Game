import Foundation

// 五子棋、象棋：每一步都有答案、对手的应着合法；
// 练习题（每段 × 每种对称变换）也一样都有答案；
// 走错以后演示的"后果"（白棋连五 / 活四，黑方吃子 / 黑将逃走）每一种错法都真的成立。

let root = CommandLine.arguments[1]
var problems = 0
var variantsChecked = 0
var consequencesShown = 0
var quiet = false
func flag(_ s: String) { problems += 1; print("  ❌ " + s) }
func say(_ s: String) { if !quiet { print(s) } }

// MARK: gomoku

func checkGomokuConsequences(_ task: TutorialTask, _ board: GLessonBoard, _ where_: String) {
    guard task.type == "place" else { return }
    for p in board.empties {
        let right = GomokuLessonLogic.check(task, p, on: board)
        guard let c = GomokuLessonLogic.consequence(task, p, on: board) else { continue }
        if right { flag("\(where_): consequence shown for a RIGHT move \(board.name(p))"); continue }
        consequencesShown += 1
        var b = board
        b[p] = .black
        for q in c.moves {
            guard b[q] == nil else { flag("\(where_): consequence plays on a taken point \(b.name(q))"); return }
            b[q] = .white
        }
        let q = c.moves.last!
        if c.line == TutorLines.gomokuWhiteFive, b.line(at: q) == nil { flag("\(where_): after \(board.name(p)) white does not make five") }
        if c.line == TutorLines.gomokuWhiteOpenFour, b.winningPoints(.white).count < 2 { flag("\(where_): after \(board.name(p)) white has no open four") }
    }
}

func checkGomoku(_ l: TutorialLesson) {
    say("[\(l.id)] \(l.title)")
    var b: GLessonBoard? = nil
    for (i, s) in l.steps.enumerated() {
        if let spec = s.board { b = GLessonBoard(spec: spec); if b == nil { flag("\(l.id) step \(i+1) bad board \(spec)") } }
        guard var board = b else { flag("\(l.id) step \(i+1) no board"); continue }
        for m in s.marks ?? [] {
            let ms = MarkSpec(m)
            for a in ms.args where a.count >= 2 && a.first!.isLetter && GLessonBoard.point(a, size: board.size) == nil && ms.kind != "label" { flag("\(l.id) mark \(m) bad point") }
        }
        if !board.winningPoints(.white).isEmpty, s.task?.rule != "block", s.task?.rule != "five" {
            say("  ⚠️ step \(i+1): white already has a winning point \(board.winningPoints(.white).map(board.name))")
        }
        guard let task = s.task else { continue }
        let ans = GomokuLessonLogic.answers(task, on: board)
        say("  step \(i+1) \(task.type)/\(task.rule ?? "accept") → \(ans.map(board.name))")
        if ans.isEmpty { flag("\(l.id) step \(i+1) has NO answer"); continue }
        checkGomokuConsequences(task, board, "\(l.id) step \(i+1)")
        if task.type == "pick" {
            for p in ans where board[p] == nil { flag("\(l.id) pick answer \(board.name(p)) is empty") }
            continue
        }
        // 显式答案也要满足规则（如果有规则）
        let p = ans[0]
        board[p] = .black
        if let reply = s.reply {
            let r = GomokuLessonLogic.reply(reply, on: board)
            say("     reply \(reply) → \(r.map(board.name))")
            if r.isEmpty { flag("\(l.id) step \(i+1) reply produced nothing") }
            for q in r { board[q] = .white }
            if r.contains(where: { board.line(at: $0) != nil }) { flag("\(l.id) white wins with reply!") }
        }
        b = board
    }
}

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

// MARK: xiangqi

func checkXiangqiConsequences(_ task: TutorialTask, _ board: XBoard, _ where_: String) {
    guard task.type == "move" else { return }
    for m in board.legalMoves() {
        if let pc = task.piece, m.from.name != pc { continue }
        guard let c = XiangqiLessonLogic.consequence(task, m, on: board) else { continue }
        if XiangqiLessonLogic.check(task, m, on: board) { flag("\(where_): consequence shown for a RIGHT move \(m.iccs)"); continue }
        consequencesShown += 1
        var b = board.applying(m)
        for r in c.moves {
            guard b.legalMoves(from: r.from).contains(r) else { flag("\(where_): consequence reply \(r.iccs) illegal after \(m.iccs)"); return }
            if c.line == TutorLines.xiangqiCaptured, b[r.to] == nil { flag("\(where_): consequence \(r.iccs) captures nothing") }
            if c.line == TutorLines.xiangqiKingEscaped, b[r.from]?.kind != .king { flag("\(where_): consequence \(r.iccs) is not a king move") }
            b.make(r)
        }
    }
}

func checkXiangqi(_ l: TutorialLesson) {
    say("[\(l.id)] \(l.title)")
    var b: XBoard? = nil
    for (i, s) in l.steps.enumerated() {
        if let f = s.board { b = XBoard(fen: f); if b == nil { flag("\(l.id) step \(i+1) bad FEN \(f)") } }
        guard var board = b else { flag("\(l.id) step \(i+1) no board"); continue }
        if board.king(.red) == nil || board.king(.black) == nil { flag("\(l.id) step \(i+1) missing king") }
        if board.inCheck(board.turn.other) { flag("\(l.id) step \(i+1) side not to move is in check (illegal position) \(board.fen)") }
        for m in s.marks ?? [] {
            let ms = MarkSpec(m)
            for a in ms.args where ms.kind != "label" || a.count == 2 {
                if ms.kind == "palace" { continue }
                if ms.kind == "label" && a.count != 2 { continue }
                if XSquare(a) == nil && !(ms.kind == "label" && a.count == 1) { flag("\(l.id) mark \(m) bad square \(a)") }
            }
        }
        guard let task = s.task else { continue }
        if task.type == "pick" {
            let ok = (task.accept ?? []).compactMap(XSquare.init)
            say("  step \(i+1) pick → \(ok.map(\.name))")
            if ok.isEmpty { flag("\(l.id) pick has no answers") }
            continue
        }
        if let pc = task.piece, let sq = XSquare(pc), board[sq]?.side != .red { flag("\(l.id) step \(i+1) piece \(pc) not a red piece") }
        let ans = XiangqiLessonLogic.answers(task, on: board)
        say("  step \(i+1) move/\(task.rule ?? "accept") → \(ans.map(\.iccs)) \(board.inCheck(.red) ? "(red in check)" : "")")
        if ans.isEmpty { flag("\(l.id) step \(i+1) has NO answer  fen=\(board.fen)"); continue }
        checkXiangqiConsequences(task, board, "\(l.id) step \(i+1)")
        if task.rule == "mate2" {
            let m1 = board.matesInOne()
            if !m1.isEmpty { say("     ⚠️ mate in one exists too: \(m1.map(\.iccs))") }
        }
        if task.rule == "mate", ans.count > 3 { say("     ⚠️ many mates") }
        let m = ans[0]
        board.make(m)
        if let reply = s.reply {
            let r = XiangqiLessonLogic.reply(reply, on: board)
            say("     reply \(reply) → \(r.map(\.iccs))")
            if r.count != reply.count { flag("\(l.id) step \(i+1) reply \(reply) not all legal (got \(r.map(\.iccs)))") }
            for q in r { board.make(q) }
        } else {
            // 没有对手应着时，轮回红方继续（教学里红方连走）
            board.turn = .red
        }
        b = board
    }
}

/// 分支检查：上面只走了"第一个答案 + 电脑的那一步"。这里把所有可能都走一遍——
/// 红方每一种被判对的走法 × 黑方每一种应着（reply 是 "engine" 时，电脑想多久、走哪步不一定），
/// 后面接着的题（没有新棋盘的那几步）都必须有答案；而且接着还有题的时候，这一步不能已经把棋下完。
func xiangqiBranches(_ l: TutorialLesson) {
    var states: [XBoard] = []
    var worst = 0
    for (i, s) in l.steps.enumerated() {
        if let f = s.board, let nb = XBoard(fen: f) { states = [nb] }
        guard let task = s.task, task.type == "move" else { continue }
        let continues = i + 1 < l.steps.count && l.steps[i + 1].board == nil
            && l.steps[(i + 1)...].prefix { $0.board == nil }.contains { $0.task?.type == "move" }
        var next = Set<XBoard>()
        for st in states {
            var board = st
            board.turn = .red
            let ans = XiangqiLessonLogic.answers(task, on: board)
            if ans.isEmpty { flag("[\(l.id)] step \(i+1) has NO answer on a reachable branch  fen=\(board.fen)"); continue }
            guard continues else { continue }
            for m in ans {
                let after = board.applying(m)
                if after.legalMoves().isEmpty {
                    flag("[\(l.id)] step \(i+1): \(m.iccs) already ends the game, but more steps follow  fen=\(board.fen)")
                    continue
                }
                guard let reply = s.reply else { var a = after; a.turn = .red; next.insert(a); continue }
                if reply == ["engine"] {
                    for r in after.legalMoves() { next.insert(after.applying(r)) }
                } else {
                    var a = after
                    for q in XiangqiLessonLogic.reply(reply, on: after) { a.make(q) }
                    next.insert(a)
                }
            }
        }
        if continues {
            worst = max(worst, next.count)
            states = Array(next)
        }
    }
    if worst > 1 { print("  branches: up to \(worst) positions checked for a following step") }
}

let gc = loadCourse(root, "gomoku")
let xc = loadCourse(root, "xiangqi")
for l in gc.lessons { checkGomoku(l) }
for t in gc.tracks { for l in t.lessons { exploreGomoku(l.id, l.steps, 0, nil, "") } }
for l in xc.lessons { checkXiangqi(l); xiangqiBranches(l) }

// 练习题：每段 × 每种变换
quiet = true
for l in gc.lessons { for v in practiceVariants(l, game: "gomoku") { variantsChecked += 1; checkGomoku(v.lesson) } }
for l in xc.lessons { for v in practiceVariants(l, game: "xiangqi") { variantsChecked += 1; checkXiangqi(v.lesson) } }
quiet = false
print("practice variants checked: \(variantsChecked); wrong moves with a shown consequence: \(consequencesShown)")
print(problems == 0 ? "ALL GOOD" : "PROBLEMS: \(problems)")
