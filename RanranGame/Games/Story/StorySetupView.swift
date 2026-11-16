import SwiftUI

/// 「小伙伴的故事」首页：五章，每章三关（演一演 → 先猜再演 → 只看文字）。
struct StorySetupView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var playing: StoryLevel?
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            ZStack {
                CreamBackground(accent: Palette.sage)
                ScrollView {
                    VStack(spacing: 22) {
                        header
                        intro
                        ForEach(Array(StoryChapter.allCases.enumerated()), id: \.element) { i, chapter in
                            ChapterRow(chapter: chapter, wide: wide,
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
                    .padding(.horizontal, 40)
                    .padding(.vertical, 28)
                    .frame(maxWidth: 1240)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
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

private struct ChapterRow: View {
    let chapter: StoryChapter
    let wide: Bool
    let best: (StoryLevel) -> Int
    let recommended: StoryLevel
    let open: (StoryLevel) -> Void

    var body: some View {
        let info = HStack(spacing: 18) {
            Image(systemName: chapter.icon)
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 74, height: 74)
                .background(chapter.tint.gradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: chapter.tint.opacity(0.45), radius: 10, y: 6)
            VStack(alignment: .leading, spacing: 4) {
                Text("第 \(chapter.rawValue) 章")
                    .font(.kid(16, weight: .heavy))
                    .foregroundStyle(Palette.inkSoft)
                Text(chapter.title)
                    .font(.kid(32, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text(chapter.subtitle)
                    .font(.kid(18, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 0)
        }
        let nodes = HStack(spacing: 0) {
            ForEach(Array(chapter.levels.enumerated()), id: \.element) { i, level in
                if i > 0 {
                    Capsule()
                        .fill(best(chapter.levels[i - 1]) > 0 ? chapter.tint : Palette.ink.opacity(0.08))
                        .frame(width: 28, height: 6)
                        .padding(.bottom, 44)
                }
                LevelNode(level: level, stars: best(level), tint: chapter.tint,
                          recommended: level == recommended) { open(level) }
            }
        }

        Group {
            if wide {
                HStack(spacing: 24) { info; nodes }
            } else {
                VStack(alignment: .leading, spacing: 20) { info; nodes.frame(maxWidth: .infinity) }
            }
        }
        .padding(26)
        .background(
            LinearGradient(colors: [chapter.tint.opacity(0.18), Palette.paper.opacity(0)],
                           startPoint: .leading, endPoint: .center),
            in: RoundedRectangle(cornerRadius: 40, style: .continuous)
        )
        .softCard(radius: 40)
    }
}

private struct LevelNode: View {
    let level: StoryLevel
    let stars: Int
    let tint: Color
    let recommended: Bool
    let action: () -> Void

    @State private var bounce = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(stars > 0 ? tint : Palette.paper)
                        .overlay(Circle().strokeBorder(tint, lineWidth: stars > 0 ? 0 : 3.5))
                        .shadow(color: tint.opacity(stars > 0 ? 0.45 : 0.15), radius: 10, y: 6)
                    VStack(spacing: 0) {
                        Image(systemName: level.mode.icon)
                            .font(.system(size: 26, weight: .bold))
                        Text("\(level.number)")
                            .font(.kid(17, weight: .heavy))
                    }
                    .foregroundStyle(stars > 0 ? .white : Palette.ink.opacity(0.8))
                }
                .frame(width: 86, height: 86)
                .overlay(alignment: .top) {
                    if recommended {
                        Text("推荐")
                            .font(.kid(14, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Palette.coral, in: Capsule())
                            .overlay(Capsule().strokeBorder(.white, lineWidth: 2.5))
                            .offset(y: bounce ? -20 : -14)
                    }
                }
                Text(level.mode.title)
                    .font(.kid(15, weight: .bold))
                    .foregroundStyle(Palette.inkSoft)
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: "star.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(i < stars ? Palette.honey : Palette.ink.opacity(0.1))
                    }
                }
            }
            .frame(width: 104)
        }
        .buttonStyle(PressableStyle(scale: 0.92))
        .accessibilityLabel("第 \(level.number) 关，\(level.mode.title)，\(stars) 颗星")
        .onAppear {
            guard recommended else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { bounce = true }
        }
    }
}
