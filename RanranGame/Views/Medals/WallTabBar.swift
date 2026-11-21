import SwiftUI

extension WallTab {
    var title: String { subject?.name ?? "星星奖章" }
    var tint: Color { subject?.tint ?? Palette.honey }
}

/// 奖章墙顶上的一排页签：星星奖章 | 五子棋 | 象棋 | 围棋 | 加减乘除 | 好习惯。
/// 每个页签下面一行小字说拿到了几枚，学会了的科目多一枚小印章。
struct WallTabBar: View {
    @Binding var selection: WallTab
    @Environment(PlayerStore.self) private var store
    @Namespace private var pill

    var body: some View {
        let lens = store.rewards
        HStack(spacing: 4) {
            ForEach(WallTab.all) { tab in
                let on = tab == selection
                Button {
                    guard !on else { return }
                    Sound.tap()
                    withAnimation(.spring(duration: 0.35, bounce: 0.2)) { selection = tab }
                } label: {
                    VStack(spacing: 1) {
                        Text(tab.title)
                            .font(.kid(22, weight: .heavy))
                        count(tab, lens: lens, on: on)
                    }
                    .foregroundStyle(on ? .white : Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .background {
                        if on {
                            Capsule().fill(tab.tint)
                                .shadow(color: tab.tint.opacity(0.4), radius: 8, y: 4)
                                .matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle(scale: 0.95))
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(5)
        .softCard(radius: 40)
    }

    @ViewBuilder
    private func count(_ tab: WallTab, lens: RewardLens, on: Bool) -> some View {
        HStack(spacing: 3) {
            if let s = tab.subject {
                if lens.graduated(s) {
                    Image(systemName: "graduationcap.fill")
                        .foregroundStyle(on ? .white : Color(hex: 0xD99A30))
                }
                Text("\(lens.earnedCount(in: s))/\(s.badges.count)")
            } else {
                Image(systemName: "star.fill")
                    .foregroundStyle(on ? .white : Palette.honey)
                Text("\(store.medalsEarned.count)/\(Medal.all.count)")
            }
        }
        .font(.kid(14, weight: .bold))
        .monospacedDigit()
        .opacity(on ? 0.95 : 0.7)
    }
}
