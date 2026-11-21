import SwiftUI

/// 七巧板的一关：影子在板子上，七块板子在托盘里。拖、点一下转、翻面、吸附、提示、看一眼、撤销、重来。
///
/// 三颗星：过关 1 颗，另外两颗——
///   有分界线的组（入门、进阶）：提示最多用一次 + 没用提示（分界线已经告诉她每块在哪，偷看没有意义，所以按提示用了几次给）
///   没有分界线的组（高手、大师）：没用提示 + 没偷看（「看一眼」会暂时画出分界线）
struct TangramPlayView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let level: TangramLevel
    /// 去下一关（nil = 没有下一关）
    var onNext: ((String) -> Void)?

    @State private var board = TangramBoard()
    @State private var hints = 0
    @State private var peeked = false
    @State private var result: PuzzleResult?
    @State private var showDone = false
    @State private var showName = false
    @State private var peekTask: Task<Void, Never>?

    private var accent: Color { TangramStyle.accent }
    private var packs: [PuzzlePack] { TangramCatalog.packs }

    private var stars: [(label: String, got: Bool)] {
        if level.peekStar {
            return [("过关", true), ("没用提示", hints == 0), ("没偷看", !peeked)]
        }
        return [("过关", true), ("提示最多一次", hints <= 1), ("没用提示", hints == 0)]
    }

    private var earned: Int { stars.filter(\.got).count }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            ZStack {
                CreamBackground(accent: accent)
                VStack(spacing: wide ? 14 : 18) {
                    header(compact: geo.size.width < 900)
                    TangramStage(board: board, accent: accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, wide ? 28 : 24)
                .padding(.vertical, 20)

                if showName { nameBanner.transition(.scale(scale: 0.4).combined(with: .opacity)).zIndex(5) }
                if showDone, let result {
                    PuzzleDoneOverlay(result: result, stars: stars, accent: accent, title: "\(level.figure.name)拼好啦！",
                                      detail: hints == 0 ? "一次提示都没用" : "用了 \(hints) 次提示",
                                      onNext: nextLevel.map { n in { onNext?(n) } },
                                      onReplay: restart, onLeave: { dismiss() })
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: start)
        .onDisappear {
            peekTask?.cancel()
            VoiceOver.shared.stop()
        }
        .onChange(of: board.solved) { _, done in if done { finished() } }
    }

    private var nextLevel: String? { store.puzzleAfter("tangram", packs, level.id) }

    // MARK: 顶上：返回、第几关、工具

    private func header(compact: Bool) -> some View {
        HStack(spacing: compact ? 10 : 14) {
            RoundIconButton(systemName: "chevron.left", label: "返回") { dismiss() }
            VStack(alignment: .leading, spacing: 4) {
                Text("第 \(level.index + 1) 关")
                    .font(.kid(compact ? 26 : 30, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text(packs.indices.contains(level.pack) ? packs[level.pack].name : "")
                    .font(.kid(16, weight: .bold))
                    .foregroundStyle(Palette.inkSoft)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            TangramToolButton(icon: "arrow.uturn.backward", title: "撤销", enabled: board.canUndo && !board.solved) { board.undo() }
            TangramToolButton(icon: "arrow.counterclockwise", title: "重来",
                              enabled: board.pieces.contains(where: \.onBoard) && !board.solved) { board.reset() }
            TangramToolButton(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill", title: "翻面",
                              enabled: !board.solved, tint: TangramStyle.accent) { board.flip() }
            if level.peekStar {
                TangramToolButton(icon: "eye.fill", title: "看一眼", enabled: !board.solved && !board.peeking, tint: Palette.lilac) { peek() }
            }
            TangramToolButton(icon: "lightbulb.fill", title: "提示", enabled: !board.solved && board.ghost == nil, tint: Palette.honey) {
                if board.showHint() { hints += 1 }
            }
        }
    }

    private var nameBanner: some View {
        VStack(spacing: 8) {
            Text("\(level.figure.name)！")
                .font(.kid(64, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 18)
                .background(Capsule().fill(accent))
                .shadow(color: accent.opacity(0.45), radius: 20, y: 10)
        }
        .allowsHitTesting(false)
    }

    // MARK: 流程

    private func start() {
        board.load(target: level.figure.poses, tray: level.trayStart, outlines: level.outlines)
        board.interactive = true
        #if DEBUG
        // 调试截图用：-tangramDemo solved（拼好、结算页）/ half（摆好四块）/ hint（摆好四块、亮着提示）/ peek（看一眼）
        switch UserDefaults.standard.string(forKey: "tangramDemo") {
        case "solved": board.debugPlace(7)
        case "half": board.debugPlace(4)
        case "hint":
            board.debugPlace(4)
            if board.showHint() { hints += 1 }
        case "peek":
            board.debugPlace(2)
            if level.peekStar { peek() }
        default: break
        }
        #endif
    }

    private func restart() {
        withAnimation(.spring(duration: 0.4)) {
            showDone = false
            showName = false
            result = nil
        }
        hints = 0
        peeked = false
        board.load(target: level.figure.poses, tray: level.trayStart, outlines: level.outlines)
    }

    private func peek() {
        peeked = true
        Sound.sparkle()
        withAnimation(.easeInOut(duration: 0.3)) { board.peeking = true }
        peekTask?.cancel()
        peekTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.5)) { board.peeking = false }
        }
    }

    private func finished() {
        guard result == nil else { return }
        peekTask?.cancel()
        board.peeking = false
        result = store.recordPuzzle(game: "tangram", level: level.id, earned: earned)
        Sound.win()
        VoiceOver.shared.say(TangramTutorial.solvedLine)
        withAnimation(.spring(duration: 0.5, bounce: 0.45).delay(0.35)) { showName = true }
        Task {
            try? await Task.sleep(for: .seconds(2.0))
            withAnimation(.easeOut(duration: 0.3)) { showName = false }
            withAnimation(.spring(duration: 0.5).delay(0.1)) { showDone = true }
        }
    }
}

/// 工具按钮：图标 + 两个字，按不了的时候变淡
struct TangramToolButton: View {
    let icon: String
    let title: String
    var enabled = true
    var tint: Color = Palette.ink
    let action: () -> Void

    var body: some View {
        Button {
            guard enabled else { Sound.nope(); return }
            action()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(tint == Palette.ink ? Palette.ink : tint)
                    .frame(height: 26)
                Text(title)
                    .font(.kid(17, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 78, height: 70)
            .softCard(radius: 22)
            .opacity(enabled ? 1 : 0.4)
        }
        .buttonStyle(PressableStyle(scale: 0.9))
        .accessibilityLabel(title)
    }
}
