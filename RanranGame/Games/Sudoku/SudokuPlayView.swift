import SwiftUI

/// 玩一关数独。横屏：盘面在左，右边是老师的话、数字按钮和工具；竖屏：从上到下排。一屏放下，不滚动。
struct SudokuPlayView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let levelID: String
    /// 「下一关」：换成这一关
    let onNext: (String) -> Void

    @State private var game: SudokuGame?
    @State private var result: PuzzleResult?
    @State private var confirmRestart = false
    @State private var demoResult = false
    @State private var finishing = false

    var body: some View {
        ZStack {
            CreamBackground(accent: SudokuStyle.accent)
            if let game {
                GeometryReader { geo in
                    layout(game, size: geo.size)
                }
                if let result {
                    PuzzleDoneOverlay(result: result,
                                      stars: [("过关", true), ("没用提示", game.hintsUsed == 0), ("没填错", game.mistakes == 0)],
                                      accent: SudokuStyle.accent, detail: detail(game),
                                      onNext: next.map { n in { onNext(n) } },
                                      onReplay: {
                                          withAnimation(.spring(duration: 0.4)) { self.result = nil }
                                          game.restart()
                                      },
                                      onLeave: { dismiss() })
                        .transition(.opacity)
                        .zIndex(10)
                }
            } else {
                Text("这一关没有找到")
                    .font(.kid(26, weight: .bold))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: start)
        .onChange(of: game?.solved ?? false) { _, solved in
            guard solved, let game else { return }
            finish(game)
        }
        .onDisappear { VoiceOver.shared.stop() }
        .alert("重新开始这一关？", isPresented: $confirmRestart) {
            Button("重新开始", role: .destructive) { game?.restart() }
            Button("不了", role: .cancel) {}
        } message: {
            Text("填好的格子会清空。")
        }
    }

    private var next: String? {
        guard result != nil else { return nil }
        return store.puzzleAfter("sudoku", SudokuCatalog.packs, levelID)
    }

    private func detail(_ g: SudokuGame) -> String {
        switch (g.mistakes, g.hintsUsed) {
        case (0, 0): "一次都没填错，也没用提示！"
        case (0, let h): "没填错，用了 \(h) 次提示"
        case (let m, 0): "填错了 \(m) 次，没用提示"
        case let (m, h): "填错了 \(m) 次，用了 \(h) 次提示"
        }
    }

    private func start() {
        guard game == nil, let level = SudokuCatalog.level(levelID) else { return }
        let g = SudokuGame(level: level)
        game = g
        Sound.start()
        #if DEBUG
        // 调试截图用：-sudokuDemo solved（过关页，不记进存档）/ mistake（填错一格）/ hint（打开提示）/ notes（小笔记）
        switch UserDefaults.standard.string(forKey: "sudokuDemo") {
        case "solved":
            demoResult = true
            g.debugSolve()
            finish(g)
        case "mistake": g.debugMistake()
        case "hint": g.askHint()
        case "notes": g.debugNotes()
        default: break
        }
        #endif
    }

    private func finish(_ g: SudokuGame) {
        guard !finishing, result == nil else { return }
        finishing = true
        let earned = 1 + (g.hintsUsed == 0 ? 1 : 0) + (g.mistakes == 0 ? 1 : 0)
        Task {
            defer { finishing = false }
            try? await Task.sleep(for: .milliseconds(700))
            let r: PuzzleResult
            if demoResult {
                r = PuzzleResult(earned: earned, best: earned, paid: earned, first: true)
            } else {
                r = store.recordPuzzle(game: "sudoku", level: levelID, earned: earned)
            }
            withAnimation(.spring(duration: 0.4)) { result = r }
        }
    }

    // MARK: 排版

    @ViewBuilder
    private func layout(_ g: SudokuGame, size: CGSize) -> some View {
        let pad: CGFloat = 24
        if size.width > size.height {
            // 横屏：右边一栏至少 360 宽
            let side = max(200, min(size.height - pad * 2, size.width - pad * 2 - 28 - 360))
            let panel = min(480, size.width - pad * 2 - 28 - side)
            HStack(spacing: 28) {
                board(g).frame(width: side, height: side)
                VStack(spacing: 16) {
                    header(g)
                    bubble(g).frame(maxHeight: .infinity)
                    padView(g, width: panel, maxHeight: size.height * 0.42, wide: true)
                    tools(g, columns: 3, height: 62)
                }
                .frame(width: panel)
                .frame(maxHeight: size.height - pad * 2)
            }
            .frame(width: size.width, height: size.height)
        } else {
            let fixed: CGFloat = 64 + 84 + 84 + 66 + 14 * 4
            let side = max(200, min(size.width - pad * 2, size.height - pad * 2 - fixed))
            VStack(spacing: 14) {
                header(g)
                bubble(g).frame(height: 84)
                board(g).frame(width: side, height: side)
                padView(g, width: size.width - pad * 2, maxHeight: 84, wide: false)
                tools(g, columns: g.canNote ? 5 : 4, height: 66)
            }
            .padding(.horizontal, pad)
            .frame(width: size.width, height: size.height)
        }
    }

    private func board(_ g: SudokuGame) -> some View {
        SudokuBoardView(look: g.look) { g.tapCell($0) }
    }

    private func header(_ g: SudokuGame) -> some View {
        HStack(spacing: 14) {
            RoundIconButton(systemName: "chevron.left", label: "选关卡") { dismiss() }
            VStack(alignment: .leading, spacing: 2) {
                Text(g.level.pack.name)
                    .font(.kid(26, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("第 \(g.level.number) 关")
                    .font(.kid(17, weight: .bold))
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 0)
            stat(icon: "xmark.circle.fill", value: g.mistakes, tint: Palette.coral, label: "填错")
            stat(icon: "lightbulb.fill", value: g.hintsUsed, tint: Palette.honey, label: "提示")
        }
        .frame(height: 64)
    }

    private func stat(icon: String, value: Int, tint: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).foregroundStyle(tint)
            Text("\(value)").monospacedDigit().foregroundStyle(Palette.ink)
        }
        .font(.kid(19, weight: .heavy))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Palette.paper, in: Capsule())
        .accessibilityLabel("\(label) \(value) 次")
    }

    private func bubble(_ g: SudokuGame) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Avatar(image: "avatar_owl", fallback: "🦉", tint: Palette.honey, size: 60)
            Text(g.message)
                .font(.kid(20, weight: .bold))
                .foregroundStyle(Palette.ink)
                .lineSpacing(3)
                .lineLimit(4)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: g.message)
            if let v = g.sticky {
                SudokuToken(value: v, fruit: g.fruit, size: 52, look: .entry)
                    .background(Palette.honey.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
    }

    private func padView(_ g: SudokuGame, width: CGFloat, maxHeight: CGFloat, wide: Bool) -> some View {
        let cols = wide ? (g.n == 4 ? 2 : 3) : g.n
        let rows = CGFloat((g.n + cols - 1) / cols)
        let gapRatio: CGFloat = 0.1
        let byWidth = width / (CGFloat(cols) + CGFloat(cols - 1) * gapRatio)
        let byHeight = maxHeight / (rows + (rows - 1) * gapRatio)
        let side = min(byWidth, byHeight, wide ? 124 : 96)
        return SudokuPad(n: g.n, fruit: g.fruit, columns: cols, side: side,
                         highlighted: g.padHighlight, sticky: g.sticky, done: g.finishedValues,
                         notesMode: g.notesMode) { g.tapValue($0) }
    }

    private func tools(_ g: SudokuGame, columns: Int, height: CGFloat) -> some View {
        var items: [(String, String, Bool, Bool, () -> Void)] = [
            ("arrow.uturn.backward", "撤销", false, g.canUndo, { g.undo() }),
            ("eraser.fill", "擦掉", false, true, { g.erase() }),
        ]
        if g.canNote { items.append(("pencil", "笔记", g.notesMode, true, { g.toggleNotes() })) }
        items.append(("lightbulb.fill", hintTitle(g), hintActive(g), true, { g.askHint() }))
        items.append(("arrow.counterclockwise", "重来", false, g.hasProgress, { confirmRestart = true }))
        let rows = (items.count + columns - 1) / columns
        return VStack(spacing: 10) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 10) {
                    ForEach(0..<columns, id: \.self) { c in
                        let k = r * columns + c
                        if k < items.count {
                            let it = items[k]
                            SudokuToolButton(icon: it.0, title: it.1, active: it.2, enabled: it.3, height: height, action: it.4)
                        } else {
                            Color.clear.frame(maxWidth: .infinity).frame(height: height)
                        }
                    }
                }
            }
        }
    }

    private func hintActive(_ g: SudokuGame) -> Bool {
        if case .explain? = g.hint { return true }
        return false
    }

    private func hintTitle(_ g: SudokuGame) -> String { hintActive(g) ? "给答案" : "提示" }
}
