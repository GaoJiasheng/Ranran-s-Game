import SwiftUI

/// 数独的主题色
enum SudokuStyle {
    static let accent = Color(hex: 0xD9973A)
    /// 她自己填的数字
    static let entry = Color(hex: 0x3D7CC9)
    /// 题目给的格子的底色
    static let givenFill = Color(hex: 0xF3EADB)
    static let line = Palette.ink.opacity(0.16)
    static let thick = Color(hex: 0x5A4A3A)
    static let fruitArt = [1: "item_apple", 2: "item_strawberry", 3: "item_carrot", 4: "item_balloon"]
    static let fruitEmoji = [1: "🍎", 2: "🍓", 3: "🥕", 4: "🎈"]
    /// 小图里水果用的颜色
    static let fruitDot: [Int: Color] = [1: Color(hex: 0xE5534B), 2: Color(hex: 0xF27A9B), 3: Color(hex: 0xF29B38), 4: Color(hex: 0x5B9BD5)]
    static let fruitName = [1: "苹果", 2: "草莓", 3: "胡萝卜", 4: "气球"]

    static func name(_ v: Int, fruit: Bool) -> String { fruit ? (fruitName[v] ?? "") : "\(v)" }
}

/// 一个数字或者一种水果
struct SudokuToken: View {
    enum Look { case given, entry, wrong, ghost, pad, padOn }

    let value: Int
    let fruit: Bool
    let size: CGFloat
    var look: Look = .given

    var body: some View {
        Group {
            if fruit {
                ArtImage(name: SudokuStyle.fruitArt[value] ?? "", fallback: SudokuStyle.fruitEmoji[value] ?? "?")
                    .frame(width: size * 0.78, height: size * 0.78)
                    .opacity(look == .ghost ? 0.4 : 1)
            } else {
                Text("\(value)")
                    .font(.system(size: size * 0.62, weight: look == .given ? .heavy : .bold, design: .rounded))
                    .foregroundStyle(color)
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(width: size, height: size)
    }

    private var color: Color {
        switch look {
        case .given, .pad: Palette.ink
        case .entry: SudokuStyle.entry
        case .wrong: Palette.coral
        case .ghost: SudokuStyle.entry.opacity(0.4)
        case .padOn: .white
        }
    }
}

/// 盘面上要画的一切：数字、哪些是题目给的、选中、亮起来的地方、打叉、小笔记……
struct SudokuBoardLook {
    var grid: SudokuGrid
    var given: Set<Int>
    /// 她填错的格子（红色，会晃一下）
    var wrong: Set<Int> = []
    /// 和填错的格子重复的格子（描一圈红边，告诉她和谁撞了）
    var clash: Set<Int> = []
    var notes: [Int: Set<Int>] = [:]
    var selected: Int?
    /// 和这个数一样的格子都亮起来
    var sameValue: Int?
    /// 选中格子的行、列、宫（淡淡地亮）
    var softUnits: [SudokuUnit] = []
    /// 提示、教学里圈出来的行、列、宫
    var focusUnits: [SudokuUnit] = []
    /// 发光的格子
    var glow: Set<Int> = []
    /// 打叉的格子（排除法）
    var crossed: Set<Int> = []
    /// 唯一法的提示：同行同列同宫轻轻亮
    var peers: Set<Int> = []
    /// 淡淡地画出来的答案
    var ghost: [Int: Int] = [:]
    /// 画一个问号
    var question: Set<Int> = []
    /// 刚填满的一行 / 列 / 宫，闪一下
    var flash: Set<Int> = []
    /// 格子 → 晃了几次（每次加一就晃一下）
    var wobble: [Int: Int] = [:]
}

struct SudokuBoardView: View {
    let look: SudokuBoardLook
    var onTap: (Int) -> Void = { _ in }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let g = look.grid
            let cell = side / CGFloat(g.n)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: side * 0.035, style: .continuous)
                    .fill(Palette.paper)
                ForEach(0..<g.count, id: \.self) { i in
                    cellView(i, size: cell)
                        .frame(width: cell, height: cell)
                        .contentShape(Rectangle())
                        .onTapGesture { onTap(i) }
                        .offset(x: CGFloat(g.col(i)) * cell, y: CGFloat(g.row(i)) * cell)
                }
                ForEach(Array(look.focusUnits.enumerated()), id: \.offset) { _, u in
                    unitOutline(u, cell: cell)
                }
                lines(side: side, cell: cell)
                    .allowsHitTesting(false)
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: side * 0.035, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: side * 0.035, style: .continuous)
                    .strokeBorder(SudokuStyle.thick, lineWidth: max(3, side * 0.008))
            )
            .shadow(color: Color(hex: 0x6B4E2E).opacity(0.14), radius: 18, y: 10)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: 一格

    private func background(_ i: Int) -> Color {
        if look.flash.contains(i) { return Palette.sage.opacity(0.45) }
        if look.selected == i { return Palette.honey.opacity(0.75) }
        if look.wrong.contains(i) { return Palette.coral.opacity(0.16) }
        if let v = look.sameValue, v > 0, look.grid[i] == v { return Palette.honey.opacity(0.42) }
        if look.focusUnits.contains(where: { look.grid.contains($0, i) }) { return Palette.sky.opacity(0.22) }
        if look.peers.contains(i) || look.softUnits.contains(where: { look.grid.contains($0, i) }) {
            return Palette.honey.opacity(0.16)
        }
        return look.given.contains(i) ? SudokuStyle.givenFill : Palette.paper
    }

    @ViewBuilder
    private func cellView(_ i: Int, size: CGFloat) -> some View {
        let v = look.grid[i]
        let fruit = look.grid.fruit
        ZStack {
            Rectangle().fill(background(i))
            if v > 0 {
                SudokuToken(value: v, fruit: fruit, size: size,
                            look: look.given.contains(i) ? .given : look.wrong.contains(i) ? .wrong : .entry)
                    .modifier(SudokuShake(animatableData: CGFloat(look.wobble[i] ?? 0)))
                    .animation(.linear(duration: 0.45), value: look.wobble[i] ?? 0)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            } else if let g = look.ghost[i] {
                SudokuToken(value: g, fruit: fruit, size: size, look: .ghost)
            } else if look.question.contains(i) {
                Text("?")
                    .font(.system(size: size * 0.55, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.coral)
            } else if let ns = look.notes[i], !ns.isEmpty {
                notes(ns, size: size, fruit: fruit)
            }
            if look.wrong.contains(i) && fruit {
                Circle().strokeBorder(Palette.coral, lineWidth: max(2, size * 0.05)).padding(size * 0.06)
            }
            if look.clash.contains(i) {
                RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                    .strokeBorder(Palette.coral.opacity(0.8), style: StrokeStyle(lineWidth: max(2, size * 0.045), dash: [size * 0.1, size * 0.07]))
                    .padding(size * 0.06)
            }
            if look.crossed.contains(i) {
                SudokuCross()
                    .stroke(Palette.coral.opacity(0.6), style: StrokeStyle(lineWidth: max(2, size * 0.06), lineCap: .round))
                    .padding(size * 0.24)
            }
            if look.glow.contains(i) {
                RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                    .strokeBorder(Palette.coral, lineWidth: max(3, size * 0.08))
                    .padding(size * 0.04)
                    .phaseAnimator([false, true]) { view, on in
                        view.opacity(on ? 1 : 0.35).scaleEffect(on ? 1 : 0.92)
                    } animation: { _ in .easeInOut(duration: 0.7) }
            }
        }
        .animation(.spring(duration: 0.3), value: v)
    }

    private func notes(_ ns: Set<Int>, size: CGFloat, fruit: Bool) -> some View {
        let n = look.grid.n
        let cols = n == 4 ? 2 : 3
        let rows = (n + cols - 1) / cols
        let s = size * 0.9 / CGFloat(max(cols, rows))
        return VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<cols, id: \.self) { c in
                        let v = r * cols + c + 1
                        Group {
                            if v <= n, ns.contains(v) {
                                if fruit {
                                    Circle().fill(SudokuStyle.fruitDot[v] ?? Palette.inkSoft).padding(s * 0.22)
                                } else {
                                    Text("\(v)")
                                        .font(.system(size: s * 0.78, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Palette.inkSoft)
                                }
                            } else {
                                Color.clear
                            }
                        }
                        .frame(width: s, height: s)
                    }
                }
            }
        }
    }

    // MARK: 线

    private func lines(side: CGFloat, cell: CGFloat) -> some View {
        let g = look.grid
        return Canvas { ctx, _ in
            var thin = Path()
            var thick = Path()
            for k in 1..<g.n {
                let p = CGFloat(k) * cell
                var v = Path(); v.move(to: CGPoint(x: p, y: 0)); v.addLine(to: CGPoint(x: p, y: side))
                var h = Path(); h.move(to: CGPoint(x: 0, y: p)); h.addLine(to: CGPoint(x: side, y: p))
                if k % g.boxCols == 0 { thick.addPath(v) } else { thin.addPath(v) }
                if k % g.boxRows == 0 { thick.addPath(h) } else { thin.addPath(h) }
            }
            ctx.stroke(thin, with: .color(SudokuStyle.line), lineWidth: max(1, side * 0.0025))
            ctx.stroke(thick, with: .color(SudokuStyle.thick), lineWidth: max(2.5, side * 0.007))
        }
        .frame(width: side, height: side)
    }

    private func unitOutline(_ u: SudokuUnit, cell: CGFloat) -> some View {
        let g = look.grid
        let cs = g.cells(u)
        let r0 = cs.map(g.row).min() ?? 0, r1 = cs.map(g.row).max() ?? 0
        let c0 = cs.map(g.col).min() ?? 0, c1 = cs.map(g.col).max() ?? 0
        let w = CGFloat(c1 - c0 + 1) * cell, h = CGFloat(r1 - r0 + 1) * cell
        return RoundedRectangle(cornerRadius: cell * 0.22, style: .continuous)
            .strokeBorder(Color(hex: 0x3F8FD2), lineWidth: max(3, cell * 0.08))
            .frame(width: w, height: h)
            .offset(x: CGFloat(c0) * cell, y: CGFloat(r0) * cell)
            .allowsHitTesting(false)
            .transition(.opacity)
    }
}

struct SudokuCross: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.move(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        return p
    }
}

/// 填错时左右晃一下
struct SudokuShake: GeometryEffect {
    var amount: CGFloat = 7
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * 4), y: 0))
    }
}

// MARK: - 关卡页的小图

/// 一关的小图：题目给的格子（一眼看出是四宫格、六宫格还是九宫格）；过了的关画出整盘答案
struct SudokuThumb: View {
    @Environment(PlayerStore.self) private var store
    let level: String

    var body: some View {
        if let lv = SudokuCatalog.level(level) {
            let cleared = store.puzzleCleared("sudoku", level)
            Canvas { ctx, size in
                let side = min(size.width, size.height)
                let g = lv.puzzle
                let cell = side / CGFloat(g.n)
                let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
                let rect = CGRect(origin: origin, size: CGSize(width: side, height: side))
                let shape = Path(roundedRect: rect, cornerRadius: side * 0.08)
                ctx.fill(shape, with: .color(Palette.paper))
                for i in 0..<g.count {
                    let r = CGRect(x: origin.x + CGFloat(g.col(i)) * cell, y: origin.y + CGFloat(g.row(i)) * cell, width: cell, height: cell)
                    let given = g[i] != 0
                    if given { ctx.fill(Path(r.insetBy(dx: 0.3, dy: 0.3)), with: .color(SudokuStyle.givenFill)) }
                    let v = given ? g[i] : (cleared ? lv.solution[i] : 0)
                    guard v > 0 else { continue }
                    if g.fruit {
                        ctx.fill(Path(ellipseIn: r.insetBy(dx: cell * 0.22, dy: cell * 0.22)),
                                 with: .color((SudokuStyle.fruitDot[v] ?? Palette.inkSoft).opacity(given ? 1 : 0.45)))
                    } else if cell >= 9 {
                        ctx.draw(Text("\(v)").font(.system(size: cell * 0.66, weight: given ? .heavy : .semibold, design: .rounded))
                                    .foregroundColor(given ? Palette.ink : SudokuStyle.entry),
                                 at: CGPoint(x: r.midX, y: r.midY))
                    } else {
                        ctx.fill(Path(ellipseIn: r.insetBy(dx: cell * 0.3, dy: cell * 0.3)),
                                 with: .color(given ? Palette.ink.opacity(0.7) : SudokuStyle.entry.opacity(0.6)))
                    }
                }
                var thick = Path()
                for k in 1..<g.n {
                    let p = CGFloat(k) * cell
                    if k % g.boxCols == 0 { thick.move(to: CGPoint(x: origin.x + p, y: origin.y)); thick.addLine(to: CGPoint(x: origin.x + p, y: origin.y + side)) }
                    if k % g.boxRows == 0 { thick.move(to: CGPoint(x: origin.x, y: origin.y + p)); thick.addLine(to: CGPoint(x: origin.x + side, y: origin.y + p)) }
                }
                ctx.stroke(thick, with: .color(SudokuStyle.thick.opacity(0.8)), lineWidth: max(1, side * 0.02))
                ctx.stroke(shape, with: .color(SudokuStyle.thick.opacity(0.8)), lineWidth: max(1.2, side * 0.025))
            }
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.honey.opacity(0.25))
        }
    }
}
