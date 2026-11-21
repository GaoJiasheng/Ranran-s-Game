import SwiftUI

// 奖章墙的两个入口：「我的」里的一张卡片，主页星星数下面的小提示。

// MARK: - 「我的」里的入口

/// 「我的」里的一行：最近拿到的奖章 + 到下一枚的进度 + 本领奖章拿了几枚，点开是奖章墙。
struct MedalSummaryCard: View {
    @Environment(PlayerStore.self) private var store
    @State private var wall: WallTab?

    var body: some View {
        let latest = store.medalsEarned.last
        let lens = store.rewards
        Button {
            Sound.tap()
            wall = .stars
        } label: {
            HStack(spacing: 18) {
                MedalBadge(medal: latest ?? Medal.all[0], unlocked: latest != nil, size: 92)
                    .frame(width: 92, height: 92)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("我的奖章")
                            .font(.kid(26, weight: .heavy))
                            .foregroundStyle(Palette.ink)
                        Text("\(store.medalsEarned.count) / \(Medal.all.count)")
                            .font(.kid(18, weight: .bold))
                            .foregroundStyle(Palette.inkSoft)
                            .monospacedDigit()
                    }
                    .lineLimit(1)
                    NextMedalProgress(textSize: 19, showName: false)
                    // 本领奖章：一枚小圆章 + 拿了几枚（「我的」左栏只有 420 宽，单独占一行）
                    HStack(spacing: 6) {
                        Image(systemName: "rosette")
                            .foregroundStyle(Palette.coral)
                        Text("本领奖章")
                            .foregroundStyle(Palette.inkSoft)
                        Text("\(lens.earnedBadgeCount) / \(Subjects.allBadges.count)")
                            .foregroundStyle(Palette.ink)
                            .monospacedDigit()
                    }
                    .font(.kid(18, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Palette.inkSoft)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .softCard(radius: 40)
        }
        .buttonStyle(PressableStyle(scale: 0.97))
        .accessibilityLabel("我的奖章，本领奖章\(lens.earnedBadgeCount)枚")
        .fullScreenCover(item: $wall) { MedalWallView(tab: $0).statusBarHidden() }
    }
}

// MARK: - 主页上的小提示

/// 星星数下面一枚小奖章 + "还差 N 颗"，点一下打开奖章墙。
struct MedalHint: View {
    @Environment(PlayerStore.self) private var store
    let action: () -> Void

    var body: some View {
        let stars = store.medalStars
        let next = store.nextMedal
        let left = next.map { max(1, $0.threshold - stars) } ?? 0
        Button {
            Sound.tap()
            action()
        } label: {
            HStack(spacing: 6) {
                MedalBadge(medal: next ?? Medal.all.last!, unlocked: next == nil, size: 28)
                    .frame(width: 28, height: 28)
                Text(next == nil ? "奖章全齐" : "还差 \(left) 颗")
                    .font(.kid(16, weight: .bold))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
                    .monospacedDigit()
            }
            .padding(.leading, 8)
            .padding(.trailing, 14)
            .frame(height: 30)
            .background(Palette.paper.opacity(0.75), in: Capsule())
        }
        .buttonStyle(PressableStyle(scale: 0.94))
        .accessibilityLabel(next == nil ? "奖章全部拿到了，打开奖章墙" : "还差\(left)颗星星拿到奖章，打开奖章墙")
    }
}

#Preview("「我的」入口") {
    MedalSummaryCard().environment(PlayerStore()).padding().frame(width: 520).background(Palette.cream)
}
