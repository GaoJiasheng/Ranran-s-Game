import Foundation

// 国际象棋接进教学框架时要交代的东西：固定台词、练习时的通用说法、练习时怎么换样子、学完一组去下第几档。见 docs/new-games.md。

enum ChessTutorial {
    /// 没写 drill 的题，按规则配的通用说法（不提方向、不提格子名字：练习时棋盘会左右镜像）
    static let practicePrompts: [String: String] = [
        "capture": "吃掉一个黑棋的子！",
        "check": "将黑王一军！",
        "mate": "一步将死黑王！",
        "mate2": "先将一军，再将死黑王！",
        "mateIn": "一步一步来，将死黑王！",
        "escape": "被将军了，快解开！",
        "escape:king": "被将军了，把王走开！",
        "escape:block": "被将军了，用别的子挡一下！",
        "escape:capture": "被将军了，把将军的子吃掉！",
        "bestCapture": "吃哪一个最划算？",
        "safe": "把这个子走到不会被吃的地方！",
        "hold": "走一步，别让自己的子白白丢掉！",
        "gain": "找一步能赚到子的棋！",
        "castle": "王车易位，让王躲到安全的地方！",
        "promote": "把兵走到底，升变！",
        "promoteIn": "把兵安全地送到底，升变成后！",
        "enpassant": "吃过路兵！",
        "develop": "把一个还没动过的马或者象放出来！",
        "center": "用一个兵去占中心！",
    ]

    static let kit = TutorialKit(
        game: "chess",
        fixedLines: ChessTutorLines.all + practicePrompts.values.sorted(),
        practicePrompts: practicePrompts,
        practiceVariants: 2,
        practiceTransform: { seg, k in ChessLessonLogic.transform(seg, k) },
        playLevels: ["basic": 1, "rules": 2, "special": 2, "mates": 3, "tactics": 4, "endgame": 5]
    )
}
