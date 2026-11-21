import Foundation

// 解一个盘面，打印最少步数和一条最短走法：zsh tools/klotski/solve.sh "VBBV/VBBV/VHHV/VSSV/S..S" ...
// 走法写成 种类@左上角格 方向 格数，例如 S@b5r1 是 b5 这块小方块往右滑 1 格。
for a in CommandLine.arguments.dropFirst() {
    guard let b = KlotskiBoard(layout: a) else { print("读不懂：\(a)"); continue }
    guard let path = KlotskiSolver.solve(b) else { print(a, "无解"); continue }
    var cur = b
    var steps: [String] = []
    for m in path {
        let p = cur.pieces[m.piece]
        steps.append("\(p.kind.letter)@\(KlotskiCellName.name(p.x, p.y))\(m.dir.letter)\(m.dist)")
        cur = cur.applying(m)
    }
    print(a, path.count, steps.joined(separator: " "))
}
