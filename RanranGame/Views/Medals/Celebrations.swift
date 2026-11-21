import SwiftUI

// 主页上的各种庆祝：星星奖章、本领奖章、升级礼物、今天的三颗星做完。
// 它们共用一个外壳 CelebrationShell（暗下来的背景、撒花、居中的大卡片、弹出动画），
// 各自只管中间放什么。

// MARK: - 约好的奖励

/// 家长写的"约好的奖励"：一张小礼物签
struct RewardNoteTag: View {
    let text: String
    var size: CGFloat = 20
    /// 庆祝里写全"约好的奖励：…"；墙上的小签只放礼物图标和字
    var long = true

    var body: some View {
        HStack(spacing: size * 0.35) {
            Image(systemName: "gift.fill")
                .foregroundStyle(Palette.coral)
            Text(long ? "约好的奖励：\(text)" : text)
                .foregroundStyle(Palette.ink)
                .lineLimit(long ? 2 : 1)
                .minimumScaleFactor(0.7)
        }
        .font(.kid(size, weight: .heavy))
        .padding(.horizontal, size * 0.75)
        .padding(.vertical, size * 0.4)
        .background(Capsule().fill(Color(hex: 0xFFEDE4)))
        .overlay(Capsule().strokeBorder(Palette.coral.opacity(0.45),
                                        style: StrokeStyle(lineWidth: max(1.5, size * 0.08), dash: [size * 0.3, size * 0.2])))
    }
}

// MARK: - 外壳

/// 所有庆祝共用的样子：背景暗下来、撒花、大卡片从中间弹出来。
struct CelebrationShell<Hero: View, Details: View, Buttons: View>: View {
    /// 卡片最上面的一行小字，比如"新奖章！"
    let eyebrow: String
    /// 主角后面那团光的颜色
    let glow: Color
    var confetti = true
    var sound = true
    @ViewBuilder var hero: (_ size: CGFloat) -> Hero
    @ViewBuilder var details: () -> Details
    @ViewBuilder var buttons: () -> Buttons
    @State private var appeared = false

    var body: some View {
        GeometryReader { g in
            let heroSize = min(280, max(170, min(g.size.width, g.size.height) * 0.3))
            ZStack {
                Color.black.opacity(0.42).ignoresSafeArea()
                    .onTapGesture {}
                if confetti { ConfettiView() }
                VStack(spacing: 14) {
                    Text(eyebrow)
                        .font(.kid(26, weight: .heavy))
                        .foregroundStyle(Palette.coral)
                    ZStack {
                        Circle()
                            .fill(RadialGradient(colors: [glow.opacity(0.5), .clear],
                                                 center: .center, startRadius: 0, endRadius: heroSize * 0.75))
                            .frame(width: heroSize * 1.5, height: heroSize * 1.5)
                            .scaleEffect(appeared ? 1 : 0.3)
                            .opacity(appeared ? 1 : 0)
                        hero(heroSize)
                            .scaleEffect(appeared ? 1 : 0.15)
                            .rotationEffect(.degrees(appeared ? 0 : -25))
                    }
                    .frame(width: heroSize * 1.2, height: heroSize * 1.1)
                    details()
                    HStack(spacing: 16) { buttons() }
                        .padding(.top, 10)
                        .padding(.bottom, 6)
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 34)
                .frame(width: min(580, g.size.width - 64))
                .softCard(radius: 48)
                .scaleEffect(appeared ? 1 : 0.9)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            if sound { Sound.fanfare() }
            withAnimation(.spring(duration: 0.8, bounce: 0.4)) { appeared = true }
        }
    }
}

/// 庆祝卡片上的大名字
private struct CelebrationTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.kid(50, weight: .heavy))
            .foregroundStyle(Palette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

// MARK: - 星星奖章

/// 星星奖章的庆祝：奖章弹出来、撒花、名字、要几颗星星、约好的奖励。
struct MedalCelebration: View {
    let medal: Medal
    let stars: Int
    var replay = false
    let onDone: () -> Void
    @Environment(PlayerStore.self) private var store

    var body: some View {
        let reward = store.medalReward(medal)
        CelebrationShell(eyebrow: replay ? "我的奖章" : "新奖章！", glow: Color(hex: medal.base), sound: !replay) { size in
            MedalBadge(medal: medal, size: size)
        } details: {
            CelebrationTitle(text: medal.name)
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .foregroundStyle(LinearGradient(colors: [Palette.honey, Palette.coral], startPoint: .top, endPoint: .bottom))
                Text("满 \(medal.threshold) 颗星星")
                    .foregroundStyle(Palette.inkSoft)
            }
            .font(.kid(22, weight: .bold))
            if !reward.isEmpty { RewardNoteTag(text: reward, size: 21) }
        } buttons: {
            Button(replay ? "好的" : "太棒了！") {
                Sound.tap()
                onDone()
            }
            .buttonStyle(PillButtonStyle(color: Palette.coral, size: 26))
        }
    }
}

// MARK: - 本领奖章

/// 本领奖章的庆祝：章弹出来、名字、怎么拿到的、约好的奖励。毕业章换一句更隆重的话。
struct BadgeCelebration: View {
    let badge: SkillBadge
    var replay = false
    let onDone: () -> Void
    @Environment(PlayerStore.self) private var store

    var body: some View {
        let reward = store.badgeReward(badge)
        let grad = badge.kind == .graduate
        let eyebrow = replay ? "我的本领奖章" : grad ? "学会啦！毕业奖章！" : "新本领奖章！"
        CelebrationShell(eyebrow: eyebrow, glow: grad ? Color(hex: 0xF2C14B) : badge.tint, sound: !replay) { size in
            SkillBadgeView(badge: badge, size: size * (grad ? 1.12 : 1))
        } details: {
            CelebrationTitle(text: badge.name)
            if let subject = Subjects.find(badge.subject) {
                Text(subject.name)
                    .font(.kid(18, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(subject.tint))
            }
            Text(badge.how)
                .font(.kid(22, weight: .bold))
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            if !reward.isEmpty { RewardNoteTag(text: reward, size: 21) }
        } buttons: {
            Button(replay ? "好的" : "太棒了！") {
                Sound.tap()
                onDone()
            }
            .buttonStyle(PillButtonStyle(color: grad ? Color(hex: 0xD99A30) : Palette.coral, size: 26))
        }
    }
}

// MARK: - 升级礼物

/// 升级到新版本后说一次：上课、第一次赢都有星星了，以前的补给你。
struct GiftCelebration: View {
    let stars: Int
    let badges: Int
    let openWall: () -> Void
    let onDone: () -> Void

    var body: some View {
        CelebrationShell(eyebrow: "送你一份礼物！", glow: Palette.honey) { size in
            ZStack {
                ArtImage(name: "badge_daily", fallback: "🎁")
                    .frame(width: size, height: size)
                Image(systemName: "gift.fill")
                    .font(.system(size: size * 0.24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: size * 0.4, height: size * 0.4)
                    .background(Circle().fill(Palette.coral))
                    .overlay(Circle().strokeBorder(.white, lineWidth: size * 0.025))
                    .offset(x: size * 0.36, y: size * 0.34)
            }
        } details: {
            Text("现在学一课、第一次赢下一档，\n都能拿到星星啦！")
                .font(.kid(24, weight: .bold))
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .minimumScaleFactor(0.7)
            if stars > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(LinearGradient(colors: [Palette.honey, Palette.coral], startPoint: .top, endPoint: .bottom))
                    Text("补给你 \(stars) 颗星星").monospacedDigit()
                }
                .font(.kid(36, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
            if badges > 0 {
                Text("你已经有 \(badges) 枚本领奖章啦")
                    .font(.kid(24, weight: .heavy))
                    .foregroundStyle(Palette.coral)
                    .monospacedDigit()
            }
        } buttons: {
            Button("好的") {
                Sound.tap()
                onDone()
            }
            .buttonStyle(PillButtonStyle(color: Palette.cream, foreground: Palette.ink, size: 24))
            Button("去看看奖章") {
                Sound.tap()
                openWall()
            }
            .buttonStyle(PillButtonStyle(color: Palette.coral, size: 24))
        }
    }
}

// MARK: - 今天的三颗星做完

/// 轻一点、快一点的庆祝：不挡太久，两秒多自己收起来，也可以点一下就收。
struct DailyCheer: View {
    let onDone: () -> Void
    @State private var appeared = false
    @State private var lit = 0

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.22 : 0).ignoresSafeArea()
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    ForEach(Array(DailyTask.allCases.enumerated()), id: \.element) { i, t in
                        DailyTaskStar(task: t, done: lit > i, size: 76)
                            .scaleEffect(lit > i ? 1 : 0.85)
                    }
                    Image(systemName: "arrow.right")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(Palette.inkSoft.opacity(0.5))
                    DailyBonusCoin(lit: lit > 3, size: 80)
                        .scaleEffect(lit > 3 ? 1.08 : 0.9)
                }
                Text("今天的三颗星做完啦！")
                    .font(.kid(38, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("多拿 \(RewardRules.dailyBonus) 颗星星")
                    .font(.kid(22, weight: .bold))
                    .foregroundStyle(Palette.coral)
            }
            .padding(.horizontal, 44)
            .padding(.vertical, 30)
            .softCard(radius: 44)
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .task {
            withAnimation(.spring(duration: 0.5, bounce: 0.35)) { appeared = true }
            // 三颗星一颗一颗亮，然后 +3 亮
            for i in 1...4 {
                try? await Task.sleep(for: .milliseconds(i == 1 ? 350 : 260))
                guard !Task.isCancelled else { return }
                if i == 4 { Sound.fanfare() } else { Sound.step(i * 3) }
                withAnimation(.spring(duration: 0.4, bounce: 0.5)) { lit = i }
            }
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            finish()
        }
    }

    private func finish() {
        guard appeared else { return }
        withAnimation(.easeOut(duration: 0.25)) { appeared = false }
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            onDone()
        }
    }
}

#Preview("星星奖章庆祝") {
    MedalCelebration(medal: Medal.all[5], stars: 120) {}.environment(PlayerStore())
}

#Preview("本领奖章庆祝") {
    BadgeCelebration(badge: Subjects.all[1].badges.last!) {}.environment(PlayerStore())
}

#Preview("升级礼物") {
    GiftCelebration(stars: 46, badges: 5, openWall: {}, onDone: {})
}

#Preview("三颗星做完") {
    ZStack { Palette.cream.ignoresSafeArea(); DailyCheer {} }
}
