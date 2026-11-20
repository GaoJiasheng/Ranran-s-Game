import Foundation

// 走错了，先让她看看会发生什么：把她的棋下上去，对手马上"教训"一手，老师说一句，然后退回去再试。
// 只在规则能说清楚"错在哪"的题上做（堵、吃、逃、将死……）；这一步还是算错一次。
// 这里只算对手怎么应，界面在各个游戏的教学页里。

/// 走错以后对手的应着和老师的一句话
struct LessonConsequence<Move> {
    let moves: [Move]
    let line: String
}

extension GomokuLessonLogic {
    /// 黑棋下在 p（规则上不对）以后：白棋连成五颗，或者做出活四
    static func consequence(_ task: TutorialTask, _ p: Point, on b: GLessonBoard) -> LessonConsequence<Point>? {
        guard task.type == "place", task.accept == nil, let rule = task.rule,
              ["block", "stopOpenFour", "five"].contains(rule), b[p] == nil,
              !check(task, p, on: b) else { return nil }
        let after = b.placing(p, .black)
        guard after.line(at: p) == nil else { return nil }
        if let w = after.winningPoints(.white).first {
            return LessonConsequence(moves: [w], line: TutorLines.gomokuWhiteFive)
        }
        if rule == "stopOpenFour",
           let q = after.empties.first(where: { after.placing($0, .white).winningPoints(.white).count >= 2 }) {
            return LessonConsequence(moves: [q], line: TutorLines.gomokuWhiteOpenFour)
        }
        return nil
    }
}

extension GoLessonLogic {
    /// 黑棋下在 m（合法，但规则上不对）以后：要吃的白棋长出来逃掉，或者要逃的黑子被白棋提掉。
    /// 返回的着法都是白棋的。
    static func consequence(_ task: TutorialTask, _ m: Int, on b: GoBoard) -> LessonConsequence<Int>? {
        guard task.type == "place", task.accept == nil, let rule = task.rule,
              b.isLegal(m), let after = b.playing(m), !check(task, m, on: b) else { return nil }
        let parts = rule.split(separator: ":").map(String.init)
        let arg = parts.count > 1 ? b.index(parts[1]) : nil

        switch parts[0] {
        case "escape":
            guard let p = arg, after[p] == .black else { return nil }
            let r = reply(["capture:\(b.name(p))"], on: after).compactMap { $0 }
            var c = after
            for mv in r { c.play(mv) }
            guard !r.isEmpty, c[p] != .black else { return nil }
            return LessonConsequence(moves: r, line: TutorLines.goBlackCaptured)

        case "kill", "chase", "net", "netChase", "capture", "atari", "doubleAtari":
            let target: Int?
            if ["kill", "chase", "net", "netChase"].contains(parts[0]) {
                target = arg.flatMap { after[$0] == .white ? $0 : nil }
            } else {
                // 没写是哪一块：挑气最少的那块白棋（最多两口气），一样少就挑大的
                var seen = Set<Int>(), best: (i: Int, libs: Int, size: Int)?
                for i in after.cells.indices where after.cells[i] == GoStone.white.rawValue && !seen.contains(i) {
                    let g = after.group(i)
                    seen.formUnion(g.stones)
                    let libs = g.liberties.count
                    guard libs <= 2 else { continue }
                    if best == nil || libs < best!.libs || (libs == best!.libs && g.stones.count > best!.size) {
                        best = (i, libs, g.stones.count)
                    }
                }
                target = best?.i
            }
            guard let t = target else { return nil }
            let r = reply(["extend:\(after.name(t))"], on: after).compactMap { $0 }
            var c = after
            for mv in r { c.play(mv) }
            guard !r.isEmpty, c[t] == .white, c.libertyCount(t, limit: 3) >= 2 else { return nil }
            return LessonConsequence(moves: r, line: TutorLines.goWhiteEscaped)

        default:
            return nil
        }
    }
}

extension XiangqiLessonLogic {
    /// 红方走 m（合法，但规则上不对）以后：黑方把子吃掉，或者黑将逃走
    static func consequence(_ task: TutorialTask, _ m: XMove, on b: XBoard) -> LessonConsequence<XMove>? {
        guard task.type == "move", task.accept == nil, let rule = task.rule,
              b.legalMoves(from: m.from).contains(m), !check(task, m, on: b) else { return nil }
        let after = b.applying(m)
        let replies = after.legalMoves()
        guard !replies.isEmpty else { return nil }

        switch rule {
        case "safe", "bestCapture":
            // 走过去的子被吃；它没事的话，黑方吃掉最值钱的那个
            let caps = replies.filter { after[$0.to] != nil }
            let onMoved = caps.filter { $0.to == m.to }.min { value(after[$0.from]!.kind) < value(after[$1.from]!.kind) }
            let best = caps.filter { after[$0.to]?.kind != .king }.max { value(after[$0.to]!.kind) < value(after[$1.to]!.kind) }
            guard let c = onMoved ?? (rule == "safe" ? best : nil) else { return nil }
            return LessonConsequence(moves: [c], line: TutorLines.xiangqiCaptured)

        case "mate":
            // 将了军但没将死：黑将走开（将走不了、只能挡或吃的，就不演示）
            guard after.inCheck(.black), let k = after.king(.black),
                  let esc = replies.first(where: { $0.from == k }) else { return nil }
            return LessonConsequence(moves: [esc], line: TutorLines.xiangqiKingEscaped)

        default:
            return nil
        }
    }
}
