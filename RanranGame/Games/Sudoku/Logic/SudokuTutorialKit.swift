import Foundation

// 数独接进教学框架：固定台词（闯关时的提示、教学里的提醒、练习的通用说法）、练习时怎么换样子、学完一组去玩哪一组关卡。
// fixedLines 要和 tools/voice/extra_sudoku.json 里的 lines 一模一样（tools/sudoku/test.sh 会检查）。

/// 闯关和教学里老师说的固定句子（都有配音，不拼接）
enum SudokuLines {
    // 闯关的「提示」：第一下讲道理（圈出来、打叉），第二下才把答案填上
    static let fullRow = "这一行只剩一个空格了，缺的是哪一个？"
    static let fullCol = "这一列只剩一个空格了，缺的是哪一个？"
    static let fullBox = "这一宫只剩一个空格了，缺的是哪一个？"
    static let hiddenBox = "这一宫里还没有亮起来的这个数。打叉的格子都不能放，只剩发光的格子能放它！"
    static let hiddenRow = "这一行里还没有亮起来的这个数。打叉的格子都不能放，只剩发光的格子能放它！"
    static let hiddenCol = "这一列里还没有亮起来的这个数。打叉的格子都不能放，只剩发光的格子能放它！"
    static let naked = "看发光的格子：它这一行、这一列、这一宫里已经有的都不能填，只剩一个能填！"
    static let reveal = "答案就是它，帮你填上啦！"
    static let fixWrong = "红色的格子填错了，先把它擦掉，再想一想。"
    // 教学里的小提醒（不算错）
    static let pickCellFirst = "先点一个空格子，再选。"
    static let notBlank = "这个格子已经填好了，点一个空格子吧。"

    static func hint(for m: SudokuMove) -> String {
        switch (m.technique, m.unit?.kind) {
        case (.full, .row?): fullRow
        case (.full, .col?): fullCol
        case (.full, _): fullBox
        case (.hidden, .row?): hiddenRow
        case (.hidden, .col?): hiddenCol
        case (.hidden, _): hiddenBox
        case (.naked, _): naked
        }
    }

    static let all = [fullRow, fullCol, fullBox, hiddenBox, hiddenRow, hiddenCol, naked, reveal, fixWrong,
                      pickCellFirst, notBlank]
}

enum SudokuTutorial {
    static let goPlayLine = "这一组学完啦，去闯关吧！"

    /// 练习时没写 drill 的题，按规则配的说法（不提位置、不提具体的数，也不说"数字"——四宫格用的是水果）
    static let prompts: [String: String] = [
        "cell": "把发光的格子填上！",
        "single": "找一个能确定的空格，填上！",
        "where": "圈出来的地方还没有亮起来的这一个，它只能放在哪一格？点一下！",
        "missing": "圈出来的地方缺了哪一个？点按钮选出来！",
        "oneBlank": "找出只剩一个空格的地方，点一下！",
        "oneBlank:row": "找出只剩一个空格的那一行，点一下！",
        "oneBlank:col": "找出只剩一个空格的那一列，点一下！",
        "oneBlank:box": "找出只剩一个空格的那一宫，点一下！",
        "fullest": "空格最少的地方在哪里？点一下！",
        "fullest:row": "哪一行的空格最少？点一下这一行！",
        "fullest:col": "哪一列的空格最少？点一下这一列！",
        "fullest:box": "哪一宫的空格最少？点一下这一宫！",
        "clash": "有一个填重复了，把它找出来！",
        "cands": "发光的格子可以填哪些？把它们都点出来！",
    ]

    /// 先找整条规则，再找冒号前那一段（和 PracticePrompts.generic 一样）
    static func prompt(for rule: String) -> String? {
        prompts[rule] ?? prompts[String(rule.split(separator: ":").first ?? "")]
    }

    static let fixedLines: [String] = SudokuLines.all + prompts.values.sorted() + [goPlayLine]

    static let kit = TutorialKit(
        game: "sudoku",
        fixedLines: fixedLines,
        practicePrompts: prompts,
        practiceVariants: 8,
        practiceTransform: { steps, k in
            guard let spec = steps.first?.board, let g = SudokuGrid(spec: spec) else { return steps }
            let t = SudokuTransform.variant(n: g.n, k: k)
            return steps.map(t.step)
        },
        playLevels: ["basic": 1, "unique": 2, "exclude": 3, "nine": 4],
        goPlayLine: goPlayLine,
        goPlayTitle: "去闯关"
    )
}
