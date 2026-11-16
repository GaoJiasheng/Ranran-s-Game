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
    var comparing = false
    /// 点一点数一数：token id → 第几个
    private(set) var counted: [Int: Int] = [:]
    /// 不显示个数的地方（显示了就等于告诉答案）
    var hiddenBadges: Set<Spot> = []
    var visible = true

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
    }

    func clear() {
        tokens = []
        counted = [:]
        comparing = false
    }

    func ordered(_ spot: Spot) -> [StoryToken] {
        tokens.filter { $0.spot == spot }.sorted { $0.order < $1.order }
    }

    func count(_ spot: Spot) -> Int { tokens.reduce(0) { $0 + ($1.spot == spot ? 1 : 0) } }

    func counts() -> [Spot: Int] {
        [.a: count(.a), .b: count(.b), .away: count(.away)]
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
                    Sound.tap()
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
                Sound.tap()
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
        guard let forward else { return false }
        return spot == forward.from || spot == forward.to
    }

    /// 按故事方向拖：可以；反方向：只有这一步拖过去的那几个可以拿回来
    private func permits(_ route: StoryRoute, token id: Int?) -> Bool {
        guard let forward else { return false }
        if route == forward { return true }
        if route.from == forward.to, route.to == forward.from, let id { return beatTokens.contains(id) }
        return false
    }

    func beginDrag(_ id: Int, at p: CGPoint, hit: Spot?) {
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
        if target != .supply, target != .away, count(target) >= limit { return }
        if route == forward { beatTokens.insert(id) } else { beatTokens.remove(id) }
        withAnimation(.spring(duration: 0.45, bounce: 0.35)) { relocate(id, to: target) }
        if target == .supply { removeLater(id, animated: true) }
        Sound.tap()
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
        guard count(target) < limit else { return }
        withAnimation(.spring(duration: 0.4, bounce: 0.5)) { beatTokens.insert(add(target, origin: .supply)) }
        Sound.tap()
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
        }
        return Set(ids)
    }

    var focusLabel: String {
        switch problem.ask {
        case .more, .less: "多出来的"
        case .total:       "合起来"
        case .count:       "现在有的"
        case .moved:       "给过去的"
        }
    }

    func countTap(_ id: Int) {
        guard comparing, focus().contains(id), counted[id] == nil else { return }
        let n = counted.count + 1
        withAnimation(.spring(duration: 0.3, bounce: 0.6)) { counted[id] = n }
        Sound.step(min(n, 10))
    }

    func resetCounting() {
        withAnimation(.easeOut(duration: 0.2)) { counted = [:] }
    }
}

// MARK: - 布局

/// 所有位置都在一个坐标系里算，物品换地方时直接动画过去。
struct StageLayout {
    let size: CGSize
    let lanes: [Spot]
    let sides: [Spot]
    let capacity: Int

    let pad: CGFloat = 14

    /// 竖着有空间时，盘子和篮子放在下面一排，把横向的位置都留给物品
    var sidesBelow: Bool { !sides.isEmpty && size.height >= CGFloat(lanes.count) * 130 + 170 }
    var sideRowH: CGFloat { sidesBelow ? min(190, size.height * 0.36) : 0 }

    var labelW: CGFloat { min(120, size.width * 0.14) }
    var sideW: CGFloat { sides.isEmpty || sidesBelow ? 0 : min(150, size.width * 0.16) }
    var itemsX0: CGFloat { pad + labelW + 16 }
    var itemsX1: CGFloat { size.width - pad - (sideW > 0 ? sideW + 22 : 14) }

    private var lanesHeight: CGFloat { size.height - (sidesBelow ? sideRowH + 10 : 0) }
    var laneH: CGFloat {
        min(lanes.count == 1 ? 210 : 180, (lanesHeight - pad * 2) / CGFloat(max(lanes.count, 1)))
    }
    private var lanesTop: CGFloat { (lanesHeight - laneH * CGFloat(lanes.count)) / 2 }

    var cell: CGFloat {
        let n = max(capacity, 10)
        let groups = CGFloat((n - 1) / 5)
        return min(84, laneH * 0.5, (itemsX1 - itemsX0) / (CGFloat(n) + groups * 0.35))
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

    func slotX(_ index: Int) -> CGFloat {
        itemsX0 + cell * (CGFloat(index) + 0.5) + gap * CGFloat(index / 5)
    }

    func slot(_ index: Int, in spot: Spot) -> CGPoint {
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
        }
    }

    func awayCell(_ r: CGRect) -> CGFloat { min(cell * 0.8, 54, (r.width - 20) / 3) }

    func hit(_ p: CGPoint) -> Spot? {
        for s in sides {
            if let r = sideRect(s), r.insetBy(dx: -12, dy: -12).contains(p) { return s }
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
            let L = StageLayout(size: geo.size, lanes: p.lanes, sides: p.sides, capacity: stage.limit)
            let focus = stage.comparing ? stage.focus() : []
            ZStack(alignment: .topLeading) {
                ForEach(Array(p.lanes.enumerated()), id: \.element) { i, spot in
                    lane(spot, rect: L.laneRect(i), L: L)
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
            .coordinateSpace(name: "stage")
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
                            Text("\(n)")
                                .font(.kid(19, weight: .heavy))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                                .frame(minWidth: 32, minHeight: 32)
                                .padding(.horizontal, 4)
                                .background(cast.ink, in: Capsule())
                                .overlay(Capsule().strokeBorder(.white, lineWidth: 3))
                                .offset(x: 10, y: 4)
                                .animation(.spring(duration: 0.3), value: n)
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
                        Text("从篮子里拖\(p.item.name)过来")
                            .font(.kid(19, weight: .bold))
                            .foregroundStyle(Palette.inkSoft)
                    }
                }
                .position(x: (L.itemsX0 + L.itemsX1) / 2, y: rect.midY)
                .transition(.opacity)
            }
        }
    }

    // MARK: 盘子和篮子

    @ViewBuilder
    private func side(_ spot: Spot, rect: CGRect, L: StageLayout) -> some View {
        let p = stage.problem
        let hovering = stage.hover == spot
        if spot == .away {
            VStack(spacing: 0) {
                Text(p.awayLabel)
                    .font(.kid(18, weight: .heavy))
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.top, 14)
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
                        stage.hover = L.hit(v.location)
                    }
                    .onEnded { v in stage.dropFromSupply(on: L.hit(v.location)) },
                including: canDrag ? .all : .none
            )
        }
    }

    // MARK: 物品

    private func token(_ t: StoryToken, L: StageLayout, focused: Bool) -> some View {
        let p = stage.problem
        let index = stage.ordered(t.spot).firstIndex { $0.id == t.id } ?? 0
        let dragging = stage.draggingID == t.id
        let inAway = t.spot == .away
        let size = inAway && !dragging ? (L.sideRect(.away).map { L.awayCell($0) } ?? L.cell) : L.cell
        let moved = (t.origin == .a || t.origin == .b) && t.origin != t.spot && t.spot != .away
        let originTint = t.origin == .a ? p.a.tint : (p.b ?? p.a).tint
        let canDrag = stage.canDrag(from: t.spot)
        return TokenView(item: p.item, size: size, focused: focused,
                         marker: moved ? originTint : nil, number: stage.counted[t.id])
            .opacity(inAway && !dragging ? 0.6 : 1)
            .opacity(t.spot == .supply ? 0 : 1)
            .scaleEffect(dragging ? 1.18 : 1)
            .position(dragging ? stage.dragPoint : L.slot(index, in: t.spot))
            .zIndex(dragging ? 10 : 1)
            .transition(.scale(scale: 0.2).combined(with: .opacity))
            .onTapGesture { stage.countTap(t.id) }
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .named("stage"))
                    .onChanged { v in stage.beginDrag(t.id, at: v.location, hit: L.hit(v.location)) }
                    .onEnded { v in stage.drop(t.id, on: L.hit(v.location)) },
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
        // 把问到的那几个圈起来
        let points = stage.tokens.filter { focus.contains($0.id) }.compactMap { t -> CGPoint? in
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
