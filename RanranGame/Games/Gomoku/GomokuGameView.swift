import SwiftUI

struct GomokuGameView: View {
    @Environment(StarStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var game: GomokuGame
    @State private var showResult = false
    @State private var awardedRounds: Set<Int> = []
    @State private var resultTask: Task<Void, Never>?

    init(config: GomokuConfig) {
        _game = State(initialValue: GomokuGame(config: config))
    }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            ZStack {
                CreamBackground(accent: game.opponent?.tint ?? Palette.sky)

                if landscape {
                    HStack(spacing: 32) {
                        BoardView(game: game)
                            .padding(.vertical, 8)
                        sidePanel
                            .frame(width: min(360, geo.size.width * 0.3))
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                } else {
                    VStack(spacing: 20) {
                        HStack(spacing: 16) {
                            RoundIconButton(systemName: "chevron.left", label: "返回") { leave() }
                            topCard
                            bottomCard
                        }
                        statusLine
                        BoardView(game: game)
                        controls
                    }
                    .padding(28)
                }

                if showResult {
                    ResultOverlay(game: game,
                                  starsEarned: game.humanWon ? (game.opponent?.stars ?? 0) : 0,
                                  onAgain: { restart() },
                                  onReview: { withAnimation(.spring(duration: 0.35)) { showResult = false } },
                                  onLeave: { leave() })
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
        }
        .onAppear { game.begin() }
        .onDisappear { game.stop(); resultTask?.cancel() }
        .onChange(of: game.isOver) { _, over in
            resultTask?.cancel()
            guard over else {
                withAnimation { showResult = false }
                return
            }
            handleGameOver()
        }
    }

    // MARK: - 侧边栏

    private var sidePanel: some View {
        VStack(spacing: 18) {
            HStack {
                RoundIconButton(systemName: "chevron.left", label: "返回") { leave() }
                Spacer()
                Text("五子棋")
                    .font(.kid(30, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Color.clear.frame(width: 64, height: 64)
            }
            .padding(.bottom, 8)

            topCard
            statusLine
            bottomCard

            Spacer(minLength: 12)
            controls
        }
    }

    /// 上面一张：电脑对手（或双人模式的白棋）
    private var topCard: some View {
        let stone = game.isTwoPlayer ? Stone.white : game.humanColor.opponent
        return Group {
            if let o = game.opponent {
                PlayerCard(avatar: .art(o.image, o.emoji, o.tint), name: o.name, stone: stone,
                           active: game.turn == stone && !game.isOver, thinking: game.aiThinking,
                           speech: game.speech)
            } else {
                PlayerCard(avatar: .stone(.white), name: "白棋", stone: .white,
                           active: game.turn == .white && !game.isOver, thinking: false, speech: nil)
            }
        }
    }

    /// 下面一张：然然（或双人模式的黑棋）
    private var bottomCard: some View {
        Group {
            if game.isTwoPlayer {
                PlayerCard(avatar: .stone(.black), name: "黑棋", stone: .black,
                           active: game.turn == .black && !game.isOver, thinking: false, speech: nil)
            } else {
                PlayerCard(avatar: .art("avatar_ranran", "👧", Palette.blush), name: "然然", stone: game.humanColor,
                           active: game.turn == game.humanColor && !game.isOver, thinking: false, speech: nil)
            }
        }
    }

    private var statusLine: some View {
        Text(statusText)
            .font(.kid(20, weight: .semibold))
            .foregroundStyle(Palette.inkSoft)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: statusText)
    }

    private var statusText: String {
        if game.isDraw { return "棋盘下满啦，平局！" }
        if let w = game.winner {
            if game.isTwoPlayer { return "\(w.name)赢啦！" }
            return game.humanWon ? "然然赢啦！🎉" : "\(game.opponent!.name)赢了这一局"
        }
        if game.aiThinking { return "\(game.opponent!.name)正在想下哪里…" }
        if game.isTwoPlayer { return "轮到\(game.turn.name)" }
        if !game.threats.isEmpty { return "快把闪烁的地方堵住！" }
        if game.moves.count < 2 { return "按住棋盘瞄准，松开手指就落子" }
        return "轮到你啦"
    }

    private var controls: some View {
        HStack(spacing: 14) {
            ControlButton(systemName: "arrow.uturn.backward", label: "悔棋", enabled: game.canUndo) { game.undo() }
            ControlButton(systemName: "lightbulb.max", label: "提示", enabled: game.canHumanMove) { game.showHint() }
            ControlButton(systemName: "arrow.clockwise", label: "重来", enabled: !game.moves.isEmpty) { restart() }
        }
    }

    // MARK: - 动作

    private func restart() {
        withAnimation(.spring(duration: 0.35)) { showResult = false }
        game.restart()
    }

    private func leave() {
        game.stop()
        dismiss()
    }

    private func handleGameOver() {
        let round = game.round
        if game.humanWon, let o = game.opponent, !awardedRounds.contains(round) {
            awardedRounds.insert(round)
            store.addStars(o.stars)
            store.increment("gomoku.win.\(o.rawValue)")
        }
        resultTask = Task {
            try? await Task.sleep(for: .milliseconds(game.winner != nil ? 1300 : 500))
            guard !Task.isCancelled, game.isOver else { return }
            (game.humanWon || game.isTwoPlayer) ? Sound.win() : Sound.lose()
            withAnimation(.spring(duration: 0.45)) { showResult = true }
        }
    }
}

// MARK: - 玩家卡片

enum AvatarKind {
    case art(String, String, Color)
    case stone(Stone)
}

struct PlayerCard: View {
    let avatar: AvatarKind
    let name: String
    let stone: Stone
    let active: Bool
    let thinking: Bool
    let speech: String?

    var body: some View {
        HStack(spacing: 16) {
            avatarView
            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.kid(28, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                HStack(spacing: 8) {
                    StoneView(stone: stone, diameter: 20)
                    Text(stone.name)
                        .font(.kid(18, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            Spacer(minLength: 0)
            if thinking {
                ThinkingDots()
                    .transition(.scale.combined(with: .opacity))
            } else if active {
                Circle()
                    .fill(Palette.coral)
                    .frame(width: 14, height: 14)
                    .shadow(color: Palette.coral.opacity(0.7), radius: 6)
                    .transition(.scale)
            }
        }
        .padding(16)
        .softCard(radius: 30)
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Palette.coral.opacity(active ? 0.9 : 0), lineWidth: 3)
        )
        .scaleEffect(active ? 1 : 0.96)
        .opacity(active ? 1 : 0.78)
        .overlay(alignment: .bottomLeading) {
            if let speech {
                SpeechBubble(text: speech)
                    .offset(x: 24, y: 0)
                    .alignmentGuide(.bottom) { d in d[.top] - 10 }
                    .transition(.scale(scale: 0.6, anchor: .topLeading).combined(with: .opacity))
            }
        }
        .zIndex(speech == nil ? 0 : 5)
        .animation(.spring(duration: 0.35, bounce: 0.3), value: active)
        .animation(.spring(duration: 0.35), value: thinking)
    }

    @ViewBuilder private var avatarView: some View {
        switch avatar {
        case let .art(image, fallback, tint):
            Avatar(image: image, fallback: fallback, tint: tint, size: 80)
        case let .stone(s):
            StoneView(stone: s, diameter: 60)
                .frame(width: 80, height: 80)
                .background(Circle().fill(Palette.cream))
                .overlay(Circle().strokeBorder(.white, lineWidth: 4))
        }
    }
}

struct SpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.kid(19, weight: .bold))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(alignment: .topLeading) {
                Triangle()
                    .fill(.white)
                    .frame(width: 18, height: 11)
                    .offset(x: 26, y: -10)
            }
            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
            .fixedSize()
    }
}

private struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.midX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.closeSubpath()
        }
    }
}

struct ThinkingDots: View {
    @State private var phase = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Palette.inkSoft.opacity(0.7))
                    .frame(width: 10, height: 10)
                    .offset(y: phase ? -6 : 2)
                    .animation(.easeInOut(duration: 0.45).repeatForever().delay(Double(i) * 0.15), value: phase)
            }
        }
        .onAppear { phase = true }
    }
}

struct ControlButton: View {
    let systemName: String
    let label: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button {
            Sound.tap()
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 28, weight: .bold))
                Text(label)
                    .font(.kid(18, weight: .bold))
            }
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .softCard(radius: 26)
        }
        .buttonStyle(PressableStyle(scale: 0.92))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .animation(.easeInOut(duration: 0.2), value: enabled)
    }
}

// MARK: - 结果

struct ResultOverlay: View {
    let game: GomokuGame
    let starsEarned: Int
    let onAgain: () -> Void
    let onReview: () -> Void
    let onLeave: () -> Void

    @State private var appeared = false
    @State private var litStars = 0

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            Color.black.opacity(0.12).ignoresSafeArea()
            if game.humanWon || game.isTwoPlayer && game.winner != nil { ConfettiView() }

            VStack(spacing: 20) {
                avatar
                    .padding(.top, -110)

                Text(title)
                    .font(.kid(52, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text(subtitle)
                    .font(.kid(24, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)

                if starsEarned > 0 {
                    HStack(spacing: 14) {
                        ForEach(0..<starsEarned, id: \.self) { i in
                            Image(systemName: "star.fill")
                                .font(.system(size: 54, weight: .bold))
                                .foregroundStyle(LinearGradient(colors: [Palette.honey, Palette.coral],
                                                                startPoint: .top, endPoint: .bottom))
                                .shadow(color: Palette.honey.opacity(0.6), radius: 10)
                                .scaleEffect(i < litStars ? 1 : 0.2)
                                .opacity(i < litStars ? 1 : 0)
                        }
                    }
                    .frame(height: 64)
                }

                HStack(spacing: 20) {
                    Button("再来一局") { Sound.tap(); onAgain() }
                        .buttonStyle(PillButtonStyle(color: Palette.coral))
                    Button("看看棋盘") { Sound.tap(); onReview() }
                        .buttonStyle(PillButtonStyle(color: Palette.paper, foreground: Palette.ink, size: 22))
                }
                .padding(.top, 8)

                Button("换个对手") { Sound.tap(); onLeave() }
                    .font(.kid(20, weight: .bold))
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 64)
            .padding(.bottom, 40)
            .padding(.top, 20)
            .frame(minWidth: 520)
            .softCard(radius: 44)
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)
        }
        .task {
            withAnimation(.spring(duration: 0.5, bounce: 0.4)) { appeared = true }
            for i in 0..<starsEarned {
                try? await Task.sleep(for: .milliseconds(i == 0 ? 450 : 260))
                withAnimation(.spring(duration: 0.45, bounce: 0.6)) { litStars = i + 1 }
            }
        }
    }

    @ViewBuilder private var avatar: some View {
        if game.isTwoPlayer, let w = game.winner {
            StoneView(stone: w, diameter: 130)
                .frame(width: 180, height: 180)
                .background(Circle().fill(Palette.cream))
                .overlay(Circle().strokeBorder(.white, lineWidth: 8))
        } else if game.humanWon || game.isDraw || game.opponent == nil {
            Avatar(image: "avatar_ranran", fallback: "👧", tint: Palette.blush, size: 180)
        } else if let o = game.opponent {
            Avatar(image: o.image, fallback: o.emoji, tint: o.tint, size: 180)
        }
    }

    private var title: String {
        if game.isDraw { return "平局！" }
        if game.isTwoPlayer { return "\(game.winner?.name ?? "")赢啦！" }
        return game.humanWon ? "你赢啦！" : "\(game.opponent?.name ?? "")赢了"
    }

    private var subtitle: String {
        if game.isDraw { return "棋盘都下满啦，你们一样厉害" }
        if game.isTwoPlayer { return "下得真精彩，再来一局吧" }
        if game.humanWon { return "\(game.opponent?.loseLine ?? "")  获得 \(starsEarned) 颗星星" }
        return "差一点点！点「悔棋」或者再来一局吧"
    }
}
