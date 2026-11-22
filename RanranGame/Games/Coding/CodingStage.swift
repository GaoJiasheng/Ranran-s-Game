import SwiftUI
import Observation

/// 编程的两个"活的"部分，闯关和教学共用：
///   CodingEditor  排积木：程序、光标（闪着的空位）、放进去、拿出来、改次数
///   CodingStage   小兔照着程序走：一步一步演出来（正在做的那一块发光、重复上写着第几次、撞到了晃一下）

// MARK: - 排积木

@Observable
@MainActor
final class CodingEditor {
    private(set) var program: CodingProgram
    private(set) var limits: CodingLimits
    /// 闪着的那个空位：下一块积木落下去的地方
    private(set) var cursor: CodingSlot
    /// 这一层满了 / 放不下：轻轻晃一下（哪一层、第几次晃）
    private(set) var shake: (track: Int, container: [Int], tick: Int)?
    /// 改了程序（跑到一半的要停下来、回到起点）
    var onEdit: (() -> Void)?
    /// 说一句（满了、放不下）
    var onSay: ((String) -> Void)?

    init(program: CodingProgram, limits: CodingLimits) {
        self.program = program
        self.limits = limits
        cursor = CodingSlot(track: 0, container: [], index: program.main.count)
        normalizeCursor()
    }

    func load(_ p: CodingProgram, limits l: CodingLimits? = nil) {
        if let l { limits = l }
        program = p
        cursor = CodingSlot(track: 0, container: [], index: min(p.main.count, limits.main))
        normalizeCursor()
    }

    /// 积木盒里这一块现在能不能放
    func refusal(_ piece: CodingPiece) -> CodingRules.Refusal? {
        CodingRules.check(piece, at: cursor, in: program, limits: limits)
    }

    /// 点积木盒里的一块：落进光标，光标往后挪一格（带壳的积木：光标进到它里面）
    func tap(_ piece: CodingPiece) {
        if let r = refusal(piece) {
            Sound.nope()
            shake = (cursor.track, cursor.container, (shake?.tick ?? 0) + 1)
            onSay?(r == .full ? CodingLines.full : CodingLines.notHere)
            return
        }
        var p = program
        guard p.insert(piece.fresh, at: cursor) else { return }
        Sound.drop()
        withAnimation(.spring(duration: 0.28, bounce: 0.3)) {
            program = p
            if piece.isContainer {
                cursor = CodingSlot(track: cursor.track, container: cursor.container + [cursor.index], index: 0)
            } else {
                cursor.index += 1
                // 壳里面满了：光标跳到壳的后面
                while let c = cursor.containerRef, let list = program.list(track: cursor.track, container: cursor.container),
                      list.count >= limits.capacity(track: cursor.track, container: program.block(at: c)) {
                    cursor = CodingSlot(track: c.track, container: Array(c.path.dropLast()), index: (c.path.last ?? 0) + 1)
                }
            }
        }
        onEdit?()
    }

    /// 点一个空位（或者两块中间）：光标挪过去
    func moveCursor(_ s: CodingSlot) {
        guard let list = program.list(track: s.track, container: s.container) else { return }
        Sound.tap()
        withAnimation(.easeOut(duration: 0.15)) {
            cursor = CodingSlot(track: s.track, container: s.container, index: min(max(0, s.index), list.count))
        }
    }

    /// 点一块放好的积木：拿掉（带壳的连里面的一起），光标停在它原来的位置
    func remove(_ r: CodingRef) {
        var p = program
        guard p.remove(at: r) != nil else { return }
        Sound.undo()
        withAnimation(.spring(duration: 0.28, bounce: 0.2)) {
            program = p
            cursor = r.parent
        }
        onEdit?()
    }

    func setCount(_ r: CodingRef, _ n: Int) {
        guard case let .loop(_, body)? = program.block(at: r) else { return }
        var p = program
        guard p.replace(at: r, with: .loop(min(9, max(2, n)), body)) else { return }
        Sound.key()
        program = p
        onEdit?()
    }

    private func normalizeCursor() {
        if program.list(track: cursor.track, container: cursor.container) == nil {
            cursor = CodingSlot(track: 0, container: [], index: program.main.count)
        }
    }
}

// MARK: - 小兔照着走

@Observable
@MainActor
final class CodingStage {
    enum Phase: Equatable {
        /// 还没跑（可以排积木）
        case editing
        /// 正在自己一步一步走
        case running
        /// 停住了（点了「一步」或者「停」），还没走完
        case paused
        /// 走完了，没过关：哪个花园、为什么
        case failed(garden: Int, CodingOutcome)
        /// 全部花园都过了
        case passed
    }

    private(set) var gardens: [CodingGarden]
    /// 现在显示第几个花园
    private(set) var shown = 0
    private(set) var bunny: CodingState
    private(set) var phase: Phase = .editing
    /// 正在做的那一块，外面套着的那些，重复现在是第几次
    private(set) var active: CodingRef?
    private(set) var stack: [CodingRef] = []
    private(set) var iterations: [CodingRef: Int] = [:]
    /// 出错的那一块（撞上去的那一块；转晕了是一直重复）
    private(set) var culprit: CodingRef?
    /// 撞到了：往哪边撞、第几次（花园那边晃一下）
    private(set) var bump: (dir: CodingDir, tick: Int)?
    /// 「如果」看了一下脚下：踩着了没有、第几次
    private(set) var check: (hit: Bool, tick: Int)?
    /// 走过的格子（画小脚印）
    private(set) var trail: [CodingCell] = []
    /// 最近一次是往左走的（小兔的图翻过来）
    private(set) var facingLeft = false
    /// 每个花园的结果（页签上画 ✓ / ✗）
    private(set) var gardenDone: [Int: Bool] = [:]
    var fast = false

    /// 走完了（过关或者没过）
    var onFinish: ((CodingRunResult) -> Void)?

    private var result: CodingRunResult?
    private var gi = 0
    private var ei = 0
    private var task: Task<Void, Never>?

    init(gardens: [CodingGarden]) {
        self.gardens = gardens
        bunny = .start(gardens[0])
    }

    var garden: CodingGarden { gardens[shown] }
    var busy: Bool { phase == .running }
    /// 走了一半（正在走或者停住了）
    var midway: Bool { phase == .running || phase == .paused }
    var failed: Bool { if case .failed = phase { return true }; return false }
    private var interval: Double { fast ? 0.2 : 0.45 }

    func setGardens(_ g: [CodingGarden]) {
        stopTask()
        gardens = g
        reset()
    }

    /// 回到起点：小兔回家、胡萝卜长回来
    func reset() {
        stopTask()
        result = nil
        gi = 0
        ei = 0
        withAnimation(.spring(duration: 0.35)) {
            shown = 0
            bunny = .start(gardens[0])
            phase = .editing
            active = nil
            stack = []
            iterations = [:]
            culprit = nil
            trail = []
            gardenDone = [:]
            facingLeft = false
        }
    }

    /// 只看某一个花园（页签）：没在走的时候才能换
    func show(_ i: Int) {
        guard !midway, gardens.indices.contains(i), i != shown else { return }
        if failed || phase == .passed { reset() }
        Sound.tap()
        withAnimation(.spring(duration: 0.3)) {
            shown = i
            bunny = .start(gardens[i])
            trail = []
        }
    }

    /// 「开始」：从头跑（停住了就接着跑）
    func start(_ p: CodingProgram) {
        if phase == .paused { resume(); return }
        prepare(p)
        Sound.start()
        phase = .running
        loop()
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .running
        loop()
    }

    /// 「停」
    func pause() {
        guard phase == .running else { return }
        stopTask()
        phase = .paused
    }

    /// 「一步」：只做一块
    func stepOnce(_ p: CodingProgram) {
        if phase == .running { pause(); return }
        if phase != .paused { prepare(p); phase = .paused }
        advance()
    }

    private func prepare(_ p: CodingProgram) {
        stopTask()
        result = CodingRunResult.run(p, gardens)
        gi = 0
        ei = 0
        shown = 0
        bunny = .start(gardens[0])
        active = nil
        stack = []
        iterations = [:]
        culprit = nil
        trail = []
        gardenDone = [:]
    }

    private func loop() {
        task?.cancel()
        task = Task { [weak self] in
            while let self, !Task.isCancelled, self.phase == .running {
                let more = self.advance()
                if !more { break }
                try? await Task.sleep(for: .seconds(self.pauseAfter))
            }
        }
    }

    private var pauseAfter: Double = 0.45

    /// 做下一块。返回 false = 走完了
    @discardableResult
    private func advance() -> Bool {
        guard let result, gi < result.traces.count else { return false }
        let t = result.traces[gi]
        if ei < t.events.count {
            let e = t.events[ei]
            ei += 1
            apply(e)
            pauseAfter = interval
            if ei < t.events.count { return true }
        }
        // 这个花园走完了
        let ok = t.passed
        gardenDone[gi] = ok
        if !ok {
            finish(failed: t)
            return false
        }
        if gi + 1 < result.traces.count {
            // 下一个花园：停一下再换
            gi += 1
            ei = 0
            pauseAfter = 0.8
            let next = gi
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(0.55))
                guard let self, self.gi == next else { return }
                Sound.pop()
                withAnimation(.spring(duration: 0.35)) {
                    self.shown = next
                    self.bunny = .start(self.gardens[next])
                    self.active = nil
                    self.stack = []
                    self.iterations = [:]
                    self.trail = []
                }
            }
            return true
        }
        finish(failed: nil)
        return false
    }

    private func apply(_ e: CodingEvent) {
        if shown != gi {
            shown = gi
            bunny = .start(gardens[gi])
            trail = []
        }
        active = e.ref
        stack = e.stack
        iterations = e.iterations
        switch e.kind {
        case .move(let d, let ate):
            if d == .left { facingLeft = true } else if d == .right { facingLeft = false }
            trail.append(bunny.cell)
            withAnimation(.spring(duration: fast ? 0.18 : 0.32, bounce: 0.35)) { bunny = e.state }
            if ate { Sound.pop() } else { Sound.step(min(10, 3 + trail.count % 5)) }
        case let .bump(d):
            bump = (d, (bump?.tick ?? 0) + 1)
            Sound.nope()
        case let .check(_, hit):
            check = (hit, (check?.tick ?? 0) + 1)
            if hit { Sound.sparkle() } else { Sound.tap() }
        }
    }

    private func finish(failed t: CodingTrace?) {
        guard let result else { return }
        stopTask()
        if let t {
            culprit = t.culprit
            phase = .failed(garden: gi, t.outcome)
            if t.outcome != .bump { Sound.oops() }
        } else {
            active = nil
            stack = []
            iterations = [:]
            phase = .passed
        }
        onFinish?(result)
    }

    private func stopTask() {
        task?.cancel()
        task = nil
    }

    func stop() { stopTask() }

    #if DEBUG
    /// 调试截图用：先跑 n 步停住（-codingStep）
    func debugSteps(_ p: CodingProgram, _ n: Int) {
        prepare(p)
        phase = .paused
        for _ in 0..<n { if !advance() { break } }
    }

    /// 调试截图用：直接摆出没过关的样子
    func debugFail(_ kind: CodingOutcome, garden: Int) {
        stopTask()
        shown = min(garden, gardens.count - 1)
        bunny = .start(gardens[shown])
        if kind == .bump { bump = (.right, (bump?.tick ?? 0) + 1) }
        culprit = CodingRef(track: 0, path: [0])
        phase = .failed(garden: shown, kind)
        for i in 0..<shown { gardenDone[i] = true }
        gardenDone[shown] = false
    }
    #endif
}
