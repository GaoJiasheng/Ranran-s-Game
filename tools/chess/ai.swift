import Foundation

// 电脑对手：从不走不合法的棋；高档能找到杀棋；低档真的会送子；想一步的时间不超过档位的时间限制太多

// MARK: 自己和自己下：每一步都合法，结局能判出来

func playGame(white: Int, black: Int, plies: Int) -> (match: ChessMatch, illegal: Int) {
    var match = ChessMatch()
    var illegal = 0
    for _ in 0..<plies {
        if match.outcome != nil { break }
        let level = match.board.turn == .white ? white : black
        guard let m = ChessAI(profile: .level(level)).bestMove(match.board, history: match.hashes) else {
            fail("level \(level) returned no move in \(match.board.fen)")
            break
        }
        if !match.board.isLegal(m) { illegal += 1; fail("level \(level) played illegal \(m.uci) in \(match.board.fen)"); break }
        match.play(m)
    }
    return (match, illegal)
}

do {
    var total = 0
    for (w, b) in [(1, 2), (2, 3), (3, 1), (4, 5)] {
        let g = playGame(white: w, black: b, plies: 120)
        total += g.match.moves.count
    }
    print("  self-play: \(total) moves by levels 1–5, all legal")
}

// MARK: 第 10 档（和第 8 档：教学里电脑应着用它）能找到两步杀

let mateInTwo = [
    // 后送到 g8，车吃回，马闷杀
    "r6k/6pp/7N/8/2Q5/8/5PPP/6K1 w - - 0 1",
    // 双车错：车将军，再在底线将死
    "8/4k3/R7/8/8/8/8/1R5K w - - 0 1",
    // 后和王：先走王，再将死
    "4k3/6Q1/2K5/8/8/8/8/8 w - - 0 1",
    // 车冲底线，黑车吃回，另一个车将死
    "2r3k1/5ppp/8/8/8/8/4RPPP/4R1K1 w - - 0 1",
]
for fen in mateInTwo {
    let b = board(fen)
    for level in [8, 10] {
        let start = Date()
        guard let m = ChessAI(profile: .level(level)).bestMove(b) else { fail("no move \(fen)"); continue }
        let t = Date().timeIntervalSince(start)
        expect(ChessLessonLogic.matesWithin(m, 2, on: b), "level \(level) misses mate in 2 in \(fen): played \(m.uci)")
        note("  level \(level) \(b.san(m)) in \(String(format: "%.2f", t))s")
    }
}
// 一步杀：第 5 档以上都不会放过（1–3 档有一定概率随便走，会漏掉，这是故意留给初学者的机会）
for fen in ["6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1", "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4"] {
    let b = board(fen)
    for level in [5, 7] {
        let m = ChessAI(profile: .level(level)).bestMove(b)!
        expect(b.isMate(after: m), "level \(level) misses mate in 1: \(m.uci) in \(fen)")
    }
}
// 被将死前要会防：第 6 档以上看到对方的一步杀会挡
do {
    let b = board("6k1/5ppp/8/8/8/8/r4PPP/3R2K1 b - - 0 1") // 白车威胁 d8 底线杀
    for level in [6, 9] {
        let m = ChessAI(profile: .level(level)).bestMove(b)!
        let after = b.applying(m)
        expect(after.matesInOne().isEmpty, "level \(level) allows a back-rank mate after \(m.uci)")
    }
}
// 随便走也不送一步杀（第 1 档）
do {
    let b = board("6k1/5ppp/8/8/8/8/r4PPP/3R2K1 b - - 0 1")
    var allowed = 0
    for _ in 0..<40 {
        let m = ChessAI(profile: .level(1)).bestMove(b)!
        if !b.applying(m).matesInOne().isEmpty { allowed += 1 }
    }
    expect(allowed == 0, "level 1 walked into a mate in one \(allowed)/40 times")
}

// MARK: 低档会丢子，高档不会

func material(_ b: ChessBoard, _ side: ChessSide) -> Int {
    b.pieces.filter { $0.1.side == side }.reduce(0) { $0 + $1.1.kind.points }
}

do {
    // 第 1 档执白、第 5 档执黑，下 40 步，看白方是不是落后很多
    var behind = 0
    let games = 10
    for _ in 0..<games {
        let g = playGame(white: 1, black: 5, plies: 40)
        let diff = material(g.match.board, .white) - material(g.match.board, .black)
        if diff <= -3 || g.match.board.isCheckmate { behind += 1 }
    }
    expect(behind >= 7, "level 1 should usually lose material to level 5 (\(behind)/\(games))")
    print("  level 1 vs level 5: level 1 down material in \(behind)/\(games) games after 20 moves")

    // 第 3 档对第 1 档：大多数时候领先
    var ahead = 0
    for _ in 0..<games {
        let g = playGame(white: 3, black: 1, plies: 40)
        let diff = material(g.match.board, .white) - material(g.match.board, .black)
        if diff >= 3 || (g.match.board.isCheckmate && g.match.board.turn == .black) { ahead += 1 }
    }
    expect(ahead >= 6, "level 3 should usually beat level 1 (\(ahead)/\(games))")
    print("  level 3 vs level 1: level 3 ahead in \(ahead)/\(games) games")
}

// 送子题：一个没保护的后，第 2 档以上一定吃
do {
    let b = board("4k3/8/8/3q4/8/8/3R4/4K3 w - - 0 1")
    for level in [2, 4, 8] {
        // 第 2 档有四成机会乱走，所以大约六成会吃；高档每次都吃
        var took = 0
        for _ in 0..<40 where ChessAI(profile: .level(level)).bestMove(b)?.uci == "d2d5" { took += 1 }
        expect(took >= (level == 2 ? 14 : 40), "level \(level) takes a free queen only \(took)/40")
    }
}

// MARK: 想一步要多久（iPad 比这台 Mac 慢，档位的时间限制留了余量）

do {
    let middle = board("r1bq1rk1/pp2bppp/2n1pn2/3p4/2PP4/2N1PN2/PP3PPP/R2QKB1R w KQ - 0 8")
    for level in [5, 8, 10] {
        let start = Date()
        _ = ChessAI(profile: .level(level)).bestMove(middle)
        let t = Date().timeIntervalSince(start)
        let limit = ChessAI.Profile.level(level).timeLimit
        expect(t < limit + 1.5, "level \(level) took \(t)s (limit \(limit))")
        print("  level \(level): \(String(format: "%.2f", t))s in a middlegame (limit \(limit)s)")
    }
}

finish("ai")
