import SwiftUI
import Observation

/// 复盘一盘国际象棋：一步一步看、记谱（标准代数记谱 + 中文说明）、电脑逐手点评，失误的地方画出电脑会怎么走。
@Observable
@MainActor
final class ChessReplay {
    struct Review: Hashable {
        /// 这一步之前，电脑觉得最好的一步
        let best: ChessMove
        /// 走完以后，局面比走最好的一步差了多少分（百分之一个兵，越大越亏）
        let loss: Int

        var verdict: (text: String, color: Color, icon: String) {
            if loss >= 250 { return ("失误", Palette.coral, "exclamationmark.triangle.fill") }
            if loss >= 90 { return ("可以更好", Palette.honey, "lightbulb.fill") }
            return ("好棋", Palette.sage, "hand.thumbsup.fill")
        }
    }

    let record: GameRecord
    let moves: [ChessMove]
    /// 每一步之前的局面（positions[0] 是开局）
    let positions: [ChessBoard]
    /// 每一步之后棋子的编号（让回放时棋子滑过去）
    private let idTrail: [[Int]]
    var step: Int
    private(set) var reviews: [Review]?
    private(set) var analyzed = 0
    private(set) var playing = false
    private var playTask: Task<Void, Never>?

    private static var cache: [UUID: [Review]] = [:]

    init(record: GameRecord) {
        self.record = record
        var b = ChessBoard.start
        var ms: [ChessMove] = []
        var ps = [b]
        var ids = ChessPieceIDs.initial(b)
        var trail = [ids]
        for m in record.moves where m.count >= 4 {
            guard (0..<8).contains(m[0]), (0..<8).contains(m[1]), (0..<8).contains(m[2]), (0..<8).contains(m[3]) else { break }
            let promo = m.count >= 5 ? ChessKind(rawValue: Int8(m[4])) : nil
            let mv = ChessMove(ChessSquare(m[0], m[1]), ChessSquare(m[2], m[3]), promotion: promo)
            guard b.isLegal(mv) else { break }
            ChessPieceIDs.apply(mv, on: b, &ids)
            b.make(mv)
            ms.append(mv)
            ps.append(b)
            trail.append(ids)
        }
        moves = ms
        positions = ps
        idTrail = trail
        step = ms.count
        reviews = Self.cache[record.id]
        if reviews != nil { analyzed = ms.count }
    }

    var level: ChessLevel? { record.opponentLevel.map(ChessLevel.init) }
    var humanSide: ChessSide? { record.playerColor.map { $0 == 1 ? .white : .black } }
    var board: ChessBoard { positions[step] }

    var currentMove: ChessMove? { step > 0 ? moves[step - 1] : nil }
    var currentReview: Review? {
        guard step > 0, let reviews, reviews.indices.contains(step - 1) else { return nil }
        return reviews[step - 1]
    }

    func side(ofPly i: Int) -> ChessSide { i % 2 == 0 ? .white : .black }

    /// 这一步要不要点评：和电脑下时只点评冉冉自己的棋
    func reviewed(_ i: Int) -> Bool { humanSide == nil || side(ofPly: i) == humanSide }

    func san(_ i: Int) -> String { positions[i].san(moves[i]) }
    func chinese(_ i: Int) -> String { positions[i].chinese(moves[i]) }

    var ids: [Int] { idTrail[step] }
    var idsBefore: [Int] { idTrail[max(0, step - 1)] }

    func analyze() async {
        guard reviews == nil, !moves.isEmpty else { return }
        let positions = self.positions, moves = self.moves
        var out: [Review] = []
        for i in moves.indices {
            let r = await Task.detached(priority: .userInitiated) { () -> Review in
                let before = positions[i]
                let ai = ChessAI(profile: .level(6))
                let best = ai.bestMove(before) ?? moves[i]
                let afterPlayed = -ai.evaluate(before.applying(moves[i]), depth: 2)
                let afterBest = best == moves[i] ? afterPlayed : -ai.evaluate(before.applying(best), depth: 2)
                return Review(best: best, loss: max(0, afterBest - afterPlayed))
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

    #if DEBUG
    /// 调试截图用的一盘示范棋（启动参数 -replayDemo YES）：意大利开局，白方第 7 步送了一个马，最后黑方走错被将死
    static let demoRecord: GameRecord = {
        let ucis = ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5", "e1g1", "g8f6", "d2d3", "d7d6", "c1g5", "h7h6",
                    "f3h4", "h6g5", "h4f5", "c8f5", "e4f5", "d8d7", "d1f3", "e8c8", "c4f7", "d7f5", "f3f5", "c8b8"]
        var b = ChessBoard.start
        var moves: [[Int]] = []
        for u in ucis {
            guard let m = ChessMove(u), b.isLegal(m) else { break }
            moves.append([m.from.file, m.from.rank, m.to.file, m.to.rank])
            b.make(m)
        }
        return GameRecord(id: UUID(uuidString: "C0FFEE00-0000-4000-8000-000000000001")!, game: "chess", date: Date(),
                          boardSize: 8, moves: moves, opponentLevel: 3, playerColor: 1, winner: nil, stars: 0)
    }()
    #endif
}

/// 复盘里点评出来的错误，对应教学里的哪一课
enum ChessReplayLessons {
    static func lessonID(before: ChessBoard, played: ChessMove) -> String? {
        let after = before.applying(played)
        // 能一步将死没将死 → 将死
        if !after.isCheckmate, !before.matesInOne().isEmpty { return "c11" }
        // 走完以后对方一步就能将死（没解好将、没防住杀） → 底线杀 / 被将军了怎么办
        if after.hasLegalMove, !after.matesInOne().isEmpty { return before.inCheck ? "c10" : "c16" }
        // 走过去的子白白被吃 → 棋子的价值
        if let p = before[played.from], p.kind != .king, p.kind != .pawn,
           !after.attackers(played.to.index, by: after.turn).isEmpty, !after.attacked(played.to.index, by: p.side) {
            return "c20"
        }
        return nil
    }
}

struct ChessReplayView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var replay: ChessReplay

    init(record: GameRecord) {
        _replay = State(initialValue: ChessReplay(record: record))
    }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            ZStack {
                CreamBackground(accent: replay.level?.character.tint ?? Palette.lilac)
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
        return ChessBoardView(state: ChessBoardState(
            board: shown, ids: showBest ? replay.idsBefore : replay.ids,
            flipped: replay.humanSide == .black,
            lastMove: showBest ? nil : played,
            checkedKing: shown.inCheck ? shown.king(shown.turn) : nil,
            hint: showBest ? replay.currentReview?.best : nil,
            marks: showBest ? played.map { [.arrow($0.from, $0.to)] } ?? [] : []
        )) { _ in }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 14) {
            RoundIconButton(systemName: "chevron.left", label: "返回") { dismiss() }
            VStack(alignment: .leading, spacing: 4) {
                Text("国际象棋复盘")
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
                    Text("开局。点 ▶ 一步一步看，或者点任意一步。")
                        .font(.kid(19, weight: .bold))
                        .foregroundStyle(Palette.ink)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("第 \(replay.step) 步 · \(replay.side(ofPly: i).name)")
                            .font(.kid(16, weight: .heavy))
                            .foregroundStyle(Palette.inkSoft)
                        Text(replay.san(i))
                            .font(.kid(22, weight: .heavy))
                            .foregroundStyle(Palette.ink)
                        Text(replay.chinese(i))
                            .font(.kid(17, weight: .bold))
                            .foregroundStyle(Palette.inkSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Text(comment(i))
                        .font(.kid(18, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let id = lessonID(i) {
                        ReviewLessonButton(game: "chess", lessonID: id)
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
        return ChessReplayLessons.lessonID(before: replay.positions[i], played: replay.moves[i])
    }

    private func comment(_ i: Int) -> String {
        if i == replay.moves.count - 1, let o = replay.positions.last?.outcome {
            return o.winner != nil ? "将死！这一步结束了比赛。" : "和棋：\(o.drawReason)。"
        }
        guard replay.reviewed(i) else { return "对手走的棋。" }
        guard let r = replay.reviews?[i] else {
            return "老师正在看这盘棋…（\(replay.analyzed)/\(replay.moves.count)）"
        }
        let bestName = replay.positions[i].san(r.best)
        if r.best == replay.moves[i] { return "好棋！和电脑想的一样。" }
        switch r.verdict.text {
        case "失误": return "这一步亏了。黄色箭头是你走的，电脑会走绿色箭头「\(bestName)」。"
        case "可以更好": return "还不错，不过绿色箭头「\(bestName)」会更好一点。"
        default: return "好棋！"
        }
    }

    /// 全部着法，两两一行（白一步、黑一步）
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
                ChessPieceView(piece: replay.positions[i][replay.moves[i].from] ?? ChessPiece(replay.side(ofPly: i), .pawn), size: 22)
                Text(replay.san(i))
                    .font(.kid(17, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                if let v = review?.verdict, v.text != "好棋" {
                    Image(systemName: v.icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(v.color)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(current ? Palette.lilac.opacity(0.35) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
