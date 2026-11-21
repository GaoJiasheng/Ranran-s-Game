import Foundation

// 国际象棋教学题的判断：只认规则上真正对的答案，而不是只认一个格子。界面、命令行测试共用这一份。
// 教学里冉冉执白，白方在下面；每道题都在"轮到白方走"的局面上判断。
//
// task.type：move（走一步）、pick（点一个格子回答问题）
// task.piece：只能动这个格子上的子；task.accept：直接列出的答案（格子 "e4" 或着法 "e2e4" / "e7e8q"）
// task.rule：
//   any                     随便走（配合 piece：认识走法）
//   capture                 吃掉一个子
//   check                   将军
//   mate                    一步将死
//   mateIn:N                N 步之内（算上这一步）不管黑方怎么应都将死（mate2 = mateIn:2）
//   escape[:king|block|capture]  被将军了，走开 / 挡住 / 吃掉将军的子
//   bestCapture             能吃的子里最划算的那一种（按吃完以后的得失算）
//   safe                    走完以后，走过去的子没有被对方攻击
//   hold                    走完以后，黑方怎么应、双方再把能吃的吃完，白方都不丢子力
//   gain:N                  同上，而且白方至少净赚 N 分（兵 1、马象 3、车 5、后 9）
//   castle[:k|q]            王车易位（短 / 长）
//   promote[:q|r|b|n]       兵升变（升成指定的子）
//   promoteIn:N             N 步之内（算上这一步）一定能把兵安全地升成后
//   enpassant               吃过路兵
//   develop[:q]             开局出子：把还在原位的马或象放到第三排以外，而且不会白白被吃（:q 还要同时攻击黑后）
//   center                  开局：兵走到中间四格（d4、e4、d5、e5）

enum ChessLessonLogic {
    /// 子力：兵 1、马象 3、车 5、后 9（王算很大，吃到王 = 赢）
    static func value(_ k: ChessKind) -> Int { k == .king ? 1000 : k.points }

    /// 白方走 m 对不对（b 是轮到白方走的局面）
    static func check(_ task: TutorialTask, _ m: ChessMove, on b: ChessBoard) -> Bool {
        if let piece = task.piece, let sq = ChessSquare(piece), m.from != sq { return false }
        guard b.isLegal(m) else { return false }
        if let accept = task.accept {
            return accept.contains { a in
                if a.count >= 4, let mv = ChessMove(a) {
                    // 写成 "e7e8" 的升变着法：升成什么都算
                    return mv.from == m.from && mv.to == m.to && (mv.promotion == nil || mv.promotion == m.promotion)
                }
                return ChessSquare(a) == m.to
            }
        }
        let parts = (task.rule ?? "any").split(separator: ":").map(String.init)
        let arg = parts.count > 1 ? parts[1] : nil
        switch parts[0] {
        case "any": return true
        case "capture": return b.isCapture(m)
        case "check": return b.givesCheck(m)
        case "mate": return b.isMate(after: m)
        case "mate2": return matesWithin(m, 2, on: b)
        case "mateIn":
            guard let n = arg.flatMap(Int.init) else { return false }
            return matesWithin(m, n, on: b)
        case "escape":
            guard b.inCheck else { return false }
            let king = b[m.from]?.kind == .king
            switch arg {
            case "king": return king
            case "capture": return !king && b.isCapture(m)
            case "block": return !king && !b.isCapture(m)
            default: return true
            }
        case "bestCapture":
            return bestCaptures(b).contains(m)
        case "safe":
            return !b.applying(m).attacked(m.to, by: .black)
        case "hold":
            return gain(m, on: b) >= 0
        case "gain":
            return gain(m, on: b) >= (arg.flatMap(Int.init) ?? 2)
        case "castle":
            guard b.isCastle(m) else { return false }
            if arg == "k" { return m.to.file == 6 }
            if arg == "q" { return m.to.file == 2 }
            return true
        case "promote":
            guard let p = m.promotion else { return false }
            guard let a = arg?.first, let k = ChessKind(letter: a) else { return true }
            return p == k
        case "promoteIn":
            guard let n = arg.flatMap(Int.init) else { return false }
            return promotesWithin(m, n, on: b)
        case "enpassant":
            return b.isEnPassant(m)
        case "develop":
            guard let p = b[m.from], p.kind == .knight || p.kind == .bishop else { return false }
            let home: Set<String> = ["b1", "g1", "c1", "f1"]
            // 放到第三排或者更远（马跳到 e2、象退到 e2 这种挡路的不算）
            guard home.contains(m.from.name), m.to.rank >= 2 else { return false }
            if arg == "q" {
                // develop:q：出子的同时攻击黑后
                let after = b.applying(m)
                guard after.pieces.contains(where: { sq, p in
                    p == ChessPiece(.black, .queen) && after.attackers(sq.index, by: .white).contains(m.to.index)
                }) else { return false }
            }
            return gain(m, on: b) >= 0
        case "center":
            guard b[m.from]?.kind == .pawn else { return false }
            return ["d4", "e4", "d5", "e5"].contains(m.to.name) && gain(m, on: b) >= 0
        default:
            return false
        }
    }

    /// 教学里每一步都轮到白方：白方走完没有对手应着时，接着还是白方走（过路兵的格子作废）
    static func whiteToMove(_ b: ChessBoard) -> ChessBoard {
        guard b.turn == .black else { return b }
        var x = b
        x.turn = .white
        x.ep = -1
        x.refresh()
        return x
    }

    /// 所有正确着法
    static func answers(_ task: TutorialTask, on b: ChessBoard) -> [ChessMove] {
        var moves = b.legalMoves()
        if let piece = task.piece, let sq = ChessSquare(piece) { moves = moves.filter { $0.from == sq } }
        return moves.filter { check(task, $0, on: b) }
    }

    /// pick 题：点对了没有
    static func checkPick(_ task: TutorialTask, _ s: ChessSquare) -> Bool {
        (task.accept ?? []).compactMap(ChessSquare.init).contains(s)
    }

    // MARK: 子力、得子

    /// 子力：白方减黑方（王不算）
    static func material(_ b: ChessBoard) -> Int {
        b.cells.reduce(0) { s, c in
            guard c != 0, let k = ChessKind(rawValue: abs(c)), k != .king else { return s }
            return s + (c > 0 ? k.points : -k.points)
        }
    }

    /// 白方走 m 以后能稳稳赚到多少子力：黑方先应一步（任何走法），之后双方把能吃的子吃完
    /// （被将军时什么都可以走）。黑方被将死算赚很多，逼和算 0。
    static func gain(_ m: ChessMove, on b: ChessBoard) -> Int {
        let after = b.applying(m)
        if !after.hasLegalMove { return after.inCheck ? 10_000 : -material(b) }
        let white = -materialSearch(after, depth: 1, alpha: -100_000, beta: 100_000, q: 0)
        return white - material(b)
    }

    /// 只数子力的小搜索，返回轮到走的一方看的分数
    static func materialSearch(_ b: ChessBoard, depth: Int, alpha: Int, beta: Int, q: Int) -> Int {
        let moves = b.legalMoves()
        let sign = b.turn == .white ? 1 : -1
        if moves.isEmpty { return b.inCheck ? -10_000 : 0 }
        let checked = b.inCheck
        var a = alpha
        var candidates = moves
        if depth <= 0 && !checked {
            // 不吃子也可以（站着不动），所以分数至少是现在的子力
            let stand = sign * material(b)
            if stand >= beta || q >= 8 { return stand }
            a = max(a, stand)
            candidates = moves.filter { b.isCapture($0) || $0.promotion == .queen }
        } else if depth <= 0 && q >= 8 {
            return sign * material(b)
        }
        candidates.sort { (b.capturedPiece($0).map { value($0.kind) } ?? 0) > (b.capturedPiece($1).map { value($0.kind) } ?? 0) }
        for mv in candidates {
            let s = -materialSearch(b.applying(mv), depth: depth - 1, alpha: -beta, beta: -a, q: depth <= 0 ? q + 1 : 0)
            if s >= beta { return s }
            a = max(a, s)
        }
        return a
    }

    /// 能吃的子里面，吃完最划算的那些（按 gain 算）
    static func bestCaptures(_ b: ChessBoard) -> [ChessMove] {
        let caps = b.legalMoves().filter { b.isCapture($0) }
        guard !caps.isEmpty else { return [] }
        let scored = caps.map { ($0, gain($0, on: b)) }
        let top = scored.map(\.1).max()!
        return scored.filter { $0.1 == top }.map(\.0)
    }

    /// 走完以后，走过去的那个子会不会被对方吃掉
    static func isHanging(_ m: ChessMove, _ b: ChessBoard) -> Bool {
        b.applying(m).legalMoves().contains { $0.to == m.to }
    }

    // MARK: 连杀、送兵

    /// 白方走 m 以后，黑方怎么应都没用，白方 n 步之内（包括 m）将死。逼和不算。
    static func matesWithin(_ m: ChessMove, _ n: Int, on b: ChessBoard) -> Bool {
        let after = b.applying(m)
        let replies = after.legalMoves()
        if replies.isEmpty { return after.inCheck }
        guard n > 1 else { return false }
        return replies.allSatisfy { r in
            let b2 = after.applying(r)
            let all = b2.legalMoves()
            // 先试将军的着法，通常更快找到
            let checks = all.filter { b2.givesCheck($0) }
            return checks.contains { matesWithin($0, n - 1, on: b2) }
                || all.contains { !checks.contains($0) && matesWithin($0, n - 1, on: b2) }
        }
    }

    /// 白方走 m 以后，黑方怎么应，白方 n 步之内（包括 m）都能把兵升成后，而且新的后不会马上被吃（或者直接将死）
    static func promotesWithin(_ m: ChessMove, _ n: Int, on b: ChessBoard) -> Bool {
        let after = b.applying(m)
        if m.promotion == .queen {
            if !after.hasLegalMove { return after.inCheck }
            return !after.legalMoves().contains { $0.to == m.to }
        }
        let replies = after.legalMoves()
        if replies.isEmpty { return after.inCheck }
        guard n > 1 else { return false }
        return replies.allSatisfy { r in
            let b2 = after.applying(r)
            // 兵被吃掉就不行了
            guard b2.pieces.contains(where: { $0.1 == ChessPiece(.white, .pawn) }) || b2.pieces.contains(where: { $0.1 == ChessPiece(.white, .queen) }) else { return false }
            return b2.legalMoves().contains { promotesWithin($0, n - 1, on: b2) }
        }
    }

    // MARK: 黑方的应着

    /// 黑方接着走的棋："engine"（电脑想一步）、"e7e5|d7d5"（第一个能走的）
    static func reply(_ spec: [String], on b: ChessBoard) -> [ChessMove] {
        var board = b
        var out: [ChessMove] = []
        for s in spec {
            let m: ChessMove?
            if s == "engine" {
                m = ChessAI(profile: .level(8)).bestMove(board)
            } else {
                m = s.split(separator: "|").compactMap { ChessMove(String($0)) }.first { board.isLegal($0) }
            }
            guard let m else { break }
            out.append(m)
            board.make(m)
        }
        return out
    }

    // MARK: 走错的后果

    /// 白方走 m（合法，但规则上不对）以后：黑方把子吃掉、黑王逃走，或者局面成了逼和
    static func consequence(_ task: TutorialTask, _ m: ChessMove, on b: ChessBoard) -> LessonConsequence<ChessMove>? {
        guard task.type == "move", task.accept == nil, let rule = task.rule,
              b.isLegal(m), !check(task, m, on: b) else { return nil }
        let after = b.applying(m)
        let replies = after.legalMoves()
        let head = String(rule.split(separator: ":").first ?? "")

        // 想将死、想赢，结果把对方逼和了
        if replies.isEmpty {
            guard !after.inCheck, ["mate", "mate2", "mateIn", "gain", "promote", "promoteIn"].contains(head) else { return nil }
            return LessonConsequence(moves: [], line: ChessTutorLines.stalemate)
        }

        switch head {
        case "safe", "bestCapture", "hold", "gain", "develop", "center":
            // 走过去的子被吃；它没事的话（只有 safe / hold），黑方吃掉最值钱的那个
            let caps = replies.filter { after.isCapture($0) }
            let onMoved = caps.filter { $0.to == m.to }
                .min { value(after[$0.from]!.kind) < value(after[$1.from]!.kind) }
            let best = caps.filter { after[$0.to]?.kind != .king }
                .max { (after.capturedPiece($0).map { value($0.kind) } ?? 0) < (after.capturedPiece($1).map { value($0.kind) } ?? 0) }
            let c = onMoved ?? (head == "safe" || head == "hold" ? best : nil)
            guard let c else { return nil }
            // 吃完以后白方马上能吃回更多的：那不算"丢了"，不演示
            if head != "safe", gain(m, on: b) >= 0 { return nil }
            return LessonConsequence(moves: [c], line: ChessTutorLines.captured)

        case "mate", "mate2", "mateIn":
            // 将了军但没将死：黑王走开（王走不了、只能挡或吃的，就不演示）
            guard after.inCheck, let k = after.king(.black),
                  let esc = replies.first(where: { $0.from == k }) else { return nil }
            return LessonConsequence(moves: [esc], line: ChessTutorLines.kingEscaped)

        default:
            return nil
        }
    }

    // MARK: 练一练：左右镜像

    /// 左右镜像能不能用在这个局面上：有易位权、过路兵的局面左右一翻就不对了（王和后不对称）
    static func mirrorable(_ fen: String) -> Bool {
        let parts = fen.split(separator: " ").map(String.init)
        return (parts.count < 3 || parts[2] == "-") && (parts.count < 4 || parts[3] == "-")
    }

    static func mirrorSquare(_ name: String) -> String? {
        guard let s = ChessSquare(name) else { return nil }
        return ChessSquare(7 - s.file, s.rank).name
    }

    /// 一个记号：格子、着法（"e2e4"、"e7e8q"），别的原样
    static func mirrorToken(_ t: String) -> String {
        if let s = mirrorSquare(t) { return s }
        if t.count >= 4, ChessMove(t) != nil,
           let a = mirrorSquare(String(t.prefix(2))), let b = mirrorSquare(String(t.dropFirst(2).prefix(2))) {
            return a + b + String(t.dropFirst(4))
        }
        return t
    }

    /// "label:e4:A"、"e7e5|d7d5"、"capture"：按 | 和 : 拆开，每一段都变
    static func mirrorSpec(_ s: String) -> String {
        s.split(separator: "|", omittingEmptySubsequences: false).map { alt in
            alt.split(separator: ":", omittingEmptySubsequences: false).map { mirrorToken(String($0)) }.joined(separator: ":")
        }.joined(separator: "|")
    }

    static func mirrorFEN(_ fen: String) -> String {
        let parts = fen.split(separator: " ", maxSplits: 1)
        let rows = parts[0].split(separator: "/", omittingEmptySubsequences: false).map { String($0.reversed()) }
        return rows.joined(separator: "/") + (parts.count > 1 ? " " + parts[1] : "")
    }

    static func mirror(_ s: TutorialStep) -> TutorialStep {
        var t = s
        t.board = s.board.map(mirrorFEN)
        t.marks = s.marks?.map(mirrorSpec)
        t.reply = s.reply?.map(mirrorSpec)
        if var task = s.task {
            task.accept = task.accept?.map(mirrorToken)
            task.rule = task.rule.map(mirrorSpec)
            task.piece = task.piece.map(mirrorToken)
            t.task = task
        }
        return t
    }

    /// 一段练习题换成第 k 种样子：0 原样，1 左右镜像（局面里有易位权或过路兵时不变）
    static func transform(_ seg: [TutorialStep], _ k: Int) -> [TutorialStep] {
        guard k == 1, let fen = seg.first?.board, mirrorable(fen) else { return seg }
        return seg.map(mirror)
    }
}

/// 国际象棋教学的固定台词（都要配音；和 tools/voice/extra_chess.json 的 lines 一致）
enum ChessTutorLines {
    static let captured = "看，被黑棋吃掉了。"
    static let kingEscaped = "看，黑王逃走了。"
    static let stalemate = "看，黑王没被将军，却一步也走不了，这是逼和，不算赢。"
    static let kingUnsafe = "王不能走到会被对方吃掉的地方。"
    static let exposesKing = "走了这一步，你的王就会被吃掉，不可以。"

    static var all: [String] { [captured, kingEscaped, stalemate, kingUnsafe, exposesKing] }
}
