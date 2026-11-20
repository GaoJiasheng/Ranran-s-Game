import SwiftUI

/// 围棋棋盘上的标记（教学用得多）
enum GoMark: Hashable {
    case glow(Int)
    case cross(Int)
    case ring(Int)
    /// 小蓝点：标出一口气
    case dot(Int)
    case label(Int, String)
}

/// 棋盘要画的东西。对局、教学、复盘共用。
struct GoBoardState {
    var board: GoBoard
    var lastMove: Int?
    var hint: Int?
    var marks: [GoMark] = []
    /// 终局数子：每个点归谁；死子画成半透明
    var owner: [Int8]? = nil
    var dead: Set<Int> = []
    /// 能不能按住瞄准（对局里用；教学里点一下就行）
    var aiming = false
    var aimColor: GoStone = .black
    /// 点错的地方，闪一个叉
    var miss: Int?
}

struct GoBoardView: View {
    let state: GoBoardState
    let onTap: (Int) -> Void

    @State private var hover: Int?

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let n = state.board.size
            let margin = side * (n >= 13 ? 0.055 : 0.075)
            let cell = (side - margin * 2) / CGFloat(n - 1)
            let center = { (i: Int) in CGPoint(x: margin + CGFloat(i % n) * cell, y: margin + CGFloat(i / n) * cell) }
            ZStack(alignment: .topLeading) {
                surface(side: side, n: n, margin: margin, cell: cell, center: center)

                ForEach(state.marks.filter(\.under), id: \.self) { m in mark(m, cell: cell, center: center) }

                if let owner = state.owner {
                    ForEach(owner.indices.filter { owner[$0] != 0 && (state.board.cells[$0] == 0 || state.dead.contains($0)) }, id: \.self) { i in
                        RoundedRectangle(cornerRadius: cell * 0.06)
                            .fill(owner[i] == 1 ? Color(hex: 0x24232A) : .white)
                            .overlay(RoundedRectangle(cornerRadius: cell * 0.06).strokeBorder(.black.opacity(0.25), lineWidth: 1))
                            .frame(width: cell * 0.32, height: cell * 0.32)
                            .position(center(i))
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                ForEach(state.board.cells.indices.filter { state.board.cells[$0] != 0 }, id: \.self) { i in
                    StoneView(stone: state.board.cells[i] == 1 ? .black : .white, diameter: cell * 0.94)
                        .opacity(state.dead.contains(i) ? 0.4 : 1)
                        .position(center(i))
                        .transition(.asymmetric(insertion: .scale(scale: 1.3).combined(with: .opacity),
                                                removal: .scale(scale: 0.4).combined(with: .opacity)))
                }

                if let last = state.lastMove, state.board.cells[last] != 0 {
                    Circle()
                        .strokeBorder(state.board.cells[last] == 1 ? .white : Palette.ink, lineWidth: max(2, cell * 0.06))
                        .frame(width: cell * 0.4, height: cell * 0.4)
                        .position(center(last))
                }

                ForEach(state.marks.filter { !$0.under }, id: \.self) { m in mark(m, cell: cell, center: center) }

                if let h = state.hint {
                    ZStack {
                        StoneView(stone: state.aimColor == .black ? .black : .white, diameter: cell * 0.94).opacity(0.45)
                        PulseRing(color: Palette.sage)
                            .frame(width: cell * 1.15, height: cell * 1.15)
                    }
                    .position(center(h))
                }

                if let miss = state.miss {
                    Image(systemName: "xmark")
                        .font(.system(size: cell * 0.5, weight: .black))
                        .foregroundStyle(Palette.coral)
                        .position(center(miss))
                        .transition(.scale.combined(with: .opacity))
                }

                if let h = hover, state.aiming, state.board.cells[h] == 0 {
                    StoneView(stone: state.aimColor == .black ? .black : .white, diameter: cell * 0.94, lifted: true)
                        .opacity(0.6)
                        .position(center(h))
                        .allowsHitTesting(false)
                }
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        guard state.aiming else { return }
                        let p = point(v.location, n: n, margin: margin, cell: cell)
                        if p != hover { withAnimation(.spring(duration: 0.15)) { hover = p } }
                    }
                    .onEnded { v in
                        hover = nil
                        if let p = point(v.location, n: n, margin: margin, cell: cell) { onTap(p) }
                    }
            )
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func point(_ loc: CGPoint, n: Int, margin: CGFloat, cell: CGFloat) -> Int? {
        let fx = (loc.x - margin) / cell, fy = (loc.y - margin) / cell
        guard fx > -0.7, fy > -0.7, fx < CGFloat(n) - 0.3, fy < CGFloat(n) - 0.3 else { return nil }
        let x = min(max(Int(fx.rounded()), 0), n - 1), y = min(max(Int(fy.rounded()), 0), n - 1)
        return y * n + x
    }

    private func surface(side: CGFloat, n: Int, margin: CGFloat, cell: CGFloat, center: @escaping (Int) -> CGPoint) -> some View {
        let r = side * 0.03
        return ZStack {
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(LinearGradient(colors: [Palette.woodDeep, Color(hex: 0x95653A)], startPoint: .top, endPoint: .bottom))
                .frame(width: side, height: side)
                .offset(y: side * 0.016)
            ArtImage(name: "board_wood", fallback: "", contentMode: .fill)
                .saturation(0.82)
                .background(LinearGradient(colors: [Color(hex: 0xEDC88E), Palette.wood], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
            Canvas { ctx, _ in
                let ink = Color(hex: 0x3A2614)
                var grid = Path()
                for k in 0..<n {
                    grid.move(to: center(k)); grid.addLine(to: center((n - 1) * n + k))
                    grid.move(to: center(k * n)); grid.addLine(to: center(k * n + n - 1))
                }
                ctx.stroke(grid, with: .color(ink.opacity(0.62)), lineWidth: max(1, cell * 0.028))
                let tl = center(0), br = center(n * n - 1)
                ctx.stroke(Path(CGRect(x: tl.x, y: tl.y, width: br.x - tl.x, height: br.y - tl.y)),
                           with: .color(ink.opacity(0.75)), lineWidth: max(1.5, cell * 0.05))
                for s in GoBoard(size: n).starPoints {
                    let c = center(s), rr = cell * 0.09
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)), with: .color(ink.opacity(0.8)))
                }
            }
        }
        .frame(width: side, height: side)
        .shadow(color: Color(hex: 0x7A4E22).opacity(0.28), radius: side * 0.04, y: side * 0.03)
    }

    @ViewBuilder
    private func mark(_ m: GoMark, cell: CGFloat, center: (Int) -> CGPoint) -> some View {
        switch m {
        case let .glow(i):
            TargetBeacon().frame(width: cell * 0.95, height: cell * 0.95).position(center(i))
        case let .cross(i):
            Image(systemName: "xmark")
                .font(.system(size: cell * 0.5, weight: .black))
                .foregroundStyle(Palette.coral)
                .position(center(i))
        case let .ring(i):
            Circle()
                .strokeBorder(Palette.sky, lineWidth: max(3, cell * 0.08))
                .frame(width: cell * 1.08, height: cell * 1.08)
                .position(center(i))
        case let .dot(i):
            Circle()
                .fill(Palette.sky)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .frame(width: cell * 0.36, height: cell * 0.36)
                .shadow(color: Palette.sky.opacity(0.6), radius: 4)
                .position(center(i))
                .transition(.scale.combined(with: .opacity))
        case let .label(i, text):
            Text(text)
                .font(.kid(cell * 0.36, weight: .black))
                .foregroundStyle(.white)
                .frame(width: cell * 0.56, height: cell * 0.56)
                .background(Palette.coral, in: Circle())
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .position(center(i))
                .offset(x: -cell * 0.5, y: -cell * 0.5)
        }
    }
}

extension GoMark {
    /// 画在棋子下面的（提示点、气、叉），走到那里以后不挡棋子
    var under: Bool {
        switch self {
        case .glow, .dot, .cross: true
        default: false
        }
    }

    static func parse(_ s: String, _ b: GoBoard) -> GoMark? {
        let m = MarkSpec(s)
        let p = { (k: Int) in m.args.count > k ? b.index(m.args[k]) : nil }
        switch m.kind {
        case "glow": return p(0).map { .glow($0) }
        case "cross": return p(0).map { .cross($0) }
        case "ring": return p(0).map { .ring($0) }
        case "dot": return p(0).map { .dot($0) }
        case "label":
            guard let i = p(0), m.args.count > 1 else { return nil }
            return .label(i, m.args[1])
        default: return nil
        }
    }
}
