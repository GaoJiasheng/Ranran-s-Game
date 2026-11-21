import SwiftUI
import UIKit

/// 国际象棋棋盘上的坐标换算。自己这一方在下面（flipped = 黑方在下）。四周留一圈写 a…h、1…8。
struct ChessLayout {
    let cell: CGFloat
    let flipped: Bool
    var margin: CGFloat { cell * 0.42 }
    var side: CGFloat { cell * 8 + margin * 2 }

    init(size: CGSize, flipped: Bool) {
        cell = max(1, min(size.width, size.height) / 8.84)
        self.flipped = flipped
    }

    func center(_ s: ChessSquare) -> CGPoint {
        let col = flipped ? 7 - s.file : s.file
        let row = flipped ? s.rank : 7 - s.rank
        return CGPoint(x: margin + (CGFloat(col) + 0.5) * cell, y: margin + (CGFloat(row) + 0.5) * cell)
    }

    func rect(_ s: ChessSquare) -> CGRect {
        let c = center(s)
        return CGRect(x: c.x - cell / 2, y: c.y - cell / 2, width: cell, height: cell)
    }

    func square(at p: CGPoint) -> ChessSquare? {
        let col = Int(floor((p.x - margin) / cell)), row = Int(floor((p.y - margin) / cell))
        guard col >= 0, col < 8, row >= 0, row < 8 else { return nil }
        return flipped ? ChessSquare(7 - col, row) : ChessSquare(col, 7 - row)
    }
}

/// 棋盘上额外的标记：教学里用得最多
enum ChessMark: Hashable {
    /// 发光提示"点这里 / 走到这里"
    case glow(ChessSquare)
    /// 一个彩色圆圈（warn = 红色虚线，比如圈出正在将军的子）
    case ring(ChessSquare, warn: Bool)
    case arrow(ChessSquare, ChessSquare)
    /// 写在格子角上的小字母
    case label(ChessSquare, String)
    /// 一个不能去的格子（打叉）
    case cross(ChessSquare)
    /// 一个能去的格子（小圆点，演示走法用）
    case dot(ChessSquare)
    /// 把格子涂上淡淡的颜色（比如中心四格）
    case tint(ChessSquare)

    /// 画在棋子底下的
    var under: Bool {
        switch self {
        case .glow, .tint, .dot: true
        default: false
        }
    }

    /// 教学 JSON 里的 "glow:e4"、"arrow:e2:e4"、"label:e4:A"
    init?(spec: String) {
        let m = MarkSpec(spec)
        let sq = { (i: Int) in m.args.count > i ? ChessSquare(m.args[i]) : nil }
        switch m.kind {
        case "glow": guard let a = sq(0) else { return nil }; self = .glow(a)
        case "ring": guard let a = sq(0) else { return nil }; self = .ring(a, warn: false)
        case "warn": guard let a = sq(0) else { return nil }; self = .ring(a, warn: true)
        case "cross": guard let a = sq(0) else { return nil }; self = .cross(a)
        case "dot": guard let a = sq(0) else { return nil }; self = .dot(a)
        case "tint": guard let a = sq(0) else { return nil }; self = .tint(a)
        case "arrow":
            guard let a = sq(0), let b = sq(1) else { return nil }
            self = .arrow(a, b)
        case "label":
            guard let a = sq(0), m.args.count > 1 else { return nil }
            self = .label(a, m.args[1])
        default: return nil
        }
    }
}

/// 棋盘要显示的全部内容。对局、复盘、教学都用它。
struct ChessBoardState {
    var board: ChessBoard
    var ids: [Int]
    var flipped = false
    var selected: ChessSquare?
    /// 选中的子能去的地方
    var targets: [ChessSquare] = []
    var lastMove: ChessMove?
    var checkedKing: ChessSquare?
    var hint: ChessMove?
    var marks: [ChessMark] = []
    var checkFlash = 0
}

/// 走一步时，棋子的编号跟着子走（界面才能画出"滑过去"的动画），吃过路兵、易位的车也一起换
struct ChessPieceIDs {
    static func initial(_ b: ChessBoard) -> [Int] { (0..<64).map { b.cells[$0] == 0 ? 0 : $0 + 1 } }

    /// 走之前的局面 b 上走 m：返回被吃掉的子的编号和它原来的格子
    @discardableResult
    static func apply(_ m: ChessMove, on b: ChessBoard, _ ids: inout [Int]) -> (id: Int, at: Int) {
        let f = m.from.index, t = m.to.index
        let at = b.isEnPassant(m) ? (b.turn == .white ? t - 8 : t + 8) : t
        let cap = ids[at]
        ids[at] = 0
        ids[t] = ids[f]
        ids[f] = 0
        if b.isCastle(m) {
            let (rf, rt) = t > f ? (f + 3, f + 1) : (f - 4, f - 1)
            ids[rt] = ids[rf]
            ids[rf] = 0
        }
        return (cap, at)
    }

    /// 退回一步（b 是走之前的局面）
    static func revert(_ m: ChessMove, on b: ChessBoard, captured: (id: Int, at: Int), _ ids: inout [Int]) {
        let f = m.from.index, t = m.to.index
        ids[f] = ids[t]
        ids[t] = 0
        if b.isCastle(m) {
            let (rf, rt) = t > f ? (f + 3, f + 1) : (f - 4, f - 1)
            ids[rf] = ids[rt]
            ids[rt] = 0
        }
        ids[captured.at] = captured.id
    }
}

struct ChessBoardView: View {
    let state: ChessBoardState
    let onTap: (ChessSquare) -> Void

    @State private var dragFrom: ChessSquare?
    @State private var dragPoint: CGPoint?

    private struct Placed: Identifiable {
        let id: Int
        let square: ChessSquare
        let piece: ChessPiece
    }

    var body: some View {
        GeometryReader { geo in
            let l = ChessLayout(size: geo.size, flipped: state.flipped)
            ZStack(alignment: .topLeading) {
                ChessSurface(layout: l)

                // 最后一步：从哪里来、到了哪里，两格都涂一层淡黄
                if let m = state.lastMove {
                    ForEach([m.from, m.to], id: \.self) { s in
                        Rectangle().fill(Palette.honey.opacity(0.42))
                            .frame(width: l.cell, height: l.cell)
                            .position(l.center(s))
                    }
                }
                if let s = state.selected {
                    Rectangle().fill(Palette.sage.opacity(0.55))
                        .frame(width: l.cell, height: l.cell)
                        .position(l.center(s))
                }
                if let k = state.checkedKing {
                    RadialGradient(colors: [Palette.coral.opacity(0.85), Palette.coral.opacity(0)],
                                   center: .center, startRadius: 0, endRadius: l.cell * 0.62)
                        .frame(width: l.cell, height: l.cell)
                        .position(l.center(k))
                }

                ForEach(Array(state.marks.enumerated()).filter { $0.element.under }, id: \.offset) { _, mark in
                    markView(mark, l)
                }

                ForEach(placed, id: \.id) { p in
                    let dragging = p.square == dragFrom && dragPoint != nil
                    ChessPieceView(piece: p.piece, size: l.cell * 0.9, lifted: p.square == state.selected || dragging)
                        .position(dragging ? dragPoint! : l.center(p.square))
                        .zIndex(dragging ? 10 : p.square == state.selected ? 2 : 1)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                        .allowsHitTesting(false)
                }

                if let k = state.checkedKing {
                    PulseRing(color: Palette.coral)
                        .frame(width: l.cell * 1.05, height: l.cell * 1.05)
                        .position(l.center(k))
                        .zIndex(3)
                        .allowsHitTesting(false)
                }

                ForEach(state.targets, id: \.self) { t in
                    Group {
                        if state.board[t] != nil || isEnPassantTarget(t) {
                            Circle()
                                .strokeBorder(Palette.coral, lineWidth: max(3, l.cell * 0.08))
                                .frame(width: l.cell * 0.92, height: l.cell * 0.92)
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
                    .allowsHitTesting(false)
                }

                ForEach(Array(state.marks.enumerated()).filter { !$0.element.under }, id: \.offset) { _, mark in
                    markView(mark, l).zIndex(5)
                }

                if let h = state.hint {
                    XArrow(from: l.center(h.from), to: l.center(h.to), width: l.cell * 0.14, color: Palette.sage)
                        .zIndex(6)
                }
            }
            .frame(width: l.side, height: l.side)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if dragFrom == nil { dragFrom = l.square(at: v.startLocation) }
                        // 按住一个子拖动：子跟着手指走
                        if let f = dragFrom, state.board[f] != nil, hypot(v.translation.width, v.translation.height) > l.cell * 0.3 {
                            dragPoint = v.location
                        }
                    }
                    .onEnded { v in
                        let start = dragFrom ?? l.square(at: v.startLocation)
                        let dragged = dragPoint != nil
                        dragFrom = nil
                        dragPoint = nil
                        guard let end = l.square(at: v.location) else { return }
                        if let start, dragged, start != end {
                            // 拖着走：先选起点再点终点
                            if state.selected != start { onTap(start) }
                            onTap(end)
                        } else if !dragged || start == end {
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

    private func isEnPassantTarget(_ t: ChessSquare) -> Bool {
        guard let s = state.selected else { return false }
        return state.board.isEnPassant(ChessMove(s, t))
    }

    private var placed: [Placed] {
        (0..<64).compactMap { i in
            guard let p = ChessPiece(code: state.board.cells[i]) else { return nil }
            let id = state.ids.indices.contains(i) && state.ids[i] != 0 ? state.ids[i] : 1000 + i
            return Placed(id: id, square: ChessSquare(index: i), piece: p)
        }
    }

    @ViewBuilder
    private func markView(_ mark: ChessMark, _ l: ChessLayout) -> some View {
        switch mark {
        case let .glow(s):
            TargetBeacon()
                .frame(width: l.cell * 0.95, height: l.cell * 0.95)
                .position(l.center(s))
        case let .ring(s, warn):
            Circle()
                .strokeBorder(warn ? Palette.coral : Palette.sky,
                              style: StrokeStyle(lineWidth: max(3, l.cell * 0.08), dash: warn ? [6, 5] : []))
                .frame(width: l.cell * 0.98, height: l.cell * 0.98)
                .position(l.center(s))
        case let .arrow(a, b):
            XArrow(from: l.center(a), to: l.center(b), width: l.cell * 0.13, color: Palette.honey)
        case let .label(s, text):
            Text(text)
                .font(.kid(l.cell * 0.3, weight: .black))
                .foregroundStyle(.white)
                .frame(width: l.cell * 0.42, height: l.cell * 0.42)
                .background(Palette.coral, in: Circle())
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .position(l.center(s))
                .offset(x: l.cell * 0.32, y: -l.cell * 0.32)
        case let .cross(s):
            Image(systemName: "xmark")
                .font(.system(size: l.cell * 0.4, weight: .black))
                .foregroundStyle(Palette.coral)
                .position(l.center(s))
        case let .dot(s):
            Circle()
                .fill(Palette.sage)
                .frame(width: l.cell * 0.28, height: l.cell * 0.28)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .position(l.center(s))
        case let .tint(s):
            RoundedRectangle(cornerRadius: l.cell * 0.12, style: .continuous)
                .fill(Palette.honey.opacity(0.45))
                .frame(width: l.cell * 0.94, height: l.cell * 0.94)
                .position(l.center(s))
        }
    }
}

// MARK: - 棋子

/// 一个国际象棋棋子：插画 chess_wk … chess_bp；图片还没到时画一个带描边的棋子符号
struct ChessPieceView: View {
    let piece: ChessPiece
    let size: CGFloat
    var lifted = false

    static let whiteInk = Color(hex: 0xFFFDF8)
    static let blackInk = Color(hex: 0x3B3350)
    static let outline = Color(hex: 0x4A3F66)

    var body: some View {
        let hasArt = UIImage(named: piece.artName) != nil
        let white = piece.side == .white
        Group {
            if hasArt {
                ArtImage(name: piece.artName, fallback: piece.glyph)
            } else {
                // 实心符号：白子白色、深紫描边；黑子深紫色、浅色描边
                let stroke = white ? Self.outline : Color.white.opacity(0.85)
                let w = max(1, size * 0.025)
                Text(piece.glyph)
                    .font(.system(size: size * 0.82))
                    .foregroundStyle(white ? Self.whiteInk : Self.blackInk)
                    .shadow(color: stroke, radius: 0, x: w, y: 0)
                    .shadow(color: stroke, radius: 0, x: -w, y: 0)
                    .shadow(color: stroke, radius: 0, x: 0, y: w)
                    .shadow(color: stroke, radius: 0, x: 0, y: -w)
                    .frame(width: size, height: size)
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(lifted ? 0.3 : 0.16), radius: lifted ? size * 0.12 : size * 0.03,
                y: lifted ? size * 0.14 : size * 0.04)
        .scaleEffect(lifted ? 1.12 : 1)
        .accessibilityLabel(piece.name)
    }
}

// MARK: - 棋盘

/// 浅奶油色和淡紫色的格子，外面一圈圆角木框写着坐标
struct ChessSurface: View {
    let layout: ChessLayout

    static let light = Color(hex: 0xFBF3E4)
    static let dark = Color(hex: 0xCBBFE8)
    static let frame = Color(hex: 0x8B7FC0)

    var body: some View {
        let l = layout
        let r = l.cell * 0.32
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(Self.frame.opacity(0.75))
                .frame(width: l.side, height: l.side)
                .offset(y: l.cell * 0.1)
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xE9E2F7), Color(hex: 0xD9CFF1)], startPoint: .top, endPoint: .bottom))
                .frame(width: l.side, height: l.side)

            Canvas { ctx, _ in
                for s in ChessSquare.all {
                    ctx.fill(Path(l.rect(s)), with: .color(s.isLight ? Self.light : Self.dark))
                }
                let inner = CGRect(x: l.margin, y: l.margin, width: l.cell * 8, height: l.cell * 8)
                ctx.stroke(Path(inner), with: .color(Self.frame.opacity(0.6)), lineWidth: max(1, l.cell * 0.03))
            }
            .frame(width: l.side, height: l.side)

            // 坐标：下面 a…h，左边 1…8（跟着棋盘翻转）
            ForEach(0..<8, id: \.self) { i in
                let file = ChessSquare(l.flipped ? 7 - i : i, l.flipped ? 7 : 0)
                Text(String(file.name.first!))
                    .font(.kid(l.cell * 0.24, weight: .heavy))
                    .foregroundStyle(Self.frame)
                    .position(x: l.center(file).x, y: l.side - l.margin / 2)
                let rank = ChessSquare(l.flipped ? 7 : 0, l.flipped ? i : 7 - i)
                Text(String(rank.name.last!))
                    .font(.kid(l.cell * 0.24, weight: .heavy))
                    .foregroundStyle(Self.frame)
                    .position(x: l.margin / 2, y: l.center(rank).y)
            }
        }
        .frame(width: l.side, height: l.side)
        .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
        .shadow(color: Self.frame.opacity(0.3), radius: l.cell * 0.35, y: l.cell * 0.25)
    }
}

// MARK: - 升变

/// 兵走到最后一排：选一个子。盖在棋盘上面。
struct ChessPromotionPicker: View {
    let side: ChessSide
    let onPick: (ChessKind) -> Void
    let onCancel: () -> Void

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let piece = min(110, s * 0.16)
            ZStack {
                Color.black.opacity(0.18)
                    .contentShape(Rectangle())
                    .onTapGesture { onCancel() }
                VStack(spacing: s * 0.03) {
                    Text("兵升变成什么？")
                        .font(.kid(min(30, s * 0.05), weight: .heavy))
                        .foregroundStyle(Palette.ink)
                    HStack(spacing: s * 0.025) {
                        ForEach(ChessKind.promotions, id: \.self) { k in
                            Button {
                                Sound.tap()
                                onPick(k)
                            } label: {
                                VStack(spacing: 4) {
                                    ChessPieceView(piece: ChessPiece(side, k), size: piece)
                                    Text(k.chinese)
                                        .font(.kid(min(24, s * 0.04), weight: .heavy))
                                        .foregroundStyle(Palette.ink)
                                }
                                .padding(.horizontal, piece * 0.12)
                                .padding(.vertical, piece * 0.1)
                                .background(k == .queen ? Palette.honey.opacity(0.35) : Palette.paper,
                                            in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
                .padding(s * 0.04)
                .softCard(radius: 34)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}
