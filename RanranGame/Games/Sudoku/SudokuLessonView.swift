import SwiftUI
import Observation

/// 数独的一课：盘面 + 下面一排数字（水果）按钮。题目按 SudokuLessonLogic 判：
/// fill 先点格子再点数字（"把这一格填上"的题格子已经选好了）；pick 点格子；value 点按钮；cands 把能填的按钮都点出来。
@Observable
@MainActor
final class SudokuLessonSession {
    let flow: LessonFlow
    private(set) var grid = SudokuGrid(n: 4)
    private(set) var given: Set<Int> = []
    /// 她在这一课里填进去的格子
    private(set) var mine: Set<Int> = []
    private(set) var selected: Int?
    /// cands 题已经点出来的数
    private(set) var found: Set<Int> = []
    /// 点对了的格子 / 按钮（亮一下）
    private(set) var picked: Int?
    private(set) var pickedValue: Int?
    /// 填错的数先画在格子里晃一下，再拿掉
    private(set) var wrongTry: (cell: Int, value: Int)?
    private(set) var wobble: [Int: Int] = [:]
    private(set) var missCell: Int?

    init(course: TutorialCourse, lesson: TutorialLesson, mode: LessonMode = .lesson) {
        flow = LessonFlow(course: course, lesson: lesson, mode: mode)
        sync()
        flow.onStep = { [weak self] in self?.sync() }
    }

    var input: SudokuLessonLogic.Input? { flow.task.map(SudokuLessonLogic.input) }

    private func sync() {
        if let spec = flow.step.board, let g = SudokuGrid(spec: spec) {
            withAnimation(.spring(duration: 0.4)) {
                grid = g
                given = Set((0..<g.count).filter { g[$0] != 0 })
                mine = []
            }
        }
        found = []
        picked = nil
        pickedValue = nil
        wrongTry = nil
        missCell = nil
        // "把这一格填上"：格子先选好
        if let t = flow.task, SudokuLessonLogic.input(t) == .fill, let c = SudokuLessonLogic.focus(t, grid).cells.first {
            selected = c
        } else {
            selected = nil
        }
    }

    // MARK: 操作

    func tapCell(_ i: Int) {
        guard flow.awaitingAnswer, let t = flow.task else { return }
        switch SudokuLessonLogic.input(t) {
        case .pick:
            if SudokuLessonLogic.pickAnswers(t, grid).contains(i) {
                withAnimation(.spring(duration: 0.3)) { picked = i }
                flow.succeed()
            } else {
                miss(i)
                flow.fail()
            }
        case .fill:
            guard grid[i] == 0 else { flow.nudge(SudokuLines.notBlank); return }
            Sound.tap()
            withAnimation(.spring(duration: 0.25)) { selected = i }
        case .value, .cands:
            break
        }
    }

    func tapValue(_ v: Int) {
        guard flow.awaitingAnswer, let t = flow.task else { return }
        Sound.key()
        switch SudokuLessonLogic.input(t) {
        case .fill:
            guard let s = selected, grid[s] == 0 else { flow.nudge(SudokuLines.pickCellFirst); return }
            if SudokuLessonLogic.fillAnswers(t, grid).contains(where: { $0.cell == s && $0.value == v }) {
                withAnimation(.spring(duration: 0.35, bounce: 0.4)) {
                    grid[s] = v
                    mine.insert(s)
                    selected = nil
                }
                flow.succeed()
            } else {
                wrongTry = (s, v)
                wobble[s, default: 0] += 1
                Task {
                    try? await Task.sleep(for: .milliseconds(900))
                    withAnimation(.easeOut(duration: 0.25)) { if self.wrongTry?.cell == s { self.wrongTry = nil } }
                }
                flow.fail()
            }
        case .value:
            if SudokuLessonLogic.valueAnswers(t, grid).contains(v) {
                withAnimation(.spring(duration: 0.3)) { pickedValue = v }
                flow.succeed()
            } else {
                flow.fail()
            }
        case .cands:
            let all = SudokuLessonLogic.candAnswers(t, grid)
            guard !found.contains(v) else { return }
            if all.contains(v) {
                withAnimation(.spring(duration: 0.3, bounce: 0.5)) { _ = found.insert(v) }
                let left = all.subtracting(found).count
                if left == 0 { flow.succeed() } else { flow.found(left) }
            } else {
                flow.fail()
            }
        case .pick:
            break
        }
    }

    private func miss(_ i: Int) {
        withAnimation(.spring(duration: 0.2)) { missCell = i }
        wobble[i, default: 0] += 1
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.easeOut(duration: 0.25)) { if self.missCell == i { self.missCell = nil } }
        }
    }

    // MARK: 画出来

    var look: SudokuBoardLook {
        var g = grid
        var l = SudokuBoardLook(grid: g, given: given)
        l.selected = selected
        l.wobble = wobble
        if let s = selected { l.softUnits = g.units(of: s) }
        // 课文里的标记
        for m in flow.step.marks ?? [] {
            let p = m.split(separator: ":").map(String.init)
            switch p.first {
            case "row", "col", "box":
                if let u = SudokuUnit(m), g.isValid(u) { l.focusUnits.append(u) }
            case "ban":
                if p.count == 3, let u = SudokuUnit("\(p[1]):\(p[2])"), g.isValid(u) {
                    l.crossed.formUnion(g.blanks(in: u))
                }
            case "cell":
                if p.count == 2, let c = g.cell(named: p[1]) { l.glow.insert(c) }
            case "cross":
                if p.count == 2, let c = g.cell(named: p[1]) { l.crossed.insert(c) }
            case "val":
                if p.count == 2, let v = Int(p[1]) { l.sameValue = v }
            case "notes":
                if p.count == 3, let c = g.cell(named: p[1]) { l.notes[c] = Set(p[2].compactMap(\.wholeNumberValue)) }
            default: break
            }
        }
        // 题目自己要圈的地方（练习时课文的标记可能不全）
        if let t = flow.task, !flow.solved {
            let f = SudokuLessonLogic.focus(t, g)
            for u in f.units where !l.focusUnits.contains(u) { l.focusUnits.append(u) }
            if SudokuLessonLogic.input(t) != .fill { l.glow.formUnion(f.cells) } else if selected == nil { l.glow.formUnion(f.cells) }
            if let v = f.value { l.sameValue = v }
            if SudokuLessonLogic.input(t) == .cands, let c = f.cells.first { l.notes[c] = found }
        }
        if let c = picked { l.glow.insert(c) }
        if let c = missCell { l.wrong.insert(c) }
        if let w = wrongTry, g[w.cell] == 0 {
            g[w.cell] = w.value
            l.grid = g
            l.wrong.insert(w.cell)
        }
        // 错了两次：亮出答案，再讲一遍道理
        if flow.revealed, let t = flow.task, !flow.solved {
            switch SudokuLessonLogic.input(t) {
            case .fill:
                let ans = SudokuLessonLogic.fillAnswers(t, grid)
                let shown = ans.first { $0.cell == selected } ?? ans.first
                if let a = shown {
                    l.ghost[a.cell] = a.value
                    l.glow.insert(a.cell)
                    if let via = t.extra?["via"], let m = SudokuLessonLogic.move(via: via, grid, cell: a.cell, value: a.value) {
                        apply(SudokuLessonLogic.explain(m, grid), to: &l)
                    }
                }
            case .pick:
                let ans = SudokuLessonLogic.pickAnswers(t, grid)
                l.glow.formUnion(ans.count <= grid.n * 2 ? ans : Set(ans.prefix(grid.n)))
                let p = SudokuLessonLogic.parts(t.rule)
                if p.first == "where", let via = t.extra?["via"], let v = Int(p[1]), let c = ans.first,
                   let m = SudokuLessonLogic.move(via: via, grid, cell: c, value: v) {
                    apply(SudokuLessonLogic.explain(m, grid), to: &l)
                }
            case .value, .cands:
                break
            }
        }
        return l
    }

    private func apply(_ e: SudokuLessonLogic.Explain, to l: inout SudokuBoardLook) {
        for u in e.units where !l.focusUnits.contains(u) { l.focusUnits.append(u) }
        l.crossed.formUnion(e.crossed)
        l.peers.formUnion(e.peers)
        if let v = e.value { l.sameValue = v }
    }

    /// 按钮上亮哪一个
    var padHighlight: Int? {
        if let v = pickedValue { return v }
        guard let t = flow.task else { return nil }
        if flow.revealed, !flow.solved {
            switch SudokuLessonLogic.input(t) {
            case .value: return SudokuLessonLogic.valueAnswers(t, grid).first
            case .fill:
                let ans = SudokuLessonLogic.fillAnswers(t, grid)
                return (ans.first { $0.cell == selected } ?? ans.first)?.value
            case .cands: return SudokuLessonLogic.candAnswers(t, grid).subtracting(found).min()
            case .pick: break
            }
        }
        return SudokuLessonLogic.focus(t, grid).value
    }

    /// 这一步要不要用按钮
    var padEnabled: Bool {
        guard flow.awaitingAnswer, let i = input else { return false }
        return i != .pick
    }

    func stop() { flow.stop() }
}

struct SudokuLessonView: View {
    let course: TutorialCourse
    let lesson: TutorialLesson
    var mode: LessonMode = .lesson
    var onNextLesson: ((TutorialLesson) -> Void)? = nil

    @State private var session: SudokuLessonSession

    init(course: TutorialCourse, lesson: TutorialLesson, mode: LessonMode = .lesson,
         onNextLesson: ((TutorialLesson) -> Void)? = nil) {
        self.course = course
        self.lesson = lesson
        self.mode = mode
        self.onNextLesson = onNextLesson
        _session = State(initialValue: SudokuLessonSession(course: course, lesson: lesson, mode: mode))
    }

    var body: some View {
        LessonScaffold(flow: session.flow, accent: SudokuStyle.accent, onNextLesson: onNextLesson) {
            GeometryReader { geo in
                let g = session.grid
                let gap: CGFloat = 16
                let padSide = min(84, geo.size.width / (CGFloat(g.n) + CGFloat(g.n - 1) * 0.1), geo.size.height * 0.16)
                let boardSide = max(120, min(geo.size.width, geo.size.height - padSide - gap))
                VStack(spacing: gap) {
                    SudokuBoardView(look: session.look) { session.tapCell($0) }
                        .frame(width: boardSide, height: boardSide)
                    SudokuPad(n: g.n, fruit: g.fruit, columns: g.n, side: padSide,
                              highlighted: session.padHighlight, enabled: session.padEnabled) { session.tapValue($0) }
                        .opacity(session.padEnabled ? 1 : 0.45)
                        .animation(.easeInOut(duration: 0.2), value: session.padEnabled)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .onDisappear { session.stop() }
    }
}
