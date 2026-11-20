import SwiftUI
import Observation

/// 复盘一盘象棋：一步一步看、中文记谱、电脑逐手点评，失误的地方画出电脑会怎么走。
@Observable
@MainActor
final class XiangqiReplay {
    struct Review: Hashable {
        /// 这一步之前，电脑觉得最好的一步
        let best: XMove
        /// 走完以后，局面比走最好的一步差了多少分（越大越亏）
        let loss: Int
        /// 走完以后的局面（站在红方看）
        let redScore: Int

        var verdict: (text: String, color: Color, icon: String) {
            if loss >= 250 { return ("失误", Palette.coral, "exclamationmark.triangle.fill") }
            if loss >= 90 { return ("可以更好", Palette.honey, "lightbulb.fill") }
            return ("好棋", Palette.sage, "hand.thumbsup.fill")
        }
    }

    let record: GameRecord
    let moves: [XMove]
    /// 每一步之前的局面（positions[0] 是开局）
    let positions: [XBoard]
    var step: Int
    private(set) var reviews: [Review]?
    private(set) var analyzed = 0
    private(set) var playing = false
    private var playTask: Task<Void, Never>?

    private static var cache: [UUID: [Review]] = [:]

    init(record: GameRecord) {
        self.record = record
        var b = XBoard(fen: XBoard.start)!
        var ms: [XMove] = []
        var ps = [b]
        for m in record.moves where m.count == 4 {
            let mv = XMove(XSquare(m[0], m[1]), XSquare(m[2], m[3]))
            guard b.legalMoves(from: mv.from).contains(mv) else { break }
            b.make(mv)
            ms.append(mv)
            ps.append(b)
        }
        moves = ms
        positions = ps
        step = ms.count
        reviews = Self.cache[record.id]
        if reviews != nil { analyzed = ms.count }
    }

    var level: XiangqiLevel? { record.opponentLevel.map(XiangqiLevel.init) }
    var humanSide: XSide? { record.playerColor.map { $0 == 1 ? .red : .black } }
    var board: XBoard { positions[step] }

    /// 显示到第几步时，正在看的是哪一步（0 = 还没开始）
    var currentMove: XMove? { step > 0 ? moves[step - 1] : nil }
    var currentReview: Review? {
        guard step > 0, let reviews, reviews.indices.contains(step - 1) else { return nil }
        return reviews[step - 1]
    }

    func side(ofPly i: Int) -> XSide { i % 2 == 0 ? .red : .black }

    /// 这一步要不要点评：和电脑下时只点评冉冉自己的棋
    func reviewed(_ i: Int) -> Bool { humanSide == nil || side(ofPly: i) == humanSide }

    func notation(_ i: Int) -> String { positions[i].notation(moves[i]) }

    /// 每个子的编号，让回放时棋子滑过去
    var ids: [Int] { ids(upTo: step) }
    var idsBefore: [Int] { ids(upTo: max(0, step - 1)) }

    private func ids(upTo n: Int) -> [Int] {
        var ids = XBoard.initialIDs(positions[0])
        for m in moves.prefix(n) {
            ids[m.to.index] = ids[m.from.index]
            ids[m.from.index] = 0
        }
        return ids
    }

    func analyze() async {
        guard reviews == nil, !moves.isEmpty else { return }
        let positions = self.positions, moves = self.moves
        var out: [Review] = []
        for i in moves.indices {
            let r = await Task.detached(priority: .userInitiated) { () -> Review in
                let before = positions[i]
                let ai = XiangqiAI(profile: .level(6))
                let best = ai.bestMove(before) ?? moves[i]
                let afterPlayed = -ai.evaluate(before.applying(moves[i]), depth: 2)
                let afterBest = best == moves[i] ? afterPlayed : -ai.evaluate(before.applying(best), depth: 2)
                let red = before.turn == .red ? afterPlayed : -afterPlayed
                return Review(best: best, loss: max(0, afterBest - afterPlayed), redScore: red)
            }.value
            out.append(r)
            analyzed = i + 1
        }
        Self.cache[record.id] = out
        withAnimation(.easeInOut(duration: 0.4)) { reviews = out }
    }

    func go(to s: Int, sound: Bool = true) {
        let target = min(max(s, 0), moves.count)
        guard target != step else { return }
        if sound { Sound.place(target > step ? .black : .white) }
        withAnimation(.spring(duration: 0.35, bounce: 0.2)) { step = target }
    }

    func togglePlay() {
        if playing { stop(); return }
        if step >= moves.count { go(to: 0, sound: false) }
        playing = true
        playTask = Task { [weak self] in
            while let self, self.playing, self.step < self.moves.count {
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled, self.playing else { return }
                self.go(to: self.step + 1)
            }
            self?.playing = false
        }
    }

    func stop() {
        playing = false
        playTask?.cancel()
    }
}

struct XiangqiReplayView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var replay: XiangqiReplay

    init(record: GameRecord) {
        _replay = State(initialValue: XiangqiReplay(record: record))
    }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            ZStack {
                CreamBackground(accent: replay.level?.character.tint ?? Palette.sky)
                if wide {
                    HStack(spacing: 28) {
                        board
                        VStack(spacing: 16) {
                            header
                            commentCard
                            moveList.frame(maxHeight: .infinity)
                            controls
                        }
                        .frame(width: min(400, geo.size.width * 0.33))
                    }
                    .padding(28)
                } else {
                    VStack(spacing: 16) {
                        header
                        commentCard
                        board
                        controls
                    }
                    .padding(26)
                }
            }
        }
        .task { await replay.analyze() }
        .onDisappear { replay.stop() }
    }

    private var board: some View {
        let mistake = replay.currentReview.map { $0.loss >= 90 } ?? false
        let showBest = mistake && replay.reviewed(replay.step - 1)
        // 有问题的一步：退回走之前的局面，黄箭头是自己走的，绿箭头是电脑会走的
        let shown = showBest ? replay.positions[replay.step - 1] : replay.board
        let played = replay.currentMove
        return XiangqiBoardView(state: XBoardState(
            board: shown, ids: showBest ? replay.idsBefore : replay.ids,
            flipped: replay.humanSide == .black,
            lastMove: showBest ? nil : played,
            checkedKing: shown.inCheck(shown.turn) ? shown.king(shown.turn) : nil,
            hint: showBest ? replay.currentReview?.best : nil,
            marks: showBest ? played.map { [.arrow($0.from, $0.to)] } ?? [] : []
        )) { _ in }
        .aspectRatio(9.6 / 10.6, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 14) {
            RoundIconButton(systemName: "chevron.left", label: "返回") { dismiss() }
            VStack(alignment: .leading, spacing: 4) {
                Text("象棋复盘")
                    .font(.kid(28, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text(subtitle)
                    .font(.kid(16, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
    }

    private var subtitle: String {
        var parts = [replay.record.date.shortChinese]
        if let l = replay.level { parts.append("第 \(l.number) 档 · \(l.character.name)") } else { parts.append("和家人下") }
        parts.append("共 \(replay.moves.count) 步")
        return parts.joined(separator: " · ")
    }

    /// 当前这一步的点评
    private var commentCard: some View {
        let i = replay.step - 1
        return HStack(alignment: .top, spacing: 14) {
            Avatar(image: "avatar_owl", fallback: "🦉", tint: Palette.honey, size: 64)
            VStack(alignment: .leading, spacing: 6) {
                if i < 0 {
                    Text("开局。点 ▶ 一步一步看，或者在右边点任意一步。")
                        .font(.kid(19, weight: .bold))
                        .foregroundStyle(Palette.ink)
                } else {
                    HStack(spacing: 8) {
                        Text("第 \(replay.step) 步 · \(replay.side(ofPly: i).name)")
                            .font(.kid(16, weight: .heavy))
                            .foregroundStyle(Palette.inkSoft)
                        Text(replay.notation(i))
                            .font(.kid(22, weight: .heavy))
                            .foregroundStyle(replay.side(ofPly: i) == .red ? XiangqiPieceView.redInk : XiangqiPieceView.blackInk)
                    }
                    Text(comment(i))
                        .font(.kid(18, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let id = lessonID(i) {
                        ReviewLessonButton(game: "xiangqi", lessonID: id)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
    }

    /// 亏了的一步：对应教学里的哪一课
    private func lessonID(_ i: Int) -> String? {
        guard replay.reviewed(i), let r = replay.reviews?[i], r.loss >= 90, r.best != replay.moves[i] else { return nil }
        return XiangqiReplayLessons.lessonID(before: replay.positions[i], played: replay.moves[i])
    }

    private func comment(_ i: Int) -> String {
        if i == replay.moves.count - 1, replay.positions.last?.isLost == true {
            return "将死！这一步结束了比赛。"
        }
        guard replay.reviewed(i) else { return "对手走的棋。" }
        guard let r = replay.reviews?[i] else {
            return "老师正在看这盘棋…（\(replay.analyzed)/\(replay.moves.count)）"
        }
        let bestName = replay.positions[i].notation(r.best)
        if r.best == replay.moves[i] { return "好棋！和电脑想的一样。" }
        switch r.verdict.text {
        case "失误": return "这一步亏了。黄色箭头是你走的，电脑会走绿色箭头「\(bestName)」。"
        case "可以更好": return "还不错，不过绿色箭头「\(bestName)」会更好一点。"
        default: return "好棋！"
        }
    }

    /// 全部着法，两两一行（红一步、黑一步）
    private var moveList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(0..<(replay.moves.count + 1) / 2, id: \.self) { row in
                        HStack(spacing: 8) {
                            Text("\(row + 1).")
                                .font(.kid(15, weight: .bold))
                                .foregroundStyle(Palette.inkSoft)
                                .frame(width: 34, alignment: .trailing)
                            moveCell(row * 2)
                            if row * 2 + 1 < replay.moves.count { moveCell(row * 2 + 1) } else { Color.clear.frame(maxWidth: .infinity) }
                        }
                        .id(row)
                    }
                }
                .padding(10)
            }
            .background(Palette.paper.opacity(0.7), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .onChange(of: replay.step) { _, s in
                withAnimation { proxy.scrollTo(max(0, (s - 1) / 2), anchor: .center) }
            }
        }
    }

    private func moveCell(_ i: Int) -> some View {
        let current = replay.step == i + 1
        let review = replay.reviewed(i) ? replay.reviews?[i] : nil
        return Button {
            replay.stop()
            replay.go(to: i + 1)
        } label: {
            HStack(spacing: 6) {
                Text(replay.notation(i))
                    .font(.kid(17, weight: .heavy))
                    .foregroundStyle(replay.side(ofPly: i) == .red ? XiangqiPieceView.redInk : XiangqiPieceView.blackInk)
                Spacer(minLength: 0)
                if let v = review?.verdict, v.text != "好棋" {
                    Image(systemName: v.icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(v.color)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(current ? Palette.honey.opacity(0.35) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            ControlButton(systemName: "backward.end.fill", label: "开局", enabled: replay.step > 0) { replay.stop(); replay.go(to: 0, sound: false) }
            ControlButton(systemName: "chevron.left", label: "上一步", enabled: replay.step > 0) { replay.stop(); replay.go(to: replay.step - 1) }
            ControlButton(systemName: replay.playing ? "pause.fill" : "play.fill", label: replay.playing ? "暂停" : "播放",
                          enabled: !replay.moves.isEmpty) { replay.togglePlay() }
            ControlButton(systemName: "chevron.right", label: "下一步", enabled: replay.step < replay.moves.count) { replay.stop(); replay.go(to: replay.step + 1) }
        }
    }
}
