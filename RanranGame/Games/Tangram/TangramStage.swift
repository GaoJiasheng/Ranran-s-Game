import SwiftUI

/// 七巧板的颜色和样子
enum TangramStyle {
    static let accent = Color(hex: 0x3FA39B)
    static let shadow = Palette.ink.opacity(0.86)

    static func color(_ kind: TangramKind, _ instance: Int) -> Color {
        switch kind {
        case .large: instance == 0 ? Palette.coral : Palette.sky
        case .medium: Palette.honey
        case .square: Color(hex: 0xF29FB4)
        case .parallelogram: Color(hex: 0x6CC3B9)
        case .small: instance == 0 ? Palette.sage : Palette.lilac
        }
    }

    /// 一组板子按种类数第几块（配颜色）
    static func instances(_ kinds: [TangramKind]) -> [Int] {
        var seen: [TangramKind: Int] = [:]
        return kinds.map { k in
            defer { seen[k, default: 0] += 1 }
            return seen[k, default: 0]
        }
    }
}

/// 凸多边形，角稍微圆一点
struct TangramPolygon: Shape {
    var points: [CGPoint]
    var radius: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard points.count >= 3 else { return p }
        if radius <= 0 {
            p.addLines(points)
            p.closeSubpath()
            return p
        }
        let n = points.count
        let mid = CGPoint(x: (points[0].x + points[n - 1].x) / 2, y: (points[0].y + points[n - 1].y) / 2)
        p.move(to: mid)
        for i in 0..<n {
            p.addArc(tangent1End: points[i], tangent2End: points[(i + 1) % n], radius: radius)
        }
        p.closeSubpath()
        return p
    }

    /// 往里缩 d 点（凸多边形；板子之间留一条细缝）
    static func inset(_ pts: [CGPoint], by d: CGFloat) -> [CGPoint] {
        let n = pts.count
        guard n >= 3, d > 0 else { return pts }
        // 统一方向：面积为正（画面坐标 y 朝下时是顺时针）
        var area: CGFloat = 0
        for i in 0..<n { area += pts[i].x * pts[(i + 1) % n].y - pts[(i + 1) % n].x * pts[i].y }
        let s: CGFloat = area > 0 ? 1 : -1
        func line(_ i: Int) -> (CGPoint, CGPoint) {
            let a = pts[i], b = pts[(i + 1) % n]
            let dx = b.x - a.x, dy = b.y - a.y
            let len = max(hypot(dx, dy), 0.001)
            // 往里的法线
            let nx = -dy / len * s, ny = dx / len * s
            return (CGPoint(x: a.x + nx * d, y: a.y + ny * d), CGPoint(x: b.x + nx * d, y: b.y + ny * d))
        }
        return (0..<n).map { i in
            let (a1, a2) = line((i - 1 + n) % n), (b1, b2) = line(i)
            let d1 = CGPoint(x: a2.x - a1.x, y: a2.y - a1.y), d2 = CGPoint(x: b2.x - b1.x, y: b2.y - b1.y)
            let den = d1.x * d2.y - d1.y * d2.x
            guard abs(den) > 1e-6 else { return pts[i] }
            let t = ((b1.x - a1.x) * d2.y - (b1.y - a1.y) * d2.x) / den
            return CGPoint(x: a1.x + d1.x * t, y: a1.y + d1.y * t)
        }
    }
}

/// 一块板子：按原形画、绕重心转和翻（这样转、翻、从托盘拿起来变大都有动画）
struct TangramPieceView: View {
    let kind: TangramKind
    let instance: Int
    /// 画的时候 1 个单位多少点
    let unit: CGFloat
    var turns = 0
    var mirror = false
    var lifted = false
    var glow = false
    var dimmed = false

    var body: some View {
        let shape = kind.canonical
        let g = TangramGeo.centroid(shape)
        let box = unit * 5
        let pts = shape.map { CGPoint(x: box / 2 + CGFloat($0.x - g.x) * unit, y: box / 2 - CGFloat($0.y - g.y) * unit) }
        let gap = max(1, unit * 0.025)
        let r = max(2, unit * 0.07)
        let inner = TangramPolygon.inset(pts, by: gap + r * 0.4)
        let color = TangramStyle.color(kind, instance)
        return ZStack {
            TangramPolygon(points: inner, radius: r)
                .fill(LinearGradient(colors: [TangramStyle.blend(color, .white, 0.28), color],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            TangramPolygon(points: TangramPolygon.inset(inner, by: max(1.5, unit * 0.05)), radius: r)
                .stroke(.white.opacity(0.35), lineWidth: max(1, unit * 0.03))
            if glow {
                TangramPolygon(points: inner, radius: r)
                    .stroke(.white, lineWidth: max(3, unit * 0.08))
            }
        }
        .frame(width: box, height: box)
        .rotationEffect(.degrees(-45 * Double(turns)))
        .scaleEffect(x: mirror ? -1 : 1)
        .shadow(color: Color(hex: 0x6B4E2E).opacity(lifted ? 0.32 : 0.16), radius: lifted ? 12 : 3, y: lifted ? 10 : 2)
        .opacity(dimmed ? 0.45 : 1)
    }
}

/// 七巧板的板子 + 托盘，带手势。闯关和教学共用。
struct TangramStage: View {
    @Bindable var board: TangramBoard
    var accent: Color = TangramStyle.accent

    @State private var pulse = false

    var body: some View {
        GeometryReader { geo in
            let L = board.layout
            ZStack(alignment: .topLeading) {
                // 底板和托盘
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Palette.paper)
                    .shadow(color: Color(hex: 0x6B4E2E).opacity(0.10), radius: 18, y: 8)
                    .frame(width: L.boardRect.width, height: L.boardRect.height)
                    .offset(x: L.boardRect.minX, y: L.boardRect.minY)
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(accent.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(accent.opacity(0.35), style: StrokeStyle(lineWidth: 2.5, dash: [8, 7])))
                    .frame(width: L.trayRect.width, height: L.trayRect.height)
                    .offset(x: L.trayRect.minX, y: L.trayRect.minY)

                silhouette(L)
                ForEach(Array(board.fixed.enumerated()), id: \.offset) { i, p in
                    staticPiece(p, instance: TangramStyle.instances(board.fixed.map(\.kind))[i], L: L)
                }
                guides(L)
                ForEach(board.order, id: \.self) { id in
                    if let p = board.pieces.first(where: { $0.id == id }) { pieceView(p, L: L) }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .contentShape(Rectangle())
            .coordinateSpace(name: "tangramStage")
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("tangramStage"))
                    .onChanged { board.touchChanged($0.location) }
                    .onEnded { board.touchEnded($0.location) }
            )
            .onAppear { board.relayout(geo.size) }
            .onChange(of: geo.size) { _, s in board.relayout(s) }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    // MARK: 影子

    private func screenPoints(_ pose: TangramPose, _ L: TangramLayout) -> [CGPoint] { pose.vertices.map(L.screen) }

    @ViewBuilder
    private func silhouette(_ L: TangramLayout) -> some View {
        if board.showSolution {
            ForEach(Array(board.target.enumerated()), id: \.offset) { i, p in
                staticPiece(p, instance: TangramStyle.instances(board.target.map(\.kind))[i], L: L)
            }
        } else {
            let polys = board.target.map { screenPoints($0, L) }
            Path { path in
                for poly in polys {
                    path.addLines(poly)
                    path.closeSubpath()
                }
            }
            .fill(board.solved ? accent.opacity(0.25) : TangramStyle.shadow)
            .animation(.easeInOut(duration: 0.4), value: board.solved)
            if board.showOutlines || board.peeking {
                Path { path in
                    for poly in polys {
                        path.addLines(poly)
                        path.closeSubpath()
                    }
                }
                .stroke(Palette.cream.opacity(0.85), style: StrokeStyle(lineWidth: max(2, L.unit * 0.045), lineJoin: .round))
                .transition(.opacity)
            }
        }
    }

    /// 摆好的、不能动的板子（教学里先帮她放好的几块、演示）
    private func staticPiece(_ p: TangramPose, instance: Int, L: TangramLayout) -> some View {
        let q = p.normalized()
        let c = L.screen(q.centroid)
        return TangramPieceView(kind: q.kind, instance: instance, unit: L.unit,
                                turns: q.flipped ? -q.rotation : q.rotation, mirror: q.flipped)
            .position(c)
            .allowsHitTesting(false)
    }

    // MARK: 提示、答案

    @ViewBuilder
    private func guides(_ L: TangramLayout) -> some View {
        ForEach(Array(board.reveal.enumerated()), id: \.offset) { _, g in ghostShape(g, L) }
        if let g = board.ghost { ghostShape(g, L) }
    }

    private func ghostShape(_ pose: TangramPose, _ L: TangramLayout) -> some View {
        let pts = screenPoints(pose, L)
        return ZStack {
            TangramPolygon(points: pts).fill(Palette.honey.opacity(pulse ? 0.55 : 0.22))
            TangramPolygon(points: pts)
                .stroke(Palette.honey, style: StrokeStyle(lineWidth: 4, lineJoin: .round, dash: [10, 7]))
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    // MARK: 板子

    private func pieceView(_ p: TangramBoard.Piece, L: TangramLayout) -> some View {
        let (c, u) = board.placement(p)
        let dragging = board.dragging == p.id
        let hinted = !p.onBoard && board.hintKind == p.kind && !dragging
        let picked = board.picked == p.id
        let popped = board.popped == p.id
        return TangramPieceView(kind: p.kind, instance: p.instance, unit: L.unit, turns: p.turns, mirror: p.mirror,
                                lifted: dragging, glow: picked || (board.solved && pulse))
            .scaleEffect(u / max(L.unit, 1) * (dragging ? 1.04 : 1) * (popped ? 1.08 : 1) * (hinted && pulse ? 1.12 : 1))
            .position(c)
            .zIndex(dragging ? 10 : 1)
            .allowsHitTesting(false)
            .animation(.spring(duration: 0.25, bounce: 0.5), value: popped)
            .animation(.easeInOut(duration: 0.8), value: pulse)
            .accessibilityLabel(p.kind.name)
    }
}

extension TangramStyle {
    /// 两个颜色按比例混合（iOS 17 没有 Color.mix）
    static func blend(_ c: Color, _ other: Color, _ t: Double) -> Color {
        let a = UIColor(c), b = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let k = CGFloat(t)
        return Color(red: Double(r1 + (r2 - r1) * k), green: Double(g1 + (g2 - g1) * k), blue: Double(b1 + (b2 - b1) * k),
                     opacity: Double(a1 + (a2 - a1) * k))
    }
}
