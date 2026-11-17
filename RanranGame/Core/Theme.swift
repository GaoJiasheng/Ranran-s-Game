import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// 整个 App 的配色：暖奶油底色 + 柔和的点缀色。
enum Palette {
    static let cream   = Color(hex: 0xF7F1E8)
    static let paper   = Color(hex: 0xFFFCF7)
    static let ink     = Color(hex: 0x2E2A35)
    static let inkSoft = Color(hex: 0x7A7180)
    static let coral   = Color(hex: 0xEE7B6B)
    static let blush   = Color(hex: 0xF4B6B0)
    static let sage    = Color(hex: 0x8DB596)
    static let honey   = Color(hex: 0xE9B872)
    static let sky     = Color(hex: 0x8EC5E8)
    static let lilac   = Color(hex: 0xB7A6E0)
    static let wood    = Color(hex: 0xE2B77A)
    static let woodDeep = Color(hex: 0xB9844A)
}

extension Font {
    static func kid(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - 背景

/// 奶油色底 + 几团很淡的彩色光晕。
struct CreamBackground: View {
    var accent: Color = Palette.coral

    var body: some View {
        GeometryReader { g in
            let r = max(g.size.width, g.size.height)
            ZStack {
                Palette.cream
                RadialGradient(colors: [accent.opacity(0.22), accent.opacity(0)],
                               center: .topLeading, startRadius: 0, endRadius: r * 0.6)
                RadialGradient(colors: [Palette.sky.opacity(0.25), Palette.sky.opacity(0)],
                               center: .bottomTrailing, startRadius: 0, endRadius: r * 0.6)
                RadialGradient(colors: [Palette.honey.opacity(0.18), Palette.honey.opacity(0)],
                               center: .topTrailing, startRadius: 0, endRadius: r * 0.45)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - 卡片 & 按钮

struct SoftCard: ViewModifier {
    var radius: CGFloat = 32
    var fill: Color = Palette.paper

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: Color(hex: 0x6B4E2E).opacity(0.10), radius: 24, y: 12)
            .shadow(color: Color(hex: 0x6B4E2E).opacity(0.06), radius: 2, y: 1)
    }
}

extension View {
    func softCard(radius: CGFloat = 32, fill: Color = Palette.paper) -> some View {
        modifier(SoftCard(radius: radius, fill: fill))
    }
}

/// 按下时微微缩小、变暗。
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.95

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.spring(duration: 0.22, bounce: 0.45), value: configuration.isPressed)
    }
}

/// 有厚度的胶囊按钮，按下去会"陷"进去。
struct PillButtonStyle: ButtonStyle {
    var color: Color = Palette.coral
    var foreground: Color = .white
    var size: CGFloat = 26

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.kid(size, weight: .heavy))
            .foregroundStyle(foreground)
            .padding(.horizontal, size * 1.15)
            .padding(.vertical, size * 0.6)
            .background(Capsule().fill(color))
            .background(Capsule().fill(color).brightness(-0.14).offset(y: pressed ? 1 : 6))
            .offset(y: pressed ? 5 : 0)
            .animation(.spring(duration: 0.16), value: pressed)
    }
}

/// 圆形图标按钮（返回、主页等）。
struct RoundIconButton: View {
    let systemName: String
    var label: String
    let action: () -> Void

    var body: some View {
        Button {
            Sound.tap()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Palette.ink)
                .frame(width: 64, height: 64)
                .softCard(radius: 32)
        }
        .buttonStyle(PressableStyle(scale: 0.9))
        .accessibilityLabel(label)
    }
}

// MARK: - 插画

/// 显示 Assets 里的插画；如果图片还没放进来，就用 emoji 顶替。
struct ArtImage: View {
    let name: String
    var fallback: String = "✨"
    var contentMode: ContentMode = .fit

    var body: some View {
        if UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: contentMode)
        } else {
            GeometryReader { g in
                Text(fallback)
                    .font(.system(size: min(g.size.width, g.size.height) * 0.62))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

/// 圆形头像：浅色底 + 插画。
struct Avatar: View {
    let image: String
    let fallback: String
    var tint: Color = Palette.blush
    var size: CGFloat = 96

    var body: some View {
        ArtImage(name: image, fallback: fallback)
            .padding(size * 0.04)
            .frame(width: size, height: size)
            .background(
                Circle().fill(
                    RadialGradient(colors: [tint.opacity(0.35), tint.opacity(0.7)],
                                   center: .init(x: 0.4, y: 0.3), startRadius: 0, endRadius: size * 0.7)
                )
            )
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: size * 0.045))
    }
}

// MARK: - 撒花

struct ConfettiView: View {
    private struct Piece {
        let color: Color
        let x: CGFloat
        let drift: CGFloat
        let delay: Double
        let duration: Double
        let spin: Double
        let size: CGSize
        let isCircle: Bool
    }

    @State private var pieces: [Piece] = (0..<90).map { _ in
        Piece(color: [Palette.coral, Palette.honey, Palette.sage, Palette.sky, Palette.lilac, Palette.blush].randomElement()!,
              x: .random(in: 0...1),
              drift: .random(in: -80...80),
              delay: .random(in: 0...0.9),
              duration: .random(in: 2.2...3.6),
              spin: .random(in: -720...720),
              size: CGSize(width: .random(in: 10...18), height: .random(in: 14...26)),
              isCircle: Bool.random())
    }
    @State private var falling = false

    var body: some View {
        GeometryReader { geo in
            ForEach(pieces.indices, id: \.self) { i in
                let p = pieces[i]
                Group {
                    if p.isCircle {
                        Circle().fill(p.color).frame(width: p.size.width, height: p.size.width)
                    } else {
                        RoundedRectangle(cornerRadius: 3).fill(p.color).frame(width: p.size.width, height: p.size.height)
                    }
                }
                .rotation3DEffect(.degrees(falling ? p.spin : 0), axis: (x: 1, y: 0.4, z: 0.2))
                .position(x: p.x * geo.size.width + (falling ? p.drift : 0),
                          y: falling ? geo.size.height + 60 : -40)
                .animation(.easeIn(duration: p.duration).delay(p.delay), value: falling)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { falling = true }
    }
}

/// 一屏的页面：放得下就固定不动，各部分按屏幕尺寸伸缩；
/// 只有窗口小到实在放不下（比如分屏缩得很窄）时，才退回可以上下滑。
struct AdaptivePage<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ViewThatFits(in: .vertical) {
            content()
            ScrollView { content() }
                .scrollBounceBehavior(.basedOnSize)
        }
    }
}
