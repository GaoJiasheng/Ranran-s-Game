import SwiftUI
import Observation

/// 编程的一课：花园、程序、积木盒放在老师旁边（LessonScaffold）。题目怎么判都在 Logic/CodingLessonLogic.swift：
/// build / fix 点「开始」跑完判；predict 点格子；spot 点积木；choose 点程序；count 点数字。都由解释器算答案。
@Observable
@MainActor
final class CodingLessonSession {
    let flow: LessonFlow
    let editor: CodingEditor
    let stage: CodingStage
    private(set) var limits: CodingLimits
    /// choose / count 题点了哪一个（做对以后摆出来跑一遍）
    private(set) var picked: Int?

    init(course: TutorialCourse, lesson: TutorialLesson, mode: LessonMode = .lesson) {
        flow = LessonFlow(course: course, lesson: lesson, mode: mode)
        let first = lesson.steps.first { $0.board != nil }
        let gs = first.flatMap(CodingLessonLogic.gardens) ?? [CodingGarden(layout: "B.C")!]
        let lim = first.map(CodingLessonLogic.limits) ?? CodingLessonLogic.defaultLimits
        limits = lim
        editor = CodingEditor(program: CodingProgram(), limits: lim)
        stage = CodingStage(gardens: gs)
        flow.onStep = { [weak self] in self?.sync() }
        editor.onEdit = { [weak self] in self?.edited() }
        editor.onSay = { [weak self] in self?.flow.nudge($0) }
        stage.onFinish = { [weak self] r in self?.finished(r) }
    }

    var step: TutorialStep { flow.step }
    var task: TutorialTask? { flow.task }
    var type: String { task?.type ?? "" }
    var editing: Bool { (type == "build" || type == "fix") && flow.awaitingAnswer }
    private var startProgram = CodingProgram()

    /// 进入新的一步：有新花园就换上；程序、格子按这一步写的来
    func sync() {
        stage.stop()
        picked = nil
        if let gs = CodingLessonLogic.gardens(step) {
            stage.setGardens(gs)
        } else {
            stage.reset()
        }
        if step.extra?["limits"] != nil || step.task?.extra?["limits"] != nil || step.board != nil {
            limits = CodingLessonLogic.limits(step)
        }
        let p = CodingLessonLogic.program(step)
        startProgram = p
        editor.load(p, limits: limits)
        if step.extra?["run"] == "yes", !p.isEmpty {
            // 演示：老师说着话，小兔照着程序走一遍
            let idx = flow.index
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(900))
                guard let self, self.flow.index == idx, self.stage.phase == .editing else { return }
                self.stage.start(self.editor.program)
            }
        }
    }

    private func edited() {
        if stage.phase != .editing { stage.reset() }
    }

    // MARK: 跑（build / fix，或者没有题的演示）

    func run() {
        switch stage.phase {
        case .running: stage.pause()
        case .failed, .passed: stage.reset()
        default: stage.start(editor.program)
        }
    }

    func stepOnce() {
        if stage.failed || stage.phase == .passed { stage.reset() }
        stage.stepOnce(editor.program)
    }

    func restore() {
        stage.reset()
        editor.load(startProgram, limits: limits)
    }

    private func finished(_ r: CodingRunResult) {
        guard editing || (flow.task != nil && !flow.solved && (type == "build" || type == "fix")) else { return }
        switch CodingLessonLogic.judge(editor.program, step) {
        case .pass:
            flow.succeed()
        case let .needs(tok):
            flow.fail(CodingLines.need(tok))
        case .tooMany:
            flow.fail(CodingLines.tooMany)
        case .fail:
            flow.fail()
        }
    }

    // MARK: 点一点的题

    func tapCell(_ c: CodingCell) {
        guard flow.awaitingAnswer, type == "predict" else { return }
        if CodingLessonLogic.predictCell(step) == c {
            flow.succeed()
            stage.start(editor.program)
        } else {
            flow.fail(TutorLines.wrongPick)
        }
    }

    func tapBlock(_ r: CodingRef) {
        guard flow.awaitingAnswer else { return }
        if type == "spot" {
            if CodingLessonLogic.spotRefs(step).contains(r) {
                flow.succeed()
            } else {
                flow.fail(TutorLines.wrongPick)
            }
        } else if editing {
            editor.remove(r)
        }
    }

    func tapOption(_ i: Int) {
        guard flow.awaitingAnswer, type == "choose" else { return }
        if CodingLessonLogic.chooseIndex(step) == i {
            picked = i
            flow.succeed()
            let p = CodingLessonLogic.options(step)[i]
            editor.load(p, limits: limits)
            stage.start(p)
        } else {
            flow.fail(TutorLines.wrongPick)
        }
    }

    func tapCount(_ n: Int) {
        guard flow.awaitingAnswer, type == "count" else { return }
        if CodingLessonLogic.countAnswer(step) == n, let p = CodingLessonLogic.countProgram(step, n) {
            picked = n
            flow.succeed()
            editor.load(p, limits: limits)
            stage.start(p)
        } else {
            flow.fail(TutorLines.wrongPick)
        }
    }

    // MARK: 画什么

    /// count 题还没答时，程序里那个数画成问号
    var countDisplay: (program: CodingProgram, unknown: CodingRef?, times: CodingRef?)? {
        guard type == "count", picked == nil, let template = CodingLessonLogic.extra(step, "template") else { return nil }
        if template.contains("#[") {
            guard let p = CodingLessonLogic.fill(template, 2) else { return nil }
            let r = p.allRefs.first { if case .loop? = p.block(at: $0) { return true }; return false }
            return (p, r, nil)
        }
        guard let p = CodingLessonLogic.fill(template, 1) else { return nil }
        // "R# U U" 填 1 以后是 "R U U"：# 前面那个箭头是第几块
        let idx = template.split(separator: " ").firstIndex { $0.hasSuffix("#") } ?? 0
        return (p, nil, CodingRef(track: 0, path: [idx]))
    }

    var decor: CodingDecor {
        var d = CodingDecor()
        d.active = stage.active
        d.stack = Set(stage.stack)
        d.iterations = stage.iterations
        if stage.failed { d.culprit = stage.culprit }
        if editing && stage.phase == .editing { d.cursor = editor.cursor }
        d.shake = editor.shake
        if flow.revealed && !flow.solved {
            switch type {
            case "build", "fix": d.ghost = CodingLessonLogic.answer(step)
            case "spot": d.rings = CodingLessonLogic.spotRefs(step)
            default: break
            }
        }
        if type == "spot", flow.solved { d.rings = CodingLessonLogic.spotRefs(step) }
        for m in step.marks ?? [] where m.hasPrefix("block:") {
            if let r = CodingLessonLogic.ref(String(m.dropFirst(6))) { d.rings.insert(r) }
        }
        return d
    }

    var glowCells: Set<CodingCell> {
        var s = Set<CodingCell>()
        for m in step.marks ?? [] where m.hasPrefix("glow:") { if let c = CodingCell(name: String(m.dropFirst(5))) { s.insert(c) } }
        if type == "predict", flow.revealed || flow.solved, let c = CodingLessonLogic.predictCell(step) { s.insert(c) }
        return s
    }

    var ringCells: Set<CodingCell> {
        var s = Set<CodingCell>()
        for m in step.marks ?? [] where m.hasPrefix("ring:") { if let c = CodingCell(name: String(m.dropFirst(5))) { s.insert(c) } }
        return s
    }

    func stop() {
        stage.stop()
        flow.stop()
    }
}

struct CodingLessonView: View {
    let course: TutorialCourse
    let lesson: TutorialLesson
    var mode: LessonMode = .lesson
    var onNextLesson: ((TutorialLesson) -> Void)? = nil

    @State private var session: CodingLessonSession

    init(course: TutorialCourse, lesson: TutorialLesson, mode: LessonMode = .lesson,
         onNextLesson: ((TutorialLesson) -> Void)? = nil) {
        self.course = course
        self.lesson = lesson
        self.mode = mode
        self.onNextLesson = onNextLesson
        _session = State(initialValue: CodingLessonSession(course: course, lesson: lesson, mode: mode))
    }

    var body: some View {
        LessonScaffold(flow: session.flow, accent: CodingPlayView.accent, onNextLesson: { onNextLesson?($0) }) {
            GeometryReader { geo in
                board(geo.size)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
        }
        .onDisappear { session.stop() }
    }

    private var type: String { session.type }
    private var stage: CodingStage { session.stage }

    @ViewBuilder
    private func board(_ size: CGSize) -> some View {
        let gs = stage.gardens
        let lim = session.limits
        let showPalette = type == "build" || type == "fix"
        let plan = CodingLayout.plan(screen: .lesson, width: Double(size.width), height: Double(size.height),
                                     cols: gs.map(\.width).max() ?? 5, rows: gs.map(\.height).max() ?? 4, multi: gs.count > 1,
                                     limits: lim, paletteCount: showPalette ? lim.palette.count : 0,
                                     minProgramHeight: type == "choose" ? CodingLayout.optionsHeight(CodingLessonLogic.options(session.step), u: 60) : 0)
        if plan.wide {
            HStack(alignment: .top, spacing: 24) {
                gardenBlock(plan, multi: gs.count > 1)
                VStack(spacing: CodingLayout.spacing) {
                    program(plan).frame(width: plan.programWidth, height: plan.programHeight, alignment: .top)
                    if showPalette { palette(plan) }
                    controls.frame(height: CodingLayout.lessonControlsHeight)
                }
                .frame(width: plan.programWidth)
            }
        } else {
            VStack(spacing: CodingLayout.spacing) {
                gardenBlock(plan, multi: gs.count > 1)
                program(plan).frame(width: plan.programWidth, height: plan.programHeight, alignment: .top)
                if showPalette { palette(plan) }
                controls.frame(height: CodingLayout.lessonControlsHeight)
            }
        }
    }

    private var tabs: some View {
        CodingGardenTabs(count: stage.gardens.count, shown: stage.shown, done: stage.gardenDone, enabled: !stage.midway) {
            stage.show($0)
        }
    }

    /// 页签贴着花园，一起摆在留给花园的那块地方的正中
    private func gardenBlock(_ plan: CodingLayout.Plan, multi: Bool) -> some View {
        VStack(spacing: CodingLayout.spacing) {
            if multi { tabs }
            garden(plan)
        }
        .frame(width: plan.gardenWidth,
               height: plan.gardenHeight + (multi ? CodingLayout.tabsHeight + CodingLayout.spacing : 0))
    }

    private func garden(_ plan: CodingLayout.Plan) -> some View {
        CodingGardenView(garden: stage.garden, bunny: stage.bunny, cell: CGFloat(plan.cell) * 0.95, facingLeft: stage.facingLeft,
                         mood: stage.failed ? .oops : stage.phase == .passed ? .yay : .idle,
                         bump: stage.bump, check: stage.check, trail: stage.trail,
                         glow: session.glowCells, rings: session.ringCells,
                         onTap: type == "predict" ? { session.tapCell($0) } : nil)
    }

    @ViewBuilder
    private func program(_ plan: CodingLayout.Plan) -> some View {
        let u = CGFloat(plan.unit)
        if type == "choose", session.picked == nil {
            options(plan)
        } else if let c = session.countDisplay {
            CodingProgramView(program: c.program, limits: session.limits, u: u, decor: countDecor(c),
                              actions: CodingProgramActions(enabled: false), tracks: 1)
        } else {
            CodingProgramView(program: session.editor.program, limits: session.limits, u: u, decor: session.decor,
                              actions: CodingProgramActions(block: { session.tapBlock($0) },
                                                            slot: { session.editor.moveCursor($0) },
                                                            count: session.editing ? { session.editor.setCount($0, $1) } : nil,
                                                            enabled: (session.editing && !stage.busy) || (type == "spot" && session.flow.awaitingAnswer)))
        }
    }

    private func countDecor(_ c: (program: CodingProgram, unknown: CodingRef?, times: CodingRef?)) -> CodingDecor {
        var d = CodingDecor()
        if let r = c.unknown { d.unknownCount = r }
        if let r = c.times { d.timesBadge = r }
        return d
    }

    /// choose 题：两三个程序摞起来，点一个
    private func options(_ plan: CodingLayout.Plan) -> some View {
        let opts = CodingLessonLogic.options(session.step)
        let answer = CodingLessonLogic.chooseIndex(session.step)
        // 每个选项一张卡片，排成一行；积木大小按最长的那个选项算
        let u = CodingLayout.optionUnit(options: opts, width: plan.programWidth, height: plan.programHeight, cap: plan.unit)
        return VStack(spacing: 12) {
            ForEach(Array(opts.enumerated()), id: \.offset) { i, p in
                Button {
                    session.tapOption(i)
                } label: {
                    HStack(spacing: 12) {
                        Text("\(i + 1)")
                            .font(.kid(26, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(CodingPlayView.accent))
                        CodingInlineProgram(program: p, u: CGFloat(u))
                            .allowsHitTesting(false)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white.opacity(0.6)))
                    .overlay {
                        if session.flow.revealed, answer == i {
                            RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(hex: 0xFFC83D), lineWidth: 5)
                        }
                    }
                }
                .buttonStyle(PressableStyle(scale: 0.97))
                .disabled(!session.flow.awaitingAnswer)
            }
        }
    }

    /// 点一点的题：下面那一行告诉她点哪儿
    private func tapHint(_ text: String, height: CGFloat) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.point.up.left.fill").font(.system(size: 26, weight: .bold))
            Text(text)
                .font(.kid(20, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(Palette.inkSoft)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .opacity(session.flow.awaitingAnswer ? 1 : 0)
    }

    private func palette(_ plan: CodingLayout.Plan) -> some View {
        CodingPaletteView(limits: session.limits, side: CGFloat(plan.palette.side), rows: plan.palette.rows,
                          available: { session.editor.refusal($0) == nil }, enabled: session.editing && !stage.busy) {
            session.editor.tap($0)
        }
        .frame(height: CGFloat(plan.palette.height))
    }

    @ViewBuilder
    private var controls: some View {
        let h = CGFloat(CodingLayout.lessonControlsHeight)
        switch type {
        case "count":
            let counts = CodingLessonLogic.counts(session.step)
            let answer = CodingLessonLogic.countAnswer(session.step)
            HStack(spacing: 14) {
                ForEach(counts, id: \.self) { n in
                    Button {
                        session.tapCount(n)
                    } label: {
                        Text("\(n)")
                            .font(.kid(36, weight: .black))
                            .foregroundStyle(Palette.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: h)
                            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(session.picked == n ? Color(hex: 0xFFE27A) : Palette.paper))
                            .overlay {
                                if session.flow.revealed && !session.flow.solved && answer == n {
                                    RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(hex: 0xFFC83D), lineWidth: 5)
                                }
                            }
                            .shadow(color: Color(hex: 0x6B4E2E).opacity(0.12), radius: 8, y: 4)
                    }
                    .buttonStyle(PressableStyle(scale: 0.93))
                    .disabled(!session.flow.awaitingAnswer)
                }
            }
        case "predict", "choose":
            tapHint(type == "predict" ? "点花园里的一个格子" : "点一个程序", height: h)
        case "spot":
            // 找虫子的办法就是跑一跑、一步一步看，所以这里也给「开始」和「一步」；答案还是点积木
            let phase = stage.phase
            let (icon, title): (String, String) = {
                switch phase {
                case .running: return ("pause.fill", "停")
                case .paused: return ("play.fill", "接着走")
                case .failed, .passed: return ("arrow.counterclockwise", "再看一遍")
                case .editing: return ("play.fill", "开始")
                }
            }()
            HStack(spacing: 12) {
                tapHint("点程序里的一块积木", height: h)
                CodingToolButton(systemName: icon, label: title, height: h) { session.run() }
                    .frame(width: 104)
                CodingToolButton(systemName: "forward.frame.fill", label: "一步", height: h) { session.stepOnce() }
                    .frame(width: 92)
            }
        default:
            let phase = stage.phase
            let (icon, title): (String, String) = {
                switch phase {
                case .running: return ("pause.fill", "停")
                case .paused: return ("play.fill", "接着走")
                case .failed, .passed: return ("arrow.counterclockwise", session.task == nil ? "再看一遍" : "再试一次")
                case .editing: return ("play.fill", "开始")
                }
            }()
            let canRun = !session.editor.program.isEmpty && (session.editing || session.task == nil)
            HStack(spacing: 12) {
                CodingToolButton(systemName: icon, label: title, height: h,
                                 tint: session.task == nil ? Palette.paper : Palette.coral,
                                 foreground: session.task == nil ? Palette.ink : .white,
                                 enabled: canRun || phase != .editing) { session.run() }
                    .frame(maxWidth: .infinity)
                CodingToolButton(systemName: "forward.frame.fill", label: "一步", height: h, enabled: canRun) { session.stepOnce() }
                    .frame(width: 92)
                if session.editing {
                    CodingToolButton(systemName: session.type == "fix" ? "arrow.uturn.backward" : "trash",
                                     label: session.type == "fix" ? "重来" : "清空", height: h,
                                     enabled: !stage.busy) {
                        Sound.tap()
                        session.restore()
                    }
                    .frame(width: 92)
                }
            }
        }
    }
}
