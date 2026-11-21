import Foundation

// 占位：数独的关卡分组（这里的三组只是为了看关卡页的样子）。组和关的 id 会写进存档，定了就不能改。见 docs/new-games.md。
enum SudokuCatalog {
    static let packs: [PuzzlePack] = [
        PuzzlePack(id: "a", name: "四宫格", subtitle: "每行每列四种水果", art: "item_apple", levels: (1...12).map { "a\($0)" }),
        PuzzlePack(id: "b", name: "六宫格", subtitle: "数字 1 到 6", art: "item_cookie", levels: (1...16).map { "b\($0)" }),
        PuzzlePack(id: "c", name: "九宫格", subtitle: "真正的数独", art: "item_pencil", levels: (1...20).map { "c\($0)" }),
    ]
    /// 通过前几组算"学会了"
    static let passPacks = 2
}
