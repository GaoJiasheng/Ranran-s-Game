import SwiftUI
import Observation

/// 一关数独正在玩的状态：她填了什么、小笔记、填错几次、用了几次提示、撤销记录。
/// 填到一半离开，下次回来接着填（存在 UserDefaults 的 sudoku.progress.<关> 里；过关或者重来时删掉）。
@Observable
@MainActor
final class SudokuGame {
    /// 提示讲到哪了
    enum Hint: Equatable {
        /// 有填错的格子，先让她擦掉
        case wrong(Set<Int>)
        /// 讲了道理，还没给答案（再按一下才填上）
        case explain(SudokuMove)
    }

    let level: SudokuLevel
    private(set) var cells: [Int]
    /// 小笔记：每格一个位掩码（第 v 位 = 记了 v）
    private(set) var notes: [Int]
    var selected: Int?
    /// 先选数字再点格子："一直用这个数"
    var sticky: Int?
    var notesMode = false
    private(set) var mistakes = 0
    private(set) var hintsUsed = 0
    private(set) var hint: Hint?
    private(set) var wobble: [Int: Int] = [:]
    private(set) var flash: Set<Int> = []
    private(set) var solved = false
    /// 气泡里的字（只显示；提示的那几句另外有配音）
    private(set) var message: String

    private struct Snapshot { var cells: [Int]; var notes: [Int] }
    private var history: [Snapshot] = []

    private struct Saved: Codable {
        var cells: [Int]
        var notes: [Int]
        var mistakes: Int
        var hints: Int
    }

    static func progressKey(_ id: String) -> String { "sudoku.progress.\(id)" }

    init(level: SudokuLevel) {
        self.level = level
        cells = level.puzzle.cells
        notes = Array(repeating: 0, count: level.puzzle.count)
        message = ""
        if let data = UserDefaults.standard.data(forKey: Self.progressKey(level.id)),
           let s = try? JSONDecoder().decode(Saved.self, from: data),
           s.cells.count == cells.count, s.notes.count == cells.count,
           zip(level.puzzle.cells, s.cells).allSatisfy({ $0 == 0 || $0 == $1 }) {
            cells = s.cells
            notes = s.notes
            mistakes = s.mistakes
            hintsUsed = s.hints
        }
        message = idleMessage
    }

    var n: Int { level.puzzle.n }
    var fruit: Bool { level.puzzle.fruit }
    var canNote: Bool { n >= 6 }

    var grid: SudokuGrid {
        var g = level.puzzle
        g.cells = cells
        return g
    }

    func isGiven(_ i: Int) -> Bool { level.puzzle[i] != 0 }

    /// 她填错的格子
    var wrongCells: Set<Int> {
        Set((0..<cells.count).filter { cells[$0] != 0 && cells[$0] != level.solution[$0] })
    }

    /// 已经全部填对的数（按钮变淡）
    var finishedValues: Set<Int> {
        Set((1...n).filter { v in (0..<cells.count).filter { cells[$0] == v && level.solution[$0] == v }.count == n })
    }

    var hasProgress: Bool { cells != level.puzzle.cells || notes.contains { $0 != 0 } }
    var canUndo: Bool { !history.isEmpty }

    private var idleMessage: String {
        fruit ? "先点一个空格子，再点一种水果。" : "先点一个空格子，再点一个数字。"
    }

    // MARK: 点格子、点数字

    func tapCell(_ i: Int) {
        guard !solved else { return }
        if let v = sticky {
            if isGiven(i) || (cells[i] != 0 && cells[i] == level.solution[i]) {
                // 点到填好的格子：换成用这个数
                sticky = cells[i]
                selected = nil
                Sound.tap()
            } else if notesMode, canNote {
                toggleNote(v, at: i)
            } else {
                place(v, at: i)
            }
            return
        }
        Sound.tap()
        withAnimation(.spring(duration: 0.25)) { selected = selected == i ? nil : i }
        if notesMode { message = "笔记：点数字，把能填的小小地记在格子里。" } else if selected != nil { message = idleMessage }
    }

    func tapValue(_ v: Int) {
        guard !solved else { return }
        Sound.key()
        if let s = selected, !isGiven(s), sticky == nil {
            if notesMode, canNote { toggleNote(v, at: s) } else { place(v, at: s) }
            return
        }
        // 没选空格子：这个数"一直用"，再点格子就填
        withAnimation(.spring(duration: 0.25)) {
            sticky = sticky == v ? nil : v
            selected = nil
        }
        if let s = sticky {
            message = fruit ? "现在点空格子，就会放上\(SudokuStyle.name(s, fruit: true))。再点一次按钮就停下。"
                            : "现在点空格子，就会填上 \(s)。再点一次按钮就停下。"
        } else {
            message = idleMessage
        }
    }

    func place(_ v: Int, at i: Int) {
        guard !isGiven(i), cells[i] != v else { return }
        push()
        cells[i] = v
        notes[i] = 0
        selected = i
        if case .explain(let m)? = hint, m.cell == i { hint = nil }
        if v != level.solution[i] {
            mistakes += 1
            wobble[i, default: 0] += 1
            Sound.oops()
            let clash = grid.peers(i).contains { cells[$0] == v }
            message = clash ? "红色的格子和虚线圈着的格子重复了，换一个试试。" : "红色的这个不对哦，可以擦掉再想一想。"
        } else {
            Sound.pop()
            // 同行同列同宫的小笔记里，把这个数划掉
            for j in grid.peers(i) { notes[j] &= ~(1 << v) }
            if case .wrong(let ws)? = hint, wrongCells.isEmpty || !ws.isSubset(of: wrongCells) { hint = nil }
            celebrate(i)
            message = ["对啦！", "真棒！", "就是这样！"].randomElement()!
            if cells == level.solution.cells {
                solved = true
                selected = nil
                sticky = nil
                hint = nil
                UserDefaults.standard.removeObject(forKey: Self.progressKey(level.id))
                return
            }
        }
        save()
    }

    private func celebrate(_ i: Int) {
        let g = grid
        var done = Set<Int>()
        for u in g.units(of: i) {
            let cs = g.cells(u)
            if cs.allSatisfy({ cells[$0] == level.solution[$0] }) { done.formUnion(cs) }
        }
        guard !done.isEmpty else { return }
        Sound.sparkle()
        withAnimation(.easeOut(duration: 0.2)) { flash = done }
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.easeOut(duration: 0.4)) { self.flash = [] }
        }
    }

    private func toggleNote(_ v: Int, at i: Int) {
        guard !isGiven(i), cells[i] == 0 || cells[i] != level.solution[i] else { return }
        push()
        if cells[i] != 0 { cells[i] = 0 }
        notes[i] ^= 1 << v
        selected = i
        save()
    }

    func notesAt(_ i: Int) -> Set<Int> { Set((1...n).filter { notes[i] & (1 << $0) != 0 }) }

    // MARK: 擦掉、撤销、重来、笔记

    func erase() {
        guard let i = selected, !isGiven(i) else {
            message = "先点一个自己填的格子，再擦掉它。"
            Sound.nope()
            return
        }
        guard cells[i] != 0 || notes[i] != 0 else { return }
        push()
        if cells[i] != 0 { cells[i] = 0 } else { notes[i] = 0 }
        if case .wrong? = hint, wrongCells.isEmpty { hint = nil }
        Sound.undo()
        message = idleMessage
        save()
    }

    func undo() {
        guard let s = history.popLast() else { return }
        Sound.undo()
        withAnimation(.spring(duration: 0.25)) {
            cells = s.cells
            notes = s.notes
        }
        hint = nil
        message = idleMessage
        save()
    }

    func restart() {
        Sound.undo()
        withAnimation(.spring(duration: 0.35)) {
            cells = level.puzzle.cells
            notes = Array(repeating: 0, count: cells.count)
        }
        history = []
        mistakes = 0
        hintsUsed = 0
        hint = nil
        selected = nil
        sticky = nil
        notesMode = false
        solved = false
        message = idleMessage
        UserDefaults.standard.removeObject(forKey: Self.progressKey(level.id))
    }

    func toggleNotes() {
        guard canNote else { return }
        notesMode.toggle()
        message = notesMode ? "笔记：点数字，把能填的小小地记在格子里。" : idleMessage
    }

    // MARK: 提示

    /// 第一下：挑最简单的一步，圈出来讲道理；第二下：把答案填上
    func askHint() {
        guard !solved else { return }
        Sound.hint()
        switch hint {
        case .explain(let m)?:
            hint = nil
            place(level.solution[m.cell], at: m.cell)
            speak(SudokuLines.reveal)
            return
        case .wrong?:
            speak(SudokuLines.fixWrong)
            return
        case nil:
            break
        }
        let wrong = wrongCells
        if !wrong.isEmpty {
            hint = .wrong(wrong)
            selected = wrong.min()
            sticky = nil
            speak(SudokuLines.fixWrong)
            return
        }
        // 只用这一组教过的几招；万一找不到（不会发生），用三招都试
        let g = grid
        guard let m = SudokuSolver.easiest(g, allowed: level.pack.allowed) ?? SudokuSolver.easiest(g) else { return }
        hintsUsed += 1
        sticky = nil
        notesMode = false
        withAnimation(.spring(duration: 0.3)) {
            hint = .explain(m)
            selected = m.cell
        }
        speak(SudokuLines.hint(for: m))
        save()
    }

    private func speak(_ line: String) {
        message = line
        VoiceOver.shared.say(line)
    }

    // MARK: 画出来

    var look: SudokuBoardLook {
        let g = grid
        let wrong = wrongCells
        var l = SudokuBoardLook(grid: g, given: Set((0..<g.count).filter(isGiven)))
        l.wrong = wrong
        for w in wrong { for j in g.peers(w) where cells[j] == cells[w] { l.clash.insert(j) } }
        for i in 0..<g.count where notes[i] != 0 && cells[i] == 0 { l.notes[i] = notesAt(i) }
        l.selected = selected
        l.flash = flash
        l.wobble = wobble
        if let s = selected {
            l.softUnits = g.units(of: s)
            if cells[s] != 0 { l.sameValue = cells[s] }
        }
        if let v = sticky { l.sameValue = v }
        switch hint {
        case .explain(let m)?:
            let e = SudokuLessonLogic.explain(m, g)
            l.focusUnits = e.units
            l.crossed = Set(e.crossed)
            l.peers = Set(e.peers)
            if let v = e.value { l.sameValue = v }
            l.glow = [m.cell]
            l.question = [m.cell]
            l.softUnits = []
        case .wrong(let ws)?:
            l.glow = ws
        case nil:
            break
        }
        return l
    }

    /// 按钮上亮哪一个
    var padHighlight: Int? {
        if let v = sticky { return v }
        if let s = selected, cells[s] != 0 { return cells[s] }
        return nil
    }

    // MARK: 存档

    private func push() {
        history.append(Snapshot(cells: cells, notes: notes))
        if history.count > 200 { history.removeFirst() }
    }

    private func save() {
        guard !solved else { return }
        let s = Saved(cells: cells, notes: notes, mistakes: mistakes, hints: hintsUsed)
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: Self.progressKey(level.id))
        }
    }

    // MARK: 调试截图

    #if DEBUG
    /// -sudokuDemo solved：除了一格都填好，再把最后一格填上（记 1 次填错）
    func debugSolve() {
        mistakes = 1
        for i in 0..<cells.count where cells[i] == 0 { cells[i] = level.solution[i] }
        solved = true
        UserDefaults.standard.removeObject(forKey: Self.progressKey(level.id))
    }

    /// -sudokuDemo mistake：先填对几格，再在一个空格里填一个和别人重复的数
    func debugMistake() {
        let blanks = (0..<cells.count).filter { cells[$0] == 0 }
        for i in blanks.prefix(2) { place(level.solution[i], at: i) }
        let g = grid
        for i in (0..<cells.count) where cells[i] == 0 {
            if let v = g.peers(i).map({ cells[$0] }).first(where: { $0 != 0 && $0 != level.solution[i] }) {
                place(v, at: i)
                return
            }
        }
    }

    /// -sudokuDemo notes：打开笔记，把前几个空格能填的都记上
    func debugNotes() {
        guard canNote else { return }
        notesMode = true
        let g = grid
        for i in (0..<cells.count).filter({ cells[$0] == 0 }).prefix(12) {
            for v in g.candidates(i) { notes[i] |= 1 << v }
        }
        selected = (0..<cells.count).first { cells[$0] == 0 }
        message = "笔记：点数字，把能填的小小地记在格子里。"
    }
    #endif
}
