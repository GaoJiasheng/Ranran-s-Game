import SwiftUI

/// 一枚本领奖章：圆形的章 + 一圈 badge.tint 色的边 + 中间的插画。
/// 拿到了是满满的颜色；没拿到的画面变灰变淡，但还认得出是什么，右下角一把小锁。
/// 几种奖章稍微不一样：毕业章有金色麦穗和缎带，小伙伴章边上一圈小星星，章节章像一张小贴纸（虚线缝边）。
/// 画在 size × size 的方框里，所有尺寸都按比例算，56 到 200 都清楚。
struct SkillBadgeView: View {
    let badge: SkillBadge
    var earned: Bool = true
    var size: CGFloat = 120

    private var isGraduate: Bool { badge.kind == .graduate }

    var body: some View {
        let s = size
        // 毕业章四周要留出麦穗和缎带的位置，章面小一点
        let d = isGraduate ? s * 0.74 : s * 0.94
        ZStack {
            if isGraduate { graduateBack(d: d) }
            medallion(d: d)
                .offset(y: isGraduate ? -s * 0.04 : 0)
            if isGraduate { graduateFront(d: d) }
        }
        .frame(width: s, height: s)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(earned ? "本领奖章：\(badge.name)" : "还没拿到的本领奖章：\(badge.name)")
    }

    // MARK: 章面

    private var tint: Color { earned ? badge.tint : Color(hex: 0xCFC5B6) }
    private var light: Color { tint.mixed(.white, 0.55) }
    private var deep: Color { tint.mixed(Color(hex: 0x3A2A20), 0.35) }
    private let gold = Color(hex: 0xE9B44C)
    private let goldDeep = Color(hex: 0xC48A2C)

    private func medallion(d: CGFloat) -> some View {
        let s = size
        let rim = d * 0.085
        let inner = d - rim * 2
        return ZStack {
            // 投影
            Circle().fill(Color(hex: 0x6B4E2E).opacity(earned ? 0.22 : 0.1))
                .frame(width: d, height: d)
                .blur(radius: s * 0.025)
                .offset(y: s * 0.03)

            // 外圈
            Circle()
                .fill(LinearGradient(colors: isGraduate && earned ? [Color(hex: 0xF7DC8E), gold, goldDeep] : [light, tint, deep],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: d, height: d)

            // 里面的底色：浅浅的同色
            Circle()
                .fill(RadialGradient(colors: earned ? [Palette.paper, tint.mixed(.white, 0.78)]
                                                     : [Color(hex: 0xF6F1E8), Color(hex: 0xE9E1D4)],
                                     center: .init(x: 0.4, y: 0.3), startRadius: 0, endRadius: inner * 0.7))
                .frame(width: inner, height: inner)

            kindTrim(d: d, inner: inner)

            // 插画
            art(inner: inner)
                .frame(width: inner, height: inner)
                .clipShape(Circle())

            // 内圈的一道细边，让插画像嵌在章里
            Circle()
                .strokeBorder(LinearGradient(colors: [deep.opacity(earned ? 0.45 : 0.25), .white.opacity(0.8)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing),
                              lineWidth: max(1, s * 0.012))
                .frame(width: inner, height: inner)

            // 高光：上面一弯
            if earned {
                Ellipse()
                    .fill(LinearGradient(colors: [.white.opacity(0.42), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .frame(width: inner * 0.8, height: inner * 0.38)
                    .offset(y: -inner * 0.3)
                    .mask(Circle().frame(width: inner, height: inner))
                    .allowsHitTesting(false)
            } else {
                lock(d: d)
            }
        }
        .frame(width: d, height: d)
    }

    /// 不同种类的小装饰
    @ViewBuilder
    private func kindTrim(d: CGFloat, inner: CGFloat) -> some View {
        switch badge.kind {
        case .opponent:
            // 外圈上一圈小星星
            ForEach(0..<8, id: \.self) { i in
                Image(systemName: "star.fill")
                    .font(.system(size: max(5, d * 0.05), weight: .bold))
                    .foregroundStyle(.white.opacity(earned ? 0.85 : 0.6))
                    .offset(y: -(d - (d - inner) / 2) / 2)
                    .rotationEffect(.degrees(Double(i) * 45 + 22.5))
            }
        case .chapter, .habit:
            // 像贴纸一样，里面一圈虚线缝边
            Circle()
                .strokeBorder(tint.opacity(earned ? 0.55 : 0.4),
                              style: StrokeStyle(lineWidth: max(1, d * 0.014), lineCap: .round, dash: [d * 0.03, d * 0.03]))
                .frame(width: inner * 0.9, height: inner * 0.9)
        case .track, .graduate:
            EmptyView()
        }
    }

    @ViewBuilder
    private func art(inner: CGFloat) -> some View {
        // 各种图的留白不一样：课程封面是方图里的一群东西，小伙伴头像要铺满，小贴纸是一个小东西
        let scale: CGFloat = switch badge.kind {
        case .track: 0.92
        case .opponent: 1.0
        case .chapter: 0.62
        case .graduate, .habit: 0.84
        }
        ArtImage(name: badge.art, fallback: badge.fallbackEmoji)
            .frame(width: inner * scale, height: inner * scale)
            .offset(y: badge.kind == .opponent ? inner * 0.06 : 0)
            .saturation(earned ? 1 : 0)
            .opacity(earned ? 1 : 0.42)
            .shadow(color: earned && badge.kind == .chapter ? Color(hex: 0x6B4E2E).opacity(0.25) : .clear,
                    radius: inner * 0.03, y: inner * 0.03)
    }

    private func lock(d: CGFloat) -> some View {
        let l = max(18, d * 0.28)
        return Image(systemName: "lock.fill")
            .font(.system(size: l * 0.48, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: l, height: l)
            .background(Circle().fill(Color(hex: 0xB3A898)))
            .overlay(Circle().strokeBorder(.white, lineWidth: max(1.5, l * 0.09)))
            .offset(x: d * 0.34, y: d * 0.34)
    }

    // MARK: 毕业章：后面的缎带、两边的麦穗、顶上的星星

    private func graduateBack(d: CGFloat) -> some View {
        let s = size
        let ribbon = earned ? badge.tint : Color(hex: 0xD9D0C2)
        let ribbonDark = earned ? badge.tint.mixed(Color(hex: 0x3A2A20), 0.3) : Color(hex: 0xCBC1B2)
        return ZStack {
            RibbonTailShape()
                .fill(LinearGradient(colors: [ribbon, ribbonDark], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.17, height: s * 0.36)
                .rotationEffect(.degrees(18), anchor: .top)
                .position(x: s * 0.42, y: s * 0.7)
            RibbonTailShape()
                .fill(LinearGradient(colors: [ribbonDark, ribbon], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.17, height: s * 0.36)
                .rotationEffect(.degrees(-18), anchor: .top)
                .position(x: s * 0.58, y: s * 0.7)
        }
        .frame(width: s, height: s)
    }

    private func graduateFront(d: CGFloat) -> some View {
        let s = size
        let leaf = earned ? LinearGradient(colors: [Color(hex: 0xF5D27A), goldDeep], startPoint: .top, endPoint: .bottom)
                          : LinearGradient(colors: [Color(hex: 0xD8CFC0), Color(hex: 0xBFB4A3)], startPoint: .top, endPoint: .bottom)
        return ZStack {
            Image(systemName: "laurel.leading")
                .font(.system(size: s * 0.5, weight: .semibold))
                .foregroundStyle(leaf)
                .position(x: s * 0.13, y: s * 0.52)
            Image(systemName: "laurel.trailing")
                .font(.system(size: s * 0.5, weight: .semibold))
                .foregroundStyle(leaf)
                .position(x: s * 0.87, y: s * 0.52)
            // 顶上一颗星
            Image(systemName: "star.fill")
                .font(.system(size: s * 0.15, weight: .black))
                .foregroundStyle(leaf)
                .shadow(color: .white.opacity(0.9), radius: 0, y: -s * 0.006)
                .position(x: s * 0.5, y: s * 0.075)
        }
        .frame(width: s, height: s)
        .allowsHitTesting(false)
    }
}

/// 缎带的一条尾巴：长方形，底下剪一个 V 形缺口。
struct RibbonTailShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.16))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

#Preview("本领奖章") {
    let badges = Subjects.everything.flatMap { s in s.badges.filter { [.track, .opponent, .chapter, .graduate, .habit].contains($0.kind) }.prefix(3) }
    return VStack(spacing: 24) {
        HStack(spacing: 18) {
            ForEach(badges.prefix(8)) { SkillBadgeView(badge: $0, size: 110) }
        }
        HStack(spacing: 18) {
            ForEach(badges.prefix(8)) { SkillBadgeView(badge: $0, earned: false, size: 110) }
        }
        HStack(spacing: 24) {
            SkillBadgeView(badge: Subjects.all[1].badges.last!, size: 56)
            SkillBadgeView(badge: Subjects.all[1].badges.last!, earned: false, size: 56)
            SkillBadgeView(badge: Subjects.all[1].badges.last!, size: 200)
            SkillBadgeView(badge: Subjects.all[3].badges[2], size: 200)
            SkillBadgeView(badge: Subjects.all[0].badges[5], earned: false, size: 200)
        }
    }
    .padding()
    .background(Palette.cream)
}
