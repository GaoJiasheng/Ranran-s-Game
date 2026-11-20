import SwiftUI
import Observation

/// 象棋的一课：冉冉执红在下面。没有题的时候也可以点自己的子，看看它能走到哪里。
@Observable
@MainActor
final class XiangqiLessonSession {
    let flow: LessonFlow
    private(set) var board = XBoard(fen: XBoard.start)!
    private(set) var ids = XBoard.initialIDs(XBoard(fen: XBoard.start)!)
    private(set) var selected: XSquare?
    private(set) var lastMove: XMove?
    private(set) var flash = 0
    private var replyTask: Task<Void, Never>?

    init(course: TutorialCourse, lesson: TutorialLesson, mode: LessonMode = .lesson) {
        flow = LessonFlow(course: course, lesson: lesson, mode: mode)
        syncBoard()
        flow.onStep = { [weak self] in self?.syncBoard() }
    }

    private var redToMove: XBoard {
        var b = board
        b.turn = .red
        return b
    }

    var state: XBoardState {
        var marks: [XMark] = (flow.step.marks ?? []).compactMap(Self.mark)
        if flow.revealed, let t = flow.task {
            if t.type == "pick" {
                marks += (t.accept ?? []).compactMap(XSquare.init).map { .glow($0) }
            } else if let m = XiangqiLessonLogic.answers(t, on: redToMove).first {
                marks.append(.arrow(m.from, m.to))
                marks.append(.glow(m.to))
            }
        }
        let checked = board.inCheck(.red) ? board.king(.red) : nil
        return XBoardState(board: board, ids: ids, flipped: false, selected: selected,
                           targets: targets, lastMove: lastMove, checkedKing: checked,
                           hint: nil, marks: marks, checkFlash: flash)
    }

    private var targets: [XSquare] {
        guard let selected, !flow.busy, flow.task?.type != "pick" else { return [] }
        return redToMove.legalMoves(from: selected).map(\.to)
    }

    private static func mark(_ s: String) -> XMark? {
        let m = MarkSpec(s)
        let sq = { (i: Int) in m.args.count > i ? XSquare(m.args[i]) : nil }
        switch m.kind {
        case "glow": return sq(0).map { .glow($0) }
        case "ring": return sq(0).map { .ring($0, warn: false) }
        case "warn": return sq(0).map { .ring($0, warn: true) }
        case "cross": return sq(0).map { .cross($0) }
        case "arrow":
            guard let a = sq(0), let b = sq(1) else { return nil }
            return .arrow(a, b)
        case "label":
            guard let a = sq(0), m.args.count > 1 else { return nil }
            return .label(a, m.args[1])
        case "palace": return .palace(m.args.first == "black" ? .black : .red)
        case "river": return .river
        default: return nil
        }
    }

    func syncBoard() {
        selected = nil
        if let fen = flow.step.board, let b = XBoard(fen: fen) {
            withAnimation(.spring(duration: 0.4)) {
                board = b
                ids = XBoard.initialIDs(b)
                lastMove = nil
            }
        }
        board.turn = .red
    }

    func tap(_ s: XSquare) {
        guard !flow.busy, !flow.finished else { return }
        let task = flow.awaitingAnswer ? flow.task : nil

        if task?.type == "pick" {
            if XiangqiLessonLogic.checkPick(task!, s) { flow.succeed() } else { flow.fail(TutorLines.wrongPick) }
            return
        }

        // 点自己的子：选中 / 换一个
        if let p = board[s], p.side == .red {
            if let piece = task?.piece, piece != s.name {
                flow.nudge(TutorLines.notThisPiece)
                return
            }
            withAnimation(.spring(duration: 0.25, bounce: 0.4)) { selected = selected == s ? nil : s }
            Sound.pick()
            return
        }
        guard let from = selected else { return }
        let m = XMove(from, s)
        let b = redToMove
        guard b.legalMoves(from: from).contains(m) else {
            // 不合规则：提醒一下，不算错
            if b.pseudoMoves(from: from).contains(m) {
                flow.nudge(b[from]?.kind == .king ? TutorLines.kingUnsafe : TutorLines.exposesKing)
            } else {
                flow.nudge(TutorLines.illegal)
            }
            withAnimation(.spring(duration: 0.25)) { selected = nil }
            return
        }
        guard let task, task.type == "move" else {
            // 没有题的时候：只是看看能走哪里，不真的走
            withAnimation(.spring(duration: 0.25)) { selected = nil }
            return
        }
        if XiangqiLessonLogic.check(task, m, on: b) {
            play(m)
            flow.succeed()
            if let reply = flow.step.reply { playReply(reply) }
        } else if let c = XiangqiLessonLogic.consequence(task, m, on: b) {
            showConsequence(m, c)
        } else {
            withAnimation(.spring(duration: 0.25)) { selected = nil }
            flow.fail()
        }
    }

    /// 走错了：真的走过去，黑方马上吃掉 / 黑将逃走，说一句，再退回去
    private func showConsequence(_ m: XMove, _ c: LessonConsequence<XMove>) {
        let before = (board: board, ids: ids, last: lastMove)
        play(m)
        flow.beginReply()
        replyTask = Task {
            try? await Task.sleep(for: .milliseconds(650))
            for r in c.moves where !Task.isCancelled { play(r) }
            await flow.showConsequence(c.line)
            withAnimation(.spring(duration: 0.45, bounce: 0.2)) {
                board = before.board
                ids = before.ids
                lastMove = before.last
                selected = nil
            }
            board.turn = .red
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .milliseconds(350))
            flow.endConsequence()
        }
    }

    private func play(_ m: XMove) {
        withAnimation(.spring(duration: 0.38, bounce: 0.25)) {
            board.make(m)
            ids[m.to.index] = ids[m.from.index]
            ids[m.from.index] = 0
            lastMove = m
            selected = nil
        }
        Sound.place(board[m.to]?.side == .red ? .black : .white)
        if board.inCheck(board.turn) { flash += 1; Sound.sparkle() }
    }

    private func playReply(_ spec: [String]) {
        flow.beginReply()
        let snapshot = board
        replyTask = Task {
            let moves = await Task.detached(priority: .userInitiated) {
                XiangqiLessonLogic.reply(spec, on: snapshot)
            }.value
            for m in moves {
                try? await Task.sleep(for: .milliseconds(1000))
                guard !Task.isCancelled else { return }
                play(m)
            }
            board.turn = .red
            try? await Task.sleep(for: .milliseconds(300))
            flow.endReply()
        }
    }

    func stop() {
        replyTask?.cancel()
        flow.stop()
    }
}

struct XiangqiLessonView: View {
    @State private var session: XiangqiLessonSession
    let onNextLesson: (TutorialLesson) -> Void

    init(course: TutorialCourse, lesson: TutorialLesson, mode: LessonMode = .lesson,
         onNextLesson: @escaping (TutorialLesson) -> Void) {
        _session = State(initialValue: XiangqiLessonSession(course: course, lesson: lesson, mode: mode))
        self.onNextLesson = onNextLesson
    }

    var body: some View {
        LessonScaffold(flow: session.flow, accent: Palette.honey, onNextLesson: onNextLesson) {
            XiangqiBoardView(state: session.state) { session.tap($0) }
                .aspectRatio(9.6 / 10.6, contentMode: .fit)
        }
        .onDisappear { session.stop() }
    }
}
