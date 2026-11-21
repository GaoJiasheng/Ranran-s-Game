import Foundation

// 华容道关卡候选生成：zsh tools/klotski/gen.sh <easy|mid|hard|master> <种子> <摆几种木盘> > 候选文件
//
// 随机摆出一种木盘（木块 + 空格），用求解器算出它能走到的所有局面离出口最少几步，
// 把每个步数里"最整齐"的几个局面当候选打印出来：
//   <最少步数> <整齐分> <木块数> <盘面>
// 然后由 tools/klotski/pick.py 按每一组的步数范围挑选、去重，写进 tools/klotski/levels.txt。
// 一个木盘摆过的局面（包括镜像）不会再摆第二次。

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

struct Mode {
    var empties: ClosedRange<Int>
    var weights: [KlotskiKind: Int]
    var maxSmall: Int
    var maxPieces: Int
    var minPieces: Int
    var distRange: ClosedRange<Int>
    var perDistance: Int
}

let modes: [String: Mode] = [
    "easy": Mode(empties: 10...14, weights: [.tall: 3, .wide: 3, .small: 2], maxSmall: 3, maxPieces: 6, minPieces: 3,
                 distRange: 2...12, perDistance: 6),
    "mid": Mode(empties: 6...9, weights: [.tall: 3, .wide: 3, .small: 2], maxSmall: 4, maxPieces: 9, minPieces: 6,
                distRange: 8...28, perDistance: 4),
    "hard": Mode(empties: 3...4, weights: [.tall: 4, .wide: 3, .small: 2], maxSmall: 5, maxPieces: 11, minPieces: 8,
                 distRange: 22...55, perDistance: 3),
    "master": Mode(empties: 2...2, weights: [.tall: 4, .wide: 3, .small: 2], maxSmall: 5, maxPieces: 11, minPieces: 8,
                   distRange: 45...150, perDistance: 4),
]

let args = CommandLine.arguments
guard args.count >= 4, let mode = modes[args[1]], let seed = UInt64(args[2]), let tries = Int(args[3]) else {
    print("用法: gen <easy|mid|hard|master> <种子> <木盘数>")
    exit(1)
}
var rng = SplitMix(state: seed &* 7919 &+ 13)

/// 随机摆一个木盘：先摆小兔，然后在第一个空格上随机放木块或者留空
func randomBoard() -> KlotskiBoard? {
    if mode.empties.lowerBound >= 5 { return randomSparseBoard() }
    let empties = Int.random(in: mode.empties, using: &rng)
    let bx = Int.random(in: 0...2, using: &rng), by = Int.random(in: 0...3, using: &rng)
    var pieces = [KlotskiPiece(kind: .big, x: bx, y: by)]
    var occ = KlotskiBoard.mask(.big, bx, by)
    var holes = 0
    var smalls = 0
    for i in 0..<20 where occ & (1 << UInt32(i)) == 0 {
        let x = i % 4, y = i / 4
        var opts: [(KlotskiKind?, Int)] = []
        for (k, w) in mode.weights {
            guard x + k.w <= 4, y + k.h <= 5, KlotskiBoard.mask(k, x, y) & occ == 0 else { continue }
            if k == .small && smalls >= mode.maxSmall { continue }
            opts.append((k, w))
        }
        if holes < empties { opts.append((nil, 2)) }
        guard !opts.isEmpty else { return nil }
        var r = Int.random(in: 0..<opts.reduce(0) { $0 + $1.1 }, using: &rng)
        let pick = opts.first { r -= $0.1; return r < 0 }!.0
        if let k = pick {
            pieces.append(KlotskiPiece(kind: k, x: x, y: y))
            occ |= KlotskiBoard.mask(k, x, y)
            if k == .small { smalls += 1 }
        } else {
            holes += 1
            occ |= 1 << UInt32(i)
        }
    }
    guard holes == empties, pieces.count >= mode.minPieces, pieces.count <= mode.maxPieces else { return nil }
    return KlotskiBoard(pieces: pieces)
}

/// 空格很多的木盘：直接随机往盘里放几块木块
func randomSparseBoard() -> KlotskiBoard? {
    let bx = Int.random(in: 0...2, using: &rng), by = Int.random(in: 0...3, using: &rng)
    var pieces = [KlotskiPiece(kind: .big, x: bx, y: by)]
    var occ = KlotskiBoard.mask(.big, bx, by)
    let n = Int.random(in: mode.minPieces...mode.maxPieces, using: &rng)
    var smalls = 0
    var guardCount = 0
    while pieces.count < n && guardCount < 200 {
        guardCount += 1
        var r = Int.random(in: 0..<mode.weights.values.reduce(0, +), using: &rng)
        let k = mode.weights.first { r -= $0.value; return r < 0 }!.key
        if k == .small && smalls >= mode.maxSmall { continue }
        let x = Int.random(in: 0...(4 - k.w), using: &rng), y = Int.random(in: 0...(5 - k.h), using: &rng)
        if KlotskiBoard.mask(k, x, y) & occ != 0 { continue }
        pieces.append(KlotskiPiece(kind: k, x: x, y: y))
        occ |= KlotskiBoard.mask(k, x, y)
        if k == .small { smalls += 1 }
    }
    return pieces.count == n ? KlotskiBoard(pieces: pieces) : nil
}

/// 整齐分：对称、木块靠墙靠边、空格连成一片、小兔在上面都加分
func tidy(_ b: KlotskiBoard) -> Double {
    var s = 0.0
    if b.key == b.mirrored.key { s += 6 }
    var flush = 0
    for p in b.pieces where p.x == 0 || p.x + p.kind.w == 4 || p.y == 0 || p.y + p.kind.h == 5 { flush += 1 }
    s += Double(flush) / Double(b.pieces.count) * 4
    // 空格连成几片
    var seen = Set<Int>()
    var regions = 0
    for c in b.emptyCells {
        let id = c.y * 4 + c.x
        if seen.contains(id) { continue }
        regions += 1
        var stack = [id]
        seen.insert(id)
        while let cur = stack.popLast() {
            let cx = cur % 4, cy = cur / 4
            for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let nx = cx + dx, ny = cy + dy
                if nx < 0 || ny < 0 || nx >= 4 || ny >= 5 { continue }
                if b.isEmpty(x: nx, y: ny), seen.insert(ny * 4 + nx).inserted { stack.append(ny * 4 + nx) }
            }
        }
    }
    s -= Double(regions - 1) * 2
    if let bi = b.bunny { s += b.pieces[bi].y == 0 ? 3 : b.pieces[bi].y == 1 ? 1 : 0 }
    // 小方块不要孤零零地飘在中间：每个小方块旁边至少有一块别的木块或墙
    for p in b.pieces where p.kind == .small {
        var touch = 0
        for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
            let nx = p.x + dx, ny = p.y + dy
            if nx < 0 || ny < 0 || nx >= 4 || ny >= 5 || !b.isEmpty(x: nx, y: ny) { touch += 1 }
        }
        if touch < 2 { s -= 1.5 }
    }
    return s
}

var visited = Set<UInt64>()
var done = 0
var attempts = 0
while done < tries && attempts < tries * 400 {
    attempts += 1
    guard let b = randomBoard(), !visited.contains(b.canonicalKey) else { continue }
    let comp = KlotskiSolver.component(of: b)
    for k in comp { visited.insert(KlotskiBoard(key: k).canonicalKey) }
    if comp.count > 400_000 { continue }
    let dist = KlotskiSolver.distancesToGoal(in: comp)
    guard !dist.isEmpty else { continue }
    done += 1
    var byDist: [Int: [(Double, KlotskiBoard)]] = [:]
    for (k, d) in dist where mode.distRange.contains(d) {
        let board = KlotskiBoard(key: k)
        byDist[d, default: []].append((tidy(board), board))
    }
    for (d, list) in byDist {
        for (score, board) in list.sorted(by: { $0.0 > $1.0 }).prefix(mode.perDistance) {
            print(d, String(format: "%.1f", score), board.pieces.count, board.layout)
        }
    }
}
