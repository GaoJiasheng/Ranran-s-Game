import SwiftUI

/// 一个游戏的「教学」课程表：几组课程分成几列（横屏尽量一组一列，竖屏两列），基础一直开着，后面的学完前一组才解锁。
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

    /// 课程表怎么排：几列、每列放哪几组、每一行多高。
    /// 课多了以后（围棋 34 课）一屏也要放得下：先试宽松的排法，放不下就把组的封面缩小、行压矮、再多分一列。
    private struct TrackPlan {
        var columns: [[Int]]
        /// 每列的"一行 + 行距"有多高
        var units: [CGFloat]
        var compact: Bool
        var tightest: CGFloat { units.min() ?? 0 }
    }

    private static let gap: CGFloat = 18

    private func plan(_ course: TutorialCourse, size: CGSize, landscape: Bool) -> TrackPlan {
        let n = course.tracks.count + (upcoming == nil ? 0 : 1)
        // 锁着的组、制作中的组只显示一把锁，按三行算
        let rows: [Int] = (0..<n).map { i in
            guard i < course.tracks.count, store.trackUnlocked(course, i) else { return 3 }
            return max(course.tracks[i].lessons.count, 3)
        }
        func make(cols: Int, compact: Bool) -> TrackPlan {
            let overhead = TrackCard.overhead(compact: compact)
            var best = TrackPlan(columns: [], units: [], compact: compact)
            // 按顺序切成几段（第 1 列放前几组……），挑最挤的那一列最宽松的切法
            func cut(_ start: Int, _ left: Int, _ acc: [[Int]]) {
                if left == 1 {
                    let all = acc + [Array(start..<n)]
                    let units = all.map { col -> CGFloat in
                        let r = col.reduce(0) { $0 + rows[$1] }
                        return (size.height - CGFloat(col.count - 1) * Self.gap - CGFloat(col.count) * overhead) / CGFloat(r)
                    }
                    if best.columns.isEmpty || (units.min() ?? 0) > best.tightest {
                        best = TrackPlan(columns: all, units: units, compact: compact)
                    }
                    return
                }
                guard n - start >= left else { return }
                for end in (start + 1)...(n - left + 1) { cut(end, left - 1, acc + [Array(start..<end)]) }
            }
            cut(0, cols, [])
            return best
        }
        let widest = max(1, Int((size.width + Self.gap) / (255 + Self.gap)))
        let low = min(2, n), high = max(low, min(n, widest))
        // 横屏先试一组一列，竖屏先试两列
        let counts = landscape ? Array((low...high).reversed()) : Array(low...high)
        let options = counts.flatMap { c in [make(cols: c, compact: false), make(cols: c, compact: true)] }
        return options.first { $0.tightest >= 46 } ?? options.max { $0.tightest < $1.tightest } ?? make(cols: low, compact: true)
    }

    private func grid(_ course: TutorialCourse, landscape: Bool) -> some View {
        GeometryReader { geo in
            let plan = plan(course, size: geo.size, landscape: landscape)
            let cols = plan.columns.count
            let width = (geo.size.width - CGFloat(cols - 1) * Self.gap) / CGFloat(max(cols, 1))
            HStack(alignment: .top, spacing: Self.gap) {
                ForEach(Array(plan.columns.enumerated()), id: \.offset) { c, column in
                    let unit = plan.units[c]
                    VStack(spacing: Self.gap) {
                        ForEach(column, id: \.self) { i in
                            let locked = !(i < course.tracks.count && store.trackUnlocked(course, i))
                            let rows = locked ? 3 : max(course.tracks[i].lessons.count, 3)
                            Group {
                                if i < course.tracks.count {
                                    TrackCard(course: course, index: i, accent: accent,
                                              next: store.nextLesson(course),
                                              compact: plan.compact, unit: unit, narrow: width < 340) { lesson in
                                        Sound.tap()
                                        playing = .lesson(lesson)
                                    } practice: { lesson in
                                        Sound.start()
                                        playing = LessonRoute.practice(lesson, game: course.game)
                                    }
                                } else if let upcoming {
                                    UpcomingCard(title: upcoming.title, subtitle: upcoming.subtitle, art: upcoming.art)
                                }
                            }
                            .frame(width: width, height: TrackCard.overhead(compact: plan.compact) + CGFloat(rows) * unit)
                            .offset(y: appeared ? 0 : 40)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(duration: 0.6, bounce: 0.3).delay(0.05 * Double(i)), value: appeared)
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
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
    /// 课多的时候：封面小一点、边距窄一点
    var compact = false
    /// 一行 + 行距的高度（课程表算好给的）
    var unit: CGFloat = 64
    /// 这一列很窄：「练一练」只留图标
    var narrow = false
    let open: (TutorialLesson) -> Void
    let practice: (TutorialLesson) -> Void

    /// 卡片里除了课程行以外占的高度：上下边距 + 封面 + 封面和课程之间的空
    static func overhead(compact: Bool) -> CGFloat { compact ? 12 * 2 + 60 + 8 : 18 * 2 + 96 + 10 }

    private var art: CGFloat { compact ? 60 : 96 }
    private var rowSpacing: CGFloat { unit < 46 ? 4 : 6 }
    private var rowHeight: CGFloat { min(58, unit - rowSpacing) }

    private var track: TutorialTrack { course.tracks[index] }
    private var unlocked: Bool { store.trackUnlocked(course, index) }
    private var done: Bool { store.trackDone(course, track) }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(alignment: .center, spacing: 12) {
                ArtImage(name: track.art, fallback: "📘", contentMode: .fit)
                    .frame(width: art, height: art)
                    .background(Circle().fill(accent.opacity(0.18)).padding(compact ? 3 : 6))
                    .saturation(unlocked ? 1 : 0.2)
                    .opacity(unlocked ? 1 : 0.6)
                VStack(alignment: .leading, spacing: 3) {
                    Text("第 \(index + 1) 组")
                        .font(.kid(compact ? 12 : 14, weight: .heavy))
                        .foregroundStyle(Palette.inkSoft)
                    Text(track.title)
                        .font(.kid(compact ? 21 : 26, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(track.subtitle)
                        .font(.kid(compact ? 13 : 15, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(compact ? 1 : 2)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
            .frame(height: art)
            if unlocked {
                VStack(spacing: rowSpacing) {
                    ForEach(Array(track.lessons.enumerated()), id: \.element.id) { i, lesson in
                        let finished = store.lessonDone(course.game, lesson.id)
                        LessonRow(number: i + 1, lesson: lesson,
                                  cup: store.lessonCup(course.game, lesson.id),
                                  isNext: lesson.id == next?.id, accent: accent,
                                  canPractice: finished && LessonPractice.canPractice(lesson, game: course.game),
                                  height: rowHeight, narrow: narrow,
                                  action: { open(lesson) }, practice: { practice(lesson) })
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            } else {
                VStack(spacing: compact ? 6 : 12) {
                    Spacer(minLength: 0)
                    Image(systemName: "lock.fill")
                        .font(.system(size: compact ? 28 : 38, weight: .bold))
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
        .padding(compact ? 12 : 18)
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
                    .font(.system(size: compact ? 24 : 30, weight: .bold))
                    .foregroundStyle(Palette.sage)
                    .padding(compact ? 10 : 14)
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
    var height: CGFloat = 52
    var narrow = false
    let action: () -> Void
    let practice: () -> Void

    private var badge: CGFloat { min(36, height - 8) }

    var body: some View {
        HStack(spacing: narrow ? 6 : 8) {
            Button(action: action) {
                HStack(spacing: narrow ? 8 : 12) {
                    if let cup {
                        CupBadge(cup: cup, size: badge)
                    } else {
                        Text("\(number)")
                            .font(.kid(badge < 32 ? 15 : 17, weight: .heavy))
                            .foregroundStyle(isNext ? .white : Palette.ink.opacity(0.7))
                            .frame(width: badge, height: badge)
                            .background(Circle().fill(isNext ? Palette.coral : Palette.cream))
                    }
                    Text(lesson.title)
                        .font(.kid(height < 42 ? 17 : 19, weight: .bold))
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
                        if !narrow {
                            Text("练一练")
                                .font(.kid(14, weight: .heavy))
                        }
                    }
                    .foregroundStyle(Palette.ink.opacity(0.75))
                    .padding(.horizontal, 10)
                    .padding(.vertical, height < 42 ? 5 : 6)
                    .background(accent.opacity(0.28), in: Capsule())
                }
                .buttonStyle(PressableStyle(scale: 0.9))
                .accessibilityLabel("练一练：\(lesson.title)")
            }
        }
        .padding(.leading, narrow ? 8 : 12)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity)
        .frame(height: height)
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
