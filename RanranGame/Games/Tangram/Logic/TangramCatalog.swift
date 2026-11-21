import Foundation

// 占位：七巧板的关卡分组。组和关的 id 会写进存档，定了就不能改。见 docs/new-games.md。
enum TangramCatalog {
    static let packs: [PuzzlePack] = []
    /// 通过前几组算"学会了"
    static let passPacks = 1
}
