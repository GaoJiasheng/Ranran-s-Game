import SwiftUI

/// 做题的页面：上面是故事，中间是演故事的舞台，旁边是猫头鹰老师和答题板。
struct StoryPlayView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Narrator.voiceKey) private var voiceOn = true

    @State private var session: StorySession
    @State private var outcome: StoryOutcome?
    /// 正在飞向右上角的星星
    @State private var flying: [UUID] = []
    /// 从错题本进来时的那道错题
    private let mistake: StoryMistake?
    private let onNextLevel: ((StoryLevel) -> Void)?

    init(level: StoryLevel, onNextLevel: ((StoryLevel) -> Void)? = nil) {
        _session = State(initialValue: StorySession(level: level))
        mistake = nil
        self.onNextLevel = onNextLevel
    }

    init(mistake: StoryMistake) {
        _session = State(initialValue: StorySession(practice: mistake.problem))
        self.mistake = mistake
        onNextLevel = nil
    }

    private var tint: Color { session.level?.chapter.tint ?? Palette.lilac }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            ZStack {
                CreamBackground(accent: tint)
                VStack(spacing: 18) {
                    topBar(width: geo.size.width)
                    if wide {
                        HStack(alignment: .top, spacing: 20) {
                            VStack(spacing: 18) {
                                storyCard
                                stageCard.frame(maxHeight: .infinity)
                            }
                            // 答题板钉在底部，老师的话变长变短时键盘不会跟着跳
                            VStack(spacing: 18) {
                                coachCard
                                Spacer(minLength: 0)
                                answerCard
                            }
                            .frame(width: 360)
                        }
                    } else {
                        storyCard
                        stageCard.frame(maxHeight: .infinity)
                        HStack(alignment: .top, spacing: 18) {
                            coachCard.frame(maxWidth: .infinity)
                            answerCard.frame(width: 360)
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 22)

                ForEach(flying, id: \.self) { id in
                    FlyingStar(from: CGPoint(x: geo.size.width - 210, y: geo.size.height - 330),
                               to: CGPoint(x: geo.size.width - 96, y: 52)) {
                        land(id)
                    }
                    .allowsHitTesting(false)
                    .zIndex(20)
                }

                if let outcome {
                    StoryResultOverlay(outcome: outcome,
                                       onNext: outcome.level.next.map { next in { goNext(next) } },
                                       onAgain: playAgain,
                                       onLeave: { dismiss() })
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
        }
        .onAppear {
            session.player = store.name
            session.onFirstAnswer = { problem, right, answer in
                store.recordStoryAnswer(problem.schema, correct: right)
                if right {
                    store.recordStorySolved()
                    // 一次就答对：一颗星星飞到右上角
                    withAnimation(.spring(duration: 0.3)) { flying.append(UUID()) }
                } else if let level = session.level {
                    store.saveMistake(StoryMistake(level: level.number, problem: problem, answer: answer))
                }
            }
            if session.phase == .telling && session.sentence == nil { session.start() }
        }
        .onDisappear { session.stop() }
        .onChange(of: session.phase) { _, phase in
            guard phase == .finished, let level = session.level else { return }
            let stars = session.stars
            let record = store.recordStoryLevel(level, stars: stars)
            Sound.fanfare()
            withAnimation(.spring(duration: 0.5)) {
                outcome = StoryOutcome(level: level, stars: stars, correct: session.correctCount,
                                       total: session.problems.count, isRecord: record)
            }
        }
    }

    /// 星星落到计数器上，才真的加上去（数字跟着跳）
    private func land(_ id: UUID) {
        flying.removeAll { $0 == id }
        store.addStars(1)
        Sound.step(min(4 + session.streak, 10))
    }

    private func goNext(_ next: StoryLevel) {
        if let onNextLevel {
            onNextLevel(next)
        } else {
            dismiss()
        }
    }

    private func playAgain() {
        withAnimation(.easeOut(duration: 0.25)) { outcome = nil }
        session.restartLevel()
    }

    // MARK: 顶栏

    /// 宽屏：标题居中，进度在左；窄屏（竖着的小 iPad）：标题靠左、进度放在标题下面，免得挤在一起
    @ViewBuilder
    private func topBar(width: CGFloat) -> some View {
        if width >= 1000 {
            ZStack {
                VStack(spacing: 2) {
                    Text(title)
                        .font(.kid(30, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                    if let level = session.level {
                        Label(level.mode.title, systemImage: level.mode.icon)
                            .font(.kid(16, weight: .bold))
                            .foregroundStyle(Palette.inkSoft)
                    }
                }
                HStack(spacing: 16) {
                    backButton
                    if session.problems.count > 1 { progress }
                    Spacer()
                    trailingButtons
                }
            }
        } else {
            HStack(spacing: 14) {
                backButton
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.kid(26, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if session.problems.count > 1 { progress }
                }
                Spacer(minLength: 8)
                trailingButtons
            }
        }
    }

    private var backButton: some View {
        RoundIconButton(systemName: "chevron.left", label: "Back") { dismiss() }
    }

    @ViewBuilder
    private var trailingButtons: some View {
        if session.streak >= 2 { streakBadge.transition(.scale.combined(with: .opacity)) }
        RoundIconButton(systemName: voiceOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
                        label: voiceOn ? "Voice off" : "Voice on") {
            voiceOn.toggle()
            if !voiceOn { Narrator.shared.stop() }
        }
        StarCounter()
    }

    private var title: String {
        guard let level = session.level else { return "Try Again" }
        return "Level \(level.number) · \(level.chapter.title)"
    }

    /// 连续答对
    private var streakBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [Palette.honey, Palette.coral], startPoint: .top, endPoint: .bottom))
            Text("\(session.streak)")
                .font(.kid(24, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .softCard(radius: 24)
        .animation(.spring(duration: 0.4, bounce: 0.5), value: session.streak)
        .accessibilityLabel("\(session.streak) in a row")
    }

    private var progress: some View {
        HStack(spacing: 8) {
            ForEach(0..<session.problems.count, id: \.self) { i in
                let current = i == session.index && session.phase != .finished
                Capsule()
                    .fill(dotColor(i))
                    .frame(width: current ? 30 : 14, height: 14)
                    .overlay(Capsule().strokeBorder(.white, lineWidth: current ? 3 : 0))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .softCard(radius: 24)
        .animation(.spring(duration: 0.4), value: session.index)
    }

    private func dotColor(_ i: Int) -> Color {
        if i < session.firstTry.count { return session.firstTry[i] ? Palette.sage : Palette.blush }
        return i == session.index ? Palette.honey : Palette.ink.opacity(0.1)
    }

    // MARK: 故事

    private var storyCard: some View {
        let p = session.problem
        return HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(p.sentences.enumerated()), id: \.offset) { i, s in
                    sentenceRow(s, index: i, isQuestion: i == p.sentences.count - 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                Narrator.shared.say(p.sentences.map { StoryText.plain($0.text, p, player: store.name) }.joined())
            } label: {
                Image(systemName: "ear.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(width: 54, height: 54)
                    .background(Palette.cream, in: Circle())
            }
            .buttonStyle(PressableStyle(scale: 0.9))
            .accessibilityLabel("Listen again")
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 20)
        .softCard(radius: 36)
        .id(p.id)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
    }

    private func sentenceRow(_ s: StorySentence, index: Int, isQuestion: Bool) -> some View {
        let p = session.problem
        let on = session.sentence == index
        return Button {
            Narrator.shared.say(StoryText.plain(s.text, p, player: store.name))
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if isQuestion {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Palette.honey)
                }
                StoryText.styled(s.text, p, player: store.name)
                    .font(.kid(28, weight: isQuestion ? .heavy : .bold))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(on ? Palette.honey.opacity(0.28) : .clear)
            )
            .scaleEffect(on ? 1.02 : 1, anchor: .leading)
            .animation(.spring(duration: 0.35), value: on)
        }
        .buttonStyle(.plain)
    }

    // MARK: 舞台

    private var stageCard: some View {
        ZStack(alignment: .topLeading) {
            switch session.display {
            case .tokens:
                StoryStageView(stage: session.stage, player: store.name)
                    .padding(10)
                    .transition(.opacity)
            case .model:
                BarModelView(model: session.model, problem: session.problem, player: store.name,
                             answer: session.phase == .solved ? session.problem.answer : nil)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 16)
                    .transition(.opacity)
            case .blank:
                readOnlyPlaceholder
            }
            if session.display != .tokens {
                Label(session.display == .model ? "Model" : "Just read",
                      systemImage: session.display == .model ? StoryMode.model.icon : StoryMode.read.icon)
                    .font(.kid(16, weight: .heavy))
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Palette.cream, in: Capsule())
                    .padding(18)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottomTrailing) {
            if session.needsConfirm {
                Button(session.confirmTitle) { session.confirmActing() }
                    .buttonStyle(PillButtonStyle(color: Palette.sage, size: 22))
                    .padding(20)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottomLeading) {
            if session.display == .tokens, session.stage.comparing,
               session.phase == .answering || session.phase == .solved {
                Button {
                    session.stage.resetCounting()
                } label: {
                    Label(session.problem.usesPlates ? "Tap to count" : "Tap the glowing ones to count",
                          systemImage: "hand.tap.fill")
                        .font(.kid(16, weight: .bold))
                        .foregroundStyle(Palette.inkSoft)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Palette.cream.opacity(0.9), in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(18)
            }
        }
        .background(Palette.paper, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
        .softCard(radius: 36)
        .animation(.spring(duration: 0.4), value: session.needsConfirm)
        .animation(.spring(duration: 0.4), value: session.display)
    }

    private var readOnlyPlaceholder: some View {
        let p = session.problem
        return VStack(spacing: 16) {
            HStack(spacing: -12) {
                Avatar(image: p.a.image, fallback: p.a.emoji, tint: p.a.tint, size: 96)
                if let b = p.b { Avatar(image: b.image, fallback: b.emoji, tint: b.tint, size: 96) }
            }
            Text("Picture the story in your head")
                .font(.kid(22, weight: .bold))
                .foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: 猫头鹰老师

    private var coachCard: some View {
        let line = session.coach
        let p = session.problem
        return HStack(alignment: .top, spacing: 14) {
            Avatar(image: "avatar_owl", fallback: "🦉", tint: Palette.honey, size: 64)
            VStack(alignment: .leading, spacing: 14) {
                Group {
                    if let line {
                        StoryText.styled(line.text, p, player: store.name)
                    } else {
                        Text("Listen to the story")
                    }
                }
                .font(.kid(21, weight: .bold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(line?.text)
                .transition(.opacity)

                if let equation = line?.equation {
                    Text(equation)
                        .font(.kid(24, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                        .monospacedDigit()
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.paper.opacity(0.75), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if session.phase == .offerHelp, let help = session.help {
                    Button {
                        session.acceptHelp()
                    } label: {
                        Label(help == .act ? "Act it out" : "Draw a model",
                              systemImage: help == .act ? StoryMode.act.icon : StoryMode.model.icon)
                    }
                    .buttonStyle(PillButtonStyle(color: Palette.coral, size: 21))
                }
                if session.phase == .solved {
                    Button {
                        if session.isLast, mistake != nil { finishPractice() } else { session.next() }
                    } label: {
                        Label(session.isLast ? (mistake != nil ? "Done" : "See my stars") : "Next",
                              systemImage: session.isLast ? "flag.checkered" : "arrow.right")
                    }
                    .buttonStyle(PillButtonStyle(color: Palette.coral, size: 21))
                }
            }
        }
        .padding(20)
        .background(coachFill(line?.tone), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .softCard(radius: 30, fill: .clear)
        .animation(.spring(duration: 0.4), value: line)
        .animation(.spring(duration: 0.4), value: session.phase)
    }

    private func coachFill(_ tone: CoachLine.Tone?) -> Color {
        switch tone {
        case .hint:   Color(hex: 0xFCE7E3)
        case .praise: Color(hex: 0xE6F2E8)
        case .reveal: Color(hex: 0xFBEFD9)
        default:      Palette.paper
        }
    }

    private func finishPractice() {
        if let mistake, !session.revealed, session.firstTry.first == true {
            store.markMistakeFixed(mistake.id)
        }
        Sound.tap()
        dismiss()
    }

    // MARK: 答题板

    private var answerCard: some View {
        let p = session.problem
        let enabled = session.phase == .answering
        let done = session.phase == .solved || session.phase == .verifying
        let filled = session.input.isEmpty ? "  ?  " : " \(session.input) "
        return VStack(spacing: 16) {
            StoryText.styled(p.answerTemplate, p, player: store.name,
                             filled: done ? " \(p.answer) " : filled)
                .font(.kid(26, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: 72)
                .padding(.horizontal, 12)
                .background(done ? Color(hex: 0xE6F2E8) : Palette.cream,
                            in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .keyframeAnimator(initialValue: CGFloat(0), trigger: session.wrongShake) { v, x in
                    v.offset(x: x)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(-16, duration: 0.07)
                        CubicKeyframe(14, duration: 0.08)
                        CubicKeyframe(-9, duration: 0.08)
                        CubicKeyframe(5, duration: 0.07)
                        CubicKeyframe(0, duration: 0.08)
                    }
                }

            Keypad(enabled: enabled, canSubmit: enabled && !session.input.isEmpty,
                   type: session.type, backspace: session.backspace, submit: session.submit)
        }
        .padding(20)
        .softCard(radius: 34)
        .opacity(session.phase == .telling || session.phase == .acting ? 0.55 : 1)
        .animation(.easeOut(duration: 0.25), value: session.phase)
    }
}

/// 一关做完的结果
struct StoryOutcome: Equatable {
    let level: StoryLevel
    let stars: Int
    let correct: Int
    let total: Int
    let isRecord: Bool
}

// MARK: - 数字键盘

private struct Keypad: View {
    let enabled: Bool
    let canSubmit: Bool
    let type: (Int) -> Void
    let backspace: () -> Void
    let submit: () -> Void

    var body: some View {
        let rows: [[Int]] = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
        VStack(spacing: 10) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { n in digit(n) }
                }
            }
            HStack(spacing: 10) {
                key(action: backspace) {
                    Image(systemName: "delete.left.fill").font(.system(size: 24, weight: .bold))
                }
                .accessibilityLabel("Delete")
                digit(0)
                Button(action: submit) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(canSubmit ? Palette.coral : Palette.coral.opacity(0.35),
                                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(PressableStyle(scale: 0.92))
                .disabled(!canSubmit)
                .accessibilityLabel("Check")
            }
        }
        .disabled(!enabled)
    }

    private func digit(_ n: Int) -> some View {
        key(action: { type(n) }) {
            Text("\(n)").font(.kid(32, weight: .heavy))
        }
    }

    private func key<L: View>(action: @escaping () -> Void, @ViewBuilder label: () -> L) -> some View {
        Button(action: action) {
            label()
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(Palette.cream, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Palette.ink.opacity(0.06), lineWidth: 1.5))
        }
        .buttonStyle(PressableStyle(scale: 0.9))
    }
}

// MARK: - 一关的结果

struct StoryResultOverlay: View {
    let outcome: StoryOutcome
    let onNext: (() -> Void)?
    let onAgain: () -> Void
    let onLeave: () -> Void

    @State private var appeared = false
    @State private var lit = 0
    @State private var showRecord = false

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            Color.black.opacity(0.12).ignoresSafeArea()
            if outcome.stars == 3 { ConfettiView() }

            VStack(spacing: 18) {
                Avatar(image: "avatar_owl", fallback: "🦉", tint: Palette.honey, size: 150)
                    .shadow(color: Palette.honey.opacity(0.4), radius: 18, y: 8)
                    .padding(.top, -100)
                Text(title)
                    .font(.kid(48, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text("Right the first time: \(outcome.correct) / \(outcome.total)")
                    .font(.kid(23, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)

                HStack(spacing: 22) {
                    ForEach(0..<3, id: \.self) { i in
                        ZStack {
                            Image(systemName: "star.fill")
                                .font(.system(size: 58, weight: .bold))
                                .foregroundStyle(Palette.ink.opacity(0.08))
                            Image(systemName: "star.fill")
                                .font(.system(size: 58, weight: .bold))
                                .foregroundStyle(LinearGradient(colors: [Palette.honey, Palette.coral],
                                                                startPoint: .top, endPoint: .bottom))
                                .shadow(color: Palette.honey.opacity(0.6), radius: 10)
                                .scaleEffect(i < lit ? 1 : 0.2)
                                .opacity(i < lit ? 1 : 0)
                        }
                    }
                }
                .padding(.vertical, 6)

                Text(advice)
                    .font(.kid(19, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)

                HStack(spacing: 18) {
                    if let onNext {
                        Button { Sound.tap(); onNext() } label: {
                            Label("Next level", systemImage: "arrow.right")
                        }
                        .buttonStyle(PillButtonStyle(color: Palette.coral, size: 24))
                    }
                    Button { Sound.tap(); onAgain() } label: {
                        Label("Play again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(PillButtonStyle(color: Palette.sage, size: 24))
                }
                .padding(.top, 6)

                Button { Sound.tap(); onLeave() } label: {
                    Label("All levels", systemImage: "square.grid.2x2")
                }
                .font(.kid(19, weight: .bold))
                .foregroundStyle(Palette.inkSoft)
            }
            .padding(.horizontal, 60)
            .padding(.bottom, 36)
            .padding(.top, 20)
            .frame(minWidth: 540)
            .softCard(radius: 44)
            .overlay(alignment: .topTrailing) {
                if showRecord {
                    Text("New record!")
                        .font(.kid(22, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(Palette.coral, in: Capsule())
                        .overlay(Capsule().strokeBorder(.white, lineWidth: 4))
                        .rotationEffect(.degrees(10))
                        .offset(x: 26, y: -10)
                        .transition(.scale(scale: 2.2).combined(with: .opacity))
                }
            }
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)
        }
        .task {
            withAnimation(.spring(duration: 0.5, bounce: 0.4)) { appeared = true }
            for i in 0..<outcome.stars {
                try? await Task.sleep(for: .milliseconds(i == 0 ? 500 : 300))
                Sound.step(6 + i * 2)
                withAnimation(.spring(duration: 0.45, bounce: 0.6)) { lit = i + 1 }
            }
            if outcome.isRecord {
                try? await Task.sleep(for: .milliseconds(350))
                Sound.record()
                withAnimation(.spring(duration: 0.5, bounce: 0.5)) { showRecord = true }
            }
        }
    }

    private var title: String {
        switch outcome.stars {
        case 3: "Perfect!"
        case 2: "Great job!"
        default: "Finished!"
        }
    }

    private var advice: String {
        switch outcome.stars {
        case 3: "You understood every story. +\(outcome.correct) stars!"
        case 2: "+\(outcome.correct) stars! The tricky ones are saved for practice."
        default: "+\(outcome.correct) stars. Practice makes perfect!"
        }
    }
}

// MARK: - 飞向计数器的星星

/// 答对一题时，一颗星星从答题板弹起来，划一道弧线飞到右上角的星星计数器。
struct FlyingStar: View {
    let from: CGPoint
    let to: CGPoint
    let landed: () -> Void

    @State private var t: CGFloat = 0
    @State private var pop: CGFloat = 0.2

    var body: some View {
        // 二次贝塞尔：控制点在起点和终点上方，飞出一道弧
        let control = CGPoint(x: (from.x + to.x) / 2 - 140, y: min(from.y, to.y) - 120)
        Image(systemName: "star.fill")
            .font(.system(size: 64, weight: .bold))
            .foregroundStyle(LinearGradient(colors: [Palette.honey, Palette.coral], startPoint: .top, endPoint: .bottom))
            .shadow(color: Palette.honey.opacity(0.7), radius: 14)
            .scaleEffect(pop * (1 - t * 0.55))
            .rotationEffect(.degrees(Double(t) * 220))
            .modifier(Arc(t: t, from: from, control: control, to: to))
            .task {
                withAnimation(.spring(duration: 0.35, bounce: 0.6)) { pop = 1.25 }
                try? await Task.sleep(for: .milliseconds(380))
                withAnimation(.easeIn(duration: 0.65)) { t = 1 }
                try? await Task.sleep(for: .milliseconds(660))
                landed()
            }
    }

    /// 让 t 的动画逐帧算出弧线上的位置（只动画 position 的话会走直线）
    private struct Arc: AnimatableModifier {
        var t: CGFloat
        let from: CGPoint
        let control: CGPoint
        let to: CGPoint
        var animatableData: CGFloat {
            get { t }
            set { t = newValue }
        }
        func body(content: Content) -> some View {
            let u = 1 - t
            content.position(x: u * u * from.x + 2 * u * t * control.x + t * t * to.x,
                             y: u * u * from.y + 2 * u * t * control.y + t * t * to.y)
        }
    }
}
