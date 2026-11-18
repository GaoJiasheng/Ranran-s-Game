import SwiftUI

// 新加坡数学的「线段图」（model drawing / bar model）。
// 部分-整体：一条长条分成几段，上面一个大括号写整体；比较：两条长条上下对齐，短的那条后面虚线框出"差"。

struct BarModel: Codable, Hashable {
    enum Style: String, Codable { case solid, gone, gap }
    /// a / b 用两个人物的颜色；neutral 是没有主人的东西（比如盘子里的）；extra 是"多出来 / 新来的"
    enum Tint: String, Codable { case a, b, neutral, extra }

    struct Seg: Codable, Hashable {
        var value: Int
        /// 段里写的数："5"、"?"，空的就不写
        var label = ""
        /// 段下面的小字："ate"、"{a}"
        var caption = ""
        var style: Style = .solid
        var tint: Tint? = nil
    }

    struct Bar: Codable, Hashable {
        /// 左边的名字（模板，可以是 {a}），空的就不写
        var name = ""
        var tint: Tint = .a
        var segs: [Seg]
        var total: Int { segs.reduce(0) { $0 + $1.value } }
    }

    struct Brace: Codable, Hashable {
        var bar: Int
        var from: Int
        var to: Int
        var label: String
        var below = false
    }

    var bars: [Bar]
    var braces: [Brace] = []
    /// 右边竖着括住所有长条的总数（比如"一共 ?"）
    var total: String? = nil
}

// MARK: - 画出来

struct BarModelView: View {
    let model: BarModel
    let problem: StoryProblem
    let player: String
    /// 答对以后把 "?" 换成答案
    var answer: Int? = nil

    private let barH: CGFloat = 58
    private let braceH: CGFloat = 54
    private let captionH: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let hasNames = model.bars.contains { !$0.name.isEmpty }
            let nameW: CGFloat = hasNames ? min(130, geo.size.width * 0.16) : 0
            let rightW: CGFloat = model.total == nil ? 24 : 96
            let width = min(max(geo.size.width - 40 - nameW - rightW, 100), 760)
            // 整张图在舞台里水平居中
            let left = max(20, (geo.size.width - nameW - width - rightW) / 2)
            let maxTotal = CGFloat(max(model.bars.map(\.total).max() ?? 1, 1))
            let unit = width / maxTotal
            let rows = model.bars.indices.map(rowHeights)
            let content = rows.reduce(0) { $0 + $1.top + barH + $1.bottom } + CGFloat(max(rows.count - 1, 0)) * 18
            let top = max((geo.size.height - content) / 2, 8)

            ZStack(alignment: .topLeading) {
                ForEach(Array(model.bars.enumerated()), id: \.offset) { i, bar in
                    let y = top + rowY(i, rows) + rows[i].top
                    if !bar.name.isEmpty {
                        Text(text(bar.name))
                            .font(.kid(22, weight: .heavy))
                            .foregroundStyle(ink(bar.tint))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(width: nameW - 10, alignment: .trailing)
                            .position(x: left + (nameW - 10) / 2, y: y + barH / 2)
                    }
                    barView(bar, x0: left + nameW, y: y, unit: unit)
                    ForEach(Array(model.braces.enumerated()).filter { $0.element.bar == i }, id: \.offset) { _, b in
                        braceView(b, bar: bar, x0: left + nameW, y: y, unit: unit)
                    }
                }
                if let total = model.total, let first = model.bars.indices.first, let last = model.bars.indices.last {
                    let y0 = top + rowY(first, rows) + rows[first].top
                    let y1 = top + rowY(last, rows) + rows[last].top + barH
                    let x = left + nameW + CGFloat(model.bars.map { solidTotal($0) }.max() ?? 0) * unit + 14
                    sideBrace(x: x, y0: y0, y1: y1, label: total)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .animation(.spring(duration: 0.55, bounce: 0.2), value: model)
        .animation(.spring(duration: 0.5, bounce: 0.4), value: answer)
    }

    // MARK: 一条

    private func barView(_ bar: BarModel.Bar, x0: CGFloat, y: CGFloat, unit: CGFloat) -> some View {
        var x = x0
        let frames: [(BarModel.Seg, CGFloat, CGFloat)] = bar.segs.map { s in
            defer { x += CGFloat(s.value) * unit }
            return (s, x, CGFloat(s.value) * unit)
        }
        return ForEach(Array(frames.enumerated()), id: \.offset) { _, f in
            let (s, sx, w) = f
            segView(s, barTint: bar.tint, width: w)
                .position(x: sx + w / 2, y: y + barH / 2)
            if !s.caption.isEmpty {
                Text(text(s.caption))
                    .font(.kid(17, weight: .bold))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: max(w, 60))
                    .position(x: sx + w / 2, y: y + barH + captionH / 2 + 2)
            }
        }
    }

    private func segView(_ s: BarModel.Seg, barTint: BarModel.Tint, width: CGFloat) -> some View {
        let tint = color(s.tint ?? barTint)
        let isQuestion = s.label == "?"
        let label = isQuestion ? (answer.map { "\($0)" } ?? "?") : s.label
        let shape = Rectangle()
        return ZStack {
            switch s.style {
            case .solid:
                shape.fill(tint.opacity(0.55))
                shape.strokeBorder(tint, lineWidth: 2.5)
            case .gone:
                shape.fill(Palette.paper)
                // 斜线：拿走了 / 用掉了
                Path { p in
                    let step: CGFloat = 14
                    var x: CGFloat = -barH
                    while x < width {
                        p.move(to: CGPoint(x: x, y: barH))
                        p.addLine(to: CGPoint(x: x + barH, y: 0))
                        x += step
                    }
                }
                .stroke(tint.opacity(0.45), lineWidth: 2)
                .clipShape(shape)
                shape.strokeBorder(tint.opacity(0.8), lineWidth: 2.5)
            case .gap:
                shape.fill(Palette.honey.opacity(0.08))
                shape.strokeBorder(Palette.inkSoft.opacity(0.6), style: StrokeStyle(lineWidth: 2.5, dash: [8, 6]))
            }
            if !label.isEmpty {
                Text(label)
                    .font(.kid(isQuestion ? 30 : 24, weight: .black))
                    .foregroundStyle(isQuestion ? (answer == nil ? Palette.coral : Color(hex: 0x4E8A5C)) : Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .padding(.horizontal, 3)
                    .contentTransition(.numericText())
            }
        }
        .frame(width: max(width, 1), height: barH)
    }

    // MARK: 括号

    private func braceView(_ b: BarModel.Brace, bar: BarModel.Bar, x0: CGFloat, y: CGFloat, unit: CGFloat) -> some View {
        let before = bar.segs.prefix(b.from).reduce(0) { $0 + $1.value }
        let span = bar.segs[b.from...min(b.to, bar.segs.count - 1)].reduce(0) { $0 + $1.value }
        let x1 = x0 + CGFloat(before) * unit, w = CGFloat(span) * unit
        let curveY = b.below ? y + barH + captionH + 6 : y - 8
        let isQuestion = b.label.contains("?")
        let label = isQuestion && answer != nil ? b.label.replacingOccurrences(of: "?", with: "\(answer!)") : text(b.label)
        return ZStack {
            CurlyBrace(down: !b.below)
                .stroke(Palette.inkSoft, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .frame(width: w, height: 16)
                .position(x: x1 + w / 2, y: curveY + (b.below ? 8 : -8))
            Text(label)
                .font(.kid(isQuestion ? 28 : 22, weight: .black))
                .foregroundStyle(isQuestion ? (answer == nil ? Palette.coral : Color(hex: 0x4E8A5C)) : Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: max(w, 90))
                .position(x: x1 + w / 2, y: b.below ? curveY + 34 : curveY - 32)
                .contentTransition(.numericText())
        }
    }

    private func sideBrace(x: CGFloat, y0: CGFloat, y1: CGFloat, label: String) -> some View {
        let isQuestion = label.contains("?")
        let shown = isQuestion && answer != nil ? label.replacingOccurrences(of: "?", with: "\(answer!)") : text(label)
        return ZStack {
            // 两头朝左对着长条，尖朝右对着数字
            CurlyBrace(down: false)
                .rotation(.degrees(-90))
                .stroke(Palette.inkSoft, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .frame(width: y1 - y0, height: 16)
                .position(x: x + 8, y: (y0 + y1) / 2)
            Text(shown)
                .font(.kid(isQuestion ? 28 : 22, weight: .black))
                .foregroundStyle(isQuestion ? (answer == nil ? Palette.coral : Color(hex: 0x4E8A5C)) : Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: 66)
                .position(x: x + 52, y: (y0 + y1) / 2)
        }
    }

    // MARK: 尺寸

    private func rowHeights(_ i: Int) -> (top: CGFloat, bottom: CGFloat) {
        let above = model.braces.contains { $0.bar == i && !$0.below }
        let below = model.braces.contains { $0.bar == i && $0.below }
        let captions = model.bars[i].segs.contains { !$0.caption.isEmpty }
        return (above ? braceH : 6, (captions || below ? captionH : 4) + (below ? braceH : 0))
    }

    private func rowY(_ i: Int, _ rows: [(top: CGFloat, bottom: CGFloat)]) -> CGFloat {
        rows.prefix(i).reduce(0) { $0 + $1.top + barH + $1.bottom + 18 }
    }

    private func solidTotal(_ bar: BarModel.Bar) -> Int {
        bar.segs.filter { $0.style != .gap }.reduce(0) { $0 + $1.value }
    }

    // MARK: 颜色、文字

    private func text(_ template: String) -> String { StoryText.plain(template, problem, player: player) }

    private func color(_ t: BarModel.Tint) -> Color {
        switch t {
        case .a:       problem.a.tint
        case .b:       (problem.b ?? problem.a).tint
        case .neutral: Palette.sky
        case .extra:   Palette.honey
        }
    }

    private func ink(_ t: BarModel.Tint) -> Color {
        switch t {
        case .a:       problem.a.ink
        case .b:       (problem.b ?? problem.a).ink
        default:       Palette.ink
        }
    }
}

/// 横着的大括号；down = 尖朝下（放在长条上面）
struct CurlyBrace: Shape {
    var down: Bool

    func path(in r: CGRect) -> Path {
        var p = Path()
        let (top, bottom) = down ? (r.minY, r.maxY) : (r.maxY, r.minY)
        let mid = (top + bottom) / 2
        let w = r.width, x = r.minX
        let c = min(14, w / 6)
        p.move(to: CGPoint(x: x, y: bottom))
        p.addQuadCurve(to: CGPoint(x: x + c, y: mid), control: CGPoint(x: x, y: mid))
        p.addLine(to: CGPoint(x: x + w / 2 - c, y: mid))
        p.addQuadCurve(to: CGPoint(x: x + w / 2, y: top), control: CGPoint(x: x + w / 2, y: mid))
        p.addQuadCurve(to: CGPoint(x: x + w / 2 + c, y: mid), control: CGPoint(x: x + w / 2, y: mid))
        p.addLine(to: CGPoint(x: x + w - c, y: mid))
        p.addQuadCurve(to: CGPoint(x: x + w, y: bottom), control: CGPoint(x: x + w, y: mid))
        return p
    }
}
