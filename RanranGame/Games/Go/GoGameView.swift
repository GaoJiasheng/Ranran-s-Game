import SwiftUI

struct GoGameView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var game: GoGame
    @State private var showResult = false
    @State private var awardedRounds: Set<Int> = []
    @State private var countedLosses: Set<Int> = []
    @State private var resultTask: Task<Void, Never>?
    @State private var lastResult = RoundResult()
    @State private var lossStreak = 0
    @AppStorage("go.level") private var savedLevel = 0

    init(config: GoConfig) {
        _game = State(initialValue: GoGame(config: config))
    }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            ZStack {
                CreamBackground(accent: game.opponent?.tint ?? Palette.sage)
                if landscape {
                    HStack(spacing: 32) {
                        board.padding(.vertical, 8)
                        sidePanel.frame(width: min(360, geo.size.width * 0.3))
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                } else {
                    VStack(spacing: 18) {
                        HStack(spacing: 16) {
                            RoundIconButton(systemName: "chevron.left", label: "返回") { leave() }
                            topCard
                            bottomCard
                        }
                        statusLine
                        board
                        controls
                    }
                    .padding(28)
                }
                if showResult {
                    GoResultOverlay(game: game, result: lastResult, lossStreak: lossStreak,
                                    onAgain: { restart() }, onLevel: { changeLevel($0) },
                                    onReview: { withAnimation(.spring(duration: 0.35)) { showResult = false } },
                                    onLeave: { leave() })
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
        }
        .onAppear {
            game.begin()
            #if DEBUG
            if UserDefaults.standard.string(forKey: "winDemo") != nil, !game.isTwoPlayer { game.debugWin() }
            #endif
        }
        .onDisappear { game.stop(); resultTask?.cancel() }
        .onChange(of: game.isOver) { _, over in
            resultTask?.cancel()
            guard over else { withAnimation { showResult = false }; return }
            handleGameOver()
        }
    }

    private var board: some View {
        GoBoardView(state: GoBoardState(
            board: game.board, lastMove: game.lastMove, hint: game.hint,
            owner: game.score?.owner, dead: game.score?.dead ?? [],
            aiming: game.canHumanMove, aimColor: game.turn
        )) { game.humanPlay($0) }
    }

    private var sidePanel: some View {
        VStack(spacing: 18) {
            HStack {
                RoundIconButton(systemName: "chevron.left", label: "返回") { leave() }
                Spacer()
                Text("围棋")
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

    private var topCard: some View {
        let stone: GoStone = game.isTwoPlayer ? .white : game.humanColor.other
        return Group {
            if let o = game.opponent, let level = game.level {
                PlayerCard(avatar: .art(o.image, o.emoji, o.tint), name: o.name, stone: stone == .black ? .black : .white,
                           active: game.turn == stone && !game.isOver, thinking: game.aiThinking,
                           speech: game.speech, badge: ("第 \(level.number) 档", o.tint))
            } else {
                PlayerCard(avatar: .stone(.white), name: "白棋", stone: .white,
                           active: game.turn == .white && !game.isOver, thinking: false, speech: game.speech)
            }
        }
    }

    private var bottomCard: some View {
        Group {
            if game.isTwoPlayer {
                PlayerCard(avatar: .stone(.black), name: "黑棋", stone: .black,
                           active: game.turn == .black && !game.isOver, thinking: false, speech: nil)
            } else {
                PlayerCard(avatar: .art("avatar_ranran", "👧", Palette.blush), name: store.name,
                           stone: game.humanColor == .black ? .black : .white,
                           active: game.turn == game.humanColor && !game.isOver, thinking: false, speech: nil)
            }
        }
    }

    /// 状态 + 提子数；固定高度，换文字时棋盘不动
    private var statusLine: some View {
        VStack(spacing: 4) {
            Text(statusText)
                .font(.kid(20, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(captureText)
                .font(.kid(16, weight: .bold))
                .foregroundStyle(Palette.inkSoft.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .contentTransition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: statusText)
    }

    private var statusText: String {
        if let w = game.winner {
            if game.isTwoPlayer { return "\(w.name)赢啦！" }
            return game.humanWon ? "\(store.name)赢啦！🎉" : "\(game.opponent!.name)赢了这一局"
        }
        if game.counting { return "双方都停一手了，正在数子…" }
        if game.aiThinking, !game.isTwoPlayer, game.turn != game.humanColor { return "\(game.opponent!.name)正在想…" }
        if game.lastWasPass { return "对方停了一手。你也停一手就数子" }
        if game.isTwoPlayer { return "轮到\(game.turn.name)" }
        if game.moves.count < 2 { return "按住棋盘瞄准，松开手指就落子" }
        return "轮到你啦"
    }

    private var captureText: String {
        if let t = game.captureTarget {
            return "吃子棋 · 先吃到 \(t) 颗赢　黑提 \(game.prisoners(.black)) · 白提 \(game.prisoners(.white))"
        }
        return "黑提 \(game.prisoners(.black)) 子 · 白提 \(game.prisoners(.white)) 子 · 白贴 7.5"
    }

    private var controls: some View {
        HStack(spacing: 14) {
            ControlButton(systemName: "arrow.uturn.backward", label: "悔棋", enabled: game.canUndo) { game.undo() }
            ControlButton(systemName: "lightbulb.max", label: "提示", enabled: game.canHumanMove) { game.showHint() }
            if game.captureTarget == nil {
                ControlButton(systemName: "hand.raised.fill", label: "停一手", enabled: game.canHumanMove && game.moves.count >= 10) { game.humanPass() }
            }
            ControlButton(systemName: "arrow.clockwise", label: "重来", enabled: !game.moves.isEmpty) { restart() }
        }
    }

    private func leave() { game.stop(); dismiss() }

    private func restart() {
        withAnimation(.spring(duration: 0.35)) { showResult = false }
        game.restart()
    }

    private func changeLevel(_ l: GoLevel) {
        savedLevel = l.number
        lossStreak = 0
        withAnimation(.spring(duration: 0.35)) { showResult = false }
        game.changeLevel(l)
    }

    private func handleGameOver() {
        let round = game.round
        #if DEBUG
        if !game.isTwoPlayer, let demo = RoundResult.demo(level: game.level?.number ?? 1) {
            lastResult = demo
            withAnimation(.spring(duration: 0.45)) { showResult = true }
            return
        }
        #endif
        // 下完一盘（输赢、和棋、和家人下都算）：「今天的三颗星」里的「下一盘棋」
        store.noteDaily(.play)
        store.saveRecord(game.makeRecord(stars: game.humanWon && !game.isTwoPlayer ? game.winStars : 0))
        if let level = game.level {
            if game.humanWon, !awardedRounds.contains(round) {
                awardedRounds.insert(round)
                let win = store.recordGoWin(level, stars: game.winStars)
                lastResult = RoundResult(win: win, usedUndo: game.usedUndo, usedHint: game.usedHint,
                                         suggest: store.goRecommended.number)
                lossStreak = 0
            } else if !game.humanWon, !countedLosses.contains(round) {
                countedLosses.insert(round)
                lastResult = RoundResult()
                lossStreak += 1
            }
        }
        resultTask = Task {
            try? await Task.sleep(for: .milliseconds(game.score != nil ? 1800 : 1000))
            guard !Task.isCancelled, game.isOver else { return }
            (game.humanWon || game.isTwoPlayer) ? Sound.win() : Sound.lose()
            withAnimation(.spring(duration: 0.45)) { showResult = true }
        }
    }
}

struct GoResultOverlay: View {
    let game: GoGame
    let result: RoundResult
    let lossStreak: Int
    let onAgain: () -> Void
    let onLevel: (GoLevel) -> Void
    let onReview: () -> Void
    let onLeave: () -> Void

    @State private var appeared = false
    @State private var litStars = 0
    @State private var showRecord = false

    private var vsAI: Bool { !game.isTwoPlayer }
    private var aiWin: Bool { vsAI && game.humanWon }
    private var easier: GoLevel? {
        guard vsAI, !game.humanWon, lossStreak >= 2 else { return nil }
        return game.level?.previous
    }

    /// 赢了之后去挑战哪一档：一般是下一档；这一档太简单了就直接去拿满星星的那一档
    private var challenge: GoLevel? {
        guard aiWin else { return nil }
        if result.reward?.low == true, result.suggest > 0 { return GoLevel(result.suggest) }
        return game.level?.next
    }

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            Color.black.opacity(0.12).ignoresSafeArea()
            if game.humanWon || game.isTwoPlayer { ConfettiView() }
            VStack(spacing: 18) {
                avatar.padding(.top, -110)
                Text(title)
                    .font(.kid(50, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text(subtitle)
                    .font(.kid(22, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
                if aiWin {
                    medals
                    WinRewardNote(level: game.level?.number ?? 0, result: result)
                }
                if let easier {
                    Text("连着输了 \(lossStreak) 局，先去第 \(easier.number) 档练练手？")
                        .font(.kid(19, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(easier.character.tint.opacity(0.22), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                HStack(spacing: 18) {
                    if let next = challenge {
                        Button { Sound.tap(); onLevel(next) } label: { Label("挑战第 \(next.number) 档", systemImage: "arrow.up.right") }
                            .buttonStyle(PillButtonStyle(color: Palette.coral))
                        Button("再来一局") { Sound.tap(); onAgain() }
                            .buttonStyle(PillButtonStyle(color: Palette.paper, foreground: Palette.ink, size: 22))
                    } else if let easier {
                        Button { Sound.tap(); onLevel(easier) } label: { Label("去第 \(easier.number) 档", systemImage: "arrow.down.right") }
                            .buttonStyle(PillButtonStyle(color: easier.character.tint))
                        Button("再来一局") { Sound.tap(); onAgain() }
                            .buttonStyle(PillButtonStyle(color: Palette.paper, foreground: Palette.ink, size: 22))
                    } else {
                        Button("再来一局") { Sound.tap(); onAgain() }
                            .buttonStyle(PillButtonStyle(color: Palette.coral))
                    }
                }
                .padding(.top, 6)
                HStack(spacing: 36) {
                    Button { Sound.tap(); onReview() } label: { Label("看看棋盘", systemImage: "eye") }
                    Button { Sound.tap(); onLeave() } label: {
                        Label(vsAI ? "换个难度" : "返回", systemImage: vsAI ? "slider.horizontal.3" : "chevron.left")
                    }
                }
                .font(.kid(19, weight: .bold))
                .foregroundStyle(Palette.inkSoft)
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
                Sound.record()
                withAnimation(.spring(duration: 0.5, bounce: 0.5)) { showRecord = true }
            }
        }
    }

    private var medals: some View {
        let earned = [true, !result.usedUndo, !result.usedHint]
        let captions = ["赢下比赛", "没有悔棋", "没用提示"]
        let order = earned.indices.sorted { earned[$0] && !earned[$1] }
        return HStack(spacing: 26) {
            ForEach(0..<3, id: \.self) { i in
                let got = earned[i]
                let lit = got && (order.firstIndex(of: i) ?? 0) < litStars
                VStack(spacing: 8) {
                    ZStack {
                        Image(systemName: "star.fill").font(.system(size: 52, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.08))
                        Image(systemName: "star.fill")
                            .font(.system(size: 52, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: [Palette.honey, Palette.coral], startPoint: .top, endPoint: .bottom))
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

    @ViewBuilder private var avatar: some View {
        if game.isTwoPlayer, let w = game.winner {
            StoneView(stone: w == .black ? .black : .white, diameter: 130)
                .frame(width: 180, height: 180)
                .background(Circle().fill(Palette.cream))
                .overlay(Circle().strokeBorder(.white, lineWidth: 8))
        } else if game.humanWon || game.opponent == nil {
            Avatar(image: "avatar_ranran", fallback: "👧", tint: Palette.blush, size: 180)
        } else if let o = game.opponent {
            Avatar(image: o.image, fallback: o.emoji, tint: o.tint, size: 180)
        }
    }

    private var title: String {
        if game.isTwoPlayer { return "\(game.winner?.name ?? "")赢啦！" }
        if game.humanWon { return game.level?.next == nil ? "你打败了围棋王！" : "你赢啦！" }
        return "\(game.opponent?.name ?? "")赢了"
    }

    /// 数子的结果，用孩子听得懂的话说
    private var subtitle: String {
        if let s = game.score {
            let m = abs(s.margin)
            let by = m.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(m))" : String(format: "%.1f", m)
            let line = "黑棋 \(s.black) 子，白棋 \(s.white) 子 + 贴 7.5"
            return line + "\n" + (s.margin > 0 ? "黑棋" : "白棋") + "赢了 \(by) 子" + (aiWin && !result.gotStars.isEmpty ? "，" + result.gotStars : "")
        }
        if let t = game.captureTarget {
            return "先吃到 \(t) 颗子！" + (aiWin ? result.gotStars : "再试一次吧")
        }
        return ""
    }
}
