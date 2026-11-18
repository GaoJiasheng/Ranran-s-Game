import SwiftUI

/// 场景里的一个物品。
struct StoryToken: Identifiable, Hashable {
    let id: Int
    var spot: Spot
    /// 同一个地方里的先后顺序，越大越靠后
    var order: Int
    /// 最开始在谁那里（给来给去以后能看出这几个是谁给的）
    let origin: Spot
}

/// 一次拖动的方向
struct StoryRoute: Hashable {
    let from: Spot
    let to: Spot
}

/// 演故事的"舞台"：两排物品对齐摆放（天然就是一一对应），旁边可能有"吃掉的"盘子和篮子。
@Observable
@MainActor
final class StoryStage {
    private(set) var problem: StoryProblem
    private(set) var tokens: [StoryToken] = []
    /// 这一步故事里的方向（比如小兔 → 熊猫）；nil 的时候谁也拖不动。
    /// 反方向只能把这一步刚拖过去的拿回来，不能从一开始就反着拖。
    var forward: StoryRoute? {
        didSet { beatTokens = [] }
    }
    /// 这一步里按故事方向拖过去的物品
    private var beatTokens: Set<Int> = []
    var draggingID: Int?
    var dragPoint: CGPoint = .zero
    /// 从篮子里拖出一个新的
    var supplyDrag: CGPoint?
    var hover: Spot?
    /// 比一比：对齐的连线、多出来的发光
    /// 比一比：亮出一一对应和"多出来的"
    var comparing = false {
        didSet { if comparing, !oldValue { Sound.sparkle() } }
    }
    /// 点一点数一数：token id → 第几个
    private(set) var counted: [Int: Int] = [:]
    /// 不显示个数的地方（显示了就等于告诉答案）
    var hiddenBadges: Set<Spot> = []
    var visible = true

    /// 盘子有几个（乘法、除法用）
    private(set) var plateCount = 0
    /// 演盘子的这一步怎么拖：nil 的时候盘子不能动
    var plateRule: PlateRule?
    /// "一共有几个"的目标牌子
    private(set) var wholeTarget: Int?
    /// 跳着数：点盘子时记下数到几（第几个盘子 → 数到的数）
    private(set) var plateCounted: [Int: Int] = [:]

    enum PlateRule: Equatable {
        /// 从篮子里往每个盘子放 n 个
        case fill(Int)
        /// 把手里的平均分到盘子里
        case share
        /// 每个盘子最多 n 个
        case group(Int)
    }

    var onDrop: ((StoryRoute) -> Void)?
    var onReject: ((StoryRoute) -> Void)?

    private var nextID = 0
    private var nextOrder = 0

    init(problem: StoryProblem) {
        self.problem = problem
    }

    /// 每一排最多能放几个（比故事里最多的再多一点，给孩子摆错的余地）
    var limit: Int { max(problem.capacity + 2, 10) }

    func reset(_ problem: StoryProblem) {
        self.problem = problem
        tokens = []
        forward = nil
        draggingID = nil
        supplyDrag = nil
        hover = nil
        comparing = false
        counted = [:]
        hiddenBadges = []
        plateCount = 0
        plateRule = nil
        wholeTarget = nil
        plateCounted = [:]
    }

    func clear() {
        tokens = []
        counted = [:]
        comparing = false
        plateCount = 0
        plateRule = nil
        wholeTarget = nil
        plateCounted = [:]
    }

    var activePlates: [Spot] { Array(Spot.plates.prefix(plateCount)) }

    func ordered(_ spot: Spot) -> [StoryToken] {
        tokens.filter { $0.spot == spot }.sorted { $0.order < $1.order }
    }

    func count(_ spot: Spot) -> Int { tokens.reduce(0) { $0 + ($1.spot == spot ? 1 : 0) } }

    func counts() -> [Spot: Int] {
        var c: [Spot: Int] = [.a: count(.a), .b: count(.b), .away: count(.away)]
        for p in activePlates { c[p] = count(p) }
        return c
    }

    @discardableResult
    private func add(_ spot: Spot, origin: Spot? = nil) -> Int {
        nextID += 1
        nextOrder += 1
        tokens.append(StoryToken(id: nextID, spot: spot, order: nextOrder, origin: origin ?? spot))
        return nextID
    }

    private func relocate(_ id: Int, to spot: Spot) {
        guard let i = tokens.firstIndex(where: { $0.id == id }) else { return }
        nextOrder += 1
        tokens[i].spot = spot
        tokens[i].order = nextOrder
    }

    // MARK: 自动演

    func perform(_ action: StoryAction, animated: Bool) async {
        switch action {
        case let .appear(s, n):
            for _ in 0..<n {
                if animated {
                    withAnimation(.spring(duration: 0.4, bounce: 0.5)) { _ = add(s) }
                    Sound.pop()
                    try? await Task.sleep(for: .milliseconds(110))
                } else {
                    add(s)
                }
            }
        case let .move(f, t, n):
            await autoMove(from: f, to: t, n, animated: animated)
        case let .build(s, n):
            let have = count(s)
            if n > have { await autoMove(from: .supply, to: s, n - have, animated: animated) }
            if n < have { await autoMove(from: s, to: .supply, have - n, animated: animated) }
        case let .balance(f, t):
            let d = (count(f) - count(t)) / 2
            if d > 0 { await autoMove(from: f, to: t, d, animated: animated) }
        case let .whole(n):
            withAnimation(.spring(duration: 0.45, bounce: 0.4)) { wholeTarget = n }
            if animated { Sound.pop() }
        case let .plates(g):
            for i in plateCount..<max(plateCount, g) {
                withAnimation(.spring(duration: 0.45, bounce: 0.4)) { plateCount = i + 1 }
                if animated {
                    Sound.pop()
                    try? await Task.sleep(for: .milliseconds(160))
                }
            }
        case let .fill(n):
            for p in activePlates where count(p) < n {
                await autoMove(from: .supply, to: p, n - count(p), animated: animated)
            }
        case .share:
            var i = 0
            while count(.a) > 0, !activePlates.isEmpty, !Task.isCancelled {
                await autoMove(from: .a, to: activePlates[i % activePlates.count], 1, animated: animated)
                i += 1
            }
        case let .group(n):
            var i = 0
            while count(.a) > 0, i < Spot.plates.count, !Task.isCancelled {
                if plateCount <= i { withAnimation(.spring(duration: 0.4)) { plateCount = i + 1 } }
                let p = Spot.plates[i]
                await autoMove(from: .a, to: p, max(0, min(n - count(p), count(.a))), animated: animated)
                i += 1
            }
        }
    }

    private func autoMove(from: Spot, to: Spot, _ n: Int, animated: Bool) async {
        for _ in 0..<n {
            if Task.isCancelled { return }
            let id: Int
            if from == .supply {
                id = add(.supply)
                if animated { try? await Task.sleep(for: .milliseconds(40)) }
            } else {
                guard let last = ordered(from).last else { return }
                id = last.id
            }
            if animated {
                withAnimation(.spring(duration: 0.55, bounce: 0.3)) { relocate(id, to: to) }
                Sound.drop()
            } else {
                relocate(id, to: to)
            }
            if to == .supply { removeLater(id, animated: animated) }
            if animated { try? await Task.sleep(for: .milliseconds(330)) }
        }
    }

    private func removeLater(_ id: Int, animated: Bool) {
        guard animated else { tokens.removeAll { $0.id == id }; return }
        Task {
            try? await Task.sleep(for: .milliseconds(380))
            withAnimation(.easeOut(duration: 0.2)) { tokens.removeAll { $0.id == id } }
        }
    }

    // MARK: 孩子拖动

    func canDrag(from spot: Spot) -> Bool {
        if let plateRule {
            switch plateRule {
            case .fill:          return spot == .supply || spot.isPlate
            case .share, .group: return spot == .a || spot.isPlate
            }
        }
        guard let forward else { return false }
        return spot == forward.from || spot == forward.to
    }

    /// 按故事方向拖：可以；反方向：只有这一步拖过去的那几个可以拿回来
    private func permits(_ route: StoryRoute, token id: Int?) -> Bool {
        if let plateRule {
            switch plateRule {
            case .fill:
                return (route.from == .supply || route.from.isPlate) && (route.to == .supply || route.to.isPlate)
            case .share:
                return (route.from == .a || route.from.isPlate) && (route.to == .a || route.to.isPlate)
            case let .group(n):
                guard (route.from == .a || route.from.isPlate) && (route.to == .a || route.to.isPlate) else { return false }
                return !route.to.isPlate || count(route.to) < n
            }
        }
        guard let forward else { return false }
        if route == forward { return true }
        if route.from == forward.to, route.to == forward.from, let id { return beatTokens.contains(id) }
        return false
    }

    /// 演盘子的时候点一下盘子：放进去一个（从篮子里或者从手里）；比一比的时候点盘子：跳着数
    func tapPlate(_ i: Int) {
        let p = Spot.plates[i]
        if comparing {
            countPlate(i)
            return
        }
        guard let plateRule else { return }
        switch plateRule {
        case .fill:
            guard count(p) < 12 else { return }
            withAnimation(.spring(duration: 0.4, bounce: 0.5)) { _ = add(p, origin: .supply) }
            Sound.drop()
            onDrop?(StoryRoute(from: .supply, to: p))
        case .share, .group:
            guard let last = ordered(.a).last else { return }
            let route = StoryRoute(from: .a, to: p)
            guard permits(route, token: last.id) else {
                onReject?(route)
                return
            }
            withAnimation(.spring(duration: 0.45, bounce: 0.35)) { relocate(last.id, to: p) }
            Sound.drop()
            growPlates()
            onDrop?(route)
        }
    }

    /// 每盘放几个：手里还有，而且盘子都放满了，就再摆一个空盘子（最多摆到这道题要用的盘子数）
    private func growPlates() {
        guard case let .group(n) = plateRule, count(.a) > 0,
              plateCount < min(max(problem.plateSlots, 1), Spot.plates.count) else { return }
        if activePlates.allSatisfy({ count($0) >= n }) {
            withAnimation(.spring(duration: 0.45, bounce: 0.4)) { plateCount += 1 }
            Sound.pop()
        }
    }

    /// 开始"每盘放几个"时先摆一个空盘子
    func beginGrouping() {
        if plateCount == 0 { withAnimation(.spring(duration: 0.45, bounce: 0.4)) { plateCount = 1 } }
    }

    func beginDrag(_ id: Int, at p: CGPoint, hit: Spot?) {
        if draggingID != id { Sound.pick() }
        draggingID = id
        dragPoint = p
        hover = hit
    }

    func drop(_ id: Int, on target: Spot?) {
        defer {
            withAnimation(.spring(duration: 0.45, bounce: 0.35)) {
                draggingID = nil
                hover = nil
            }
        }
        guard let token = tokens.first(where: { $0.id == id }), let target, target != token.spot else { return }
        let route = StoryRoute(from: token.spot, to: target)
        guard permits(route, token: id) else {
            onReject?(route)
            return
        }
        if target != .supply, target != .away, count(target) >= (target.isPlate ? 12 : limit) { return }
        if route == forward { beatTokens.insert(id) } else { beatTokens.remove(id) }
        withAnimation(.spring(duration: 0.45, bounce: 0.35)) { relocate(id, to: target) }
        if target == .supply { removeLater(id, animated: true) }
        Sound.drop()
        growPlates()
        onDrop?(route)
    }

    func dropFromSupply(on target: Spot?) {
        defer {
            withAnimation(.spring(duration: 0.3)) {
                supplyDrag = nil
                hover = nil
            }
        }
        guard let target, target != .supply else { return }
        let route = StoryRoute(from: .supply, to: target)
        guard permits(route, token: nil) else {
            onReject?(route)
            return
        }
        guard count(target) < (target.isPlate ? 12 : limit) else { return }
        withAnimation(.spring(duration: 0.4, bounce: 0.5)) { beatTokens.insert(add(target, origin: .supply)) }
        Sound.drop()
        onDrop?(route)
    }

    // MARK: 比一比、数一数

    /// 问题问到的那几个物品（会发光，可以点着数）
    func focus() -> Set<Int> {
        let ids: [Int]
        switch problem.ask {
        case .more, .less:
            let a = ordered(.a), b = ordered(.b)
            let (big, small) = a.count >= b.count ? (a, b) : (b, a)
            ids = big.dropFirst(small.count).map(\.id)
        case .total:
            ids = tokens.filter { $0.spot == .a || $0.spot == .b }.map(\.id)
        case let .count(s):
            ids = ordered(s).map(\.id)
        case .moved:
            ids = tokens.filter { ($0.spot == .a || $0.spot == .b) && ($0.origin == .a || $0.origin == .b) && $0.origin != $0.spot }.map(\.id)
        case .perPlate:
            ids = ordered(.p1).map(\.id)
        case .inPlates:
            ids = tokens.filter { $0.spot.isPlate }.map(\.id)
        case .plates:
            ids = []
        }
        return Set(ids)
    }

    var focusLabel: String {
        switch problem.ask {
        case .more, .less: "the extra ones"
        case .total:       "altogether"
        case .count:       "now"
        case .moved:       "given"
        case .perPlate:    "one \(problem.plateWord)"
        case .plates:      problem.plateWords
        case .inPlates:    "in all"
        }
    }

    /// 点盘子跳着数：问几个盘子就 1、2、3……；问一共几个就 4、8、12……
    private func countPlate(_ i: Int) {
        guard problem.usesPlates, plateCounted[i] == nil, i < plateCount else { return }
        let step = problem.ask == .plates ? 1 : count(Spot.plates[i])
        let n = (plateCounted.values.max() ?? 0) + step
        withAnimation(.spring(duration: 0.3, bounce: 0.6)) { plateCounted[i] = n }
        Sound.step(min(plateCounted.count + 2, 10))
    }

    func countTap(_ id: Int) {
        guard comparing, focus().contains(id), counted[id] == nil else { return }
        let n = counted.count + 1
        withAnimation(.spring(duration: 0.3, bounce: 0.6)) { counted[id] = n }
        Sound.step(min(n, 10))
    }

    func resetCounting() {
        withAnimation(.easeOut(duration: 0.2)) {
            counted = [:]
            plateCounted = [:]
        }
    }
}

// MARK: - 布局

/// 所有位置都在一个坐标系里算，物品换地方时直接动画过去。
struct StageLayout {
    let size: CGSize
    let lanes: [Spot]
    let sides: [Spot]
    let capacity: Int
    /// 最多几个盘子（0 = 这道题不用盘子）
    var plates = 0

    let pad: CGFloat = 14

    /// 竖着有空间时，盘子和篮子放在下面一排，把横向的位置都留给物品
    var sidesBelow: Bool { plates == 0 && !sides.isEmpty && size.height >= CGFloat(lanes.count) * 130 + 170 }
    var sideRowH: CGFloat { sidesBelow ? min(190, size.height * 0.36) : 0 }

    var labelW: CGFloat { min(120, size.width * 0.14) }
    var sideW: CGFloat { sides.isEmpty || sidesBelow ? 0 : min(150, size.width * 0.16) }
    var itemsX0: CGFloat { pad + labelW + 16 }
    var itemsX1: CGFloat { size.width - pad - (sideW > 0 ? sideW + 22 : 14) }

    /// 有盘子的时候，人物那一排在上面，盘子在下面
    private var lanesHeight: CGFloat {
        if plates > 0 { return lanes.isEmpty ? 0 : min(170, size.height * 0.36) }
        return size.height - (sidesBelow ? sideRowH + 10 : 0)
    }
    var laneH: CGFloat {
        guard !lanes.isEmpty else { return 0 }
        return min(lanes.count == 1 ? 210 : 180, (lanesHeight - pad * 2) / CGFloat(lanes.count))
    }
    private var lanesTop: CGFloat { plates > 0 ? pad : (lanesHeight - laneH * CGFloat(lanes.count)) / 2 }

    var cell: CGFloat {
        let n = max(capacity, 10)
        let groups = CGFloat((n - 1) / 5)
        let byLane = laneH > 0 ? laneH * 0.5 : 84
        return min(84, byLane, (itemsX1 - itemsX0) / (CGFloat(n) + groups * 0.35))
    }

    var gap: CGFloat { cell * 0.35 }

    func laneRect(_ i: Int) -> CGRect {
        CGRect(x: pad, y: lanesTop + CGFloat(i) * laneH + 6, width: itemsX1 - pad + 12, height: laneH - 12)
    }

    func laneRect(_ s: Spot) -> CGRect? { lanes.firstIndex(of: s).map { laneRect($0) } }

    func sideRect(_ s: Spot) -> CGRect? {
        guard let j = sides.firstIndex(of: s) else { return nil }
        let n = CGFloat(sides.count)
        let spacing: CGFloat = 16
        if sidesBelow {
            let w = min(300, (size.width - pad * 2 - spacing * (n - 1)) / n)
            let left = (size.width - (w * n + spacing * (n - 1))) / 2
            return CGRect(x: left + CGFloat(j) * (w + spacing), y: size.height - pad - sideRowH, width: w, height: sideRowH)
        }
        let avail = size.height - pad * 2
        let h = min(250, (avail - spacing * (n - 1)) / n)
        let top = (size.height - (h * n + spacing * (n - 1))) / 2
        return CGRect(x: size.width - pad - sideW, y: top + CGFloat(j) * (h + spacing), width: sideW, height: h)
    }

    // MARK: 盘子

    private var platesTop: CGFloat { lanes.isEmpty ? pad : lanesTop + laneH * CGFloat(lanes.count) + 4 }
    private var platesRight: CGFloat { size.width - pad - (sideW > 0 ? sideW + 22 : 0) }
    /// 盘子一排最多几个
    private var plateCols: Int { plates <= 4 ? plates : 3 }
    private var plateRows: Int { plates == 0 ? 0 : (plates + plateCols - 1) / plateCols }
    private let plateLabelH: CGFloat = 40

    var plateD: CGFloat {
        guard plates > 0 else { return 0 }
        let spacing: CGFloat = 18
        let w = (platesRight - pad - spacing * CGFloat(plateCols - 1)) / CGFloat(plateCols)
        let h = (size.height - platesTop - pad - CGFloat(plateRows) * plateLabelH) / CGFloat(plateRows)
        return max(60, min(250, w, h))
    }

    func plateRect(_ i: Int) -> CGRect {
        let spacing: CGFloat = 18
        let d = plateD
        let row = i / plateCols, col = i % plateCols
        let inRow = min(plateCols, plates - row * plateCols)
        let rowW = CGFloat(inRow) * d + CGFloat(inRow - 1) * spacing
        let x0 = pad + (platesRight - pad - rowW) / 2
        let blockH = CGFloat(plateRows) * (d + plateLabelH)
        let y0 = platesTop + max(0, (size.height - pad - platesTop - blockH) / 2)
        return CGRect(x: x0 + CGFloat(col) * (d + spacing), y: y0 + CGFloat(row) * (d + plateLabelH), width: d, height: d)
    }

    /// 盘子里物品的大小：放 6 个以内时宽松，再多就缩小
    func plateCell(_ count: Int) -> CGFloat {
        let rows = max(2, (count + 2) / 3)
        return plateD * min(0.27, 0.66 / CGFloat(rows))
    }

    /// 盘子里第 index 个的位置（一共 count 个）：一排 3 个居中摆，4 个摆成 2×2
    func plateSlot(_ index: Int, count: Int, plate i: Int) -> CGPoint {
        let r = plateRect(i)
        let cols = count == 4 ? 2 : 3
        let rows = (count + cols - 1) / cols
        let c = plateCell(count) * 1.08
        let row = index / cols
        let inRow = min(cols, count - row * cols)
        let x = r.midX + (CGFloat(index % cols) - CGFloat(inRow - 1) / 2) * c
        let y = r.midY + (CGFloat(row) - CGFloat(rows - 1) / 2) * c
        return CGPoint(x: x, y: y)
    }

    // MARK: 位置

    func slotX(_ index: Int) -> CGFloat {
        itemsX0 + cell * (CGFloat(index) + 0.5) + gap * CGFloat(index / 5)
    }

    func slot(_ index: Int, in spot: Spot, count: Int = 0) -> CGPoint {
        if let i = spot.plateIndex { return plateSlot(index, count: max(count, index + 1), plate: i) }
        switch spot {
        case .a, .b:
            let r = laneRect(spot) ?? .zero
            return CGPoint(x: slotX(index), y: r.midY)
        case .away:
            guard let r = sideRect(.away) else { return .zero }
            let s = awayCell(r)
            let cols = max(3, Int((r.width - 20) / s))
            let x0 = r.midX - s * CGFloat(cols) / 2
            let x = x0 + s * (CGFloat(index % cols) + 0.5)
            let y = r.minY + 50 + s * (CGFloat(index / cols) + 0.5)
            return CGPoint(x: x, y: min(y, r.maxY - s / 2))
        case .supply:
            guard let r = sideRect(.supply) else { return .zero }
            return CGPoint(x: r.midX, y: r.midY - 8)
        default:
            return .zero
        }
    }

    func awayCell(_ r: CGRect) -> CGFloat { min(cell * 0.8, 54, (r.width - 20) / 3) }

    func hit(_ p: CGPoint, plateCount: Int = 0) -> Spot? {
        for s in sides {
            if let r = sideRect(s), r.insetBy(dx: -12, dy: -12).contains(p) { return s }
        }
        for i in 0..<min(plateCount, plates) {
            let r = plateRect(i).insetBy(dx: -14, dy: -14)
            if hypot(p.x - r.midX, p.y - r.midY) <= r.width / 2 { return Spot.plates[i] }
        }
        for (i, s) in lanes.enumerated() where laneRect(i).insetBy(dx: -8, dy: -2).contains(p) {
            return s
        }
        return nil
    }
}

// MARK: - 视图

struct StoryStageView: View {
    let stage: StoryStage
    let player: String

    var body: some View {
        GeometryReader { geo in
            let p = stage.problem
            let L = StageLayout(size: geo.size, lanes: p.lanes, sides: p.sides, capacity: stage.limit,
                                plates: p.usesPlates ? max(p.plateSlots, 1) : 0)
            let focus = stage.comparing ? stage.focus() : []
            ZStack(alignment: .topLeading) {
                ForEach(Array(p.lanes.enumerated()), id: \.element) { i, spot in
                    lane(spot, rect: L.laneRect(i), L: L)
                }
                ForEach(0..<stage.plateCount, id: \.self) { i in
                    plate(i, L: L)
                }
                ForEach(p.sides, id: \.self) { spot in
                    if let r = L.sideRect(spot) { side(spot, rect: r, L: L) }
                }
                if stage.comparing { compareOverlay(L: L, focus: focus) }

                ForEach(stage.tokens) { t in
                    token(t, L: L, focused: focus.contains(t.id))
                }

                if let at = stage.supplyDrag {
                    TokenView(item: p.item, size: L.cell * 1.1, focused: false, marker: nil, number: nil)
                        .position(at)
                        .zIndex(20)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay(alignment: .topTrailing) { wholeBadge }
            .coordinateSpace(name: "stage")
        }
    }

    /// "Altogether: 12" 目标牌子，旁边是现在一共几个
    @ViewBuilder
    private var wholeBadge: some View {
        if let target = stage.wholeTarget {
            let now = stage.count(.a) + stage.count(.b)
            HStack(spacing: 10) {
                Text("Altogether")
                    .font(.kid(17, weight: .heavy))
                    .foregroundStyle(Palette.inkSoft)
                Text("\(target)")
                    .font(.kid(26, weight: .black))
                    .foregroundStyle(Palette.ink)
                if now > 0 {
                    Text("now \(now)")
                        .font(.kid(16, weight: .heavy))
                        .foregroundStyle(now == target ? Color(hex: 0x4E8A5C) : Palette.coral)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background((now == target ? Palette.sage : Palette.coral).opacity(0.16), in: Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Palette.honey.opacity(0.22), in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.honey, lineWidth: 2.5))
            .padding(16)
            .animation(.spring(duration: 0.3), value: now)
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: 一排

    private func lane(_ spot: Spot, rect: CGRect, L: StageLayout) -> some View {
        let p = stage.problem
        let cast = spot == .a ? p.a : (p.b ?? p.a)
        let hovering = stage.hover == spot
        let avatar = min(78, rect.height * 0.56)
        let n = stage.count(spot)
        let unknownEmpty = p.unknown == spot && n == 0
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(cast.tint.opacity(hovering ? 0.32 : 0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(cast.tint.opacity(hovering ? 0.9 : 0), lineWidth: 3)
                )
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)

            // 物品放的"架子"
            Capsule()
                .fill(Palette.paper.opacity(0.75))
                .frame(width: L.itemsX1 - L.itemsX0 + 20, height: min(rect.height - 16, L.cell * 1.34))
                .position(x: (L.itemsX0 + L.itemsX1) / 2, y: rect.midY)

            VStack(spacing: 6) {
                Avatar(image: cast.image, fallback: cast.emoji, tint: cast.tint, size: avatar)
                    .overlay(alignment: .bottomTrailing) {
                        if !stage.hiddenBadges.contains(spot), p.unknown != spot || n > 0 {
                            countBadge(n, color: cast.ink)
                                .offset(x: 10, y: 4)
                        }
                    }
                Text(cast.name(player))
                    .font(.kid(18, weight: .heavy))
                    .foregroundStyle(cast.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(width: L.labelW)
            .position(x: L.pad + L.labelW / 2 + 8, y: rect.midY)

            if unknownEmpty {
                HStack(spacing: 10) {
                    Text("?")
                        .font(.kid(44, weight: .black))
                        .foregroundStyle(cast.ink.opacity(0.55))
                    if stage.canDrag(from: .supply) {
                        Text("Drag \(p.thing.many) from the basket")
                            .font(.kid(19, weight: .bold))
                            .foregroundStyle(Palette.inkSoft)
                    }
                }
                .position(x: (L.itemsX0 + L.itemsX1) / 2, y: rect.midY)
                .transition(.opacity)
            }
        }
    }

    private func countBadge(_ n: Int, color: Color) -> some View {
        Text("\(n)")
            .font(.kid(19, weight: .heavy))
            .foregroundStyle(.white)
            .monospacedDigit()
            .contentTransition(.numericText())
            .frame(minWidth: 32, minHeight: 32)
            .padding(.horizontal, 4)
            .background(color, in: Capsule())
            .overlay(Capsule().strokeBorder(.white, lineWidth: 3))
            .animation(.spring(duration: 0.3), value: n)
    }

    // MARK: 盘子

    private func plate(_ i: Int, L: StageLayout) -> some View {
        let p = stage.problem
        let spot = Spot.plates[i]
        let r = L.plateRect(i)
        let hovering = stage.hover == spot
        let n = stage.count(spot)
        let counted = stage.plateCounted[i]
        let glow = stage.comparing && (p.ask == .plates || p.ask == .inPlates || (p.ask == .perPlate && i == 0))
        return ZStack {
            Circle()
                .fill(Palette.honey.opacity(glow ? 0.25 : 0))
                .frame(width: r.width * 1.12, height: r.width * 1.12)
            ArtImage(name: "item_plate", fallback: "🍽️")
                .frame(width: r.width, height: r.height)
                .scaleEffect(hovering ? 1.06 : 1)
                .overlay(
                    Circle().strokeBorder(Palette.coral.opacity(hovering ? 0.8 : 0), lineWidth: 3.5)
                )
            if let counted {
                Text("\(counted)")
                    .font(.kid(22, weight: .black))
                    .foregroundStyle(.white)
                    .frame(minWidth: 44, minHeight: 44)
                    .background(Palette.coral, in: Circle())
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    .offset(x: r.width * 0.36, y: -r.width * 0.36)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        }
        .frame(width: r.width, height: r.height)
        .overlay(alignment: .bottom) {
            if !stage.hiddenBadges.contains(spot) {
                countBadge(n, color: Palette.inkSoft)
                    .offset(y: 30)
            }
        }
        .contentShape(Circle())
        .onTapGesture { stage.tapPlate(i) }
        .position(x: r.midX, y: r.midY)
        .transition(.scale(scale: 0.4).combined(with: .opacity))
    }

    // MARK: 用掉的盘子和篮子

    @ViewBuilder
    private func side(_ spot: Spot, rect: CGRect, L: StageLayout) -> some View {
        let p = stage.problem
        let hovering = stage.hover == spot
        if spot == .away {
            VStack(spacing: 0) {
                Text(p.awayLabel)
                    .font(.kid(18, weight: .heavy))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.top, 14)
                    .padding(.horizontal, 8)
                Spacer()
                if !stage.hiddenBadges.contains(.away), stage.count(.away) > 0 {
                    Text("\(stage.count(.away))")
                        .font(.kid(18, weight: .heavy))
                        .foregroundStyle(Palette.inkSoft)
                        .padding(.bottom, 10)
                }
            }
            .frame(width: rect.width, height: rect.height)
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Palette.cream)
                    .overlay(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .strokeBorder(hovering ? Palette.coral.opacity(0.8) : Palette.inkSoft.opacity(0.22),
                                          style: StrokeStyle(lineWidth: hovering ? 3 : 2.5, dash: hovering ? [] : [9, 8]))
                    )
            )
            .position(x: rect.midX, y: rect.midY)
        } else {
            let canDrag = stage.canDrag(from: .supply)
            VStack(spacing: 6) {
                ArtImage(name: "item_basket", fallback: "🧺")
                    .frame(width: rect.width * 0.82, height: min(rect.height * 0.62, rect.width * 0.82))
                    .scaleEffect(hovering ? 1.08 : 1)
                Text(p.supplyLabel)
                    .font(.kid(17, weight: .heavy))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 6)
            }
            .frame(width: rect.width, height: rect.height)
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Palette.honey.opacity(canDrag ? 0.22 : 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .strokeBorder(Palette.honey.opacity(hovering ? 0.9 : 0), lineWidth: 3)
                    )
            )
            .contentShape(Rectangle())
            .position(x: rect.midX, y: rect.midY)
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .named("stage"))
                    .onChanged { v in
                        stage.supplyDrag = v.location
                        stage.hover = L.hit(v.location, plateCount: stage.plateCount)
                    }
                    .onEnded { v in stage.dropFromSupply(on: L.hit(v.location, plateCount: stage.plateCount)) },
                including: canDrag ? .all : .none
            )
        }
    }

    // MARK: 物品

    private func token(_ t: StoryToken, L: StageLayout, focused: Bool) -> some View {
        let p = stage.problem
        let siblings = stage.ordered(t.spot)
        let index = siblings.firstIndex { $0.id == t.id } ?? 0
        let dragging = stage.draggingID == t.id
        let inAway = t.spot == .away
        let size: CGFloat = {
            if dragging { return L.cell }
            if inAway { return L.sideRect(.away).map { L.awayCell($0) } ?? L.cell }
            if t.spot.isPlate { return L.plateCell(siblings.count) }
            return L.cell
        }()
        let moved = (t.origin == .a || t.origin == .b) && t.origin != t.spot && t.spot != .away && !t.spot.isPlate
        let originTint = t.origin == .a ? p.a.tint : (p.b ?? p.a).tint
        let canDrag = stage.canDrag(from: t.spot)
        return TokenView(item: p.item, size: size, focused: focused,
                         marker: moved ? originTint : nil, number: stage.counted[t.id])
            .opacity(inAway && !dragging ? 0.6 : 1)
            .opacity(t.spot == .supply ? 0 : 1)
            .scaleEffect(dragging ? 1.18 : 1)
            .position(dragging ? stage.dragPoint : L.slot(index, in: t.spot, count: siblings.count))
            .zIndex(dragging ? 10 : 1)
            .transition(.scale(scale: 0.2).combined(with: .opacity))
            .onTapGesture {
                if stage.comparing {
                    stage.countTap(t.id)
                } else if let i = t.spot.plateIndex {
                    stage.tapPlate(i)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .named("stage"))
                    .onChanged { v in stage.beginDrag(t.id, at: v.location, hit: L.hit(v.location, plateCount: stage.plateCount)) }
                    .onEnded { v in stage.drop(t.id, on: L.hit(v.location, plateCount: stage.plateCount)) },
                including: canDrag ? .all : .none
            )
    }

    // MARK: 比一比

    @ViewBuilder
    private func compareOverlay(L: StageLayout, focus: Set<Int>) -> some View {
        let p = stage.problem
        let a = stage.ordered(.a), b = stage.ordered(.b)
        // 两排一个对一个的连线
        let pairs: Bool = {
            if p.schema == .inverse { return true }
            switch p.ask {
            case .more, .less, .moved: return true
            default: return false
            }
        }()
        if pairs, p.lanes.count == 2, let ra = L.laneRect(.a), let rb = L.laneRect(.b) {
            Path { path in
                for i in 0..<min(a.count, b.count) {
                    let x = L.slotX(i)
                    path.move(to: CGPoint(x: x, y: ra.midY + L.cell * 0.5))
                    path.addLine(to: CGPoint(x: x, y: rb.midY - L.cell * 0.5))
                }
            }
            .stroke(Palette.inkSoft.opacity(0.35), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [2, 7]))
            .transition(.opacity)
        }
        // 把问到的那几个圈起来（盘子题由盘子自己发光）
        let points = p.usesPlates ? [] : stage.tokens.filter { focus.contains($0.id) }.compactMap { t -> CGPoint? in
            guard let i = stage.ordered(t.spot).firstIndex(where: { $0.id == t.id }) else { return nil }
            return L.slot(i, in: t.spot)
        }
        if let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
           let minY = points.map(\.y).min(), let maxY = points.map(\.y).max() {
            let r = CGRect(x: minX - L.cell * 0.62, y: minY - L.cell * 0.62,
                           width: maxX - minX + L.cell * 1.24, height: maxY - minY + L.cell * 1.24)
            RoundedRectangle(cornerRadius: L.cell * 0.5, style: .continuous)
                .strokeBorder(Palette.honey, style: StrokeStyle(lineWidth: 3.5, dash: [10, 7]))
                .background(RoundedRectangle(cornerRadius: L.cell * 0.5, style: .continuous).fill(Palette.honey.opacity(0.12)))
                .frame(width: r.width, height: r.height)
                .position(x: r.midX, y: r.midY)
                .transition(.opacity)
            Text(stage.focusLabel)
                .font(.kid(16, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Palette.honey, in: Capsule())
                .position(x: r.midX, y: r.minY - 4)
                .transition(.opacity)
        }
    }
}

/// 一个物品的样子：可能发光、带着"是谁给的"小圆点、带着数到第几个的数字。
struct TokenView: View {
    let item: StoryItem
    let size: CGFloat
    let focused: Bool
    let marker: Color?
    let number: Int?

    var body: some View {
        ZStack {
            if focused {
                Circle()
                    .fill(RadialGradient(colors: [Palette.honey.opacity(0.65), Palette.honey.opacity(0)],
                                         center: .center, startRadius: 0, endRadius: size * 0.62))
                    .frame(width: size * 1.3, height: size * 1.3)
            }
            ArtImage(name: item.image, fallback: item.emoji)
                .frame(width: size * 0.9, height: size * 0.9)
                .shadow(color: Color(hex: 0x6B4E2E).opacity(0.18), radius: 3, y: 2)
            if let marker {
                Circle()
                    .fill(marker)
                    .frame(width: size * 0.26, height: size * 0.26)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    .offset(x: size * 0.34, y: size * 0.32)
            }
            if let number {
                Text("\(number)")
                    .font(.kid(max(13, size * 0.34), weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: size * 0.5, height: size * 0.5)
                    .background(Palette.coral, in: Circle())
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    .offset(y: -size * 0.52)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
    }
}
