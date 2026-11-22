import SwiftUI

/// 花园：草地用代码画（两种绿交错的圆角格子），石头、胡萝卜、家、两种花、小兔用图片（图没到时用 emoji）。
/// 只管画；格子多大由外面算好（CodingLayout.plan）传进来。
struct CodingGardenView: View {
    let garden: CodingGarden
    let bunny: CodingState
    /// 格子边长（点）
    let cell: CGFloat
    var facingLeft = false
    var mood: Mood = .idle
    var bump: (dir: CodingDir, tick: Int)? = nil
    var check: (hit: Bool, tick: Int)? = nil
    var trail: [CodingCell] = []
    /// 发光的格子、画圈的格子（教学的标记、predict 题的答案）
    var glow: Set<CodingCell> = []
    var rings: Set<CodingCell> = []
    /// 点格子（predict 题）
    var onTap: ((CodingCell) -> Void)? = nil

    enum Mood { case idle, oops, yay }

    var body: some View {
        let w = CGFloat(garden.width) * cell, h = CGFloat(garden.height) * cell
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: cell * 0.32, style: .continuous)
                .fill(Color(hex: 0x6FA35A))
                .frame(width: w + cell * 0.24, height: h + cell * 0.24)
                .offset(x: -cell * 0.12, y: -cell * 0.12)
                .shadow(color: Color(hex: 0x3E5E2E).opacity(0.25), radius: 10, y: 6)
            ForEach(0..<garden.height, id: \.self) { y in
                ForEach(0..<garden.width, id: \.self) { x in
                    tile(x, y)
                        .frame(width: cell, height: cell)
                        .offset(x: CGFloat(x) * cell, y: CGFloat(y) * cell)
                }
            }
            ForEach(Array(trail.enumerated()), id: \.offset) { _, c in
                Circle()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: cell * 0.16, height: cell * 0.16)
                    .offset(x: (CGFloat(c.x) + 0.42) * cell, y: (CGFloat(c.y) + 0.42) * cell)
                    .allowsHitTesting(false)
            }
            bunnyView
                .frame(width: cell * 0.92, height: cell * 0.92)
                .offset(x: (CGFloat(bunny.x) + 0.04) * cell, y: (CGFloat(bunny.y) + 0.0) * cell)
                .allowsHitTesting(false)
                .zIndex(5)
        }
        .frame(width: w, height: h, alignment: .topLeading)
    }

    @ViewBuilder
    private func tile(_ x: Int, _ y: Int) -> some View {
        let c = garden.char(x, y)
        let here = CodingCell(x: x, y: y)
        let base = (x + y) % 2 == 0 ? Color(hex: 0xA8D58A) : Color(hex: 0x98CB7A)
        let flowerTint: Color? = c == "b" ? Color(hex: 0xBFDDF5) : c == "y" ? Color(hex: 0xFBE8A6) : nil
        ZStack {
            RoundedRectangle(cornerRadius: cell * 0.18, style: .continuous)
                .fill(flowerTint ?? base)
                .padding(cell * 0.04)
            switch c {
            case "#":
                ArtImage(name: "coding_rock", fallback: "🪨").padding(cell * 0.1)
            case "C":
                if let i = garden.carrotIndex(x, y), bunny.eaten & (1 << i) == 0 {
                    ArtImage(name: "coding_carrot", fallback: "🥕").padding(cell * 0.12)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                }
            case "H":
                ArtImage(name: "coding_home", fallback: "🏡").padding(cell * 0.08)
            case "b":
                ArtImage(name: "coding_flower_blue", fallback: "🪻").padding(cell * 0.16)
            case "y":
                ArtImage(name: "coding_flower_yellow", fallback: "🌼").padding(cell * 0.16)
            case "B":
                // 出发的地方：一个浅浅的圈
                Circle().strokeBorder(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: max(2, cell * 0.04), dash: [cell * 0.08, cell * 0.06]))
                    .padding(cell * 0.14)
            default:
                EmptyView()
            }
            if glow.contains(here) {
                RoundedRectangle(cornerRadius: cell * 0.18, style: .continuous)
                    .fill(Color.white.opacity(0.35))
                    .overlay(RoundedRectangle(cornerRadius: cell * 0.18, style: .continuous)
                        .strokeBorder(Color.white, lineWidth: max(3, cell * 0.06)))
                    .padding(cell * 0.03)
                    .shadow(color: .white.opacity(0.9), radius: 8)
            }
            if rings.contains(here) {
                Circle().strokeBorder(Palette.coral, lineWidth: max(4, cell * 0.08))
                    .padding(cell * 0.04)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap?(here) }
        .animation(.spring(duration: 0.3), value: bunny.eaten)
    }

    private var bunnyImage: (String, String) {
        switch mood {
        case .oops: ("coding_bunny_oops", "🐰")
        case .yay: ("coding_bunny_yay", "🐰")
        case .idle: ("coding_bunny", "🐰")
        }
    }

    private var bunnyView: some View {
        let (name, fb) = bunnyImage
        return ArtImage(name: name, fallback: fb)
            .scaleEffect(x: facingLeft ? -1 : 1, y: 1)
            .overlay {
                if let check {
                    Circle()
                        .strokeBorder(check.hit ? Palette.sage : Color.white, lineWidth: max(3, cell * 0.06))
                        .scaleEffect(1.15)
                        .keyframeAnimator(initialValue: 0.0, trigger: check.tick) { v, o in v.opacity(o) } keyframes: { _ in
                            LinearKeyframe(1, duration: 0.05)
                            LinearKeyframe(1, duration: 0.25)
                            LinearKeyframe(0, duration: 0.25)
                        }
                }
            }
            .keyframeAnimator(initialValue: CGFloat(0), trigger: bump?.tick ?? 0) { v, t in
                let d = bump?.dir ?? .right
                return v.offset(x: CGFloat(d.dx) * t * cell, y: CGFloat(d.dy) * t * cell)
            } keyframes: { _ in
                SpringKeyframe(0.22, duration: 0.12)
                SpringKeyframe(-0.08, duration: 0.14)
                SpringKeyframe(0.06, duration: 0.12)
                SpringKeyframe(0, duration: 0.2)
            }
            .shadow(color: .black.opacity(0.18), radius: 4, y: 3)
    }
}

/// 页签：好几个花园时，1 / 2 / 3，走过的画 ✓ / ✗
struct CodingGardenTabs: View {
    let count: Int
    let shown: Int
    let done: [Int: Bool]
    var enabled = true
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { i in
                Button {
                    onSelect(i)
                } label: {
                    HStack(spacing: 8) {
                        Text("花园 \(i + 1)")
                            .font(.kid(19, weight: .heavy))
                        if let ok = done[i] {
                            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(ok ? Palette.sage : Palette.coral)
                        }
                    }
                    .foregroundStyle(i == shown ? .white : Palette.ink)
                    .padding(.horizontal, 18)
                    .frame(minWidth: 96, minHeight: 56)
                    .background(Capsule().fill(i == shown ? Color(hex: 0x6FA35A) : Palette.paper))
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                }
                .buttonStyle(PressableStyle(scale: 0.94))
                .disabled(!enabled)
            }
        }
        .frame(height: CGFloat(CodingLayout.tabsHeight))
    }
}

/// 关卡页上的小图：第一个花园缩小画（画布，不用图片）
struct CodingThumb: View {
    let level: CodingLevel?

    var body: some View {
        Canvas { ctx, size in
            guard let g = level?.gardenList.first else { return }
            let c = min(size.width / CGFloat(g.width), size.height / CGFloat(g.height))
            let ox = (size.width - c * CGFloat(g.width)) / 2, oy = (size.height - c * CGFloat(g.height)) / 2
            let bg = CGRect(x: ox - c * 0.1, y: oy - c * 0.1, width: c * CGFloat(g.width) + c * 0.2, height: c * CGFloat(g.height) + c * 0.2)
            ctx.fill(Path(roundedRect: bg, cornerRadius: c * 0.3), with: .color(Color(hex: 0x6FA35A)))
            for y in 0..<g.height {
                for x in 0..<g.width {
                    let r = CGRect(x: ox + CGFloat(x) * c, y: oy + CGFloat(y) * c, width: c, height: c).insetBy(dx: c * 0.05, dy: c * 0.05)
                    let ch = g.char(x, y)
                    let base = (x + y) % 2 == 0 ? Color(hex: 0xA8D58A) : Color(hex: 0x98CB7A)
                    let fill: Color = ch == "b" ? Color(hex: 0x6FB3E8) : ch == "y" ? Color(hex: 0xF2C94C) : base
                    ctx.fill(Path(roundedRect: r, cornerRadius: c * 0.18), with: .color(fill))
                    let dot = r.insetBy(dx: c * 0.22, dy: c * 0.22)
                    switch ch {
                    case "#": ctx.fill(Path(roundedRect: r.insetBy(dx: c * 0.12, dy: c * 0.12), cornerRadius: c * 0.2), with: .color(Color(hex: 0x8A8F98)))
                    case "C": ctx.fill(Path(ellipseIn: dot), with: .color(Color(hex: 0xF08A3C)))
                    case "H": ctx.fill(Path(roundedRect: r.insetBy(dx: c * 0.14, dy: c * 0.14), cornerRadius: c * 0.1), with: .color(Color(hex: 0x9C6B3E)))
                    case "B": ctx.fill(Path(ellipseIn: dot), with: .color(.white))
                    default: break
                    }
                }
            }
        }
    }
}
