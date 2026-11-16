import SwiftUI
import Observation

/// 复盘一盘五子棋：一步一步看、每手点评、形势曲线、电脑推荐的下法。
@Observable
@MainActor
final class GomokuReplay {
    let record: GameRecord
    let moves: [Point]
    /// 棋盘上显示到第几手（0 = 空棋盘）
    var step: Int
    private(set) var reviews: [MoveReview]?
    private(set) var analyzed = 0
    private(set) var playing = false
    private var playTask: Task<Void, Never>?

    /// 分析结果缓存，退出再进来不用重算
    private static var cache: [UUID: [MoveReview]] = [:]

    init(record: GameRecord) {
        self.record = record
        moves = record.moves.compactMap { $0.count == 2 ? Point(x: $0[0], y: $0[1]) : nil }
        step = moves.count
        reviews = Self.cache[record.id]
        if reviews != nil { analyzed = moves.count }
    }

    var level: GomokuLevel? { record.opponentLevel.map(GomokuLevel.init) }
    var playerColor: Stone? { record.playerColor.flatMap { Stone(rawValue: Int8($0)) } }
    var winner: Stone? { record.winner.flatMap { Stone(rawValue: Int8($0)) } }

    func color(ofMove i: Int) -> Stone { i % 2 == 0 ? .black : .white }

    var currentReview: MoveReview? {
        guard step > 0, let reviews, reviews.indices.contains(step - 1) else { return nil }
        return reviews[step - 1]
    }

    var winLine: [Point] {
        guard step == moves.count, let last = moves.last else { return [] }
        var b = Board()
        for (i, p) in moves.enumerated() { b[p] = color(ofMove: i) }
        return b.winningLine(at: last) ?? []
    }

    func analyze() async {
        guard reviews == nil else { return }
        let moves = self.moves
        let result = await Task.detached(priority: .userInitiated) { [weak self] in
            GomokuAI.review(moves: moves) { n in
                Task { @MainActor in self?.analyzed = n }
            }
        }.value
        Self.cache[record.id] = result
        withAnimation(.easeInOut(duration: 0.4)) {
            reviews = result
            analyzed = moves.count
        }
    }

    func go(to s: Int, sound: Bool = true) {
        let target = min(max(s, 0), moves.count)
        guard target != step else { return }
        if sound, target > step { Sound.place(color(ofMove: target - 1)) }
        withAnimation(.spring(duration: 0.3, bounce: 0.25)) { step = target }
    }

    func togglePlay() {
        if playing { stopPlaying(); return }
        if step >= moves.count { go(to: 0, sound: false) }
        playing = true
        playTask = Task { [weak self] in
            while let self, self.playing, self.step < self.moves.count {
                try? await Task.sleep(for: .milliseconds(750))
                guard !Task.isCancelled, self.playing else { return }
                self.go(to: self.step + 1)
            }
            self?.playing = false
        }
    }

    func stopPlaying() {
        playing = false
        playTask?.cancel()
    }

    /// 从当前位置往后找下一手符合条件的棋，没有就从头找
    func jumpToNext(where match: (MoveReview) -> Bool) {
        guard let reviews else { return }
        let after = reviews.filter { $0.index >= step && match($0) }
        if let r = after.first ?? reviews.first(where: match) {
            stopPlaying()
            go(to: r.index + 1)
        }
    }

    /// 点评总结只看"自己"那一方（和家人下就两方都看）
    func counts(for color: Stone?) -> [MoveReview.Group: Int] {
        var out: [MoveReview.Group: Int] = [:]
        for r in reviews ?? [] where color == nil || r.color == color {
            if let g = r.group { out[g, default: 0] += 1 }
        }
        return out
    }
}

extension MoveReview {
    enum Group: CaseIterable { case brilliant, good, inaccuracy, mistake }

    var group: Group? {
        switch kind {
        case .brilliant: .brilliant
        case .best, .good: .good
        case .inaccuracy: .inaccuracy
        case .mistake, .missedWin: .mistake
        case .win, .forced: nil
        }
    }

    var tag: String {
        switch kind {
        case .win: "胜利"
        case .brilliant: "妙手"
        case .best: "好棋"
        case .good: "不错"
        case .forced: "防守"
        case .inaccuracy: "疑问手"
        case .mistake: "失误"
        case .missedWin: "错过胜机"
        }
    }

    var icon: String {
        switch kind {
        case .win: "trophy.fill"
        case .brilliant: "sparkles"
        case .best: "checkmark.circle.fill"
        case .good: "hand.thumbsup.fill"
        case .forced: "shield.fill"
        case .inaccuracy: "questionmark.circle.fill"
        case .mistake: "exclamationmark.triangle.fill"
        case .missedWin: "exclamationmark.circle.fill"
        }
    }

    var tint: Color {
        switch kind {
        case .win: Palette.honey
        case .brilliant: Palette.lilac
        case .best: Palette.sage
        case .good: Palette.sky
        case .forced: Palette.inkSoft
        case .inaccuracy: Palette.honey
        case .mistake, .missedWin: Palette.coral
        }
    }
}

extension MoveReview.Group {
    var title: String {
        switch self {
        case .brilliant: "妙手"
        case .good: "好棋"
        case .inaccuracy: "疑问手"
        case .mistake: "失误"
        }
    }

    var tint: Color {
        switch self {
        case .brilliant: Palette.lilac
        case .good: Palette.sage
        case .inaccuracy: Palette.honey
        case .mistake: Palette.coral
        }
    }

    var icon: String {
        switch self {
        case .brilliant: "sparkles"
        case .good: "checkmark.circle.fill"
        case .inaccuracy: "questionmark.circle.fill"
        case .mistake: "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - 界面

struct GomokuReplayView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var replay: GomokuReplay
    @State private var showNumbers = false

    init(record: GameRecord) {
        _replay = State(initialValue: GomokuReplay(record: record))
    }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            ZStack {
                CreamBackground(accent: replay.level?.character.tint ?? Palette.sky)
                if landscape {
                    HStack(spacing: 32) {
                        ReplayBoard(replay: replay, showNumbers: showNumbers)
                            .padding(.vertical, 8)
                        ScrollView {
                            panel.padding(.vertical, 4)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .frame(width: min(420, geo.size.width * 0.33))
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                } else {
                    VStack(spacing: 18) {
                        header
                        ReplayBoard(replay: replay, showNumbers: showNumbers)
                            .frame(maxHeight: geo.size.width - 56)
                        HStack(alignment: .top, spacing: 18) {
                            VStack(spacing: 16) {
                                commentCard
                                controls
                            }
                            VStack(spacing: 16) {
                                chartCard
                                summary
                            }
                        }
                    }
                    .padding(28)
                }
            }
        }
        .task { await replay.analyze() }
        .onDisappear { replay.stopPlaying() }
    }

    private var panel: some View {
        VStack(spacing: 18) {
            header
            commentCard
            chartCard
            summary
            controls
        }
    }

    // MARK: 标题

    private var header: some View {
        HStack(spacing: 14) {
            RoundIconButton(systemName: "chevron.left", label: "返回") { dismiss() }
            VStack(alignment: .leading, spacing: 2) {
                Text("复盘")
                    .font(.kid(30, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text(subtitle)
                    .font(.kid(16, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
    }

    private var subtitle: String {
        let date = replay.record.date.shortChinese
        let who = replay.level.map { "第 \($0.number) 档 · \($0.character.name)" } ?? "和家人下"
        let result: String
        if let w = replay.winner {
            if let me = replay.playerColor { result = w == me ? "赢了" : "输了" } else { result = "\(w.name)赢" }
        } else {
            result = "平局"
        }
        return "\(date) · \(who) · \(result)"
    }

    private func name(of color: Stone) -> String {
        guard let me = replay.playerColor else { return color.name }
        return color == me ? store.name : (replay.level?.character.name ?? color.name)
    }

    // MARK: 当前这一手的点评

    private var commentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if replay.step == 0 {
                Text("空棋盘")
                    .font(.kid(22, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text("点 ▶ 一步一步看，或者在下面的曲线上滑动")
                    .font(.kid(18, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
            } else {
                let i = replay.step - 1
                let color = replay.color(ofMove: i)
                HStack(spacing: 10) {
                    StoneView(stone: color, diameter: 26)
                    Text("第 \(replay.step) 手 · \(name(of: color))")
                        .font(.kid(22, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: 0)
                    if let r = replay.currentReview {
                        Label(r.tag, systemImage: r.icon)
                            .font(.kid(16, weight: .heavy))
                            .foregroundStyle(Palette.ink.opacity(0.85))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(r.tint.opacity(0.35), in: Capsule())
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                if let r = replay.currentReview {
                    Text(r.note)
                        .font(.kid(19, weight: .semibold))
                        .foregroundStyle(Palette.ink.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                    if r.suggestion != nil {
                        HStack(spacing: 8) {
                            Circle().fill(Palette.sage).frame(width: 12, height: 12)
                            Text("棋盘上发光的地方是推荐的下法")
                                .font(.kid(16, weight: .semibold))
                                .foregroundStyle(Palette.inkSoft)
                        }
                    }
                } else {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("正在分析这盘棋… \(replay.analyzed)/\(replay.moves.count)")
                            .font(.kid(17, weight: .semibold))
                            .foregroundStyle(Palette.inkSoft)
                            .monospacedDigit()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(20)
        .softCard(radius: 28)
        .animation(.spring(duration: 0.3), value: replay.step)
    }

    // MARK: 形势曲线

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("形势")
                    .font(.kid(20, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("按住左右滑动")
                    .font(.kid(14, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft.opacity(0.8))
            }
            AdvantageChart(replay: replay)
                .frame(height: 130)
        }
        .padding(20)
        .softCard(radius: 28)
    }

    // MARK: 总结

    private var summary: some View {
        let focus = replay.playerColor
        let counts = replay.counts(for: focus)
        return VStack(alignment: .leading, spacing: 12) {
            Text(focus == nil ? "两边一共" : "\(store.name)这盘棋")
                .font(.kid(20, weight: .heavy))
                .foregroundStyle(Palette.ink)
            HStack(spacing: 10) {
                ForEach(MoveReview.Group.allCases, id: \.self) { g in
                    let n = counts[g, default: 0]
                    Button {
                        Sound.tap()
                        replay.jumpToNext { $0.group == g && (focus == nil || $0.color == focus) }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: g.icon)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(g.tint)
                            Text("\(n)")
                                .font(.kid(24, weight: .heavy))
                                .foregroundStyle(Palette.ink)
                                .monospacedDigit()
                            Text(g.title)
                                .font(.kid(14, weight: .bold))
                                .foregroundStyle(Palette.inkSoft)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(g.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(PressableStyle(scale: 0.92))
                    .disabled(n == 0)
                    .opacity(replay.reviews == nil ? 0.4 : 1)
                }
            }
            Text("点一下可以跳到那一手")
                .font(.kid(14, weight: .semibold))
                .foregroundStyle(Palette.inkSoft.opacity(0.8))
        }
        .padding(20)
        .softCard(radius: 28)
    }

    // MARK: 播放控制

    private var controls: some View {
        HStack(spacing: 10) {
            ReplayButton(systemName: "backward.end.fill", label: "开头") { replay.stopPlaying(); replay.go(to: 0, sound: false) }
            ReplayButton(systemName: "chevron.left", label: "上一手") { replay.stopPlaying(); replay.go(to: replay.step - 1, sound: false) }
            ReplayButton(systemName: replay.playing ? "pause.fill" : "play.fill", label: replay.playing ? "暂停" : "播放",
                         prominent: true) { replay.togglePlay() }
            ReplayButton(systemName: "chevron.right", label: "下一手") { replay.stopPlaying(); replay.go(to: replay.step + 1) }
            ReplayButton(systemName: "forward.end.fill", label: "最后") { replay.stopPlaying(); replay.go(to: replay.moves.count, sound: false) }
            ReplayButton(systemName: "number", label: "手数", selected: showNumbers) {
                withAnimation(.spring(duration: 0.3)) { showNumbers.toggle() }
            }
        }
    }
}

private struct ReplayButton: View {
    let systemName: String
    let label: String
    var prominent = false
    var selected = false
    let action: () -> Void

    var body: some View {
        Button {
            Sound.tap()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: prominent ? 24 : 20, weight: .heavy))
                .foregroundStyle(prominent || selected ? .white : Palette.ink)
                .frame(maxWidth: .infinity)
                .frame(height: prominent ? 64 : 56)
                .background(prominent ? Palette.coral : (selected ? Palette.ink : Palette.paper),
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        }
        .buttonStyle(PressableStyle(scale: 0.9))
        .accessibilityLabel(label)
    }
}

// MARK: - 棋盘

private struct ReplayBoard: View {
    let replay: GomokuReplay
    let showNumbers: Bool

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let layout = BoardLayout(side: side)
            let review = replay.currentReview

            ZStack(alignment: .topLeading) {
                BoardSurface(layout: layout)

                // 推荐的下法
                if let review, let s = review.suggestion {
                    ZStack {
                        StoneView(stone: review.color, diameter: layout.cell * 0.9).opacity(0.4)
                        PulseRing(color: Palette.sage)
                            .frame(width: layout.cell * 1.15, height: layout.cell * 1.15)
                    }
                    .position(layout.center(s))
                    .transition(.scale.combined(with: .opacity))
                    .id("suggest-\(review.index)")
                }

                ForEach(0..<replay.step, id: \.self) { i in
                    let p = replay.moves[i]
                    let color = replay.color(ofMove: i)
                    StoneView(stone: color, diameter: layout.cell * 0.9)
                        .overlay {
                            if showNumbers {
                                Text("\(i + 1)")
                                    .font(.system(size: layout.cell * (i >= 99 ? 0.3 : 0.38), weight: .bold, design: .rounded))
                                    .foregroundStyle(color == .black ? .white : Palette.ink)
                                    .minimumScaleFactor(0.5)
                            }
                        }
                        .position(layout.center(p))
                        .transition(.asymmetric(insertion: .scale(scale: 1.35).combined(with: .opacity),
                                                removal: .opacity))
                }

                // 正在点评的这一手：外面一圈颜色表示好坏
                if let review, replay.step > 0 {
                    Circle()
                        .strokeBorder(review.tint, lineWidth: max(3, layout.cell * 0.09))
                        .frame(width: layout.cell * 1.08, height: layout.cell * 1.08)
                        .position(layout.center(replay.moves[replay.step - 1]))
                        .allowsHitTesting(false)
                } else if replay.step > 0, !showNumbers {
                    Circle()
                        .fill(Palette.coral)
                        .frame(width: layout.cell * 0.2, height: layout.cell * 0.2)
                        .position(layout.center(replay.moves[replay.step - 1]))
                }

                let line = replay.winLine
                if line.count >= 2 {
                    WinStroke(from: layout.center(line.first!), to: layout.center(line.last!),
                              progress: 1, width: layout.cell * 0.16)
                }
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            // 点棋盘上的棋子，跳到那一手
            .onTapGesture { loc in
                guard let p = layout.point(at: loc), let i = replay.moves.firstIndex(of: p) else { return }
                replay.stopPlaying()
                replay.go(to: i + 1, sound: false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - 形势曲线

/// 上半边是黑棋占优，下半边是白棋占优；红点是失误，紫点是妙手。按住滑动可以跳到任意一手。
private struct AdvantageChart: View {
    let replay: GomokuReplay

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let n = max(replay.moves.count, 1)
            let reviews = replay.reviews ?? []
            let x = { (step: Int) -> CGFloat in CGFloat(step) / CGFloat(n) * w }
            let y = { (a: Double) -> CGFloat in h / 2 - CGFloat(a) * (h / 2 - 6) }

            ZStack(alignment: .topLeading) {
                // 背景：上黑下白
                VStack(spacing: 0) {
                    Palette.ink.opacity(0.07)
                    Color.white.opacity(0.7)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text("黑棋占优").font(.kid(12, weight: .bold)).foregroundStyle(Palette.inkSoft.opacity(0.7))
                    .padding(6)
                Text("白棋占优").font(.kid(12, weight: .bold)).foregroundStyle(Palette.inkSoft.opacity(0.7))
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

                Path { p in
                    p.move(to: CGPoint(x: 0, y: h / 2)); p.addLine(to: CGPoint(x: w, y: h / 2))
                }
                .stroke(Palette.inkSoft.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                if !reviews.isEmpty {
                    let points = [CGPoint(x: 0, y: h / 2)] + reviews.map { CGPoint(x: x($0.index + 1), y: y($0.advantage)) }
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: h / 2))
                        for pt in points { p.addLine(to: pt) }
                        p.addLine(to: CGPoint(x: points.last!.x, y: h / 2))
                        p.closeSubpath()
                    }
                    .fill(Palette.ink.opacity(0.12))
                    Path { p in
                        p.move(to: points[0])
                        for pt in points.dropFirst() { p.addLine(to: pt) }
                    }
                    .stroke(Palette.ink.opacity(0.75), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    ForEach(reviews.filter { $0.group == .mistake || $0.kind == .brilliant }, id: \.index) { r in
                        Circle()
                            .fill(r.kind == .brilliant ? Palette.lilac : Palette.coral)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                            .position(x: x(r.index + 1), y: y(r.advantage))
                    }
                } else {
                    ProgressView(value: Double(replay.analyzed), total: Double(n))
                        .tint(Palette.coral)
                        .padding(.horizontal, 30)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // 当前位置
                Capsule()
                    .fill(Palette.coral)
                    .frame(width: 3, height: h)
                    .position(x: x(replay.step), y: h / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        replay.stopPlaying()
                        let s = Int((v.location.x / w * CGFloat(n)).rounded())
                        replay.go(to: s, sound: false)
                    }
            )
        }
    }
}
