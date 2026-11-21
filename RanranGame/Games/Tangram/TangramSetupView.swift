import SwiftUI

/// 占位：七巧板的首页，还没做。
struct TangramSetupView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            CreamBackground()
            VStack(spacing: 24) {
                Text("七巧板").font(.kid(54, weight: .heavy)).foregroundStyle(Palette.ink)
                Text("正在精心制作中…").font(.kid(22, weight: .semibold)).foregroundStyle(Palette.inkSoft)
                RoundIconButton(systemName: "house.fill", label: "回主页") { dismiss() }
            }
        }
    }
}
