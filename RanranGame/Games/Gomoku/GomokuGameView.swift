import SwiftUI

struct GomokuGameView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var game: GomokuGame
    @State private var showResult = false
    @State private var awardedRounds: Set<Int> = []
    @State private var countedLosses: Set<Int> = []
    @State private var resultTask: Task<Void, Never>?
    @State private var lastResult = RoundResult()
    /// 在当前档位连续输了几局（用来建议降一档）
    @State private var lossStreak = 0
    @AppStorage("gomoku.level") private var savedLevel = 0

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
                                  result: lastResult,
                                  lossStreak: lossStreak,
                                  onAgain: { restart() },
                                  onLevel: { changeLevel($0) },
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
            if let o = game.opponent, let level = game.level {
                PlayerCard(avatar: .art(o.image, o.emoji, o.tint), name: o.name, stone: stone,
                           active: game.turn == stone && !game.isOver, thinking: game.aiThinking,
                           speech: game.speech, badge: ("第 \(level.number) 档", o.tint))
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
                PlayerCard(avatar: .art("avatar_ranran", "👧", Palette.blush), name: store.name, stone: game.humanColor,
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
            return game.humanWon ? "\(store.name)赢啦！🎉" : "\(game.opponent!.name)赢了这一局"
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

    private func changeLevel(_ level: GomokuLevel) {
        savedLevel = level.number
        lossStreak = 0
        withAnimation(.spring(duration: 0.35)) { showResult = false }
        game.changeLevel(level)
    }

    private func leave() {
        game.stop()
        dismiss()
    }

    private func handleGameOver() {
        let round = game.round
        store.saveRecord(game.makeRecord(stars: game.humanWon && !game.isTwoPlayer ? game.winStars : 0))
        if let level = game.level {
            if game.humanWon, !awardedRounds.contains(round) {
                awardedRounds.insert(round)
                let stars = game.winStars
                let record = store.recordGomokuWin(level, stars: stars)
                store.addStars(stars)
                lastResult = RoundResult(stars: stars, usedUndo: game.usedUndo, usedHint: game.usedHint, isRecord: record)
                lossStreak = 0
            } else if !game.humanWon, game.winner != nil, !countedLosses.contains(round) {
                countedLosses.insert(round)
                lastResult = RoundResult()
                lossStreak += 1
            }
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
    var badge: (String, Color)? = nil

    var body: some View {
        HStack(spacing: 16) {
            avatarView
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(name)
                        .font(.kid(28, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                    if let (text, tint) = badge {
                        Text(text)
                            .font(.kid(15, weight: .heavy))
                            .foregroundStyle(Palette.ink.opacity(0.8))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(tint.opacity(0.45), in: Capsule())
                            .fixedSize()
                    }
                }
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

/// 一局人机对战赢下来的成绩
struct RoundResult {
    var stars = 0
    var usedUndo = false
    var usedHint = false
    var isRecord = false
}

struct ResultOverlay: View {
    let game: GomokuGame
    let result: RoundResult
    let lossStreak: Int
    let onAgain: () -> Void
    let onLevel: (GomokuLevel) -> Void
    let onReview: () -> Void
    let onLeave: () -> Void

    @State private var appeared = false
    @State private var litStars = 0
    @State private var showRecord = false

    private var vsAI: Bool { !game.isTwoPlayer }
    private var aiWin: Bool { vsAI && game.humanWon }
    /// 输了两局以上，建议降一档
    private var easier: GomokuLevel? {
        guard vsAI, !game.humanWon, !game.isDraw, lossStreak >= 2 else { return nil }
        return game.level?.previous
    }

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            Color.black.opacity(0.12).ignoresSafeArea()
            if game.humanWon || game.isTwoPlayer && game.winner != nil { ConfettiView() }

            VStack(spacing: 18) {
                avatar
                    .padding(.top, -110)

                Text(title)
                    .font(.kid(50, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text(subtitle)
                    .font(.kid(23, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)

                if aiWin { starMedals }

                if let easier {
                    suggestion(easier)
                }

                HStack(spacing: 18) {
                    primaryButton
                    secondaryButton
                }
                .padding(.top, 6)

                HStack(spacing: 36) {
                    Button { Sound.tap(); onReview() } label: {
                        Label("看看棋盘", systemImage: "eye")
                    }
                    Button { Sound.tap(); onLeave() } label: {
                        Label(vsAI ? "换个难度" : "返回", systemImage: vsAI ? "slider.horizontal.3" : "chevron.left")
                    }
                }
                .font(.kid(19, weight: .bold))
                .foregroundStyle(Palette.inkSoft)
                .padding(.top, 2)
            }
            .padding(.horizontal, 60)
            .padding(.bottom, 36)
            .padding(.top, 20)
            .frame(minWidth: 560)
            .softCard(radius: 44)
            .overlay(alignment: .topTrailing) {
                if showRecord {
                    Text("新纪录！")
                        .font(.kid(22, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(Palette.coral, in: Capsule())
                        .overlay(Capsule().strokeBorder(.white, lineWidth: 4))
                        .rotationEffect(.degrees(10))
                        .offset(x: 26, y: -10)
                        .transition(.scale(scale: 2.2).combined(with: .opacity))
                }
            }
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)
        }
        .task {
            withAnimation(.spring(duration: 0.5, bounce: 0.4)) { appeared = true }
            guard aiWin else { return }
            for i in 0..<result.stars {
                try? await Task.sleep(for: .milliseconds(i == 0 ? 500 : 300))
                Sound.step(6 + i * 2)
                withAnimation(.spring(duration: 0.45, bounce: 0.6)) { litStars = i + 1 }
            }
            if result.isRecord {
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation(.spring(duration: 0.5, bounce: 0.5)) { showRecord = true }
            }
        }
    }

    // MARK: 三颗星：赢了 / 没悔棋 / 没用提示

    private var starMedals: some View {
        let earned = [true, !result.usedUndo, !result.usedHint]
        let captions = ["赢下比赛", "没有悔棋", "没用提示"]
        // 拿到的星排在前面依次点亮
        let order = earned.indices.sorted { earned[$0] && !earned[$1] }
        return HStack(spacing: 26) {
            ForEach(0..<3, id: \.self) { i in
                let got = earned[i]
                let lit = got && (order.firstIndex(of: i) ?? 0) < litStars
                VStack(spacing: 8) {
                    ZStack {
                        Image(systemName: "star.fill")
                            .font(.system(size: 52, weight: .bold))
                            .foregroundStyle(Palette.ink.opacity(0.08))
                        Image(systemName: "star.fill")
                            .font(.system(size: 52, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: [Palette.honey, Palette.coral],
                                                            startPoint: .top, endPoint: .bottom))
                            .shadow(color: Palette.honey.opacity(0.6), radius: 10)
                            .scaleEffect(lit ? 1 : 0.2)
                            .opacity(lit ? 1 : 0)
                    }
                    .offset(y: i == 1 ? -10 : 0)
                    Text(captions[i])
                        .font(.kid(15, weight: .bold))
                        .foregroundStyle(got ? Palette.inkSoft : Palette.inkSoft.opacity(0.4))
                        .strikethrough(!got, color: Palette.inkSoft.opacity(0.4))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func suggestion(_ easier: GomokuLevel) -> some View {
        HStack(spacing: 14) {
            Avatar(image: easier.character.image, fallback: easier.character.emoji, tint: easier.character.tint, size: 54)
            Text("连着输了 \(lossStreak) 局，先去第 \(easier.number) 档练练手？")
                .font(.kid(19, weight: .bold))
                .foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(easier.character.tint.opacity(0.22), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder private var primaryButton: some View {
        if aiWin, let next = game.level?.next {
            Button { Sound.tap(); onLevel(next) } label: {
                Label("挑战第 \(next.number) 档", systemImage: "arrow.up.right")
            }
            .buttonStyle(PillButtonStyle(color: Palette.coral))
        } else if let easier {
            Button { Sound.tap(); onLevel(easier) } label: {
                Label("去第 \(easier.number) 档", systemImage: "arrow.down.right")
            }
            .buttonStyle(PillButtonStyle(color: easier.character.tint))
        } else {
            Button("再来一局") { Sound.tap(); onAgain() }
                .buttonStyle(PillButtonStyle(color: Palette.coral))
        }
    }

    @ViewBuilder private var secondaryButton: some View {
        if (aiWin && game.level?.next != nil) || easier != nil {
            Button("再来一局") { Sound.tap(); onAgain() }
                .buttonStyle(PillButtonStyle(color: Palette.paper, foreground: Palette.ink, size: 22))
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
        if game.humanWon { return game.level?.next == nil ? "你打败了棋王！" : "你赢啦！" }
        return "\(game.opponent?.name ?? "")赢了"
    }

    private var subtitle: String {
        if game.isDraw { return "棋盘都下满啦，你们一样厉害" }
        if game.isTwoPlayer { return "下得真精彩，再来一局吧" }
        if game.humanWon {
            let o = game.opponent?.loseLine ?? ""
            return "\(o)  获得 \(result.stars) 颗星星"
        }
        return "差一点点！点「悔棋」或者再来一局吧"
    }
}
