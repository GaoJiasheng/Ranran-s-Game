import SwiftUI
import Observation

/// 一课的进行状态：第几步、老师在说什么、做对做错、能不能下一步。各个游戏的教学共用。
@Observable
@MainActor
final class LessonFlow {
    enum Mood { case talk, happy, oops }

    let course: TutorialCourse
    let lesson: TutorialLesson
    let mode: LessonMode

    private(set) var index = 0
    private(set) var line = ""
    private(set) var mood: Mood = .talk
    /// 这一步的题做对了（或者这一步本来就没有题）
    private(set) var solved = false
    /// 下一步按钮能不能按
    private(set) var canContinue = false
    private(set) var wrong = 0
    /// 错了两次，把答案亮出来
    private(set) var revealed = false
    private(set) var finished = false
    /// 对手正在应着（或者正在演示走错的后果），先别动
    private(set) var busy = false
    /// 做错过的题（第几步）；一次就做对的题不在里面
    private(set) var missed: Set<Int> = []
    /// 这一课以前没学完过（学完时用来判断是不是刚解锁了新的一组）
    var firstTime = true
    /// 开始这一课之前：这一课最好的奖杯、下一组开没开、这一组学没学完
    var cupBefore: LessonCup?
    var nextTrackOpenBefore = true
    var trackDoneBefore = false
    /// 进入新的一步时，棋盘那边要换局面
    var onStep: (() -> Void)?

    private var talkTask: Task<Void, Never>?

    init(course: TutorialCourse, lesson: TutorialLesson, mode: LessonMode = .lesson) {
        self.course = course
        self.lesson = lesson
        self.mode = mode
    }

    var step: TutorialStep { lesson.steps[index] }
    var isLast: Bool { index == lesson.steps.count - 1 }
    var task: TutorialTask? { step.task }
    /// 现在能不能在棋盘上操作
    var awaitingAnswer: Bool { task != nil && !solved && !busy && !finished }

    /// 一共几道题、几道一次就做对
    var taskCount: Int { lesson.steps.filter { $0.task != nil }.count }
    var firstTryCount: Int { taskCount - missed.count }
    var cup: LessonCup { LessonCup.earned(tasks: taskCount, firstTry: firstTryCount) }
    /// 每道题一次做对没有（按顺序），学完时画成一排小圆点
    var taskResults: [Bool] {
        lesson.steps.indices.filter { lesson.steps[$0].task != nil }.map { !missed.contains($0) }
    }

    func begin() { enter() }

    func next() {
        guard canContinue, !busy else { return }
        Sound.tap()
        if isLast {
            withAnimation(.spring(duration: 0.5)) { finished = true }
            VoiceOver.shared.stop()
            return
        }
        index += 1
        enter()
    }

    func replay() { talk(line) }

    private func enter() {
        onStep?()
        solved = step.task == nil
        canContinue = step.task == nil
        wrong = 0
        revealed = false
        mood = .talk
        talk(step.say)
    }

    /// 做对了
    func succeed() {
        guard !solved else { return }
        solved = true
        mood = .happy
        Sound.correct()
        talk(step.ok ?? TutorLines.praise.randomElement()!)
        if step.reply == nil {
            withAnimation(.spring(duration: 0.3)) { canContinue = true }
        }
    }

    /// 对手应着开始 / 结束
    func beginReply() { busy = true }

    func endReply(speakAfter: Bool = true) {
        busy = false
        if speakAfter, let after = step.after {
            mood = .talk
            talk(after, after: 0.15)
        }
        withAnimation(.spring(duration: 0.3)) { canContinue = true }
    }

    /// 循环的一步（征子、枷）：对方逃了，还没吃掉，同一步再来一次。
    /// 做错过就一直算做错过（missed 不清）。
    func rearm(_ text: String) {
        busy = false
        solved = false
        wrong = 0
        revealed = false
        mood = .talk
        talk(text, after: 0.15)
    }

    /// 找全部答案的题（点出所有的气）：找到一个，夸一句
    func found(_ remaining: Int) {
        Sound.pop()
        mood = .happy
        if remaining > 0 { talk(TutorLines.foundOne) }
    }

    /// 做错了：第一次给提示，第二次亮出答案
    func fail(_ reason: String? = nil) {
        guard !solved else { return }
        registerWrong()
        Sound.oops()
        respondToWrong(reason)
    }

    private func registerWrong() {
        wrong += 1
        missed.insert(index)
        mood = .oops
    }

    private func respondToWrong(_ reason: String?) {
        if wrong >= 2 {
            withAnimation(.spring(duration: 0.4)) { revealed = true }
            talk(TutorLines.showAnswer)
        } else {
            talk(reason ?? step.hint ?? TutorLines.retry)
        }
    }

    /// 走错了，先演示后果：棋盘那边把她的棋和对手的应着摆上去，这里说一句、至少停 1.5 秒。
    /// 等这个返回以后，棋盘退回去，再调 endConsequence()。算错一次。
    func showConsequence(_ text: String) async {
        guard !solved else { return }
        busy = true
        registerWrong()
        Sound.oops()
        talkTask?.cancel()
        withAnimation(.spring(duration: 0.3)) { line = text }
        let start = ContinuousClock.now
        await VoiceOver.shared.speak(text)
        let left = .milliseconds(1500) - (ContinuousClock.now - start)
        if left > .zero { try? await Task.sleep(for: left) }
        try? await Task.sleep(for: .milliseconds(250))
    }

    /// 后果演示完、棋盘已经退回：给提示（第二次错就亮答案），可以再试
    func endConsequence() {
        busy = false
        respondToWrong(nil)
    }

    /// 不算错，只是提醒一下（比如走了不合规则的棋）
    func nudge(_ text: String) {
        mood = .oops
        Sound.nope()
        talk(text)
    }

    private func talk(_ text: String, after delay: Double = 0) {
        talkTask?.cancel()
        withAnimation(.spring(duration: 0.3)) { line = text }
        talkTask = Task {
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled else { return }
            await VoiceOver.shared.speak(text)
        }
    }

    func stop() {
        talkTask?.cancel()
        VoiceOver.shared.stop()
    }
}

/// 教学页之间跳转：再练一次、复习、学完一组去下一盘。由课程表（或者复盘里打开的一课）提供。
struct LessonNavigator {
    var open: (LessonRoute) -> Void = { _ in }
    /// 回到游戏首页，选好这一档（没有就不显示「去下一盘」）
    var playGame: ((Int) -> Void)?
    /// 结算页上"回去"那个按钮的字
    var leaveTitle = "课程表"
}

private struct LessonNavigatorKey: EnvironmentKey {
    static let defaultValue = LessonNavigator()
}

extension EnvironmentValues {
    var lessonNavigator: LessonNavigator {
        get { self[LessonNavigatorKey.self] }
        set { self[LessonNavigatorKey.self] = newValue }
    }
}

// MARK: - 一课的画面

/// 左边（竖屏时是下面）是棋盘，右边是猫头鹰老师、进度和按钮。
struct LessonScaffold<Board: View>: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(VoiceOver.enabledKey) private var voiceOn = true

    let flow: LessonFlow
    let accent: Color
    let onNextLesson: ((TutorialLesson) -> Void)?
    @ViewBuilder let board: () -> Board

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            ZStack {
                CreamBackground(accent: accent)
                if wide {
                    HStack(spacing: 28) {
                        board()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        VStack(spacing: 18) {
                            header
                            teacher(fixed: false)
                            Spacer(minLength: 0)
                            controls
                        }
                        .frame(width: min(420, geo.size.width * 0.34))
                    }
                    .padding(28)
                } else {
                    VStack(spacing: 18) {
                        header
                        teacher(fixed: true)
                        board()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        controls
                    }
                    .padding(28)
                }

                if flow.finished {
                    LessonDoneOverlay(flow: flow, accent: accent, onNextLesson: onNextLesson) { dismiss() }
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
        }
        .onAppear {
            let course = flow.course
            if flow.mode.isLesson {
                flow.firstTime = !store.lessonDone(course.game, flow.lesson.id)
                flow.cupBefore = store.lessonCup(course.game, flow.lesson.id)
                if let ti = course.tracks.firstIndex(where: { $0.lessons.contains { $0.id == flow.lesson.id } }) {
                    flow.trackDoneBefore = store.trackDone(course, course.tracks[ti])
                    flow.nextTrackOpenBefore = ti + 1 >= course.tracks.count || store.trackUnlocked(course, ti + 1)
                }
            }
            flow.begin()
        }
        .onDisappear { flow.stop() }
        .onChange(of: flow.finished) { _, done in
            guard done else { return }
            let game = flow.course.game
            switch flow.mode {
            case .lesson:
                store.recordLesson(game, flow.lesson.id, cup: flow.cup)
                store.rememberOpenTracks(flow.course)
            case let .practice(id):
                store.recordPractice(game, id)
            case .review:
                store.recordReview(game)
            }
        }
    }

    private var title: String {
        switch flow.mode {
        case .lesson: flow.lesson.title
        case .practice: "练一练 · \(flow.lesson.title)"
        case .review: "复习"
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            RoundIconButton(systemName: "chevron.left", label: "返回") { dismiss() }
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.kid(28, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                StepDots(count: flow.lesson.steps.count, current: flow.index, tint: accent)
            }
            Spacer(minLength: 0)
            RoundIconButton(systemName: voiceOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
                            label: voiceOn ? "关掉声音" : "打开声音") {
                voiceOn.toggle()
                if !voiceOn { VoiceOver.shared.stop() }
            }
        }
    }

    /// fixed：竖屏时老师在棋盘上面，气泡固定三行高，话长话短都不会把棋盘顶来顶去
    private func teacher(fixed: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Avatar(image: "avatar_owl", fallback: "🦉", tint: Palette.honey, size: 86)
                .keyframeAnimator(initialValue: 0.0, trigger: flow.line) { v, y in
                    v.offset(y: y)
                } keyframes: { _ in
                    SpringKeyframe(-8, duration: 0.15)
                    SpringKeyframe(0, duration: 0.35, spring: .bouncy)
                }
            VStack(alignment: .leading, spacing: 10) {
                Text(flow.line)
                    .font(.kid(23, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .lineSpacing(4)
                    .lineLimit(fixed ? 3 : nil)
                    .minimumScaleFactor(fixed ? 0.75 : 1)
                    .fixedSize(horizontal: false, vertical: !fixed)
                    .contentTransition(.opacity)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .frame(height: fixed ? 96 : nil, alignment: .topLeading)
                HStack(spacing: 10) {
                    Button {
                        flow.replay()
                    } label: {
                        Label("再听一遍", systemImage: "ear.fill")
                            .font(.kid(16, weight: .bold))
                            .foregroundStyle(Palette.inkSoft)
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                    if flow.task != nil {
                        Label(taskLabel, systemImage: flow.solved ? "checkmark.circle.fill" : "hand.point.up.left.fill")
                            .font(.kid(16, weight: .heavy))
                            .foregroundStyle(flow.solved ? Palette.sage : Palette.coral)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(18)
            .background(.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(moodColor.opacity(flow.mood == .talk ? 0 : 0.8), lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        }
        .animation(.spring(duration: 0.3), value: flow.mood)
    }

    private var taskLabel: String {
        if flow.solved { return "做对了" }
        switch flow.task?.type {
        case "pick": return "点一点"
        default: return "轮到你"
        }
    }

    private var moodColor: Color {
        switch flow.mood {
        case .talk: .clear
        case .happy: Palette.sage
        case .oops: Palette.coral
        }
    }

    private var controls: some View {
        Button {
            flow.next()
        } label: {
            Label(flow.isLast ? (flow.mode.isLesson ? "学完啦" : "练完啦") : "下一步", systemImage: flow.isLast ? "checkmark" : "arrow.right")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PillButtonStyle(color: flow.canContinue ? Palette.coral : Palette.inkSoft.opacity(0.35), size: 26))
        .disabled(!flow.canContinue)
        .scaleEffect(flow.canContinue ? 1 : 0.97)
        .animation(.spring(duration: 0.3, bounce: 0.4), value: flow.canContinue)
    }
}

struct StepDots: View {
    let count: Int
    let current: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i < current ? tint : (i == current ? Palette.coral : Palette.ink.opacity(0.1)))
                    .frame(width: i == current ? 26 : 12, height: 10)
            }
        }
        .animation(.spring(duration: 0.35), value: current)
    }
}

