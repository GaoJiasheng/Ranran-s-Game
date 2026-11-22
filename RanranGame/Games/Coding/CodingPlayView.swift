import SwiftUI
import Observation

/// 玩一关：花园（横屏在左、竖屏在上）、猫头鹰的一句话、程序、积木盒、下面一排大按钮。
@Observable
@MainActor
final class CodingPlaySession {
    let level: CodingLevel
    let editor: CodingEditor
    let stage: CodingStage
    private(set) var line = ""
    /// 提示点了几下（0 没点；1 说了思路；2 在程序里标出来了）
    private(set) var hintLevel = 0
    private(set) var hint: CodingHint.Result = .none
    private(set) var usedHint = false
    /// 过关时的程序（结算页上写用了几块）
    private(set) var passedSize: Int?
    private var talkTask: Task<Void, Never>?

    init(level: CodingLevel) {
        self.level = level
        editor = CodingEditor(program: level.startProgram, limits: level.limitsValue)
        stage = CodingStage(gardens: level.gardenList)
        editor.onEdit = { [weak self] in self?.edited() }
        editor.onSay = { [weak self] in self?.say($0) }
        stage.onFinish = { [weak self] r in self?.finished(r) }
        #if DEBUG
        if let s = UserDefaults.standard.string(forKey: "codingProgram"), let p = CodingProgram(text: s), CodingRules.fits(p, level.limitsValue) {
            editor.load(p)
        }
        #endif
    }

    var size: Int { editor.program.size }
    var inPar: Bool { (passedSize ?? size) <= level.par }
    /// 这一次拿几颗星：过关 1 + 没用提示 1 + 积木不多 1
    var earned: Int { 1 + (usedHint ? 0 : 1) + (inPar ? 1 : 0) }

    func say(_ s: String) {
        talkTask?.cancel()
        withAnimation(.spring(duration: 0.3)) { line = s }
        talkTask = Task { await VoiceOver.shared.speak(s) }
    }

    func replay() { if !line.isEmpty { say(line) } }

    private func edited() {
        if stage.phase != .editing { stage.reset() }
        if hint != .none { withAnimation { hint = .none } }
    }

    // MARK: 跑

    func run() {
        switch stage.phase {
        case .running: stage.pause()
        case .failed, .passed: stage.reset(); line = ""
        default:
            if hint != .none { withAnimation { hint = .none } }
            stage.start(editor.program)
        }
    }

    func step() {
        if stage.failed || stage.phase == .passed { stage.reset() }
        stage.stepOnce(editor.program)
    }

    private func finished(_ r: CodingRunResult) {
        if r.passed {
            passedSize = editor.program.size
            say(CodingLines.passed)
        } else if let i = r.failedGarden {
            let t = r.traces[i]
            say(CodingLines.failure(t.outcome, garden: i, eatenAll: t.final.eaten == t.garden.allEaten))
        }
    }

    // MARK: 提示

    var reference: CodingProgram { level.answerProgram }

    func showHint() {
        guard !stage.busy else { return }
        usedHint = true
        Sound.hint()
        if stage.phase != .editing { stage.reset() }
        if hintLevel == 0 {
            hintLevel = 1
            say(CodingLines.idea(pack: level.pack, bug: level.kind == .bug))
            return
        }
        hintLevel = 2
        let h = CodingHint.next(current: editor.program, reference: reference)
        withAnimation(.spring(duration: 0.35)) { hint = h }
        switch h {
        case let .ghost(_, slot):
            editor.moveCursor(slot)
            say(CodingLines.ghost)
        case .ring:
            say(level.kind == .bug && editor.program == level.startProgram ? CodingLines.bugBlock : CodingLines.wrongBlock)
        case .none:
            say(CodingLines.tryRun)
        }
    }

    var decor: CodingDecor {
        var d = CodingDecor()
        d.active = stage.active
        d.stack = Set(stage.stack)
        d.iterations = stage.iterations
        if stage.failed { d.culprit = stage.culprit }
        switch hint {
        case let .ghost(g, _): d.ghost = g
        case let .ring(r): d.rings = [r]
        case .none: break
        }
        if stage.phase == .editing { d.cursor = editor.cursor }
        d.shake = editor.shake
        return d
    }

    func clear() {
        stage.reset()
        hint = .none
        editor.load(level.startProgram)
        line = ""
    }

    func stop() {
        stage.stop()
        talkTask?.cancel()
        VoiceOver.shared.stop()
    }

    #if DEBUG
    /// 调试截图用：-codingRun / -codingStep / -codingFail / -codingHint
    func applyDebug() {
        let d = UserDefaults.standard
        // 过关页：没给程序就摆上参考答案（结算页上的积木数才像样）
        if d.bool(forKey: "codingDone"), d.string(forKey: "codingProgram") == nil {
            editor.load(reference)
            passedSize = reference.size
        }
        if d.integer(forKey: "codingHint") > 0 {
            showHint()
            if d.integer(forKey: "codingHint") > 1 { showHint() }
        }
        if let f = d.string(forKey: "codingFail") {
            let kind: CodingOutcome = f == "bump" ? .bump : f == "dizzy" ? .dizzy : .end
            let g = f == "garden" ? min(1, level.gardenList.count - 1) : 0
            stage.debugFail(kind, garden: g)
            say(CodingLines.failure(kind, garden: g, eatenAll: f == "home"))
            return
        }
        if d.integer(forKey: "codingStep") > 0 {
            stage.debugSteps(editor.program, d.integer(forKey: "codingStep"))
        } else if d.bool(forKey: "codingRun") {
            stage.start(editor.program)
        }
    }
    #endif
}

struct CodingPlayView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PuzzleRules.unlockAllKey) private var unlockAll = false

    @State private var session: CodingPlaySession
    @State private var result: PuzzleResult?
    @State private var finishTask: Task<Void, Never>?
    @State private var confirmClear = false
    let onSwitch: (String) -> Void

    static let accent = Color(hex: 0x6FA35A)

    init(levelID: String, onSwitch: @escaping (String) -> Void) {
        let level = CodingCatalog.level(levelID) ?? CodingCatalog.levels[0]
        _session = State(initialValue: CodingPlaySession(level: level))
        self.onSwitch = onSwitch
    }

    private var level: CodingLevel { session.level }
    private var stage: CodingStage { session.stage }
    private var editor: CodingEditor { session.editor }

    private var nextLevel: String? {
        store.puzzleAfter("coding", CodingCatalog.packs, level.id, unlockAll: unlockAll)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width - 2 * CodingLayout.playPadH, h = geo.size.height - 2 * CodingLayout.playPadV
            let gs = level.gardenList
            let plan = CodingLayout.plan(screen: .play, width: w, height: h, cols: gs.map(\.width).max() ?? 7,
                                         rows: gs.map(\.height).max() ?? 6, multi: gs.count > 1,
                                         limits: level.limitsValue, paletteCount: level.limitsValue.palette.count)
            ZStack {
                CreamBackground(accent: Self.accent)
                Group {
                    if plan.wide {
                        VStack(spacing: CodingLayout.spacing) {
                            header.frame(height: CodingLayout.headerHeight)
                            HStack(alignment: .top, spacing: 24) {
                                VStack(spacing: CodingLayout.spacing) {
                                    gardenBlock(plan, multi: gs.count > 1)
                                    owlBar.frame(height: CodingLayout.owlHeight)
                                }
                                .frame(width: plan.gardenWidth)
                                VStack(spacing: CodingLayout.spacing) {
                                    programArea(plan).frame(width: plan.programWidth, height: plan.programHeight, alignment: .top)
                                    paletteArea(plan)
                                    controls(plan).frame(height: CodingLayout.controlsHeight)
                                }
                                .frame(width: plan.programWidth)
                            }
                        }
                    } else {
                        VStack(spacing: CodingLayout.spacing) {
                            header.frame(height: CodingLayout.headerHeight)
                            gardenBlock(plan, multi: gs.count > 1)
                            owlBar.frame(height: CodingLayout.owlHeight)
                            programArea(plan).frame(width: plan.programWidth, height: plan.programHeight, alignment: .top)
                            paletteArea(plan)
                            controls(plan).frame(height: CodingLayout.controlsHeight)
                        }
                    }
                }
                .frame(width: w, height: h, alignment: .top)
                if let result {
                    PuzzleDoneOverlay(result: result,
                                      stars: [("过关", true), ("没用提示", !session.usedHint), ("积木不多", session.inPar)],
                                      accent: Self.accent,
                                      detail: "用了 \(session.passedSize ?? session.size) 块积木，\(level.par) 块以内有星星",
                                      onNext: nextLevel.map { next in { onSwitch(next) } },
                                      onReplay: replay,
                                      onLeave: { dismiss() })
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
        }
        .onChange(of: stage.phase) { _, p in
            if p == .passed { finish() }
        }
        .onAppear {
            #if DEBUG
            session.applyDebug()
            if UserDefaults.standard.bool(forKey: "codingDone") {
                let e = 3
                result = PuzzleResult(earned: e, best: e, paid: e, first: true)
            }
            #endif
        }
        .onDisappear { session.stop(); finishTask?.cancel() }
        .confirmationDialog(level.kind == .bug ? "把程序恢复成一开始的样子？" : "把程序清空？", isPresented: $confirmClear, titleVisibility: .visible) {
            Button(level.kind == .bug ? "恢复原样" : "清空", role: .destructive) { session.clear() }
            Button("不要", role: .cancel) {}
        }
    }

    // MARK: 顶上

    private var header: some View {
        HStack(spacing: 14) {
            RoundIconButton(systemName: "chevron.left", label: "返回") { dismiss() }
            VStack(alignment: .leading, spacing: 2) {
                Text("第 \(CodingCatalog.number(level)) 关")
                    .font(.kid(30, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text("\(CodingCatalog.packName(level.pack)) · \(level.name)")
                    .font(.kid(18, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Spacer(minLength: 8)
            parBadge
        }
    }

    /// 积木数：现在几块、几块以内有星星（写在屏幕上，不朗读）
    private var parBadge: some View {
        let over = session.size > level.par
        return HStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(session.size)")
                    .font(.kid(34, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(over ? Palette.coral : Palette.ink)
                    .contentTransition(.numericText())
                Text("块")
                    .font(.kid(19, weight: .bold))
                    .foregroundStyle(Palette.inkSoft)
            }
            Label("\(level.par) 块以内有星星", systemImage: "star.fill")
                .font(.kid(18, weight: .bold))
                .foregroundStyle(over ? Palette.inkSoft : Color(hex: 0xC98D2E))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 18)
        .frame(height: 60)
        .softCard(radius: 30)
        .animation(.spring(duration: 0.25), value: session.size)
    }

    private var tabs: some View {
        CodingGardenTabs(count: level.gardenList.count, shown: stage.shown, done: stage.gardenDone, enabled: !stage.midway) {
            stage.show($0)
        }
    }

    // MARK: 花园

    /// 页签贴着花园，一起摆在留给花园的那块地方的正中
    private func gardenBlock(_ plan: CodingLayout.Plan, multi: Bool) -> some View {
        VStack(spacing: CodingLayout.spacing) {
            if multi { tabs }
            gardenArea(plan)
        }
        .frame(width: plan.gardenWidth,
               height: plan.gardenHeight + (multi ? CodingLayout.tabsHeight + CodingLayout.spacing : 0))
    }

    private func gardenArea(_ plan: CodingLayout.Plan) -> some View {
        let g = stage.garden
        let cell = CGFloat(plan.cell) * 0.95
        return CodingGardenView(garden: g, bunny: stage.bunny, cell: cell,
                                facingLeft: stage.facingLeft,
                                mood: stage.failed ? .oops : stage.phase == .passed ? .yay : .idle,
                                bump: stage.bump, check: stage.check, trail: stage.trail)
    }

    private var owlBar: some View {
        HStack(spacing: 12) {
            Avatar(image: "avatar_owl", fallback: "🦉", tint: Palette.honey, size: 64)
            Text(session.line.isEmpty ? "排好积木，点「开始」，看小兔照着走！" : session.line)
                .font(.kid(20, weight: .bold))
                .foregroundStyle(session.line.isEmpty ? Palette.inkSoft : Palette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !session.line.isEmpty {
                Button { session.replay() } label: {
                    Image(systemName: "ear.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Palette.inkSoft)
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("再听一遍")
            }
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }

    // MARK: 程序和积木盒

    private func programArea(_ plan: CodingLayout.Plan) -> some View {
        CodingProgramView(program: editor.program, limits: level.limitsValue, u: CGFloat(plan.unit), decor: session.decor,
                          actions: CodingProgramActions(block: { editor.remove($0) }, slot: { editor.moveCursor($0) },
                                                        count: { editor.setCount($0, $1) }, enabled: !stage.busy))
    }

    private func paletteArea(_ plan: CodingLayout.Plan) -> some View {
        CodingPaletteView(limits: level.limitsValue, side: CGFloat(plan.palette.side), rows: plan.palette.rows,
                          available: { editor.refusal($0) == nil }, enabled: !stage.busy) { editor.tap($0) }
            .frame(height: CGFloat(plan.palette.height))
    }

    private func controls(_ plan: CodingLayout.Plan) -> some View {
        let phase = stage.phase
        // 四个小按钮一样宽、够手指点；剩下的都给「开始」
        let gap: CGFloat = 12
        let tool = min(100, (CGFloat(plan.programWidth) - 4 * gap) / 6)
        let (icon, title, tint): (String, String, Color) = {
            switch phase {
            case .running: return ("pause.fill", "停", Palette.honey)
            case .paused: return ("play.fill", "接着走", Palette.coral)
            case .failed: return ("arrow.counterclockwise", "再试一次", Palette.coral)
            case .passed: return ("arrow.counterclockwise", "再走一遍", Palette.sage)
            case .editing: return ("play.fill", "开始", Palette.coral)
            }
        }()
        return HStack(spacing: gap) {
            CodingToolButton(systemName: icon, label: title, tint: tint, foreground: .white,
                             enabled: !editor.program.isEmpty || phase != .editing) { session.run() }
                .frame(maxWidth: .infinity)
            CodingToolButton(systemName: "forward.frame.fill", label: "一步", enabled: !editor.program.isEmpty) { session.step() }
                .frame(width: tool)
            CodingToolButton(systemName: stage.fast ? "hare.fill" : "tortoise.fill", label: stage.fast ? "快" : "慢") {
                Sound.tap()
                stage.fast.toggle()
            }
            .frame(width: tool)
            CodingToolButton(systemName: "lightbulb.max", label: "提示", enabled: !stage.busy) { session.showHint() }
                .frame(width: tool)
            CodingToolButton(systemName: level.kind == .bug ? "arrow.uturn.backward" : "trash",
                             label: level.kind == .bug ? "重来" : "清空",
                             enabled: !stage.busy && editor.program != level.startProgram) {
                Sound.tap()
                confirmClear = true
            }
            .frame(width: tool)
        }
    }

    // MARK: 过关

    private func finish() {
        finishTask?.cancel()
        Sound.fanfare()
        finishTask = Task {
            // 让小兔高兴一下，再出结算页
            try? await Task.sleep(for: .milliseconds(1300))
            guard !Task.isCancelled else { return }
            let r = store.recordPuzzle(game: "coding", level: level.id, earned: session.earned)
            withAnimation(.spring(duration: 0.4)) { result = r }
        }
    }

    private func replay() {
        finishTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { result = nil }
        session.clear()
    }
}
