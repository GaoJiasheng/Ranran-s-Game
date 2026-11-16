import SwiftUI

/// 一颗有光泽、有厚度的棋子（类似云子），纯代码绘制，任何尺寸都清晰。
struct StoneView: View {
    let stone: Stone
    let diameter: CGFloat
    var lifted = false

    var body: some View {
        let d = diameter
        ZStack {
            Circle().fill(base)
            // 边缘的一圈暗部，让棋子看起来是鼓起来的
            Circle().fill(
                RadialGradient(colors: [.clear, .black.opacity(stone == .black ? 0.35 : 0.12)],
                               center: .center, startRadius: d * 0.30, endRadius: d * 0.52)
            )
            // 高光
            Ellipse()
                .fill(
                    RadialGradient(colors: [.white.opacity(stone == .black ? 0.55 : 0.95), .white.opacity(0)],
                                   center: .center, startRadius: 0, endRadius: d * 0.2)
                )
                .frame(width: d * 0.42, height: d * 0.30)
                .offset(x: -d * 0.16, y: -d * 0.19)
        }
        .frame(width: d, height: d)
        .shadow(color: .black.opacity(stone == .black ? 0.42 : 0.30),
                radius: lifted ? d * 0.16 : d * 0.05,
                x: lifted ? d * 0.06 : d * 0.025,
                y: lifted ? d * 0.22 : d * 0.07)
    }

    private var base: RadialGradient {
        switch stone {
        case .black:
            RadialGradient(colors: [Color(hex: 0x5C5B63), Color(hex: 0x26252B), Color(hex: 0x0D0C10)],
                           center: .init(x: 0.36, y: 0.32), startRadius: 0, endRadius: diameter * 0.72)
        case .white:
            RadialGradient(colors: [Color(hex: 0xFFFFFF), Color(hex: 0xF5F2EC), Color(hex: 0xD8D2C6)],
                           center: .init(x: 0.36, y: 0.32), startRadius: 0, endRadius: diameter * 0.72)
        }
    }
}

#Preview {
    HStack(spacing: 30) {
        StoneView(stone: .black, diameter: 120)
        StoneView(stone: .white, diameter: 120)
        StoneView(stone: .white, diameter: 120, lifted: true)
    }
    .padding(60)
    .background(Palette.wood)
}
