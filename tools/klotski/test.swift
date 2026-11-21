import Foundation

// 华容道的命令行测试：zsh tools/klotski/test.sh（全部通过时最后一行是 ALL PASSED）
//   1. 盘面、走法、滑动的限制
//   2. 求解器：和一个另外写的最笨的搜索对照；横刀立马的最少步数
//   3. 关卡：全部有解、最少步数和求解器一致、每组的范围、排序、不重复（包括镜像）、id 不重复、提示每一步都在最短路上
//   4. 教学：每课 ≥ 2 道题、每道题都有答案（也有 hint / drill）、题目里说几步就是最少几步、标记写得对
//   5. 练一练：每一段题的每一种镜像都还有答案，镜像两次变回原样，drill 不提方向
//   6. 配音：固定台词和 extra_klotski.json 一致

let root = CommandLine.arguments[1]
var failures = 0
func fail(_ s: String) { failures += 1; print("  ❌ " + s) }
func expect(_ ok: Bool, _ what: @autoclosure () -> String) { if !ok { fail(what()) } }

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

let classic = "VBBV/VBBV/VHHV/VSSV/S..S"

// MARK: 1. 盘面和走法

print("[盘面和走法]")
do {
    let b = KlotskiBoard(layout: classic)!
    expect(b.layout == classic, "layout round trip")
    expect(b.pieces.count == 10, "classic has 10 pieces")
    expect(b.emptyCells.count == 2, "classic has 2 empty cells")
    expect(b.allMoves.count == 6, "classic opening has 6 moves, got \(b.allMoves.count)")
    expect(!b.solved && b.bunny != nil, "classic is not solved")
    expect(KlotskiBoard(layout: "VBBV/VBBV/VHHV/VSSV/S..")  == nil, "short row is rejected")
    expect(KlotskiBoard(layout: "VBB./VBBV/VHHV/VSSV/S..S") == nil, "broken piece is rejected")
    expect(KlotskiBoard(layout: "VBBX/VBBV/VHHV/VSSV/S..S") == nil, "unknown letter is rejected")
    // 墙和别的木块：不能出界、不能跳过
    let c = KlotskiBoard(layout: "BB../BB../..S./..../.HH.")!
    let s = c.pieceAt(x: 2, y: 2)!
    expect(c.maxSlide(s, .down) == 1 && c.maxSlide(s, .up) == 2 && c.maxSlide(s, .right) == 1 && c.maxSlide(s, .left) == 2,
           "small block slide limits")
    let big = c.bunny!
    expect(c.maxSlide(big, .right) == 2 && c.maxSlide(big, .down) == 2 && c.maxSlide(big, .left) == 0, "bunny slide limits")
    expect(!c.canApply(KlotskiMove(piece: s, dir: .down, dist: 2)), "cannot slide through a block")
    expect(c.canApply(KlotskiMove(piece: s, dir: .up, dist: 2)), "can slide 2")
    let blocked = KlotskiBoard(layout: "..BB/..BB/S.S./..../....")!
    expect(blocked.maxSlide(blocked.pieceAt(x: 0, y: 2)!, .right) == 1, "cannot jump over a block")
    // 移动以后序号不变，盘面一致
    let moved = c.applying(KlotskiMove(piece: s, dir: .down, dist: 1))
    expect(moved.pieces[s].y == 3 && moved.pieces.count == c.pieces.count, "apply keeps piece index")
    // 镜像
    expect(b.mirrored.layout == classic, "classic is symmetric")
    expect(KlotskiBoard(layout: ".BB./.BB./.V../.V../....")!.mirrored.mirrored == KlotskiBoard(layout: ".BB./.BB./.V../.V../....")!, "mirror twice")
    // key 的来回
    for lay in [classic, "SBBS/.BB./V.HH/V.../.S..", "VVBB/VVBB/V.../V.../S..."] {
        let x = KlotskiBoard(layout: lay)!
        expect(KlotskiBoard(key: x.key).key == x.key && KlotskiBoard(key: x.key).layout == lay, "key round trip \(lay)")
    }
    // 形状一样的木块换位置，key 一样
    let twoS = KlotskiBoard(pieces: [KlotskiPiece(kind: .small, x: 0, y: 0), KlotskiPiece(kind: .small, x: 1, y: 0)])
    let twoS2 = KlotskiBoard(pieces: [KlotskiPiece(kind: .small, x: 1, y: 0), KlotskiPiece(kind: .small, x: 0, y: 0)])
    expect(twoS.key == twoS2.key, "identical pieces are interchangeable")
    expect(KlotskiBoard.isGoal(key: KlotskiBoard(layout: "VVSS/VV../.BB./.BB./....")!.key) == false, "not goal")
    expect(KlotskiBoard.isGoal(key: KlotskiBoard(layout: "VVSS/VV../..../.BB./.BB.")!.key), "goal key")
    expect(KlotskiBoard(layout: "VVSS/VV../..../.BB./.BB.")!.solved, "goal solved")
}

// MARK: 2. 求解器

print("[求解器]")

/// 另外写的最笨的搜索：直接在 5×4 的字符格子上滑，一次滑几格都算一步。
func naiveMin(_ layout: String, step: Int = 3) -> Int? {
    typealias Grid = [[Character]]
    func parse(_ s: String) -> Grid { s.split(separator: "/").map { Array($0) } }
    func norm(_ g: Grid) -> String { g.map { String($0) }.joined(separator: "/") }
    func goal(_ g: Grid) -> Bool { g[3][1] == "B" && g[3][2] == "B" && g[4][1] == "B" && g[4][2] == "B" }
    func pieces(_ g: Grid) -> [(c: Character, cells: [(Int, Int)])] {
        var seen = Set<Int>()
        var out: [(Character, [(Int, Int)])] = []
        for y in 0..<5 { for x in 0..<4 where g[y][x] != "." && !seen.contains(y * 4 + x) {
            let c = g[y][x]
            let (w, h) = c == "B" ? (2, 2) : c == "V" ? (1, 2) : c == "H" ? (2, 1) : (1, 1)
            var cells: [(Int, Int)] = []
            for dy in 0..<h { for dx in 0..<w { cells.append((x + dx, y + dy)); seen.insert((y + dy) * 4 + x + dx) } }
            out.append((c, cells))
        } }
        return out
    }
    var seen: Set<String> = [layout]
    var frontier = [parse(layout)]
    var d = 0
    while !frontier.isEmpty {
        for g in frontier where goal(g) { return d }
        d += 1
        var next: [Grid] = []
        for g in frontier {
            for p in pieces(g) {
                for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                    var gg = g
                    for (x, y) in p.cells { gg[y][x] = "." }
                    var cells = p.cells
                    for _ in 1...step {
                        cells = cells.map { ($0.0 + dx, $0.1 + dy) }
                        if cells.contains(where: { $0.0 < 0 || $0.0 > 3 || $0.1 < 0 || $0.1 > 4 || gg[$0.1][$0.0] != "." }) { break }
                        var g2 = gg
                        for (x, y) in cells { g2[y][x] = p.c }
                        if seen.insert(norm(g2)).inserted { next.append(g2) }
                    }
                }
            }
        }
        frontier = next
    }
    return nil
}

do {
    // 已知的盘面：最少步数要和另外写的搜索一样
    let samples = [".BB./.BB./.S../..../....", "BB../BB../HH../..../....", ".BB./.BB./.HH./..../....",
                   "VBBV/VBBV/..../.SS./....", "SBBS/.BB./..../..../.HH.", ".BB./.BB./..../HH../HH..",
                   "..BB/..BB/..../HH../HH..", "BB../BB../V.../V.../.HH.", "SBBS/.BB./V.HH/V.../.S..",
                   "VVBB/VVBB/V.../V.../S..."]
    for lay in samples {
        let t = Date()
        defer { if Date().timeIntervalSince(t) > 3 { print("  (慢) \(lay) \(Int(Date().timeIntervalSince(t))) 秒") } }
        let b = KlotskiBoard(layout: lay)!
        let a = KlotskiSolver.minMoves(b), n = naiveMin(lay)
        expect(a == n && a != nil, "solver vs naive on \(lay): \(String(describing: a)) vs \(String(describing: n))")
    }
    // 随机盘面也对一对
    var rng = SplitMix(state: 99)
    var checked = 0
    while checked < 12 {
        var pieces = [KlotskiPiece(kind: .big, x: Int.random(in: 0...2, using: &rng), y: Int.random(in: 0...3, using: &rng))]
        var occ = KlotskiBoard.mask(pieces[0])
        for _ in 0..<Int.random(in: 2...6, using: &rng) {
            let k: KlotskiKind = [.tall, .wide, .small, .small].randomElement(using: &rng)!
            let x = Int.random(in: 0...(4 - k.w), using: &rng), y = Int.random(in: 0...(5 - k.h), using: &rng)
            if KlotskiBoard.mask(k, x, y) & occ != 0 { continue }
            pieces.append(KlotskiPiece(kind: k, x: x, y: y))
            occ |= KlotskiBoard.mask(k, x, y)
        }
        let b = KlotskiBoard(pieces: pieces)
        let a = KlotskiSolver.minMoves(b), n = naiveMin(b.layout)
        expect(a == n, "random board \(b.layout): \(String(describing: a)) vs \(String(describing: n))")
        // 路径真的走得通、到出口
        if let path = KlotskiSolver.solve(b) {
            var cur = b
            var ok = true
            for m in path { if !cur.canApply(m) { ok = false; break }; cur = cur.applying(m) }
            expect(ok && cur.solved, "solution replays on \(b.layout)")
        }
        checked += 1
    }
    // 横刀立马：一次直着滑几格算一步，最少 90 步；每次只挪一格的话是 116 步
    let t0 = Date()
    expect(KlotskiSolver.minMoves(KlotskiBoard(layout: classic)!) == 90, "横刀立马 needs 90 moves (any distance straight line = 1 move)")
    expect(naiveMin(classic, step: 1) == 116, "横刀立马 needs 116 single-cell moves")
    expect(KlotskiSolver.component(of: KlotskiBoard(layout: classic)!).count == 25955, "横刀立马 has 25955 reachable positions")
    // 快速展开和 allMoves 逐个盘面对照（横刀立马的 25955 个盘面）
    var mismatches = 0
    for k in KlotskiSolver.component(of: KlotskiBoard(layout: classic)!) {
        let b = KlotskiBoard(key: k)
        let slow = Set(b.allMoves.map { b.applying($0).key })
        if slow != Set(KlotskiBoard.neighbors(of: k)) { mismatches += 1 }
    }
    expect(mismatches == 0, "fast expand differs from allMoves on \(mismatches) positions")
    print("  横刀立马：90 步（一次直着滑几格都算一步）/ 116 步（每次一格），用时 \(Int(Date().timeIntervalSince(t0) * 1000)) 毫秒")
    // 无解
    expect(KlotskiSolver.solve(KlotskiBoard(layout: "VVSS/VV../..../.BB./.BB.")!)?.isEmpty == true, "already solved = 0 moves")
}

// MARK: 3. 关卡

print("[关卡]")
do {
    let packs = KlotskiCatalog.specs
    expect((3...4).contains(packs.count), "3–4 packs")
    expect(KlotskiCatalog.passPacks >= 1 && KlotskiCatalog.passPacks <= packs.count, "passPacks in range")
    expect(Set(KlotskiCatalog.levels.map(\.id)).count == KlotskiCatalog.levels.count, "level ids are unique")
    expect(Set(packs.map(\.id)).count == packs.count, "pack ids are unique")
    var seen: [UInt64: String] = [:]
    var worst = 0.0
    var total = 0
    for spec in packs {
        let levels = KlotskiCatalog.levels.filter { $0.pack == spec.id }
        let pk = KlotskiCatalog.packs.first { $0.id == spec.id }
        expect(pk?.levels == levels.map(\.id), "\(spec.id): catalog lists the levels in order")
        expect(pk?.art == "pack_klotski_\(spec.id)", "\(spec.id): art name")
        expect(!levels.isEmpty && levels.count <= 20, "\(spec.id): 1–20 levels, has \(levels.count)")
        var last = 0
        var info: [String] = []
        for l in levels {
            guard let b = KlotskiBoard(layout: l.layout) else { fail("\(l.id): bad layout"); continue }
            let t = Date()
            let path = KlotskiSolver.solve(b)
            worst = max(worst, Date().timeIntervalSince(t))
            guard let path else { fail("\(l.id): unsolvable"); continue }
            expect(path.count == l.minMoves, "\(l.id): stored min \(l.minMoves) but solver says \(path.count)")
            expect(spec.minRange.contains(l.minMoves), "\(l.id): \(l.minMoves) is outside \(spec.minRange)")
            expect(l.minMoves >= last, "\(l.id): not in order")
            last = l.minMoves
            expect(l.layout.first(where: { $0 == "B" }) != nil && b.bunny != nil, "\(l.id): has a bunny")
            expect(!b.solved, "\(l.id): already solved")
            expect(l.starBound >= l.minMoves + 3 && l.starBound >= l.minMoves * 3 / 2, "\(l.id): star bound")
            // 重复（包括镜像）
            for k in [b.key, b.mirrored.key] {
                if let other = seen[k] { fail("\(l.id) duplicates \(other)") }
            }
            seen[b.key] = l.id
            seen[b.mirrored.key] = l.id
            // 镜像也是同样的最少步数
            expect(KlotskiSolver.minMoves(b.mirrored) == l.minMoves, "\(l.id): mirror has a different minimum")
            // 提示：沿着提示一直走，每一步都让最少步数少一步；中途随便走错一步以后，提示仍然给出最短路
            var cur = b
            var left = l.minMoves
            var good = true
            while !cur.solved, let m = KlotskiSolver.bestMove(cur) {
                cur = cur.applying(m)
                left -= 1
                if KlotskiSolver.minMoves(cur) != left { good = false; break }
            }
            expect(good && cur.solved && left == 0, "\(l.id): hint does not follow a shortest path")
            if let wrong = b.allMoves.first(where: { b.applying($0).key != path.first.map({ b.applying($0).key }) }) {
                let after = b.applying(wrong)
                expect(KlotskiSolver.bestMove(after) != nil || after.solved, "\(l.id): hint after a wrong move")
            }
            info.append("\(l.minMoves)")
            total += 1
        }
        print("  \(spec.id)（\(spec.name)）\(levels.count) 关，最少步数 \(info.joined(separator: " "))")
    }
    // 提示要快：最慢的一次求解
    print("  \(total) 关，最慢的一关求解 \(Int(worst * 1000)) 毫秒")
    expect(worst < 1.0, "solving is too slow: \(worst)s")
    // 只有横刀立马有名字
    expect(KlotskiCatalog.levels.contains { $0.name == "横刀立马" && $0.layout == classic }, "横刀立马 is in the classic pack")
}

// MARK: 4. 教学

print("[教学]")
let banned = ["左", "右", "横", "竖", "上面", "下面", "上边", "下边", "往上", "往下", "上方", "下方", "上下"]
let numerals: [Int: [String]] = [1: ["一"], 2: ["两", "二"], 3: ["三"], 4: ["四"], 5: ["五"], 6: ["六"], 7: ["七"], 8: ["八"]]
let course = loadCourse(root, "klotski")

func validMark(_ m: String) -> Bool {
    let p = m.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
    switch p.first {
    case "door": return p.count == 1
    case "glow", "ring": return p.count == 2 && KlotskiCellName.parse(p[1]) != nil
    case "arrow": return p.count == 4 && KlotskiCellName.parse(p[1]) != nil && p[2].count == 1 && KlotskiDir(letter: p[2].first!) != nil && Int(p[3]) != nil
    default: return false
    }
}

/// 检查一课里的每一步；返回走了多少道题
@discardableResult
func checkSteps(_ id: String, _ steps: [TutorialStep], practice: Bool) -> Int {
    var board: KlotskiBoard?
    var tasks = 0
    for (i, s) in steps.enumerated() {
        let tag = "\(id) step \(i + 1)"
        if let spec = s.board {
            if let b = KlotskiBoard(layout: spec) { board = b } else { fail("\(tag): bad board \(spec)") }
        } else if board == nil {
            fail("\(tag): no board yet")
        }
        for m in s.marks ?? [] { expect(validMark(m), "\(tag): bad mark \(m)") }
        if let m = s.marks, let b = board {
            for x in m {
                let p = x.split(separator: ":").map(String.init)
                if p.first == "glow", let c = KlotskiCellName.parse(p[1]) { expect(b.pieceAt(x: c.x, y: c.y) != nil, "\(tag): glow on an empty cell \(x)") }
                if p.first == "arrow", let c = KlotskiCellName.parse(p[1]), let d = KlotskiDir(letter: p[2].first!), let n = Int(p[3]),
                   let pi = b.pieceAt(x: c.x, y: c.y) {
                    expect(b.maxSlide(pi, d) >= n, "\(tag): arrow \(x) points where the block cannot go")
                }
            }
        }
        guard let task = s.task, let b = board else { continue }
        tasks += 1
        let rule = task.rule ?? ""
        expect(task.type == "slide" || task.type == "pick", "\(tag): task type \(task.type)")
        if !practice {
            expect(s.hint?.isEmpty == false, "\(tag): task has no hint")
            expect(s.drill?.isEmpty == false, "\(tag): task has no drill")
        }
        if let d = s.drill {
            for w in banned where d.contains(w) { fail("\(tag): drill mentions 「\(w)」: \(d)") }
            expect(!d.unicodeScalars.contains { $0.value >= 65 && $0.value <= 90 }, "\(tag): drill has a letter: \(d)")
        }
        if task.type == "pick" {
            let cells = KlotskiLessonLogic.pickCells(task, on: b)
            expect(!cells.isEmpty, "\(tag): pick \(rule) has no accepted cell")
            expect(cells.count < KlotskiBoard.cols * KlotskiBoard.rows - b.emptyCells.count + (rule == "cells" ? 20 : 0), "\(tag): pick accepts everything")
            for y in 0..<KlotskiBoard.rows { for x in 0..<KlotskiBoard.cols {
                expect(KlotskiLessonLogic.pickCheck(task, on: b, x: x, y: y) == cells.contains(y * 4 + x), "\(tag): pickCheck")
            } }
            let reveal = KlotskiLessonLogic.revealMarks(task, start: b, moves: [])
            expect(!reveal.isEmpty && reveal.allSatisfy(validMark), "\(tag): reveal marks")
            for a in task.accept ?? [] { expect(KlotskiCellName.parse(a) != nil, "\(tag): accept \(a)") }
            continue
        }
        // 滑的题：起点不能已经做到；要有答案；答案真的能做对
        let parts = KlotskiLessonLogic.parts(task)
        if ["at", "bunnyAt", "empty", "free"].contains(parts.head) {
            expect(!KlotskiLessonLogic.satisfied(task, start: b, board: b), "\(tag): already satisfied at the start")
        }
        if parts.head == "bunnyAt" || parts.head == "at" {
            for a in parts.args { if let c = KlotskiCellName.parse(a) { _ = c } }
        }
        guard let ans = KlotskiLessonLogic.answer(task, start: b, moves: []) else { fail("\(tag): \(rule) has no answer"); continue }
        var played: [KlotskiMove] = []
        var verdict = KlotskiLessonLogic.Verdict.progress
        for m in ans {
            expect(b.applying(contentsOf: played).canApply(m), "\(tag): answer move is illegal")
            expect(KlotskiLessonLogic.permits(task, start: b, move: m), "\(tag): answer move is not permitted")
            played.append(m)
            verdict = KlotskiLessonLogic.judge(task, start: b, moves: played)
        }
        if parts.head == "undo" {
            expect(ans.count == 1 && b.allMoves.contains(ans[0]), "\(tag): undo needs a move")
        } else {
            expect(verdict == .solved, "\(tag): answer does not solve \(rule): \(verdict)")
            expect(ans.count <= KlotskiLessonLogic.moveLimit(task), "\(tag): answer longer than the limit")
        }
        if parts.head == "free", let n = Int(parts.args.first ?? "") {
            expect(KlotskiSolver.minMoves(b) == n, "\(tag): free:\(n) but the minimum is \(String(describing: KlotskiSolver.minMoves(b)))")
            expect(ans.count == n, "\(tag): answer has \(ans.count) moves, rule says \(n)")
            let text = practice ? (s.drill ?? "") : s.say
            expect(numerals[n]?.contains { text.contains($0 + "步") } == true, "\(tag): text should say \(n) 步: \(text)")
            expect(b.solved == false, "\(tag): solved at start")
        }
        // 错的做法要判错：一步都没动就算没做完；做对以后再多走一步（free）也不会误判
        if parts.head == "move" || parts.head == "far" {
            let wrong = b.allMoves.filter { m in KlotskiLessonLogic.permits(task, start: b, move: m) && KlotskiLessonLogic.judge(task, start: b, moves: [m]) == .wrong }
            expect(!wrong.isEmpty, "\(tag): \(rule) has no wrong move to test")
        }
        // 答案的标记
        let reveal = KlotskiLessonLogic.revealMarks(task, start: b, moves: [])
        expect(parts.head == "undo" || (!reveal.isEmpty && reveal.allSatisfy(validMark)), "\(tag): reveal marks \(reveal)")
        // 走了一步之后，答案还能接着给（free）
        if parts.head == "free", ans.count >= 2 {
            let rest = KlotskiLessonLogic.answer(task, start: b, moves: [ans[0]])
            expect(rest?.count == ans.count - 1, "\(tag): answer after the first move")
        }
        // 这一步以后接着的盘面：做完题的盘面（后面没有 board 的步骤接着用）
        board = b.applying(contentsOf: ans)
    }
    return tasks
}

extension KlotskiBoard {
    func applying(contentsOf moves: [KlotskiMove]) -> KlotskiBoard { moves.reduce(self) { $0.applying($1) } }
}

do {
    expect(course.tracks.first?.id == "basic", "first track is basic")
    expect(course.tracks.count >= 3, "at least 3 tracks")
    expect(course.lessons.count >= 10, "at least 10 lessons, has \(course.lessons.count)")
    expect(Set(course.lessons.map(\.id)).count == course.lessons.count, "lesson ids unique")
    for t in course.tracks {
        expect(t.art == "tutor_klotski_\(t.id)", "track art name \(t.id)")
        for l in t.lessons {
            let n = checkSteps(l.id, l.steps, practice: false)
            expect(n >= 2, "\(l.id): needs at least 2 tasks, has \(n)")
            expect((4...8).contains(l.steps.count), "\(l.id): 4–8 steps, has \(l.steps.count)")
            expect(!l.learned.isEmpty, "\(l.id): learned")
        }
    }
    let kit = KlotskiTutorial.kit
    for (n, pack) in kit.playLevels { expect(KlotskiCatalog.packs.indices.contains(pack - 1), "playLevels \(n) → pack \(pack)") }
    expect(course.tracks.allSatisfy { kit.playLevels[$0.id] != nil }, "every track has a play level")
    expect(kit.goPlayLine == "这一组学完啦，去闯关吧！" && kit.goPlayTitle == "去闯关", "go play texts")
    print("  \(course.lessons.count) 课，\(course.lessons.reduce(0) { $0 + $1.steps.filter { $0.task != nil }.count }) 道题")
}

// MARK: 5. 练一练

print("[练一练]")
do {
    let kit = KlotskiTutorial.kit
    var variants = 0, practised = 0, all = 0
    var rng = SplitMix(state: 3)
    for l in course.lessons {
        let taskCount = l.steps.filter { $0.task != nil }.count
        all += taskCount
        let segs = LessonPractice.segments(l, game: "klotski")
        let inSegs = segs.reduce(0) { $0 + LessonPractice.taskCount($1) }
        practised += inSegs
        expect(inSegs == taskCount, "\(l.id): only \(inSegs) of \(taskCount) tasks can be practised")
        for (si, seg) in segs.enumerated() {
            expect(seg.first?.board != nil, "\(l.id): segment starts without a board")
            for k in 0..<kit.practiceVariants {
                let steps = k == 0 ? seg : kit.practiceTransform!(seg, k)
                checkSteps("\(l.id)~练习\(si + 1)~变换\(k)", steps, practice: true)
                variants += 1
                for s in steps {
                    if let say = Optional(s.say) { for w in banned where say.contains(w) { fail("\(l.id) practice step says 「\(w)」: \(say)") } }
                }
            }
            // 镜像两次变回原样
            let twice = KlotskiMirror.steps(KlotskiMirror.steps(seg, 1), 1)
            expect(twice == seg, "\(l.id): mirror twice is not the identity")
        }
        if let p = LessonPractice.practiceLesson(l, game: "klotski", using: &rng) {
            expect(p.steps.count == inSegs, "\(l.id): practice lesson has every task")
        }
    }
    // 镜像真的换了位置（小兔不在正中的盘面）
    let mirrored = KlotskiMirror.layout(".BB./.BB./.V../.V../....")
    expect(mirrored == ".BB./.BB./..V./..V./....", "mirror layout")
    expect(KlotskiMirror.mark("arrow:a3:r:2") == "arrow:d3:l:2" && KlotskiMirror.mark("ring:b5") == "ring:c5" && KlotskiMirror.mark("door") == "door", "mirror marks")
    expect(KlotskiMirror.rule("move:b3:l:1") == "move:c3:r:1" && KlotskiMirror.rule("empty:b3,c3") == "empty:c3,b3" && KlotskiMirror.rule("free:3") == "free:3"
           && KlotskiMirror.rule("at:a3:b5") == "at:d3:c5" && KlotskiMirror.rule("kind:tall") == "kind:tall", "mirror rules")
    // 复习：从学过的课里抽题
    var cups: [String: LessonCup] = [:]
    for l in course.lessons { cups[l.id] = .bronze }
    for _ in 0..<20 {
        if let r = LessonPractice.reviewLesson(course, cups: cups, using: &rng) {
            expect(r.steps.filter { $0.task != nil }.count == 5, "review has 5 tasks")
            checkSteps("review", r.steps, practice: true)
        } else { fail("no review lesson") }
    }
    print("  \(practised)/\(all) 道题能练，\(variants) 种样子（每段 × 原样 / 镜像）都有答案")
    // 通用说法也不提方向
    for (_, v) in kit.practicePrompts { for w in banned where v.contains(w) { fail("generic prompt mentions \(w): \(v)") } }
}

// MARK: 6. 配音

print("[配音]")
do {
    struct Extra: Decodable { var lines: [String]; var replace: [[String]]; var regex: [[String]] }
    let data = try! Data(contentsOf: URL(fileURLWithPath: root + "/tools/voice/extra_klotski.json"))
    let extra = try! JSONDecoder().decode(Extra.self, from: data)
    expect(extra.lines == KlotskiTutorial.kit.fixedLines, "extra_klotski.json lines must equal KlotskiTutorial.kit.fixedLines")
    // 课文里不能出现多音字风险：用 得（děi）、重来、一行
    for l in course.lessons {
        var texts = [TutorLines.lessonDone(l.learned)]
        for s in l.steps { texts += [s.say] + [s.hint, s.ok, s.after, s.drill].compactMap { $0 } }
        for t in texts {
            for bad in ["得先", "得要", "重来", "重新", "一行", "行了", "着急", "数一数"] where t.contains(bad) { fail("\(l.id): risky reading「\(bad)」in: \(t)") }
            for pair in extra.replace where t.contains(pair[0]) { _ = pair }
            expect(!t.isEmpty, "empty text")
        }
    }
    expect(extra.replace.contains { $0 == ["空", "控"] }, "空 is read kòng")
}

print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
