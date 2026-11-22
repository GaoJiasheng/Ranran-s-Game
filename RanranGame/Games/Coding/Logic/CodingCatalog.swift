import Foundation

// 占位：编程的关卡分组。组和关的 id 会写进存档，定了就不能改。见 docs/new-games.md 和 docs/tutorial-coding.md。
enum CodingCatalog {
    static let packs: [PuzzlePack] = []
    /// 通过前几组算"学会了"
    static let passPacks = 2
}
