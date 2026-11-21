import SwiftUI

// 「今天的三颗星」：学一课、算一组题、下一盘棋。
// 每件事是一颗星：没做是虚线描边的空星（里面是这件事的小图标），做了就涂满颜色、打个勾。
// 天数只说"已经做到 N 天"，是一直往上加的，不说"连续"，断了一天也不会清零。

/// 五角星的形状（圆角靠描边的 lineJoin）
struct StarShape: Shape {
    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY + r.height * 0.04)
        let outer = min(r.width, r.height) * 0.5
        let inner = outer * 0.5
        var p = Path()
        for i in 0..<10 {
            let a = Double(i) * .pi / 5 - .pi / 2
            let rad = i.isMultiple(of: 2) ? outer : inner
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * rad, y: c.y + CGFloat(sin(a)) * rad)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// 一件事的那颗星
struct DailyTaskStar: View {
    let task: DailyTask
    let done: Bool
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            if done {
                StarShape()
                    .fill(LinearGradient(colors: [Color(hex: 0xFFD978), Palette.honey, Palette.coral],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(StarShape().stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: size * 0.05, lineJoin: .round)))
                    .shadow(color: Palette.coral.opacity(0.35), radius: size * 0.08, y: size * 0.06)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.26, weight: .black))
                    .foregroundStyle(.white)
                    .offset(y: size * 0.05)
            } else {
                StarShape()
                    .fill(Palette.paper.opacity(0.9))
                StarShape()
                    .stroke(Palette.inkSoft.opacity(0.4),
                            style: StrokeStyle(lineWidth: size * 0.045, lineCap: .round, lineJoin: .round,
                                               dash: [size * 0.07, size * 0.06]))
                Image(systemName: task.icon)
                    .font(.system(size: size * 0.2, weight: .heavy))
                    .foregroundStyle(Palette.inkSoft.opacity(0.65))
                    .offset(y: size * 0.05)
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(duration: 0.5, bounce: 0.45), value: done)
    }
}

/// 三样都做完的加奖：一枚小圆章 "+3"，做完了亮起来
struct DailyBonusCoin: View {
    let lit: Bool
    var size: CGFloat = 56

    var body: some View {
        VStack(spacing: -size * 0.04) {
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.22, weight: .bold))
            Text("+\(RewardRules.dailyBonus)")
                .font(.kid(size * 0.36, weight: .heavy))
                .monospacedDigit()
        }
        .foregroundStyle(lit ? .white : Palette.inkSoft.opacity(0.55))
        .frame(width: size, height: size)
        .background(
            Circle().fill(lit ? AnyShapeStyle(LinearGradient(colors: [Palette.honey, Palette.coral], startPoint: .top, endPoint: .bottom))
                              : AnyShapeStyle(Palette.cream))
        )
        .overlay(Circle().strokeBorder(lit ? .white.opacity(0.8) : Palette.inkSoft.opacity(0.22),
                                       style: StrokeStyle(lineWidth: size * 0.04, dash: lit ? [] : [size * 0.08, size * 0.06])))
        .shadow(color: lit ? Palette.coral.opacity(0.35) : .clear, radius: size * 0.1, y: size * 0.06)
    }
}

/// "已经做到 N 天"（还一天都没有时换成一句鼓励的话）
func dailyDaysText(_ n: Int) -> String { n > 0 ? "已经做到 \(n) 天" : "每天来摘三颗星" }

// MARK: - 主页上的横条

/// 主页底部的「今天的三颗星」横条：插画、标题和天数、三颗星、+3 加奖。点一下打开奖章墙的「好习惯」。
struct DailyStarsCard: View {
    let action: () -> Void
    @Environment(PlayerStore.self) private var store

    var body: some View {
        let lens = store.rewards
        Button {
            Sound.tap()
            action()
        } label: {
            GeometryReader { g in
                let h = g.size.height
                // 竖屏比较窄，放不下就依次省掉：箭头 → 星星下面的字变小 → 插画变小
                ViewThatFits(in: .horizontal) {
                    row(lens: lens, h: h, star: h * 0.5, labels: true, chevron: true)
                    row(lens: lens, h: h, star: h * 0.46, labels: true, chevron: false)
                    row(lens: lens, h: h, star: h * 0.5, labels: false, chevron: false)
                }
                .frame(width: g.size.width, height: h, alignment: .leading)
            }
            .background(
                LinearGradient(colors: [Color(hex: 0xFFF6E2), Palette.paper], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 40, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .strokeBorder(lens.dailyComplete ? Palette.honey.opacity(0.7) : .white, lineWidth: 2.5)
            )
            .softCard(radius: 40, fill: .clear)
        }
        .buttonStyle(PressableStyle(scale: 0.98))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今天的三颗星，做了\(lens.dailyCount)样，\(dailyDaysText(lens.dailyDays))。打开好习惯")
    }

    private func row(lens: RewardLens, h: CGFloat, star: CGFloat, labels: Bool, chevron: Bool) -> some View {
        HStack(spacing: h * 0.16) {
            ArtImage(name: "badge_daily", fallback: "⭐")
                .frame(width: h * 0.86, height: h * 0.86)
                .padding(.leading, h * 0.14)
            VStack(alignment: .leading, spacing: h * 0.03) {
                Text("今天的三颗星")
                    .font(.kid(h * 0.26, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill").foregroundStyle(Palette.sage)
                    Text(dailyDaysText(lens.dailyDays)).monospacedDigit()
                }
                .font(.kid(h * 0.16, weight: .bold))
                .foregroundStyle(Palette.inkSoft)
            }
            .lineLimit(1)
            .fixedSize()
            Spacer(minLength: h * 0.1)
            HStack(spacing: h * 0.12) {
                ForEach(DailyTask.allCases) { t in
                    let done = lens.dailyDone(t)
                    VStack(spacing: h * 0.02) {
                        DailyTaskStar(task: t, done: done, size: star)
                        if labels {
                            Text(t.title)
                                .font(.kid(h * 0.14, weight: .bold))
                                .foregroundStyle(done ? Palette.ink : Palette.inkSoft)
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                }
            }
            // 三颗星 → 加奖：中间一个小加号，告诉她"做完三样，再送 3 颗"
            Image(systemName: "arrow.right")
                .font(.system(size: h * 0.14, weight: .heavy))
                .foregroundStyle(Palette.inkSoft.opacity(0.45))
            DailyBonusCoin(lit: lens.dailyComplete, size: h * 0.56)
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: h * 0.16, weight: .heavy))
                    .foregroundStyle(Palette.inkSoft.opacity(0.7))
            }
        }
        .padding(.trailing, h * 0.22)
    }
}

#Preview("今天的三颗星") {
    VStack(spacing: 30) {
        DailyStarsCard {}.frame(width: 1098, height: 110)
        DailyStarsCard {}.frame(width: 738, height: 110)
        HStack {
            ForEach(DailyTask.allCases) { DailyTaskStar(task: $0, done: $0 == .learn, size: 90) }
            DailyBonusCoin(lit: false, size: 90)
            DailyBonusCoin(lit: true, size: 90)
        }
    }
    .padding()
    .background(Palette.cream)
    .environment(PlayerStore())
}
