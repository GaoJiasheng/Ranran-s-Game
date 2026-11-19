import SwiftUI

/// 五子棋首页：在"难度阶梯"上选一档难度、选谁先下，或者和家人下。
struct GomokuSetupView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("gomoku.humanFirst") private var humanFirst = true
    /// 上次选的档位；0 表示还没选过，用推荐档
    @AppStorage("gomoku.level") private var savedLevel = 0
    @State private var config: GomokuConfig?
    @State private var appeared = false

    private var level: GomokuLevel {
        savedLevel == 0 ? store.gomokuRecommended : GomokuLevel(savedLevel)
    }

    private var selection: Binding<Int> {
        Binding(get: { level.number }, set: { savedLevel = $0 })
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
                        challengePanel(wide: wide)
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
        }
        .navigationDestination(item: $config) { c in
            GomokuGameView(config: c)
                .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        ZStack {
            VStack(spacing: 6) {
                Text("五子棋")
                    .font(.kid(54, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text("横着、竖着、斜着，谁先连成五颗谁就赢")
                    .font(.kid(20, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
            }
            HStack {
                RoundIconButton(systemName: "house.fill", label: "回主页") { dismiss() }
                Spacer()
                // 五子棋里拿到的星星 = 每一档的星星加起来
                StarCounter(value: store.gomokuStarTotal)
            }
        }
    }

    private func challengePanel(wide: Bool) -> some View {
        let showcase = LevelShowcase(level: level,
                                     stars: store.gomokuStars(level),
                                     wins: store.gomokuWins(level),
                                     recommended: level == store.gomokuRecommended,
                                     row: !wide,
                                     step: { step($0) },
                                     start: start)
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
                        recommended: store.gomokuRecommended.number,
                        stars: { store.gomokuStars(GomokuLevel($0)) })
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
                FirstMovePicker(humanFirst: $humanFirst)
                Spacer(minLength: 0)
                FamilyButton { start(twoPlayer: true) }
            }
            VStack(spacing: 20) {
                FirstMovePicker(humanFirst: $humanFirst)
                FamilyButton { start(twoPlayer: true) }
            }
        }
    }

    private func step(_ delta: Int) {
        let n = GomokuLevel(level.number + delta).number
        guard n != level.number else { return }
        Sound.step(n)
        withAnimation(.spring(duration: 0.4, bounce: 0.35)) { savedLevel = n }
    }

    private func start() { start(twoPlayer: false) }

    private func start(twoPlayer: Bool) {
        Sound.start()
        config = twoPlayer
            ? GomokuConfig(mode: .twoPlayer, humanFirst: true)
            : GomokuConfig(mode: .vsAI(level), humanFirst: humanFirst)
    }
}

// MARK: - 左边：当前这一档的对手

private struct LevelShowcase: View {
    let level: GomokuLevel
    /// 这一档一共拿到的星星
    let stars: Int
    let wins: Int
    let recommended: Bool
    /// 竖屏时头像放左边、文字放右边，给难度阶梯多留高度
    var row = false
    let step: (Int) -> Void
    let start: () -> Void

    private var o: Opponent { level.character }

    var body: some View {
        if row {
            HStack(spacing: 24) {
                portrait
                    .frame(minWidth: 150, maxWidth: 250, minHeight: 150, maxHeight: 250)
                details
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 14) {
                // 头像区跟着屏幕高度伸缩，其余部分保持原大小
                portrait.frame(minHeight: 100, maxHeight: 230)
                details
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// 当前对手的大头像，大小跟着可用空间走
    private var portrait: some View {
        GeometryReader { g in
            let k = min(g.size.width, g.size.height) / 220
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [o.tint.opacity(0.55), o.tint.opacity(0)],
                                         center: .center, startRadius: 40 * k, endRadius: 150 * k))
                    .frame(width: 300 * k, height: 300 * k)
                Avatar(image: o.image, fallback: o.emoji, tint: o.tint, size: 190 * k)
                    .id(o)
                    .transition(.asymmetric(insertion: .scale(scale: 0.5).combined(with: .opacity),
                                            removal: .scale(scale: 1.2).combined(with: .opacity)))
                    .keyframeAnimator(initialValue: 1.0, trigger: level.number) { v, s in
                        v.scaleEffect(s)
                    } keyframes: { _ in
                        SpringKeyframe(1.07, duration: 0.12)
                        SpringKeyframe(1.0, duration: 0.35, spring: .bouncy)
                    }
                if recommended {
                    Text("推荐")
                        .font(.kid(17, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Palette.coral, in: Capsule())
                        .overlay(Capsule().strokeBorder(.white, lineWidth: 3))
                        .rotationEffect(.degrees(-8))
                        .offset(x: 82 * k, y: -78 * k)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
    }

    private var details: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                StepButton(systemName: "minus", enabled: level.previous != nil) { step(-1) }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("第")
                        .font(.kid(26, weight: .bold))
                    Text("\(level.number)")
                        .font(.system(size: 58, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText(value: Double(level.number)))
                        .frame(minWidth: 72)
                    Text("档")
                        .font(.kid(26, weight: .bold))
                }
                .foregroundStyle(Palette.ink)
                .monospacedDigit()
                StepButton(systemName: "plus", enabled: level.next != nil) { step(1) }
            }

            HStack(spacing: 10) {
                Text(o.tierName)
                    .font(.kid(17, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(o.tint.opacity(0.95), in: Capsule())
                Text(o.name)
                    .font(.kid(26, weight: .heavy))
                    .foregroundStyle(Palette.ink)
            }

            Text(level.blurb)
                .font(.kid(19, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
                .contentTransition(.opacity)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: 6) {
                if wins > 0 {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Palette.honey)
                    Text("\(stars)")
                        .font(.kid(17, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                        .monospacedDigit()
                    Text("· 赢过 \(wins) 次")
                        .padding(.leading, 2)
                } else {
                    Text("还没有赢过这一档")
                }
            }
            .font(.kid(17, weight: .semibold))
            .foregroundStyle(Palette.inkSoft.opacity(0.9))
            .frame(height: 24)

            Button(action: start) {
                Label("开始挑战", systemImage: "play.fill")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(PillButtonStyle(color: Palette.coral, size: 28))
            .padding(.top, 6)
            .padding(.bottom, 6)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct StepButton: View {
    let systemName: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .frame(width: 54, height: 54)
                .background(Palette.cream, in: Circle())
                .overlay(Circle().strokeBorder(Palette.ink.opacity(0.08), lineWidth: 2))
        }
        .buttonStyle(PressableStyle(scale: 0.88))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(systemName == "plus" ? "难一点" : "简单一点")
    }
}

// MARK: - 右边：难度阶梯

/// 十根越来越高的柱子。按住左右滑动或者点一下来选档位，每换一档响一个越来越高的音。
private struct LevelLadder: View {
    @Binding var selection: Int
    let recommended: Int
    /// 每一档一共拿到的星星
    let stars: (Int) -> Int

    private let count = 10
    private let spacing: CGFloat = 10
    private let markerZone: CGFloat = 84
    private let footer: CGFloat = 76
    /// 柱子区最矮/最高多少；中间随屏幕高度伸缩
    private let minBars: CGFloat = 90
    private let maxBars: CGFloat = 420

    var body: some View {
        GeometryReader { geo in
            let barW = (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count)
            let barsHeight = min(maxBars, max(minBars, geo.size.height - markerZone - footer))
            let height = { (n: Int) in barsHeight * (0.26 + 0.74 * CGFloat(n - 1) / CGFloat(count - 1)) }
            ZStack(alignment: .topLeading) {
                ForEach(1...count, id: \.self) { n in
                    bar(n, width: barW, height: height(n), zone: barsHeight)
                        .position(x: x(n, barW), y: markerZone + barsHeight / 2)
                    tally(n)
                        .position(x: x(n, barW), y: markerZone + barsHeight + 18)
                    if n == recommended && n != selection {
                        Text("推荐")
                            .font(.kid(14, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Palette.coral, in: Capsule())
                            .position(x: x(n, barW), y: markerZone + barsHeight - height(n) - 18)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                tierBrackets(barW: barW)
                    .offset(y: markerZone + barsHeight + 38)
                marker
                    .position(x: x(selection, barW), y: markerZone + barsHeight - height(selection) - 50)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let n = Int(v.location.x / (barW + spacing)) + 1
                        select(min(max(n, 1), count))
                    }
            )
        }
        .frame(minHeight: markerZone + minBars + footer, maxHeight: markerZone + maxBars + footer)
        .accessibilityElement()
        .accessibilityLabel("难度")
        .accessibilityValue("第 \(selection) 档")
        .accessibilityAdjustableAction { dir in
            switch dir {
            case .increment: select(min(selection + 1, count))
            case .decrement: select(max(selection - 1, 1))
            @unknown default: break
            }
        }
    }

    private func x(_ n: Int, _ barW: CGFloat) -> CGFloat {
        CGFloat(n - 1) * (barW + spacing) + barW / 2
    }

    private func select(_ n: Int) {
        guard n != selection else { return }
        Sound.step(n)
        withAnimation(.spring(duration: 0.4, bounce: 0.35)) { selection = n }
    }

    private func bar(_ n: Int, width: CGFloat, height: CGFloat, zone: CGFloat) -> some View {
        let tint = GomokuLevel(n).character.tint
        let lit = n <= selection
        let selected = n == selection
        return VStack {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: min(18, width / 3), style: .continuous)
                .fill(
                    lit ? AnyShapeStyle(LinearGradient(colors: [tint, tint.opacity(0.78)], startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(tint.opacity(0.3))
                )
                .overlay(alignment: .bottom) {
                    Text("\(n)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(lit ? .white : Palette.inkSoft.opacity(0.75))
                        .padding(.bottom, 10)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: min(18, width / 3), style: .continuous)
                        .strokeBorder(.white, lineWidth: selected ? 4 : 0)
                )
                .shadow(color: selected ? tint.opacity(0.7) : .clear, radius: 12, y: 4)
                .frame(height: height)
                .scaleEffect(selected ? 1.06 : 1, anchor: .bottom)
        }
        .frame(width: width, height: zone)
    }

    /// 柱子下面："★ 7"，这一档一共拿到几颗
    private func tally(_ n: Int) -> some View {
        let k = stars(n)
        return HStack(spacing: 2) {
            Image(systemName: "star.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(k > 0 ? Palette.honey : Palette.ink.opacity(0.15))
            Text("\(k)")
                .font(.kid(13, weight: .heavy))
                .foregroundStyle(k > 0 ? Palette.ink : Palette.inkSoft.opacity(0.5))
                .monospacedDigit()
        }
    }

    /// 柱子下面按组标出"入门 / 进阶 / 高手 / 棋王"
    private func tierBrackets(barW: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Opponent.allCases) { o in
                let lo = o.levels.lowerBound, hi = o.levels.upperBound
                let left = x(lo, barW) - barW / 2
                let w = x(hi, barW) + barW / 2 - left
                let active = o.levels.contains(selection)
                VStack(spacing: 6) {
                    Capsule()
                        .fill(o.tint.opacity(active ? 1 : 0.45))
                        .frame(height: 5)
                    Text(o.tierName)
                        .font(.kid(16, weight: active ? .heavy : .semibold))
                        .foregroundStyle(active ? Palette.ink : Palette.inkSoft.opacity(0.75))
                }
                .frame(width: w)
                .offset(x: left)
            }
        }
    }

    /// 站在选中柱子顶上的小伙伴头像
    private var marker: some View {
        let o = GomokuLevel(selection).character
        return VStack(spacing: -2) {
            Avatar(image: o.image, fallback: o.emoji, tint: o.tint, size: 66)
                .id(o)
                .transition(.scale(scale: 0.4).combined(with: .opacity))
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.12), radius: 2, y: 2)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 和家人下

private struct FamilyButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
}

/// "我先下 / 让对手先"切换。
private struct FirstMovePicker: View {
    @Binding var humanFirst: Bool
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 18) {
            Text("和电脑下时")
                .font(.kid(20, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
            HStack(spacing: 0) {
                option(title: "我先下", stone: .black, selected: humanFirst) { humanFirst = true }
                option(title: "让对手先", stone: .white, selected: !humanFirst) { humanFirst = false }
            }
            .padding(6)
            .softCard(radius: 30)
        }
    }

    private func option(title: String, stone: Stone, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Sound.tap()
            withAnimation(.spring(duration: 0.35, bounce: 0.3)) { action() }
        } label: {
            HStack(spacing: 10) {
                StoneView(stone: stone, diameter: 22)
                Text(title).font(.kid(21, weight: .bold))
            }
            .foregroundStyle(selected ? .white : Palette.ink)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background {
                if selected {
                    Capsule().fill(Palette.ink).matchedGeometryEffect(id: "sel", in: ns)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
