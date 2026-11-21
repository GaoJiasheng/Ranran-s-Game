import SwiftUI

// MARK: - 奖章墙

/// 全屏的奖章墙。顶上一排页签：星星奖章 | 每个科目 | 好习惯（按 Subjects.everything，以后加了科目自动多一页）。
/// 每一页都是固定的格子，不滚动。
struct MedalWallView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var tab: WallTab
    /// 点一枚拿到的星星奖章，再看一遍它的庆祝
    @State private var replay: Medal?
    /// 点一枚本领奖章，看它的详情
    @State private var detail: SkillBadge?

    init(tab: WallTab = .stars) {
        _tab = State(initialValue: WallTab.all.contains(tab) ? tab : .stars)
    }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            ZStack {
                CreamBackground(accent: tab.tint)
                    .animation(.easeInOut(duration: 0.4), value: tab)
                VStack(spacing: 20) {
                    HStack(spacing: 16) {
                        WallTabBar(selection: $tab)
                        RoundIconButton(systemName: "xmark", label: "关闭") { dismiss() }
                    }

                    Group {
                        if let s = tab.subject {
                            if s.id == Subjects.habit.id {
                                HabitWallPage(wide: wide, onSelect: select)
                            } else {
                                SubjectWallPage(subject: s, wide: wide, onSelect: select)
                            }
                        } else {
                            StarMedalsPage(wide: wide) { m in
                                withAnimation(.spring(duration: 0.4, bounce: 0.3)) { replay = m }
                            }
                        }
                    }
                    .id(tab)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, wide ? 32 : 28)
                .padding(.vertical, 24)
                .frame(maxWidth: 1300)
                .frame(maxWidth: .infinity)

                if let m = replay {
                    MedalCelebration(medal: m, stars: store.medalStars, replay: true) {
                        withAnimation(.easeOut(duration: 0.25)) { replay = nil }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
                if let b = detail {
                    BadgeDetailCard(badge: b) {
                        withAnimation(.easeOut(duration: 0.2)) { detail = nil }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
    }

    private func select(_ badge: SkillBadge) {
        withAnimation(.spring(duration: 0.35)) { detail = badge }
    }
}

// MARK: - 星星奖章这一页

/// 12 枚星星奖章：上面一条"再拿 N 颗"，下面固定的格子，横屏 4×3，竖屏 3×4。
struct StarMedalsPage: View {
    let wide: Bool
    let onReplay: (Medal) -> Void
    @Environment(PlayerStore.self) private var store

    var body: some View {
        let cols = wide ? 4 : 3
        let rows = Medal.all.count / cols
        VStack(spacing: 20) {
            progressCard
            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<cols, id: \.self) { c in
                            cell(Medal.all[r * cols + c])
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .softCard(radius: 40)
        }
    }

    private var progressCard: some View {
        let next = store.nextMedal
        return HStack(spacing: 20) {
            MedalBadge(medal: next ?? Medal.all.last!, unlocked: next == nil, size: 84)
                .frame(width: 84, height: 84)
            NextMedalProgress(textSize: 26)
            Text("\(store.medalsEarned.count) / \(Medal.all.count)")
                .font(.kid(30, weight: .heavy))
                .foregroundStyle(Palette.inkSoft)
                .monospacedDigit()
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .softCard(radius: 36)
    }

    private func cell(_ medal: Medal) -> some View {
        let unlocked = store.hasMedal(medal)
        let reward = store.medalReward(medal)
        return GeometryReader { g in
            let badge = max(56, min(180, g.size.width * 0.82, g.size.height - 78))  // 名字、门槛（或约好的奖励）两行字 + 和下一排缎带之间留一点空
            Button {
                guard unlocked else { Sound.nope(); return }
                Sound.pop()
                onReplay(medal)
            } label: {
                VStack(spacing: 4) {
                    MedalBadge(medal: medal, unlocked: unlocked, size: badge)
                    Text(medal.name)
                        .font(.kid(22, weight: .heavy))
                        .foregroundStyle(unlocked ? Palette.ink : Palette.inkSoft.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    // 家长约好了奖励的，这一行换成小礼物签；没有就写要几颗星星
                    if reward.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill").font(.system(size: 13, weight: .bold))
                            Text("\(medal.threshold)").font(.kid(16, weight: .bold)).monospacedDigit()
                        }
                        .foregroundStyle(unlocked ? Palette.honey : Palette.inkSoft.opacity(0.6))
                        .frame(height: 24)
                    } else {
                        RewardNoteTag(text: reward, size: 14, long: false)
                            .frame(maxWidth: g.size.width - 12)
                            .frame(height: 24)
                    }
                }
                .frame(width: g.size.width, height: g.size.height)
            }
            .buttonStyle(PressableStyle(scale: 0.94))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 到下一枚奖章的进度

/// "再拿 N 颗星星" + 一条细细的进度条。
struct NextMedalProgress: View {
    var textSize: CGFloat = 24
    var showName = true
    @Environment(PlayerStore.self) private var store

    var body: some View {
        let stars = store.medalStars
        if let next = store.nextMedal {
            let from = Medal.previousThreshold(before: next)
            let span = max(next.threshold - from, 1)
            let fraction = min(max(Double(stars - from) / Double(span), 0), 1)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("再拿 \(max(1, next.threshold - stars)) 颗星星")
                        .font(.kid(textSize, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                    if showName {
                        Text("解锁「\(next.name)」")
                            .font(.kid(textSize * 0.72, weight: .semibold))
                            .foregroundStyle(Palette.inkSoft)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                ProgressBar(fraction: fraction, tint: Palette.coral)
                    .frame(height: 10)
            }
        } else {
            Text("所有奖章都拿到啦！")
                .font(.kid(textSize, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

#Preview("奖章墙") {
    MedalWallView().environment(PlayerStore())
}

#Preview("奖章墙 象棋") {
    MedalWallView(tab: WallTab(id: "xiangqi")).environment(PlayerStore())
}

#Preview("奖章墙 好习惯", traits: .landscapeLeft) {
    MedalWallView(tab: .daily).environment(PlayerStore())
}
