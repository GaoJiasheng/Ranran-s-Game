import SwiftUI

/// 「加减乘除」首页：英文应用题。十章，每章三关（大多是 Act it out → Draw a model → Just read）。
/// 十张章卡一屏铺满、不滚动：横屏 5 列 × 2 行（上面一排是一年级的内容，下面一排是二年级的），竖屏 2 列 × 5 行。
struct StorySetupView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(StoryLevel.unlockAllKey) private var unlockAll = false
    @State private var playing: StoryLevel?
    /// 正在练的错题（一次最多 practiceBatch 道，一道接一道）
    @State private var practicing: [StoryMistake]?
    /// 练一练挑好的题
    @State private var mixing: MixRun?
    @State private var appeared = false

    private static let practiceBatch = 5

    /// navigationDestination(item:) 要 Hashable
    struct MixRun: Hashable {
        let id = UUID()
        let pick: StoryMix.Pick
        static func == (l: MixRun, r: MixRun) -> Bool { l.id == r.id }
        func hash(into h: inout Hasher) { h.combine(id) }
    }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            let cols = landscape ? 5 : 2
            // 三种玩法的介绍只在很高的横屏（13 寸）上放得下
            let roomy = landscape && geo.size.height > 900
            ZStack {
                CreamBackground(accent: Palette.sky)
                VStack(spacing: roomy ? 18 : 14) {
                    header
                    if roomy { intro }
                    grid(cols: cols)
                        .frame(maxHeight: .infinity)
                }
                .padding(.horizontal, landscape ? 30 : 26)
                .padding(.vertical, 20)
                .frame(maxWidth: 1400, maxHeight: .infinity)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.3)) { appeared = true }
            #if DEBUG
            // 调试截图用：启动参数 -level 22 直接打开首页上的第 22 关；-mix 1 直接打开练一练
            let n = UserDefaults.standard.integer(forKey: "level")
            if n > 0, playing == nil { playing = StoryLevel(position: n) }
            if UserDefaults.standard.integer(forKey: "mix") > 0, mixing == nil,
               let pick = store.storyMixPick(unlockAll: true) { mixing = MixRun(pick: pick) }
            #endif
        }
        .navigationDestination(item: $playing) { level in
            StoryPlayView(level: level) { next in playing = next }
                .id(level)
                .toolbar(.hidden, for: .navigationBar)
        }
        .navigationDestination(item: $practicing) { mistakes in
            StoryPlayView(mistakes: mistakes)
                .toolbar(.hidden, for: .navigationBar)
        }
        .navigationDestination(item: $mixing) { run in
            StoryPlayView(mix: run.pick)
                .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func grid(cols: Int) -> some View {
        let chapters = StoryChapter.allCases
        let rows = stride(from: 0, to: chapters.count, by: cols).map { Array(chapters[$0..<min($0 + cols, chapters.count)]) }
        let gap: CGFloat = 14
        let recommended = store.storyRecommended(unlockAll: unlockAll)
        return GeometryReader { g in
            let cell = CGSize(width: (g.size.width - gap * CGFloat(cols - 1)) / CGFloat(cols),
                              height: (g.size.height - gap * CGFloat(rows.count - 1)) / CGFloat(rows.count))
            VStack(spacing: gap) {
                ForEach(Array(rows.enumerated()), id: \.offset) { r, row in
                    HStack(spacing: gap) {
                        ForEach(Array(row.enumerated()), id: \.element) { c, chapter in
                            ChapterCard(chapter: chapter, cell: cell,
                                        best: { store.storyBest($0) },
                                        stars: { store.storyStars($0) },
                                        unlocked: { store.storyUnlocked($0, unlockAll: unlockAll) },
                                        recommended: recommended) { level in
                                Sound.tap()
                                playing = level
                            }
                            .frame(width: cell.width, height: cell.height)
                            .offset(y: appeared ? 0 : 40)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(duration: 0.6, bounce: 0.3).delay(0.04 * Double(r * cols + c)), value: appeared)
                        }
                    }
                }
            }
        }
    }

    /// 标题居中；左边回主页、"Tricky ones"和"Practice mix"，右边做对几题和星星。两边各占一半剩下的宽度，窄了就收成短的。
    private var header: some View {
        HStack(spacing: 14) {
            HStack(spacing: 12) {
                RoundIconButton(systemName: "house.fill", label: "回主页") { dismiss() }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { trickyButton(short: false); mixButton(short: false) }
                    HStack(spacing: 12) { trickyButton(short: true); mixButton(short: false) }
                    HStack(spacing: 12) { trickyButton(short: true); mixButton(short: true) }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            VStack(spacing: 4) {
                Text("加减乘除")
                    .font(.kid(50, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text("Word Problems")
                    .font(.kid(20, weight: .bold))
                    .foregroundStyle(Palette.inkSoft)
            }
            .fixedSize()
            HStack(spacing: 14) {
                Spacer(minLength: 0)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) {
                        solvedBadge
                        StarCounter(value: store.storyStarTotal)
                    }
                    // 这个游戏里拿到的星星 = 下面每一关的星星加起来
                    StarCounter(value: store.storyStarTotal)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var solvedBadge: some View {
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
    }

    /// 还有没练会的错题时，让她自己点进去再练（一次最多 5 道）
    @ViewBuilder
    private func trickyButton(short: Bool) -> some View {
        let open = store.storyOpenMistakes
        if !open.isEmpty {
            Button {
                Sound.tap()
                practicing = Array(open.prefix(Self.practiceBatch))
            } label: {
                Group {
                    if short {
                        Label("\(open.count)", systemImage: "arrow.counterclockwise")
                    } else {
                        Label("Tricky ones · \(open.count)", systemImage: "arrow.counterclockwise")
                    }
                }
                .lineLimit(1)
                .fixedSize()
            }
            .buttonStyle(PillButtonStyle(color: Palette.coral, size: 20))
            .accessibilityLabel("Tricky ones, \(open.count) to practise")
            .transition(.scale.combined(with: .opacity))
        }
    }

    /// 练一练：做过几道题以后出现，多练做得不好的题型
    @ViewBuilder
    private func mixButton(short: Bool) -> some View {
        if store.storyMixReady {
            Button {
                Sound.tap()
                if let pick = store.storyMixPick(unlockAll: unlockAll) { mixing = MixRun(pick: pick) }
            } label: {
                Group {
                    if short {
                        Image(systemName: "sparkles")
                    } else {
                        Label("Practice mix", systemImage: "sparkles")
                    }
                }
                .lineLimit(1)
                .fixedSize()
            }
            .buttonStyle(PillButtonStyle(color: Palette.sage, size: 20))
            .accessibilityLabel("Practice mix")
            .transition(.scale.combined(with: .opacity))
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
        case .steps: "Answer the hidden step first"
        }
    }
}

/// 一章：标题在上，三关横排在下。卡片的大小由首页网格算好传进来：
/// 横屏的卡又窄又高（标题、说明各占一行），竖屏的卡又宽又矮（标题旁边放星星，矮了就不放说明）。
private struct ChapterCard: View {
    let chapter: StoryChapter
    let cell: CGSize
    let best: (StoryLevel) -> Int
    let stars: (StoryLevel) -> Int
    let unlocked: (StoryLevel) -> Bool
    let recommended: StoryLevel
    let open: (StoryLevel) -> Void

    private var chapterStars: Int { chapter.levels.reduce(0) { $0 + stars($1) } }
    private var chapterMax: Int { chapter.levels.reduce(0) { $0 + $1.maxStars } }

    /// 窄卡：标题和星星分两行
    private var narrow: Bool { cell.width < 300 }
    private var pad: CGFloat { narrow ? 14 : 18 }
    /// 关卡圆圈的直径：三个圆加两段连线要放得下
    private var dot: CGFloat {
        let byWidth = (cell.width - 2 * pad - 2 * 8) / 3 - 6
        let byHeight = narrow ? 64 : (cell.height - 2 * pad - 50 - 60 - (showSubtitle ? 28 : 0))
        return max(44, min(64, byWidth, byHeight))
    }
    private var showSubtitle: Bool { narrow ? cell.height > 270 : cell.height > 228 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if narrow {
                HStack(spacing: 10) {
                    badge(size: 42)
                    Spacer(minLength: 0)
                    tally
                }
                Text("Chapter \(chapter.rawValue)")
                    .font(.kid(13, weight: .heavy))
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.top, 10)
                Text(chapter.title)
                    .font(.kid(21, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                HStack(spacing: 12) {
                    badge(size: cell.height < 215 ? 44 : 50)
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
                    tally
                }
            }
            if showSubtitle {
                Text(chapter.subtitle)
                    .font(.kid(15, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(narrow ? 2 : 1)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, narrow ? 4 : 8)
            }
            Spacer(minLength: 0)
                .frame(maxHeight: .infinity)
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(chapter.levels.enumerated()), id: \.element) { i, level in
                    if i > 0 {
                        Capsule()
                            .fill(link(i))
                            .frame(minWidth: 6, maxWidth: 40)
                            .frame(height: 5)
                            .padding(.top, dot / 2 - 2)
                    }
                    LevelNode(level: level, size: dot, cleared: best(level) >= 2, perfect: best(level) >= 3,
                              locked: !unlocked(level), stars: stars(level), tint: chapter.tint,
                              recommended: level == recommended && unlocked(level)) { open(level) }
                }
            }
            .frame(maxWidth: .infinity)
            // 给推荐关上面跳动的 "Next" 标签留出位置
            .padding(.top, 14)
            Spacer(minLength: 0)
                .frame(maxHeight: .infinity)
        }
        .padding(pad)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(colors: [chapter.tint.opacity(0.2), Palette.paper.opacity(0)],
                           startPoint: .top, endPoint: .center),
            in: RoundedRectangle(cornerRadius: 34, style: .continuous)
        )
        .softCard(radius: 34)
    }

    @ViewBuilder
    private var tally: some View {
        if chapterStars > 0 {
            StarTally(count: chapterStars, max: chapterMax, size: narrow ? 15 : 17)
                .padding(.horizontal, narrow ? 8 : 10)
                .padding(.vertical, 5)
                .background(Palette.honey.opacity(0.16), in: Capsule())
        }
    }

    private func link(_ i: Int) -> Color {
        best(chapter.levels[i - 1]) >= 2 ? chapter.tint : Palette.ink.opacity(0.08)
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

/// 一关："圆 + 下面写字和这一关拿到的星星"。过关了圆就涂满；有一次全对就戴皇冠；
/// 前一关还没过的关是灰的、带一把锁，点了只轻轻晃一下。
private struct LevelNode: View {
    let level: StoryLevel
    /// 圆圈的直径
    let size: CGFloat
    let cleared: Bool
    let perfect: Bool
    let locked: Bool
    /// 这一关拿到的星星（上限 level.maxStars）
    let stars: Int
    let tint: Color
    let recommended: Bool
    let action: () -> Void

    @State private var bounce = false
    @State private var nudge = 0

    var body: some View {
        Button {
            if locked {
                Sound.nope()
                nudge += 1
            } else {
                action()
            }
        } label: {
            VStack(spacing: 5) {
                circle(size)
                    .keyframeAnimator(initialValue: CGFloat(0), trigger: nudge) { v, x in
                        v.offset(x: x)
                    } keyframes: { _ in
                        KeyframeTrack {
                            CubicKeyframe(-8, duration: 0.07)
                            CubicKeyframe(7, duration: 0.08)
                            CubicKeyframe(-4, duration: 0.08)
                            CubicKeyframe(0, duration: 0.08)
                        }
                    }
                Text(level.short)
                    .font(.kid(14, weight: .bold))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
                    .fixedSize()
                StarTally(count: stars, max: level.maxStars, size: 14)
                    .opacity(stars > 0 ? 1 : 0.35)
            }
            .frame(minWidth: size + 2)
            .opacity(locked ? 0.6 : 1)
        }
        .buttonStyle(PressableStyle(scale: locked ? 0.98 : 0.92))
        .accessibilityLabel("Level \(level.position), \(level.mode.title), \(stars) of \(level.maxStars) stars"
                            + (perfect ? ", perfect" : "") + (locked ? ", locked" : ""))
        .onAppear {
            guard recommended else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { bounce = true }
        }
    }

    private func circle(_ d: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(cleared ? tint : Palette.paper)
                .overlay(Circle().strokeBorder(locked ? Palette.ink.opacity(0.14) : tint, lineWidth: cleared ? 0 : 3.5))
                .shadow(color: locked ? .clear : tint.opacity(cleared ? 0.45 : 0.15), radius: 10, y: 6)
            VStack(spacing: 0) {
                Image(systemName: locked ? "lock.fill" : level.mode.icon)
                    .font(.system(size: d * 0.3, weight: .bold))
                Text("\(level.position)")
                    .font(.kid(d * 0.2, weight: .heavy))
            }
            .foregroundStyle(cleared ? .white : Palette.ink.opacity(locked ? 0.35 : 0.8))
        }
        .frame(width: d, height: d)
        .overlay(alignment: .topTrailing) {
            if perfect {
                Image(systemName: "crown.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.honey)
                    .padding(5)
                    .background(.white, in: Circle())
                    .shadow(color: Palette.honey.opacity(0.5), radius: 4, y: 2)
                    .offset(x: 8, y: -6)
                    .accessibilityHidden(true)
            }
        }
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
}

/// "★ 12/24"：这里拿到几颗星星 / 最多能拿几颗
private struct StarTally: View {
    let count: Int
    var max: Int? = nil
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.85, weight: .bold))
                .foregroundStyle(count > 0 ? Palette.honey : Palette.ink.opacity(0.25))
            Text("\(count)")
                .font(.kid(size, weight: .heavy))
                .foregroundStyle(count > 0 ? Palette.ink : Palette.inkSoft)
                .monospacedDigit()
                .contentTransition(.numericText())
            if let max {
                Text("/\(max)")
                    .font(.kid(size * 0.82, weight: .bold))
                    .foregroundStyle(Palette.inkSoft)
                    .monospacedDigit()
            }
        }
        .fixedSize()
    }
}
