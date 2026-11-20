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

/// 舞台上显示什么：实物、线段图、十和一（100 以内的加减），还是什么都不显示（只看文字）
enum StageDisplay: Equatable { case tokens, model, tens, blank }

/// 答错以后可以给的帮助：画线段图，用实物演，或者（数太大没法演的时候）数十和一
enum StoryHelp: Equatable { case model, act, tens }

/// 故事卡上的一行：故事的一句，或者（分两问的时候）(a) (b) 两问
struct StoryRow: Hashable {
    var text: String
    var isQuestion = false
    /// "a" / "b"：分两问做时标在问题前面
    var tag: String? = nil
}

/// 一关（或者错题本里的错题、或者"练一练"）的流程：
/// 讲故事（边读边摆 / 边读边画）→ 演一演（孩子拖动）→（读题关）先选算式 → 答一答
/// → 答错了就针对这种错法解释，再画一画、演一演（或者数十和一）。
/// 两步题的 "Step by step" 关：先答中间那一问 (a)，线段图长出来，再答 (b)。
/// 一关的题做完以后，第一次答错的题按顺序再做一遍（"再练一轮"），然后才结算；再练一轮不算成绩、不给星星。
@Observable
@MainActor
final class StorySession {
    enum Phase: Equatable { case telling, acting, choosing, answering, offerHelp, verifying, solved, finished }
    enum Kind: Equatable { case level, mistakes, mix }

    let kind: Kind
    /// 正在玩的关（练错题、练一练的时候是 nil）
    let level: StoryLevel?
    /// 练一练挑的题
    let mix: StoryMix.Pick?
    /// 要做的题：先是这一轮本来的题，再练一轮开始后，后面接上要再做一遍的题
    private(set) var problems: [StoryProblem]
    /// 每道题算在哪一关（星星、错题记在那一关上）
    private(set) var levels: [StoryLevel?]
    /// 每道题怎么玩（练一练里每道题按它原来那一关的玩法）
    private(set) var modes: [StoryMode]
    /// 这一轮本来有几道题（不算再练一轮）
    let mainCount: Int
    let stage: StoryStage

    private(set) var index = 0
    private(set) var phase: Phase = .telling
    /// 正在读、正在演的那一行（rows 里的第几行）
    private(set) var sentence: Int?
    private(set) var coach: CoachLine?
    /// 现在等孩子演的动作
    private(set) var acting: StoryAction?
    private(set) var display: StageDisplay = .tokens
    /// 线段图画到第几句
    private(set) var modelStep = 0
    /// 分两问的时候，线段图用中间那一问的图
    private(set) var stepModel: BarModel?
    /// 分两问：0 = 正在答 (a)，1 = 正在答 (b)（不分两问的题一直是 1）
    private(set) var step = 1
    /// 答对或揭晓以后，答题板和线段图上填出来的数
    private(set) var filled: Int?
    private(set) var help: StoryHelp?
    private(set) var revealed = false
    /// 读题关先选算式：选对的那个；选错过的那几个
    private(set) var chosen: Int?
    private(set) var wrongChoices: Set<Int> = []
    private(set) var choiceShake = 0
    /// 每道题第一次答得对不对（只算这一轮本来的题）
    private(set) var firstTry: [Bool] = []
    /// 再练一轮里每道题第一次答得对不对
    private(set) var retryResults: [Bool] = []
    /// 连续一次就答对几道
    private(set) var streak = 0
    private(set) var wrongShake = 0
    var input = ""

    var player = PlayerStore.defaultName
    /// 每道题第一次作答：题、对不对、答的数、错在哪一问（0 = 中间那一问；再练一轮里的不算）
    var onFirstAnswer: ((StoryProblem, Bool, Int, Int?) -> Void)?
    /// 再练一轮里每道题第一次作答：题、对不对
    var onRetryAnswer: ((StoryProblem, Bool) -> Void)?
    /// 读题关里第一下选的算式对不对（再练一轮里的不算）
    var onChoice: ((StoryProblem, Bool) -> Void)?

    private var flow: Task<Void, Never>?
    private var waiter: CheckedContinuation<Void, Never>?
    private var actingStart: [Spot: Int] = [:]
    private var answered = false
    private var wrongAfterHelp = 0
    private var choiceTapped = false

    /// avoiding：刚做完那套题的 starKey，"Play again"时换一套
    init(level: StoryLevel, avoiding: Set<String> = []) {
        kind = .level
        self.level = level
        mix = nil
        let set = StoryBank.problems(for: level, avoiding: avoiding) ?? level.makeProblems()
        problems = set
        levels = set.map { _ in level }
        modes = set.map { _ in level.mode }
        mainCount = set.count
        stage = StoryStage(problem: set[0])
    }

    /// 错题本里再练一道：能演就演，不能演就画线段图；两步题那一关的错题还是分两问
    init(practice mistake: StoryMistake) {
        kind = .mistakes
        level = nil
        mix = nil
        let home = StoryLevel(mistake.level)
        let p = mistake.problem
        problems = [p]
        levels = [home]
        modes = [home.mode == .steps && p.middle != nil ? .steps : p.canAct ? .act : .model]
        mainCount = 1
        stage = StoryStage(problem: p)
    }

    /// 练一练：每道题按它原来那一关的玩法，星星也记在原来那一关
    init(mix pick: StoryMix.Pick) {
        kind = .mix
        level = nil
        mix = pick
        let ps = pick.entries.map(\.problem)
        problems = ps
        levels = pick.entries.map(\.level)
        modes = pick.entries.map(\.level.mode)
        mainCount = ps.count
        stage = StoryStage(problem: ps[0])
    }

    var problem: StoryProblem { problems[index] }
    var mode: StoryMode { modes[index] }
    /// 这道题的星星、错题记在哪一关
    var problemLevel: StoryLevel? { levels[index] }
    /// 正在再练一轮
    var isRetry: Bool { index >= mainCount }
    /// 再练一轮有几道题（还没开始时是 0）
    var retryCount: Int { problems.count - mainCount }
    /// 这一轮的题做完了，接下来要再练一轮（练错题的时候没有）
    var retryPending: Bool { kind != .mistakes && index == mainCount - 1 && !StoryRetry.indices(firstTry).isEmpty }
    var isLast: Bool { index == problems.count - 1 && !retryPending }
    var correctCount: Int { firstTry.filter { $0 }.count }
    /// 这一关本来那几道题的 starKey（"Play again"时避开）
    var problemKeys: Set<String> {
        Set(problems.prefix(mainCount).map { $0.starKey(level: level?.number ?? 0) })
    }

    var stars: Int {
        let n = mainCount
        if correctCount >= n { return 3 }
        if correctCount * 4 >= n * 3 { return 2 }
        return 1
    }

    /// 这道题分两问做
    var asksMiddle: Bool { mode == .steps && problem.middle != nil }
    /// 正在答 (a)
    var onMiddle: Bool { asksMiddle && step == 0 }
    /// 读题关：算之前先选算式
    var choice: StoryChoice? { mode == .read ? problem.choice : nil }
    /// 现在要填的答案句和答案
    var answerTemplate: String { onMiddle ? problem.middle!.answerTemplate : problem.answerTemplate }
    var currentAnswer: Int { onMiddle ? problem.middle!.answer : problem.answer }

    /// 故事卡上的几行：分两问的时候，最后是 (a) (b) 两问
    var rows: [StoryRow] {
        let p = problem
        let last = p.sentences.count - 1
        guard asksMiddle, let m = p.middle else {
            return p.sentences.enumerated().map { StoryRow(text: $1.text, isQuestion: $0 == last) }
        }
        return p.sentences.dropLast().map { StoryRow(text: $0.text) }
            + [StoryRow(text: m.text, isQuestion: true, tag: "a"),
               StoryRow(text: p.sentences[last].text, isQuestion: true, tag: "b")]
    }

    /// 分两问的时候正在问的那一行（另一问调淡）
    var activeRow: Int? {
        guard asksMiddle, phase != .telling else { return nil }
        let n = rows.count
        return step == 0 ? n - 2 : n - 1
    }

    /// 线段图现在画到哪一步
    var model: BarModel {
        if let stepModel { return stepModel }
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
            if retryPending {
                let again = StoryRetry.indices(firstTry)
                let (ps, ls, ms) = (problems, levels, modes)
                problems += again.map { ps[$0] }
                levels += again.map { ls[$0] }
                modes += again.map { ms[$0] }
            }
            index += 1
            start()
        }
    }

    private func render(_ template: String) -> String { StoryText.plain(template, problem, player: player) }

    /// parts：分成几句读（每句都有录音），不给就读整句
    private func say(_ line: CoachLine, speak: Bool = true, parts: [String]? = nil) {
        withAnimation(.spring(duration: 0.4, bounce: 0.3)) { coach = line }
        guard speak else { return }
        if let parts { Narrator.shared.say(parts.map(render)) } else { Narrator.shared.say(render(line.text)) }
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
        stepModel = nil
        step = asksMiddle ? 0 : 1
        filled = nil
        chosen = nil
        wrongChoices = []
        choiceTapped = false
        middleWrong = 0
        display = switch mode {
        case .act:           .tokens
        case .model, .steps: .model
        case .read:          .blank
        }
        phase = .telling

        try? await Task.sleep(for: .milliseconds(450))
        if index == 0, let mix {
            // 练一练开始：告诉她这次多练什么、为什么（只显示，不读）
            say(CoachLine(text: StoryMix.reason(mix)), speak: false)
            try? await Task.sleep(for: .milliseconds(1400))
            if Task.isCancelled { return }
        }
        if index == mainCount, isRetry {
            // 再练一轮开始：老师先说一句
            say(CoachLine(text: StoryVoiceLines.retryIntro), speak: false)
            await Narrator.shared.speak(StoryVoiceLines.retryIntro)
            if Task.isCancelled { return }
            try? await Task.sleep(for: .milliseconds(250))
        }
        await tellSentences(childActs: mode == .act)
        if Task.isCancelled { return }
        if choice != nil { beginChoosing() } else { beginAnswering() }
    }

    /// 一句一句读；舞台上同时摆物品或者画线段图。分两问的题最后读 (a) (b) 两问。
    private func tellSentences(childActs: Bool) async {
        let p = problem
        let split = asksMiddle
        let told = split ? Array(p.sentences.dropLast()) : p.sentences
        for (i, s) in told.enumerated() {
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
        if split, let m = p.middle {
            // (a)：线段图换成中间那一问的图，"?" 在中间那个数上
            withAnimation(.easeOut(duration: 0.25)) { sentence = told.count }
            withAnimation(.spring(duration: 0.55, bounce: 0.2)) { stepModel = m.model }
            await Narrator.shared.speak(render(m.text))
            if Task.isCancelled { return }
            try? await Task.sleep(for: .milliseconds(180))
            // (b)
            withAnimation(.easeOut(duration: 0.25)) { sentence = told.count + 1 }
            await Narrator.shared.speak(render(p.sentences[p.sentences.count - 1].text))
            if Task.isCancelled { return }
        }
        withAnimation(.easeOut(duration: 0.25)) { sentence = nil }
    }

    /// quiet：老师刚说过话（选对算式、进到下一问），这里不再换一句
    private func beginAnswering(quiet: Bool = false) {
        withAnimation(.spring(duration: 0.5)) {
            if display == .tokens { stage.comparing = true }
            phase = .answering
        }
        guard !quiet else { return }
        let text: String
        switch display {
        case .tokens: text = "Look at the glowing ones. Tap to count, then type your answer."
        case .model:  text = onMiddle ? "First answer part (a). Look at the model: what goes where the ? is?"
                                      : "Look at the model. What number goes where the ? is?"
        case .tens:   text = "Count the tens, then the ones. What is the answer?"
        case .blank:  text = "Picture the story in your head. What is the answer?"
        }
        say(CoachLine(text: text), speak: false)
    }

    // MARK: 先选算式

    private func beginChoosing() {
        guard let choice else { beginAnswering(); return }
        withAnimation(.spring(duration: 0.5)) { phase = .choosing }
        let line = choice.first ? StoryVoiceLines.chooseFirst : StoryVoiceLines.chooseOp
        say(CoachLine(text: line))
    }

    /// 点了一个算式
    func choose(_ i: Int) {
        guard phase == .choosing, let choice, choice.options.indices.contains(i), !wrongChoices.contains(i) else { return }
        let right = i == choice.correct
        if !choiceTapped {
            choiceTapped = true
            if !isRetry { onChoice?(problem, right) }
        }
        if right {
            Sound.done()
            withAnimation(.spring(duration: 0.45, bounce: 0.4)) { chosen = i }
            say(CoachLine(text: StoryVoiceLines.chooseRight, tone: .praise))
            beginAnswering(quiet: true)
        } else {
            // 选错了不扣星星：说一句这类题怎么想，再选
            Sound.oops()
            withAnimation(.spring(duration: 0.35)) { _ = wrongChoices.insert(i) }
            choiceShake += 1
            say(CoachLine(text: problem.choiceNudge, tone: .hint))
        }
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
        case .appear, .whole, .plates, .gather:
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

    /// 这道题第一次答（对或错）的结果报上去；分两问的题，(a) 答错也算这道题第一下没答对
    private func report(_ right: Bool, _ n: Int, step: Int?) {
        guard !answered else { return }
        answered = true
        let p = problem
        if isRetry {
            retryResults.append(right)
            onRetryAnswer?(p, right)
        } else {
            firstTry.append(right)
            streak = right ? streak + 1 : 0
            onFirstAnswer?(p, right, n, step)
        }
    }

    func submit() {
        guard phase == .answering, let n = Int(input) else { return }
        if onMiddle { submitMiddle(n); return }
        let p = problem
        let right = n == p.answer
        let first = !answered
        report(right, n, step: nil)
        if right {
            flow = Task { await solved(first: first) }
        } else {
            wrong(n)
        }
    }

    private var nextHelp: StoryHelp? {
        switch display {
        case .blank:  return .model
        // 分两问的关本来就在画图，不再往下换
        case .model:
            if mode == .steps { return nil }
            if problem.canAct { return .act }
            // 大数目没法演：数十和一
            return problem.tensOnes != nil ? .tens : nil
        case .tokens, .tens: return nil
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
            let offer = switch next {
            case .act:   StoryVoiceLines.actIt
            case .model: StoryVoiceLines.drawIt
            case .tens:  StoryVoiceLines.tensIt
            }
            say(CoachLine(text: hint + " " + offer, tone: .hint), parts: [hint, offer])
            return
        }
        wrongAfterHelp += 1
        if wrongAfterHelp >= 2 { reveal(); return }
        input = ""
        stage.resetCounting()
        say(CoachLine(text: hint, tone: .hint))
    }

    /// 答错以后接受帮助：画线段图，亲手演一遍，或者数十和一
    func acceptHelp() {
        guard phase == .offerHelp, let help else { return }
        Sound.tap()
        input = ""
        wrongAfterHelp = 0
        self.help = nil
        if help == .tens {
            // 十和一不用再讲一遍故事：直接摆出来，接着答
            withAnimation(.spring(duration: 0.45)) { display = .tens }
            beginAnswering()
            return
        }
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
        guard first else { return StoryVoiceLines.laterTry.randomElement()! }
        if !isRetry, streak >= 3 { return StoryVoiceLines.streak(streak) }
        return StoryVoiceLines.firstTry.randomElement()!
    }

    private func solved(first: Bool) async {
        let p = problem
        Sound.correct()
        phase = .verifying
        // 只看文字的题，答对后把线段图画出来给她看
        withAnimation(.spring(duration: 0.5)) {
            filled = p.answer
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
        await Narrator.shared.speak([praise, StoryText.plain(p.answerTemplate, p, player: player, blank: "\(p.answer)")])
    }

    private func reveal() {
        let p = problem
        revealed = true
        input = "\(p.answer)"
        withAnimation(.spring(duration: 0.5)) {
            filled = p.answer
            if display == .tokens { stage.comparing = true }
            if display == .blank || display == .model {
                display = .model
                modelStep = p.models.count - 1
            }
            phase = .solved
        }
        say(CoachLine(text: StoryVoiceLines.answerIs(p.answer) + " " + StoryVoiceLines.lookTogether, tone: .reveal, equation: p.explain),
            parts: [StoryVoiceLines.answerIs(p.answer), StoryVoiceLines.lookTogether])
    }

    // MARK: 分两问：先答 (a)

    private var middleWrong = 0

    private func submitMiddle(_ n: Int) {
        guard let m = problem.middle else { return }
        if n == m.answer {
            let clean = middleWrong == 0
            flow = Task { await middleSolved(praise: clean ? StoryVoiceLines.firstTry.randomElement()! : StoryVoiceLines.laterTry.randomElement()!) }
            return
        }
        report(false, n, step: 0)
        Sound.oops()
        wrongShake += 1
        middleWrong += 1
        if middleWrong >= 2 {
            flow = Task { await revealMiddle() }
            return
        }
        input = ""
        say(CoachLine(text: m.hints[n] ?? StoryVoiceLines.stepGeneric, tone: .hint))
    }

    private func middleSolved(praise: String) async {
        guard let m = problem.middle else { return }
        Sound.correct()
        withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
            phase = .verifying
            filled = m.answer
        }
        say(CoachLine(text: praise, tone: .praise, equation: m.explain), speak: false)
        await Narrator.shared.speak([praise, StoryText.plain(m.answerTemplate, problem, player: player, blank: "\(m.answer)")])
        if Task.isCancelled { return }
        await nextQuestion()
    }

    private func revealMiddle() async {
        guard let m = problem.middle else { return }
        input = "\(m.answer)"
        withAnimation(.spring(duration: 0.5)) {
            phase = .verifying
            filled = m.answer
        }
        say(CoachLine(text: StoryVoiceLines.answerIs(m.answer) + " " + StoryVoiceLines.lookTogether, tone: .reveal, equation: m.explain),
            speak: false)
        await Narrator.shared.speak([StoryVoiceLines.answerIs(m.answer), StoryVoiceLines.lookTogether])
        if Task.isCancelled { return }
        try? await Task.sleep(for: .milliseconds(600))
        await nextQuestion()
    }

    /// (a) 答完了：线段图长出来（中间那个数写上，"?" 挪到最后的答案上），接着问 (b)
    private func nextQuestion() async {
        guard let m = problem.middle else { return }
        try? await Task.sleep(for: .milliseconds(350))
        if Task.isCancelled { return }
        withAnimation(.spring(duration: 0.6, bounce: 0.2)) {
            stepModel = m.after
            step = 1
            filled = nil
            input = ""
            wrongAfterHelp = 0
        }
        let question = problem.sentences[problem.sentences.count - 1].text
        say(CoachLine(text: StoryVoiceLines.nextQuestion), speak: false)
        beginAnswering(quiet: true)
        await Narrator.shared.speak([StoryVoiceLines.nextQuestion, render(question)])
    }
}
