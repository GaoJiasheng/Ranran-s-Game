import SwiftUI

/// 棋盘坐标换算。
struct BoardLayout {
    let side: CGFloat
    static let n = Board.size

    var margin: CGFloat { side * 0.058 }
    var cell: CGFloat { (side - margin * 2) / CGFloat(Self.n - 1) }

    func center(_ p: Point) -> CGPoint {
        CGPoint(x: margin + CGFloat(p.x) * cell, y: margin + CGFloat(p.y) * cell)
    }

    /// 手指位置 → 最近的交叉点（手指在棋盘外太远就返回 nil）
    func point(at loc: CGPoint) -> Point? {
        let fx = (loc.x - margin) / cell, fy = (loc.y - margin) / cell
        guard fx > -0.8, fy > -0.8, fx < CGFloat(Self.n) - 0.2, fy < CGFloat(Self.n) - 0.2 else { return nil }
        let x = min(max(Int(fx.rounded()), 0), Self.n - 1)
        let y = min(max(Int(fy.rounded()), 0), Self.n - 1)
        return Point(x: x, y: y)
    }
}

struct BoardView: View {
    let game: GomokuGame

    @State private var hover: Point?
    @State private var winProgress: CGFloat = 0

    private struct PlacedStone: Identifiable {
        let id: String
        let point: Point
        let stone: Stone
    }

    private var placedStones: [PlacedStone] {
        game.moves.enumerated().map { i, p in
            PlacedStone(id: "\(game.round)-\(i)-\(p.x)-\(p.y)", point: p, stone: game.color(ofMove: i))
        }
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let layout = BoardLayout(side: side)

            ZStack(alignment: .topLeading) {
                BoardSurface(layout: layout)

                if let hover, game.canHumanMove, game.board[hover] == nil {
                    Crosshair(layout: layout, point: hover)
                }

                ForEach(game.threats, id: \.self) { p in
                    PulseRing(color: Palette.coral, dashed: true)
                        .frame(width: layout.cell * 0.95, height: layout.cell * 0.95)
                        .position(layout.center(p))
                        .transition(.scale.combined(with: .opacity))
                }

                ForEach(placedStones) { placed in
                    let p = placed.point
                    StoneView(stone: placed.stone, diameter: layout.cell * 0.9)
                        .scaleEffect(game.winLine.contains(p) && winProgress >= 1 ? 1.08 : 1)
                        .animation(.spring(duration: 0.5, bounce: 0.5).repeatCount(3, autoreverses: true), value: winProgress)
                        .position(layout.center(p))
                        .transition(.asymmetric(
                            insertion: .scale(scale: 1.35).combined(with: .opacity),
                            removal: .scale(scale: 0.7).combined(with: .opacity)))
                }

                if let last = game.lastMove, game.winLine.isEmpty {
                    Circle()
                        .fill(Palette.coral)
                        .frame(width: layout.cell * 0.2, height: layout.cell * 0.2)
                        .shadow(color: Palette.coral.opacity(0.6), radius: 4)
                        .position(layout.center(last))
                        .transition(.scale)
                        .id("last-\(last.x)-\(last.y)")
                }

                if let hint = game.hint {
                    ZStack {
                        StoneView(stone: game.turn, diameter: layout.cell * 0.9).opacity(0.45)
                        PulseRing(color: Palette.sage, dashed: false)
                            .frame(width: layout.cell * 1.15, height: layout.cell * 1.15)
                    }
                    .position(layout.center(hint))
                    .transition(.scale.combined(with: .opacity))
                }

                if let hover, game.canHumanMove, game.board[hover] == nil {
                    StoneView(stone: game.turn, diameter: layout.cell * 0.9, lifted: true)
                        .opacity(0.65)
                        .position(layout.center(hover))
                        .allowsHitTesting(false)
                }

                if game.winLine.count >= 2 {
                    WinStroke(from: layout.center(game.winLine.first!), to: layout.center(game.winLine.last!),
                              progress: winProgress, width: layout.cell * 0.16)
                }
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        guard game.canHumanMove else { hover = nil; return }
                        let p = layout.point(at: v.location)
                        if p != hover {
                            withAnimation(.spring(duration: 0.18)) { hover = p }
                        }
                    }
                    .onEnded { v in
                        defer { hover = nil }
                        guard let p = layout.point(at: v.location) else { return }
                        game.humanPlay(p)
                    }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: game.winLine) { _, line in
            winProgress = 0
            guard !line.isEmpty else { return }
            withAnimation(.easeInOut(duration: 0.7).delay(0.25)) { winProgress = 1 }
        }
    }
}

/// 木质棋盘：带厚度的边、木纹、网格和星位。
struct BoardSurface: View {
    let layout: BoardLayout

    var body: some View {
        let side = layout.side
        let radius = side * 0.03
        ZStack {
            // 棋盘侧面（厚度）
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(colors: [Palette.woodDeep, Color(hex: 0x95653A)], startPoint: .top, endPoint: .bottom))
                .offset(y: side * 0.016)

            // 木纹面
            ArtImage(name: "board_wood", fallback: "", contentMode: .fill)
                .saturation(0.82)
                .background(LinearGradient(colors: [Color(hex: 0xEDC88E), Palette.wood], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RadialGradient(colors: [.white.opacity(0.22), .clear, Color(hex: 0x8A5A2B).opacity(0.18)],
                                   center: .init(x: 0.3, y: 0.25), startRadius: 0, endRadius: side * 0.95)
                )
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.05)],
                                                     startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
                )

            Canvas { ctx, _ in
                let n = BoardLayout.n
                let ink = Color(hex: 0x3A2614)
                let lineW = max(1, layout.cell * 0.028)
                var grid = Path()
                for i in 0..<n {
                    let a = layout.center(Point(x: i, y: 0)), b = layout.center(Point(x: i, y: n - 1))
                    grid.move(to: a); grid.addLine(to: b)
                    let c = layout.center(Point(x: 0, y: i)), d = layout.center(Point(x: n - 1, y: i))
                    grid.move(to: c); grid.addLine(to: d)
                }
                ctx.stroke(grid, with: .color(ink.opacity(0.62)), lineWidth: lineW)

                let tl = layout.center(Point(x: 0, y: 0)), br = layout.center(Point(x: n - 1, y: n - 1))
                ctx.stroke(Path(CGRect(x: tl.x, y: tl.y, width: br.x - tl.x, height: br.y - tl.y)),
                           with: .color(ink.opacity(0.75)), lineWidth: lineW * 2)

                for (x, y) in [(3, 3), (11, 3), (7, 7), (3, 11), (11, 11)] {
                    let c = layout.center(Point(x: x, y: y))
                    let r = layout.cell * 0.1
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                             with: .color(ink.opacity(0.8)))
                }
            }
        }
        .frame(width: side, height: side)
        .shadow(color: Color(hex: 0x7A4E22).opacity(0.28), radius: side * 0.04, y: side * 0.03)
    }
}

/// 瞄准时的十字线，帮助小朋友看清落在哪一行哪一列。
private struct Crosshair: View {
    let layout: BoardLayout
    let point: Point

    var body: some View {
        let n = BoardLayout.n
        Path { p in
            p.move(to: layout.center(Point(x: point.x, y: 0)))
            p.addLine(to: layout.center(Point(x: point.x, y: n - 1)))
            p.move(to: layout.center(Point(x: 0, y: point.y)))
            p.addLine(to: layout.center(Point(x: n - 1, y: point.y)))
        }
        .stroke(Palette.coral.opacity(0.55), style: StrokeStyle(lineWidth: max(2, layout.cell * 0.06), lineCap: .round))
        .allowsHitTesting(false)
    }
}

/// 连成五子后划过的发光线。
struct WinStroke: View {
    let from: CGPoint
    let to: CGPoint
    let progress: CGFloat
    let width: CGFloat

    var body: some View {
        let path = Path { p in p.move(to: from); p.addLine(to: to) }
        ZStack {
            path.trim(from: 0, to: progress)
                .stroke(Palette.honey.opacity(0.6), style: StrokeStyle(lineWidth: width * 2.2, lineCap: .round))
                .blur(radius: width * 0.8)
            path.trim(from: 0, to: progress)
                .stroke(LinearGradient(colors: [Palette.coral, Palette.honey], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: width, lineCap: .round))
                .shadow(color: Palette.coral.opacity(0.8), radius: width * 0.6)
        }
        .allowsHitTesting(false)
    }
}

/// 一圈一圈"呼吸"的光环，用于提示和警告。
struct PulseRing: View {
    let color: Color
    var dashed = false
    @State private var pulse = false

    var body: some View {
        Circle()
            .strokeBorder(color, style: StrokeStyle(lineWidth: 4, dash: dashed ? [6, 5] : []))
            .background(Circle().fill(color.opacity(0.15)))
            .scaleEffect(pulse ? 1.08 : 0.88)
            .opacity(pulse ? 1 : 0.55)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
            .allowsHitTesting(false)
    }
}
