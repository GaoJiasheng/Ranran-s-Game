import SwiftUI

/// 给家长用的按钮：长按约 1.5 秒才算数，避免孩子随手点进去。按住时底色从左往右慢慢填满。
struct ParentHoldButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @State private var pressing = false

    var body: some View {
        VStack(spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.kid(20, weight: .heavy))
                .foregroundStyle(pressing ? .white : Palette.ink)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(alignment: .leading) {
                    GeometryReader { g in
                        Capsule().fill(Palette.coral)
                            .frame(width: pressing ? g.size.width : 0)
                            // 松手立刻清零，按住时线性填满
                            .animation(pressing ? .linear(duration: 1.5) : .easeOut(duration: 0.15), value: pressing)
                    }
                }
                .background(Capsule().fill(Palette.lilac.opacity(0.3)))
                .clipShape(Capsule())
                .contentShape(Capsule())
                .onLongPressGesture(minimumDuration: 1.5, maximumDistance: 30) {
                    Sound.tap()
                    action()
                } onPressingChanged: { pressing = $0 }
            Text("家长长按打开")
                .font(.kid(13, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
        }
    }
}
