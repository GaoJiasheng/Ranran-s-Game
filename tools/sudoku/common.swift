import Foundation

// 出题器和测试共用：一道题的"指纹"。换数字（水果）、行在自己那一条里换位置、整条换位置、列也一样、
// 沿对角线翻过来（宫是正方形时）——这样变出来的题算同一道。
//   四宫格、六宫格：把所有变换都试一遍，取最小的写法（准确）
//   九宫格：变换太多，用变换下不变的量（每行 / 列 / 宫有几个空格、每个数出现几次）当指纹。
//           一样的题指纹一定一样；指纹撞了就当作重复（宁可多挡掉一道）

func sudokuPermutations(_ k: Int) -> [[Int]] {
    if k <= 1 { return [Array(0..<k)] }
    var out: [[Int]] = []
    for p in sudokuPermutations(k - 1) {
        for i in 0...p.count {
            var q = p
            q.insert(k - 1, at: i)
            out.append(q)
        }
    }
    return out
}

/// 一条一条（每条 size 行）地换：先换整条的顺序，再换条里面的顺序
func sudokuLineMaps(count: Int, size: Int) -> [[Int]] {
    var maps: [[Int]] = []
    let inner = sudokuPermutations(size)
    func build(_ band: Int, _ order: [Int], _ acc: [Int]) {
        if band == count { maps.append(acc); return }
        for p in inner {
            var a = acc
            for pos in 0..<size { a[order[band] * size + pos] = band * size + p[pos] }
            build(band + 1, order, a)
        }
    }
    for order in sudokuPermutations(count) { build(0, order, Array(repeating: 0, count: count * size)) }
    return maps
}

/// 换掉数字的名字：按第一次出现的顺序重新编号
func sudokuRelabeled(_ cells: [Int]) -> String {
    var map: [Int: Int] = [:]
    var out = ""
    for v in cells {
        if v == 0 { out += "."; continue }
        if map[v] == nil { map[v] = map.count + 1 }
        out += String(map[v]!)
    }
    return out
}

func sudokuFingerprint(_ g: SudokuGrid) -> String {
    if g.n <= 6 {
        let rows = sudokuLineMaps(count: g.n / g.boxRows, size: g.boxRows)
        let cols = sudokuLineMaps(count: g.n / g.boxCols, size: g.boxCols)
        var best: String?
        for rm in rows {
            for cm in cols {
                for flip in (g.boxRows == g.boxCols ? [false, true] : [false]) {
                    var cells = Array(repeating: 0, count: g.count)
                    for i in 0..<g.count {
                        let r = rm[i / g.n], c = cm[i % g.n]
                        cells[flip ? c * g.n + r : r * g.n + c] = g[i]
                    }
                    let s = sudokuRelabeled(cells)
                    if best == nil || s < best! { best = s }
                }
            }
        }
        return "\(g.n)|" + best!
    }
    func counts(_ k: SudokuUnit.Kind) -> String {
        (0..<g.n).map { g.blanks(in: SudokuUnit(k, $0)).count }.sorted().map(String.init).joined(separator: ",")
    }
    let rc = [counts(.row), counts(.col)].sorted().joined(separator: "/")
    var freq = Array(repeating: 0, count: g.n + 1)
    for v in g.cells where v > 0 { freq[v] += 1 }
    let f = freq.dropFirst().sorted().map(String.init).joined(separator: ",")
    return "\(g.n)|\(g.blankCount)|\(rc)|\(counts(.box))|\(f)"
}

/// 关卡数据的校验和（FNV-1a）：题目定了就不能变
func sudokuChecksum(_ puzzles: [String: String]) -> String {
    var h: UInt64 = 0xcbf2_9ce4_8422_2325
    for k in puzzles.keys.sorted() {
        for b in (k + "=" + puzzles[k]! + ";").utf8 {
            h ^= UInt64(b)
            h = h &* 0x0000_0100_0000_01B3
        }
    }
    return String(h, radix: 16)
}
