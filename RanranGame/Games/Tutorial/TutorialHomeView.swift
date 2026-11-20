import SwiftUI

/// 一个游戏的「教学」课程表：几组课程排成一排（竖屏 2×2），基础一直开着，后面的学完前一组才解锁。
/// 学完的课显示小奖杯，可以「练一练」；右上角的「复习」从学过的课里随机抽题。
struct TutorialHomeView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let game: String
    let accent: Color
    /// 还在制作中的一组（只显示封面）
    var upcoming: (title: String, subtitle: String, art: String)? = nil
    /// 学完一组后「去下一盘」：回到游戏首页并选好这一档
    var onPlay: ((Int) -> Void)? = nil

    @State private var course: TutorialCourse?
    @State private var playing: LessonRoute?
    @State private var appeared = false

    init(game: String, accent: Color, upcoming: (title: String, subtitle: String, art: String)? = nil,
         onPlay: ((Int) -> Void)? = nil) {
        self.game = game
        self.accent = accent
        self.upcoming = upcoming
        self.onPlay = onPlay
        _course = State(initialValue: TutorialCourse.load(game))
    }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            ZStack {
                CreamBackground(accent: accent)
                if let course {
                    VStack(spacing: 22) {
                        header(course)
                        grid(course, landscape: landscape)
                            .frame(maxHeight: .infinity)
                    }
                    .padding(.horizontal, 36)
                    .padding(.vertical, 26)
                    .frame(maxWidth: 1400)
                    .frame(maxWidth: .infinity)
                } else {
                    Text("教学内容没有找到")
                        .font(.kid(26, weight: .bold))
                        .foregroundStyle(Palette.inkSoft)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.3)) { appeared = true }
            if let course { store.rememberOpenTracks(course) }
            #if DEBUG
            // 调试截图用：启动参数 -lesson x4 直接打开那一课；再加 -practice YES 打开它的「练一练」；-review YES 打开「复习」
            if playing == nil, let course {
                let d = UserDefaults.standard
                // -tutorCups YES：把这门课的每一课都记成学完，金银铜轮着来（看课程表、「我的」、复习用）
                if d.bool(forKey: "tutorCups"), store.lessonsDone(course) == 0 {
                    for (i, l) in course.lessons.enumerated() {
                        store.recordLesson(course.game, l.id, cup: LessonCup(rawValue: 3 - i % 3) ?? .bronze)
                    }
                    store.rememberOpenTracks(course)
                }
                if d.bool(forKey: "review") {
                    playing = LessonRoute.review(course, store: store)
                } else if let id = d.string(forKey: "lesson"), let l = course.lesson(id) {
                    playing = d.bool(forKey: "practice") ? LessonRoute.practice(l, game: game) : .lesson(l)
                }
            }
            #endif
        }
        .navigationDestination(item: $playing) { route in
            if let course {
                LessonScreen(course: course, route: route) { playing = .lesson($0) }
                    .id(route)
                    .environment(\.lessonNavigator, LessonNavigator(open: { playing = $0 }, playGame: onPlay))
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
    }

    private func header(_ course: TutorialCourse) -> some View {
        let done = store.lessonsDone(course), total = course.lessons.count
        return HStack(spacing: 18) {
            RoundIconButton(systemName: "chevron.left", label: "返回") { dismiss() }
            VStack(alignment: .leading, spacing: 4) {
                Text(course.title)
                    .font(.kid(44, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(done == 0 ? "从基础规则开始，一步一步学" : "已经学会 \(done) / \(total) 课")
                    .font(.kid(19, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if course.canReview(store) {
                ReviewButton(game: course.game, accent: accent) {
                    Sound.start()
                    playing = LessonRoute.review(course, store: store)
                }
                .fixedSize()
            }
            if let next = store.nextLesson(course) {
                Button {
                    Sound.start()
                    playing = .lesson(next)
                } label: {
                    Label(done == 0 ? "开始学：\(next.title)" : "继续学：\(next.title)", systemImage: "play.fill")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .buttonStyle(PillButtonStyle(color: Palette.coral, size: 22))
            }
        }
    }

    private func grid(_ course: TutorialCourse, landscape: Bool) -> some View {
        let cards = course.tracks.count + (upcoming == nil ? 0 : 1)
        let cols = landscape ? cards : 2
        let rows = Int((Double(cards) / Double(cols)).rounded(.up))
        return VStack(spacing: 18) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 18) {
                    ForEach(0..<cols, id: \.self) { c in
                        let i = r * cols + c
                        Group {
                            if i < course.tracks.count {
                                TrackCard(course: course, index: i, accent: accent,
                                          next: store.nextLesson(course)) { lesson in
                                    Sound.tap()
                                    playing = .lesson(lesson)
                                } practice: { lesson in
                                    Sound.start()
                                    playing = LessonRoute.practice(lesson, game: course.game)
                                }
                            } else if i == course.tracks.count, let upcoming {
                                UpcomingCard(title: upcoming.title, subtitle: upcoming.subtitle, art: upcoming.art)
                            } else {
                                Color.clear
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .offset(y: appeared ? 0 : 40)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(duration: 0.6, bounce: 0.3).delay(0.05 * Double(i)), value: appeared)
                    }
                }
            }
        }
    }
}

/// 打开的一课：按游戏选对应的棋盘。课程表和复盘里的「复习这一课」共用。
struct LessonScreen: View {
    let course: TutorialCourse
    let route: LessonRoute
    let onNextLesson: (TutorialLesson) -> Void

    var body: some View {
        switch course.game {
        case "xiangqi": XiangqiLessonView(course: course, lesson: route.lesson, mode: route.mode, onNextLesson: onNextLesson)
        case "go": GoLessonView(course: course, lesson: route.lesson, mode: route.mode, onNextLesson: onNextLesson)
        default: GomokuLessonView(course: course, lesson: route.lesson, mode: route.mode, onNextLesson: onNextLesson)
        }
    }
}

/// 从别的地方（比如复盘）直接打开某一课；学完可以接着下一课，「课程表」就是关掉回去。
struct LessonLaunchView: View {
    @Environment(PlayerStore.self) private var store
    let course: TutorialCourse
    @State private var route: LessonRoute

    init(course: TutorialCourse, lesson: TutorialLesson) {
        self.course = course
        _route = State(initialValue: .lesson(lesson))
    }

    var body: some View {
        LessonScreen(course: course, route: route) { route = .lesson($0) }
            .id(route)
            .environment(\.lessonNavigator, LessonNavigator(open: { route = $0 }, leaveTitle: "回到复盘"))
            .onAppear { store.rememberOpenTracks(course) }
    }
}

/// 复盘里点评到一个学过的错误时的「复习这一课」按钮：全屏打开那一课
struct ReviewLessonButton: View {
    @Environment(PlayerStore.self) private var store
    let game: String
    let lessonID: String
    @State private var showing = false

    private var course: TutorialCourse? { TutorialCourse.bundled[game] }

    var body: some View {
        if let course, let lesson = course.lesson(lessonID) {
            Button {
                Sound.tap()
                showing = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Palette.coral, in: Circle())
                    VStack(alignment: .leading, spacing: 0) {
                        Text("复习这一课")
                            .font(.kid(17, weight: .heavy))
                            .foregroundStyle(Palette.ink)
                        Text("「\(lesson.title)」")
                            .font(.kid(14, weight: .bold))
                            .foregroundStyle(Palette.inkSoft)
                            .lineLimit(1)
                    }
                    if let cup = store.lessonCup(game, lessonID) {
                        CupBadge(cup: cup, size: 26)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Palette.inkSoft.opacity(0.6))
                }
                .padding(.leading, 6)
                .padding(.trailing, 14)
                .padding(.vertical, 6)
                .background(Palette.coral.opacity(0.1), in: Capsule())
                .overlay(Capsule().strokeBorder(Palette.coral.opacity(0.35), lineWidth: 1.5))
            }
            .buttonStyle(PressableStyle(scale: 0.95))
            .accessibilityLabel("复习这一课：\(lesson.title)")
            .fullScreenCover(isPresented: $showing) {
                LessonLaunchView(course: course, lesson: lesson)
                    .environment(store)
            }
        }
    }
}

/// 课程表右上角的「复习」：从学过的课里抽 5 道题，换个方向再做一遍
private struct ReviewButton: View {
    @Environment(PlayerStore.self) private var store
    let game: String
    let accent: Color
    let action: () -> Void

    private var days: Int? { store.daysSinceReview(game) }

    /// 没复习过，或者三天没复习了：亮一个小红点
    private var due: Bool { days.map { $0 >= 3 } ?? true }

    private var caption: String {
        guard let d = days else { return "还没复习过" }
        let when = d == 0 ? "今天" : (d == 1 ? "昨天" : "\(d) 天前")
        return "上次 \(when) · 第 \(store.reviewCount(game)) 次"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Palette.sage, in: Circle())
                    .overlay(alignment: .topTrailing) {
                        if due {
                            Circle()
                                .fill(Palette.coral)
                                .frame(width: 14, height: 14)
                                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                                .offset(x: 3, y: -3)
                        }
                    }
                VStack(alignment: .leading, spacing: 1) {
                    Text("复习")
                        .font(.kid(22, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                    Text(caption)
                        .font(.kid(13, weight: .bold))
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(1)
                        .monospacedDigit()
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 18)
            .padding(.vertical, 8)
            .softCard(radius: 40)
        }
        .buttonStyle(PressableStyle(scale: 0.94))
        .accessibilityLabel("复习，\(caption)")
    }
}

/// 一组课程
private struct TrackCard: View {
    @Environment(PlayerStore.self) private var store
    let course: TutorialCourse
    let index: Int
    let accent: Color
    let next: TutorialLesson?
    let open: (TutorialLesson) -> Void
    let practice: (TutorialLesson) -> Void

    private var track: TutorialTrack { course.tracks[index] }
    private var unlocked: Bool { store.trackUnlocked(course, index) }
    private var done: Bool { store.trackDone(course, track) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                ArtImage(name: track.art, fallback: "📘", contentMode: .fit)
                    .frame(width: 96, height: 96)
                    .background(Circle().fill(accent.opacity(0.18)).padding(6))
                    .saturation(unlocked ? 1 : 0.2)
                    .opacity(unlocked ? 1 : 0.6)
                VStack(alignment: .leading, spacing: 3) {
                    Text("第 \(index + 1) 组")
                        .font(.kid(14, weight: .heavy))
                        .foregroundStyle(Palette.inkSoft)
                    Text(track.title)
                        .font(.kid(26, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(track.subtitle)
                        .font(.kid(15, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
            if unlocked {
                VStack(spacing: 6) {
                    ForEach(Array(track.lessons.enumerated()), id: \.element.id) { i, lesson in
                        let finished = store.lessonDone(course.game, lesson.id)
                        LessonRow(number: i + 1, lesson: lesson,
                                  cup: store.lessonCup(course.game, lesson.id),
                                  isNext: lesson.id == next?.id, accent: accent,
                                  canPractice: finished && LessonPractice.canPractice(lesson, game: course.game),
                                  action: { open(lesson) }, practice: { practice(lesson) })
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            } else {
                VStack(spacing: 12) {
                    Spacer(minLength: 0)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(Palette.inkSoft.opacity(0.55))
                    Text("学完「\(course.tracks[index - 1].title)」\n就能解锁")
                        .font(.kid(18, weight: .bold))
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center)
                    Text("\(track.lessons.count) 课")
                        .font(.kid(15, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft.opacity(0.7))
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(colors: [accent.opacity(unlocked ? 0.2 : 0.06), Palette.paper.opacity(0)],
                           startPoint: .top, endPoint: .center),
            in: RoundedRectangle(cornerRadius: 34, style: .continuous)
        )
        .softCard(radius: 34)
        .overlay(alignment: .topTrailing) {
            if done {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Palette.sage)
                    .padding(14)
            }
        }
    }
}

/// 课程表上的一课：学完的显示拿到的小奖杯，右边可以「练一练」
private struct LessonRow: View {
    let number: Int
    let lesson: TutorialLesson
    let cup: LessonCup?
    let isNext: Bool
    let accent: Color
    let canPractice: Bool
    let action: () -> Void
    let practice: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: action) {
                HStack(spacing: 12) {
                    if let cup {
                        CupBadge(cup: cup, size: 36)
                    } else {
                        Text("\(number)")
                            .font(.kid(17, weight: .heavy))
                            .foregroundStyle(isNext ? .white : Palette.ink.opacity(0.7))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(isNext ? Palette.coral : Palette.cream))
                    }
                    Text(lesson.title)
                        .font(.kid(19, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    if isNext {
                        Text("下一课")
                            .font(.kid(13, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Palette.coral, in: Capsule())
                    } else if !canPractice {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Palette.inkSoft.opacity(0.5))
                    }
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle(scale: 0.96))
            .accessibilityLabel("第 \(number) 课 \(lesson.title)\(cup.map { "，已学会，\($0.name)" } ?? "")")

            if canPractice && !isNext {
                Button(action: practice) {
                    HStack(spacing: 4) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 12, weight: .black))
                        Text("练一练")
                            .font(.kid(14, weight: .heavy))
                    }
                    .foregroundStyle(Palette.ink.opacity(0.75))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(accent.opacity(0.28), in: Capsule())
                }
                .buttonStyle(PressableStyle(scale: 0.9))
                .accessibilityLabel("练一练：\(lesson.title)")
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 58)
        .background(isNext ? Palette.coral.opacity(0.1) : Palette.paper.opacity(0.7),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Palette.coral.opacity(isNext ? 0.6 : 0), lineWidth: 2)
        )
    }
}

private struct UpcomingCard: View {
    let title: String
    let subtitle: String
    let art: String

    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            ArtImage(name: art, fallback: "✨", contentMode: .fit)
                .frame(maxWidth: 160, maxHeight: 160)
                .saturation(0.35)
                .opacity(0.75)
            Text(title)
                .font(.kid(26, weight: .heavy))
                .foregroundStyle(Palette.ink.opacity(0.7))
            Text(subtitle)
                .font(.kid(16, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
            Text("正在精心制作中…")
                .font(.kid(15, weight: .bold))
                .foregroundStyle(Palette.inkSoft.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Palette.paper, in: Capsule())
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.paper.opacity(0.45), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(Palette.inkSoft.opacity(0.25), style: StrokeStyle(lineWidth: 2.5, dash: [10, 9]))
        )
    }
}

/// 游戏首页右上角的「教学」按钮
struct TutorialButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            Sound.tap()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.coral)
                Text("教学")
                    .font(.kid(22, weight: .heavy))
                    .foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .softCard(radius: 40)
        }
        .buttonStyle(PressableStyle(scale: 0.94))
        .accessibilityLabel("教学")
    }
}
