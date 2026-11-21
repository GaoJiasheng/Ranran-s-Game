import Foundation

// 华容道接进教学框架时要交代的东西：固定台词、练习说法、左右镜像、学完一组去玩哪一组。见 docs/new-games.md。

enum KlotskiLines {
    /// 要求动某一块木块的题，她动了别的木块
    static let notThisBlock = "这一步要动发光的那块木块。"
    /// 还没滑过木块就点了「撤销」
    static let undoFirst = "先滑一块木块，再点撤销。"
    /// 练习的通用说法里，课文的 drill 没用到的那一句（别的几句和 drill 相同，已经在课文里录了）
    static let freeBunny = "想办法让小兔走到出口！"
    static let all = [notThisBlock, undoFirst, freeBunny]
}

enum KlotskiTutorial {
    static let kit = TutorialKit(
        game: "klotski",
        // 和 tools/voice/extra_klotski.json 的 lines 一模一样
        fixedLines: KlotskiLines.all,
        // 没写 drill 的题按规则配的通用说法（课文里每道题都写了 drill，这里是兜底）。不能提方向和位置。
        practicePrompts: [
            "move": "照着箭头，把发光的木块滑过去！",
            "far": "把发光的木块一直滑到头，滑到被挡住为止！",
            "at": "让发光的木块走到圈出来的格子！",
            "bunnyAt": "让小兔走到圈出来的格子！",
            "empty": "把圈出来的格子都空出来！",
            "free": KlotskiLines.freeBunny,
            "undo": "先滑一块木块，再点撤销！",
            "blocker": "点一块挡着小兔的木块！",
            "movable": "点一块现在能动的木块！",
            "stuck": "点一块现在动不了的木块！",
        ],
        // 同一道题能换成两种样子：原样，左右镜像（出口在正中间，镜像永远成立）
        practiceVariants: 2,
        practiceTransform: { steps, k in KlotskiMirror.steps(steps, k) },
        // 学完基础去入门组，学完让路去进阶组，学完多想几步去高手组
        playLevels: ["basic": 1, "space": 2, "plan": 3],
        goPlayLine: "这一组学完啦，去闯关吧！",
        goPlayTitle: "去闯关"
    )
}
