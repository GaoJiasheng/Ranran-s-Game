import SwiftUI

/// 做题的页面：上面是故事，中间是演故事的舞台，旁边是猫头鹰老师和答题板。
struct StoryPlayView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Narrator.voiceKey) private var voiceOn = true
    @AppStorage(StoryLevel.unlockAllKey) private var unlockAll = false

    @State private var session: StorySession
    @State private var outcome: StoryOutcome?
    /// 正在飞向右上角的星星（星星答对时就已经记上了，计数器先不算还在飞的，落地才跳）
    @State private var flying: [UUID] = []
    /// 一次就答对、但这道题的星星以前拿过了：不飞星星，只冒一个小勾
    @State private var acks: [UUID] = []
    /// 这一轮里每道题拿没拿到新星星（和 session.firstTry 一一对应）
    @State private var earned: [Bool] = []
    /// 错题练习：正在练的那道错题，和后面排着的
    @State private var mistake: StoryMistake?
    @State private var queue: [StoryMistake] = []
    @State private var practiceTotal = 0
    /// 练一练做完了
    @State private var mixDone = false
    private let onNextLevel: ((StoryLevel) -> Void)?

    init(level: StoryLevel, onNextLevel: ((StoryLevel) -> Void)? = nil) {
        _session = State(initialValue: StorySession(level: level))
        self.onNextLevel = onNextLevel
    }

    init(mistake: StoryMistake) {
        self.init(mistakes: [mistake])
    }

    /// 一道接一道练错题（加减乘除首页的 "Tricky ones"）
    init(mistakes: [StoryMistake]) {
        let first = mistakes[0]
        _session = State(initialValue: StorySession(practice: first))
        _mistake = State(initialValue: first)
        _queue = State(initialValue: Array(mistakes.dropFirst()))
        _practiceTotal = State(initialValue: mistakes.count)
        onNextLevel = nil
    }

    /// 练一练（加减乘除首页的 "Practice mix"）：多练做得不好的题型
    init(mix: StoryMix.Pick) {
        _session = State(initialValue: StorySession(mix: mix))
        onNextLevel = nil
    }

    private var tint: Color {
        if let level = session.level { return level.chapter.tint }
        return session.kind == .mix ? Palette.sage : Palette.lilac
    }
    /// 星星记在哪一关上：错题、练一练里的题记回那道题原来的关
    private var starLevel: StoryLevel? { session.problemLevel }

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

                let launch = CGPoint(x: geo.size.width - 210, y: geo.size.height - 330)
                ForEach(flying, id: \.self) { id in
                    FlyingStar(from: launch, to: CGPoint(x: geo.size.width - 96, y: 52)) {
                        land(id)
                    }
                    .allowsHitTesting(false)
                    .zIndex(20)
                }
                ForEach(acks, id: \.self) { id in
                    AlreadyCollected(at: launch) { acks.removeAll { $0 == id } }
                        .allowsHitTesting(false)
                        .zIndex(20)
                }

                if let outcome {
                    StoryResultOverlay(outcome: outcome,
                                       onNext: outcome.canGoNext ? outcome.level.next.map { next in { goNext(next) } } : nil,
                                       onAgain: playAgain,
                                       onLeave: { dismiss() })
                        .transition(.opacity)
                        .zIndex(10)
                }
                if mixDone, let pick = session.mix {
                    StoryMixResultOverlay(headline: StoryMix.headline(pick), correct: session.correctCount,
                                          slots: slots(), onAgain: anotherMix, onLeave: { dismiss() })
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
        }
        .onAppear {
            configure(session)
            if session.phase == .telling && session.sentence == nil { session.start() }
            #if DEBUG
            // 调试截图用：启动参数 -result 4 直接弹出"第一下就答对 4 题"的结算
            let shown = UserDefaults.standard.integer(forKey: "result")
            if shown > 0, let level = session.level {
                session.stop()
                let total = session.mainCount, correct = min(shown, total)
                let rating = correct >= total ? 3 : correct * 4 >= total * 3 ? 2 : 1
                outcome = makeOutcome(level: level, rating: rating, correct: correct,
                                      slots: (0..<total).map { $0 < correct ? ($0 % 3 == 2 ? .had : .new) : .missed },
                                      isRecord: true, wasUnlocked: false)
            }
            #endif
        }
        .onDisappear { session.stop() }
        .onChange(of: session.phase) { _, phase in
            guard phase == .finished else { return }
            if session.kind == .mix {
                Sound.fanfare()
                withAnimation(.spring(duration: 0.5)) { mixDone = true }
                return
            }
            guard let level = session.level else { return }
            let rating = session.stars
            let nextWasOpen = level.next.map { store.storyUnlocked($0, unlockAll: unlockAll) } ?? true
            let record = store.recordStoryLevel(level, stars: rating)
            let slots = slots()
            Sound.fanfare()
            withAnimation(.spring(duration: 0.5)) {
                outcome = makeOutcome(level: level, rating: rating, correct: session.correctCount,
                                      slots: slots, isRecord: record, wasUnlocked: nextWasOpen)
            }
        }
    }

    private func makeOutcome(level: StoryLevel, rating: Int, correct: Int, slots: [StoryOutcome.Slot],
                             isRecord: Bool, wasUnlocked: Bool) -> StoryOutcome {
        let next = level.next
        let nextOpen = next.map { store.storyUnlocked($0, unlockAll: unlockAll) } ?? false
        return StoryOutcome(level: level, stars: rating, correct: correct, total: slots.count, isRecord: isRecord,
                            slots: slots, levelStars: store.storyStars(level), levelMax: level.maxStars,
                            passed: store.storyPassed(level),
                            opened: !wasUnlocked && nextOpen ? next : nil,
                            canGoNext: store.storyPassed(level) && nextOpen)
    }

    /// 这一轮每道题一个星位：拿到新星星的、答对但星星以前拿过的、答错的
    private func slots() -> [StoryOutcome.Slot] {
        session.firstTry.indices.map { i in
            guard session.firstTry[i] else { return .missed }
            return i < earned.count && earned[i] ? .new : .had
        }
    }

    /// 把这一轮的作答接到存档上：星星、统计、错题本
    private func configure(_ s: StorySession) {
        s.player = store.name
        let tracked = s.kind != .mistakes
        s.onFirstAnswer = { [weak s] problem, right, answer, step in
            store.recordStoryAnswer(problem.schema, correct: right)
            // 星星和错题记在这道题自己的那一关（练一练里的题来自好几关）
            let home = s?.problemLevel
            if right {
                store.recordStorySolved()
                // 一次就答对：这道题的星星还没拿过，就飞一颗到右上角；拿过了只冒一个小勾
                let got = home.map { store.collectStoryStar(problem, level: $0) } ?? false
                if tracked { earned.append(got) }
                withAnimation(.spring(duration: 0.3)) {
                    if got { flying.append(UUID()) } else { acks.append(UUID()) }
                }
            } else if tracked, let home {
                earned.append(false)
                store.saveMistake(StoryMistake(level: home.number, problem: problem, answer: answer, step: step))
            }
        }
        // 再练一轮：不算成绩、不给星星，第一下就答对的话错题本里这道题算练会了
        s.onRetryAnswer = { [weak s] problem, right in
            guard right, let home = s?.problemLevel else { return }
            store.markStoryProblemFixed(problem, level: home.number)
        }
        // 读题关先选算式：第一下选得对不对，按题型记下来（家长页上和算错分开显示）
        s.onChoice = { problem, right in
            store.recordStoryChoice(problem.schema, correct: right)
        }
    }

    /// 练一练做完了，再来一组
    private func anotherMix() {
        guard let pick = store.storyMixPick(unlockAll: unlockAll) else { dismiss(); return }
        session.stop()
        let fresh = StorySession(mix: pick)
        configure(fresh)
        earned = []
        withAnimation(.easeOut(duration: 0.25)) {
            mixDone = false
            session = fresh
        }
        fresh.start()
    }

    /// 星星落到计数器上，计数器才跳（星星本身答对时就已经记上了）
    private func land(_ id: UUID) {
        flying.removeAll { $0 == id }
        Sound.step(min(4 + session.streak, 10))
    }

    private func goNext(_ next: StoryLevel) {
        if let onNextLevel {
            onNextLevel(next)
        } else {
            dismiss()
        }
    }

    /// 再玩一次：换下一套题，刚做过的那套不会原样再来
    private func playAgain() {
        guard let level = session.level else { return }
        session.stop()
        let fresh = StorySession(level: level, avoiding: session.problemKeys)
        configure(fresh)
        earned = []
        withAnimation(.easeOut(duration: 0.25)) {
            outcome = nil
            session = fresh
        }
        fresh.start()
    }

    // MARK: 顶栏

    /// 横着的大屏：标题居中，进度在左；其余（竖屏、横着的小 iPad）：标题靠左、进度放在标题下面，免得挤在一起
    @ViewBuilder
    private func topBar(width: CGFloat) -> some View {
        if width >= 1250 {
            ZStack {
                VStack(spacing: 2) {
                    Text(title)
                        .font(.kid(30, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                    if session.isRetry {
                        Label("Tricky ones again", systemImage: "arrow.counterclockwise")
                            .font(.kid(16, weight: .bold))
                            .foregroundStyle(Palette.coral)
                    } else if let level = session.level {
                        Label(level.mode.title, systemImage: level.mode.icon)
                            .font(.kid(16, weight: .bold))
                            .foregroundStyle(Palette.inkSoft)
                    } else if let pick = session.mix {
                        mixLabel(pick)
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
                    if let pick = session.mix, !session.isRetry {
                        mixLabel(pick)
                    }
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
        StarCounter(value: store.storyStarTotal - flying.count)
    }

    private var title: String {
        if session.kind == .mix { return "Practice mix" }
        guard let level = session.level else {
            // 错题练习：几道题一道接一道时显示做到第几道
            let n = practiceTotal - queue.count
            return practiceTotal > 1 ? "Tricky ones · \(n) of \(practiceTotal)" : "Tricky ones"
        }
        return "Level \(level.position) · \(level.chapter.title)"
    }

    /// 练一练这次多练哪几种："More practice: Who has more? and Sharing"
    private func mixLabel(_ pick: StoryMix.Pick) -> some View {
        Label(StoryMix.headline(pick), systemImage: "sparkles")
            .font(.kid(16, weight: .bold))
            .foregroundStyle(Color(hex: 0x4E8A5C))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
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

    /// 一关的进度：每道题一个点，第一下就答对是绿的、答错是粉的。
    /// 再练一轮时，前面那一轮收成一个"✓ 7/10"，后面跟着 ↻ 和要再做的那几道题的点。
    private var progress: some View {
        HStack(spacing: 8) {
            if session.isRetry {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .black))
                    Text("\(session.correctCount)/\(session.mainCount)")
                        .font(.kid(16, weight: .heavy))
                        .monospacedDigit()
                }
                .foregroundStyle(Palette.sage)
                .transition(.scale.combined(with: .opacity))
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Palette.coral)
                    .padding(.leading, 4)
                ForEach(0..<session.retryCount, id: \.self) { j in
                    let current = session.mainCount + j == session.index && session.phase != .finished
                    Capsule()
                        .fill(retryColor(j))
                        .frame(width: current ? 30 : 14, height: 14)
                        .overlay(Capsule().strokeBorder(.white, lineWidth: current ? 3 : 0))
                }
            } else {
                ForEach(0..<session.mainCount, id: \.self) { i in
                    let current = i == session.index && session.phase != .finished
                    Capsule()
                        .fill(dotColor(i))
                        .frame(width: current ? 30 : 14, height: 14)
                        .overlay(Capsule().strokeBorder(.white, lineWidth: current ? 3 : 0))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .softCard(radius: 24)
        .animation(.spring(duration: 0.4), value: session.index)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(session.isRetry
            ? "Tricky ones again: \(session.index - session.mainCount + 1) of \(session.retryCount)"
            : "Problem \(session.index + 1) of \(session.mainCount)")
    }

    private func dotColor(_ i: Int) -> Color {
        if i < session.firstTry.count { return session.firstTry[i] ? Palette.sage : Palette.blush }
        return i == session.index ? Palette.honey : Palette.ink.opacity(0.1)
    }

    private func retryColor(_ j: Int) -> Color {
        if j < session.retryResults.count { return session.retryResults[j] ? Palette.sage : Palette.blush }
        return session.mainCount + j == session.index ? Palette.coral : Palette.blush.opacity(0.35)
    }

    // MARK: 故事

    private var storyCard: some View {
        let p = session.problem
        let rows = session.rows
        // 分两问的时候多一行，字稍微小一点，舞台不会被挤得太小
        let size: CGFloat = rows.count >= 5 ? 25 : 28
        return HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: rows.count >= 5 ? 6 : 10) {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    sentenceRow(row, index: i, size: size)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                Narrator.shared.say(rows.map { StoryText.plain($0.text, p, player: store.name) })
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

    private func sentenceRow(_ s: StoryRow, index: Int, size: CGFloat) -> some View {
        let p = session.problem
        let on = session.sentence == index
        // 分两问的时候，没在问的那一问调淡
        let dim = session.activeRow.map { s.isQuestion && $0 != index } ?? false
        return Button {
            Narrator.shared.say(StoryText.plain(s.text, p, player: store.name))
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if let tag = s.tag {
                    Text("(\(tag))")
                        .font(.kid(size * 0.85, weight: .black))
                        .foregroundStyle(dim ? Palette.inkSoft : Palette.coral)
                } else if s.isQuestion {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Palette.honey)
                }
                StoryText.styled(s.text, p, player: store.name)
                    .font(.kid(size, weight: s.isQuestion ? .heavy : .bold))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(dim ? 0.45 : 1)
            .animation(.easeOut(duration: 0.3), value: dim)
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
                             answer: session.filled)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 16)
                    .transition(.opacity)
            case .tens:
                if let calc = session.problem.tensOnes {
                    TensOnesView(calc: calc, solved: session.filled != nil)
                        .padding(.horizontal, 14)
                        .padding(.top, 58)
                        .padding(.bottom, 16)
                        .transition(.opacity)
                }
            case .blank:
                if let choice = session.choice, session.phase == .choosing || session.chosen != nil {
                    ChoiceBoard(choice: choice, chosen: session.chosen, wrong: session.wrongChoices,
                                shake: session.choiceShake, enabled: session.phase == .choosing,
                                pick: session.choose)
                        .padding(.horizontal, 20)
                        .padding(.top, 58)
                        .padding(.bottom, 20)
                        .transition(.opacity)
                } else {
                    readOnlyPlaceholder
                }
            }
            if session.display != .tokens {
                Label(stageLabel.0, systemImage: stageLabel.1)
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

    /// 舞台左上角的小标签
    private var stageLabel: (String, String) {
        switch session.display {
        case .model:  ("Model", StoryMode.model.icon)
        case .tens:   ("Tens and ones", "square.grid.3x3.fill")
        default:      session.phase == .choosing || session.chosen != nil
                        ? ("What do we do?", "questionmark.bubble.fill")
                        : ("Just read", StoryMode.read.icon)
        }
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
                        switch help {
                        case .act:   Label("Act it out", systemImage: StoryMode.act.icon)
                        case .model: Label("Draw a model", systemImage: StoryMode.model.icon)
                        case .tens:  Label("Tens and ones", systemImage: "square.grid.3x3.fill")
                        }
                    }
                    .buttonStyle(PillButtonStyle(color: Palette.coral, size: 21))
                }
                if session.phase == .solved {
                    Button {
                        if session.isLast, mistake != nil { finishPractice() } else { session.next() }
                    } label: {
                        Label(nextTitle, systemImage: session.isLast && (mistake == nil || queue.isEmpty) ? "flag.checkered" : "arrow.right")
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

    private var nextTitle: String {
        guard session.isLast else { return "Next" }
        if mistake != nil { return queue.isEmpty ? "Done" : "Next" }
        return "See my stars"
    }

    /// 一道错题练完：第一下就做对了就算练会了（同一道题错过几次的记录都算）；后面还有就接着下一道
    private func finishPractice() {
        if let mistake, !session.revealed, session.firstTry.first == true {
            store.markMistakeFixed(mistake.id)
            store.markStoryProblemFixed(mistake.problem, level: mistake.level)
        }
        Sound.tap()
        guard !queue.isEmpty else { dismiss(); return }
        session.stop()
        let next = queue.removeFirst()
        let fresh = StorySession(practice: next)
        configure(fresh)
        withAnimation(.easeOut(duration: 0.25)) {
            mistake = next
            session = fresh
        }
        fresh.start()
    }

    // MARK: 答题板

    private var answerCard: some View {
        let p = session.problem
        let enabled = session.phase == .answering
        let done = session.filled != nil
        let filled = session.input.isEmpty ? "  ?  " : " \(session.input) "
        return VStack(spacing: 16) {
            StoryText.styled(session.answerTemplate, p, player: store.name,
                             filled: session.filled.map { " \($0) " } ?? filled)
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
        .opacity(session.phase == .telling || session.phase == .acting || session.phase == .choosing ? 0.55 : 1)
        .animation(.easeOut(duration: 0.25), value: session.phase)
    }
}

/// 一关做完的结果
struct StoryOutcome: Equatable {
    /// 结算上每道题一个星位
    enum Slot: Equatable {
        /// 第一下就答对，拿到这道题的星星
        case new
        /// 第一下就答对，但这道题的星星以前就拿过了
        case had
        /// 第一下答错了
        case missed
    }

    let level: StoryLevel
    /// 这一轮做得怎么样（1~3）：3 = 全对（皇冠），2 = 过关
    let stars: Int
    let correct: Int
    let total: Int
    let isRecord: Bool
    let slots: [Slot]
    /// 这一关现在一共拿到的星星和上限
    let levelStars: Int
    let levelMax: Int
    /// 这一关过关了（这一轮或者以前）
    let passed: Bool
    /// 这一轮刚刚打开的下一关
    let opened: StoryLevel?
    /// 能不能直接去下一关
    let canGoNext: Bool

    var newStars: Int { slots.filter { $0 == .new }.count }
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
            if outcome.correct == outcome.total { ConfettiView() }

            VStack(spacing: 16) {
                Avatar(image: "avatar_owl", fallback: "🦉", tint: Palette.honey, size: 150)
                    .shadow(color: Palette.honey.opacity(0.4), radius: 18, y: 8)
                    .padding(.top, -100)
                Text(title)
                    .font(.kid(48, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text("Right the first time: \(outcome.correct) / \(outcome.total)")
                    .font(.kid(23, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)

                slots.padding(.vertical, 4)
                levelTally

                Text(advice)
                    .font(.kid(19, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 520)

                HStack(spacing: 18) {
                    // 这一轮过关了"下一关"在前；没过关"再玩一次（换一套题）"在前
                    if let onNext, outcome.stars >= 2 { nextButton(onNext, color: Palette.coral) }
                    Button { Sound.tap(); onAgain() } label: {
                        Label("Play again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(PillButtonStyle(color: outcome.stars >= 2 && onNext != nil ? Palette.sage : Palette.coral, size: 24))
                    if let onNext, outcome.stars < 2 { nextButton(onNext, color: Palette.sage) }
                }
                .padding(.top, 6)

                Button { Sound.tap(); onLeave() } label: {
                    Label("All levels", systemImage: "square.grid.2x2")
                }
                .font(.kid(19, weight: .bold))
                .foregroundStyle(Palette.inkSoft)
            }
            .padding(.horizontal, 56)
            .padding(.bottom, 32)
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
            // 第一下就答对的那几个星位依次亮起来；只有新星星才响
            var step = 0
            for (i, slot) in outcome.slots.enumerated() where slot != .missed {
                try? await Task.sleep(for: .milliseconds(step == 0 ? 500 : 180))
                if slot == .new { Sound.step(min(4 + step, 10)) }
                step += 1
                withAnimation(.spring(duration: 0.45, bounce: 0.6)) { lit = i + 1 }
            }
            if outcome.isRecord {
                try? await Task.sleep(for: .milliseconds(350))
                Sound.record()
                withAnimation(.spring(duration: 0.5, bounce: 0.5)) { showRecord = true }
            }
        }
    }

    private func nextButton(_ action: @escaping () -> Void, color: Color) -> some View {
        Button { Sound.tap(); action() } label: {
            Label("Next level", systemImage: "arrow.right")
        }
        .buttonStyle(PillButtonStyle(color: color, size: 24))
    }

    /// 这一轮每道题一个星位：拿到新星星的亮金色（= 这一轮飞到右上角的星星）；
    /// 答对了但星星以前就拿过的，是一颗淡淡的星星里一个勾；答错的空着。
    private var slots: some View {
        let size: CGFloat = outcome.total <= 6 ? 54 : outcome.total <= 8 ? 46 : 40
        return HStack(spacing: outcome.total <= 6 ? 16 : 10) {
            ForEach(Array(outcome.slots.enumerated()), id: \.offset) { i, slot in
                let on = i < lit
                ZStack {
                    Image(systemName: "star.fill")
                        .font(.system(size: size, weight: .bold))
                        .foregroundStyle(Palette.ink.opacity(0.08))
                    switch slot {
                    case .new:
                        Image(systemName: "star.fill")
                            .font(.system(size: size, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: [Palette.honey, Palette.coral],
                                                            startPoint: .top, endPoint: .bottom))
                            .shadow(color: Palette.honey.opacity(0.6), radius: 10)
                            .scaleEffect(on ? 1 : 0.2)
                            .opacity(on ? 1 : 0)
                    case .had:
                        ZStack {
                            Image(systemName: "star.fill")
                                .font(.system(size: size, weight: .bold))
                                .foregroundStyle(Palette.honey.opacity(0.32))
                            Image(systemName: "checkmark")
                                .font(.system(size: size * 0.34, weight: .black))
                                .foregroundStyle(.white)
                                .offset(y: size * 0.04)
                        }
                        .scaleEffect(on ? 1 : 0.6)
                        .opacity(on ? 1 : 0)
                    case .missed:
                        EmptyView()
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(outcome.newStars) new stars")
    }

    /// "★ 14 / 24 in this level  +3 new"
    private var levelTally: some View {
        HStack(spacing: 10) {
            Image(systemName: "star.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Palette.honey)
            Text("\(outcome.levelStars) / \(outcome.levelMax)")
                .font(.kid(22, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .monospacedDigit()
            Text(outcome.levelStars >= outcome.levelMax ? "All stars in this level!" : "in this level")
                .font(.kid(18, weight: .bold))
                .foregroundStyle(Palette.inkSoft)
            if outcome.newStars > 0 {
                Text("+\(outcome.newStars) new")
                    .font(.kid(17, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Palette.coral, in: Capsule())
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(Palette.honey.opacity(0.16), in: Capsule())
    }

    private var title: String {
        switch outcome.stars {
        case 3: "Perfect!"
        case 2: "Great job!"
        default: "Good try!"
        }
    }

    private var advice: String {
        let had = outcome.newStars == 0 && outcome.correct > 0 && outcome.levelStars < outcome.levelMax
            ? " You had these stars already. A new set has new ones!" : ""
        if outcome.stars >= 3 {
            if let opened = outcome.opened { return "You understood every story and earned a crown! Level \(opened.position) is open now." }
            return "You understood every story and earned a crown!" + had
        }
        if outcome.stars == 2 {
            if let opened = outcome.opened { return "You passed! Level \(opened.position) is open now." }
            return "You passed this level!" + had
        }
        let need = "\(outcome.level.passMark) of \(outcome.total)"
        if outcome.passed { return "Get \(need) right the first time to beat this round. Try a new set!" }
        if let next = outcome.level.next {
            return "Get \(need) right the first time to open Level \(next.position). Let's try a new set!"
        }
        return "Get \(need) right the first time to pass. Let's try a new set!"
    }
}

/// 一次就答对、但这道题的星星以前拿过了：答题板上冒出一个小勾，往上飘一下就没了（没有星星飞走）
private struct AlreadyCollected: View {
    let at: CGPoint
    let done: () -> Void

    @State private var shown = false
    @State private var rise: CGFloat = 0

    var body: some View {
        Label("Star already yours", systemImage: "checkmark.circle.fill")
            .font(.kid(19, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Palette.sage, in: Capsule())
            .overlay(Capsule().strokeBorder(.white, lineWidth: 3))
            .shadow(color: Palette.sage.opacity(0.4), radius: 10, y: 4)
            .fixedSize()
            .scaleEffect(shown ? 1 : 0.5)
            .opacity(shown ? 1 : 0)
            .position(x: at.x, y: at.y - rise)
            .task {
                withAnimation(.spring(duration: 0.35, bounce: 0.5)) { shown = true }
                withAnimation(.easeOut(duration: 1.4)) { rise = 60 }
                try? await Task.sleep(for: .milliseconds(1100))
                withAnimation(.easeIn(duration: 0.3)) { shown = false }
                try? await Task.sleep(for: .milliseconds(320))
                done()
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
