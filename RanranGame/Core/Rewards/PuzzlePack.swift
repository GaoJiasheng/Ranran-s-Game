import Foundation

// 解谜类游戏（数独、七巧板、华容道……）的关卡怎么分组。只有数据，和界面、存档都无关，命令行工具也编译它。

/// 一组关卡，比如数独的「四宫格」。组和关的 id 会写进存档，定了就永远不能改。
struct PuzzlePack: Identifiable, Hashable {
    /// 存档里用的名字，比如 "g4"
    let id: String
    /// 给孩子看的名字，比如「四宫格」
    let name: String
    /// 一句话说明，比如"每行每列四种水果"
    let subtitle: String
    /// 这一组的小图（Assets 里的名字），也是通过这一组的本领奖章
    let art: String
    /// 这一组的关卡 id，按从易到难的顺序。一组最多 20 关（关卡页不滚动，要一屏放下）
    let levels: [String]
}

enum PuzzleRules {
    /// 家长在「我的」里打开的"全部解锁"，全 App 共用一个开关
    static let unlockAllKey = "story.unlockAll"
    /// 前一组过了多少关，下一组才打开：三分之二，向上取整
    static func needed(toOpenAfter pack: PuzzlePack) -> Int { (pack.levels.count * 2 + 2) / 3 }
    /// 每组里同时开着几关还没过的：卡住一关，还能先玩后面一关
    static let openAhead = 2
}
