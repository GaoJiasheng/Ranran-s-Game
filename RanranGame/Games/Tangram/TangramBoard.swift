import SwiftUI
import Observation

/// 七巧板的一块"棋盘"：上面是影子，旁边是托盘里的板子。闯关和教学共用。
/// 坐标：影子和板子用七巧板单位（大正方形边长 4，y 朝上，见 TangramGeometry.swift）；画面用点（y 朝下）。
/// 怎么换算由 TangramLayout 管，画面尺寸一变就重新算。
@Observable
@MainActor
final class TangramBoard {
    struct Piece: Identifiable, Equatable {
        let id: Int
        let kind: TangramKind
        /// 同一种板子里的第几块（配颜色用）
        let instance: Int
        /// 画出来转了几个 45°（顺时针点一下 -1，累计，不取余，这样动画不会倒着转）
        var turns: Int
        /// 画出来左右翻了（只有平行四边形）
        var mirror: Bool
        /// 在板子上的位置（重心，七巧板单位）；在托盘里是 nil
        var center: TangramPoint?

        var onBoard: Bool { center != nil }

        /// 逻辑上的摆法：画面 = 翻(mirror) · 转(turns) · 原形 = 转(rotation) · 翻(flipped) · 原形
        var rotation: Int { ((mirror ? -turns : turns) % 8 + 8) % 8 }

        func pose(at c: TangramPoint) -> TangramPose {
            var p = TangramPose(kind: kind, rotation: rotation, flipped: mirror)
            p.offset = c - p.centroid
            return p
        }

        var pose: TangramPose? { center.map(pose(at:)) }
    }

    /// 一次操作之后告诉外面（教学判题、闯关检查拼好）
    enum Event {
        case dropped(Int, fits: Bool)
        case returned(Int)
        case turned(Int)
        case flipped(Int)
    }

    // MARK: 局面

    private(set) var target: [TangramPose] = []
    private(set) var fixed: [TangramPose] = []
    private(set) var pieces: [Piece] = []
    /// 画的先后（后面的在上面）
    private(set) var order: [Int] = []
    /// 影子里画出每一块的分界线
    var showOutlines = false
    /// 「看一眼」：暂时画出分界线
    var peeking = false
    /// 演示：影子直接画成彩色
    var showSolution = false

    // MARK: 操作中的状态

    var interactive = true
    /// 点板子是回答问题（教学的 pick 题），不是转
    var pickMode = false
    private(set) var dragging: Int?
    private(set) var dragSnapped = false
    /// 刚吸进去的那块，"啵"一下
    private(set) var popped: Int?
    /// 提示：一块板子该放的地方（虚线）
    var ghost: TangramPose?
    /// 教学错两次：亮出全部答案
    var reveal: [TangramPose] = []
    /// 提示的时候，托盘里该用的那种板子闪一闪
    var hintKind: TangramKind?
    /// 教学 pick 题点对的那块
    var picked: Int?
    /// 拼好了
    private(set) var solved = false

    var onEvent: ((Event) -> Void)?
    var onPick: ((TangramKind, Int) -> Void)?

    private(set) var layout = TangramLayout()
    private var history: [[Piece]] = []
    private var targetPolys: [[TangramPoint]] = []
    private var targetAnchors: [TangramPoint] = []

    // 拖动
    private var touchStart: CGPoint?
    private var touchTime = Date()
    private var touched: Int?
    private var grab = CGSize.zero
    private var moved = false
    private(set) var dragCenter: TangramPoint?
    private(set) var dragScreen: CGPoint = .zero

    init() {}

    /// 换一个局面：target 影子，fixed 已经摆好的，tray 托盘里的板子（种类、朝向）
    func load(target: [TangramPose], fixed: [TangramPose] = [], tray: [TangramPose], outlines: Bool, show: Bool = false) {
        self.target = target
        self.fixed = fixed
        showOutlines = outlines
        showSolution = show
        var counts: [TangramKind: Int] = [:]
        for f in fixed { counts[f.kind, default: 0] += 1 }
        pieces = tray.enumerated().map { i, t in
            let n = counts[t.kind, default: 0]
            counts[t.kind, default: 0] += 1
            let mirror = t.kind.chiral && t.flipped
            return Piece(id: i, kind: t.kind, instance: n, turns: mirror ? -t.rotation : t.rotation, mirror: mirror, center: nil)
        }
        order = pieces.map(\.id)
        targetPolys = target.map(\.vertices)
        targetAnchors = TangramSnapper.anchors(targetPolys + fixed.map(\.vertices))
        history = []
        ghost = nil
        reveal = []
        hintKind = nil
        picked = nil
        solved = false
        dragging = nil
        peeking = false
        relayout(layout.size)
    }

    // MARK: 布局

    func relayout(_ size: CGSize) {
        guard size.width > 10, size.height > 10 else { return }
        let polys = targetPolys + fixed.map(\.vertices)
        layout = TangramLayout(size: size, bounds: TangramGeo.bounds(polys.isEmpty ? [[.init(0, 0), .init(4, 4)]] : polys),
                               trayCount: pieces.count)
    }

    /// 一块板子现在画在哪里、画多大
    func placement(_ p: Piece) -> (center: CGPoint, unit: CGFloat) {
        if p.id == dragging {
            if let c = dragCenter { return (layout.screen(c), layout.unit) }
            return (dragScreen, layout.unit)
        }
        if let c = p.center { return (layout.screen(c), layout.unit) }
        let slot = layout.slots.indices.contains(p.id) ? layout.slots[p.id] : .zero
        return (CGPoint(x: slot.midX, y: slot.midY), layout.trayUnit)
    }

    /// 画面上这块板子的轮廓（点）
    func screenPolygon(_ p: Piece) -> [CGPoint] {
        let (c, u) = placement(p)
        let shape = TangramPose.shape(p.kind, rotation: p.rotation, flipped: p.mirror)
        let g = TangramGeo.centroid(shape)
        return shape.map { CGPoint(x: c.x + ($0.x - g.x) * u, y: c.y - ($0.y - g.y) * u) }
    }

    var boardPoses: [TangramPose] { pieces.compactMap(\.pose) }
    var trayEmpty: Bool { pieces.allSatisfy(\.onBoard) }
    var hasMirrorPiece: Bool { pieces.contains { $0.kind.chiral } }
    var canUndo: Bool { !history.isEmpty }

    // MARK: 手势

    func touchChanged(_ location: CGPoint) {
        guard interactive, !solved else { return }
        if touchStart == nil {
            touchStart = location
            touchTime = Date()
            moved = false
            touched = hit(location)
            if let id = touched, let p = pieces.first(where: { $0.id == id }) {
                let (c, u) = placement(p)
                let k = layout.unit / max(u, 1)
                grab = CGSize(width: (c.x - location.x) * k, height: (c.y - location.y) * k)
            }
            return
        }
        guard let id = touched, !pickMode else { return }
        let start = touchStart ?? location
        if !moved, hypot(location.x - start.x, location.y - start.y) < 8 { return }
        if !moved {
            moved = true
            beginDrag(id)
        }
        dragTo(location)
    }

    func touchEnded(_ location: CGPoint) {
        defer {
            touchStart = nil
            touched = nil
            moved = false
        }
        // 拖到一半被锁住了（比如教学里刚好做对）：也要放下来
        if let id = dragging, !interactive || solved {
            drop(id)
            return
        }
        guard interactive, !solved, let id = touched else { return }
        if pickMode {
            if let p = pieces.first(where: { $0.id == id }) { onPick?(p.kind, id) }
            return
        }
        if moved {
            drop(id)
        } else if Date().timeIntervalSince(touchTime) < 0.6 {
            turn(id)
        }
    }

    /// 手指下面最上面的一块
    private func hit(_ pt: CGPoint) -> Int? {
        let tp = TangramPoint(Double(pt.x), Double(pt.y))
        var best: (Int, Double)?
        for id in order.reversed() {
            guard let p = pieces.first(where: { $0.id == id }) else { continue }
            let poly = screenPolygon(p).map { TangramPoint(Double($0.x), Double($0.y)) }
            let d = TangramGeo.distance(poly, tp)
            if d == 0 { return id }
            if d < 16, best == nil || d < best!.1 { best = (id, d) }
        }
        return best?.0
    }

    private func beginDrag(_ id: Int) {
        guard let i = index(id) else { return }
        history.append(pieces)
        if history.count > 60 { history.removeFirst() }
        dragging = id
        dragSnapped = false
        dragCenter = pieces[i].center
        order.removeAll { $0 == id }
        order.append(id)
        ghostCheck()
        Sound.pick()
    }

    private func dragTo(_ location: CGPoint) {
        guard let id = dragging, let i = index(id) else { return }
        let screen = CGPoint(x: location.x + grab.width, y: location.y + grab.height)
        dragScreen = screen
        let c = layout.figure(screen)
        guard layout.boardRect.insetBy(dx: -30, dy: -30).contains(screen) else {
            withAnimation(.spring(duration: 0.2)) {
                dragCenter = nil
                dragSnapped = false
            }
            return
        }
        let free = pieces[i].pose(at: c)
        let others = pieces.filter { $0.id != id }.compactMap(\.pose).map(\.vertices) + fixed.map(\.vertices)
        let anchors = targetAnchors + TangramSnapper.anchors(pieces.filter { $0.id != id }.compactMap(\.pose).map(\.vertices))
        if let s = TangramSnapper.snap(free, anchors: anchors, target: targetPolys, others: others,
                                       fitRadius: 0.55, plainRadius: 0.3) {
            let sc = s.pose.centroid
            if !dragSnapped || dragCenter.map({ $0.distance(sc) > 1e-6 }) ?? true {
                withAnimation(.spring(duration: 0.15, bounce: 0.3)) { dragCenter = sc }
                if !dragSnapped { Sound.key() }
            }
            dragSnapped = true
        } else {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { dragCenter = c }
            dragSnapped = false
        }
    }

    private func drop(_ id: Int) {
        guard let i = index(id) else { return }
        let inBoard = layout.boardRect.insetBy(dx: -24, dy: -24).contains(dragScreen) && dragCenter != nil
        let center = dragCenter
        let snapped = dragSnapped
        withAnimation(.spring(duration: 0.35, bounce: 0.35)) {
            dragging = nil
            dragCenter = nil
            if inBoard, let c = center {
                pieces[i].center = layout.clamp(c)
            } else {
                pieces[i].center = nil
            }
        }
        if inBoard, let pose = pieces[i].pose {
            let fits = snapped && fitsHere(pose, id: id)
            if snapped {
                Sound.pop()
                pop(id)
            } else {
                Sound.drop()
            }
            onEvent?(.dropped(id, fits: fits))
        } else {
            Sound.tap()
            onEvent?(.returned(id))
        }
        afterChange()
    }

    /// 这块放在这里合适（在影子里、不压别的板子）
    func fitsHere(_ pose: TangramPose, id: Int) -> Bool {
        let others = pieces.filter { $0.id != id }.compactMap(\.pose).map(\.vertices) + fixed.map(\.vertices)
        return TangramChecker.fits(pose.vertices, target: targetPolys, others: others)
    }

    /// 压在别的板子上
    func overlapsOthers(_ pose: TangramPose, id: Int) -> Bool {
        let others = pieces.filter { $0.id != id }.compactMap(\.pose).map(\.vertices) + fixed.map(\.vertices)
        return others.contains { TangramGeo.overlap(pose.vertices, $0) > TangramChecker.eps }
    }

    /// 和影子有没有重叠的地方
    func touchesTarget(_ pose: TangramPose) -> Bool {
        TangramChecker.insideArea(pose.vertices, target: targetPolys) > TangramChecker.eps
    }

    /// 转一转、翻一翻能不能在附近找到合适的位置（教学提醒"先转好"用）
    func wouldFitTurned(_ id: Int) -> Bool {
        guard let p = pieces.first(where: { $0.id == id }), let pose = p.pose else { return false }
        let others = pieces.filter { $0.id != id }.compactMap(\.pose).map(\.vertices) + fixed.map(\.vertices)
        for f in p.kind.chiral ? [false, true] : [false] {
            for r in 0..<8 {
                var q = TangramPose(kind: p.kind, rotation: r, flipped: f)
                q.offset = pose.centroid - q.centroid
                if let s = TangramSnapper.snap(q, anchors: targetAnchors, target: targetPolys, others: others,
                                               fitRadius: 1.2, plainRadius: 0), s.fits { return true }
            }
        }
        return false
    }

    /// 放回托盘（教学里放错了弹回去）
    func sendBack(_ id: Int, after delay: Double = 0.35) {
        Task {
            try? await Task.sleep(for: .seconds(delay))
            guard let i = index(id) else { return }
            withAnimation(.spring(duration: 0.45, bounce: 0.3)) { pieces[i].center = nil }
        }
    }

    /// 点一下：顺时针转 45°（在板子上的话，转完再就近对齐一下）
    func turn(_ id: Int) {
        guard let i = index(id) else { return }
        history.append(pieces)
        Sound.tap()
        withAnimation(.spring(duration: 0.3, bounce: 0.3)) {
            pieces[i].turns += pieces[i].mirror ? 1 : -1
            if let c = pieces[i].center {
                let pose = pieces[i].pose(at: c)
                let others = pieces.filter { $0.id != id }.compactMap(\.pose).map(\.vertices) + fixed.map(\.vertices)
                let anchors = targetAnchors + TangramSnapper.anchors(others)
                if let s = TangramSnapper.snap(pose, anchors: anchors, target: targetPolys, others: others,
                                               fitRadius: 0.45, plainRadius: 0.3) {
                    pieces[i].center = s.pose.centroid
                }
            }
        }
        onEvent?(.turned(id))
        afterChange()
    }

    /// 翻面（平行四边形）。id 不给就翻第一块能翻的。
    func flip(_ id: Int? = nil) {
        guard interactive, !solved,
              let i = id.flatMap(index) ?? pieces.firstIndex(where: { $0.kind.chiral }) else { return }
        history.append(pieces)
        Sound.sparkle()
        withAnimation(.spring(duration: 0.45, bounce: 0.2)) {
            pieces[i].mirror.toggle()
            if let c = pieces[i].center {
                let pose = pieces[i].pose(at: c)
                let others = pieces.filter { $0.id != pieces[i].id }.compactMap(\.pose).map(\.vertices) + fixed.map(\.vertices)
                if let s = TangramSnapper.snap(pose, anchors: targetAnchors + TangramSnapper.anchors(others),
                                               target: targetPolys, others: others, fitRadius: 0.45, plainRadius: 0.3) {
                    pieces[i].center = s.pose.centroid
                }
            }
        }
        onEvent?(.flipped(pieces[i].id))
        afterChange()
    }

    func undo() {
        guard interactive, !solved, let last = history.popLast() else { return }
        Sound.undo()
        withAnimation(.spring(duration: 0.4, bounce: 0.25)) { pieces = last }
        afterChange()
    }

    /// 全部放回托盘
    func reset() {
        guard interactive, !solved, pieces.contains(where: \.onBoard) else { return }
        history.append(pieces)
        Sound.undo()
        withAnimation(.spring(duration: 0.5, bounce: 0.25)) {
            for i in pieces.indices { pieces[i].center = nil }
        }
        afterChange()
    }

    private func pop(_ id: Int) {
        popped = id
        Task {
            try? await Task.sleep(for: .milliseconds(220))
            if popped == id { popped = nil }
        }
    }

    private func index(_ id: Int) -> Int? { pieces.firstIndex { $0.id == id } }

    private func afterChange() {
        ghostCheck()
        if trayEmpty, TangramChecker.solved(boardPoses, target: target, fixed: fixed) {
            solved = true
            ghost = nil
            hintKind = nil
        }
    }

    /// 提示的那个位置已经放好了，就收起来
    private func ghostCheck() {
        guard let g = ghost else { return }
        if boardPoses.contains(where: { $0.sameSpot(g) }) {
            withAnimation(.easeOut(duration: 0.3)) {
                ghost = nil
                hintKind = nil
            }
        }
    }

    // MARK: 提示

    /// 闯关的提示：一块还没放对的板子该放在哪（大块优先）。没有了返回 false。
    @discardableResult
    func showHint() -> Bool {
        let open = TangramChecker.openSlots(boardPoses, target: target)
        guard let first = open.first else { return false }
        Sound.hint()
        withAnimation(.spring(duration: 0.4)) {
            ghost = target[first]
            hintKind = target[first].kind
        }
        return true
    }

    // MARK: 调试

    #if DEBUG
    /// 调试截图用：把前 n 块按参考拼法摆好（大块先摆）
    func debugPlace(_ n: Int) {
        var refs = target.filter { t in !fixed.contains { $0.sameSpot(t) } }
        var placedCount = 0
        for i in pieces.indices where placedCount < n {
            guard let j = refs.firstIndex(where: { $0.kind == pieces[i].kind }) else { continue }
            let r = refs.remove(at: j)
            pieces[i].mirror = r.flipped && r.kind.chiral
            pieces[i].turns = pieces[i].mirror ? -r.rotation : r.rotation
            pieces[i].center = r.centroid
            placedCount += 1
        }
        afterChange()
    }
    #endif

    /// 教学里点对了 / 放好了之后锁住，不再接受操作
    func lock() { interactive = false }
}

/// 画面怎么排：影子在哪、多大，托盘在哪、每一格多大。
struct TangramLayout: Equatable {
    var size: CGSize = .zero
    var boardRect: CGRect = .zero
    var trayRect: CGRect = .zero
    /// 板子上 1 个七巧板单位 = 多少点
    var unit: CGFloat = 40
    /// 七巧板坐标 (0,0) 在画面上的位置
    var origin: CGPoint = .zero
    /// 托盘里的板子画多大
    var trayUnit: CGFloat = 20
    var slots: [CGRect] = []
    /// 托盘在旁边（横着排）还是在下面
    var trayAside = true
    /// 板子上能放的范围（七巧板单位）
    var world: (min: TangramPoint, max: TangramPoint) = (.init(0, 0), .init(0, 0))

    static func == (a: Self, b: Self) -> Bool {
        a.size == b.size && a.boardRect == b.boardRect && a.unit == b.unit && a.origin == b.origin && a.slots == b.slots
    }

    init() {}

    init(size: CGSize, bounds: (min: TangramPoint, max: TangramPoint), trayCount: Int) {
        self.size = size
        let gap: CGFloat = 16
        trayAside = size.width > size.height * 1.05
        if trayAside {
            let w = min(max(size.width * 0.31, 200), 400)
            trayRect = CGRect(x: size.width - w, y: 0, width: w, height: size.height)
            boardRect = CGRect(x: 0, y: 0, width: size.width - w - gap, height: size.height)
        } else {
            let h = min(max(size.height * 0.3, 150), 300)
            trayRect = CGRect(x: 0, y: size.height - h, width: size.width, height: h)
            boardRect = CGRect(x: 0, y: 0, width: size.width, height: size.height - h - gap)
        }
        // 影子放在中间，四周留一点地方给还没对齐的板子
        let margin = 0.9
        let w = bounds.max.x - bounds.min.x, h = bounds.max.y - bounds.min.y
        let pad: CGFloat = 18
        unit = min((boardRect.width - pad * 2) / CGFloat(w + margin * 2),
                   (boardRect.height - pad * 2) / CGFloat(h + margin * 2), 120)
        unit = max(unit, 12)
        let cx = (bounds.min.x + bounds.max.x) / 2, cy = (bounds.min.y + bounds.max.y) / 2
        origin = CGPoint(x: boardRect.midX - CGFloat(cx) * unit, y: boardRect.midY + CGFloat(cy) * unit)
        world = (figure(CGPoint(x: boardRect.minX + pad, y: boardRect.maxY - pad)),
                 figure(CGPoint(x: boardRect.maxX - pad, y: boardRect.minY + pad)))
        // 托盘的格子
        let n = max(trayCount, 1)
        let cols: Int, rows: Int
        if trayAside {
            cols = n > 4 ? 2 : 1
            rows = (n + cols - 1) / cols
        } else {
            cols = n > 4 ? 4 : n
            rows = (n + cols - 1) / cols
        }
        let inner = trayRect.insetBy(dx: 12, dy: 12)
        let sw = inner.width / CGFloat(cols), sh = inner.height / CGFloat(rows)
        slots = (0..<trayCount).map { i in
            let c = i % cols, r = i / cols
            return CGRect(x: inner.minX + CGFloat(c) * sw, y: inner.minY + CGFloat(r) * sh, width: sw, height: sh)
        }
        // 托盘里的板子尽量大一点，好让小手按得住：最长的边（大三角形的斜边 4 个单位）竖过来时会稍微探出格子一点，不碍事
        trayUnit = min(unit, min(sw, sh) / 3.5)
    }

    func screen(_ p: TangramPoint) -> CGPoint {
        CGPoint(x: origin.x + CGFloat(p.x) * unit, y: origin.y - CGFloat(p.y) * unit)
    }

    func figure(_ s: CGPoint) -> TangramPoint {
        TangramPoint(Double((s.x - origin.x) / unit), Double((origin.y - s.y) / unit))
    }

    /// 没对齐的板子放在板子范围里面
    func clamp(_ c: TangramPoint) -> TangramPoint {
        TangramPoint(min(max(c.x, world.min.x), world.max.x), min(max(c.y, world.min.y), world.max.y))
    }
}
