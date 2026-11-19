import SwiftUI

/// 象棋棋盘上的坐标换算。自己这一方在下面（flipped = 黑方在下）。
struct XLayout {
    let cell: CGFloat
    let flipped: Bool
    var margin: CGFloat { cell * 0.8 }
    var width: CGFloat { cell * 8 + margin * 2 }
    var height: CGFloat { cell * 9 + margin * 2 }

    init(size: CGSize, flipped: Bool) {
        cell = min(size.width / 9.6, size.height / 10.6)
        self.flipped = flipped
    }

    func center(_ s: XSquare) -> CGPoint {
        let col = flipped ? 8 - s.x : s.x
        let row = flipped ? s.y : 9 - s.y
        return CGPoint(x: margin + CGFloat(col) * cell, y: margin + CGFloat(row) * cell)
    }

    func square(at p: CGPoint) -> XSquare? {
        let col = Int(((p.x - margin) / cell).rounded()), row = Int(((p.y - margin) / cell).rounded())
        guard col >= 0, col < 9, row >= 0, row < 10 else { return nil }
        return flipped ? XSquare(8 - col, row) : XSquare(col, 9 - row)
    }
}

/// 棋盘上额外的标记：教学里用得最多
enum XMark: Hashable {
    /// 发光提示"点这里 / 走到这里"
    case glow(XSquare)
    /// 一个彩色圆圈（比如圈出正在将军的子）
    case ring(XSquare, warn: Bool)
    case arrow(XSquare, XSquare)
    /// 写在格子旁边的小字母 A / B / C
    case label(XSquare, String)
    /// 把一方的九宫涂上颜色
    case palace(XSide)
    case river
    /// 一个不能走的点（打叉）
    case cross(XSquare)
}

extension XMark {
    var under: Bool {
        switch self {
        case .glow, .cross: true
        default: false
        }
    }
}

/// 棋盘要显示的全部内容。对局和教学都用它。
struct XBoardState {
    var board: XBoard
    var ids: [Int]
    var flipped = false
    var selected: XSquare?
    /// 选中的子能去的地方
    var targets: [XSquare] = []
    var lastMove: XMove?
    var checkedKing: XSquare?
    var hint: XMove?
    var marks: [XMark] = []
    var checkFlash = 0
}

struct XiangqiBoardView: View {
    let state: XBoardState
    let onTap: (XSquare) -> Void

    @State private var dragFrom: XSquare?

    private struct Placed: Identifiable {
        let id: Int
        let square: XSquare
        let piece: XPiece
    }

    var body: some View {
        GeometryReader { geo in
            let l = XLayout(size: geo.size, flipped: state.flipped)
            ZStack(alignment: .topLeading) {
                XiangqiSurface(layout: l, marks: state.marks)

                if let m = state.lastMove {
                    // 从哪里走来：一个空心小圈
                    Circle()
                        .strokeBorder(Palette.honey, lineWidth: max(2, l.cell * 0.07))
                        .background(Circle().fill(Palette.honey.opacity(0.25)))
                        .frame(width: l.cell * 0.42, height: l.cell * 0.42)
                        .position(l.center(m.from))
                }

                ForEach(placed, id: \.id) { p in
                    XiangqiPieceView(piece: p.piece, diameter: l.cell * 0.9,
                                     lifted: p.square == state.selected)
                        .position(l.center(p.square))
                        .zIndex(p.square == state.selected ? 2 : 1)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }

                if let m = state.lastMove {
                    // 走到了哪里：棋子外面一圈亮黄
                    Circle()
                        .strokeBorder(Palette.honey, lineWidth: max(3, l.cell * 0.075))
                        .frame(width: l.cell * 1.04, height: l.cell * 1.04)
                        .position(l.center(m.to))
                        .zIndex(1.5)
                        .allowsHitTesting(false)
                }

                if let k = state.checkedKing {
                    PulseRing(color: Palette.coral)
                        .frame(width: l.cell * 1.2, height: l.cell * 1.2)
                        .position(l.center(k))
                        .zIndex(3)
                }

                ForEach(state.targets, id: \.self) { t in
                    Group {
                        if state.board[t] != nil {
                            Circle()
                                .strokeBorder(Palette.coral, lineWidth: max(3, l.cell * 0.08))
                                .frame(width: l.cell * 1.0, height: l.cell * 1.0)
                        } else {
                            Circle()
                                .fill(Palette.sage)
                                .frame(width: l.cell * 0.3, height: l.cell * 0.3)
                                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                                .shadow(color: Palette.sage.opacity(0.6), radius: 4)
                        }
                    }
                    .position(l.center(t))
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(4)
                }

                ForEach(Array(state.marks.enumerated()), id: \.offset) { _, mark in
                    // 提示点、叉画在棋子底下（走到那里以后不挡字），圈、箭头、字母在上面
                    markView(mark, l).zIndex(mark.under ? 0.5 : 5)
                }

                if let h = state.hint {
                    XArrow(from: l.center(h.from), to: l.center(h.to), width: l.cell * 0.16, color: Palette.sage)
                        .zIndex(6)
                }
            }
            .frame(width: l.width, height: l.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if dragFrom == nil { dragFrom = l.square(at: v.startLocation) }
                    }
                    .onEnded { v in
                        let start = dragFrom ?? l.square(at: v.startLocation)
                        dragFrom = nil
                        guard let end = l.square(at: v.location) else { return }
                        // 拖着走：先选起点再点终点；只是点一下就是一次点击
                        if let start, start != end, hypot(v.translation.width, v.translation.height) > l.cell * 0.5 {
                            if state.selected != start { onTap(start) }
                            onTap(end)
                        } else {
                            onTap(end)
                        }
                    }
            )
            .frame(width: geo.size.width, height: geo.size.height)
            .keyframeAnimator(initialValue: CGFloat(0), trigger: state.checkFlash) { v, shake in
                v.offset(x: shake)
            } keyframes: { _ in
                KeyframeTrack {
                    SpringKeyframe(6, duration: 0.06)
                    SpringKeyframe(-6, duration: 0.08)
                    SpringKeyframe(0, duration: 0.2)
                }
            }
        }
    }

    private var placed: [Placed] {
        state.board.cells.indices.compactMap { i in
            guard let p = XPiece(code: state.board.cells[i]) else { return nil }
            let id = state.ids.indices.contains(i) && state.ids[i] != 0 ? state.ids[i] : 1000 + i
            return Placed(id: id, square: XSquare(i % 9, i / 9), piece: p)
        }
    }

    @ViewBuilder
    private func markView(_ mark: XMark, _ l: XLayout) -> some View {
        switch mark {
        case let .glow(s):
            TargetBeacon()
                .frame(width: l.cell * 0.95, height: l.cell * 0.95)
                .position(l.center(s))
        case let .ring(s, warn):
            Circle()
                .strokeBorder(warn ? Palette.coral : Palette.sky,
                              style: StrokeStyle(lineWidth: max(3, l.cell * 0.08), dash: warn ? [6, 5] : []))
                .frame(width: l.cell * 1.08, height: l.cell * 1.08)
                .position(l.center(s))
        case let .arrow(a, b):
            XArrow(from: l.center(a), to: l.center(b), width: l.cell * 0.14, color: Palette.honey)
        case let .label(s, text):
            Text(text)
                .font(.kid(l.cell * 0.34, weight: .black))
                .foregroundStyle(.white)
                .frame(width: l.cell * 0.5, height: l.cell * 0.5)
                .background(Palette.coral, in: Circle())
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .position(l.center(s))
                .offset(x: l.cell * 0.38, y: -l.cell * 0.38)
        case let .cross(s):
            Image(systemName: "xmark")
                .font(.system(size: l.cell * 0.42, weight: .black))
                .foregroundStyle(Palette.coral)
                .position(l.center(s))
        case .palace, .river:
            EmptyView() // 画在棋盘底下
        }
    }
}

// MARK: - 棋子

/// 一枚木头象棋子：木纹圆片 + 一圈刻线 + 字。红方红字，黑方墨字。
struct XiangqiPieceView: View {
    let piece: XPiece
    let diameter: CGFloat
    var lifted = false

    static let redInk = Color(hex: 0xC23A2C)
    static let blackInk = Color(hex: 0x22303A)

    var body: some View {
        let d = diameter
        let ink = piece.side == .red ? Self.redInk : Self.blackInk
        ZStack {
            // 侧面厚度
            Circle()
                .fill(Color(hex: 0xB07A43))
                .offset(y: d * 0.05)
            ArtImage(name: "piece_xiangqi", fallback: "", contentMode: .fit)
                .background(
                    Circle().fill(RadialGradient(colors: [Color(hex: 0xF8E2B6), Color(hex: 0xE9C68D), Color(hex: 0xD4A766)],
                                                 center: .init(x: 0.38, y: 0.32), startRadius: 0, endRadius: d * 0.62))
                )
                .clipShape(Circle())
            Circle()
                .strokeBorder(ink.opacity(0.85), lineWidth: max(1.2, d * 0.035))
                .padding(d * 0.085)
            Text(piece.glyph)
                .font(.system(size: d * 0.54, weight: .heavy, design: .serif))
                .foregroundStyle(ink)
                .shadow(color: .white.opacity(0.5), radius: 0, y: d * 0.012)
        }
        .frame(width: d, height: d)
        .shadow(color: .black.opacity(0.32),
                radius: lifted ? d * 0.16 : d * 0.05,
                x: lifted ? d * 0.05 : d * 0.02,
                y: lifted ? d * 0.2 : d * 0.06)
        .scaleEffect(lifted ? 1.1 : 1)
        .accessibilityLabel(piece.side.name + piece.glyph)
    }
}

// MARK: - 棋盘

struct XiangqiSurface: View {
    let layout: XLayout
    var marks: [XMark] = []

    var body: some View {
        let l = layout
        let r = l.cell * 0.3
        ZStack {
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(LinearGradient(colors: [Palette.woodDeep, Color(hex: 0x95653A)], startPoint: .top, endPoint: .bottom))
                .frame(width: l.width, height: l.height)
                .offset(y: l.cell * 0.14)
            ArtImage(name: "board_wood", fallback: "", contentMode: .fill)
                .saturation(0.82)
                .background(LinearGradient(colors: [Color(hex: 0xEDC88E), Palette.wood], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RadialGradient(colors: [.white.opacity(0.22), .clear, Color(hex: 0x8A5A2B).opacity(0.18)],
                                   center: .init(x: 0.3, y: 0.25), startRadius: 0, endRadius: l.height)
                )
                .frame(width: l.width, height: l.height)
                .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))

            Canvas { ctx, _ in
                let ink = Color(hex: 0x3A2614)
                let w = max(1, l.cell * 0.03)
                func c(_ x: Int, _ y: Int) -> CGPoint { l.center(XSquare(x, y)) }

                // 教学里涂颜色的九宫 / 河界
                for mark in marks {
                    if case let .palace(side) = mark {
                        let ys = side == .red ? (0, 2) : (7, 9)
                        let a = c(3, ys.0), b = c(5, ys.1)
                        let rect = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
                        ctx.fill(Path(rect.insetBy(dx: -l.cell * 0.2, dy: -l.cell * 0.2)), with: .color(Palette.honey.opacity(0.35)))
                    }
                    if case .river = mark {
                        let a = c(0, 4), b = c(8, 5)
                        let rect = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
                        ctx.fill(Path(rect), with: .color(Palette.sky.opacity(0.4)))
                    }
                }

                var grid = Path()
                for y in 0..<10 { grid.move(to: c(0, y)); grid.addLine(to: c(8, y)) }
                for x in 0..<9 {
                    if x == 0 || x == 8 {
                        grid.move(to: c(x, 0)); grid.addLine(to: c(x, 9))
                    } else {
                        // 河界那里竖线断开
                        grid.move(to: c(x, 0)); grid.addLine(to: c(x, 4))
                        grid.move(to: c(x, 5)); grid.addLine(to: c(x, 9))
                    }
                }
                // 九宫的斜线
                for (y0, y1) in [(0, 2), (7, 9)] {
                    grid.move(to: c(3, y0)); grid.addLine(to: c(5, y1))
                    grid.move(to: c(5, y0)); grid.addLine(to: c(3, y1))
                }
                ctx.stroke(grid, with: .color(ink.opacity(0.66)), lineWidth: w)

                // 外框
                let tl = c(0, 9), br = c(8, 0)
                let frame = CGRect(x: min(tl.x, br.x), y: min(tl.y, br.y), width: abs(br.x - tl.x), height: abs(br.y - tl.y))
                ctx.stroke(Path(frame.insetBy(dx: -l.cell * 0.12, dy: -l.cell * 0.12)), with: .color(ink.opacity(0.75)), lineWidth: w * 2.2)

                // 炮位、兵位的小折角
                let spots: [(Int, Int)] = [(1, 2), (7, 2), (1, 7), (7, 7)]
                    + [0, 2, 4, 6, 8].flatMap { [($0, 3), ($0, 6)] }
                let g = l.cell * 0.1, len = l.cell * 0.2
                var marks = Path()
                for (x, y) in spots {
                    let p = c(x, y)
                    for sx in [-1.0, 1.0] {
                        if (x == 0 && sx < 0) || (x == 8 && sx > 0) { continue }
                        for sy in [-1.0, 1.0] {
                            let o = CGPoint(x: p.x + sx * g, y: p.y + sy * g)
                            marks.move(to: CGPoint(x: o.x + sx * len, y: o.y))
                            marks.addLine(to: o)
                            marks.addLine(to: CGPoint(x: o.x, y: o.y + sy * len))
                        }
                    }
                }
                ctx.stroke(marks, with: .color(ink.opacity(0.6)), lineWidth: w)
            }

            // 楚河 汉界
            let mid = (l.center(XSquare(0, 4)).y + l.center(XSquare(0, 5)).y) / 2
            HStack {
                Text("楚 河")
                Spacer()
                Text("汉 界")
            }
            .font(.system(size: l.cell * 0.5, weight: .bold, design: .serif))
            .foregroundStyle(Color(hex: 0x3A2614).opacity(0.55))
            .padding(.horizontal, l.cell * 1.4)
            .frame(width: l.width)
            .position(x: l.width / 2, y: mid)
        }
        .frame(width: l.width, height: l.height)
        .shadow(color: Color(hex: 0x7A4E22).opacity(0.28), radius: l.cell * 0.4, y: l.cell * 0.3)
    }
}

/// 一根带箭头的粗线
struct XArrow: View {
    let from: CGPoint
    let to: CGPoint
    let width: CGFloat
    let color: Color

    var body: some View {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let head = width * 2.6
        let end = CGPoint(x: to.x - cos(angle) * head * 0.7, y: to.y - sin(angle) * head * 0.7)
        ZStack {
            Path { p in p.move(to: from); p.addLine(to: end) }
                .stroke(color.opacity(0.85), style: StrokeStyle(lineWidth: width, lineCap: .round))
            Path { p in
                p.move(to: to)
                p.addLine(to: CGPoint(x: to.x - cos(angle - 0.5) * head, y: to.y - sin(angle - 0.5) * head))
                p.addLine(to: CGPoint(x: to.x - cos(angle + 0.5) * head, y: to.y - sin(angle + 0.5) * head))
                p.closeSubpath()
            }
            .fill(color)
        }
        .shadow(color: color.opacity(0.5), radius: 4)
        .allowsHitTesting(false)
    }
}
