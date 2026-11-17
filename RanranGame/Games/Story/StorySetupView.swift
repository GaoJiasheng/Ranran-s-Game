import SwiftUI

/// 「小伙伴的故事」首页：五章，每章三关（演一演 → 先猜再演 → 只看文字）。
struct StorySetupView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var playing: StoryLevel?
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            // 横屏：五章排成五列；竖屏（或窄窗口）：五章排成五行。都铺满一屏，不滚动。
            let columns = geo.size.width > geo.size.height && geo.size.width > 960
            ZStack {
                CreamBackground(accent: Palette.sage)
                AdaptivePage {
                    VStack(spacing: 20) {
                        header
                        intro
                        Group {
                            if columns {
                                HStack(spacing: 16) { chapters(columns: true) }
                            } else {
                                VStack(spacing: 14) { chapters(columns: false) }
                            }
                        }
                        .frame(maxHeight: .infinity)
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 24)
                    .frame(maxWidth: 1240, maxHeight: .infinity)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.3)) { appeared = true }
        }
        .navigationDestination(item: $playing) { level in
            StoryPlayView(level: level) { next in playing = next }
                .id(level)
                .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func chapters(columns: Bool) -> some View {
        ForEach(Array(StoryChapter.allCases.enumerated()), id: \.element) { i, chapter in
            ChapterCard(chapter: chapter, column: columns,
                        best: { store.storyBest($0) },
                        recommended: store.storyRecommended) { level in
                Sound.tap()
                playing = level
            }
            .offset(y: appeared ? 0 : 40)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(duration: 0.6, bounce: 0.3).delay(0.05 * Double(i)), value: appeared)
        }
    }

    private var header: some View {
        ZStack {
            VStack(spacing: 6) {
                Text("小伙伴的故事")
                    .font(.kid(54, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text("听故事、演一演，再算一算")
                    .font(.kid(20, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
            }
            HStack {
                RoundIconButton(systemName: "house.fill", label: "回主页") { dismiss() }
                Spacer()
                StarCounter()
            }
        }
    }

    /// 告诉孩子（和家长）三种玩法分别是什么
    private var intro: some View {
        HStack(spacing: 14) {
            ForEach([StoryMode.act, .guess, .read], id: \.self) { mode in
                HStack(spacing: 12) {
                    Image(systemName: mode.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Palette.ink.opacity(0.75))
                        .frame(width: 46, height: 46)
                        .background(Palette.paper, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode.title)
                            .font(.kid(19, weight: .heavy))
                            .foregroundStyle(Palette.ink)
                        Text(blurb(mode))
                            .font(.kid(15, weight: .semibold))
                            .foregroundStyle(Palette.inkSoft)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(Palette.paper.opacity(0.6), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
    }

    private func blurb(_ mode: StoryMode) -> String {
        switch mode {
        case .act:   "跟着故事拖一拖，看清楚再答"
        case .guess: "先说答案，再演一遍看对不对"
        case .read:  "只看文字，在脑子里演"
        }
    }
}

/// 一章：横屏时是一列（标题在上、三关竖排），竖屏时是一行（标题在左、三关横排）。
private struct ChapterCard: View {
    let chapter: StoryChapter
    let column: Bool
    let best: (StoryLevel) -> Int
    let recommended: StoryLevel
    let open: (StoryLevel) -> Void

    var body: some View {
        Group {
            if column {
                VStack(alignment: .leading, spacing: 0) {
                    badge(size: 56)
                    titles(title: 26, subtitle: 16)
                        .padding(.top, 14)
                    Spacer(minLength: 16)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(chapter.levels.enumerated()), id: \.element) { i, level in
                            if i > 0 {
                                // 连线在高屏幕上拉长一点，三关均匀铺开
                                Capsule()
                                    .fill(link(i))
                                    .frame(width: 6)
                                    .frame(minHeight: 16, maxHeight: 44)
                                    .padding(.leading, 29)
                            }
                            node(level, compact: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                HStack(spacing: 18) {
                    badge(size: 68)
                    titles(title: 30, subtitle: 17)
                    Spacer(minLength: 8)
                    HStack(spacing: 0) {
                        ForEach(Array(chapter.levels.enumerated()), id: \.element) { i, level in
                            if i > 0 {
                                Capsule()
                                    .fill(link(i))
                                    .frame(width: 22, height: 6)
                                    .padding(.bottom, 40)
                            }
                            node(level, compact: false)
                        }
                    }
                    .layoutPriority(1)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(
            LinearGradient(colors: [chapter.tint.opacity(0.18), Palette.paper.opacity(0)],
                           startPoint: column ? .top : .leading, endPoint: .center),
            in: RoundedRectangle(cornerRadius: 36, style: .continuous)
        )
        .softCard(radius: 36)
    }

    private func link(_ i: Int) -> Color {
        best(chapter.levels[i - 1]) > 0 ? chapter.tint : Palette.ink.opacity(0.08)
    }

    private func node(_ level: StoryLevel, compact: Bool) -> some View {
        LevelNode(level: level, stars: best(level), tint: chapter.tint,
                  recommended: level == recommended, compact: compact) { open(level) }
    }

    private func badge(size: CGFloat) -> some View {
        Image(systemName: chapter.icon)
            .font(.system(size: size * 0.4, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(chapter.tint.gradient, in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
            .shadow(color: chapter.tint.opacity(0.45), radius: 10, y: 6)
    }

    private func titles(title: CGFloat, subtitle: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("第 \(chapter.rawValue) 章")
                .font(.kid(15, weight: .heavy))
                .foregroundStyle(Palette.inkSoft)
            Text(chapter.title)
                .font(.kid(title, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(chapter.subtitle)
                .font(.kid(subtitle, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(2, reservesSpace: true)
                .minimumScaleFactor(0.85)
        }
    }
}

/// 一关。竖屏一行里是"圆 + 下面写字"，横屏一列里是"圆 + 右边写字"。
private struct LevelNode: View {
    let level: StoryLevel
    let stars: Int
    let tint: Color
    let recommended: Bool
    var compact = false
    let action: () -> Void

    @State private var bounce = false

    var body: some View {
        Button(action: action) {
            if compact {
                HStack(spacing: 12) {
                    circle(64)
                    VStack(alignment: .leading, spacing: 4) {
                        label
                        starRow
                    }
                    Spacer(minLength: 0)
                }
            } else {
                VStack(spacing: 6) {
                    circle(76)
                    label
                    starRow
                }
                .frame(width: 96)
            }
        }
        .buttonStyle(PressableStyle(scale: 0.92))
        .accessibilityLabel("第 \(level.number) 关，\(level.mode.title)，\(stars) 颗星")
        .onAppear {
            guard recommended else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { bounce = true }
        }
    }

    private func circle(_ d: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(stars > 0 ? tint : Palette.paper)
                .overlay(Circle().strokeBorder(tint, lineWidth: stars > 0 ? 0 : 3.5))
                .shadow(color: tint.opacity(stars > 0 ? 0.45 : 0.15), radius: 10, y: 6)
            VStack(spacing: 0) {
                Image(systemName: level.mode.icon)
                    .font(.system(size: d * 0.3, weight: .bold))
                Text("\(level.number)")
                    .font(.kid(d * 0.2, weight: .heavy))
            }
            .foregroundStyle(stars > 0 ? .white : Palette.ink.opacity(0.8))
        }
        .frame(width: d, height: d)
        .overlay(alignment: .top) {
            if recommended {
                Text("推荐")
                    .font(.kid(13, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Palette.coral, in: Capsule())
                    .overlay(Capsule().strokeBorder(.white, lineWidth: 2.5))
                    .fixedSize()
                    .offset(y: bounce ? -18 : -12)
            }
        }
    }

    private var label: some View {
        Text(level.mode.title)
            .font(.kid(15, weight: .bold))
            .foregroundStyle(Palette.inkSoft)
            .lineLimit(1)
            .fixedSize()
    }

    private var starRow: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "star.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(i < stars ? Palette.honey : Palette.ink.opacity(0.1))
            }
        }
    }
}
