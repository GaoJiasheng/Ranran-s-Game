import SwiftUI
import Observation

/// 国际象棋的一课：冉冉执白在下面。没有题的时候也可以点自己的子，看看它能走到哪里。
@Observable
@MainActor
final class ChessLessonSession {
    let flow: LessonFlow
    private(set) var board = ChessBoard.start
    private(set) var ids = ChessPieceIDs.initial(.start)
    private(set) var selected: ChessSquare?
    private(set) var lastMove: ChessMove?
    private(set) var flash = 0
    /// 兵走到最后一排，等她选升变成什么
    private(set) var pendingPromotion: (from: ChessSquare, to: ChessSquare)?
    /// 错两次以后亮出来的答案（连杀题要算一会儿，所以算好了存起来）
    private(set) var revealedMove: ChessMove?
    private var revealedStep = -1
    private var replyTask: Task<Void, Never>?
    private var revealTask: Task<Void, Never>?

    init(course: TutorialCourse, lesson: TutorialLesson, mode: LessonMode = .lesson) {
        flow = LessonFlow(course: course, lesson: lesson, mode: mode)
        syncBoard()
        flow.onStep = { [weak self] in self?.syncBoard() }
    }

    /// 教学里每一步都轮到白方
    private var whiteToMove: ChessBoard { ChessLessonLogic.whiteToMove(board) }

    var state: ChessBoardState {
        var marks: [ChessMark] = (flow.step.marks ?? []).compactMap(ChessMark.init(spec:))
        // 只能动某一个子的题：那个子一直发光（提醒里说的"发光的那个子"），练习时也一样
        if flow.awaitingAnswer, let p = flow.task?.piece.flatMap(ChessSquare.init), selected != p, !marks.contains(.glow(p)) {
            marks.append(.glow(p))
        }
        if flow.revealed, let t = flow.task {
            if t.type == "pick" {
                marks += (t.accept ?? []).compactMap(ChessSquare.init).map { .glow($0) }
            } else if revealedStep == flow.index, let m = revealedMove {
                marks.append(.arrow(m.from, m.to))
                marks.append(.glow(m.to))
            }
        }
        let checked = board.inCheck(.white) ? board.king(.white) : (board.inCheck(.black) ? board.king(.black) : nil)
        return ChessBoardState(board: board, ids: ids, flipped: false, selected: selected,
                               targets: targets, lastMove: lastMove, checkedKing: checked,
                               hint: nil, marks: marks, checkFlash: flash)
    }

    private var targets: [ChessSquare] {
        guard let selected, !flow.busy, flow.task?.type != "pick", pendingPromotion == nil else { return [] }
        return Array(Set(whiteToMove.legalMoves(from: selected).map(\.to)))
    }

    func syncBoard() {
        selected = nil
        pendingPromotion = nil
        revealedMove = nil
        revealedStep = -1
        revealTask?.cancel()
        if let fen = flow.step.board, let b = ChessBoard(fen: fen) {
            withAnimation(.spring(duration: 0.4)) {
                board = b
                ids = ChessPieceIDs.initial(b)
                lastMove = nil
            }
        }
        board = whiteToMove
    }

    /// 答案亮出来之前先算好（连杀题在后台算）
    func prepareReveal() {
        guard flow.revealed, let t = flow.task, t.type == "move", revealedStep != flow.index else { return }
        let index = flow.index
        let b = whiteToMove
        revealedStep = index
        revealTask = Task {
            let m = await Task.detached(priority: .userInitiated) { ChessLessonLogic.answers(t, on: b).first }.value
            guard !Task.isCancelled, flow.index == index else { return }
            withAnimation(.spring(duration: 0.35)) { revealedMove = m }
        }
    }

    func tap(_ s: ChessSquare) {
        guard !flow.busy, !flow.finished, pendingPromotion == nil else { return }
        let task = flow.awaitingAnswer ? flow.task : nil

        if task?.type == "pick" {
            if ChessLessonLogic.checkPick(task!, s) { flow.succeed() } else { flow.fail(TutorLines.wrongPick) }
            return
        }

        let b = whiteToMove
        // 点自己的子：选中 / 换一个
        if let p = b[s], p.side == .white {
            if let piece = task?.piece, piece != s.name {
                flow.nudge(TutorLines.notThisPiece)
                return
            }
            withAnimation(.spring(duration: 0.25, bounce: 0.4)) { selected = selected == s ? nil : s }
            Sound.pick()
            return
        }
        guard let from = selected else { return }
        let legal = b.legalMoves(from: from).filter { $0.to == s }
        guard let first = legal.first else {
            // 不合规则：提醒一下，不算错
            if b.pseudoMoves(from: from).contains(where: { $0.to == s }) {
                flow.nudge(b[from]?.kind == .king ? ChessTutorLines.kingUnsafe : ChessTutorLines.exposesKing)
            } else {
                flow.nudge(TutorLines.illegal)
            }
            withAnimation(.spring(duration: 0.25)) { selected = nil }
            return
        }
        if legal.count > 1 {
            // 升变：先选升成什么（没有题的时候也让她选着玩）
            withAnimation(.spring(duration: 0.3)) { pendingPromotion = (from, s) }
            Sound.pick()
            return
        }
        attempt(first, task: task)
    }

    func choosePromotion(_ k: ChessKind) {
        guard let p = pendingPromotion else { return }
        withAnimation(.spring(duration: 0.25)) { pendingPromotion = nil }
        attempt(ChessMove(p.from, p.to, promotion: k), task: flow.awaitingAnswer ? flow.task : nil)
    }

    func cancelPromotion() {
        withAnimation(.spring(duration: 0.25)) { pendingPromotion = nil; selected = nil }
    }

    private func attempt(_ m: ChessMove, task: TutorialTask?) {
        let b = whiteToMove
        guard let task, task.type == "move" else {
            // 没有题的时候：只是看看能走哪里，不真的走
            withAnimation(.spring(duration: 0.25)) { selected = nil }
            return
        }
        if ChessLessonLogic.check(task, m, on: b) {
            play(m)
            flow.succeed()
            if let reply = flow.step.reply { playReply(reply) }
        } else if let c = ChessLessonLogic.consequence(task, m, on: b) {
            showConsequence(m, c)
        } else {
            withAnimation(.spring(duration: 0.25)) { selected = nil }
            flow.fail()
            prepareReveal()
        }
    }

    /// 走错了：真的走过去，黑方马上吃掉 / 黑王逃走 / 逼和，说一句，再退回去
    private func showConsequence(_ m: ChessMove, _ c: LessonConsequence<ChessMove>) {
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
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .milliseconds(350))
            flow.endConsequence()
            prepareReveal()
        }
    }

    private func play(_ m: ChessMove) {
        let before = board
        withAnimation(.spring(duration: 0.38, bounce: 0.25)) {
            var newIDs = ids
            ChessPieceIDs.apply(m, on: before, &newIDs)
            ids = newIDs
            board.make(m)
            lastMove = m
            selected = nil
        }
        Sound.place(before.isCapture(m) ? .white : .black)
        if board.inCheck { flash += 1; Sound.sparkle() }
    }

    private func playReply(_ spec: [String]) {
        flow.beginReply()
        let snapshot = board
        replyTask = Task {
            let moves = await Task.detached(priority: .userInitiated) {
                ChessLessonLogic.reply(spec, on: snapshot)
            }.value
            for m in moves {
                try? await Task.sleep(for: .milliseconds(1000))
                guard !Task.isCancelled else { return }
                play(m)
            }
            board = whiteToMove
            try? await Task.sleep(for: .milliseconds(300))
            flow.endReply()
        }
    }

    func stop() {
        replyTask?.cancel()
        revealTask?.cancel()
        flow.stop()
    }
}

struct ChessLessonView: View {
    @State private var session: ChessLessonSession
    let onNextLesson: ((TutorialLesson) -> Void)?

    init(course: TutorialCourse, lesson: TutorialLesson, mode: LessonMode = .lesson,
         onNextLesson: ((TutorialLesson) -> Void)? = nil) {
        _session = State(initialValue: ChessLessonSession(course: course, lesson: lesson, mode: mode))
        self.onNextLesson = onNextLesson
    }

    var body: some View {
        LessonScaffold(flow: session.flow, accent: ChessSurface.frame, onNextLesson: onNextLesson) {
            ChessBoardView(state: session.state) { session.tap($0) }
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if session.pendingPromotion != nil {
                        ChessPromotionPicker(side: .white, onPick: { session.choosePromotion($0) },
                                             onCancel: { session.cancelPromotion() })
                    }
                }
        }
        .onChange(of: session.flow.revealed) { _, shown in if shown { session.prepareReveal() } }
        .onDisappear { session.stop() }
    }
}
