import SwiftUI

/// 猫头鹰老师说的话
struct CoachLine: Equatable {
    enum Tone { case info, hint, praise, reveal }
    /// 模板文字，{a} {b} {i} {m} 显示时再换成名字和物品
    var text: String
    var tone: Tone = .info
}

/// 一关（或者错题本里的一道题）的流程：
/// 讲故事（边读边摆）→ 演一演（孩子拖动）→ 比一比、答一答 → 答错了就针对这种错法解释，再演一遍。
@Observable
@MainActor
final class StorySession {
    enum Phase: Equatable { case telling, acting, answering, offerAct, verifying, solved, finished }

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
    /// 已经亲手演过（之后才显示比一比）
    private(set) var actedOut = false
    private(set) var revealed = false
    /// 每道题第一次答得对不对
    private(set) var firstTry: [Bool] = []
    /// 场景上的小标签，比如"故事开始的时候"
    private(set) var stageCaption: String?
    private(set) var wrongShake = 0
    var input = ""

    var player = PlayerStore.defaultName
    /// 每道题第一次作答：题、对不对、答的数
    var onFirstAnswer: ((StoryProblem, Bool, Int) -> Void)?

    private var flow: Task<Void, Never>?
    private var waiter: CheckedContinuation<Void, Never>?
    private var actingStart: [Spot: Int] = [:]
    private var answered = false
    private var wrongAfterAct = 0

    init(level: StoryLevel) {
        self.level = level
        mode = level.mode
        problems = level.makeProblems()
        stage = StoryStage(problem: problems[0])
    }

    /// 错题本里再练一道：总是用"演一演"
    init(practice problem: StoryProblem) {
        level = nil
        mode = .act
        problems = [problem]
        stage = StoryStage(problem: problem)
    }

    var problem: StoryProblem { problems[index] }
    var isLast: Bool { index == problems.count - 1 }
    var correctCount: Int { firstTry.filter { $0 }.count }

    var stars: Int {
        switch correctCount {
        case problems.count...: 3
        case 3...: 2
        default: 1
        }
    }

    /// 演一演的时候要不要孩子自己按"摆好了"
    var needsConfirm: Bool {
        switch acting {
        case .build, .balance: true
        default: false
        }
    }

    var confirmTitle: String {
        if case .balance = acting { return "一样多了" }
        return "摆好了"
    }

    // MARK: 流程

    func start() {
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
        start()
    }

    private func render(_ template: String) -> String { StoryText.plain(template, problem, player: player) }

    private func say(_ line: CoachLine, speak: Bool = true) {
        withAnimation(.spring(duration: 0.4, bounce: 0.3)) { coach = line }
        if speak { Narrator.shared.say(render(line.text)) }
    }

    private func tell() async {
        let p = problem
        stage.reset(p)
        stage.onDrop = { [weak self] route in self?.dropped(route) }
        stage.onReject = { [weak self] route in self?.rejected(route) }
        if case let .count(s) = p.ask { stage.hiddenBadges = [s] }
        stage.visible = mode != .read
        input = ""
        coach = nil
        acting = nil
        actedOut = false
        revealed = false
        answered = false
        wrongAfterAct = 0
        stageCaption = mode == .guess ? "故事开始的时候" : nil
        phase = .telling

        try? await Task.sleep(for: .milliseconds(450))
        for (i, s) in p.sentences.enumerated() {
            if Task.isCancelled { return }
            withAnimation(.easeOut(duration: 0.25)) { sentence = i }
            let text = render(s.text)
            async let speech: Void = Narrator.shared.speak(text)
            for act in s.actions where !act.needsChild {
                await stage.perform(act, animated: mode != .read)
            }
            await speech
            if Task.isCancelled { return }
            if mode == .act {
                for act in s.actions where act.needsChild { await waitForChild(act) }
            }
            try? await Task.sleep(for: .milliseconds(180))
        }
        if Task.isCancelled { return }
        withAnimation(.easeOut(duration: 0.25)) { sentence = nil }
        actedOut = mode == .act
        beginAnswering()
    }

    private func beginAnswering() {
        withAnimation(.spring(duration: 0.5)) {
            if actedOut { stage.comparing = true }
            phase = .answering
        }
        let text = actedOut ? "看看发光的那些，点一点、数一数，再把答案填上。" : "先自己想一想，答案是几？"
        say(CoachLine(text: text), speak: false)
    }

    // MARK: 演一演

    private func waitForChild(_ act: StoryAction) async {
        acting = act
        actingStart = stage.counts()
        phase = .acting
        switch act {
        case let .move(f, t, _):
            stage.forward = StoryRoute(from: f, to: t)
            say(CoachLine(text: "照着这句话，用手拖一拖{i}，演一演。"), speak: false)
        case let .build(s, _):
            stage.forward = StoryRoute(from: .supply, to: s)
            say(CoachLine(text: "照着这句话，从篮子里给\(name(s))摆{i}。摆好了就按「摆好了」。"), speak: false)
        case let .balance(f, t):
            stage.forward = StoryRoute(from: f, to: t)
            say(CoachLine(text: "把{i}从\(name(f))那里拖给\(name(t))，直到两个人一样多。"), speak: false)
        case .appear:
            return
        }
        await withCheckedContinuation { waiter = $0 }
        stage.forward = nil
        acting = nil
        if phase == .acting { phase = .telling }
    }

    private func resumeWaiter() {
        waiter?.resume()
        waiter = nil
    }

    private func name(_ s: Spot) -> String {
        switch s {
        case .a:      "{a}"
        case .b:      "{b}"
        case .away:   "「\(problem.awayLabel)」盘子"
        case .supply: "篮子"
        }
    }

    private func dropped(_ route: StoryRoute) {
        guard case let .move(f, t, n)? = acting else { return }
        var expect = actingStart
        StoryProblem.apply(.move(f, t, n), to: &expect)
        let matches = { [weak self] () -> Bool in
            guard let self else { return false }
            let now = self.stage.counts()
            return [Spot.a, .b, .away].allSatisfy { now[$0, default: 0] == expect[$0, default: 0] }
        }
        guard matches() else { return }
        Task {
            // 等一下，万一她还要接着拖
            try? await Task.sleep(for: .milliseconds(650))
            guard self.acting != nil, matches() else { return }
            self.actingDone()
        }
    }

    private func rejected(_ route: StoryRoute) {
        Sound.undo()
        guard let acting else { return }
        let text: String
        switch acting {
        case let .move(f, t, _):
            text = "这句话里，{i}是从\(name(f))那里，到\(name(t))那里的哦。"
        case let .build(s, _):
            text = "这一句要给\(name(s))摆{i}，从篮子里拖出来。"
        case let .balance(f, t):
            text = "是\(name(f))把{i}给\(name(t))哦。"
        case .appear:
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
            if c == y {
                text = "现在两个人一样多。再听听这句话，他们一样多吗？"
            } else if c < y {
                text = "现在是\(name(other))多。再听听这句话，到底是谁多？"
            } else {
                text = "现在\(name(s))比\(name(other))多 \(c - y) {m}。故事里说的是多几{m}呢？"
            }
            Sound.undo()
            say(CoachLine(text: text, tone: .hint))
            if let i = p.sentences.firstIndex(where: { $0.actions.contains(acting) }) {
                sentence = i
            }
        case let .balance(f, t):
            if stage.count(f) == stage.count(t) { actingDone(); return }
            let more = stage.count(f) > stage.count(t) ? f : t
            Sound.undo()
            say(CoachLine(text: "还不一样多哦，\(name(more))的还多一些。", tone: .hint))
        default:
            break
        }
    }

    private func actingDone() {
        Sound.hint()
        say(CoachLine(text: "演好啦！", tone: .praise), speak: false)
        resumeWaiter()
    }

    // MARK: 答一答

    func type(_ digit: Int) {
        guard phase == .answering, input.count < 2 else { return }
        if input == "0" { input = "" }
        input += "\(digit)"
        Sound.tap()
    }

    func backspace() {
        guard phase == .answering, !input.isEmpty else { return }
        input.removeLast()
        Sound.tap()
    }

    func submit() {
        guard phase == .answering, let n = Int(input) else { return }
        let p = problem
        let right = n == p.answer
        if !answered {
            answered = true
            firstTry.append(right)
            onFirstAnswer?(p, right, n)
        }
        if right {
            flow = Task { await solved() }
        } else {
            wrong(n)
        }
    }

    private func wrong(_ n: Int) {
        let p = problem
        Sound.undo()
        wrongShake += 1
        let hint = p.hints[n] ?? p.genericHint
        if actedOut {
            wrongAfterAct += 1
            if wrongAfterAct >= 2 { reveal(); return }
            input = ""
            stage.resetCounting()
            say(CoachLine(text: hint, tone: .hint))
        } else {
            withAnimation(.spring(duration: 0.4)) { phase = .offerAct }
            say(CoachLine(text: hint + "我们来演一演，就知道啦。", tone: .hint))
        }
    }

    /// 答错以后（先猜再演 / 只看文字）亲手演一遍
    func actOut() {
        guard phase == .offerAct else { return }
        Sound.tap()
        input = ""
        flow = Task {
            let p = problem
            withAnimation(.spring(duration: 0.4)) {
                stage.clear()
                stage.visible = true
                stageCaption = nil
                phase = .telling
            }
            try? await Task.sleep(for: .milliseconds(300))
            for (i, s) in p.sentences.enumerated() {
                if Task.isCancelled { return }
                withAnimation(.easeOut(duration: 0.25)) { sentence = i }
                async let speech: Void = Narrator.shared.speak(render(s.text))
                for act in s.actions where !act.needsChild { await stage.perform(act, animated: true) }
                await speech
                if Task.isCancelled { return }
                for act in s.actions where act.needsChild { await waitForChild(act) }
            }
            if Task.isCancelled { return }
            withAnimation(.easeOut(duration: 0.25)) { sentence = nil }
            actedOut = true
            beginAnswering()
        }
    }

    private func solved() async {
        let p = problem
        Sound.hint()
        phase = .verifying
        // 没演过的话，自动演一遍给她看，验证答案
        if !actedOut {
            say(CoachLine(text: "答对啦！我们演一遍看看。", tone: .praise), speak: false)
            withAnimation(.spring(duration: 0.4)) {
                stage.visible = true
                stageCaption = nil
            }
            try? await Task.sleep(for: .milliseconds(400))
            for (i, s) in p.sentences.enumerated() where s.actions.contains(where: \.needsChild) {
                if Task.isCancelled { return }
                withAnimation(.easeOut(duration: 0.25)) { sentence = i }
                for act in s.actions where act.needsChild { await stage.perform(act, animated: true) }
                try? await Task.sleep(for: .milliseconds(250))
            }
            withAnimation(.easeOut(duration: 0.25)) { sentence = nil }
            withAnimation(.spring(duration: 0.5)) { stage.comparing = true }
        }
        if Task.isCancelled { return }
        let praise = ["答对啦！", "真棒！", "完全正确！", "你真会想！"].randomElement()!
        withAnimation(.spring(duration: 0.5, bounce: 0.4)) { phase = .solved }
        say(CoachLine(text: praise, tone: .praise), speak: false)
        await Narrator.shared.speak(praise + StoryText.plain(p.answerTemplate, p, player: player, blank: "\(p.answer)"))
    }

    private func reveal() {
        let p = problem
        revealed = true
        input = "\(p.answer)"
        withAnimation(.spring(duration: 0.5)) {
            stage.comparing = true
            phase = .solved
        }
        say(CoachLine(text: "答案是 \(p.answer)。" + p.explain, tone: .reveal))
    }
}
