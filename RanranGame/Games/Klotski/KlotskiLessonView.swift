import SwiftUI
import Observation

/// 华容道的一课：木盘在左边（竖屏时在下面），老师在右边。
/// 题目怎么判都在 Logic/KlotskiLessonLogic.swift：滑木块的题每滑一步就判一次，点一点的题点一下判一次。
@Observable
@MainActor
final class KlotskiLessonSession {
    let flow: LessonFlow
    private(set) var board: KlotskiBoard
    /// 这道题开始时的盘面（做错了退回到这里，题目里的格子名也按它来认木块）
    private(set) var start: KlotskiBoard
    private(set) var looks: [KlotskiLook]
    /// 这道题已经走了的步
    private(set) var moves: [KlotskiMove] = []
    private(set) var exiting = false
    var nudge: (piece: Int, tick: Int)?
    private var resetTask: Task<Void, Never>?

    init(course: TutorialCourse, lesson: TutorialLesson, mode: LessonMode = .lesson) {
        flow = LessonFlow(course: course, lesson: lesson, mode: mode)
        let first = lesson.steps.first?.board.flatMap { KlotskiBoard(layout: $0) } ?? KlotskiBoard(layout: ".BB./.BB./..../..../....")!
        board = first
        start = first
        looks = KlotskiLooks.assign(first)
        flow.onStep = { [weak self] in self?.syncBoard() }
    }

    private var task: TutorialTask? { flow.task }
    var isSlide: Bool { task?.type == "slide" }
    var canPlay: Bool { flow.awaitingAnswer && isSlide }

    /// 进入新的一步：有新盘面就换上，没有就接着用现在的
    func syncBoard() {
        resetTask?.cancel()
        moves = []
        if let spec = flow.step.board, let b = KlotskiBoard(layout: spec) {
            exiting = false
            looks = KlotskiLooks.assign(b)
            withAnimation(.spring(duration: 0.4)) { board = b }
        }
        start = board
    }

    // MARK: 标记

    struct Marks {
        var glow: Set<Int> = []
        var arrows: [KlotskiArrow] = []
        var rings: Set<Int> = []
        var door = false
    }

    var marks: Marks {
        var m = Marks()
        let solved = flow.solved && flow.task != nil
        func resolve(_ token: String, on b: KlotskiBoard) {
            let p = token.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
            switch p.first {
            case "door":
                m.door = true
            case "glow":
                if p.count == 2, let c = KlotskiCellName.parse(p[1]), let i = b.pieceAt(x: c.x, y: c.y) { m.glow.insert(i) }
            case "ring":
                if p.count == 2, let c = KlotskiCellName.parse(p[1]) { m.rings.insert(c.y * KlotskiBoard.cols + c.x) }
            case "arrow":
                if p.count == 4, let c = KlotskiCellName.parse(p[1]), let i = b.pieceAt(x: c.x, y: c.y),
                   let d = p[2].first.flatMap(KlotskiDir.init(letter:)), let n = Int(p[3]) {
                    m.arrows.append(KlotskiArrow(piece: i, dir: d, dist: n))
                }
            default:
                break
            }
        }
        for t in flow.step.marks ?? [] {
            if solved && t != "door" { continue }
            // 箭头指的是起点的样子，走了一步以后就不画了
            if t.hasPrefix("arrow") && !moves.isEmpty { continue }
            resolve(t, on: start)
        }
        if flow.revealed, !solved, let task {
            for t in KlotskiLessonLogic.revealMarks(task, start: start, moves: moves) { resolve(t, on: board) }
        }
        return m
    }

    // MARK: 操作

    func move(_ m: KlotskiMove) {
        guard canPlay, let task, board.canApply(m) else { return }
        guard KlotskiLessonLogic.permits(task, start: start, move: m) else {
            nudge = (m.piece, (nudge?.tick ?? 0) + 1)
            flow.nudge(KlotskiLines.notThisBlock)
            return
        }
        withAnimation(.spring(duration: 0.28, bounce: 0.22)) { board = board.applying(m) }
        Sound.drop()
        moves.append(m)
        switch KlotskiLessonLogic.judge(task, start: start, moves: moves) {
        case .solved:
            if board.solved { exiting = true }
            flow.succeed()
        case .progress:
            break
        case .wrong:
            flow.fail()
            backToStart(after: 0.7)
        }
    }

    func tap(piece: Int?, x: Int, y: Int) {
        guard flow.awaitingAnswer, let task, task.type == "pick" else { return }
        // 点在空格上：只有"点格子"的题才算数，别的题不算错
        if piece == nil, KlotskiLessonLogic.parts(task).head != "cells" { return }
        if KlotskiLessonLogic.pickCheck(task, on: board, x: x, y: y) {
            flow.succeed()
        } else {
            flow.fail(TutorLines.wrongPick)
        }
    }

    func undo() {
        guard flow.awaitingAnswer, let task else { return }
        guard !moves.isEmpty else {
            if task.type == "slide" { flow.nudge(KlotskiLines.undoFirst) }
            return
        }
        let before = moves.dropLast().reduce(start) { $0.applying($1) }
        moves.removeLast()
        Sound.undo()
        withAnimation(.spring(duration: 0.3, bounce: 0.2)) { board = before }
        if KlotskiLessonLogic.parts(task).head == "undo" { flow.succeed() }
    }

    func restartStep() {
        guard flow.awaitingAnswer, !moves.isEmpty else { return }
        Sound.tap()
        backToStart(after: 0)
    }

    private func backToStart(after delay: Double) {
        resetTask?.cancel()
        resetTask = Task {
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled else { return }
            moves = []
            withAnimation(.spring(duration: 0.4, bounce: 0.2)) { board = start }
        }
    }

    func stop() {
        resetTask?.cancel()
        flow.stop()
    }
}

struct KlotskiLessonView: View {
    let course: TutorialCourse
    let lesson: TutorialLesson
    var mode: LessonMode = .lesson
    var onNextLesson: ((TutorialLesson) -> Void)? = nil

    @State private var session: KlotskiLessonSession

    init(course: TutorialCourse, lesson: TutorialLesson, mode: LessonMode = .lesson,
         onNextLesson: ((TutorialLesson) -> Void)? = nil) {
        self.course = course
        self.lesson = lesson
        self.mode = mode
        self.onNextLesson = onNextLesson
        _session = State(initialValue: KlotskiLessonSession(course: course, lesson: lesson, mode: mode))
    }

    var body: some View {
        LessonScaffold(flow: session.flow, accent: KlotskiPlayView.accent,
                       onNextLesson: { onNextLesson?($0) }) {
            VStack(spacing: 14) {
                boardView
                buttons
            }
        }
        .onDisappear { session.stop() }
    }

    private var boardView: some View {
        let m = session.marks
        return KlotskiBoardView(
            board: session.board,
            looks: session.looks,
            interactive: session.canPlay,
            glow: m.glow,
            arrows: m.arrows,
            rings: m.rings,
            doorGlow: m.door,
            exiting: session.exiting,
            nudge: session.nudge,
            onMove: { session.move($0) },
            onTap: { piece, x, y in session.tap(piece: piece, x: x, y: y) }
        )
    }

    private var buttons: some View {
        HStack(spacing: 14) {
            lessonButton("撤销", "arrow.uturn.backward", enabled: session.flow.awaitingAnswer && session.isSlide) { session.undo() }
            lessonButton("回到开头", "arrow.counterclockwise", enabled: session.flow.awaitingAnswer && !session.moves.isEmpty) {
                session.restartStep()
            }
        }
        .frame(height: 56)
    }

    private func lessonButton(_ title: String, _ icon: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button {
            Sound.tap()
            action()
        } label: {
            Label(title, systemImage: icon)
                .font(.kid(19, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 22)
                .frame(height: 52)
                .softCard(radius: 26)
        }
        .buttonStyle(PressableStyle(scale: 0.94))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}
