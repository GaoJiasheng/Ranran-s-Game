import Foundation

// 编程的命令行测试：zsh tools/coding/test.sh（全部通过时最后一行是 ALL PASSED）
//   1. 程序：文字写法来回、积木数、套法的规矩、编辑
//   2. 解释器：撞到、走完、转晕、家、如果、绝招、一直重复
//   3. 关卡：每一关的性质（见 docs/tutorial-coding.md「每一关都要满足」），打印关卡表
//   4. 页面尺寸：每一关在四种 iPad 上、横竖屏，积木不小于 56 点
//   5. 教学：每道题 × 四种样子都由解释器判出唯一的答案，提示和答案对得上，drill 不提方向 / 位置 / 数字
//   6. 配音：固定台词和 extra_coding.json 一致，多音字都换掉了

let root = CommandLine.arguments[1]
let only = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : ""
/// 只查 id 以它开头的关（设计关卡时用）
let levelFilter = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : ""
setvbuf(stdout, nil, _IONBF, 0)
/// 穷举一关最多花几秒（环境变量 CODING_DEADLINE 可以改）
let deadlineSeconds = Double(ProcessInfo.processInfo.environment["CODING_DEADLINE"] ?? "") ?? 150
var failures = 0
func fail(_ s: String) { failures += 1; print("  ❌ " + s) }
func expect(_ ok: Bool, _ what: @autoclosure () -> String) { if !ok { fail(what()) } }

func P(_ s: String) -> CodingProgram {
    guard let p = CodingProgram(text: s) else { fatalError("bad program \(s)") }
    return p
}

func G(_ s: String) -> CodingGarden {
    guard let g = CodingGarden(layout: s) else { fatalError("bad garden \(s)") }
    return g
}

// MARK: 1. 程序

if only.isEmpty || only == "unit" {
    print("[程序]")
    for s in ["R R U", "3[R U] R", "S 2[S R] ; S=R R U", "*[R ?b[U]]", "?y[D L] 2[?b[U] R]", "S T ; S=2[R] ; T=D D",
              "3[]", "*[]", "S ; S=U ?b[R]"] {
        let p = P(s)
        expect(p.text == s, "round trip \(s) → \(p.text)")
    }
    expect(P("2[R U] R").size == 4, "size 2[R U] R = 4")
    expect(P("S S ; S=R U").size == 4, "size S S ; S=R U = 4")
    expect(P("*[R ?b[U]]").size == 4, "size *[R ?b[U]] = 4")
    for bad in ["X", "3[R", "R]", "?c[U]", "S=R ; R", "3 [R]", "*R"] {
        expect(CodingProgram(text: bad) == nil, "rejects \(bad)")
    }
    let lim = CodingLimits(spec: "main=4 loop=2 proc=3 when=1 | U D L R rep S ?b *")!
    expect(lim.trackCount == 2, "track count")
    expect(CodingRules.fits(P("2[R ?b[U]] S ; S=2[U] R"), lim), "fits nested")
    expect(!CodingRules.fits(P("2[2[R]]"), lim), "no repeat in repeat")
    expect(!CodingRules.fits(P("?b[2[R]]"), lim), "no repeat in if")
    expect(!CodingRules.fits(P("?b[R U]"), lim), "if body limit")
    expect(!CodingRules.fits(P("*[R] R"), lim), "forever must be last")
    expect(!CodingRules.fits(P("2[*[R]]"), lim), "forever only top level")
    expect(!CodingRules.fits(P("S ; S=S"), lim), "no call in proc")
    expect(!CodingRules.fits(P("R R R R R"), lim), "main slots")
    expect(!CodingRules.fits(P("1[R]"), lim), "repeat count 2–9")
    expect(!CodingRules.fits(P("T ; T=R"), lim), "◆ not in palette")
    // 编辑：放进去、拿出来
    var p = CodingProgram()
    expect(CodingRules.check(.loop, at: CodingSlot(track: 0, container: [], index: 0), in: p, limits: lim) == nil, "can place loop")
    _ = p.insert(.loop(3, []), at: CodingSlot(track: 0, container: [], index: 0))
    expect(CodingRules.check(.loop, at: CodingSlot(track: 0, container: [0], index: 0), in: p, limits: lim) == .notHere, "no loop in loop")
    expect(CodingRules.check(.arrow(.right), at: CodingSlot(track: 0, container: [0], index: 0), in: p, limits: lim) == nil, "arrow in loop")
    _ = p.insert(.move(.right), at: CodingSlot(track: 0, container: [0], index: 0))
    _ = p.insert(.when(.blue, []), at: CodingSlot(track: 0, container: [0], index: 1))
    expect(CodingRules.check(.arrow(.up), at: CodingSlot(track: 0, container: [0], index: 2), in: p, limits: lim) == .full, "loop full")
    _ = p.insert(.move(.up), at: CodingSlot(track: 0, container: [0, 1], index: 0))
    expect(p.text == "3[R ?b[U]]", "built \(p.text)")
    expect(CodingRules.check(.forever, at: CodingSlot(track: 0, container: [], index: 0), in: p, limits: lim) == .notHere, "forever must go last")
    expect(CodingRules.check(.forever, at: CodingSlot(track: 0, container: [], index: 1), in: p, limits: lim) == nil, "forever at end")
    _ = p.insert(.forever([]), at: CodingSlot(track: 0, container: [], index: 1))
    expect(CodingRules.check(.arrow(.up), at: CodingSlot(track: 0, container: [], index: 2), in: p, limits: lim) == .notHere, "nothing after forever")
    expect(p.remove(at: CodingRef(track: 0, path: [0, 1])) == .when(.blue, [.move(.up)]), "remove shell with contents")
    expect(p.text == "3[R] *[]", "after remove \(p.text)")
    expect(p.allRefs.count == 3, "refs")
    expect(P("3[R U] L ; S=D").flipped(1).text == "3[L U] R ; S=D" && P("3[R U] L").flipped(3).text == "3[L D] R", "flip arrows")

    // MARK: 2. 解释器

    print("[解释器]")
    let g = G("...../B.#C./.....")
    expect(CodingMachine.outcome(P("R R"), in: g) == .bump, "bump into rock")
    expect(CodingMachine.outcome(P("L"), in: g) == .bump, "bump into edge")
    expect(CodingMachine.outcome(P("R U R R D"), in: g) == .success, "around the rock")
    expect(CodingMachine.outcome(P("R U R R D L L"), in: g) == .success, "extra blocks after the last carrot are fine")
    expect(CodingMachine.outcome(P("R U R R"), in: g) == .end, "program ends")
    expect(CodingMachine.outcome(P("*[R L]"), in: g) == .dizzy, "forever gets dizzy")
    expect(CodingMachine.outcome(P("*[?b[U]]"), in: g) == .dizzy, "forever with no moves gets dizzy")
    let t = CodingMachine.trace(P("R R"), in: g)
    expect(t.events.count == 2 && t.culprit == CodingRef(track: 0, path: [1]), "bump culprit")
    let home = G("BCH..")
    expect(CodingMachine.outcome(P("R"), in: home) == .end, "home: carrot alone is not enough")
    expect(CodingMachine.outcome(P("R R"), in: home) == .success, "home after carrots")
    let passHome = G("BHC..")
    expect(CodingMachine.outcome(P("R R L"), in: passHome) == .success && CodingMachine.outcome(P("R R"), in: passHome) == .end,
           "passing home before the carrots does not count")
    let fl = G("BbC/..y")
    expect(CodingMachine.outcome(P("R ?y[D] ?b[R]"), in: fl) == .success, "if blue")
    let tr = CodingMachine.trace(P("R ?y[D] ?b[R]"), in: fl)
    expect(tr.events.map(\.kind) == [.move(.right, ate: false), .check(.yellow, hit: false), .check(.blue, hit: true), .move(.right, ate: true)],
           "if checks are events")
    let call = CodingMachine.trace(P("2[S] ; S=R"), in: G("B.C"))
    expect(call.passed && call.events.count == 2 && call.events[1].stack == [CodingRef(track: 0, path: [0]), CodingRef(track: 0, path: [0, 0])]
           && call.events[1].ref == CodingRef(track: 1, path: [0]) && call.events[1].iterations[CodingRef(track: 0, path: [0])] == 2,
           "call stack and iterations")
    expect(G("B.#/C.y").flipped(1).layout == "#.B/y.C" && G("B.#/C.y").flipped(2).layout == "C.y/B.#", "flip garden")
}

// MARK: 3. 关卡

/// 一关的难度分（用来查"难度不倒退"）：par、用到几种积木、花园个数、花园大小
func difficulty(_ l: CodingLevel) -> Double {
    let kinds = l.answerProgram.pieces.count
    let gs = l.gardenList
    return Double(l.par) + 1.5 * Double(kinds) + 2 * Double(gs.count - 1) + Double(gs.map(\.area).max() ?? 0) / 12
        + 2 * Double(depth(l.answerProgram))
}

/// 套了几层：重复、如果、一直重复、叫绝招，各算一层
func depth(_ p: CodingProgram) -> Int {
    func d(_ l: [CodingBlock]) -> Int {
        l.map { b -> Int in
            switch b {
            case let .call(q): return 1 + d(p.tracks[q.track])
            default: return b.body.map { 1 + d($0) } ?? 0
            }
        }.max() ?? 0
    }
    return d(p.main)
}

/// 胡乱排满箭头（主程序每一格都随便放一个箭头）能过的机会
func randomPass(_ l: CodingLevel) -> Double {
    let gs = l.gardenList
    let m = l.limitsValue.main
    let arrows = CodingDir.allCases.filter { l.limitsValue.palette.contains(.arrow($0)) }
    guard !arrows.isEmpty else { return 0 }
    var passes = 0.0
    func go(_ states: [CodingState], _ done: [Bool], _ depth: Int, _ weight: Double) {
        if done.allSatisfy({ $0 }) { passes += weight; return }
        if depth == m { return }
        for d in arrows {
            var ns = states, nd = done
            var bad = false
            for i in gs.indices where !done[i] {
                let (s, o) = CodingMachine.exec([.move(d)], program: CodingProgram(), garden: gs[i], from: states[i])
                if o == .bump { bad = true; break }
                ns[i] = s
                if o == .success { nd[i] = true }
            }
            if !bad { go(ns, nd, depth + 1, weight / Double(arrows.count)) }
        }
    }
    go(gs.map(CodingState.start), gs.map { _ in false }, 0, 1)
    return passes
}

/// 改动一块（换一块、删一块、加一块、改一个次数）就能过的改法
func oneEditFixes(_ p: CodingProgram, _ l: CodingLevel) -> [CodingProgram] {
    let lim = l.limitsValue, gs = l.gardenList
    var out: [CodingProgram] = []
    func consider(_ q: CodingProgram) {
        if CodingRules.fits(q, lim), q.size <= l.par, CodingMachine.passes(q, gs) { out.append(q) }
    }
    let simple = lim.palette.filter { !$0.isContainer }
    for r in p.allRefs {
        var d = p; d.remove(at: r); consider(d)
        guard let b = p.block(at: r) else { continue }
        if case let .loop(n, body) = b {
            for k in 2...9 where k != n { var q = p; _ = q.replace(at: r, with: .loop(k, body)); consider(q) }
        } else if b.body == nil {
            for s in simple where s.fresh != b { var q = p; _ = q.replace(at: r, with: s.fresh); consider(q) }
        }
    }
    // 加一块：每一层的每一个位置
    var containers: [(Int, [Int], Int)] = []
    for t in 0..<lim.trackCount { containers.append((t, [], p.tracks[t].count)) }
    for r in p.allRefs { if let body = p.block(at: r)?.body { containers.append((r.track, r.path, body.count)) } }
    for (t, c, n) in containers {
        for i in 0...n {
            for s in simple {
                var q = p
                if q.insert(s.fresh, at: CodingSlot(track: t, container: c, index: i)) { consider(q) }
            }
        }
    }
    return out
}

struct LevelRow {
    var id: String, name: String, kind: String, gardens: String, palette: String, slots: String, par: Int, answer: String, proof: String, random: Double
}

var levelRows: [LevelRow] = []

if only.isEmpty || only == "levels" {
    print("[关卡]")
    let levels = CodingCatalog.levels
    expect(Set(levels.map(\.id)).count == levels.count, "level ids unique")
    expect(CodingCatalog.packs.map(\.id) == ["seq", "loop", "func", "cond"], "pack ids")
    for pack in CodingCatalog.packs {
        expect(pack.levels.count == 12, "\(pack.id) has 12 levels")
        let prefix = pack.id
        for (i, id) in pack.levels.enumerated() { expect(id == String(format: "%@%02d", prefix, i + 1), "level id \(id)") }
        let bugs = pack.levels.compactMap(CodingCatalog.level).filter { $0.kind == .bug }.count
        expect((2...3).contains(bugs), "\(pack.id): 2–3 bug levels, got \(bugs)")
    }
    let t0 = Date()
    for pack in CodingCatalog.specs {
        let ls = levels.filter { $0.pack == pack.id }
        var prev: CodingLevel?
        for l in ls where l.id.hasPrefix(levelFilter) {
            guard let gs = CodingGardens.parse(l.gardens) else { fail("\(l.id): bad gardens"); continue }
            guard let lim = CodingLimits(spec: l.limits) else { fail("\(l.id): bad limits"); continue }
            guard let ans = CodingProgram(text: l.answer) else { fail("\(l.id): bad answer"); continue }
            let tag = l.id
            expect(gs.allSatisfy { $0.width <= 7 && $0.height <= 6 }, "\(tag): garden ≤ 7 × 6")
            expect(CodingRules.fits(ans, lim), "\(tag): answer \(l.answer) does not fit \(l.limits)")
            expect(ans.text == l.answer, "\(tag): answer written canonically (\(ans.text))")
            let res = gs.map { CodingMachine.outcome(ans, in: $0) }
            expect(res.allSatisfy { $0 == .success }, "\(tag): answer fails \(res)")
            expect(ans.size == l.par || ans.size >= l.par, "\(tag): answer size \(ans.size) < par \(l.par)")
            expect(ans.size == l.par, "\(tag): answer uses \(ans.size) blocks, par is \(l.par)")
            if pack.id == "cond" { expect(gs.count >= 1 && gs.count <= 3, "\(tag): 1–3 gardens") } else { expect(gs.count == 1, "\(tag): one garden") }
            expect(lim.when <= 2, "\(tag): if holds at most 2")
            // 只能用这一组和前面几组教过的积木
            let allowed: Set<String> = {
                switch pack.id {
                case "seq": ["U", "D", "L", "R"]
                case "loop": ["U", "D", "L", "R", "rep"]
                case "func": ["U", "D", "L", "R", "rep", "S", "T"]
                default: ["U", "D", "L", "R", "rep", "S", "T", "?b", "?y", "*"]
                }
            }()
            expect(lim.palette.allSatisfy { allowed.contains($0.token) }, "\(tag): palette uses blocks from a later pack")
            // par 是最少的：穷举积木数 ≤ par - 1 的全部程序
            var solver = CodingSolver(gardens: gs, limits: lim)
            solver.deadline = Date().addingTimeInterval(deadlineSeconds)
            let st = Date()
            let r = solver.minimal(budget: l.par - 1)
            let secs = Date().timeIntervalSince(st)
            var proof: String
            if let p = r.program {
                fail("\(tag): found a shorter program (\(p.size) blocks): \(p.text)")
                proof = "✗"
            } else if r.complete {
                proof = String(format: "穷举 %d 种 / %.1f 秒", r.expanded, secs)
            } else {
                proof = "穷举没做完（\(Int(secs)) 秒）：par = 参考答案"
                print("  ⚠️ \(tag): exhaustive search timed out; par is the reference size")
            }
            // 新想法用得上：不用它就放不进格子 / 过不了
            // 这一组的新想法：不用它，多少块都过不了；同一关里另加的积木（◆、黄花、一直重复）：不用它，par 块以内过不了
            func without(_ drop: Set<String>, budget: Int = 40) -> CodingProgram? {
                var lim2 = lim
                lim2.palette = lim.palette.filter { !drop.contains($0.token) }
                var s = CodingSolver(gardens: gs, limits: lim2)
                s.deadline = Date().addingTimeInterval(deadlineSeconds)
                let rr = s.minimal(budget: budget)
                if !rr.complete { print("  ⚠️ \(tag): necessity search without \(drop.sorted()) timed out") }
                return rr.program
            }
            switch pack.id {
            case "loop":
                if let p = without(["rep"]) { fail("\(tag): passable without repeat: \(p.text)") }
            case "func":
                if let p = without(["S", "T"]) { fail("\(tag): passable without 绝招: \(p.text)") }
                if lim.palette.contains(.call(.diamond)), let p = without(["T"], budget: l.par) { fail("\(tag): passable without ◆: \(p.text)") }
            case "cond":
                if let p = without(["?b", "?y"]) { fail("\(tag): passable without 如果: \(p.text)") }
                if lim.palette.contains(.when(.yellow)), lim.palette.contains(.when(.blue)) {
                    if let p = without(["?y"], budget: l.par) { fail("\(tag): passable without 黄花: \(p.text)") }
                }
                if lim.palette.contains(.forever), let p = without(["*"], budget: l.par) { fail("\(tag): passable without 一直重复: \(p.text)") }
            default:
                break
            }
            // 捉虫关
            if let given = l.given {
                if let gp = CodingProgram(text: given) {
                    expect(CodingRules.fits(gp, lim), "\(tag): given program does not fit")
                    expect(!CodingMachine.passes(gp, gs), "\(tag): given program already passes")
                    let fixes = oneEditFixes(gp, l)
                    expect(!fixes.isEmpty, "\(tag): no one-edit fix within par")
                    expect(fixes.contains(ans), "\(tag): the answer is not a one-edit fix of the given program")
                } else { fail("\(tag): bad given program") }
            }
            // 胡乱排满箭头
            let rp = randomPass(l)
            expect(rp < 0.03, "\(tag): random arrows pass \(String(format: "%.1f", rp * 100))%")
            // 难度不倒退
            if let prev {
                let a = difficulty(prev), b = difficulty(l)
                expect(b >= a - 1.6, "\(tag): difficulty drops from \(prev.id) (\(String(format: "%.1f → %.1f", a, b)))")
                let sameShape = prev.answer == l.answer && prev.kind == l.kind && prev.gardenList.count == gs.count
                expect(prev.gardens != l.gardens && !sameShape, "\(tag): almost the same as \(prev.id)")
            }
            prev = l
            let sizes = Set(gs.map { "\($0.width)×\($0.height)" }).sorted().joined(separator: ",")
            levelRows.append(LevelRow(id: l.id, name: l.name, kind: l.kind == .bug ? "捉虫" : "写程序",
                                      gardens: (gs.count > 1 ? "\(gs.count) 个 " : "") + sizes,
                                      palette: lim.palette.map(\.token).joined(separator: " "),
                                      slots: "主\(lim.main)" + (lim.palette.contains(.loop) || lim.palette.contains(.forever) ? " 重\(lim.loop)" : "")
                                        + (lim.hasProc ? " 招\(lim.proc)" : "") + (lim.palette.contains { if case .when = $0 { return true }; return false } ? " 如\(lim.when)" : ""),
                                      par: l.par, answer: l.answer + (l.given.map { "（给的：`\($0)`）" } ?? ""), proof: proof, random: rp))
            print("  \(l.id) par \(l.par) d=\(String(format: "%.1f", difficulty(l))) \(proof)  answer: \(l.answer)")
        }
    }
    print("  关卡用时 \(Int(Date().timeIntervalSince(t0))) 秒")
    print("")
    print("| 关 | 名字 | 类型 | 花园 | 积木盒 | 格子 | par | 参考答案 | par 怎么证明的 | 乱排箭头能过 |")
    print("|---|---|---|---|---|---|---|---|---|---|")
    for r in levelRows {
        let ans = r.answer.hasPrefix("`") ? r.answer : "`" + r.answer.replacingOccurrences(of: "（给的", with: "`（给的")
        let fixed = ans.contains("`（给的") ? ans : ans + "`"
        print("| \(r.id) | \(r.name) | \(r.kind) | \(r.gardens) | \(r.palette) | \(r.slots) | \(r.par) | \(fixed) | \(r.proof) | \(String(format: "%.2f%%", r.random * 100)) |")
    }
}

// MARK: 4. 页面尺寸

if only.isEmpty || only == "layout" {
    print("[页面尺寸]")
    var worst = (u: 999.0, cell: 999.0, pal: 999.0, what: "")
    for l in CodingCatalog.levels {
        let gs = l.gardenList, lim = l.limitsValue
        let cols = gs.map(\.width).max()!, rows = gs.map(\.height).max()!
        for d in CodingLayout.devices {
            let w = d.w - 2 * CodingLayout.playPadH, h = d.h - 2 * CodingLayout.playPadV
            let p = CodingLayout.plan(screen: .play, width: w, height: h, cols: cols, rows: rows, multi: gs.count > 1,
                                      limits: lim, paletteCount: lim.palette.count)
            if p.unit < worst.u { worst = (p.unit, worst.cell, worst.pal, "\(l.id) \(d.name)") }
            worst.cell = min(worst.cell, p.cell)
            worst.pal = min(worst.pal, p.palette.side)
            expect(p.unit >= 62, "\(l.id) \(d.name): blocks only \(Int(p.unit)) pt")
            expect(p.cell >= 50, "\(l.id) \(d.name): garden cell only \(Int(p.cell)) pt")
            expect(p.palette.side >= 60, "\(l.id) \(d.name): palette blocks only \(Int(p.palette.side)) pt")
        }
    }
    print("  闯关页面：最小的积木 \(Int(worst.u)) 点（\(worst.what)），最小的花园格子 \(Int(worst.cell)) 点，最小的积木盒 \(Int(worst.pal)) 点")

    // 教学：LessonScaffold 给棋盘的那一块小一点
    var lw = (u: 999.0, cell: 999.0, what: "", opt: 999.0)
    let course = loadCourse(root, "coding")
    for l in course.lessons {
        for (i, s) in l.steps.enumerated() {
            guard let gs = CodingLessonLogic.gardens(s) ?? l.steps[..<i].last(where: { $0.board != nil }).flatMap(CodingLessonLogic.gardens) else { continue }
            let lim = CodingLessonLogic.limits(s)
            let type = s.task?.type ?? ""
            let pal = type == "build" || type == "fix" ? lim.palette.count : 0
            for d in CodingLayout.devices {
                let b = CodingLayout.lessonBoard(w: d.w, h: d.h)
                let p = CodingLayout.plan(screen: .lesson, width: b.w, height: b.h, cols: gs.map(\.width).max()!, rows: gs.map(\.height).max()!,
                                          multi: gs.count > 1, limits: lim, paletteCount: pal,
                                          minProgramHeight: type == "choose" ? CodingLayout.optionsHeight(CodingLessonLogic.options(s), u: 60) : 0)
                if p.unit < lw.u { lw = (p.unit, lw.cell, "\(l.id) step \(i + 1) \(d.name)", lw.opt) }
                lw.cell = min(lw.cell, p.cell)
                expect(p.unit >= 56, "\(l.id) step \(i + 1) \(d.name): lesson blocks only \(Int(p.unit)) pt")
                expect(p.cell >= 44, "\(l.id) step \(i + 1) \(d.name): lesson garden cell only \(Int(p.cell)) pt")
                if pal > 0 { expect(p.palette.side >= 60, "\(l.id) step \(i + 1) \(d.name): lesson palette \(Int(p.palette.side)) pt") }
                if type == "choose" {
                    let ou = CodingLayout.optionUnit(options: CodingLessonLogic.options(s), width: p.programWidth, height: p.programHeight, cap: p.unit)
                    expect(ou >= 44, "\(l.id) step \(i + 1) \(d.name): choose options only \(Int(ou)) pt")
                    lw.opt = min(lw.opt, ou)
                }
            }
        }
    }
    print("  教学：最小的积木 \(Int(lw.u)) 点（\(lw.what)），最小的花园格子 \(Int(lw.cell)) 点，选程序的题里最小的积木 \(Int(lw.opt)) 点")
}

// MARK: 3b. 提示

if only.isEmpty || only == "levels" {
    print("[提示]")
    // 从空程序（捉虫关从给的程序）开始，照着提示一块一块做，一定能走到参考答案；捉虫关第一下就圈出有虫子的那一块
    for l in CodingCatalog.levels where l.id.hasPrefix(levelFilter) {
        var p = l.startProgram
        let ref = l.answerProgram
        var steps = 0
        if l.kind == .bug {
            if case .ring = CodingHint.next(current: p, reference: ref) {} else { fail("\(l.id): first hint on a bug level should ring a block") }
        }
        while steps < 60 {
            steps += 1
            switch CodingHint.next(current: p, reference: ref) {
            case let .ghost(g, slot):
                expect(CodingRules.fits(g, l.limitsValue), "\(l.id): hint ghost does not fit")
                guard let b = g.block(at: slot.ref) else { fail("\(l.id): ghost slot"); steps = 99; break }
                expect(CodingRules.check(b.piece, at: slot, in: p, limits: l.limitsValue) == nil, "\(l.id): hint asks for a block that cannot go there")
                _ = p.insert(b.body == nil ? b : b.withBody([]), at: slot)
                if case let .loop(n, _) = b, case .loop? = p.block(at: slot.ref) { _ = p.replace(at: slot.ref, with: .loop(n, [])) }
            case let .ring(r):
                p.remove(at: r)
            case .none:
                steps = 100
            }
        }
        expect(p == ref, "\(l.id): following the hints reaches \(p.text), not the answer")
    }
}

// MARK: 5. 教学

/// 练习说明里不能有的字：方向、位置、数字（"点一下""一个"里的"一""下"不算）
let drillBanned = ["左", "右", "往上", "往下", "向上", "向下", "上面", "下面", "上边", "下边", "朝", "横", "竖", "第",
                   "二", "三", "四", "五", "六", "七", "八", "九", "十", "两", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
                   "格", "角"]

var allSpoken: [String] = []

/// 一道题：用解释器判出答案，核对 claim。返回 nil = 没问题
func checkTask(_ s: TutorialStep, _ tag: String) {
    guard let task = s.task else { return }
    guard let gs = CodingLessonLogic.gardens(s) else { fail("\(tag): task step without a garden"); return }
    let lim = CodingLessonLogic.limits(s)
    let prog = CodingLessonLogic.program(s)
    if let e = CodingLessonLogic.extra(s, "program"), CodingProgram(text: e) == nil { fail("\(tag): bad program \(e)") }
    if let e = CodingLessonLogic.extra(s, "limits"), CodingLimits(spec: e) == nil { fail("\(tag): bad limits \(e)") }
    expect(CodingRules.fits(prog, lim), "\(tag): program \(prog.text) does not fit \(lim.spec)")
    expect(gs.allSatisfy { $0.width <= 7 && $0.height <= 6 }, "\(tag): garden too big")
    var claims: [String: String] = [:]
    for c in (CodingLessonLogic.extra(s, "claim") ?? "").split(separator: ",") {
        let kv = c.split(separator: "=").map(String.init)
        if kv.count == 2 { claims[kv[0]] = kv[1] }
    }
    let run = CodingRunResult.run(prog, gs)
    let firstBad = run.traces.first { !$0.passed }
    if let o = claims["outcome"] { expect((firstBad?.outcome ?? .success).rawValue == o, "\(tag): outcome is \(firstBad?.outcome.rawValue ?? "success"), claim says \(o)") }
    if let c = claims["culprit"] { expect(firstBad?.culprit.map(CodingLessonLogic.refText) == c, "\(tag): culprit claim \(c)") }
    switch task.type {
    case "build", "fix":
        guard let ans = CodingLessonLogic.answer(s) else { fail("\(tag): no answer"); return }
        expect(CodingRules.fits(ans, lim), "\(tag): answer \(ans.text) does not fit \(lim.spec)")
        expect(CodingLessonLogic.judge(ans, s) == .pass, "\(tag): answer \(ans.text) is judged \(CodingLessonLogic.judge(ans, s))")
        expect(CodingLessonLogic.judge(prog, s) != .pass, "\(tag): the starting program already passes")
        if task.type == "fix" { expect(!prog.isEmpty, "\(tag): fix without a program") }
        if let n = claims["size"].flatMap(Int.init) {
            expect(ans.size == n, "\(tag): answer size \(ans.size), claim says \(n)")
            // 题里说"排几块"，就真的是最少几块（一个箭头、一块重复……）
            var sv = CodingSolver(gardens: gs, limits: lim)
            sv.deadline = Date().addingTimeInterval(20)
            let shorter = sv.minimal(budget: n - 1)
            expect(shorter.program == nil, "\(tag): a shorter program exists: \(shorter.program?.text ?? "")")
        }
        if let n = claims["count"].flatMap(Int.init) {
            let counts = ans.allRefs.compactMap { r -> Int? in if case let .loop(k, _)? = ans.block(at: r) { return k }; return nil }
            expect(counts.contains(n), "\(tag): answer has no repeat of \(n)")
        }
    case "predict":
        guard let c = CodingLessonLogic.predictCell(s) else { fail("\(tag): no predict answer"); return }
        expect(gs[0].inside(c.x, c.y), "\(tag): predict cell outside")
        expect(claims["cell"] == c.name, "\(tag): predict answer is \(c.name), claim says \(claims["cell"] ?? "-")")
        expect(!prog.isEmpty, "\(tag): predict without a program")
    case "spot":
        let refs = CodingLessonLogic.spotRefs(s)
        expect(refs.count == 1, "\(tag): spot has \(refs.count) answers \(refs.map(CodingLessonLogic.refText))")
        if let c = claims["spot"] { expect(refs.map(CodingLessonLogic.refText) == [c], "\(tag): spot answer \(refs.map(CodingLessonLogic.refText)), claim says \(c)") }
        expect(!CodingMachine.passes(prog, gs), "\(tag): spot program already passes")
    case "choose":
        let opts = CodingLessonLogic.options(s)
        expect(opts.count >= 2 && opts.count <= 3, "\(tag): 2–3 options")
        expect(opts.allSatisfy { CodingRules.fits($0, lim) }, "\(tag): an option does not fit")
        guard let i = CodingLessonLogic.chooseIndex(s) else { fail("\(tag): choose does not have exactly one passing option"); return }
        expect(claims["option"] == String(i + 1), "\(tag): option \(i + 1) passes, claim says \(claims["option"] ?? "-")")
    case "count":
        let cs = CodingLessonLogic.counts(s)
        expect(cs.count >= 2 && cs.count <= 4, "\(tag): 2–4 counts")
        expect(cs.allSatisfy { n in CodingLessonLogic.countProgram(s, n).map { CodingRules.fits($0, lim) } ?? false }, "\(tag): a count program does not fit")
        guard let a = CodingLessonLogic.countAnswer(s) else { fail("\(tag): count does not have exactly one answer"); return }
        expect(claims["answer"] == String(a), "\(tag): count answer \(a), claim says \(claims["answer"] ?? "-")")
    default:
        fail("\(tag): unknown task type \(task.type)")
    }
    for m in s.marks ?? [] {
        let p = m.split(separator: ":", maxSplits: 1).map(String.init)
        if p.first == "glow" || p.first == "ring" {
            expect(p.count == 2 && CodingCell(name: p[1]).map { gs[0].inside($0.x, $0.y) } == true, "\(tag): mark \(m)")
        } else if p.first == "block" {
            expect(p.count == 2 && CodingLessonLogic.ref(p[1]).flatMap { prog.block(at: $0) } != nil, "\(tag): mark \(m)")
        } else { fail("\(tag): unknown mark \(m)") }
    }
}

if only.isEmpty || only == "lessons" {
    print("[教学]")
    let course = loadCourse(root, "coding")
    expect(course.tracks.map(\.id) == ["basic", "loop", "func", "cond"], "track ids \(course.tracks.map(\.id))")
    expect((18...24).contains(course.lessons.count), "about 20 lessons, got \(course.lessons.count)")
    expect(Set(course.lessons.map(\.id)).count == course.lessons.count, "lesson ids unique")
    var tasks = 0, variants = 0
    var types: [String: Int] = [:]
    for t in course.tracks {
        expect(t.art == "tutor_coding_\(t.id)", "\(t.id): art name")
        for l in t.lessons {
            let tag = l.id
            expect((4...8).contains(l.steps.count), "\(tag): 4–8 steps, got \(l.steps.count)")
            let ts = l.steps.filter { $0.task != nil }
            expect(ts.count >= 2, "\(tag): at least 2 tasks")
            expect(!l.learned.isEmpty, "\(tag): learned")
            allSpoken.append(TutorLines.lessonDone(l.learned))
            for (i, s) in l.steps.enumerated() {
                let st = "\(tag) step \(i + 1)"
                allSpoken += [s.say, s.hint, s.ok, s.after, s.drill].compactMap { $0 }
                if let b = s.board { expect(CodingGardens.parse(b) != nil, "\(st): bad garden \(b)") }
                if let e = s.extra?["program"] { expect(CodingProgram(text: e) != nil, "\(st): bad program \(e)") }
                guard let task = s.task else { continue }
                tasks += 1
                types[task.type, default: 0] += 1
                expect(s.board != nil, "\(st): every task brings its own garden (练一练 needs it)")
                expect(s.hint?.isEmpty == false, "\(st): no hint")
                guard let d = s.drill, !d.isEmpty else { fail("\(st): no drill"); continue }
                for w in drillBanned where d.contains(w) { fail("\(st): drill mentions「\(w)」: \(d)") }
                checkTask(s, st)
            }
            // 练一练：每一段 × 四种样子
            for (si, seg) in LessonPractice.segments(l, game: "coding").enumerated() {
                for k in 0..<CodingTutorial.kit.practiceVariants {
                    let v = CodingLessonLogic.flip(seg, k)
                    for (j, s) in v.enumerated() { checkTask(s, "\(tag) 练习\(si + 1).\(j + 1) 样子\(k)"); variants += 1 }
                    if k > 0 { expect(CodingLessonLogic.flip(v, k) == seg, "\(tag): flipping twice gives the original") }
                }
            }
            expect(LessonPractice.canPractice(l, game: "coding"), "\(tag): practisable")
            // 基础组：花园不超过 5×4、程序不超过 8 块；重复那一组的次数不超过 6
            for s in l.steps {
                if t.id == "basic", let gs = CodingLessonLogic.gardens(s) {
                    expect(gs.allSatisfy { $0.width <= 5 && $0.height <= 4 }, "\(tag): basic garden larger than 5×4")
                }
                let progs = [CodingLessonLogic.program(s), CodingLessonLogic.answer(s)].compactMap { $0 } + CodingLessonLogic.options(s)
                if t.id == "basic" { expect(progs.allSatisfy { $0.size <= 8 }, "\(tag): basic program longer than 8 blocks") }
                if t.id == "loop" {
                    let counts = progs.flatMap { p in p.allRefs.compactMap { r -> Int? in if case let .loop(k, _)? = p.block(at: r) { return k }; return nil } }
                    expect(counts.allSatisfy { $0 <= 6 } && CodingLessonLogic.counts(s).allSatisfy { $0 <= 6 }, "\(tag): repeat count above 6")
                }
            }
        }
    }
    let kit = CodingTutorial.kit
    expect(kit.playLevels == ["basic": 1, "loop": 2, "func": 3, "cond": 4], "play levels")
    expect(kit.goPlayLine == "这一组学完啦，去闯关吧！" && kit.goPlayTitle == "去闯关", "go play line")
    expect(CodingCatalog.passPacks == 2, "pass packs")
    print("  \(course.lessons.count) 课，\(tasks) 道题（\(types.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: "、"))），练一练 \(variants) 道题 × 样子都判过")
}

// MARK: 6. 配音

if only.isEmpty || only == "lessons" {
    print("[配音]")
    let kit = CodingTutorial.kit
    let data = try! Data(contentsOf: URL(fileURLWithPath: root + "/tools/voice/extra_coding.json"))
    let extra = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    let lines = extra["lines"] as? [String] ?? []
    expect(lines == kit.fixedLines, "extra_coding.json lines must equal CodingTutorial.kit.fixedLines")
    let drills = Set(allSpoken)
    for p in kit.practicePrompts.values { expect(kit.fixedLines.contains(p) || drills.contains(p), "practice prompt not recorded: \(p)") }
    let replace = (extra["replace"] as? [[String]] ?? []).compactMap { $0.count == 2 ? ($0[0], $0[1]) : nil }
    let regex = (extra["regex"] as? [[String]] ?? []).compactMap { $0.count == 2 ? ($0[0], $0[1]) : nil }
    func spoken(_ t: String) -> String {
        var s = t
        for (a, b) in replace { s = s.replacingOccurrences(of: a, with: b) }
        for (p, r) in regex { s = s.replacingOccurrences(of: p, with: r, options: .regularExpression) }
        return s
    }
    // 多音字：换完同音字以后，下面这些字不能再出现（"数字""次数"里的数读 shù，本来就对）
    let risky = ["行", "得", "朝", "模", "倒", "调", "差", "空", "重", "转", "数", "长", "背", "还原", "处理"]
    var checked = 0
    for t in Set(allSpoken + kit.fixedLines) {
        checked += 1
        var s = spoken(t)
        for ok in ["数字", "次数"] { s = s.replacingOccurrences(of: ok, with: "") }
        for r in risky where s.contains(r) { fail("polyphonic「\(r)」not fixed: \(t)") }
        expect(!t.unicodeScalars.contains { $0.value >= 48 && $0.value <= 57 }, "digits in a spoken line (write Chinese numerals): \(t)")
        expect(!t.contains("★") && !t.contains("◆"), "symbols in a spoken line: \(t)")
    }
    print("  \(checked) 句要配音的话：固定台词 \(kit.fixedLines.count) 句和 extra_coding.json 一致，多音字都换掉了")
}

print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
