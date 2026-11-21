import Foundation

// 教学内容：每道题按 ChessLessonLogic 都有答案；黑方每一种应着以后，后面的题也都有答案；
// 练一练的每一段 × 每种样子（原样、左右镜像）都有答案；走错时演示的后果真的成立；
// 每课 4–8 步、至少两道题；drill 和通用说法不提方向、不提格子；固定台词和 tools/voice/extra_chess.json 一致。

let root = CommandLine.arguments[1]
let course = loadCourse(root, "chess")
var consequencesShown = 0
var variantsChecked = 0
var branchesChecked = 0

/// 教学里每一步之后都轮回白方（没有对手应着时白方连走）
func whiteToMove(_ b: ChessBoard) -> ChessBoard { ChessLessonLogic.whiteToMove(b) }

func checkMarks(_ s: TutorialStep, _ where_: String) {
    for m in s.marks ?? [] {
        let ms = MarkSpec(m)
        let known = ["glow", "ring", "warn", "cross", "arrow", "label", "dot", "tint"]
        expect(known.contains(ms.kind), "\(where_): unknown mark \(m)")
        let squares = ms.kind == "label" ? Array(ms.args.prefix(1)) : ms.args
        for a in squares { expect(ChessSquare(a) != nil, "\(where_): mark \(m) has a bad square \(a)") }
        if ms.kind == "arrow" { expect(ms.args.count == 2, "\(where_): arrow needs two squares") }
    }
}

func checkConsequences(_ task: TutorialTask, _ b: ChessBoard, _ where_: String) {
    guard task.type == "move" else { return }
    for m in b.legalMoves() {
        if let pc = task.piece, m.from.name != pc { continue }
        guard let c = ChessLessonLogic.consequence(task, m, on: b) else { continue }
        if ChessLessonLogic.check(task, m, on: b) { fail("\(where_): consequence shown for a RIGHT move \(m.uci)"); continue }
        consequencesShown += 1
        var x = b.applying(m)
        if c.line == ChessTutorLines.stalemate { expect(x.isStalemate, "\(where_): \(m.uci) is not stalemate"); continue }
        for r in c.moves {
            guard x.isLegal(r) else { fail("\(where_): consequence reply \(r.uci) illegal after \(m.uci)"); break }
            if c.line == ChessTutorLines.captured { expect(x.isCapture(r), "\(where_): consequence \(r.uci) captures nothing") }
            if c.line == ChessTutorLines.kingEscaped { expect(x[r.from]?.kind == .king, "\(where_): \(r.uci) is not a king move") }
            x.make(r)
        }
    }
}

/// 一课从头走到尾：每一步的题都有答案；会把棋下完的题后面不能还有题；glow 标记要和答案对得上
func checkLesson(_ l: TutorialLesson, quiet: Bool = false) {
    if !quiet { note("[\(l.id)] \(l.title)") }
    var b: ChessBoard?
    for (i, s) in l.steps.enumerated() {
        let w = "\(l.id) step \(i + 1)"
        if let f = s.board {
            b = ChessBoard(fen: f)
            if b == nil { fail("\(w): bad FEN \(f)"); continue }
            expect(b!.turn == .white, "\(w): lesson boards start with white to move")
        }
        guard var board = b else { fail("\(w): no board"); continue }
        if s.board != nil || s.task != nil {
            // 摆出来的局面里黑王不能正在被将军（只有展示"已经将死"的那种不出题的局面可以）
            var asBlack = board
            if s.task == nil, let f = s.board, let bb = ChessBoard(fen: f.replacingOccurrences(of: " w ", with: " b ")) { asBlack = bb }
            expect(!board.inCheck(.black) || (s.task == nil && asBlack.isCheckmate),
                   "\(w): black is in check with white to move (illegal) \(board.fen)")
        }
        checkMarks(s, w)
        guard let task = s.task else { continue }
        if task.type == "pick" {
            let ok = (task.accept ?? []).compactMap(ChessSquare.init)
            if !quiet { note("  step \(i + 1) pick → \(ok.map(\.name))") }
            expect(!ok.isEmpty && ok.count == task.accept?.count, "\(w): pick answers")
            for sq in ok { expect(board[sq] != nil, "\(w): pick answer \(sq.name) is an empty square") }
            continue
        }
        expect(task.type == "move", "\(w): unknown task type \(task.type)")
        if let pc = task.piece {
            expect(ChessSquare(pc).flatMap { board[$0] }?.side == .white, "\(w): piece \(pc) is not a white piece")
        }
        if let acc = task.accept {
            for a in acc {
                let ok = a.count == 2 ? ChessSquare(a) != nil : ChessMove(a) != nil
                expect(ok, "\(w): bad accept token \(a)")
            }
        }
        let ans = ChessLessonLogic.answers(task, on: board)
        if !quiet { note("  step \(i + 1) \(task.rule ?? "accept") → \(ans.map { board.san($0) }) \(board.inCheck ? "(in check)" : "")") }
        if ans.isEmpty { fail("\(w): has NO answer  fen=\(board.fen)"); continue }
        if !quiet { checkConsequences(task, board, w) }
        // 发光的格子是提示要走到哪里：至少有一个答案落在发光的格子上（发光的是要动的子也行）
        let glows = (s.marks ?? []).map(MarkSpec.init).filter { $0.kind == "glow" }.compactMap { $0.args.first.flatMap(ChessSquare.init) }
        if !glows.isEmpty {
            expect(ans.contains { glows.contains($0.to) || glows.contains($0.from) }, "\(w): no answer goes to a glowing square")
        }
        if let rule = task.rule, rule.hasPrefix("mate"), rule != "mate", !board.matesInOne().isEmpty, i + 1 < l.steps.count,
           l.steps[i + 1].board == nil, l.steps[i + 1].task != nil {
            fail("\(w): \(rule) but a mate in one exists, and the next step expects the game to go on")
        }
        // 接着往下走：第一个答案 + 黑方的应着
        let m = ans[0]
        board.make(m)
        if let reply = s.reply {
            let r = ChessLessonLogic.reply(reply, on: board)
            if !quiet { note("     reply \(reply) → \(r.map(\.uci))") }
            expect(r.count == reply.count, "\(w): reply \(reply) not all legal")
            for q in r { board.make(q) }
        }
        b = whiteToMove(board)
    }
}

/// 分支检查：白方每一种被判对的走法 × 黑方每一种应着（reply 是 engine 时电脑走哪步不一定），后面的题都要有答案；
/// 后面还有题的时候，这一步不能已经把棋下完
func checkBranches(_ l: TutorialLesson) {
    var states: [ChessBoard] = []
    var worst = 0
    for (i, s) in l.steps.enumerated() {
        if let f = s.board, let nb = ChessBoard(fen: f) { states = [nb] }
        guard let task = s.task, task.type == "move" else { continue }
        let continues = i + 1 < l.steps.count && l.steps[i + 1].board == nil
            && l.steps[(i + 1)...].prefix { $0.board == nil }.contains { $0.task?.type == "move" }
        var next = Set<String>()
        for st in states {
            let board = whiteToMove(st)
            let ans = ChessLessonLogic.answers(task, on: board)
            if ans.isEmpty { fail("[\(l.id)] step \(i + 1) has NO answer on a reachable branch  fen=\(board.fen)"); continue }
            guard continues else { continue }
            for m in ans {
                let after = board.applying(m)
                if !after.hasLegalMove {
                    fail("[\(l.id)] step \(i + 1): \(board.san(m)) already ends the game, but more steps follow  fen=\(board.fen)")
                    continue
                }
                guard let reply = s.reply else { next.insert(whiteToMove(after).fen); continue }
                if reply == ["engine"] {
                    for r in after.legalMoves() { next.insert(after.applying(r).fen) }
                } else {
                    var a = after
                    let r = ChessLessonLogic.reply(reply, on: after)
                    expect(r.count == reply.count, "[\(l.id)] step \(i + 1): reply \(reply) illegal after \(board.san(m))")
                    for q in r { a.make(q) }
                    next.insert(a.fen)
                }
            }
        }
        if continues {
            worst = max(worst, next.count)
            branchesChecked += next.count
            states = next.compactMap(ChessBoard.init(fen:))
        }
    }
    if worst > 1 { note("  branches: up to \(worst) positions checked for a following step") }
}

// MARK: 课程结构

expect(course.game == "chess" && course.tracks.first?.id == "basic", "first track id is basic")
var ids = Set<String>()
for t in course.tracks {
    expect(t.art == "tutor_chess_\(t.id)", "track \(t.id) art name")
    expect(!t.lessons.isEmpty, "track \(t.id) has lessons")
    for l in t.lessons {
        expect(ids.insert(l.id).inserted, "duplicate lesson id \(l.id)")
        let tasks = l.steps.filter { $0.task != nil }.count
        expect(tasks >= 2, "\(l.id) has only \(tasks) tasks")
        expect((4...8).contains(l.steps.count), "\(l.id) has \(l.steps.count) steps (want 4–8)")
        expect(!l.learned.isEmpty && !l.title.isEmpty, "\(l.id) title / learned")
        expect(l.steps.first?.board != nil, "\(l.id) first step has no board")
        for (i, s) in l.steps.enumerated() where s.task != nil {
            expect(s.hint != nil, "\(l.id) step \(i + 1): task without a hint")
        }
    }
}
let levels = course.tracks.map { course.playLevel(after: $0) }
expect(levels == levels.sorted() && levels.allSatisfy { (1...10).contains($0) }, "play levels after each track \(levels)")
print("  course: \(course.tracks.count) tracks, \(course.lessons.count) lessons, \(course.lessons.reduce(0) { $0 + $1.steps.filter { $0.task != nil }.count }) tasks; play levels \(levels)")

// MARK: 每一课、每一个分支

for l in course.lessons {
    checkLesson(l)
    checkBranches(l)
}

// MARK: 练一练、复习

let banned = ["左", "右", "上面", "下面", "往上", "往下", "上边", "下边", "上方", "下方"]
func checkPracticeText(_ t: String, _ where_: String) {
    for w in banned where t.contains(w) { fail("\(where_): practice text mentions a direction「\(w)」: \(t)") }
    let scalars = Array(t.unicodeScalars)
    for (i, c) in scalars.enumerated() {
        if c.value >= 65 && c.value <= 90 { fail("\(where_): practice text mentions a label letter: \(t)"); break }
        if c.value >= 97 && c.value <= 104, i + 1 < scalars.count, scalars[i + 1].value >= 49, scalars[i + 1].value <= 56 {
            fail("\(where_): practice text names a square: \(t)"); break
        }
    }
}
for (k, v) in ChessTutorial.practicePrompts { checkPracticeText(v, "prompt \(k)") }

var practisable = 0, totalTasks = 0
var mirrored = 0
for l in course.lessons {
    for (i, s) in l.steps.enumerated() where s.task != nil {
        totalTasks += 1
        if let d = s.drill { checkPracticeText(d, "\(l.id) step \(i + 1) drill") }
        // 用到的规则都要有练习说法（或者写了 drill）
        if s.drill == nil, let r = s.task?.rule, r != "any", PracticePrompts.generic(r, game: "chess") == nil {
            fail("\(l.id) step \(i + 1): rule \(r) has no practice prompt and no drill")
        }
    }
    let segs = LessonPractice.segments(l, game: "chess")
    practisable += segs.reduce(0) { $0 + LessonPractice.taskCount($1) }
    for (si, seg) in segs.enumerated() {
        expect(seg.first?.board != nil, "\(l.id): practice segment starts without a board")
        for k in 0..<ChessTutorial.kit.practiceVariants {
            var v = l
            v.id = "\(l.id)~练习\(si + 1)~样子\(k)"
            v.steps = ChessTutorial.kit.practiceTransform!(seg, k)
            if k == 1, v.steps != seg { mirrored += 1 }
            variantsChecked += 1
            checkLesson(v, quiet: true)
            checkBranches(v)
        }
    }
}
// 镜像两次 = 原样
for l in course.lessons {
    for seg in LessonPractice.segments(l, game: "chess") {
        expect(ChessLessonLogic.transform(ChessLessonLogic.transform(seg, 1), 1) == seg, "\(l.id): mirror twice is not identity")
    }
}
expect(ChessLessonLogic.mirrorToken("e7e8q") == "d7d8q" && ChessLessonLogic.mirrorToken("a1") == "h1"
    && ChessLessonLogic.mirrorSpec("e7e5|d7d5") == "d7d5|e7e5" && ChessLessonLogic.mirrorSpec("label:e4:A") == "label:d4:A",
    "mirror tokens")
expect(ChessLessonLogic.mirrorFEN("4k3/8/8/8/8/8/8/R3K3 w - - 0 1") == "3k4/8/8/8/8/8/8/3K3R w - - 0 1", "mirror FEN")
do {
    var rng = SplitMix(state: 3)
    var cups: [String: LessonCup] = [:]
    for l in course.lessons { cups[l.id] = .gold }
    for _ in 0..<30 {
        guard let r = LessonPractice.reviewLesson(course, cups: cups, using: &rng) else { fail("no review lesson"); break }
        expect(r.steps.filter { $0.task != nil }.count == min(5, practisable), "review has 5 tasks")
        checkLesson(r, quiet: true)
    }
}
print("  practice: \(practisable)/\(totalTasks) tasks practisable; \(variantsChecked) segment variants checked (\(mirrored) mirrored)")
print("  branches: \(branchesChecked) positions after black replies checked; \(consequencesShown) wrong moves with a shown consequence")

// MARK: 配音：固定台词和 extra_chess.json 一致；读音修正

do {
    let url = URL(fileURLWithPath: root + "/tools/voice/extra_chess.json")
    let json = try! JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
    let lines = json["lines"] as! [String]
    expect(lines == ChessTutorial.kit.fixedLines, "tools/voice/extra_chess.json lines differ from ChessTutorial.kit.fixedLines")
    let replace = (json["replace"] as? [[String]]) ?? []
    expect(replace.contains(["车", "居"]), "车 must be read jū (replace 车 → 居)")
    // 所有要读的句子
    var all = ChessTutorial.kit.fixedLines
    for l in course.lessons {
        all.append(TutorLines.lessonDone(l.learned))
        for s in l.steps { all += [s.say, s.hint, s.ok, s.after, s.drill].compactMap { $0 } }
    }
    // 容易读错的字：不在白名单里的用法要提醒（白名单之外请改说法，或者在 extra_chess.json 里加修正）
    let risky: [(String, [String])] = [
        ("长", ["长易位", "长着"]), ("行", ["都行", "不行", "才行", "就行"]), ("重", ["重要"]),
        ("还", ["还有", "还能", "还没", "还要", "还是", "还不"]), ("朝", []), ("相", []), ("调", []), ("曲", []), ("差", []),
        ("着法", []), ("一着", []), ("应", ["应着"]), ("空格", []), ("闷", ["闷杀"]),
        ("得", ["得子", "吃得", "离得", "围得", "顾得", "来得", "两得", "记得", "觉得", "得到"]), ("便", ["顺便"]),
        ("数", ["数一数", "步数"]), ("转", []), ("背", []), ("落", ["角落", "落到", "落在"]), ("干", []), ("乐", []),
    ]
    var flagged = 0
    for t in Set(all) {
        for (ch, okWords) in risky {
            var rest = t
            for w in okWords { rest = rest.replacingOccurrences(of: w, with: "") }
            if rest.contains(ch) { fail("polyphone 「\(ch)」 needs a check: \(t)"); flagged += 1 }
        }
    }
    print("  voice: \(Set(all).count) lines (fixed lines match extra_chess.json), \(flagged) risky polyphones")
}

finish("tutorial")
