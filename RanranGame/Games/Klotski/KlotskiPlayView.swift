import SwiftUI
import Observation

/// 玩一关：一个木盘、走了几步、撤销、提示。小兔走到出口就过关。
@Observable
@MainActor
final class KlotskiPlaySession {
    let level: KlotskiLevel
    private(set) var board: KlotskiBoard
    let looks: [KlotskiLook]
    /// 走每一步之前的盘面（撤销用，也是走了几步）
    private(set) var history: [KlotskiBoard] = []
    var usedHint = false
    private(set) var hint: KlotskiMove?
    private(set) var thinking = false
    private(set) var exiting = false
    var nudge: (piece: Int, tick: Int)?
    private var hintTask: Task<Void, Never>?

    init(level: KlotskiLevel) {
        self.level = level
        board = level.board
        looks = KlotskiLooks.assign(level.board)
    }

    var moves: Int { history.count }
    var bound: Int { level.starBound }
    var inBound: Bool { moves <= bound }
    /// 这一次拿几颗星：过关 1 + 没用提示 1 + 步数不多 1
    var earned: Int { 1 + (usedHint ? 0 : 1) + (inBound ? 1 : 0) }
    var canPlay: Bool { !exiting && !board.solved }

    func move(_ m: KlotskiMove) {
        guard canPlay, board.canApply(m) else { return }
        history.append(board)
        withAnimation(.spring(duration: 0.28, bounce: 0.22)) { board = board.applying(m) }
        Sound.drop()
        clearHint()
        if board.solved { exiting = true }
    }

    func undo() {
        guard canPlay, let last = history.popLast() else { return }
        Sound.undo()
        clearHint()
        withAnimation(.spring(duration: 0.3, bounce: 0.2)) { board = last }
    }

    func restart() {
        clearHint()
        exiting = false
        usedHint = false
        history = []
        withAnimation(.spring(duration: 0.35, bounce: 0.2)) { board = level.board }
    }

    /// 点一下木块：只有一种走法就直接走；一种都没有就抖一抖
    func tap(_ piece: Int?) {
        guard canPlay, let piece else { return }
        let options = board.moves(of: piece)
        if options.count == 1 {
            move(options[0])
        } else if options.isEmpty {
            Sound.nope()
            nudge = (piece, (nudge?.tick ?? 0) + 1)
        }
    }

    func showHint() {
        guard canPlay, !thinking else { return }
        usedHint = true
        Sound.hint()
        thinking = true
        let b = board
        hintTask?.cancel()
        hintTask = Task {
            // 求解在别的线程上做，点提示不会卡住画面
            let best = await Task.detached(priority: .userInitiated) { KlotskiSolver.bestMove(b) }.value
            guard !Task.isCancelled, board == b else { return }
            withAnimation(.spring(duration: 0.3)) { hint = best }
            thinking = false
        }
    }

    private func clearHint() {
        hintTask?.cancel()
        thinking = false
        if hint != nil { withAnimation(.easeOut(duration: 0.15)) { hint = nil } }
    }

    func stop() { hintTask?.cancel() }

    #if DEBUG
    /// 调试截图用：把最短的走法一口气走完（不算提示），或者填满步数
    func debugSolve(pad: Int = 0) {
        var b = level.board
        var h: [KlotskiBoard] = []
        for m in KlotskiSolver.solve(b) ?? [] { h.append(b); b = b.applying(m) }
        for _ in 0..<pad { h.append(b) }
        history = h
        board = b
        exiting = true
    }
    #endif
}

struct KlotskiPlayView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PuzzleRules.unlockAllKey) private var unlockAll = false

    @State private var session: KlotskiPlaySession
    @State private var result: PuzzleResult?
    @State private var finishTask: Task<Void, Never>?
    /// 点「下一关」时换成哪一关（外面负责换）
    let onSwitch: (String) -> Void

    static let accent = Color(hex: 0xC47A4E)

    init(levelID: String, onSwitch: @escaping (String) -> Void) {
        let level = KlotskiCatalog.level(levelID) ?? KlotskiCatalog.levels[0]
        _session = State(initialValue: KlotskiPlaySession(level: level))
        self.onSwitch = onSwitch
    }

    private var level: KlotskiLevel { session.level }

    private var pack: (name: String, number: Int) {
        let spec = KlotskiCatalog.specs.first { $0.id == level.pack }
        let n = (KlotskiCatalog.levels.filter { $0.pack == level.pack }.firstIndex(of: level) ?? 0) + 1
        return (spec?.name ?? "", n)
    }

    private var nextLevel: String? {
        store.puzzleAfter("klotski", KlotskiCatalog.packs, level.id, unlockAll: unlockAll)
    }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            ZStack {
                CreamBackground(accent: Self.accent)
                if wide {
                    HStack(spacing: 32) {
                        boardView.frame(maxWidth: .infinity, maxHeight: .infinity)
                        VStack(spacing: 18) {
                            header
                            statusCard
                            Spacer(minLength: 0)
                            controls
                        }
                        .frame(width: min(400, geo.size.width * 0.33))
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                } else {
                    VStack(spacing: 14) {
                        header
                        statusCard
                        boardView.frame(maxWidth: .infinity, maxHeight: .infinity)
                        controls
                    }
                    .padding(28)
                }
                if let result {
                    PuzzleDoneOverlay(result: result,
                                      stars: [("过关", true), ("没用提示", !session.usedHint), ("步数不多", session.inBound)],
                                      accent: Self.accent,
                                      detail: "用了 \(session.moves) 步，最少 \(level.minMoves) 步",
                                      onNext: nextLevel.map { next in { onSwitch(next) } },
                                      onReplay: replay,
                                      onLeave: { dismiss() })
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
        }
        .onDisappear { session.stop(); finishTask?.cancel() }
        .onChange(of: session.exiting) { _, now in
            if now { finish() }
        }
        .onAppear {
            #if DEBUG
            applyDemo()
            #endif
        }
    }

    // MARK: 木盘

    private var boardView: some View {
        let hint = session.hint
        return KlotskiBoardView(
            board: session.board,
            looks: session.looks,
            interactive: session.canPlay,
            glow: hint.map { [$0.piece] } ?? [],
            arrows: hint.map { [KlotskiArrow(piece: $0.piece, dir: $0.dir, dist: $0.dist)] } ?? [],
            exiting: session.exiting,
            nudge: session.nudge,
            onMove: { session.move($0) },
            onTap: { piece, _, _ in session.tap(piece) }
        )
    }

    // MARK: 顶上和右边

    private var header: some View {
        HStack(spacing: 14) {
            RoundIconButton(systemName: "chevron.left", label: "返回") { dismiss() }
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                Text("第 \(pack.number) 关")
                    .font(.kid(30, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text(level.name.isEmpty ? pack.name : "\(pack.name) · \(level.name)")
                    .font(.kid(17, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
            Color.clear.frame(width: 64, height: 64)
        }
    }

    /// 走了几步、最少几步、目标几步：目标写在屏幕上，不是藏起来的规矩
    private var statusCard: some View {
        let over = !session.inBound
        return HStack(alignment: .center, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(session.moves)")
                    .font(.kid(64, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(over ? Palette.coral : Palette.ink)
                    .contentTransition(.numericText())
                Text("步")
                    .font(.kid(26, weight: .bold))
                    .foregroundStyle(Palette.inkSoft)
            }
            .animation(.spring(duration: 0.25), value: session.moves)
            VStack(alignment: .leading, spacing: 8) {
                Label("最少 \(level.minMoves) 步", systemImage: "flag.checkered")
                    .foregroundStyle(Palette.inkSoft)
                Label(over ? "超过 \(session.bound) 步，也能过关" : "\(session.bound) 步以内有星星",
                      systemImage: "star.fill")
                    .foregroundStyle(over ? Palette.inkSoft.opacity(0.8) : Color(hex: 0xC98D2E))
            }
            .font(.kid(19, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .softCard(radius: 30)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            ControlButton(systemName: session.thinking ? "hourglass" : "lightbulb.max", label: "提示",
                          enabled: session.canPlay && !session.thinking) { session.showHint() }
            ControlButton(systemName: "arrow.uturn.backward", label: "撤销",
                          enabled: session.canPlay && session.moves > 0) { session.undo() }
            ControlButton(systemName: "arrow.counterclockwise", label: "回到开头",
                          enabled: session.moves > 0 && !session.exiting) { replay() }
        }
    }

    // MARK: 过关

    private func finish() {
        finishTask?.cancel()
        Sound.sparkle()
        finishTask = Task {
            // 让小兔跳出去，看完再出结算页
            try? await Task.sleep(for: .milliseconds(1250))
            guard !Task.isCancelled else { return }
            #if DEBUG
            if UserDefaults.standard.string(forKey: "klotskiDemo") != nil {
                let e = session.earned
                withAnimation(.spring(duration: 0.4)) { result = PuzzleResult(earned: e, best: e, paid: e, first: true) }
                return
            }
            #endif
            let r = store.recordPuzzle(game: "klotski", level: level.id, earned: session.earned)
            withAnimation(.spring(duration: 0.4)) { result = r }
        }
    }

    private func replay() {
        finishTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { result = nil }
        session.restart()
    }

    #if DEBUG
    /// 调试截图用：-klotskiDemo hint（打开就亮出提示）| solved（过关页，三颗星）| solvedHint（用了提示，两颗星）| over（步数超了，两颗星）
    private func applyDemo() {
        guard let demo = UserDefaults.standard.string(forKey: "klotskiDemo") else { return }
        switch demo {
        case "hint":
            Task { try? await Task.sleep(for: .milliseconds(400)); session.showHint() }
        case "solved":
            session.debugSolve()
        case "solvedHint":
            session.usedHint = true
            session.debugSolve()
        case "over":
            session.debugSolve(pad: level.starBound - level.minMoves + 1)
        default:
            break
        }
    }
    #endif
}
