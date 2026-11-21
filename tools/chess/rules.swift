import Foundation

// 规则：perft、FEN、特殊走法、结局、记谱

// MARK: perft（标准局面，数字来自 chessprogramming.org）

let perfts: [(String, String, [Int])] = [
    ("start", ChessBoard.startFEN, [20, 400, 8902, 197281]),
    ("kiwipete", "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", [48, 2039, 97862]),
    ("position 3", "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", [14, 191, 2812, 43238]),
    ("position 4", "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1", [6, 264, 9467, 422333]),
    ("position 5", "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", [44, 1486, 62379]),
    ("position 6", "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10", [46, 2079, 89890]),
]
for (name, fen, counts) in perfts {
    let b = board(fen)
    for (i, n) in counts.enumerated() {
        let got = b.perft(i + 1)
        expect(got == n, "perft \(name) depth \(i + 1): \(got), expected \(n)")
    }
    print("  perft \(name): depths 1–\(counts.count) ok")
}

// 走一步再退回来，局面（包括哈希）要和原来一模一样
do {
    var rng = SplitMix(state: 1)
    var b = ChessBoard.start
    var stack: [(ChessMove, ChessUndo, ChessBoard)] = []
    for _ in 0..<400 {
        let ms = b.legalMoves()
        if ms.isEmpty { break }
        let m = ms[Int(rng.next() % UInt64(ms.count))]
        let before = b
        let u = b.make(m)
        stack.append((m, u, before))
        var fresh = ChessBoard(fen: b.fen)!
        fresh.halfmove = b.halfmove
        expect(fresh.hash == b.hash, "incremental hash differs from fresh hash after \(m.uci): \(b.fen)")
    }
    while let (m, u, before) = stack.popLast() {
        b.unmake(m, u)
        expect(b == before, "unmake \(m.uci) does not restore the position")
    }
}

// MARK: FEN

for fen in [ChessBoard.startFEN, "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
            "rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3", "8/8/8/8/8/8/8/K6k b - - 37 80"] {
    expect(board(fen).fen == fen, "FEN round trip \(fen) → \(board(fen).fen)")
}
expect(ChessBoard(fen: "8/8/8/8/8/8/8/9 w - - 0 1") == nil, "bad FEN rejected")
expect(ChessBoard(fen: "8/8/8 w - - 0 1") == nil, "short FEN rejected")
// 易位权和棋盘对不上（车不在角上）就去掉
expect(board("4k3/8/8/8/8/8/8/4K3 w KQkq - 0 1").castling == 0, "castling rights without rooks are dropped")

// MARK: 王车易位

do {
    let b = board("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
    expect(moves(b).isSuperset(of: ["e1g1", "e1c1"]), "white can castle both sides")
    let bb = play(b, ["a1a2"])
    expect(moves(bb).isSuperset(of: ["e8g8", "e8c8"]), "black can castle both sides")
    // 车走过一次，那一边就不能再易位
    let moved = play(b, ["h1h2", "a8a7", "h2h1", "a7a8"])
    expect(!moves(moved).contains("e1g1") && moves(moved).contains("e1c1"), "moved rook loses its side")
    // 王走过就都不行
    let king = play(b, ["e1e2", "e8e7", "e2e1", "e7e8"])
    expect(!moves(king).contains("e1g1") && !moves(king).contains("e1c1"), "moved king cannot castle")
    // 被将军不能易位
    let checked = board("4r1k1/8/8/8/8/8/8/R3K2R w KQ - 0 1")
    expect(!moves(checked).contains("e1g1") && !moves(checked).contains("e1c1"), "no castling out of check")
    // 经过被攻击的格子不行（f1），落脚格被攻击也不行（c1）
    let through = board("5r1k/8/8/8/8/8/8/R3K2R w KQ - 0 1")
    expect(!moves(through).contains("e1g1") && moves(through).contains("e1c1"), "no castling through f1")
    let into = board("2r4k/8/8/8/8/8/8/R3K2R w KQ - 0 1")
    expect(!moves(into).contains("e1c1") && moves(into).contains("e1g1"), "no castling into c1")
    // 长易位时 b1 被攻击没关系，但 b1 上有子不行
    let b1 = board("1r5k/8/8/8/8/8/8/R3K2R w KQ - 0 1")
    expect(moves(b1).contains("e1c1"), "attacked b1 does not stop long castling")
    let b1blocked = board("7k/8/8/8/8/8/8/RN2K2R w KQ - 0 1")
    expect(!moves(b1blocked).contains("e1c1"), "a piece on b1 stops long castling")
    // 车被吃掉以后，对方那一边的易位权也没了
    let taken = play(board("r3k2r/8/8/8/8/8/8/R3K1BR w KQkq - 0 1"), ["g1a7", "e8f8", "a7b8", "f8e8"])
    _ = taken
    let capRook = play(board("r3k2r/8/8/8/8/8/6B1/R3K2R w KQkq - 0 1"), ["g2a8"])
    expect(capRook.castling & 8 == 0 && capRook.castling & 4 != 0, "capturing a rook removes that castling right")
    // 易位以后车也跟着走
    let castled = play(b, ["e1g1"])
    expect(castled[ChessSquare("f1")!] == ChessPiece(.white, .rook) && castled[ChessSquare("g1")!] == ChessPiece(.white, .king)
        && castled[ChessSquare("h1")!] == nil, "short castling moves the rook to f1")
    let long = play(b, ["e1c1"])
    expect(long[ChessSquare("d1")!] == ChessPiece(.white, .rook) && long[ChessSquare("a1")!] == nil, "long castling moves the rook to d1")
    expect(b.san(ChessMove("e1g1")!) == "O-O" && b.san(ChessMove("e1c1")!) == "O-O-O", "castling SAN")
}

// MARK: 吃过路兵

do {
    let b = play(board("4k3/3p4/8/4P3/8/8/8/4K3 b - - 0 1"), ["d7d5"])
    expect(b.ep == ChessSquare("d6")!.index, "double push sets the en-passant square")
    expect(moves(b).contains("e5d6"), "en passant is available")
    let after = play(b, ["e5d6"])
    expect(after[ChessSquare("d5")!] == nil && after[ChessSquare("d6")!] == ChessPiece(.white, .pawn), "en passant removes the pawn")
    // 只有下一步能吃
    let late = play(b, ["e1e2", "e8e7"])
    expect(!moves(late).contains("e5d6"), "en passant expires after one move")
    // 吃过路兵以后自己的王会被将军（横线上的牵制），不合法
    let pinned = play(board("8/3p4/8/K3P2r/8/8/8/7k b - - 0 1"), ["d7d5"])
    expect(!moves(pinned).contains("e5d6"), "en passant that exposes the king is illegal")
    expect(b.san(ChessMove("e5d6")!) == "exd6", "en passant SAN")
}

// MARK: 升变

do {
    let b = board("3r3k/2P5/8/8/8/8/8/K7 w - - 0 1")
    let ms = moves(b)
    expect(ms.isSuperset(of: ["c7c8q", "c7c8r", "c7c8b", "c7c8n", "c7d8q", "c7d8n"]), "all four promotions, pushing and capturing")
    expect(!ms.contains("c7c8"), "no promotion-less move to the last rank")
    let q = play(b, ["c7c8q"])
    expect(q[ChessSquare("c8")!] == ChessPiece(.white, .queen), "promotes to a queen")
    let n = play(b, ["c7d8n"])
    expect(n[ChessSquare("d8")!] == ChessPiece(.white, .knight), "promotes to a knight with capture")
    expect(b.san(ChessMove("c7c8q")!) == "c8=Q", "promotion SAN \(b.san(ChessMove("c7c8q")!))")
    expect(b.san(ChessMove("c7d8q")!) == "cxd8=Q+", "capture promotion with check SAN \(b.san(ChessMove("c7d8q")!))")
    // 升变以后退回来还是兵
    var x = b
    let m = ChessMove("c7d8n")!
    let u = x.make(m)
    x.unmake(m, u)
    expect(x == b, "unmake promotion")
}

// MARK: 将死、逼和

do {
    let fool = play(ChessBoard.start, ["f2f3", "e7e5", "g2g4", "d8h4"])
    expect(fool.isCheckmate && fool.outcome == .checkmate(winner: .black), "fool's mate is checkmate")
    let scholar = play(ChessBoard.start, ["e2e4", "e7e5", "f1c4", "b8c6", "d1h5", "g8f6", "h5f7"])
    expect(scholar.isCheckmate, "scholar's mate is checkmate")
    expect(board("r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4").san(ChessMove("h5f7")!) == "Qxf7#", "mate SAN")
    let stale = board("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
    expect(stale.isStalemate && stale.outcome == .stalemate, "queen stalemate")
    let stale2 = board("k7/P7/1K6/8/8/8/8/8 b - - 0 1")
    expect(stale2.isStalemate, "pawn stalemate")
    let notStale = board("k7/P7/1K6/8/8/7p/8/8 b - - 0 1")
    expect(!notStale.isStalemate && notStale.outcome == nil, "a pawn that can move avoids stalemate")
    let smother = board("6rk/5Npp/8/8/8/8/8/6K1 b - - 0 1")
    expect(smother.isCheckmate, "smothered mate")
    // 双将只能动王
    let double = board("4k3/8/8/8/8/8/3n4/r3K3 w - - 0 1")
    expect(double.inCheck && double.legalMoves().allSatisfy { $0.from.name == "e1" }, "double check: only king moves")
    expect(double.matesInOne().isEmpty, "no mates for the checked side")
}

// MARK: 和棋：子力不足、50 回合、三次重复

expect(board("8/8/8/4k3/8/8/8/4K3 w - - 0 1").outcome == .insufficientMaterial, "K v K")
expect(board("8/8/8/4k3/8/8/8/4KB2 w - - 0 1").outcome == .insufficientMaterial, "K+B v K")
expect(board("8/8/8/4k3/8/8/8/4KN2 w - - 0 1").outcome == .insufficientMaterial, "K+N v K")
expect(board("8/8/8/4k3/2b5/8/8/4KB2 w - - 0 1").outcome == .insufficientMaterial, "K+B v K+B same colour")
expect(board("8/8/8/2b1k3/8/8/8/4KB2 w - - 0 1").outcome == nil, "K+B v K+B opposite colours can still mate")
expect(board("8/8/8/4k3/8/8/8/3NKN2 w - - 0 1").outcome == nil, "K+N+N is not automatically a draw")
expect(board("8/8/8/4k3/8/8/4P3/4K3 w - - 0 1").outcome == nil, "a pawn is enough material")
expect(board("8/8/8/4k3/8/8/8/R3K3 w - - 99 80").outcome == nil, "99 plies: not yet")
expect(play(board("8/8/8/4k3/8/8/8/R3K3 w - - 99 80"), ["a1a2"]).outcome == .fiftyMoves, "100 plies without capture or pawn move")
expect(play(board("8/8/8/4k3/8/8/P7/R3K3 w - - 99 80"), ["a2a3"]).outcome == nil, "a pawn move resets the count")
do {
    var match = ChessMatch()
    for u in ["g1f3", "g8f6", "f3g1", "f6g8", "g1f3", "g8f6", "f3g1"] { match.play(ChessMove(u)!) }
    expect(match.outcome == nil && match.repetitions == 2, "twice is not yet a draw")
    match.play(ChessMove("f6g8")!)
    expect(match.outcome == .repetition && match.repetitions == 3, "threefold repetition")
    match.takeBack()
    expect(match.outcome == nil, "take back undoes the repetition")
    expect(match.position(before: 2) == play(ChessBoard.start, ["g1f3", "g8f6"]), "position(before:)")
    // 易位权不同，就不算同一个局面
    var m2 = ChessMatch(board("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1"))
    for u in ["e1f1", "e8f8", "f1e1", "f8e8", "e1f1", "e8f8", "f1e1", "f8e8"] { m2.play(ChessMove(u)!) }
    expect(m2.repetitions == 2, "castling rights lost: the first position does not count (\(m2.repetitions))")
    // 能不能吃过路兵也算在局面里：只有真的能吃时才算
    let e = play(board("4k3/3p4/8/4P3/8/8/8/4K3 b - - 0 1"), ["d7d5"])
    let noEp = play(board("4k3/3p4/8/8/4P3/8/8/4K3 b - - 0 1"), ["d7d5"])
    expect(e.repetitionKey.hasSuffix(" d6") && !noEp.repetitionKey.hasSuffix(" d5") && !noEp.repetitionKey.contains("d6"),
           "repetition key includes only a capturable en-passant square")
}

// MARK: 记谱

do {
    let b = board("4k3/8/8/8/8/8/4K3/R6R w - - 0 1")
    expect(b.san(ChessMove("a1d1")!) == "Rad1" && b.san(ChessMove("h1d1")!) == "Rhd1", "file disambiguation")
    let c = board("4k3/8/8/8/R7/8/8/R3K3 w - - 0 1")
    expect(c.san(ChessMove("a1a2")!) == "R1a2" && c.san(ChessMove("a4a2")!) == "R4a2", "rank disambiguation")
    expect(ChessBoard.start.san(ChessMove("g1f3")!) == "Nf3" && ChessBoard.start.san(ChessMove("e2e4")!) == "e4", "simple SAN")
    expect(ChessBoard.start.chinese(ChessMove("g1f3")!) == "马f3", "Chinese notation \(ChessBoard.start.chinese(ChessMove("g1f3")!))")
    let s = board("r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4")
    expect(s.chinese(ChessMove("h5f7")!) == "后吃f7 将死", "Chinese mate notation")
    expect(ChessMove("e7e8q")?.uci == "e7e8q" && ChessMove("e7e8k") == nil && ChessMove("z9a1") == nil, "uci parsing")
}

finish("rules")
