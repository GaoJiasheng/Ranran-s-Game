import SwiftUI

// MARK: - 小奖杯

/// 金 / 银 / 铜小奖杯的颜色
extension LessonCup {
    var tint: Color {
        switch self {
        case .gold: Color(hex: 0xF2B53A)
        case .silver: Color(hex: 0xA9B4C2)
        case .bronze: Color(hex: 0xCF8A55)
        }
    }

    /// 奖杯的亮面（做渐变用）
    var shine: Color {
        switch self {
        case .gold: Color(hex: 0xFFE08A)
        case .silver: Color(hex: 0xE6ECF2)
        case .bronze: Color(hex: 0xF2C49A)
        }
    }
}

/// 一个小奖杯：圆形奖牌底上一个奖杯。没拿到的画成浅浅的轮廓。
struct CupBadge: View {
    let cup: LessonCup
    var earned = true
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            if earned {
                Circle().fill(LinearGradient(colors: [cup.shine, cup.tint], startPoint: .top, endPoint: .bottom))
            } else {
                Circle().fill(Palette.ink.opacity(0.05))
            }
            Circle()
                .strokeBorder(earned ? cup.tint : Palette.ink.opacity(0.12), lineWidth: max(1.5, size * 0.06))
            Image(systemName: "trophy.fill")
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundStyle(earned ? Color.white : Palette.ink.opacity(0.16))
                .shadow(color: earned ? cup.tint.opacity(0.9) : .clear, radius: 1, y: 1)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(earned ? cup.name : "还没拿到\(cup.name)")
    }
}

// MARK: - 学完一课

/// 学完一课（或者练完一遍）的结算页：学会了什么、这次拿到哪个小奖杯、发了几颗星星、接下来去哪里。
struct LessonDoneOverlay: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.lessonNavigator) private var navigator
    let flow: LessonFlow
    let accent: Color
    let onNextLesson: ((TutorialLesson) -> Void)?
    let onLeave: () -> Void

    @State private var appeared = false
    @State private var badge = false
    @State private var cupIn = false
    @State private var starsIn = false

    private var course: TutorialCourse { flow.course }
    private var track: TutorialTrack? { course.track(of: flow.lesson.id) }

    /// 学完这一课，下一组是不是刚刚解锁
    private var unlockedTrack: TutorialTrack? {
        let tracks = course.tracks
        guard flow.mode.isLesson, !flow.nextTrackOpenBefore,
              let i = tracks.firstIndex(where: { $0.lessons.contains { $0.id == flow.lesson.id } }),
              i + 1 < tracks.count, store.trackUnlocked(course, i + 1) else { return nil }
        return tracks[i + 1]
    }

    private var nextLesson: TutorialLesson? {
        guard flow.mode.isLesson else { return nil }
        let all = course.lessons
        guard let i = all.firstIndex(of: flow.lesson), i + 1 < all.count else { return nil }
        let next = all[i + 1]
        // 下一课在还没解锁的组里就不给按钮
        let ti = course.tracks.firstIndex { $0.lessons.contains(next) } ?? 0
        return store.trackUnlocked(course, ti) ? next : nil
    }

    /// 这一组刚学完（或者学的是这一组最后一课）：去和电脑下一盘
    private var playLevel: Int? {
        guard flow.mode.isLesson, navigator.playGame != nil, let track, store.trackDone(course, track),
              !flow.trackDoneBefore || track.lessons.last?.id == flow.lesson.id else { return nil }
        return course.playLevel(after: track)
    }

    /// 这一次拿到的比以前的好
    private var improved: Bool {
        guard let before = flow.cupBefore else { return false }
        return flow.cup > before
    }

    private var bestCup: LessonCup { max(flow.cup, flow.cupBefore ?? .bronze) }

    private var headline: String {
        switch flow.mode {
        case .lesson: "学会啦！"
        case .practice: "练完啦！"
        case .review: "复习完啦！"
        }
    }

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            Color.black.opacity(0.12).ignoresSafeArea()
            ConfettiView()
            VStack(spacing: 16) {
                emblem
                    .scaleEffect(badge ? 1 : 0.3)
                    .rotationEffect(.degrees(badge ? 0 : -30))
                    .padding(.top, -96)

                Text(headline)
                    .font(.kid(50, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                if flow.mode.isLesson {
                    Text("「\(flow.lesson.title)」：\(flow.lesson.learned)")
                        .font(.kid(23, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }

                scoreCard

                starLine

                if let t = unlockedTrack {
                    HStack(spacing: 14) {
                        ArtImage(name: t.art, fallback: "🔓", contentMode: .fit)
                            .frame(width: 64, height: 64)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("新课程解锁！")
                                .font(.kid(17, weight: .heavy))
                                .foregroundStyle(Palette.coral)
                            Text(t.title)
                                .font(.kid(24, weight: .heavy))
                                .foregroundStyle(Palette.ink)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(accent.opacity(0.22), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .transition(.scale.combined(with: .opacity))
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { buttons }
                    VStack(spacing: 14) { buttons }
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 52)
            .padding(.bottom, 32)
            .padding(.top, 20)
            .frame(minWidth: 540)
            .softCard(radius: 44)
            .padding(.horizontal, 24)
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)
        }
        .task {
            Sound.fanfare()
            withAnimation(.spring(duration: 0.5, bounce: 0.4)) { appeared = true }
            withAnimation(.spring(duration: 0.7, bounce: 0.55).delay(0.25)) { badge = true }
            if !flow.mode.isLesson {
                withAnimation(.spring(duration: 0.55, bounce: 0.55).delay(0.6)) { starsIn = true }
            }
            switch flow.mode {
            case .lesson:
                await VoiceOver.shared.speak(TutorLines.lessonDone(flow.lesson.learned))
                guard !Task.isCancelled else { return }
                if flow.cup == .gold { Sound.sparkle() } else { Sound.pop() }
                withAnimation(.spring(duration: 0.55, bounce: 0.6)) { cupIn = true }
                withAnimation(.spring(duration: 0.55, bounce: 0.55).delay(0.3)) { starsIn = true }
                await VoiceOver.shared.speak(flow.cup.line)
                guard !Task.isCancelled else { return }
                if unlockedTrack != nil {
                    Sound.record()
                    await VoiceOver.shared.speak(TutorLines.trackUnlocked)
                } else if playLevel != nil {
                    await VoiceOver.shared.speak(TutorialKits.find(course.game)?.goPlayLine ?? TutorLines.goPlay)
                }
            case .practice:
                await VoiceOver.shared.speak(TutorLines.practiceDone)
            case .review:
                await VoiceOver.shared.speak(TutorLines.reviewDone)
            }
        }
    }

    /// 上面的大圆章：这一课的图标；上课时右下角盖一个这次拿到的小奖杯
    private var emblem: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Palette.honey, Palette.coral], startPoint: .top, endPoint: .bottom))
                    .frame(width: 150, height: 150)
                    .shadow(color: Palette.honey.opacity(0.6), radius: 18)
                Image(systemName: flow.lesson.icon)
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(.white)
            }
            if flow.mode.isLesson {
                CupBadge(cup: flow.cup, size: 62)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 4))
                    .shadow(color: flow.cup.tint.opacity(0.6), radius: 8, y: 3)
                    .offset(x: 12, y: 6)
                    .scaleEffect(cupIn ? 1 : 0.1)
                    .opacity(cupIn ? 1 : 0)
            }
        }
    }

    /// 这一次的成绩：每道题一个小圆圈（一次做对是绿勾），上课时再摆出三个奖杯
    private var scoreCard: some View {
        VStack(spacing: 10) {
            if flow.mode.isLesson {
                HStack(alignment: .bottom, spacing: 22) {
                    ForEach(LessonCup.allCases, id: \.self) { c in
                        VStack(spacing: 4) {
                            CupBadge(cup: c, earned: c == flow.cup, size: c == flow.cup ? 52 : 36)
                                .scaleEffect(c == flow.cup && cupIn ? 1.06 : 1)
                            Text(c.name)
                                .font(.kid(14, weight: .heavy))
                                .foregroundStyle(c == flow.cup ? Palette.ink : Palette.inkSoft.opacity(0.6))
                        }
                    }
                }
                .frame(height: 76, alignment: .bottom)
            }
            HStack(spacing: 8) {
                ForEach(Array(flow.taskResults.enumerated()), id: \.offset) { _, ok in
                    Image(systemName: ok ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(ok ? Palette.sage : Palette.coral.opacity(0.75))
                }
            }
            .accessibilityHidden(true)
            Text(caption)
                .font(.kid(18, weight: .bold))
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Palette.cream.opacity(0.85), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    /// 这一次发的星星："★★ +2 颗星星"；复习今天已经给过就说一声明天再来。
    /// 上课没发星星时不在这里说，下面的小字已经告诉她拿到金杯还能再得几颗。
    @ViewBuilder private var starLine: some View {
        if let n = flow.starsPaid, n > 0 {
            HStack(spacing: 10) {
                HStack(spacing: 2) {
                    ForEach(0..<min(n, 3), id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: [Palette.honey, Palette.coral],
                                                            startPoint: .top, endPoint: .bottom))
                            .shadow(color: Palette.honey.opacity(0.6), radius: 6)
                    }
                }
                Text("+\(n) 颗星星")
                    .font(.kid(26, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .monospacedDigit()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
            .background(Palette.honey.opacity(0.24), in: Capsule())
            .scaleEffect(starsIn ? 1 : 0.3)
            .opacity(starsIn ? 1 : 0)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("得到 \(n) 颗星星")
        } else if flow.mode == .review, flow.starsPaid == 0 {
            Label("今天的复习星星已经拿过啦，明天再来", systemImage: "star.fill")
                .font(.kid(19, weight: .bold))
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .opacity(starsIn ? 1 : 0)
        }
    }

    private var caption: String {
        guard flow.taskCount > 0 else { return "认真看完了每一步" }
        let score = "一次就做对 \(flow.firstTryCount) / \(flow.taskCount) 题"
        guard flow.mode.isLesson else { return score }
        if flow.cup == .gold { return score + "，拿到金杯！" }
        let best = improved ? "，比上次更好！" : (bestCup > flow.cup ? "，最好是\(bestCup.name)" : "")
        // 星星按最好的奖杯给：还没拿过金杯，就告诉她金杯还能再得几颗
        let more = RewardRules.lessonStars(cup: LessonCup.gold.rawValue) - RewardRules.lessonStars(cup: bestCup.rawValue)
        let goal = more > 0 ? "拿到金杯，还能再得 \(more) 颗星星" : "每一题都一次做对，就能拿金杯"
        return score + best + "\n" + goal
    }

    @ViewBuilder
    private var buttons: some View {
        let hasNext = nextLesson != nil && onNextLesson != nil
        if let next = nextLesson, let onNextLesson {
            Button { Sound.tap(); onNextLesson(next) } label: {
                Label("下一课", systemImage: "arrow.right")
            }
            .buttonStyle(PillButtonStyle(color: Palette.coral, size: 22))
        }
        if let level = playLevel, let play = navigator.playGame {
            Button { Sound.start(); play(level) } label: {
                Label(TutorialKits.find(course.game)?.goPlayTitle ?? "去下一盘", systemImage: "flag.checkered")
            }
            .buttonStyle(PillButtonStyle(color: hasNext ? Palette.sage : Palette.coral, size: 22))
        }
        if canAgain {
            Button { Sound.tap(); if let again = makeAgain() { navigator.open(again) } } label: {
                Label(againTitle, systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(PillButtonStyle(color: Palette.honey, size: 22))
        }
        Button { Sound.tap(); onLeave() } label: {
            Label(navigator.leaveTitle, systemImage: navigator.leaveTitle == "课程表" ? "list.bullet" : "arrow.uturn.backward")
        }
        .buttonStyle(PillButtonStyle(color: Palette.paper, foreground: Palette.ink, size: 22))
    }

    private var againTitle: String {
        switch flow.mode {
        case .lesson: "再来一次拿金杯"
        case .practice: "再练一次"
        case .review: "再来一组"
        }
    }

    /// 上课拿了金杯就不用再来；练习、复习总可以再来一组
    private var canAgain: Bool { flow.mode != .lesson || flow.cup != .gold }

    /// 再来一次：上课没拿金杯就重新上；练习、复习换一组新的方向
    private func makeAgain() -> LessonRoute? {
        switch flow.mode {
        case .lesson:
            return flow.cup == .gold ? nil : .lesson(flow.lesson)
        case let .practice(id):
            return course.lesson(id).flatMap { LessonRoute.practice($0, game: course.game) }
        case .review:
            return LessonRoute.review(course, store: store)
        }
    }
}
