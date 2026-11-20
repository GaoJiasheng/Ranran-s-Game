import SwiftUI

/// 一个游戏的「教学」课程表：几组课程排成一排（竖屏 2×2），基础一直开着，后面的学完前一组才解锁。
struct TutorialHomeView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let game: String
    let accent: Color
    /// 还在制作中的一组（只显示封面）
    var upcoming: (title: String, subtitle: String, art: String)? = nil

    @State private var course: TutorialCourse?
    @State private var playing: TutorialLesson?
    @State private var appeared = false

    init(game: String, accent: Color, upcoming: (title: String, subtitle: String, art: String)? = nil) {
        self.game = game
        self.accent = accent
        self.upcoming = upcoming
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
            #if DEBUG
            // 调试截图用：启动参数 -lesson x4 直接打开那一课
            if let id = UserDefaults.standard.string(forKey: "lesson"), playing == nil,
               let l = course?.lessons.first(where: { $0.id == id }) { playing = l }
            #endif
        }
        .navigationDestination(item: $playing) { lesson in
            lessonView(lesson)
                .id(lesson)
                .toolbar(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder
    private func lessonView(_ lesson: TutorialLesson) -> some View {
        if let course {
            switch game {
            case "xiangqi": XiangqiLessonView(course: course, lesson: lesson) { playing = $0 }
            case "go": GoLessonView(course: course, lesson: lesson) { playing = $0 }
            default: GomokuLessonView(course: course, lesson: lesson) { playing = $0 }
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
                Text(done == 0 ? "从基础规则开始，一步一步学" : "已经学会 \(done) / \(total) 课")
                    .font(.kid(19, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 0)
            if let next = store.nextLesson(course) {
                Button {
                    Sound.start()
                    playing = next
                } label: {
                    Label(done == 0 ? "开始学：\(next.title)" : "继续学：\(next.title)", systemImage: "play.fill")
                        .lineLimit(1)
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
                                    playing = lesson
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

/// 一组课程
private struct TrackCard: View {
    @Environment(PlayerStore.self) private var store
    let course: TutorialCourse
    let index: Int
    let accent: Color
    let next: TutorialLesson?
    let open: (TutorialLesson) -> Void

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
                        LessonRow(number: i + 1, lesson: lesson,
                                  done: store.lessonDone(course.game, lesson.id),
                                  isNext: lesson.id == next?.id, accent: accent) { open(lesson) }
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

private struct LessonRow: View {
    let number: Int
    let lesson: TutorialLesson
    let done: Bool
    let isNext: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(done ? Palette.sage : (isNext ? Palette.coral : Palette.cream))
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(.white)
                    } else {
                        Text("\(number)")
                            .font(.kid(17, weight: .heavy))
                            .foregroundStyle(isNext ? .white : Palette.ink.opacity(0.7))
                    }
                }
                .frame(width: 36, height: 36)
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
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Palette.inkSoft.opacity(0.5))
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 58)
            .background(isNext ? Palette.coral.opacity(0.1) : Palette.paper.opacity(0.7),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Palette.coral.opacity(isNext ? 0.6 : 0), lineWidth: 2)
            )
        }
        .buttonStyle(PressableStyle(scale: 0.96))
        .accessibilityLabel("第 \(number) 课 \(lesson.title)\(done ? "，已学会" : "")")
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
