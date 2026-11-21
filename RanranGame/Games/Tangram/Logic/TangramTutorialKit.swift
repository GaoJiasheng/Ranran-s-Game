import Foundation

// 七巧板接进教学框架时要交代的东西：固定台词、练习说法、学完一组去玩哪一组关卡。见 docs/new-games.md。

enum TangramTutorial {
    // 教学里拼错时的提醒（不算做错，见 TangramLessonView）
    static let outside = "这一块跑到影子外面去了，换个地方试试。"
    static let overlap = "这一块压在别的板子上了，换个地方试试。"
    static let turnFirst = "先点一点这块板子，把它转到和影子一样的方向。"
    // 闯关拼好时说的话
    static let solvedLine = "拼好啦！"

    /// 练一练 / 复习里，没写 drill 的题按规则配的通用说法（也要配音，所以一起放进固定台词）
    static let prompts: [String: String] = [
        "fill": "用这几块板子，把影子填满！",
        "pick:L": "点一点大三角形！",
        "pick:M": "点一点中三角形！",
        "pick:S": "点一点小三角形！",
        "pick:Q": "点一点正方形！",
        "pick:P": "点一点平行四边形！",
    ]
    static let promptLines = ["fill", "pick:L", "pick:M", "pick:S", "pick:Q", "pick:P"].compactMap { prompts[$0] }

    static let kit = TutorialKit(
        game: "tangram",
        // 和 tools/voice/extra_tangram.json 的 lines 一模一样
        fixedLines: [outside, overlap, turnFirst, solvedLine] + promptLines,
        practicePrompts: prompts,
        practiceVariants: 8,
        practiceTransform: { steps, k in steps.map { TangramLessonLogic.transform($0, k) } },
        playLevels: ["basic": 1, "combine": 2, "tricks": 3],
        goPlayLine: "这一组学完啦，去闯关吧！",
        goPlayTitle: "去闯关"
    )
}
