import SwiftUI

/// 在奖章墙上点一枚本领奖章：居中弹出一张小卡片，大大的章、名字、怎么拿到、做到多少、约好的奖励。
/// 点卡片外面或"好的"就收起来。
struct BadgeDetailCard: View {
    let badge: SkillBadge
    let onClose: () -> Void
    @Environment(PlayerStore.self) private var store
    @State private var appeared = false

    var body: some View {
        let lens = store.rewards
        let p = lens.progress(badge)
        let reward = store.badgeReward(badge)
        GeometryReader { g in
            let art = min(210, max(140, min(g.size.width, g.size.height) * 0.26))
            ZStack {
                Color.black.opacity(0.32).ignoresSafeArea()
                    .onTapGesture(perform: close)
                VStack(spacing: 12) {
                    SkillBadgeView(badge: badge, earned: p.complete, size: art)
                        .scaleEffect(appeared ? 1 : 0.6)
                    Text(badge.name)
                        .font(.kid(42, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(badge.how)
                        .font(.kid(22, weight: .bold))
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    progressLine(p)
                        .padding(.top, 4)
                    if !reward.isEmpty { RewardNoteTag(text: reward, size: 20) }
                    Button("好的", action: close)
                        .buttonStyle(PillButtonStyle(color: p.complete ? badge.tint : Palette.coral, size: 24))
                        .padding(.top, 8)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 30)
                .frame(width: min(520, g.size.width - 64))
                .softCard(radius: 44)
                .scaleEffect(appeared ? 1 : 0.92)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear { withAnimation(.spring(duration: 0.45, bounce: 0.35)) { appeared = true } }
    }

    @ViewBuilder
    private func progressLine(_ p: RewardProgress) -> some View {
        if p.complete {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                Text("已经拿到啦！")
            }
            .font(.kid(26, weight: .heavy))
            .foregroundStyle(badge.tint)
        } else {
            HStack(spacing: 12) {
                ProgressBar(fraction: p.fraction, tint: badge.tint, track: Palette.cream)
                    .frame(width: 200, height: 16)
                Text("\(p.done) / \(p.total)\(badge.kind == .habit ? " 天" : "")")
                    .font(.kid(26, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .monospacedDigit()
            }
        }
    }

    private func close() {
        Sound.tap()
        onClose()
    }
}

#Preview("本领奖章详情") {
    BadgeDetailCard(badge: Subjects.all[1].badges[2]) {}.environment(PlayerStore())
}
