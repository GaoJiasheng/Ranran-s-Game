import SwiftUI

/// 围棋首页：在难度阶梯上选一档（1–3 档吃子棋，4–10 档正式九路），选执黑还是执白，或者和家人下；右上角进「教学」。
struct GoSetupView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("go.humanBlack") private var humanBlack = true
    @AppStorage("go.level") private var savedLevel = 0
    @State private var config: GoConfig?
    @State private var showTutorial = false
    @State private var appeared = false

    private var level: GoLevel {
        savedLevel == 0 ? store.goRecommended : GoLevel(savedLevel)
    }

    private var selection: Binding<Int> {
        Binding(get: { level.number }, set: { savedLevel = $0 })
    }

    /// 一盘都没下过、教学也没学过：先建议去学规则
    private var newcomer: Bool {
        GoLevel.all.allSatisfy { store.goWins($0) == 0 }
            && !store.lessonDone("go", "go1") && store.records(for: "go").isEmpty
    }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            ZStack {
                CreamBackground(accent: level.character.tint)
                    .animation(.easeInOut(duration: 0.6), value: level.character)
                AdaptivePage {
                    VStack(spacing: wide ? 20 : 26) {
                        header
                        if newcomer { learnFirst }
                        panel(wide: wide)
                            .frame(maxHeight: .infinity)
                            .offset(y: appeared ? 0 : 50)
                            .opacity(appeared ? 1 : 0)
                        bottomRow
                            .offset(y: appeared ? 0 : 50)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(duration: 0.6, bounce: 0.3).delay(0.08), value: appeared)
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
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "tutorial") { showTutorial = true }
            if UserDefaults.standard.bool(forKey: "play") { start(twoPlayer: false) }
            #endif
        }
        .navigationDestination(item: $config) { c in
            GoGameView(config: c).toolbar(.hidden, for: .navigationBar)
        }
        .navigationDestination(isPresented: $showTutorial) {
            TutorialHomeView(game: "go", accent: Palette.sage, onPlay: playFromTutorial)
                .toolbar(.hidden, for: .navigationBar)
        }
    }

    /// 教学里学完一组点「去下一盘」：回到这里，选好那一档
    private func playFromTutorial(_ level: Int) {
        savedLevel = level
        showTutorial = false
    }

    private var header: some View {
        ZStack {
            VStack(spacing: 6) {
                Text("围棋")
                    .font(.kid(54, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text("围住的地越多越好，先从吃子棋玩起")
                    .font(.kid(20, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
            }
            HStack(spacing: 14) {
                RoundIconButton(systemName: "house.fill", label: "回主页") { dismiss() }
                Spacer()
                TutorialButton { showTutorial = true }
                // 赢棋、第一次赢的加奖、上课、复习拿到的星星全都算
                StarCounter(value: store.stars(prefix: "go.stars."))
            }
        }
    }

    /// 第一次来：先去学规则
    private var learnFirst: some View {
        Button {
            Sound.tap()
            showTutorial = true
        } label: {
            HStack(spacing: 16) {
                ArtImage(name: "tutor_go_basic", fallback: "🦉", contentMode: .fit)
                    .frame(width: 70, height: 70)
                VStack(alignment: .leading, spacing: 2) {
                    Text("第一次下围棋？")
                        .font(.kid(22, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                    Text("先跟猫头鹰老师学会气和提子")
                        .font(.kid(17, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                }
                Spacer(minLength: 0)
                Label("去学习", systemImage: "graduationcap.fill")
                    .font(.kid(20, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Palette.coral, in: Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Palette.honey.opacity(0.22), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }

    private func panel(wide: Bool) -> some View {
        let showcase = LevelShowcase(level: level.info,
                                     stars: store.goStars(level),
                                     wins: store.goWins(level),
                                     preview: store.winPreview(game: "go", level: level.number),
                                     recommended: level == store.goRecommended,
                                     row: !wide,
                                     step: { step($0) },
                                     start: { start(twoPlayer: false) })
        let ladder = VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("选择难度")
                    .font(.kid(26, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Label("按住左右滑动", systemImage: "hand.draw.fill")
                    .font(.kid(17, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft.opacity(0.85))
            }
            LevelLadder(selection: selection,
                        recommended: store.goRecommended.number,
                        stars: { store.goStars(GoLevel($0)) })
        }
        return Group {
            if wide {
                HStack(alignment: .center, spacing: 44) {
                    showcase.frame(width: 360)
                    ladder
                }
            } else {
                VStack(spacing: 24) {
                    showcase
                    ladder
                }
            }
        }
        .padding(wide ? 36 : 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [level.character.tint.opacity(0.20), Palette.paper.opacity(0)],
                           startPoint: .topLeading, endPoint: .center),
            in: RoundedRectangle(cornerRadius: 44, style: .continuous)
        )
        .softCard(radius: 44)
    }

    private var bottomRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 24) {
                SidePicker(humanBlack: $humanBlack)
                Spacer(minLength: 0)
                familyButton
            }
            VStack(spacing: 20) {
                SidePicker(humanBlack: $humanBlack)
                familyButton
            }
        }
    }

    private var familyButton: some View {
        Button { start(twoPlayer: true) } label: {
            HStack(spacing: 18) {
                ZStack {
                    StoneView(stone: .black, diameter: 34).offset(x: -11, y: 3)
                    StoneView(stone: .white, diameter: 34).offset(x: 11, y: -3)
                }
                .frame(width: 64, height: 64)
                .background(Circle().fill(Palette.sky.opacity(0.45)))
                .overlay(Circle().strokeBorder(.white, lineWidth: 4))
                VStack(alignment: .leading, spacing: 2) {
                    Text("和家人下")
                        .font(.kid(24, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                    Text("同一台 iPad 轮流下")
                        .font(.kid(16, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Palette.inkSoft.opacity(0.6))
                    .padding(.leading, 8)
            }
            .padding(.vertical, 12)
            .padding(.leading, 12)
            .padding(.trailing, 26)
            .softCard(radius: 44)
        }
        .buttonStyle(PressableStyle())
    }

    private func step(_ delta: Int) {
        let n = GoLevel(level.number + delta).number
        guard n != level.number else { return }
        Sound.step(n)
        withAnimation(.spring(duration: 0.4, bounce: 0.35)) { savedLevel = n }
    }

    private func start(twoPlayer: Bool) {
        Sound.start()
        config = twoPlayer
            ? GoConfig(mode: .twoPlayer, humanBlack: true)
            : GoConfig(mode: .vsAI(level), humanBlack: humanBlack)
    }
}

/// "我执黑（先下）/ 我执白"
private struct SidePicker: View {
    @Binding var humanBlack: Bool
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 18) {
            Text("和电脑下时")
                .font(.kid(20, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
            HStack(spacing: 0) {
                option("我执黑先下", stone: .black, selected: humanBlack) { humanBlack = true }
                option("我执白", stone: .white, selected: !humanBlack) { humanBlack = false }
            }
            .padding(6)
            .softCard(radius: 30)
        }
    }

    private func option(_ title: String, stone: Stone, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Sound.tap()
            withAnimation(.spring(duration: 0.35, bounce: 0.3)) { action() }
        } label: {
            HStack(spacing: 10) {
                StoneView(stone: stone, diameter: 22)
                Text(title).font(.kid(21, weight: .bold))
            }
            .foregroundStyle(selected ? .white : Palette.ink)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background {
                if selected { Capsule().fill(Palette.ink).matchedGeometryEffect(id: "sel", in: ns) }
            }
        }
        .buttonStyle(.plain)
    }
}
