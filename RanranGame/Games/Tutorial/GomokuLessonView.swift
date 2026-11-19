import SwiftUI
import Observation

/// 五子棋的一课：小棋盘上的局面跟着每一步变化，冉冉执黑。
@Observable
@MainActor
final class GomokuLessonSession {
    let flow: LessonFlow
    private(set) var board = GLessonBoard(size: 9)
    private(set) var last: Point?
    /// 刚刚点错的地方（显示一下马上消失）
    private(set) var miss: Point?
    private var replyTask: Task<Void, Never>?

    init(course: TutorialCourse, lesson: TutorialLesson) {
        flow = LessonFlow(course: course, lesson: lesson)
        syncBoard()
        flow.onStep = { [weak self] in self?.syncBoard() }
    }

    var marks: [MarkSpec] { (flow.step.marks ?? []).map(MarkSpec.init) }

    /// 答错两次后亮出来的答案
    var revealed: [Point] {
        guard flow.revealed, let t = flow.task else { return [] }
        return Array(GomokuLessonLogic.answers(t, on: board).prefix(t.type == "pick" ? 10 : 2))
    }

    /// 棋盘上已经连成五颗的那一排
    var winLine: [Point]? {
        guard let last else { return nil }
        return board.line(at: last)
    }

    func syncBoard() {
        if let spec = flow.step.board, let b = GLessonBoard(spec: spec) {
            withAnimation(.spring(duration: 0.4)) {
                board = b
                last = nil
            }
        }
    }

    func tap(_ p: Point) {
        guard flow.awaitingAnswer, let task = flow.task else { return }
        if task.type == "pick" {
            if GomokuLessonLogic.check(task, p, on: board) {
                flow.succeed()
            } else {
                flow.fail(board[p] == nil ? nil : TutorLines.wrongPick)
            }
            return
        }
        guard board[p] == nil else { return }
        if GomokuLessonLogic.check(task, p, on: board) {
            withAnimation(.spring(duration: 0.32, bounce: 0.35)) {
                board[p] = .black
                last = p
            }
            Sound.place(.black)
            flow.succeed()
            if let reply = flow.step.reply { playReply(reply) }
        } else {
            withAnimation(.spring(duration: 0.2)) { miss = p }
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                withAnimation(.easeOut(duration: 0.25)) { if self.miss == p { self.miss = nil } }
            }
            flow.fail()
        }
    }

    private func playReply(_ spec: [String]) {
        let moves = GomokuLessonLogic.reply(spec, on: board)
        flow.beginReply()
        replyTask = Task {
            for p in moves {
                try? await Task.sleep(for: .milliseconds(1100))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(duration: 0.32, bounce: 0.35)) {
                    board[p] = .white
                    last = p
                }
                Sound.place(.white)
            }
            try? await Task.sleep(for: .milliseconds(300))
            flow.endReply()
        }
    }

    func stop() {
        replyTask?.cancel()
        flow.stop()
    }
}

struct GomokuLessonView: View {
    @State private var session: GomokuLessonSession
    let onNextLesson: (TutorialLesson) -> Void

    init(course: TutorialCourse, lesson: TutorialLesson, onNextLesson: @escaping (TutorialLesson) -> Void) {
        _session = State(initialValue: GomokuLessonSession(course: course, lesson: lesson))
        self.onNextLesson = onNextLesson
    }

    var body: some View {
        LessonScaffold(flow: session.flow, accent: Palette.coral, onNextLesson: onNextLesson) {
            MiniGoBoard(session: session)
        }
        .onDisappear { session.stop() }
    }
}

/// 教学用的五子棋小棋盘
private struct MiniGoBoard: View {
    let session: GomokuLessonSession

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let n = session.board.size
            let margin = side * 0.075
            let cell = (side - margin * 2) / CGFloat(n - 1)
            let center = { (p: Point) in CGPoint(x: margin + CGFloat(p.x) * cell, y: margin + CGFloat(p.y) * cell) }
            ZStack(alignment: .topLeading) {
                surface(side: side, n: n, margin: margin, cell: cell, center: center)

                // 提示点、叉在棋子下面；连线、字母在上面
                ForEach(Array(session.marks.enumerated()).filter { ["glow", "cross"].contains($0.element.kind) }, id: \.offset) { _, m in
                    mark(m, cell: cell, center: center)
                }

                ForEach(session.board.stones, id: \.0) { p, s in
                    StoneView(stone: s, diameter: cell * 0.88)
                        .position(center(p))
                        .transition(.scale(scale: 1.35).combined(with: .opacity))
                }

                if let last = session.last, session.winLine == nil {
                    Circle()
                        .fill(Palette.coral)
                        .frame(width: cell * 0.2, height: cell * 0.2)
                        .position(center(last))
                }

                if let line = session.winLine, line.count >= 2 {
                    WinStroke(from: center(line.first!), to: center(line.last!), progress: 1, width: cell * 0.14)
                        .transition(.opacity)
                }

                ForEach(Array(session.marks.enumerated()).filter { !["glow", "cross"].contains($0.element.kind) }, id: \.offset) { _, m in
                    mark(m, cell: cell, center: center)
                }

                ForEach(session.revealed, id: \.self) { p in
                    TargetBeacon(color: Color(hex: 0x4E8A5C))
                        .frame(width: cell * 1.0, height: cell * 1.0)
                        .position(center(p))
                }

                if let miss = session.miss {
                    ZStack {
                        StoneView(stone: .black, diameter: cell * 0.88).opacity(0.35)
                        Image(systemName: "xmark")
                            .font(.system(size: cell * 0.45, weight: .black))
                            .foregroundStyle(Palette.coral)
                    }
                    .position(center(miss))
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onEnded { v in
                    let x = Int(((v.location.x - margin) / cell).rounded())
                    let y = Int(((v.location.y - margin) / cell).rounded())
                    guard x >= 0, y >= 0, x < n, y < n else { return }
                    session.tap(Point(x: x, y: y))
                }
            )
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func surface(side: CGFloat, n: Int, margin: CGFloat, cell: CGFloat, center: @escaping (Point) -> CGPoint) -> some View {
        let r = side * 0.035
        return ZStack {
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(LinearGradient(colors: [Palette.woodDeep, Color(hex: 0x95653A)], startPoint: .top, endPoint: .bottom))
                .offset(y: side * 0.016)
            ArtImage(name: "board_wood", fallback: "", contentMode: .fill)
                .saturation(0.82)
                .background(LinearGradient(colors: [Color(hex: 0xEDC88E), Palette.wood], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
            Canvas { ctx, _ in
                let ink = Color(hex: 0x3A2614)
                var grid = Path()
                for i in 0..<n {
                    grid.move(to: center(Point(x: i, y: 0))); grid.addLine(to: center(Point(x: i, y: n - 1)))
                    grid.move(to: center(Point(x: 0, y: i))); grid.addLine(to: center(Point(x: n - 1, y: i)))
                }
                ctx.stroke(grid, with: .color(ink.opacity(0.62)), lineWidth: max(1, cell * 0.03))
                let c = center(Point(x: n / 2, y: n / 2))
                let rr = cell * 0.09
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)), with: .color(ink.opacity(0.8)))
            }
        }
        .frame(width: side, height: side)
        .shadow(color: Color(hex: 0x7A4E22).opacity(0.28), radius: side * 0.04, y: side * 0.03)
    }

    @ViewBuilder
    private func mark(_ m: MarkSpec, cell: CGFloat, center: (Point) -> CGPoint) -> some View {
        let size = session.board.size
        let pt = { (i: Int) in m.args.count > i ? GLessonBoard.point(m.args[i], size: size) : nil }
        switch m.kind {
        case "glow":
            if let p = pt(0) {
                TargetBeacon()
                    .frame(width: cell * 0.95, height: cell * 0.95)
                    .position(center(p))
            }
        case "cross":
            if let p = pt(0) {
                Image(systemName: "xmark")
                    .font(.system(size: cell * 0.5, weight: .black))
                    .foregroundStyle(Palette.coral)
                    .position(center(p))
            }
        case "label":
            if let p = pt(0), m.args.count > 1 {
                Text(m.args[1])
                    .font(.kid(cell * 0.36, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: cell * 0.56, height: cell * 0.56)
                    .background(Palette.coral, in: Circle())
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    .position(center(p))
                    .offset(x: -cell * 0.5, y: -cell * 0.5)
            }
        case "line":
            if let a = pt(0), let b = pt(1) {
                WinStroke(from: center(a), to: center(b), progress: 1, width: cell * 0.14)
            }
        default:
            EmptyView()
        }
    }
}
