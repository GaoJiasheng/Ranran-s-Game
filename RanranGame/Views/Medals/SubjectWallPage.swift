import SwiftUI

/// 奖章墙上一个科目的一页（五子棋、象棋、围棋、加减乘除）：
/// 左边（竖屏是上面）是毕业线——圆环里套着毕业章、学会了多少、每条目标、这一科拿的星星；
/// 右边（竖屏是下面）是这一科的本领奖章格子。不滚动。
struct SubjectWallPage: View {
    let subject: Subject
    let wide: Bool
    let onSelect: (SkillBadge) -> Void
    @Environment(PlayerStore.self) private var store

    var body: some View {
        let lens = store.rewards
        // 毕业章放在毕业线的圆环里当主角，格子里放其他的
        let graduate = subject.badges.first { $0.kind == .graduate }
        let others = subject.badges.filter { $0.kind != .graduate }
        GeometryReader { g in
            if wide {
                HStack(spacing: 20) {
                    GraduationPanel(subject: subject, graduate: graduate, lens: lens, vertical: true, onSelect: onSelect)
                        .frame(width: min(440, g.size.width * 0.36))
                    grid(others, lens: lens)
                }
            } else {
                VStack(spacing: 20) {
                    GraduationPanel(subject: subject, graduate: graduate, lens: lens, vertical: false, onSelect: onSelect)
                        .frame(height: min(400, g.size.height * 0.36))
                    grid(others, lens: lens)
                }
            }
        }
    }

    private func grid(_ badges: [SkillBadge], lens: RewardLens) -> some View {
        BadgeGrid(badges: badges, lens: lens, onSelect: onSelect)
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .softCard(radius: 40)
    }
}

/// 一个科目的毕业线
struct GraduationPanel: View {
    let subject: Subject
    let graduate: SkillBadge?
    let lens: RewardLens
    /// 横屏时竖着排（圆环在上），竖屏时横着排（圆环在左）
    let vertical: Bool
    let onSelect: (SkillBadge) -> Void

    var body: some View {
        let p = lens.progress(of: subject)
        let done = lens.graduated(subject)
        GeometryReader { g in
            Group {
                if vertical {
                    let ring = min(g.size.width * 0.62, g.size.height * 0.42)
                    VStack(spacing: 14) {
                        hero(p: p, done: done, size: ring)
                        heading(done: done, center: true)
                        goals
                        Spacer(minLength: 0)
                        starsChip
                    }
                    .padding(.horizontal, 26)
                    .padding(.vertical, 24)
                } else {
                    let ring = min(g.size.height - 48, g.size.width * 0.4)
                    HStack(spacing: 26) {
                        hero(p: p, done: done, size: ring)
                        VStack(alignment: .leading, spacing: 14) {
                            heading(done: done, center: false)
                            goals
                            Spacer(minLength: 0)
                            starsChip
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
            LinearGradient(colors: [subject.tint.mixed(.white, 0.86), Palette.paper], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 40, style: .continuous)
        )
        .softCard(radius: 40, fill: .clear)
    }

    /// 圆环 + 里面的毕业章 + 底下压着的百分比
    private func hero(p: RewardProgress, done: Bool, size: CGFloat) -> some View {
        Button {
            guard let graduate else { return }
            Sound.pop()
            onSelect(graduate)
        } label: {
            ZStack {
                ProgressRing(fraction: p.fraction, tint: done ? Color(hex: 0xE0A93C) : subject.tint, lineWidth: max(8, size * 0.06))
                if let graduate {
                    SkillBadgeView(badge: graduate, earned: done, size: size * 0.84)
                }
                Text(done ? "学会啦" : percentText(p.fraction))
                    .font(.kid(max(18, size * 0.11), weight: .heavy))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .padding(.horizontal, size * 0.07)
                    .padding(.vertical, size * 0.022)
                    .background(Capsule().fill(done ? Color(hex: 0xD99A30) : subject.tint))
                    .overlay(Capsule().strokeBorder(.white, lineWidth: max(2, size * 0.012)))
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                    .offset(y: size * 0.47)
            }
            .frame(width: size, height: size)
            .padding(.bottom, size * 0.06)
        }
        .buttonStyle(PressableStyle(scale: 0.96))
        .accessibilityLabel(done ? "已经学会了\(subject.name)" : "\(subject.name)学会了\(percentText(p.fraction))")
    }

    private func heading(done: Bool, center: Bool) -> some View {
        VStack(alignment: center ? .center : .leading, spacing: 2) {
            Text(done ? "已经是" : "学会了就是")
                .font(.kid(18, weight: .bold))
                .foregroundStyle(Palette.inkSoft)
            Text(subject.graduateName)
                .font(.kid(34, weight: .heavy))
                .foregroundStyle(done ? Color(hex: 0x9A6A1E) : Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: center ? .center : .leading)
    }

    private var goals: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(lens.goals(subject)) { goal in
                GoalRow(goal: goal, tint: subject.tint)
            }
        }
    }

    private var starsChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .foregroundStyle(LinearGradient(colors: [Palette.honey, Palette.coral], startPoint: .top, endPoint: .bottom))
            Text("在\(subject.name)里拿了")
                .foregroundStyle(Palette.inkSoft)
            Text("\(lens.stars(in: subject))")
                .font(.kid(26, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .monospacedDigit()
            Text("颗星星")
                .foregroundStyle(Palette.inkSoft)
        }
        .font(.kid(19, weight: .bold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(Capsule().fill(Palette.paper))
        .overlay(Capsule().strokeBorder(Palette.honey.opacity(0.35), lineWidth: 1.5))
    }
}

/// 毕业线上的一条目标：一个圆点（做到了打勾）、标题、进度条、done/total
struct GoalRow: View {
    let goal: SubjectGoal
    let tint: Color

    var body: some View {
        let p = goal.progress
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: p.complete ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(p.complete ? tint : Palette.inkSoft.opacity(0.6))
                Text(goal.title)
                    .font(.kid(20, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Spacer(minLength: 6)
                Text("\(p.done)/\(p.total)")
                    .font(.kid(20, weight: .heavy))
                    .foregroundStyle(p.complete ? tint : Palette.inkSoft)
                    .monospacedDigit()
                    .fixedSize()
            }
            ProgressBar(fraction: p.fraction, tint: tint, track: Palette.inkSoft.opacity(0.1))
                .frame(height: 12)
                .padding(.leading, 28)
        }
    }
}

#Preview("科目页 横屏", traits: .landscapeLeft) {
    SubjectWallPage(subject: Subjects.all[1], wide: true) { _ in }
        .padding(32)
        .background(Palette.cream)
        .environment(PlayerStore())
}

#Preview("科目页 竖屏") {
    SubjectWallPage(subject: Subjects.all[3], wide: false) { _ in }
        .padding(32)
        .background(Palette.cream)
        .environment(PlayerStore())
}
