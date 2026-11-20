import SwiftUI

/// 复盘一盘围棋：一步一步看，提子数跟着变；下到最后显示数子的结果。
struct GoReplayView: View {
    @Environment(\.dismiss) private var dismiss
    let record: GameRecord
    private let positions: [GoBoard]
    private let moves: [Int?]
    @State private var step: Int
    @State private var playing = false
    @State private var score: (black: Int, white: Int, owner: [Int8], dead: Set<Int>)?

    init(record: GameRecord) {
        self.record = record
        var b = GoBoard(size: record.boardSize)
        var ps = [b], ms: [Int?] = []
        for m in record.moves where m.count == 2 {
            if m[0] < 0 { b.pass(); ms.append(nil) } else {
                let i = m[1] * record.boardSize + m[0]
                guard b.play(i) != nil else { break }
                ms.append(i)
            }
            ps.append(b)
        }
        positions = ps
        moves = ms
        _step = State(initialValue: ms.count)
    }

    private var board: GoBoard { positions[step] }
    private var finished: Bool { step == moves.count && board.passes >= 2 }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            ZStack {
                CreamBackground(accent: record.opponentLevel.map { Opponent.forLevel($0).tint } ?? Palette.sage)
                if wide {
                    HStack(spacing: 28) {
                        boardView
                        VStack(spacing: 18) { header; info; Spacer(minLength: 0); controls }
                            .frame(width: min(380, geo.size.width * 0.32))
                    }
                    .padding(28)
                } else {
                    VStack(spacing: 18) { header; info; boardView; controls }.padding(26)
                }
            }
        }
        .task(id: finished) {
            guard finished, score == nil else { return }
            let b = board
            let s = await Task.detached(priority: .userInitiated) { () -> (Int, Int, [Int8], Set<Int>) in
                let dead = GoAI.deadStones(b)
                let a = b.area(dead: dead)
                return (a.black, a.white, a.owner, dead)
            }.value
            withAnimation(.easeInOut(duration: 0.5)) { score = s }
        }
    }

    private var boardView: some View {
        GoBoardView(state: GoBoardState(board: board, lastMove: step > 0 ? moves[step - 1] : nil,
                                        owner: finished ? score?.owner : nil,
                                        dead: finished ? (score?.dead ?? []) : [])) { _ in }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 14) {
            RoundIconButton(systemName: "chevron.left", label: "返回") { dismiss() }
            VStack(alignment: .leading, spacing: 4) {
                Text("围棋复盘")
                    .font(.kid(28, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text([record.date.shortChinese,
                      record.opponentLevel.map { "第 \($0) 档 · \(Opponent.forLevel($0).name)" } ?? "和家人下",
                      "共 \(moves.count) 手"].joined(separator: " · "))
                    .font(.kid(16, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(step == 0 ? "开局" : "第 \(step) 手 · \(step % 2 == 1 ? "黑棋" : "白棋")\(moves[step - 1] == nil ? "停一手" : "")")
                .font(.kid(20, weight: .heavy))
                .foregroundStyle(Palette.ink)
            Text("黑提 \(board.prisoners[0]) 子 · 白提 \(board.prisoners[1]) 子")
                .font(.kid(17, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
                .monospacedDigit()
            if finished, let s = score {
                let margin = Double(s.black) - Double(s.white) - GoAI.komi
                Text("数子：黑 \(s.black)，白 \(s.white) + 7.5 → \(margin > 0 ? "黑" : "白")胜 \(String(format: "%.1f", abs(margin))) 子")
                    .font(.kid(17, weight: .bold))
                    .foregroundStyle(Palette.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 96, alignment: .topLeading)
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var controls: some View {
        HStack(spacing: 12) {
            ControlButton(systemName: "backward.end.fill", label: "开局", enabled: step > 0) { playing = false; go(0) }
            ControlButton(systemName: "chevron.left", label: "上一手", enabled: step > 0) { playing = false; go(step - 1) }
            ControlButton(systemName: playing ? "pause.fill" : "play.fill", label: playing ? "暂停" : "播放", enabled: !moves.isEmpty) { toggle() }
            ControlButton(systemName: "chevron.right", label: "下一手", enabled: step < moves.count) { playing = false; go(step + 1) }
        }
    }

    private func go(_ s: Int) {
        let t = min(max(s, 0), moves.count)
        guard t != step else { return }
        if t > step { Sound.place(t % 2 == 1 ? .black : .white) }
        withAnimation(.spring(duration: 0.3)) { step = t }
    }

    private func toggle() {
        if playing { playing = false; return }
        if step >= moves.count { go(0) }
        playing = true
        Task {
            while playing, step < moves.count {
                try? await Task.sleep(for: .milliseconds(700))
                guard playing else { return }
                go(step + 1)
            }
            playing = false
        }
    }
}
