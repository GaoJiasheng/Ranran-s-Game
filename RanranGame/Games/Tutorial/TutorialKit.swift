import Foundation

// 后来加进来的游戏（国际象棋、数独、七巧板、华容道、编程……）接进教学框架时要交代的东西。
// 只有数据和纯函数，和界面无关——命令行校验工具（tools/tutorials/validate.sh）也编译这个文件。
// 每个游戏在自己的 Games/<游戏>/Logic/<游戏>TutorialKit.swift 里写一个 kit，在下面的 all 里登记一行。

struct TutorialKit {
    /// 游戏的名字，和 Tutorials/<game>.json、PlayerStore 里的计数前缀一致
    let game: String
    /// 这个游戏自己的固定台词（都要配音）。要和 tools/voice/extra_<game>.json 里的 lines 一模一样。
    var fixedLines: [String] = []
    /// 练一练 / 复习时，没写 drill 的题按 task.rule 配的通用说法（先找整条 rule，再找冒号前那一段）
    var practicePrompts: [String: String] = [:]
    /// 练一练 / 复习时一段题能换成几种样子（包括原样）。1 = 只有原样。
    var practiceVariants = 1
    /// 把一段题换成第 k 种样子（0 是原样）：局面、标记、答案……所有写着位置或内容的地方要一起变
    var practiceTransform: (([TutorialStep], Int) -> [TutorialStep])? = nil
    /// 学完一组以后去玩什么：棋类是选第几档，解谜类是打开第几组关卡（从 1 开始）。没写的组按顺序往后排。
    var playLevels: [String: Int] = [:]
    /// 学完一组时说的那句话；nil 就用下棋的那句（TutorLines.goPlay）
    var goPlayLine: String? = nil
    /// 学完一组时按钮上的字；nil 就是「去下一盘」
    var goPlayTitle: String? = nil
}

enum TutorialKits {
    static let all: [TutorialKit] = [ChessTutorial.kit, SudokuTutorial.kit, TangramTutorial.kit, KlotskiTutorial.kit,
                                      CodingTutorial.kit]

    static func find(_ game: String) -> TutorialKit? { all.first { $0.game == game } }
}
