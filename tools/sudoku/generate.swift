import Foundation

// 出题器：zsh tools/sudoku/generate.sh
// 每一组用固定种子：随机填满一个盘面，再一个一个（九宫格、六宫格成对、中心对称地）挖空格，
// 每挖一个都要求"只用这一组允许的几招还能解完"（能解完就一定只有一个解），挖到目标空格数为止。
// 每一关出几道候选，挑一道比上一关稍难一点的；最后按难度分排好。写进 RanranGame/Games/Sudoku/Logic/SudokuLevelData.swift。
// 关卡一旦发布就不能再改（存档里记着哪一关过了几颗星），所以这个脚本只在第一次出题时跑。

let root = CommandLine.arguments[1]
setvbuf(stdout, nil, _IONBF, 0)

func seed(_ s: String) -> UInt64 {
    var h: UInt64 = 0xcbf2_9ce4_8422_2325
    for b in ("ranran-sudoku-" + s).utf8 { h ^= UInt64(b); h = h &* 0x0000_0100_0000_01B3 }
    return h
}

/// 后面的关卡要求"更简单的几招解不完"，逼她用上这一组新学的那一招
func weaker(_ p: SudokuPackInfo, _ k: Int) -> Set<SudokuTechnique>? {
    switch p.id {
    case "n4": return k >= 4 ? [.full] : nil
    case "s6": return k >= 3 ? [.full] : nil
    case "e9": return k >= 4 ? [.full] : nil
    case "h9": return k >= 9 ? [.full, .hidden] : nil
    default: return nil
    }
}

func carve(_ sol: SudokuGrid, target: Int, allowed: Set<SudokuTechnique>, rng: inout SudokuRNG) -> SudokuGrid? {
    var g = sol
    let symmetric = g.n >= 6
    var groups: [[Int]] = []
    var seen = Set<Int>()
    for i in (0..<g.count).shuffled(using: &rng) where !seen.contains(i) {
        let j = g.count - 1 - i
        let grp = symmetric && j != i ? [i, j] : [i]
        grp.forEach { seen.insert($0) }
        groups.append(grp)
    }
    for grp in groups {
        if g.blankCount >= target { break }
        let cells = g.blankCount + grp.count > target ? [grp[0]] : grp
        for c in cells { g[c] = 0 }
        if !SudokuSolver.logicSolve(g, allowed: allowed).solved { for c in cells { g[c] = sol[c] } }
    }
    return g.blankCount == target ? g : nil
}

var puzzles: [String: String] = [:]
var prints = Set<String>()
for p in SudokuCatalog.info {
    var rng = SudokuRNG(seed: seed(p.id))
    var chosen: [(grid: SudokuGrid, score: Double)] = []
    for k in 0..<p.count {
        let span = Double(p.blanks.upperBound - p.blanks.lowerBound)
        var target = p.blanks.lowerBound + Int((Double(k) * span / Double(max(p.count - 1, 1))).rounded())
        var cands: [(grid: SudokuGrid, score: Double)] = []
        var attempts = 0
        var require = weaker(p, k)
        while cands.count < 6 {
            attempts += 1
            if attempts % 2000 == 0 {
                // 太难出：先不要求"更简单的几招解不完"，再不行就少挖一个
                if require != nil { require = nil } else { target -= 1 }
                print("  \(p.id)-\(k + 1): relaxing (target \(target))")
            }
            let sol = SudokuSolver.randomSolution(n: p.n, using: &rng)
            guard var g = carve(sol, target: target, allowed: p.allowed, rng: &rng) else { continue }
            g.fruit = p.fruit
            if let w = require, SudokuSolver.logicSolve(g, allowed: w).solved { continue }
            let fp = sudokuFingerprint(g)
            if prints.contains(fp) || cands.contains(where: { sudokuFingerprint($0.grid) == fp }) { continue }
            cands.append((g, SudokuSolver.logicSolve(g, allowed: p.allowed).score))
        }
        print("  \(p.id)-\(k + 1): \(attempts) attempts, target \(target)")
        let prev = chosen.last?.score ?? 0
        let sorted = cands.sorted { $0.score < $1.score }
        let pick = sorted.first { $0.score > prev } ?? sorted.last!
        prints.insert(sudokuFingerprint(pick.grid))
        chosen.append(pick)
    }
    chosen.sort { $0.score < $1.score }
    for (k, c) in chosen.enumerated() {
        let id = p.levels[k]
        puzzles[id] = c.grid.spec
        let tr = SudokuSolver.logicSolve(c.grid, allowed: p.allowed)
        print("\(id)\tblanks \(c.grid.blankCount)\tscore \(Int(c.score))\thardest \(tr.hardest)")
    }
}

var out = """
// 自动生成：zsh tools/sudoku/generate.sh（固定种子）。不要手改。
// 关卡 id 和题目会写进存档，发布以后就不能再改（tools/sudoku/test.sh 用校验和守着）。
// 写法见 SudokuGrid："<边长>[f]:<格子>"，"." 是空格，f 表示用水果显示。

enum SudokuLevelData {
    static let puzzles: [String: String] = [

"""
for p in SudokuCatalog.info {
    for id in p.levels { out += "        \"\(id)\": \"\(puzzles[id]!)\",\n" }
}
out += "    ]\n}\n"
try! out.write(toFile: root + "/RanranGame/Games/Sudoku/Logic/SudokuLevelData.swift", atomically: true, encoding: .utf8)
print("wrote \(puzzles.count) levels; checksum \(sudokuChecksum(puzzles))")
