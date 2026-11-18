import SwiftUI

/// 「加减乘除」首页：英文应用题。八章，每章三关（Act it out → Draw a model → Just read）。
struct StorySetupView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var playing: StoryLevel?
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            // 横屏：4 列 × 2 行；竖屏：2 列 × 4 行。都铺满一屏，不滚动。
            let landscape = geo.size.width > geo.size.height
            let cols = landscape ? 4 : 2
            // 竖屏 8 章排 4 行，只有很高的屏幕才放得下三种玩法的介绍
            let roomy = landscape ? geo.size.height > 820 : geo.size.height > 1250
            ZStack {
                CreamBackground(accent: Palette.sky)
                AdaptivePage {
                    VStack(spacing: roomy ? 20 : 14) {
                        header
                        if roomy { intro }
                        grid(cols: cols)
                            .frame(maxHeight: .infinity)
                    }
                    .padding(.horizontal, 36)
                    .padding(.vertical, 22)
                    .frame(maxWidth: 1320, maxHeight: .infinity)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.3)) { appeared = true }
            #if DEBUG
            // 调试截图用：启动参数 -level 16 直接打开那一关
            let n = UserDefaults.standard.integer(forKey: "level")
            if n > 0, playing == nil { playing = StoryLevel(n) }
            #endif
        }
        .navigationDestination(item: $playing) { level in
            StoryPlayView(level: level) { next in playing = next }
                .id(level)
                .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func grid(cols: Int) -> some View {
        let chapters = StoryChapter.allCases
        let rows = stride(from: 0, to: chapters.count, by: cols).map { Array(chapters[$0..<min($0 + cols, chapters.count)]) }
        return VStack(spacing: 14) {
            ForEach(Array(rows.enumerated()), id: \.offset) { r, row in
                HStack(spacing: 14) {
                    ForEach(Array(row.enumerated()), id: \.element) { c, chapter in
                        ChapterCard(chapter: chapter,
                                    best: { store.storyBest($0) },
                                    recommended: store.storyRecommended) { level in
                            Sound.tap()
                            playing = level
                        }
                        .offset(y: appeared ? 0 : 40)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(duration: 0.6, bounce: 0.3).delay(0.04 * Double(r * cols + c)), value: appeared)
                    }
                }
            }
        }
    }

    private var header: some View {
        ZStack {
            VStack(spacing: 4) {
                Text("加减乘除")
                    .font(.kid(50, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text("Word Problems")
                    .font(.kid(20, weight: .bold))
                    .foregroundStyle(Palette.inkSoft)
            }
            HStack(spacing: 14) {
                RoundIconButton(systemName: "house.fill", label: "回主页") { dismiss() }
                Spacer()
                if store.storySolved > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Palette.sage)
                        Text("\(store.storySolved) solved")
                            .font(.kid(22, weight: .heavy))
                            .foregroundStyle(Palette.ink)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .softCard(radius: 40)
                }
                StarCounter()
            }
        }
    }

    /// 三种玩法 = 新加坡数学的 C-P-A
    private var intro: some View {
        HStack(spacing: 14) {
            ForEach([StoryMode.act, .model, .read], id: \.self) { mode in
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
        case .act:   "Move the things to act out the story"
        case .model: "Draw bars to see the parts and the whole"
        case .read:  "Just read and think"
        }
    }
}

/// 一章：标题在上，三关横排在下。
private struct ChapterCard: View {
    let chapter: StoryChapter
    let best: (StoryLevel) -> Int
    let recommended: StoryLevel
    let open: (StoryLevel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                badge(size: 50)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Chapter \(chapter.rawValue)")
                        .font(.kid(14, weight: .heavy))
                        .foregroundStyle(Palette.inkSoft)
                    Text(chapter.title)
                        .font(.kid(23, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 0)
            }
            Text(chapter.subtitle)
                .font(.kid(15, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.top, 8)
            Spacer(minLength: 0)
                .frame(maxHeight: .infinity)
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(chapter.levels.enumerated()), id: \.element) { i, level in
                    if i > 0 {
                        Capsule()
                            .fill(link(i))
                            .frame(minWidth: 6, maxWidth: 40)
                            .frame(height: 5)
                            .padding(.top, 30)
                    }
                    LevelNode(level: level, stars: best(level), tint: chapter.tint,
                              recommended: level == recommended) { open(level) }
                }
            }
            .frame(maxWidth: .infinity)
            // 给推荐关上面跳动的 "Next" 标签留出位置
            .padding(.top, 14)
            Spacer(minLength: 0)
                .frame(maxHeight: .infinity)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(colors: [chapter.tint.opacity(0.2), Palette.paper.opacity(0)],
                           startPoint: .top, endPoint: .center),
            in: RoundedRectangle(cornerRadius: 34, style: .continuous)
        )
        .softCard(radius: 34)
    }

    private func link(_ i: Int) -> Color {
        best(chapter.levels[i - 1]) > 0 ? chapter.tint : Palette.ink.opacity(0.08)
    }

    private func badge(size: CGFloat) -> some View {
        Image(systemName: chapter.icon)
            .font(.system(size: size * 0.42, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(chapter.tint.gradient, in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
            .shadow(color: chapter.tint.opacity(0.45), radius: 10, y: 6)
    }
}

/// 一关："圆 + 下面写字和星星"。
private struct LevelNode: View {
    let level: StoryLevel
    let stars: Int
    let tint: Color
    let recommended: Bool
    let action: () -> Void

    @State private var bounce = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                circle(64)
                Text(level.mode.short)
                    .font(.kid(14, weight: .bold))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
                    .fixedSize()
                starRow
            }
            .frame(minWidth: 66)
        }
        .buttonStyle(PressableStyle(scale: 0.92))
        .accessibilityLabel("Level \(level.number), \(level.mode.title), \(stars) stars")
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
                Text("Next")
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

    private var starRow: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "star.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(i < stars ? Palette.honey : Palette.ink.opacity(0.1))
            }
        }
    }
}
