import SwiftUI

struct ChessGameView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var game: ChessGame
    @State private var showResult = false
    @State private var awardedRounds: Set<Int> = []
    @State private var countedLosses: Set<Int> = []
    @State private var finishedRounds: Set<Int> = []
    @State private var resultTask: Task<Void, Never>?
    @State private var lastResult = RoundResult()
    @State private var lossStreak = 0
    @AppStorage("chess.level") private var savedLevel = 0

    init(config: ChessConfig) {
        _game = State(initialValue: ChessGame(config: config))
    }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            ZStack {
                CreamBackground(accent: game.opponent?.tint ?? Palette.lilac)
                if landscape {
                    HStack(spacing: 28) {
                        board.padding(.vertical, 8)
                        sidePanel.frame(width: min(370, geo.size.width * 0.3))
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 22)
                } else {
                    VStack(spacing: 14) {
                        HStack(spacing: 14) {
                            RoundIconButton(systemName: "chevron.left", label: "返回") { leave() }
                            topCard
                            bottomCard
                        }
                        capturedRow(by: game.bottomSide.other)
                        statusLine
                        board
                        capturedRow(by: game.bottomSide)
                        controls
                    }
                    .padding(26)
                }

                if showResult {
                    ChessResultOverlay(game: game, result: lastResult, lossStreak: lossStreak,
                                       onAgain: { restart() },
                                       onLevel: { changeLevel($0) },
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
            // 调试截图用：-winDemo bonus|low|none 假装赢了一盘；-chessResult lose|draw 看输棋、和棋的结果页；
            // -chessPromo YES 打开升变选子窗口（要配一个有兵能升变的 -chessFEN）
            let d = UserDefaults.standard
            if d.string(forKey: "winDemo") != nil, !game.isTwoPlayer { game.debugFinish("win") }
            if let r = d.string(forKey: "chessResult") { game.debugFinish(r) }
            if d.bool(forKey: "chessPromo") { game.debugPromotion() }
            #endif
        }
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

    private var board: some View {
        ChessBoardView(state: ChessBoardState(
            board: game.board, ids: game.ids, flipped: game.bottomSide == .black,
            selected: game.selected, targets: game.targets, lastMove: game.lastMove,
            checkedKing: game.inCheck ? game.board.king(game.turn) : nil,
            hint: game.hint,
            marks: game.checkers.map { .ring($0, warn: true) } + game.warnSquares.map { .ring($0, warn: true) },
            checkFlash: game.checkFlash
        )) { game.tap($0) }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if game.pendingPromotion != nil {
                ChessPromotionPicker(side: game.turn, onPick: { game.choosePromotion($0) }, onCancel: { game.cancelPromotion() })
            }
        }
    }

    private var sidePanel: some View {
        VStack(spacing: 14) {
            HStack {
                RoundIconButton(systemName: "chevron.left", label: "返回") { leave() }
                Spacer()
                Text("国际象棋")
                    .font(.kid(30, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Color.clear.frame(width: 64, height: 64)
            }
            .padding(.bottom, 4)
            topCard
            capturedRow(by: game.bottomSide.other)
            statusLine
            capturedRow(by: game.bottomSide)
            bottomCard
            Spacer(minLength: 10)
            controls
        }
    }

    private var topCard: some View {
        let side = game.bottomSide.other
        return Group {
            if let o = game.opponent, let level = game.level {
                ChessPlayerCard(avatar: .art(o.image, o.emoji, o.tint), name: o.name, side: side,
                                active: game.turn == side && !game.isOver, thinking: game.aiThinking,
                                speech: game.speech, badge: ("第 \(level.number) 档", o.tint))
            } else {
                ChessPlayerCard(avatar: .piece(side), name: side.name, side: side,
                                active: game.turn == side && !game.isOver, thinking: false, speech: nil)
            }
        }
    }

    private var bottomCard: some View {
        let side = game.bottomSide
        return Group {
            if game.isTwoPlayer {
                ChessPlayerCard(avatar: .piece(side), name: side.name, side: side,
                                active: game.turn == side && !game.isOver, thinking: false, speech: nil)
            } else {
                ChessPlayerCard(avatar: .art("avatar_ranran", "👧", Palette.blush), name: store.name, side: side,
                                active: game.turn == side && !game.isOver, thinking: false, speech: nil)
            }
        }
    }

    /// 某一方吃掉的子，排成一小排；后面写上子力领先几分
    private func capturedRow(by side: ChessSide) -> some View {
        let list = game.captured(by: side)
        let mine = list.reduce(0) { $0 + $1.kind.points }
        let theirs = game.captured(by: side.other).reduce(0) { $0 + $1.kind.points }
        return HStack(spacing: -8) {
            ForEach(Array(list.enumerated()), id: \.offset) { _, p in
                ChessPieceView(piece: p, size: 30)
            }
            if mine > theirs {
                Text("+\(mine - theirs)")
                    .font(.kid(16, weight: .heavy))
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.leading, 14)
            }
            Spacer(minLength: 0)
        }
        .frame(height: 30)
        .clipped()
        .opacity(list.isEmpty ? 0 : 1)
        .animation(.spring(duration: 0.35), value: list.count)
    }

    private var statusLine: some View {
        Text(statusText)
            .font(.kid(20, weight: .semibold))
            .foregroundStyle(game.inCheck ? Palette.coral : Palette.inkSoft)
            .multilineTextAlignment(.center)
            // 固定一行的高度：文字换了也不能把棋盘顶得上下动
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: statusText)
    }

    private var statusText: String {
        if game.isDraw { return "和棋：\(game.outcome?.drawReason ?? "")" }
        if let w = game.winner {
            if game.isTwoPlayer { return "将死！\(w.name)赢啦！" }
            return game.humanWon ? "将死！\(store.name)赢啦！🎉" : "\(game.opponent!.name)赢了这一局"
        }
        if game.pendingPromotion != nil { return "兵走到底了，选一个子升变" }
        if game.aiThinking, !game.isTwoPlayer, game.turn != game.humanSide { return "\(game.opponent!.name)正在想…" }
        if game.warned != nil { return "再点一次同一个地方就走，或者换一步" }
        if game.inCheck { return "将军！快保护你的王" }
        if game.isTwoPlayer { return "轮到\(game.turn.name)" }
        if game.history.count < 2 { return "点一下你的棋子，再点要去的地方" }
        return game.selected == nil ? "轮到你啦" : "绿点是可以走的地方"
    }

    private var controls: some View {
        HStack(spacing: 14) {
            ControlButton(systemName: "arrow.uturn.backward", label: "悔棋", enabled: game.canUndo) { game.undo() }
            ControlButton(systemName: "lightbulb.max", label: "提示", enabled: game.canHumanMove) { game.showHint() }
            ControlButton(systemName: "arrow.clockwise", label: "重来", enabled: !game.history.isEmpty) { restart() }
        }
    }

    // MARK: 动作

    private func leave() {
        game.stop()
        dismiss()
    }

    private func restart() {
        withAnimation(.spring(duration: 0.35)) { showResult = false }
        game.restart()
    }

    private func changeLevel(_ l: ChessLevel) {
        savedLevel = l.number
        lossStreak = 0
        withAnimation(.spring(duration: 0.35)) { showResult = false }
        game.changeLevel(l)
    }

    private func handleGameOver() {
        let round = game.round
        #if DEBUG
        if !game.isTwoPlayer, game.humanWon, let demo = RoundResult.demo(level: game.level?.number ?? 1) {
            lastResult = demo
            withAnimation(.spring(duration: 0.45)) { showResult = true }
            return
        }
        if UserDefaults.standard.string(forKey: "chessResult") != nil, game.history.isEmpty {
            if !game.humanWon { lossStreak = 2 }
            withAnimation(.spring(duration: 0.45)) { showResult = true }
            return
        }
        #endif
        // 下完一盘（输赢、和棋、和家人下都算）：「今天的三颗星」里的「下一盘棋」。悔棋以后再下完，同一盘不重复记
        if !finishedRounds.contains(round) {
            finishedRounds.insert(round)
            store.noteDaily(.play)
        }
        if game.savesRecord {
            store.saveRecord(game.makeRecord(stars: game.humanWon && !game.isTwoPlayer ? game.winStars : 0))
        }
        if let level = game.level {
            if game.humanWon, !awardedRounds.contains(round) {
                awardedRounds.insert(round)
                let win = store.recordChessWin(level, stars: game.winStars)
                lastResult = RoundResult(win: win, usedUndo: game.usedUndo, usedHint: game.usedHint,
                                         suggest: store.chessRecommended.number)
                lossStreak = 0
            } else if !game.humanWon, game.winner != nil, !countedLosses.contains(round) {
                countedLosses.insert(round)
                lastResult = RoundResult()
                lossStreak += 1
            }
        }
        resultTask = Task {
            try? await Task.sleep(for: .milliseconds(1100))
            guard !Task.isCancelled, game.isOver else { return }
            (game.humanWon || game.isTwoPlayer || game.isDraw) ? Sound.win() : Sound.lose()
            withAnimation(.spring(duration: 0.45)) { showResult = true }
        }
    }
}

// MARK: - 玩家卡片

enum ChessAvatar {
    case art(String, String, Color)
    case piece(ChessSide)
}

struct ChessPlayerCard: View {
    let avatar: ChessAvatar
    let name: String
    let side: ChessSide
    let active: Bool
    let thinking: Bool
    let speech: String?
    var badge: (String, Color)? = nil

    var body: some View {
        HStack(spacing: 14) {
            Group {
                switch avatar {
                case let .art(image, fallback, tint):
                    Avatar(image: image, fallback: fallback, tint: tint, size: 76)
                case let .piece(s):
                    ChessPieceView(piece: ChessPiece(s, .king), size: 60)
                        .frame(width: 76, height: 76)
                        .background(Circle().fill(Palette.lilac.opacity(0.35)))
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(name)
                        .font(.kid(26, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
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
                    ChessPieceView(piece: ChessPiece(side, .king), size: 24)
                    Text(side.name)
                        .font(.kid(17, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            Spacer(minLength: 0)
            if thinking {
                ThinkingDots().transition(.scale.combined(with: .opacity))
            } else if active {
                Circle()
                    .fill(Palette.coral)
                    .frame(width: 14, height: 14)
                    .shadow(color: Palette.coral.opacity(0.7), radius: 6)
                    .transition(.scale)
            }
        }
        .padding(14)
        .softCard(radius: 30)
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Palette.coral.opacity(active ? 0.9 : 0), lineWidth: 3)
        )
        .scaleEffect(active ? 1 : 0.96)
        .opacity(active ? 1 : 0.8)
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
}

// MARK: - 结果

struct ChessResultOverlay: View {
    let game: ChessGame
    let result: RoundResult
    let lossStreak: Int
    let onAgain: () -> Void
    let onLevel: (ChessLevel) -> Void
    let onReview: () -> Void
    let onLeave: () -> Void

    @State private var appeared = false
    @State private var litStars = 0
    @State private var showRecord = false

    private var vsAI: Bool { !game.isTwoPlayer }
    private var aiWin: Bool { vsAI && game.humanWon }
    private var easier: ChessLevel? {
        guard vsAI, !game.humanWon, !game.isDraw, lossStreak >= 2 else { return nil }
        return game.level?.previous
    }

    /// 赢了之后去挑战哪一档：一般是下一档；这一档太简单了就直接去拿满星星的那一档
    private var challenge: ChessLevel? {
        guard aiWin else { return nil }
        if result.reward?.low == true, result.suggest > 0 { return ChessLevel(result.suggest) }
        return game.level?.next
    }

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            Color.black.opacity(0.12).ignoresSafeArea()
            if game.humanWon || (game.isTwoPlayer && game.winner != nil) { ConfettiView() }

            VStack(spacing: 18) {
                avatar.padding(.top, -110)
                Text(title)
                    .font(.kid(50, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(subtitle)
                    .font(.kid(23, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if aiWin {
                    medals
                    WinRewardNote(level: game.level?.number ?? 0, result: result)
                }
                if let easier {
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
            .frame(minWidth: 560, maxWidth: 760)
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

    /// 三颗星：赢了 / 没悔棋 / 没用提示
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
                        Image(systemName: "star.fill")
                            .font(.system(size: 52, weight: .bold))
                            .foregroundStyle(Palette.ink.opacity(0.08))
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
            ChessPieceView(piece: ChessPiece(w, .king), size: 130)
                .frame(width: 180, height: 180)
                .background(Circle().fill(Palette.lilac.opacity(0.4)))
                .overlay(Circle().strokeBorder(.white, lineWidth: 8))
        } else if game.humanWon || game.isDraw || game.opponent == nil {
            Avatar(image: "avatar_ranran", fallback: "👧", tint: Palette.blush, size: 180)
        } else if let o = game.opponent {
            Avatar(image: o.image, fallback: o.emoji, tint: o.tint, size: 180)
        }
    }

    private var title: String {
        if game.isDraw { return "和棋！" }
        if game.isTwoPlayer { return "\(game.winner?.name ?? "")赢啦！" }
        if game.humanWon { return game.level?.next == nil ? "你打败了国际象棋王！" : "将死！你赢啦！" }
        return "\(game.opponent?.name ?? "")赢了"
    }

    private var subtitle: String {
        if game.isDraw { return (game.outcome?.drawReason ?? "") + "，算平局" }
        if game.isTwoPlayer { return "下得真精彩，再来一局吧" }
        if game.humanWon { return "\(game.opponent?.loseLine ?? "")  \(result.gotStars)" }
        return "差一点点！点「悔棋」或者去「教学」学几招杀法"
    }
}
