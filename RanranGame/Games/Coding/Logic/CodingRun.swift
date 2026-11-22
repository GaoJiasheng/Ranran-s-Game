import Foundation

// 编程的解释器：小兔照着程序一块一块做，记下每一步（跑的时候一步一步演，"一步"按钮一次演一步）。只用 Foundation。
//
// 规则（docs/tutorial-coding.md「花园和规则」）：
//   往石头上走、往花园外面走都算"撞到了"，程序停在那一块；
//   走上胡萝卜就吃掉；没有家的花园，吃到最后一根就过关（后面多排的不算错）；
//   有家的花园，吃完全部胡萝卜再走到家才过关（没吃完路过家不算，接着走）；
//   程序走完还没过关 = "指令走完了"；走了 200 步还没完（一直重复才会这样）= "转晕了"。
//   「如果踩着蓝花」看的是小兔现在站的那一格；看一下算一步（不走路），让她看得见"看了、没踩着、跳过"。

struct CodingState: Hashable {
    var x: Int
    var y: Int
    /// 吃掉了哪几根胡萝卜（第 i 位是第 i 根）
    var eaten: UInt32

    var cell: CodingCell { CodingCell(x: x, y: y) }

    static func start(_ g: CodingGarden) -> CodingState { CodingState(x: g.start.x, y: g.start.y, eaten: 0) }
}

enum CodingOutcome: String, Hashable {
    /// 过关
    case success
    /// 撞到石头或者花园的边
    case bump
    /// 指令走完了，还没过关
    case end
    /// 走了太多步（一直重复停不下来）
    case dizzy
}

struct CodingEvent: Hashable {
    enum Kind: Hashable {
        /// 走了一格；ate = 吃到了一根胡萝卜
        case move(CodingDir, ate: Bool)
        /// 想往这边走，撞到了（没动）
        case bump(CodingDir)
        /// 「如果」看了一下脚下：hit = 踩着了
        case check(CodingFlower, hit: Bool)
    }

    let kind: Kind
    /// 正在做的那一块
    let ref: CodingRef
    /// 外面套着的积木（从外往里）：重复、绝招、如果、一直重复的壳，还有主程序里叫绝招的那一块
    let stack: [CodingRef]
    /// 重复、一直重复现在是第几次
    let iterations: [CodingRef: Int]
    /// 做完这一块以后的样子
    let state: CodingState
}

struct CodingTrace: Hashable {
    let garden: CodingGarden
    let events: [CodingEvent]
    let outcome: CodingOutcome
    let final: CodingState
    /// 出错的那一块：撞上去的那一块；转晕了是外面那个一直重复
    let culprit: CodingRef?

    var passed: Bool { outcome == .success }
}

struct CodingMachine {
    static let maxMoves = 200
    /// 看花、空转也算上的总步数（一直重复里只放了「如果」、又一直踩不着花，也要停下来）
    static let maxTicks = 600

    let garden: CodingGarden
    let program: CodingProgram
    let record: Bool

    private(set) var state: CodingState
    private(set) var events: [CodingEvent] = []
    private(set) var outcome: CodingOutcome?
    private(set) var culprit: CodingRef?
    private var moves = 0
    private var ticks = 0
    private var stack: [CodingRef] = []
    private var iterations: [CodingRef: Int] = [:]

    init(garden: CodingGarden, program: CodingProgram, from state: CodingState? = nil, record: Bool) {
        self.garden = garden
        self.program = program
        self.record = record
        self.state = state ?? .start(garden)
    }

    private var won: Bool {
        guard state.eaten == garden.allEaten else { return false }
        guard let h = garden.home else { return true }
        return h.x == state.x && h.y == state.y
    }

    private mutating func emit(_ k: CodingEvent.Kind, _ ref: CodingRef) {
        guard record else { return }
        events.append(CodingEvent(kind: k, ref: ref, stack: stack, iterations: iterations, state: state))
    }

    private mutating func dizzy(_ ref: CodingRef) {
        outcome = .dizzy
        culprit = stack.first ?? ref
    }

    /// 做一串积木；返回 true = 停下来了（过关、撞到、转晕）
    mutating func run(_ list: [CodingBlock], track: Int, prefix: [Int]) -> Bool {
        for (i, b) in list.enumerated() {
            let ref = CodingRef(track: track, path: prefix + [i])
            if step(b, ref) { return true }
        }
        return false
    }

    private mutating func step(_ b: CodingBlock, _ ref: CodingRef) -> Bool {
        switch b {
        case let .move(d):
            let nx = state.x + d.dx, ny = state.y + d.dy
            ticks += 1
            guard garden.open(nx, ny) else {
                emit(.bump(d), ref)
                outcome = .bump
                culprit = ref
                return true
            }
            state.x = nx
            state.y = ny
            var ate = false
            if let c = garden.carrotIndex(nx, ny), state.eaten & (1 << c) == 0 {
                state.eaten |= 1 << c
                ate = true
            }
            moves += 1
            emit(.move(d, ate: ate), ref)
            if won { outcome = .success; return true }
            if moves >= Self.maxMoves || ticks >= Self.maxTicks { dizzy(ref); return true }
            return false
        case let .call(p):
            // 绝招里不能再叫绝招（规矩不让放）；万一有，当它不存在，免得没完没了
            guard ref.track == 0 else { return false }
            stack.append(ref)
            defer { stack.removeLast() }
            return run(program.tracks[p.track], track: p.track, prefix: [])
        case let .loop(n, body):
            stack.append(ref)
            defer { stack.removeLast(); iterations[ref] = nil }
            for k in 1...max(n, 1) {
                iterations[ref] = k
                if run(body, track: ref.track, prefix: ref.path) { return true }
            }
            return false
        case let .when(f, body):
            let hit = garden.flower(state.x, state.y) == f
            ticks += 1
            emit(.check(f, hit: hit), ref)
            if ticks >= Self.maxTicks { dizzy(ref); return true }
            guard hit else { return false }
            stack.append(ref)
            defer { stack.removeLast() }
            return run(body, track: ref.track, prefix: ref.path)
        case let .forever(body):
            stack.append(ref)
            defer { stack.removeLast(); iterations[ref] = nil }
            var k = 0
            while true {
                k += 1
                iterations[ref] = k
                if run(body, track: ref.track, prefix: ref.path) { return true }
                ticks += 1
                if ticks >= Self.maxTicks { dizzy(ref); return true }
            }
        }
    }

    /// 跑一整个程序，记下每一步
    static func trace(_ program: CodingProgram, in garden: CodingGarden) -> CodingTrace {
        var m = CodingMachine(garden: garden, program: program, record: true)
        _ = m.run(program.main, track: 0, prefix: [])
        return CodingTrace(garden: garden, events: m.events, outcome: m.outcome ?? .end, final: m.state, culprit: m.culprit)
    }

    /// 只看结果（不记每一步，快）
    static func outcome(_ program: CodingProgram, in garden: CodingGarden) -> CodingOutcome {
        var m = CodingMachine(garden: garden, program: program, record: false)
        _ = m.run(program.main, track: 0, prefix: [])
        return m.outcome ?? .end
    }

    static func passes(_ program: CodingProgram, _ gardens: [CodingGarden]) -> Bool {
        gardens.allSatisfy { outcome(program, in: $0) == .success }
    }

    /// 从某个样子开始做一串积木（求解器用）：返回做完的样子，和停下来的原因（nil = 做完了还没过关）
    static func exec(_ blocks: [CodingBlock], program: CodingProgram, garden: CodingGarden,
                     from s: CodingState) -> (CodingState, CodingOutcome?) {
        var m = CodingMachine(garden: garden, program: program, from: s, record: false)
        _ = m.run(blocks, track: 0, prefix: [])
        return (m.state, m.outcome)
    }
}

/// 好几个花园依次跑：第一个没过的停下来
struct CodingRunResult: Hashable {
    let traces: [CodingTrace]

    var passed: Bool { traces.allSatisfy(\.passed) }
    /// 第一个没过的花园
    var failedGarden: Int? { traces.firstIndex { !$0.passed } }

    static func run(_ p: CodingProgram, _ gardens: [CodingGarden]) -> CodingRunResult {
        var out: [CodingTrace] = []
        for g in gardens {
            let t = CodingMachine.trace(p, in: g)
            out.append(t)
            if !t.passed { break }
        }
        return CodingRunResult(traces: out)
    }
}
