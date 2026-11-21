import SwiftUI

/// 国际象棋首页：和象棋一样在难度阶梯上选一档，选执白还是执黑，或者和家人下；右上角进「教学」。
struct ChessSetupView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("chess.humanWhite") private var humanWhite = true
    @AppStorage("chess.level") private var savedLevel = 0
    @State private var config: ChessConfig?
    @State private var showTutorial = false
    @State private var replayDemo: GameRecord?
    @State private var appeared = false

    private var level: ChessLevel {
        savedLevel == 0 ? store.chessRecommended : ChessLevel(savedLevel)
    }

    private var selection: Binding<Int> {
        Binding(get: { level.number }, set: { savedLevel = $0 })
    }

    /// 一盘都没下过、教学也没学过：先建议去学规则
    private var newcomer: Bool {
        ChessLevel.all.allSatisfy { store.chessWins($0) == 0 }
            && !store.lessonDone("chess", "c1") && store.records(for: "chess").isEmpty
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
            // 调试截图用：
            //   -tutorial YES 打开课程表；-lesson c5 直接打开那一课（课程表负责打开）
            //   -play YES 直接开一盘（档位用 -chessLevel N，执黑用 -chessBlack YES）；-chessFEN "<FEN>" 从这个局面开始
            //   -replayDemo YES 打开一盘示范棋谱的复盘
            let d = UserDefaults.standard
            if d.bool(forKey: "tutorial") || d.string(forKey: "lesson") != nil { showTutorial = true }
            if d.integer(forKey: "chessLevel") > 0 { savedLevel = d.integer(forKey: "chessLevel") }
            if d.object(forKey: "chessBlack") != nil { humanWhite = !d.bool(forKey: "chessBlack") }
            if d.bool(forKey: "play") || d.string(forKey: "chessFEN") != nil {
                config = ChessConfig(mode: .vsAI(level), humanWhite: humanWhite, startFEN: d.string(forKey: "chessFEN"))
            }
            if d.bool(forKey: "replayDemo") { replayDemo = ChessReplay.demoRecord }
            #endif
        }
        .navigationDestination(item: $config) { c in
            ChessGameView(config: c).toolbar(.hidden, for: .navigationBar)
        }
        .navigationDestination(isPresented: $showTutorial) {
            TutorialHomeView(game: "chess", accent: ChessSurface.frame, onPlay: playFromTutorial)
                .toolbar(.hidden, for: .navigationBar)
        }
        .navigationDestination(item: $replayDemo) { r in
            ChessReplayView(record: r).toolbar(.hidden, for: .navigationBar)
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
                Text("国际象棋")
                    .font(.kid(54, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text("白先黑后，将死对方的王就赢")
                    .font(.kid(20, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
            }
            HStack(spacing: 14) {
                RoundIconButton(systemName: "house.fill", label: "回主页") { dismiss() }
                Spacer()
                TutorialButton { showTutorial = true }
                // 赢棋、第一次赢的加奖、上课、复习拿到的星星全都算
                StarCounter(value: store.stars(prefix: "chess.stars."))
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
                ArtImage(name: "tutor_chess_basic", fallback: "🦉", contentMode: .fit)
                    .frame(width: 70, height: 70)
                VStack(alignment: .leading, spacing: 2) {
                    Text("第一次下国际象棋？")
                        .font(.kid(22, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                    Text("先跟猫头鹰老师学会每个棋子怎么走")
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
            .background(Palette.lilac.opacity(0.25), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }

    private func panel(wide: Bool) -> some View {
        let showcase = LevelShowcase(level: level.info,
                                     stars: store.chessStars(level),
                                     wins: store.chessWins(level),
                                     preview: store.winPreview(game: "chess", level: level.number),
                                     recommended: level == store.chessRecommended,
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
                        recommended: store.chessRecommended.number,
                        stars: { store.chessStars(ChessLevel($0)) })
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
                ChessSidePicker(humanWhite: $humanWhite)
                Spacer(minLength: 0)
                familyButton
            }
            VStack(spacing: 20) {
                ChessSidePicker(humanWhite: $humanWhite)
                familyButton
            }
        }
    }

    private var familyButton: some View {
        Button { start(twoPlayer: true) } label: {
            HStack(spacing: 18) {
                ZStack {
                    ChessPieceView(piece: ChessPiece(.white, .king), size: 40).offset(x: -11, y: 3)
                    ChessPieceView(piece: ChessPiece(.black, .king), size: 40).offset(x: 11, y: -3)
                }
                .frame(width: 64, height: 64)
                .background(Circle().fill(Palette.lilac.opacity(0.45)))
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
        let n = ChessLevel(level.number + delta).number
        guard n != level.number else { return }
        Sound.step(n)
        withAnimation(.spring(duration: 0.4, bounce: 0.35)) { savedLevel = n }
    }

    private func start(twoPlayer: Bool) {
        Sound.start()
        config = twoPlayer
            ? ChessConfig(mode: .twoPlayer, humanWhite: true)
            : ChessConfig(mode: .vsAI(level), humanWhite: humanWhite)
    }
}

/// "我执白先走 / 我执黑"
private struct ChessSidePicker: View {
    @Binding var humanWhite: Bool
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 18) {
            Text("和电脑下时")
                .font(.kid(20, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
            HStack(spacing: 0) {
                option("我执白先走", side: .white, selected: humanWhite) { humanWhite = true }
                option("我执黑", side: .black, selected: !humanWhite) { humanWhite = false }
            }
            .padding(6)
            .softCard(radius: 30)
        }
    }

    private func option(_ title: String, side: ChessSide, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Sound.tap()
            withAnimation(.spring(duration: 0.35, bounce: 0.3)) { action() }
        } label: {
            HStack(spacing: 10) {
                ChessPieceView(piece: ChessPiece(side, .king), size: 30)
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
