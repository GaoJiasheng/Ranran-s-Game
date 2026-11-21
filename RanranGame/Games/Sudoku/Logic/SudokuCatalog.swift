import Foundation

// 数独的关卡分组。组和关的 id 会写进存档，定了就永远不能改（见 docs/new-games.md）。
// 题目本身在 SudokuLevelData.swift（由 tools/sudoku/generate.sh 用固定种子生成，生成一次就不再改）。
//
// 五组从易到难，和教学的四组一一对应（学完一组课就去玩对应的那一组）：
//   f4 四宫格·水果  只剩一个空格（基础规则）              ← 教学第一组
//   n4 四宫格·数字  + 唯一法（这一格只能填谁）            ← 教学第二组
//   s6 六宫格       + 排除法（这个数在这一宫只能放哪）    ← 教学第三组
//   e9 九宫格·入门  只剩一个空格 + 排除法，空格少         ← 教学第四组
//   h9 九宫格·进阶  三招都用，空格多（还是不用猜）

/// 一组关卡的玩法：多大、用水果还是数字、能用哪几招
struct SudokuPackInfo {
    let id: String
    let name: String
    let subtitle: String
    let n: Int
    let fruit: Bool
    /// 这一组的每一关只用这几招就能解完（出题器保证，测试检查）；提示也只教这几招
    let allowed: Set<SudokuTechnique>
    let count: Int
    /// 出题器用：第一关和最后一关大约几个空格
    let blanks: ClosedRange<Int>

    var levels: [String] { (1...count).map { "\(id)-\($0)" } }
}

/// 一关：题目和答案
struct SudokuLevel {
    let id: String
    let pack: SudokuPackInfo
    /// 第几关（从 1 数）
    let number: Int
    let puzzle: SudokuGrid
    let solution: SudokuGrid
}

enum SudokuCatalog {
    static let info: [SudokuPackInfo] = [
        SudokuPackInfo(id: "f4", name: "四宫格·水果", subtitle: "四种水果，每行、每列、每宫都不重复",
                       n: 4, fruit: true, allowed: [.full], count: 10, blanks: 3...8),
        SudokuPackInfo(id: "n4", name: "四宫格·数字", subtitle: "数字 1 到 4，看看这一格只能填谁",
                       n: 4, fruit: false, allowed: [.full, .naked], count: 12, blanks: 6...11),
        SudokuPackInfo(id: "s6", name: "六宫格", subtitle: "数字 1 到 6，用排除法找位置",
                       n: 6, fruit: false, allowed: [.full, .hidden, .naked], count: 15, blanks: 12...22),
        SudokuPackInfo(id: "e9", name: "九宫格·入门", subtitle: "真正的数独！空格不多，慢慢来",
                       n: 9, fruit: false, allowed: [.full, .hidden], count: 15, blanks: 33...41),
        SudokuPackInfo(id: "h9", name: "九宫格·进阶", subtitle: "空格更多，还是只靠想、不用猜",
                       n: 9, fruit: false, allowed: [.full, .hidden, .naked], count: 18, blanks: 42...52),
    ]

    static let packs: [PuzzlePack] = info.map {
        PuzzlePack(id: $0.id, name: $0.name, subtitle: $0.subtitle, art: "pack_sudoku_\($0.id)", levels: $0.levels)
    }

    /// 通过前四组（到九宫格·入门为止）算"学会了"：能自己解完一道真正的九宫格数独
    static let passPacks = 4

    static func packInfo(of level: String) -> SudokuPackInfo? {
        info.first { $0.levels.contains(level) }
    }

    /// 全部关卡（第一次用到时解一遍，拿到答案）
    static let levels: [String: SudokuLevel] = {
        var out: [String: SudokuLevel] = [:]
        for p in info {
            for (k, id) in p.levels.enumerated() {
                guard let spec = SudokuLevelData.puzzles[id], let g = SudokuGrid(spec: spec),
                      let sol = SudokuSolver.solve(g) else { continue }
                out[id] = SudokuLevel(id: id, pack: p, number: k + 1, puzzle: g, solution: sol)
            }
        }
        return out
    }()

    static func level(_ id: String) -> SudokuLevel? { levels[id] }
}
