import SwiftUI
import Observation

/// 一课的进行状态：第几步、老师在说什么、做对做错、能不能下一步。各个游戏的教学共用。
@Observable
@MainActor
final class LessonFlow {
    enum Mood { case talk, happy, oops }

    let course: TutorialCourse
    let lesson: TutorialLesson

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
    /// 对手正在应着，先别动
    private(set) var busy = false
    /// 这一课以前没学完过（学完时用来判断是不是刚解锁了新的一组）
    var firstTime = true
    /// 进入新的一步时，棋盘那边要换局面
    var onStep: (() -> Void)?

    private var talkTask: Task<Void, Never>?

    init(course: TutorialCourse, lesson: TutorialLesson) {
        self.course = course
        self.lesson = lesson
    }

    var step: TutorialStep { lesson.steps[index] }
    var isLast: Bool { index == lesson.steps.count - 1 }
    var task: TutorialTask? { step.task }
    /// 现在能不能在棋盘上操作
    var awaitingAnswer: Bool { task != nil && !solved && !busy && !finished }

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

    func endReply() {
        busy = false
        if let after = step.after {
            mood = .talk
            talk(after, after: 0.15)
        }
        withAnimation(.spring(duration: 0.3)) { canContinue = true }
    }

    /// 做错了：第一次给提示，第二次亮出答案
    func fail(_ reason: String? = nil) {
        guard !solved else { return }
        wrong += 1
        mood = .oops
        Sound.oops()
        if wrong >= 2 {
            withAnimation(.spring(duration: 0.4)) { revealed = true }
            talk(TutorLines.showAnswer)
        } else {
            talk(reason ?? step.hint ?? TutorLines.retry)
        }
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
            flow.firstTime = !store.lessonDone(flow.course.game, flow.lesson.id)
            flow.begin()
        }
        .onDisappear { flow.stop() }
        .onChange(of: flow.finished) { _, done in
            if done { store.markLessonDone(flow.course.game, flow.lesson.id) }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            RoundIconButton(systemName: "chevron.left", label: "返回") { dismiss() }
            VStack(alignment: .leading, spacing: 6) {
                Text(flow.lesson.title)
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
            Label(flow.isLast ? "学完啦" : "下一步", systemImage: flow.isLast ? "checkmark" : "arrow.right")
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

// MARK: - 学完一课

private struct LessonDoneOverlay: View {
    @Environment(PlayerStore.self) private var store
    let flow: LessonFlow
    let accent: Color
    let onNextLesson: ((TutorialLesson) -> Void)?
    let onLeave: () -> Void

    @State private var appeared = false
    @State private var badge = false

    /// 学完这一课，下一组是不是刚刚解锁
    private var unlockedTrack: TutorialTrack? {
        let tracks = flow.course.tracks
        guard flow.firstTime,
              let i = tracks.firstIndex(where: { $0.lessons.contains { $0.id == flow.lesson.id } }),
              i + 1 < tracks.count, store.trackDone(flow.course, tracks[i]) else { return nil }
        return tracks[i + 1]
    }

    private var nextLesson: TutorialLesson? {
        let all = flow.course.lessons
        guard let i = all.firstIndex(of: flow.lesson), i + 1 < all.count else { return nil }
        let next = all[i + 1]
        // 下一课在还没解锁的组里就不给按钮
        let ti = flow.course.tracks.firstIndex { $0.lessons.contains(next) } ?? 0
        return store.trackUnlocked(flow.course, ti) ? next : nil
    }

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            Color.black.opacity(0.12).ignoresSafeArea()
            ConfettiView()
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Palette.honey, Palette.coral], startPoint: .top, endPoint: .bottom))
                        .frame(width: 150, height: 150)
                        .shadow(color: Palette.honey.opacity(0.6), radius: 18)
                    Image(systemName: flow.lesson.icon)
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(badge ? 1 : 0.3)
                .rotationEffect(.degrees(badge ? 0 : -30))
                .padding(.top, -96)

                Text("学会啦！")
                    .font(.kid(50, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text("「\(flow.lesson.title)」：\(flow.lesson.learned)")
                    .font(.kid(23, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)

                if let t = unlockedTrack {
                    HStack(spacing: 14) {
                        ArtImage(name: t.art, fallback: "🔓", contentMode: .fit)
                            .frame(width: 70, height: 70)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("新课程解锁！")
                                .font(.kid(17, weight: .heavy))
                                .foregroundStyle(Palette.coral)
                            Text(t.title)
                                .font(.kid(24, weight: .heavy))
                                .foregroundStyle(Palette.ink)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(accent.opacity(0.22), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .transition(.scale.combined(with: .opacity))
                }

                HStack(spacing: 18) {
                    if let next = nextLesson, let onNextLesson {
                        Button { Sound.tap(); onNextLesson(next) } label: {
                            Label("下一课", systemImage: "arrow.right")
                        }
                        .buttonStyle(PillButtonStyle(color: Palette.coral))
                    }
                    Button { Sound.tap(); onLeave() } label: {
                        Label("课程表", systemImage: "list.bullet")
                    }
                    .buttonStyle(PillButtonStyle(color: nextLesson == nil ? Palette.coral : Palette.paper,
                                                 foreground: nextLesson == nil ? .white : Palette.ink, size: 22))
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 60)
            .padding(.bottom, 36)
            .padding(.top, 20)
            .frame(minWidth: 540)
            .softCard(radius: 44)
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)
        }
        .task {
            Sound.fanfare()
            withAnimation(.spring(duration: 0.5, bounce: 0.4)) { appeared = true }
            withAnimation(.spring(duration: 0.7, bounce: 0.55).delay(0.25)) { badge = true }
            await VoiceOver.shared.speak(TutorLines.lessonDone(flow.lesson.learned))
            if unlockedTrack != nil {
                Sound.record()
                await VoiceOver.shared.speak(TutorLines.trackUnlocked)
            }
        }
    }
}
