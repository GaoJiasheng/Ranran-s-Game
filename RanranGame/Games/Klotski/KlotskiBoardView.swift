import SwiftUI

// 华容道的木盘和木块（全部用 SwiftUI 画，不用图片；小伙伴的头像嵌在木块上）。
// 游戏页和教学页共用：只管画、管拖动，不管规则——一步走成了没有，由外面（玩的页面 / 教学页）决定。

/// 箭头：这块木块要往哪边滑几格
struct KlotskiArrow: Hashable {
    var piece: Int
    var dir: KlotskiDir
    var dist: Int
}

/// 木块的颜色（和缩略图共用）
enum KlotskiPaint {
    static func face(_ look: KlotskiLook, _ kind: KlotskiKind) -> (top: Color, bottom: Color) {
        switch look {
        case .bunny: return (Color(hex: 0xF9A99C), Color(hex: 0xEE7B6B))
        case .panda: return (Color(hex: 0xB4DAF0), Color(hex: 0x8EC5E8))
        case .owl: return (Color(hex: 0xF5D3A0), Color(hex: 0xE9B872))
        case .dragon: return (Color(hex: 0xB2D3B9), Color(hex: 0x8DB596))
        case let .plain(n):
            let tall: [(UInt32, UInt32)] = [(0xCFC3EE, 0xB7A6E0), (0xBFE3D3, 0x9CCDB6), (0xF8D2B0, 0xEFB88A)]
            let wide: [(UInt32, UInt32)] = [(0xF9CFCA, 0xF4B6B0), (0xB9DDF0, 0x92C7E6), (0xF4DDA8, 0xE9C57E)]
            let small: [(UInt32, UInt32)] = [(0xF6E1BC, 0xEBCB98), (0xF3D6B0, 0xE5BC87)]
            let list = kind == .tall ? tall : kind == .wide ? wide : small
            let c = list[n % list.count]
            return (Color(hex: c.0), Color(hex: c.1))
        }
    }
}

/// 木盘的尺寸：一格 c，木框宽 f，出口下面留一块地方让小兔跳出去
struct KlotskiMetrics {
    let c: CGFloat
    let f: CGFloat
    let trayW: CGFloat
    let trayH: CGFloat
    let doorH: CGFloat
    var totalH: CGFloat { trayH + doorH }

    init(_ size: CGSize) {
        let cols = CGFloat(KlotskiBoard.cols), rows = CGFloat(KlotskiBoard.rows)
        c = max(8, min(size.width / (cols + 0.64), size.height / (rows + 0.64 + 0.95)))
        f = c * 0.32
        trayW = cols * c + 2 * f
        trayH = rows * c + 2 * f
        doorH = c * 0.95
    }

    func origin(x: Int, y: Int) -> CGPoint { CGPoint(x: f + CGFloat(x) * c, y: f + CGFloat(y) * c) }

    func center(of p: KlotskiPiece) -> CGPoint {
        let o = origin(x: p.x, y: p.y)
        return CGPoint(x: o.x + CGFloat(p.kind.w) * c / 2, y: o.y + CGFloat(p.kind.h) * c / 2)
    }
}

struct KlotskiBoardView: View {
    let board: KlotskiBoard
    let looks: [KlotskiLook]
    /// 能不能拖木块
    var interactive = true
    /// 发光的木块（盘面里的序号）
    var glow: Set<Int> = []
    var arrows: [KlotskiArrow] = []
    /// 圈出来的格子（y * 4 + x）
    var rings: Set<Int> = []
    var doorGlow = false
    /// 小兔从出口跳出去
    var exiting = false
    /// 抖一抖：哪块木块、第几次（次数变了才抖）
    var nudge: (piece: Int, tick: Int)? = nil
    let onMove: (KlotskiMove) -> Void
    /// 点了一下（没拖）：点到的木块（空格是 nil）和格子
    var onTap: (_ piece: Int?, _ x: Int, _ y: Int) -> Void = { _, _, _ in }

    private struct DragInfo {
        enum Axis { case undecided, horizontal, vertical, none }
        var piece: Int
        var axis: Axis = .undecided
        var offset: CGSize = .zero
        var startCell: (x: Int, y: Int)
        /// 四个方向最多能滑几格
        var room: [KlotskiDir: Int]
    }

    @State private var drag: DragInfo?
    @State private var hop: CGFloat = 0
    @State private var gone = false
    @State private var wiggleX: CGFloat = 0

    var body: some View {
        GeometryReader { g in
            let m = KlotskiMetrics(g.size)
            ZStack(alignment: .topLeading) {
                tray(m)
                cellRings(m)
                ForEach(board.pieces.indices, id: \.self) { i in
                    block(i, m)
                }
                ForEach(arrows, id: \.self) { a in
                    arrow(a, m)
                }
                Color.clear
                    .frame(width: m.trayW, height: m.trayH)
                    .contentShape(Rectangle())
                    .gesture(dragGesture(m))
            }
            .frame(width: m.trayW, height: m.totalH, alignment: .topLeading)
            .position(x: g.size.width / 2, y: g.size.height / 2)
            .onChange(of: exiting) { _, now in
                if now { runExit(m) } else { hop = 0; gone = false }
            }
            .onChange(of: nudge?.tick) { _, _ in runWiggle(m) }
        }
    }

    // MARK: 木盘

    private func tray(_ m: KlotskiMetrics) -> some View {
        let c = m.c, f = m.f
        let slotX = f + c, slotW = 2 * c
        return ZStack(alignment: .topLeading) {
            // 木框，下面正中间留出口
            RoundedRectangle(cornerRadius: c * 0.36, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xEFCB93), Palette.wood, Color(hex: 0xCF9A5C)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: m.trayW, height: m.trayH)
                .overlay(
                    RoundedRectangle(cornerRadius: c * 0.36, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.45), lineWidth: c * 0.025)
                )
                .mask {
                    Path { p in
                        p.addRoundedRect(in: CGRect(x: 0, y: 0, width: m.trayW, height: m.trayH),
                                         cornerSize: CGSize(width: c * 0.36, height: c * 0.36), style: .continuous)
                        p.addRect(CGRect(x: slotX, y: f + 5 * c - 2, width: slotW, height: f + 2))
                    }
                    .fill(style: FillStyle(eoFill: true))
                }
                .shadow(color: Color(hex: 0x6B4E2E).opacity(0.28), radius: c * 0.16, y: c * 0.1)

            // 凹进去的盘底
            RoundedRectangle(cornerRadius: c * 0.14, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xB07B44), Color(hex: 0xC4925A)], startPoint: .top, endPoint: .bottom))
                .frame(width: 4 * c, height: 5 * c)
                .overlay(
                    RoundedRectangle(cornerRadius: c * 0.14, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.18), lineWidth: c * 0.03)
                )
                .offset(x: f, y: f)

            // 一格一格的浅坑，帮她看清格子
            ForEach(0..<20, id: \.self) { i in
                RoundedRectangle(cornerRadius: c * 0.12, style: .continuous)
                    .fill(Color.black.opacity(0.07))
                    .frame(width: c * 0.9, height: c * 0.9)
                    .offset(x: f + CGFloat(i % 4) * c + c * 0.05, y: f + CGFloat(i / 4) * c + c * 0.05)
            }

            // 出口：一条亮亮的路通到外面，外面有个小房子
            RoundedRectangle(cornerRadius: c * 0.1, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xC4925A), Palette.honey.opacity(doorGlow ? 0.95 : 0.55)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: slotW - c * 0.1, height: f + c * 0.2)
                .offset(x: slotX + c * 0.05, y: f + 5 * c - c * 0.12)
            Image(systemName: "house.fill")
                .font(.system(size: c * 0.5, weight: .bold))
                .foregroundStyle(Palette.coral)
                .frame(width: slotW, height: m.doorH)
                .offset(x: slotX, y: m.trayH + c * 0.02)
                .scaleEffect(doorGlow ? 1.12 : 1)
                .animation(doorGlow ? .easeInOut(duration: 0.7).repeatForever() : .default, value: doorGlow)
            if doorGlow {
                DoorPulse(c: c)
                    .frame(width: slotW, height: f + c * 0.5)
                    .offset(x: slotX, y: m.trayH - f - c * 0.3)
                    .allowsHitTesting(false)
            }
        }
    }

    private func cellRings(_ m: KlotskiMetrics) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(rings).sorted(), id: \.self) { i in
                let o = m.origin(x: i % 4, y: i / 4)
                RingMark(c: m.c)
                    .frame(width: m.c, height: m.c)
                    .offset(x: o.x, y: o.y)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: 木块

    private func block(_ i: Int, _ m: KlotskiMetrics) -> some View {
        let p = board.pieces[i]
        let o = m.origin(x: p.x, y: p.y)
        let dragging = drag?.piece == i
        let off = dragging ? drag!.offset : .zero
        let isBunny = p.kind == .big
        let look = looks.indices.contains(i) ? looks[i] : .plain(0)
        let extraY = isBunny ? hop : 0
        return KlotskiBlock(kind: p.kind, look: look, c: m.c, glowing: glow.contains(i), lifted: dragging)
            .frame(width: CGFloat(p.kind.w) * m.c, height: CGFloat(p.kind.h) * m.c)
            .offset(x: o.x + off.width + (nudge?.piece == i ? wiggleX : 0), y: o.y + off.height + extraY)
            .opacity(isBunny && gone ? 0 : 1)
            .zIndex(dragging ? 3 : (isBunny && exiting ? 2 : (glow.contains(i) ? 1 : 0)))
            .allowsHitTesting(false)
    }

    private func arrow(_ a: KlotskiArrow, _ m: KlotskiMetrics) -> some View {
        guard board.pieces.indices.contains(a.piece) else { return AnyView(EmptyView()) }
        let p = board.pieces[a.piece]
        let center = m.center(of: p)
        let half = (a.dir.dx != 0 ? CGFloat(p.kind.w) : CGFloat(p.kind.h)) * m.c / 2
        let length = max(CGFloat(a.dist) * m.c, m.c * 0.9)
        let mid = half + CGFloat(a.dist) * m.c / 2
        let pos = CGPoint(x: center.x + CGFloat(a.dir.dx) * mid, y: center.y + CGFloat(a.dir.dy) * mid)
        let angle: Double = a.dir == .right ? 0 : a.dir == .down ? 90 : a.dir == .left ? 180 : -90
        return AnyView(
            ArrowMark(dir: a.dir, c: m.c)
                .frame(width: length, height: m.c * 0.56)
                .rotationEffect(.degrees(angle))
                .position(pos)
                .zIndex(5)
                .allowsHitTesting(false)
        )
    }

    // MARK: 拖动

    private func cell(_ pt: CGPoint, _ m: KlotskiMetrics) -> (x: Int, y: Int)? {
        let x = Int(floor((pt.x - m.f) / m.c)), y = Int(floor((pt.y - m.f) / m.c))
        guard x >= 0, x < KlotskiBoard.cols, y >= 0, y < KlotskiBoard.rows else { return nil }
        return (x, y)
    }

    private func dragGesture(_ m: KlotskiMetrics) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if drag == nil {
                    guard !exiting, let c = cell(v.startLocation, m), let i = board.pieceAt(x: c.x, y: c.y) else { return }
                    var room: [KlotskiDir: Int] = [:]
                    for d in KlotskiDir.allCases { room[d] = board.maxSlide(i, d) }
                    drag = DragInfo(piece: i, startCell: c, room: room)
                    if interactive { Sound.pick() }
                }
                guard interactive, var d = drag else { return }
                let t = v.translation
                if d.axis == .undecided, max(abs(t.width), abs(t.height)) > 6 {
                    let h = (d.room[.left] ?? 0) + (d.room[.right] ?? 0) > 0
                    let vv = (d.room[.up] ?? 0) + (d.room[.down] ?? 0) > 0
                    if h && vv { d.axis = abs(t.width) >= abs(t.height) ? .horizontal : .vertical }
                    else if h { d.axis = .horizontal }
                    else if vv { d.axis = .vertical }
                    else { d.axis = .none }
                }
                switch d.axis {
                case .horizontal:
                    d.offset = CGSize(width: min(max(t.width, -CGFloat(d.room[.left] ?? 0) * m.c), CGFloat(d.room[.right] ?? 0) * m.c), height: 0)
                case .vertical:
                    d.offset = CGSize(width: 0, height: min(max(t.height, -CGFloat(d.room[.up] ?? 0) * m.c), CGFloat(d.room[.down] ?? 0) * m.c))
                default:
                    d.offset = .zero
                }
                drag = d
            }
            .onEnded { v in
                guard let d = drag else { return }
                let moved = hypot(v.translation.width, v.translation.height)
                var move: KlotskiMove?
                if interactive, moved >= 8 {
                    // 松手：拖过了 0.35 格就算滑了一格（再多就再算一格）
                    func steps(_ len: CGFloat) -> Int {
                        let a = abs(len) / m.c
                        return Int(floor(a)) + (a - floor(a) >= 0.35 ? 1 : 0)
                    }
                    switch d.axis {
                    case .horizontal:
                        let dir: KlotskiDir = d.offset.width < 0 ? .left : .right
                        let n = min(steps(d.offset.width), d.room[dir] ?? 0)
                        if n > 0 { move = KlotskiMove(piece: d.piece, dir: dir, dist: n) }
                    case .vertical:
                        let dir: KlotskiDir = d.offset.height < 0 ? .up : .down
                        let n = min(steps(d.offset.height), d.room[dir] ?? 0)
                        if n > 0 { move = KlotskiMove(piece: d.piece, dir: dir, dist: n) }
                    default:
                        break
                    }
                }
                let tapped = moved < 8
                if let move { onMove(move) }
                withAnimation(.spring(duration: 0.26, bounce: 0.25)) { drag = nil }
                if tapped { onTap(d.piece, d.startCell.x, d.startCell.y) }
                else if move == nil, interactive { Sound.drop() }
            }
            .simultaneously(with: SpatialTapGesture().onEnded { v in
                // 点在空格上（拖动手势没有选中木块）
                guard drag == nil, let c = cell(v.location, m), board.pieceAt(x: c.x, y: c.y) == nil else { return }
                onTap(nil, c.x, c.y)
            })
    }

    // MARK: 动画

    private func runExit(_ m: KlotskiMetrics) {
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.22)) { hop = -m.c * 0.35 }
            try? await Task.sleep(for: .milliseconds(240))
            withAnimation(.easeIn(duration: 0.5)) { hop = m.c * 2.35 }
            try? await Task.sleep(for: .milliseconds(420))
            withAnimation(.easeOut(duration: 0.2)) { gone = true }
        }
    }

    private func runWiggle(_ m: KlotskiMetrics) {
        Task { @MainActor in
            for dx in [9.0, -9.0, 6.0, -6.0, 0.0] {
                withAnimation(.easeInOut(duration: 0.06)) { wiggleX = CGFloat(dx) * m.c / 100 * 4 }
                try? await Task.sleep(for: .milliseconds(60))
            }
        }
    }
}

// MARK: - 一块木块

struct KlotskiBlock: View {
    let kind: KlotskiKind
    let look: KlotskiLook
    let c: CGFloat
    var glowing = false
    var lifted = false

    @State private var pulse = false

    var body: some View {
        let w = CGFloat(kind.w) * c, h = CGFloat(kind.h) * c
        let gap = c * 0.045
        let colors = KlotskiPaint.face(look, kind)
        let radius = c * 0.2
        let thick = c * 0.06
        ZStack {
            // 木块的厚度
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(colors.bottom)
                .brightness(-0.16)
                .frame(width: w - gap * 2, height: h - gap * 2)
                .offset(y: thick)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(colors: [colors.top, colors.bottom], startPoint: .top, endPoint: .bottom))
                .frame(width: w - gap * 2, height: h - gap * 2)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.75), .white.opacity(0.05)],
                                                     startPoint: .top, endPoint: .bottom), lineWidth: c * 0.035)
                )
                .overlay(face(w: w, h: h))
            if glowing {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Palette.honey, lineWidth: c * 0.09)
                    .frame(width: w - gap * 2, height: h - gap * 2)
                    .shadow(color: Palette.honey.opacity(0.9), radius: c * 0.14)
                    .opacity(pulse ? 1 : 0.35)
                    .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
                    .onAppear { pulse = true }
            }
        }
        .frame(width: w, height: h)
        .scaleEffect(lifted ? 1.04 : 1)
        .shadow(color: .black.opacity(lifted ? 0.32 : 0.2), radius: lifted ? c * 0.16 : c * 0.07, y: lifted ? c * 0.1 : c * 0.04)
        .animation(.spring(duration: 0.2), value: lifted)
    }

    @ViewBuilder
    private func face(w: CGFloat, h: CGFloat) -> some View {
        if let avatar = look.avatar {
            let size = min(w, h) * (kind == .big ? 0.72 : 0.7)
            Avatar(image: avatar, fallback: look.emoji, tint: .white, size: size)
                .shadow(color: .black.opacity(0.12), radius: c * 0.03, y: c * 0.02)
        } else {
            // 普通木块：里面一圈浅浅的边，像木头的纹路
            RoundedRectangle(cornerRadius: c * 0.12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.4), lineWidth: c * 0.03)
                .padding(c * 0.14)
        }
    }
}

// MARK: - 标记

private struct ArrowMark: View {
    let dir: KlotskiDir
    let c: CGFloat
    @State private var bob = false

    var body: some View {
        ArrowShape()
            .fill(Palette.coral)
            .overlay(ArrowShape().stroke(Color.white, lineWidth: c * 0.04))
            .shadow(color: .black.opacity(0.25), radius: c * 0.05, y: c * 0.03)
            .offset(x: bob ? c * 0.08 : -c * 0.04)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: bob)
            .onAppear { bob = true }
    }
}

/// 向右的粗箭头（外面再转到要的方向）
private struct ArrowShape: Shape {
    func path(in r: CGRect) -> Path {
        let head = min(r.height * 0.95, r.width * 0.6)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY - r.height * 0.17))
        p.addLine(to: CGPoint(x: r.maxX - head, y: r.midY - r.height * 0.17))
        p.addLine(to: CGPoint(x: r.maxX - head, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX - head, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - head, y: r.midY + r.height * 0.17))
        p.addLine(to: CGPoint(x: r.minX, y: r.midY + r.height * 0.17))
        p.closeSubpath()
        return p
    }
}

private struct RingMark: View {
    let c: CGFloat
    @State private var on = false

    var body: some View {
        RoundedRectangle(cornerRadius: c * 0.16, style: .continuous)
            .fill(Palette.coral.opacity(0.14))
            .overlay(
                RoundedRectangle(cornerRadius: c * 0.16, style: .continuous)
                    .strokeBorder(Palette.coral, style: StrokeStyle(lineWidth: c * 0.05, dash: [c * 0.14, c * 0.1]))
            )
            .padding(c * 0.06)
            .scaleEffect(on ? 1.0 : 0.93)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}

private struct DoorPulse: View {
    let c: CGFloat
    @State private var on = false

    var body: some View {
        RoundedRectangle(cornerRadius: c * 0.2, style: .continuous)
            .strokeBorder(Palette.honey, lineWidth: c * 0.08)
            .shadow(color: Palette.honey, radius: c * 0.14)
            .opacity(on ? 1 : 0.3)
            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}

// MARK: - 小图

/// 关卡格子里的小图：木盘 + 彩色的圆角方块（小兔是珊瑚色）
struct KlotskiThumb: View {
    let layout: String

    var body: some View {
        GeometryReader { g in
            let board = KlotskiBoard(layout: layout)
            let side = min(g.size.width, g.size.height)
            let c = side / 5.5
            let f = c * 0.22
            let w = 4 * c + 2 * f, h = 5 * c + 2 * f
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: c * 0.3, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0xEFCB93), Palette.woodDeep.opacity(0.85)], startPoint: .top, endPoint: .bottom))
                    .frame(width: w, height: h)
                RoundedRectangle(cornerRadius: c * 0.12, style: .continuous)
                    .fill(Color(hex: 0xB98A52))
                    .frame(width: 4 * c, height: 5 * c)
                    .offset(x: f, y: f)
                // 出口
                Rectangle()
                    .fill(Palette.cream)
                    .frame(width: 2 * c - c * 0.1, height: f + 1)
                    .offset(x: f + c + c * 0.05, y: f + 5 * c - 0.5)
                if let board {
                    let looks = KlotskiLooks.assign(board)
                    ForEach(board.pieces.indices, id: \.self) { i in
                        let p = board.pieces[i]
                        let colors = KlotskiPaint.face(looks[i], p.kind)
                        RoundedRectangle(cornerRadius: c * 0.16, style: .continuous)
                            .fill(LinearGradient(colors: [colors.top, colors.bottom], startPoint: .top, endPoint: .bottom))
                            .overlay(RoundedRectangle(cornerRadius: c * 0.16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.5), lineWidth: max(0.5, c * 0.03)))
                            .frame(width: CGFloat(p.kind.w) * c - c * 0.08, height: CGFloat(p.kind.h) * c - c * 0.08)
                            .offset(x: f + CGFloat(p.x) * c + c * 0.04, y: f + CGFloat(p.y) * c + c * 0.04)
                    }
                }
            }
            .frame(width: w, height: h, alignment: .topLeading)
            .position(x: g.size.width / 2, y: g.size.height / 2)
        }
    }
}
