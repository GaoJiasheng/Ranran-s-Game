import SwiftUI
import Observation

/// 围棋的一课：冉冉执黑。点出所有的气、提子、叫吃、征子……白棋按课程里写好的方式应。
@Observable
@MainActor
final class GoLessonSession {
    let flow: LessonFlow
    private(set) var board = GoBoard(size: 9)
    private(set) var last: Int?
    private(set) var miss: Int?
    /// pickAll 题已经找到的点
    private(set) var found: Set<Int> = []
    private var loops = 0
    private var replyTask: Task<Void, Never>?

    init(course: TutorialCourse, lesson: TutorialLesson) {
        flow = LessonFlow(course: course, lesson: lesson)
        syncBoard()
        flow.onStep = { [weak self] in self?.syncBoard() }
    }

    var state: GoBoardState {
        var marks = (flow.step.marks ?? []).compactMap { GoMark.parse($0, board) }
        marks += found.map { .dot($0) }
        if flow.revealed, let t = flow.task {
            let ans = GoLessonLogic.answers(t, on: board).filter { !found.contains($0) }
            marks += ans.prefix(t.type == "pickAll" ? 10 : 2).map { .glow($0) }
        }
        return GoBoardState(board: board, lastMove: last, marks: marks, miss: miss)
    }

    func syncBoard() {
        found = []
        loops = 0
        if let spec = flow.step.board, let b = GoBoard(spec: spec) {
            withAnimation(.spring(duration: 0.4)) {
                board = b
                last = nil
            }
        }
        board.turn = .black
    }

    func tap(_ i: Int) {
        guard flow.awaitingAnswer, let task = flow.task else { return }
        switch task.type {
        case "pickAll":
            let all = Set((task.accept ?? []).compactMap { board.index($0) })
            guard !found.contains(i) else { return }
            if all.contains(i) {
                withAnimation(.spring(duration: 0.3, bounce: 0.5)) { _ = found.insert(i) }
                let left = all.subtracting(found).count
                if left == 0 { flow.succeed() } else { flow.found(left) }
            } else {
                flash(i)
                flow.fail()
            }
        case "pick":
            if GoLessonLogic.check(task, i, on: board) { flow.succeed() } else { flash(i); flow.fail(TutorLines.wrongPick) }
        default:
            guard board.cells[i] == 0 else { return }
            guard board.isLegal(i) else {
                flow.nudge(i == board.ko ? TutorLines.goKo : TutorLines.goNoLiberty)
                return
            }
            if GoLessonLogic.check(task, i, on: board) {
                play(i)
                flow.succeed()
                playReply(flow.step.reply ?? [])
            } else {
                flash(i)
                flow.fail()
            }
        }
    }

    private func play(_ i: Int) {
        let color = board.turn
        var captured: [Int] = []
        withAnimation(.spring(duration: 0.32, bounce: 0.3)) {
            captured = board.play(i) ?? []
            last = i
        }
        Sound.place(color == .black ? .black : .white)
        if !captured.isEmpty { Sound.pop() }
    }

    private func flash(_ i: Int) {
        withAnimation(.spring(duration: 0.2)) { miss = i }
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.easeOut(duration: 0.25)) { if self.miss == i { self.miss = nil } }
        }
    }

    private func playReply(_ spec: [String]) {
        let step = flow.step
        // 没有对手应着、也不用循环：直接下一步
        if spec.isEmpty && step.loop == nil { board.turn = .black; return }
        flow.beginReply()
        replyTask = Task {
            let moves = GoLessonLogic.reply(spec, on: board)
            for m in moves {
                try? await Task.sleep(for: .milliseconds(1000))
                guard !Task.isCancelled else { return }
                if let m { play(m) } else { board.pass() }
            }
            if moves.count < spec.count { board.turn = .black } // 白棋没地方逃：停一手
            board.turn = .black
            try? await Task.sleep(for: .milliseconds(250))
            // 征子 / 枷：还没吃掉就同一步再来；最多 30 次以防万一
            if let lp = step.loop, let li = board.index(lp), board[li] == .white, loops < 30 {
                loops += 1
                flow.rearm(step.after ?? step.say)
            } else {
                // 循环的一步吃掉了：不再说"它又逃了"
                flow.endReply(speakAfter: step.loop == nil)
            }
        }
    }

    func stop() {
        replyTask?.cancel()
        flow.stop()
    }
}

struct GoLessonView: View {
    @State private var session: GoLessonSession
    let onNextLesson: (TutorialLesson) -> Void

    init(course: TutorialCourse, lesson: TutorialLesson, onNextLesson: @escaping (TutorialLesson) -> Void) {
        _session = State(initialValue: GoLessonSession(course: course, lesson: lesson))
        self.onNextLesson = onNextLesson
    }

    var body: some View {
        LessonScaffold(flow: session.flow, accent: Palette.sage, onNextLesson: onNextLesson) {
            GoBoardView(state: session.state) { session.tap($0) }
        }
        .onDisappear { session.stop() }
    }
}
