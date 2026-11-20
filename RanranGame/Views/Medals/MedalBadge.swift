import SwiftUI

private extension Color {
    /// 往另一种颜色靠 t（0...1）
    func mixed(_ other: Color, _ t: Double) -> Color {
        var a: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var b: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        UIColor(self).getRed(&a.0, green: &a.1, blue: &a.2, alpha: &a.3)
        UIColor(other).getRed(&b.0, green: &b.1, blue: &b.2, alpha: &b.3)
        let k = CGFloat(t)
        return Color(.sRGB, red: a.0 + (b.0 - a.0) * k, green: a.1 + (b.1 - a.1) * k, blue: a.2 + (b.2 - a.2) * k)
    }
}

/// 缎带的一条尾巴：长方形，底下剪一个 V 形缺口。
private struct RibbonTail: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.14))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// 一枚奖章：缎带 + 外圈 + 内圆盘 + 图案 + 高光。没拿到的是浅浅压在纸上的剪影，上面写着要几颗星星。
/// 画在 size × size 的方框里，所有尺寸都按 size 的比例算，56 到 180 都清楚。
struct MedalBadge: View {
    let medal: Medal
    var unlocked: Bool = true
    var size: CGFloat = 120

    var body: some View {
        let s = size
        let d = s * 0.74                       // 圆盘直径
        let cy = s * 0.62                      // 圆盘中心的高度
        let base = Color(hex: medal.base)
        let light = base.mixed(.white, 0.55)
        let deep = base.mixed(Color(hex: 0x3A2A20), 0.38)
        let ribbon = unlocked ? Color(hex: medal.ribbon) : Color(hex: 0xD9D0C2)
        let ribbonDark = unlocked ? Color(hex: medal.ribbon).mixed(Color(hex: 0x3A2A20), 0.25) : Color(hex: 0xCBC1B2)

        ZStack {
            // 缎带，压在圆盘后面
            RibbonTail()
                .fill(LinearGradient(colors: [ribbon, ribbonDark], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.2, height: s * 0.5)
                .rotationEffect(.degrees(13), anchor: .top)
                .position(x: s * 0.5 - s * 0.085, y: s * 0.25)
            RibbonTail()
                .fill(LinearGradient(colors: [ribbonDark, ribbon.mixed(Color(hex: 0x3A2A20), 0.4)], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.2, height: s * 0.5)
                .rotationEffect(.degrees(-13), anchor: .top)
                .position(x: s * 0.5 + s * 0.085, y: s * 0.25)

            disc(d: d, base: base, light: light, deep: deep)
                .position(x: s * 0.5, y: cy)
        }
        .frame(width: s, height: s)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(unlocked ? "奖章：\(medal.name)" : "还没拿到的奖章：\(medal.name)，需要\(medal.threshold)颗星星")
    }

    @ViewBuilder
    private func disc(d: CGFloat, base: Color, light: Color, deep: Color) -> some View {
        let s = size
        let inner = d * 0.76
        ZStack {
            // 投影
            Circle().fill(Color(hex: 0x6B4E2E).opacity(unlocked ? 0.25 : 0.12))
                .frame(width: d, height: d)
                .blur(radius: s * 0.03)
                .offset(y: s * 0.035)

            // 外圈（金属边）
            Circle()
                .fill(unlocked
                      ? LinearGradient(colors: [light, base, deep], startPoint: .topLeading, endPoint: .bottomTrailing)
                      : LinearGradient(colors: [Color(hex: 0xF3EDE3), Color(hex: 0xD3C9BA)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: d, height: d)
            // 外圈里面的一道凹槽
            Circle()
                .strokeBorder(unlocked
                              ? LinearGradient(colors: [deep.opacity(0.7), light.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
                              : LinearGradient(colors: [Color(hex: 0xC4B9A9), Color.white.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing),
                              lineWidth: s * 0.02)
                .frame(width: d * 0.9, height: d * 0.9)

            // 内圆盘
            Circle()
                .fill(unlocked
                      ? RadialGradient(colors: [light, base, base.mixed(deep, 0.45)], center: .init(x: 0.35, y: 0.28),
                                       startRadius: 0, endRadius: inner * 0.85)
                      : RadialGradient(colors: [Color(hex: 0xF2ECE1), Color(hex: 0xE2D9CB)], center: .init(x: 0.4, y: 0.3),
                                       startRadius: 0, endRadius: inner * 0.8))
                .frame(width: inner, height: inner)
                .overlay(
                    Circle().strokeBorder(unlocked
                                          ? LinearGradient(colors: [.white.opacity(0.7), deep.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                          : LinearGradient(colors: [Color(hex: 0xBFB4A3).opacity(0.8), .white], startPoint: .topLeading, endPoint: .bottomTrailing),
                                          lineWidth: s * 0.014)
                )

            // 一圈小点点
            Circle()
                .strokeBorder(unlocked ? Color.white.opacity(0.55) : Color(hex: 0xBFB4A3).opacity(0.45),
                              style: StrokeStyle(lineWidth: s * 0.014, lineCap: .round, dash: [0.1, s * 0.034]))
                .frame(width: d * 0.84, height: d * 0.84)

            // 图案
            Image(systemName: medal.emblem)
                .font(.system(size: s * 0.3, weight: .black))
                .foregroundStyle(unlocked
                                 ? LinearGradient(colors: [.white, Color.white.mixed(base, 0.3)], startPoint: .top, endPoint: .bottom)
                                 : LinearGradient(colors: [Color(hex: 0xC2B8A8), Color(hex: 0xB3A898)], startPoint: .top, endPoint: .bottom))
                .shadow(color: unlocked ? deep.opacity(0.55) : .white.opacity(0.9),
                        radius: 0, x: 0, y: s * 0.012)
                .shadow(color: unlocked ? deep.opacity(0.3) : .clear, radius: s * 0.02, y: s * 0.025)
                .offset(y: unlocked ? 0 : -s * 0.045)
                .frame(width: inner * 0.8, height: inner * 0.8)

            if !unlocked {
                HStack(spacing: s * 0.012) {
                    Image(systemName: "star.fill").font(.system(size: max(8, s * 0.1), weight: .bold))
                    Text("\(medal.threshold)").font(.kid(max(9, s * 0.125), weight: .heavy)).monospacedDigit()
                }
                .foregroundStyle(Color(hex: 0x9A8F7F))
                .shadow(color: .white.opacity(0.9), radius: 0, y: s * 0.008)
                .offset(y: inner * 0.31)
            }

            // 高光：左上角一弯月牙
            if unlocked {
                Ellipse()
                    .fill(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .frame(width: inner * 0.78, height: inner * 0.42)
                    .offset(y: -inner * 0.27)
                    .mask(Circle().frame(width: inner, height: inner))
                Image(systemName: "sparkle")
                    .font(.system(size: s * 0.1, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
                    .offset(x: -d * 0.31, y: -d * 0.31)
            }
        }
        .frame(width: d, height: d)
    }
}

#Preview("奖章") {
    ScrollView {
        VStack(spacing: 24) {
            HStack(spacing: 20) {
                ForEach(Medal.all.prefix(6)) { MedalBadge(medal: $0, size: 100) }
            }
            HStack(spacing: 20) {
                ForEach(Medal.all.suffix(6)) { MedalBadge(medal: $0, unlocked: false, size: 100) }
            }
            HStack(spacing: 20) {
                MedalBadge(medal: Medal.all[4], size: 56)
                MedalBadge(medal: Medal.all[4], unlocked: false, size: 56)
                MedalBadge(medal: Medal.all[8], size: 180)
                MedalBadge(medal: Medal.all[8], unlocked: false, size: 180)
            }
        }
        .padding()
    }
    .background(Palette.cream)
}
