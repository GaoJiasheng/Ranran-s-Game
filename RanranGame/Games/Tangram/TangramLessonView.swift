import SwiftUI
import Observation

/// 七巧板教学的一课：猫头鹰老师在旁边讲，冉冉在板子上动手。
///   fill 题：把托盘里的板子全部放进影子正好盖满（任何正确的拼法都算对，由 TangramChecker 判断）
///   pick 题：点一下老师说的那种板子
/// 放错地方（露到影子外面、压在别的板子上）的板子会弹回托盘，老师提醒一句，不算做错；
/// 同一道题放错三次算做错一次（第一次给提示，第二次亮出答案，这是 LessonFlow 的规矩）。
@Observable
@MainActor
final class TangramLessonSession {
    let flow: LessonFlow
    let board = TangramBoard()
    private var misses = 0

    init(course: TutorialCourse, lesson: TutorialLesson, mode: LessonMode = .lesson) {
        flow = LessonFlow(course: course, lesson: lesson, mode: mode)
        board.onEvent = { [weak self] e in self?.handle(e) }
        board.onPick = { [weak self] k, id in self?.picked(k, id) }
        flow.onStep = { [weak self] in self?.enterStep() }
        enterStep()
    }

    private var lessonBoard = TangramLessonBoard()

    private func enterStep() {
        misses = 0
        let step = flow.step
        if let spec = step.board, let b = TangramLessonBoard(spec: spec) {
            lessonBoard = b
            board.load(target: b.target, fixed: b.fixed, tray: b.show ? [] : b.tray, outlines: b.lines, show: b.show)
        }
        board.reveal = []
        board.picked = nil
        board.pickMode = step.task?.type == "pick"
        syncInteractive()
    }

    /// 有题而且还没做对的时候才能动板子
    func syncInteractive() {
        board.interactive = flow.awaitingAnswer
        if flow.revealed, flow.task?.type == "fill", board.reveal.isEmpty, let ans = TangramLessonLogic.answer(lessonBoard) {
            withAnimation(.easeInOut(duration: 0.4)) { board.reveal = ans }
        }
        if flow.revealed, let k = TangramLessonLogic.pickKind(flow.task?.rule) { board.hintKind = k }
    }

    private func handle(_ e: TangramBoard.Event) {
        guard flow.task?.type == "fill", flow.awaitingAnswer else { return }
        switch e {
        case let .dropped(id, fits):
            if fits {
                if board.solved {
                    board.reveal = []
                    flow.succeed()
                    board.lock()
                }
                return
            }
            guard let pose = board.pieces.first(where: { $0.id == id })?.pose else { return }
            if !board.touchesTarget(pose) && !board.overlapsOthers(pose, id: id) {
                // 放在影子旁边的空地上：先搁着，不算放错
                return
            }
            let line: String
            if board.overlapsOthers(pose, id: id) {
                line = TangramTutorial.overlap
            } else if board.wouldFitTurned(id) {
                line = TangramTutorial.turnFirst
            } else {
                line = TangramTutorial.outside
            }
            board.sendBack(id)
            misses += 1
            if misses % 3 == 0 {
                flow.fail()
                syncInteractive()
            } else {
                flow.nudge(line)
            }
        case .turned, .flipped:
            if board.solved {
                board.reveal = []
                flow.succeed()
                board.lock()
            }
        case .returned:
            break
        }
    }

    private func picked(_ kind: TangramKind, _ id: Int) {
        guard flow.awaitingAnswer, flow.task?.type == "pick" else { return }
        if TangramLessonLogic.picked(kind, rule: flow.task?.rule) {
            withAnimation(.spring(duration: 0.3, bounce: 0.5)) { board.picked = id }
            board.hintKind = nil
            flow.succeed()
            board.lock()
        } else {
            flow.fail(TutorLines.wrongPick)
            syncInteractive()
        }
    }

    func stop() { flow.stop() }

    #if DEBUG
    func debugDemo(_ demo: String) {
        guard flow.task != nil else { return }
        switch demo {
        case "reveal":
            flow.fail()
            flow.fail()
        case "wrong":
            flow.fail()
        case "half":
            board.debugPlace(max(1, board.pieces.count / 2))
        default: break
        }
        syncInteractive()
    }
    #endif
}

struct TangramLessonView: View {
    let course: TutorialCourse
    let lesson: TutorialLesson
    var mode: LessonMode = .lesson
    var onNextLesson: ((TutorialLesson) -> Void)? = nil

    @State private var session: TangramLessonSession

    init(course: TutorialCourse, lesson: TutorialLesson, mode: LessonMode = .lesson,
         onNextLesson: ((TutorialLesson) -> Void)? = nil) {
        self.course = course
        self.lesson = lesson
        self.mode = mode
        self.onNextLesson = onNextLesson
        _session = State(initialValue: TangramLessonSession(course: course, lesson: lesson, mode: mode))
    }

    var body: some View {
        let flow = session.flow
        let board = session.board
        LessonScaffold(flow: flow, accent: TangramStyle.accent, onNextLesson: onNextLesson) {
            VStack(spacing: 10) {
                TangramStage(board: board)
                // 工具一直占着地方（不用的时候看不见），换题的时候板子不会跳
                let fill = flow.task?.type == "fill"
                HStack(spacing: 14) {
                    Spacer()
                    TangramToolButton(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill", title: "翻面",
                                      enabled: flow.awaitingAnswer, tint: TangramStyle.accent) { board.flip() }
                        .opacity(fill && board.hasMirrorPiece ? 1 : 0)
                        .allowsHitTesting(fill && board.hasMirrorPiece)
                    TangramToolButton(icon: "arrow.counterclockwise", title: "重来",
                                      enabled: flow.awaitingAnswer && board.pieces.contains(where: \.onBoard)) { board.reset() }
                        .opacity(fill ? 1 : 0)
                        .allowsHitTesting(fill)
                }
                .frame(height: 66)
            }
        }
        .onChange(of: flow.revealed) { _, _ in session.syncInteractive() }
        .onChange(of: flow.index) { _, _ in session.syncInteractive() }
        .onChange(of: flow.solved) { _, _ in session.syncInteractive() }
        .onChange(of: flow.busy) { _, _ in session.syncInteractive() }
        .onDisappear { session.stop() }
        #if DEBUG
        .task {
            // 调试截图用（和 -lesson <id> 一起用）：-tangramLessonDemo reveal（这一步的题做错两次，亮出答案）
            // / half（fill 题先摆好一半）/ wrong（做错一次，看提示）
            guard let demo = UserDefaults.standard.string(forKey: "tangramLessonDemo") else { return }
            try? await Task.sleep(for: .milliseconds(600))
            session.debugDemo(demo)
        }
        #endif
    }
}
