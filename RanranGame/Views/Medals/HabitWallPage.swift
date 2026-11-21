import SwiftUI

/// 奖章墙的「好习惯」一页：今天的三颗星做了哪几样、一共做到多少天，和 4 枚好习惯奖章。
/// 没有毕业线：好习惯不用"学会"，一直做下去就好。
struct HabitWallPage: View {
    let wide: Bool
    let onSelect: (SkillBadge) -> Void
    @Environment(PlayerStore.self) private var store

    var body: some View {
        let lens = store.rewards
        GeometryReader { g in
            if wide {
                HStack(spacing: 20) {
                    TodayPanel(lens: lens, vertical: true)
                        .frame(width: min(440, g.size.width * 0.36))
                    grid(lens)
                }
            } else {
                VStack(spacing: 20) {
                    TodayPanel(lens: lens, vertical: false)
                        .frame(height: min(400, g.size.height * 0.36))
                    grid(lens)
                }
            }
        }
    }

    private func grid(_ lens: RewardLens) -> some View {
        VStack(spacing: 4) {
            Text("坚持的奖章")
                .font(.kid(24, weight: .heavy))
                .foregroundStyle(Palette.inkSoft)
                .padding(.top, 14)
            BadgeGrid(badges: Subjects.habit.badges, lens: lens, unit: " 天", onSelect: onSelect)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .softCard(radius: 40)
    }
}

/// 今天的三颗星：插画、三件事（大星星 + 名字 + 做了没有）、+3 加奖、做到多少天
private struct TodayPanel: View {
    let lens: RewardLens
    let vertical: Bool

    var body: some View {
        GeometryReader { g in
            Group {
                if vertical {
                    let art = min(g.size.width * 0.5, g.size.height * 0.26)
                    VStack(spacing: 16) {
                        ArtImage(name: "badge_daily", fallback: "⭐")
                            .frame(width: art, height: art)
                        title(center: true)
                        tasks(star: min(76, g.size.width * 0.17))
                        Spacer(minLength: 0)
                        daysChip
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                } else {
                    let art = min(g.size.height - 60, g.size.width * 0.28)
                    HStack(spacing: 24) {
                        ArtImage(name: "badge_daily", fallback: "⭐")
                            .frame(width: art, height: art)
                        VStack(alignment: .leading, spacing: 14) {
                            title(center: false)
                            tasks(star: min(76, g.size.height * 0.2))
                            Spacer(minLength: 0)
                            daysChip
                        }
                        .frame(maxHeight: .infinity)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
                }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .background(
            LinearGradient(colors: [Color(hex: 0xFFF3DA), Palette.paper], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 40, style: .continuous)
        )
        .softCard(radius: 40, fill: .clear)
    }

    private func title(center: Bool) -> some View {
        VStack(alignment: center ? .center : .leading, spacing: 2) {
            Text("今天的三颗星")
                .font(.kid(34, weight: .heavy))
                .foregroundStyle(Palette.ink)
            Text(lens.dailyComplete ? "今天都做完啦！" : "三样都做完，多拿 \(RewardRules.dailyBonus) 颗星星")
                .font(.kid(18, weight: .bold))
                .foregroundStyle(lens.dailyComplete ? Palette.coral : Palette.inkSoft)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: center ? .center : .leading)
    }

    private func tasks(star: CGFloat) -> some View {
        HStack(alignment: .top, spacing: star * 0.22) {
            ForEach(DailyTask.allCases) { t in
                let done = lens.dailyDone(t)
                VStack(spacing: 4) {
                    DailyTaskStar(task: t, done: done, size: star)
                    Text(t.title)
                        .font(.kid(18, weight: .heavy))
                        .foregroundStyle(done ? Palette.ink : Palette.inkSoft)
                    Text(done ? "做了" : "还没做")
                        .font(.kid(14, weight: .bold))
                        .foregroundStyle(done ? Palette.coral : Palette.inkSoft.opacity(0.7))
                }
                .lineLimit(1)
                .fixedSize()
            }
            DailyBonusCoin(lit: lens.dailyComplete, size: star * 0.9)
                .padding(.top, star * 0.05)
        }
        .frame(maxWidth: .infinity, alignment: vertical ? .center : .leading)
    }

    private var daysChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "leaf.fill").foregroundStyle(Palette.sage)
            Text(dailyDaysText(lens.dailyDays))
                .foregroundStyle(Palette.ink)
                .monospacedDigit()
        }
        .font(.kid(24, weight: .heavy))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Capsule().fill(Palette.paper))
        .overlay(Capsule().strokeBorder(Palette.sage.opacity(0.4), lineWidth: 1.5))
    }
}

#Preview("好习惯") {
    HabitWallPage(wide: false) { _ in }
        .padding(32)
        .background(Palette.cream)
        .environment(PlayerStore())
}
