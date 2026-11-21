import Foundation

// 华容道教学的判题。只用 Foundation。
//
// 格子的名字：列用 a b c d（从左到右），行用 1 2 3 4 5（从上到下），"b3" 是第 2 列第 3 行。
// 一步的方向用一个字母：u 上 d 下 l 左 r 右。
//
// 盘面（step.board）：KlotskiBoard 的盘面字符串；没写就接着上一步的盘面。
// 标记（step.marks）：
//   glow:b2           包着 b2 这一格的那块木块发光
//   arrow:b2:d:2      那块木块旁边画一个箭头，往下滑 2 格
//   ring:a5           在 a5 这个格子上画一圈（常用来标空格）
//   door              让出口亮一下
// 题目（task.type）：
//   slide  在盘面上滑木块。task.rule：
//     move:b2:d[:n]     把 b2 那块木块往下滑（n 格；不写 n 就是随便几格）。这一步别的木块不能动
//     far:b2:r          把 b2 那块木块往右滑到头（一直滑到被挡住）
//     at:b2:d4          想办法让 b2 那块木块盖住 d4 这一格（随便几步）
//     bunnyAt:b3        想办法让小兔盖住 b3 这一格
//     empty:b3,c3       想办法让这几个格子都空着
//     free:3            让小兔走到出口，最多 3 步（题目里说几步，就是最少几步）
//     undo              先随便滑一步，再点「撤销」
//     extra["limit"]    at / bunnyAt / empty 最多允许几步（默认 8），滑过头就重来
//   pick   点一下盘面回答问题。task.rule：
//     kind:big|tall|wide|small   点一块这种形状的木块
//     blocker                    点一块挡在小兔去出口的路上的木块
//     movable / stuck            点一块现在能动 / 动不了的木块
//     cells                      点 task.accept 里列出的格子（点到哪块木块都算，只看点的格子）

enum KlotskiLessonLogic {
    enum Verdict: Equatable {
        /// 做对了
        case solved
        /// 走的没错，还没做完
        case progress
        /// 走错了（要重来）
        case wrong
    }

    // MARK: 规则

    static func parts(_ t: TutorialTask) -> (head: String, args: [String]) {
        let p = (t.rule ?? "").split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        return (p.first ?? "", Array(p.dropFirst()))
    }

    /// 起始盘面上 cell 那一格属于哪块木块
    static func piece(_ cell: String, in board: KlotskiBoard) -> Int? {
        KlotskiCellName.parse(cell).flatMap { board.pieceAt(x: $0.x, y: $0.y) }
    }

    /// 最多允许走几步（走到这么多步还没做对就算错，重来）
    static func moveLimit(_ t: TutorialTask) -> Int {
        let p = parts(t)
        switch p.head {
        case "move", "far": return 1
        case "free": return Int(p.args.first ?? "") ?? 6
        default: return Int(t.extra?["limit"] ?? "") ?? 8
        }
    }

    /// 这一步该不该让她走：要求动某一块木块的题，动了别的就不让走（只提醒，不算错）
    static func permits(_ t: TutorialTask, start: KlotskiBoard, move: KlotskiMove) -> Bool {
        let p = parts(t)
        switch p.head {
        case "move", "far":
            guard let cell = p.args.first, let target = piece(cell, in: start) else { return true }
            return move.piece == target
        default:
            return true
        }
    }

    /// 到 board 这个局面（从 start 走了 moves.count 步）时做对没有
    static func judge(_ t: TutorialTask, start: KlotskiBoard, moves: [KlotskiMove]) -> Verdict {
        let board = moves.reduce(start) { $0.applying($1) }
        let p = parts(t)
        let limit = moveLimit(t)
        switch p.head {
        case "move":
            guard let m = moves.last, p.args.count >= 2, let dir = p.args[1].first.flatMap(KlotskiDir.init(letter:)) else { return .wrong }
            let n = p.args.count > 2 ? Int(p.args[2]) : nil
            return m.dir == dir && (n == nil || m.dist == n) ? .solved : .wrong
        case "far":
            guard let m = moves.last, p.args.count >= 2, let dir = p.args[1].first.flatMap(KlotskiDir.init(letter:)) else { return .wrong }
            let before = moves.dropLast().reduce(start) { $0.applying($1) }
            return m.dir == dir && m.dist == before.maxSlide(m.piece, dir) ? .solved : .wrong
        case "undo":
            return .progress
        default:
            if satisfied(t, start: start, board: board) { return .solved }
            return moves.count >= limit ? .wrong : .progress
        }
    }

    /// 这个局面算不算做到了（at / bunnyAt / empty / free）
    static func satisfied(_ t: TutorialTask, start: KlotskiBoard, board: KlotskiBoard) -> Bool {
        let p = parts(t)
        switch p.head {
        case "at":
            guard p.args.count >= 2, let i = piece(p.args[0], in: start), let c = KlotskiCellName.parse(p.args[1]) else { return false }
            return board.pieceAt(x: c.x, y: c.y) == i
        case "bunnyAt":
            guard let c = p.args.first.flatMap(KlotskiCellName.parse), let b = board.bunny else { return false }
            return board.pieceAt(x: c.x, y: c.y) == b
        case "empty":
            guard let list = p.args.first else { return false }
            let cells = list.split(separator: ",").compactMap { KlotskiCellName.parse(String($0)) }
            return !cells.isEmpty && cells.allSatisfy { board.isEmpty(x: $0.x, y: $0.y) }
        case "free":
            return board.solved
        default:
            return false
        }
    }

    // MARK: 答案

    /// 从现在这个局面（start 走了 moves）起，做对这道题还要走哪几步（最短的）；做不到是 nil。
    static func answer(_ t: TutorialTask, start: KlotskiBoard, moves: [KlotskiMove]) -> [KlotskiMove]? {
        let p = parts(t)
        let board = moves.reduce(start) { $0.applying($1) }
        let left = moveLimit(t) - moves.count
        guard left >= 1 else { return nil }
        switch p.head {
        case "move":
            guard moves.isEmpty, let cell = p.args.first, let i = piece(cell, in: start), p.args.count >= 2,
                  let dir = p.args[1].first.flatMap(KlotskiDir.init(letter:)) else { return nil }
            let n = p.args.count > 2 ? (Int(p.args[2]) ?? 1) : 1
            let m = KlotskiMove(piece: i, dir: dir, dist: n)
            return start.canApply(m) ? [m] : nil
        case "far":
            guard moves.isEmpty, let cell = p.args.first, let i = piece(cell, in: start), p.args.count >= 2,
                  let dir = p.args[1].first.flatMap(KlotskiDir.init(letter:)) else { return nil }
            let n = start.maxSlide(i, dir)
            return n > 0 ? [KlotskiMove(piece: i, dir: dir, dist: n)] : nil
        case "free":
            guard let path = KlotskiSolver.solve(board), path.count <= left else { return nil }
            return path
        case "undo":
            return moves.isEmpty ? board.allMoves.first.map { [$0] } : []
        default:
            // 一层一层往外找（盘面里每块木块的序号不变，所以不能把形状一样的木块当成同一个）
            if satisfied(t, start: start, board: board) { return [] }
            var parent: [[KlotskiPiece]: (prev: [KlotskiPiece], move: KlotskiMove)?] = [board.pieces: nil]
            var frontier = [board]
            var depth = 0
            while !frontier.isEmpty, depth < left {
                depth += 1
                var next: [KlotskiBoard] = []
                for b in frontier {
                    for m in b.allMoves {
                        let nb = b.applying(m)
                        if parent[nb.pieces] != nil { continue }
                        parent[nb.pieces] = (b.pieces, m)
                        if satisfied(t, start: start, board: nb) {
                            var out: [KlotskiMove] = []
                            var cur = nb.pieces
                            while let entry = parent[cur], let e = entry { out.append(e.move); cur = e.prev }
                            return out.reversed()
                        }
                        next.append(nb)
                    }
                }
                frontier = next
            }
            return nil
        }
    }

    // MARK: 点一点的题

    /// 点这些格子算对（格子编号 y*4+x）
    static func pickCells(_ t: TutorialTask, on board: KlotskiBoard) -> Set<Int> {
        let p = parts(t)
        func cells(of pieces: [Int]) -> Set<Int> {
            var s = Set<Int>()
            for i in pieces {
                let q = board.pieces[i]
                for dy in 0..<q.kind.h { for dx in 0..<q.kind.w { s.insert((q.y + dy) * KlotskiBoard.cols + q.x + dx) } }
            }
            return s
        }
        switch p.head {
        case "kind":
            guard let name = p.args.first, let k = name.first.flatMap(kindLetter) else { return [] }
            return cells(of: board.pieces.indices.filter { board.pieces[$0].kind == k })
        case "blocker":
            // 小兔直直往下走要经过的格子：它下面的两列
            guard let b = board.bunny else { return [] }
            let bp = board.pieces[b]
            let blockers = board.pieces.indices.filter { i in
                let q = board.pieces[i]
                return i != b && q.x < bp.x + 2 && q.x + q.kind.w > bp.x && q.y + q.kind.h > bp.y + 2
            }
            return cells(of: blockers)
        case "movable":
            return cells(of: board.pieces.indices.filter { !board.moves(of: $0).isEmpty })
        case "stuck":
            return cells(of: board.pieces.indices.filter { board.moves(of: $0).isEmpty })
        case "cells":
            return Set((t.accept ?? []).compactMap(KlotskiCellName.parse).map { $0.y * KlotskiBoard.cols + $0.x })
        default:
            return []
        }
    }

    static func kindLetter(_ c: Character) -> KlotskiKind? {
        switch c {
        case "b": .big
        case "t": .tall
        case "w": .wide
        case "s": .small
        default: nil
        }
    }

    static func pickCheck(_ t: TutorialTask, on board: KlotskiBoard, x: Int, y: Int) -> Bool {
        pickCells(t, on: board).contains(y * KlotskiBoard.cols + x)
    }

    // MARK: 答案的标记

    /// 错了两次，把答案亮出来：点一点的题让对的木块 / 格子发光；滑的题标出下一步（发光 + 箭头）
    static func revealMarks(_ t: TutorialTask, start: KlotskiBoard, moves: [KlotskiMove]) -> [String] {
        let board = moves.reduce(start) { $0.applying($1) }
        if t.type == "pick" {
            var out: [String] = []
            for i in pickCells(t, on: board).sorted() {
                let x = i % KlotskiBoard.cols, y = i / KlotskiBoard.cols
                out.append(parts(t).head == "cells" ? "ring:\(KlotskiCellName.name(x, y))" : "glow:\(KlotskiCellName.name(x, y))")
            }
            return out
        }
        guard let m = answer(t, start: start, moves: moves)?.first else { return [] }
        let q = board.pieces[m.piece]
        let cell = KlotskiCellName.name(q.x, q.y)
        return ["glow:\(cell)", "arrow:\(cell):\(m.dir.letter):\(m.dist)"]
    }
}

// MARK: - 左右镜像（练一练 / 复习用）

/// 把一段题左右翻过来：盘面、标记、答案里所有写着位置、写着左右的地方一起变。出口在正中间，所以翻过来规则一模一样。
enum KlotskiMirror {
    static func layout(_ s: String) -> String {
        s.split(separator: "/", omittingEmptySubsequences: false).map { String($0.reversed()) }.joined(separator: "/")
    }

    static func cell(_ s: String) -> String { KlotskiCellName.mirror(s) ?? s }

    static func cellList(_ s: String) -> String { s.split(separator: ",").map { cell(String($0)) }.joined(separator: ",") }

    static func dir(_ s: String) -> String {
        s == "l" ? "r" : s == "r" ? "l" : s
    }

    /// "arrow:b2:l:1" → "arrow:c2:r:1"
    static func mark(_ s: String) -> String {
        let p = s.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        switch p.first {
        case "glow", "ring": return p.count == 2 ? "\(p[0]):\(cell(p[1]))" : s
        case "arrow": return p.count == 4 ? "arrow:\(cell(p[1])):\(dir(p[2])):\(p[3])" : s
        default: return s
        }
    }

    /// 题的规则。at / bunnyAt 的目标是"盖住这一格"，镜像以后还是盖住对应的那一格
    static func rule(_ s: String) -> String {
        let p = s.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        switch p.first {
        case "move", "far":
            guard p.count >= 3 else { return s }
            return ([p[0], cell(p[1]), dir(p[2])] + p.dropFirst(3)).joined(separator: ":")
        case "at":
            guard p.count == 3 else { return s }
            return "at:\(cell(p[1])):\(cell(p[2]))"
        case "bunnyAt":
            return p.count == 2 ? "bunnyAt:\(cell(p[1]))" : s
        case "empty":
            return p.count == 2 ? "empty:\(cellList(p[1]))" : s
        default:
            return s
        }
    }

    static func step(_ s: TutorialStep) -> TutorialStep {
        var t = s
        t.board = s.board.map(layout)
        t.marks = s.marks?.map(mark)
        if var task = s.task {
            task.rule = task.rule.map(rule)
            task.accept = task.accept?.map(cell)
            t.task = task
        }
        return t
    }

    /// 一段题的第 k 种样子：0 原样，1 左右镜像
    static func steps(_ steps: [TutorialStep], _ k: Int) -> [TutorialStep] {
        k == 0 ? steps : steps.map(step)
    }
}
