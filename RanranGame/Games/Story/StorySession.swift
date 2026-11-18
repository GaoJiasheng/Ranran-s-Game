import SwiftUI

/// 猫头鹰老师说的话
struct CoachLine: Equatable {
    enum Tone { case info, hint, praise, reveal }
    /// 模板文字，{a} {b} 显示时再换成名字
    var text: String
    var tone: Tone = .info
    /// 算式，答对或揭晓时单独一行显示
    var equation: String? = nil
}

/// 舞台上显示什么：实物、线段图，还是什么都不显示（只看文字）
enum StageDisplay: Equatable { case tokens, model, blank }

/// 答错以后可以给的帮助：画线段图，或者用实物演
enum StoryHelp: Equatable { case model, act }

/// 一关（或者错题本里的一道题）的流程：
/// 讲故事（边读边摆 / 边读边画）→ 演一演（孩子拖动）→ 答一答 → 答错了就针对这种错法解释，再画一画、演一演。
@Observable
@MainActor
final class StorySession {
    enum Phase: Equatable { case telling, acting, answering, offerHelp, verifying, solved, finished }

    let level: StoryLevel?
    let mode: StoryMode
    let problems: [StoryProblem]
    let stage: StoryStage

    private(set) var index = 0
    private(set) var phase: Phase = .telling
    /// 正在读、正在演的那一句
    private(set) var sentence: Int?
    private(set) var coach: CoachLine?
    /// 现在等孩子演的动作
    private(set) var acting: StoryAction?
    private(set) var display: StageDisplay = .tokens
    /// 线段图画到第几句
    private(set) var modelStep = 0
    private(set) var help: StoryHelp?
    private(set) var revealed = false
    /// 每道题第一次答得对不对
    private(set) var firstTry: [Bool] = []
    /// 连续一次就答对几道
    private(set) var streak = 0
    /// 每答对一道就 +1，界面用它放星星飞过去的动画
    private(set) var starBurst = 0
    private(set) var wrongShake = 0
    var input = ""

    var player = PlayerStore.defaultName
    /// 每道题第一次作答：题、对不对、答的数
    var onFirstAnswer: ((StoryProblem, Bool, Int) -> Void)?

    private var flow: Task<Void, Never>?
    private var waiter: CheckedContinuation<Void, Never>?
    private var actingStart: [Spot: Int] = [:]
    private var answered = false
    private var wrongAfterHelp = 0

    init(level: StoryLevel) {
        self.level = level
        mode = level.mode
        problems = level.makeProblems()
        stage = StoryStage(problem: problems[0])
    }

    /// 错题本里再练一道：能演就演，不能演就画线段图
    init(practice problem: StoryProblem) {
        level = nil
        mode = problem.canAct ? .act : .model
        problems = [problem]
        stage = StoryStage(problem: problem)
    }

    var problem: StoryProblem { problems[index] }
    var isLast: Bool { index == problems.count - 1 }
    var correctCount: Int { firstTry.filter { $0 }.count }

    var stars: Int {
        let n = problems.count
        if correctCount >= n { return 3 }
        if correctCount * 4 >= n * 3 { return 2 }
        return 1
    }

    /// 线段图现在画到哪一步
    var model: BarModel {
        let models = problem.models
        return models[min(modelStep, models.count - 1)]
    }

    /// 演一演的时候要不要孩子自己按"摆好了"
    var needsConfirm: Bool {
        switch acting {
        case .build, .balance, .fill: true
        default: false
        }
    }

    var confirmTitle: String {
        if case .balance = acting { return "Same now!" }
        return "Done!"
    }

    // MARK: 流程

    func start() {
        if sentence == nil && index == 0 { Sound.start() }
        flow?.cancel()
        flow = Task { await tell() }
    }

    func stop() {
        flow?.cancel()
        flow = nil
        resumeWaiter()
        Narrator.shared.stop()
    }

    func next() {
        guard phase == .solved else { return }
        Sound.tap()
        if isLast {
            Narrator.shared.stop()
            phase = .finished
        } else {
            index += 1
            start()
        }
    }

    func restartLevel() {
        stop()
        index = 0
        firstTry = []
        streak = 0
        start()
    }

    private func render(_ template: String) -> String { StoryText.plain(template, problem, player: player) }

    private func say(_ line: CoachLine, speak: Bool = true) {
        withAnimation(.spring(duration: 0.4, bounce: 0.3)) { coach = line }
        if speak { Narrator.shared.say(render(line.text)) }
    }

    private func prepareStage() {
        let p = problem
        stage.reset(p)
        stage.onDrop = { [weak self] route in self?.dropped(route) }
        stage.onReject = { [weak self] route in self?.rejected(route) }
        switch p.ask {
        case let .count(s): stage.hiddenBadges = [s]
        case .perPlate:     stage.hiddenBadges = Set(Spot.plates)
        default:            break
        }
    }

    private func tell() async {
        prepareStage()
        input = ""
        coach = nil
        acting = nil
        help = nil
        revealed = false
        answered = false
        wrongAfterHelp = 0
        modelStep = 0
        display = switch mode {
        case .act:   .tokens
        case .model: .model
        case .read:  .blank
        }
        phase = .telling

        try? await Task.sleep(for: .milliseconds(450))
        await tellSentences(childActs: mode == .act)
        if Task.isCancelled { return }
        beginAnswering()
    }

    /// 一句一句读；舞台上同时摆物品或者画线段图
    private func tellSentences(childActs: Bool) async {
        let p = problem
        for (i, s) in p.sentences.enumerated() {
            if Task.isCancelled { return }
            withAnimation(.easeOut(duration: 0.25)) { sentence = i }
            if display == .model { withAnimation(.spring(duration: 0.55, bounce: 0.2)) { modelStep = i } }
            async let speech: Void = Narrator.shared.speak(render(s.text))
            if display == .tokens {
                for act in s.actions where !act.needsChild { await stage.perform(act, animated: true) }
            }
            await speech
            if Task.isCancelled { return }
            if childActs {
                for act in s.actions where act.needsChild { await waitForChild(act) }
            }
            try? await Task.sleep(for: .milliseconds(180))
        }
        if Task.isCancelled { return }
        withAnimation(.easeOut(duration: 0.25)) { sentence = nil }
    }

    private func beginAnswering() {
        withAnimation(.spring(duration: 0.5)) {
            if display == .tokens { stage.comparing = true }
            phase = .answering
        }
        let text: String
        switch display {
        case .tokens: text = "Look at the glowing ones. Tap to count, then type your answer."
        case .model:  text = "Look at the model. What number goes where the ? is?"
        case .blank:  text = "Picture the story in your head. What is the answer?"
        }
        say(CoachLine(text: text), speak: false)
    }

    // MARK: 演一演

    private func waitForChild(_ act: StoryAction) async {
        acting = act
        actingStart = stage.counts()
        phase = .acting
        let p = problem
        switch act {
        case let .move(f, t, _):
            stage.forward = StoryRoute(from: f, to: t)
            say(CoachLine(text: "Act it out! Drag the \(p.thing.many) just like the story says."), speak: false)
        case let .build(s, _):
            stage.forward = StoryRoute(from: .supply, to: s)
            if let whole = p.whole {
                say(CoachLine(text: "Drag \(p.thing.many) from the basket to \(name(s)) until there are \(whole) altogether. Then tap Done."), speak: false)
            } else {
                say(CoachLine(text: "Drag \(p.thing.many) from the basket to \(name(s)), just like the sentence says. Then tap Done."), speak: false)
            }
        case let .balance(f, t):
            stage.forward = StoryRoute(from: f, to: t)
            say(CoachLine(text: "Drag \(p.thing.many) from \(name(f)) to \(name(t)) until they have the same number."), speak: false)
        case let .fill(n):
            stage.plateRule = .fill(n)
            say(CoachLine(text: "Put \(n) on each \(p.plateWord). Drag from the basket, or tap a \(p.plateWord). Then tap Done."), speak: false)
        case .share:
            stage.plateRule = .share
            say(CoachLine(text: "Share them out! Give one to each \(p.plateWord) in turn. You can drag or tap a \(p.plateWord)."), speak: false)
        case let .group(n):
            stage.plateRule = .group(n)
            stage.beginGrouping()
            say(CoachLine(text: "Put \(n) on each \(p.plateWord) until there are none left. Drag or tap a \(p.plateWord)."), speak: false)
        case .appear, .whole, .plates:
            return
        }
        await withCheckedContinuation { waiter = $0 }
        stage.forward = nil
        stage.plateRule = nil
        acting = nil
        if phase == .acting { phase = .telling }
    }

    private func resumeWaiter() {
        waiter?.resume()
        waiter = nil
    }

    private func name(_ s: Spot) -> String {
        if let i = s.plateIndex { return "\(problem.plateWord) \(i + 1)" }
        switch s {
        case .a:      return "{a}"
        case .b:      return "{b}"
        case .away:   return "the \"\(problem.awayLabel)\" box"
        default:      return "the basket"
        }
    }

    private func dropped(_ route: StoryRoute) {
        switch acting {
        case let .move(f, t, n)?:
            var expect = actingStart
            StoryProblem.apply(.move(f, t, n), to: &expect)
            let matches = { [weak self] () -> Bool in
                guard let self else { return false }
                let now = self.stage.counts()
                return [Spot.a, .b, .away].allSatisfy { now[$0, default: 0] == expect[$0, default: 0] }
            }
            guard matches() else { return }
            settle(when: matches)
        case .share?:
            guard stage.count(.a) == 0 else { return }
            let counts = stage.activePlates.map { stage.count($0) }
            if Set(counts).count == 1 {
                settle { [weak self] in
                    guard let self else { return false }
                    return self.stage.count(.a) == 0 && Set(self.stage.activePlates.map { self.stage.count($0) }).count == 1
                }
            } else {
                Sound.oops()
                say(CoachLine(text: "Are all the \(problem.plateWords) the same? Move some so that every \(problem.plateWord) has the same number.", tone: .hint))
            }
        case let .group(n)?:
            guard stage.count(.a) == 0 else { return }
            let used = stage.activePlates.filter { stage.count($0) > 0 }
            if used.allSatisfy({ stage.count($0) == n }) {
                settle { [weak self] in
                    guard let self else { return false }
                    return self.stage.count(.a) == 0 && self.stage.activePlates.allSatisfy { [0, n].contains(self.stage.count($0)) }
                }
            } else {
                Sound.oops()
                say(CoachLine(text: "Each \(problem.plateWord) should have \(n). Move them so every \(problem.plateWord) has \(n).", tone: .hint))
            }
        default:
            break
        }
    }

    /// 等一下，万一她还要接着拖
    private func settle(when ok: @escaping () -> Bool) {
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            guard self.acting != nil, ok() else { return }
            self.actingDone()
        }
    }

    private func rejected(_ route: StoryRoute) {
        Sound.nope()
        guard let acting else { return }
        let text: String
        switch acting {
        case let .move(f, t, _):
            text = "In this sentence, the \(problem.thing.many) go from \(name(f)) to \(name(t))."
        case let .build(s, _):
            text = "Drag them from the basket to \(name(s))."
        case let .balance(f, t):
            text = "\(name(f)) gives to \(name(t))."
        case let .group(n):
            text = "Only \(n) on each \(problem.plateWord)!"
        default:
            return
        }
        say(CoachLine(text: text, tone: .hint))
    }

    /// 孩子按了"摆好了 / 一样多了"
    func confirmActing() {
        guard let acting else { return }
        let p = problem
        switch acting {
        case let .build(s, target):
            let other: Spot = s == .a ? .b : .a
            let c = stage.count(s), y = stage.count(other)
            if c == target { actingDone(); return }
            let text: String
            if let whole = p.whole {
                text = "Now there are \(c + y) altogether. The story says \(whole) altogether."
            } else if c == y {
                text = "Now they have the same number. Read the sentence again."
            } else if c > y {
                text = "Now \(name(s)) has \(c - y) more than \(name(other)). Read the sentence again."
            } else {
                text = "Now \(name(s)) has \(y - c) fewer than \(name(other)). Read the sentence again."
            }
            Sound.oops()
            say(CoachLine(text: text, tone: .hint))
            if let i = p.sentences.firstIndex(where: { $0.actions.contains(acting) }) {
                sentence = i
            }
        case let .balance(f, t):
            if stage.count(f) == stage.count(t) { actingDone(); return }
            let more = stage.count(f) > stage.count(t) ? f : t
            Sound.oops()
            say(CoachLine(text: "Not the same yet. \(name(more)) still has more.", tone: .hint))
        case let .fill(n):
            if let wrong = stage.activePlates.first(where: { stage.count($0) != n }) {
                Sound.oops()
                say(CoachLine(text: "\(name(wrong).capitalized) has \(stage.count(wrong)). Each \(p.plateWord) needs \(n).", tone: .hint))
            } else {
                actingDone()
            }
        default:
            break
        }
    }

    private func actingDone() {
        Sound.done()
        say(CoachLine(text: "Well acted!", tone: .praise), speak: false)
        resumeWaiter()
    }

    // MARK: 答一答

    func type(_ digit: Int) {
        guard phase == .answering, input.count < 3 else { return }
        if input == "0" { input = "" }
        input += "\(digit)"
        Sound.key()
    }

    func backspace() {
        guard phase == .answering, !input.isEmpty else { return }
        input.removeLast()
        Sound.key()
    }

    func submit() {
        guard phase == .answering, let n = Int(input) else { return }
        let p = problem
        let right = n == p.answer
        let first = !answered
        if first {
            answered = true
            firstTry.append(right)
            streak = right ? streak + 1 : 0
            onFirstAnswer?(p, right, n)
        }
        if right {
            if first { starBurst += 1 }
            flow = Task { await solved(first: first) }
        } else {
            wrong(n)
        }
    }

    private var nextHelp: StoryHelp? {
        switch display {
        case .blank:  .model
        case .model:  problem.canAct ? .act : nil
        case .tokens: nil
        }
    }

    private func wrong(_ n: Int) {
        let p = problem
        Sound.oops()
        wrongShake += 1
        let hint = p.hints[n] ?? p.genericHint
        if let next = nextHelp {
            help = next
            withAnimation(.spring(duration: 0.4)) { phase = .offerHelp }
            say(CoachLine(text: hint + (next == .act ? " Let's act it out!" : " Let's draw a model!"), tone: .hint))
            return
        }
        wrongAfterHelp += 1
        if wrongAfterHelp >= 2 { reveal(); return }
        input = ""
        stage.resetCounting()
        say(CoachLine(text: hint, tone: .hint))
    }

    /// 答错以后接受帮助：画线段图，或者亲手演一遍
    func acceptHelp() {
        guard phase == .offerHelp, let help else { return }
        Sound.tap()
        input = ""
        wrongAfterHelp = 0
        self.help = nil
        flow = Task {
            withAnimation(.spring(duration: 0.4)) {
                if help == .act {
                    prepareStage()
                    display = .tokens
                } else {
                    modelStep = 0
                    display = .model
                }
                phase = .telling
            }
            try? await Task.sleep(for: .milliseconds(300))
            await tellSentences(childActs: help == .act)
            if Task.isCancelled { return }
            beginAnswering()
        }
    }

    private func praise(first: Bool) -> String {
        guard first else { return ["That's right!", "Yes, you got it!"].randomElement()! }
        if streak >= 3 { return "\(streak) in a row! Amazing!" }
        return ["Correct!", "Well done!", "Great thinking!", "You got it!"].randomElement()!
    }

    private func solved(first: Bool) async {
        let p = problem
        Sound.correct()
        phase = .verifying
        // 只看文字的题，答对后把线段图画出来给她看
        withAnimation(.spring(duration: 0.5)) {
            if display == .blank {
                display = .model
                modelStep = p.models.count - 1
            }
            if display == .tokens { stage.comparing = true }
        }
        if Task.isCancelled { return }
        let praise = praise(first: first)
        withAnimation(.spring(duration: 0.5, bounce: 0.4)) { phase = .solved }
        say(CoachLine(text: praise, tone: .praise, equation: p.explain), speak: false)
        await Narrator.shared.speak(praise + " " + StoryText.plain(p.answerTemplate, p, player: player, blank: "\(p.answer)"))
    }

    private func reveal() {
        let p = problem
        revealed = true
        input = "\(p.answer)"
        withAnimation(.spring(duration: 0.5)) {
            if display == .tokens { stage.comparing = true }
            if display != .tokens {
                display = .model
                modelStep = p.models.count - 1
            }
            phase = .solved
        }
        say(CoachLine(text: "The answer is \(p.answer). Let's look at it together.", tone: .reveal, equation: p.explain))
    }
}
