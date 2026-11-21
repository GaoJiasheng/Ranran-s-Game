import Foundation

// tools/chess 里几个测试共用的小工具

var failures = 0
var verbose = CommandLine.arguments.contains("-v")

func fail(_ s: String) { failures += 1; print("  ❌ " + s) }
func expect(_ ok: Bool, _ what: @autoclosure () -> String) { if !ok { fail(what()) } }
func note(_ s: String) { if verbose { print(s) } }

func board(_ fen: String) -> ChessBoard {
    guard let b = ChessBoard(fen: fen) else { fatalError("bad FEN \(fen)") }
    return b
}

func moves(_ b: ChessBoard) -> Set<String> { Set(b.legalMoves().map(\.uci)) }

/// 按 uci 走一串棋（每一步都要合法）
func play(_ b: ChessBoard, _ ucis: [String]) -> ChessBoard {
    var x = b
    for u in ucis {
        guard let m = ChessMove(u), x.isLegal(m) else { fatalError("illegal \(u) in \(x.fen)") }
        x.make(m)
    }
    return x
}

func finish(_ name: String) -> Never {
    print(failures == 0 ? "  \(name): ok" : "  \(name): \(failures) problems")
    exit(failures == 0 ? 0 : 1)
}

struct SplitMix: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
