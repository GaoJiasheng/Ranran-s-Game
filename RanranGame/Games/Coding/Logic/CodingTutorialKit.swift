import Foundation

// 编程接进教学框架时要交代的东西：固定台词、练习说法、四种样子、学完一组去玩哪一组。见 docs/new-games.md。
// 每一句都要预先录好：这里的句子原样抄在 tools/voice/extra_coding.json 的 lines 里（测试会对一遍）。
// 带数字、会变的话（"用 6 块以内""第 2 次"）只显示不朗读，所以这里没有。

enum CodingLines {
    // 跑完没过关（闯关页面和教学都用）
    static let bump = "哎呀，撞到了！看看是哪一块让小兔撞上去的。"
    static let endCarrots = "指令做完了，还有胡萝卜没吃到。"
    static let endHome = "胡萝卜吃完了，可是小兔还没回到家。"
    static let dizzy = "小兔转晕了！它一直走，停不下来。"
    static let garden = "这个花园没过。同一个程序，换个花园就不对了，看看哪里不一样？"
    static let passed = "过关啦！小兔吃饱啦。"

    // 排积木的时候
    static let full = "这一栏满啦。点一块积木把它拿掉，再放新的。"
    static let notHere = "这一块不能放在这里哦。"

    // 提示：第一下说这一组的思路，第二下在程序里标出来
    static let ideaSeq = "先用手指在花园里比一比，小兔要往哪边走、走几格？"
    static let ideaLoop = "先找一找，哪几步是完全一样、连着出现好几次的？"
    static let ideaFunc = "看一看，路上有没有完全一样的一小段？把它排进绝招里。"
    static let ideaCond = "看一看几个花园哪里不一样。踩到花的时候，小兔要做什么？"
    static let ideaBug = "点「一步」，一步一步看，小兔是在哪一步走歪的？"
    static let ghost = "看，发光的影子就是下一块要放的积木。"
    static let wrongBlock = "圈出来的这一块不太对，点它拿掉，换一块试试。"
    static let bugBlock = "圈出来的就是有虫子的那一块，把它改对！"
    static let tryRun = "照现在的样子，点「开始」试试吧！"

    // 教学
    static let needLoop = "能过关！这一次要用上「重复」哦。"
    static let needProc = "能过关！这一次要用上绝招哦。"
    static let needIf = "能过关！这一次要用上「如果」哦。"
    static let needForever = "能过关！这一次要用上「一直重复」哦。"
    static let tooMany = "能过关！可是积木多了一点，想想能不能少用几块。"

    /// 练一练的通用说法（不提方向、位置、数字）
    static let practice: [String: String] = [
        "build": "排一个程序，带小兔吃到胡萝卜！",
        "fix": "程序里有一只小虫子，把它改对！",
        "predict": "点一点，小兔最后会站在哪儿？",
        "spot": "点出程序里错的那一块！",
        "choose": "哪一个程序能过关？点一下！",
        "count": "要几次才够？选一个！",
    ]

    static let all: [String] = [
        bump, endCarrots, endHome, dizzy, garden, passed,
        full, notHere,
        ideaSeq, ideaLoop, ideaFunc, ideaCond, ideaBug, ghost, wrongBlock, bugBlock, tryRun,
        needLoop, needProc, needIf, needForever, tooMany,
    ] + ["build", "fix", "predict", "spot", "choose", "count"].map { practice[$0]! }

    static func idea(pack: String, bug: Bool) -> String {
        if bug { return ideaBug }
        switch pack {
        case "loop": return ideaLoop
        case "func": return ideaFunc
        case "cond": return ideaCond
        default: return ideaSeq
        }
    }

    /// 没过关时说哪一句（好几个花园时，第二个起没过的说"这个花园没过"）
    static func failure(_ o: CodingOutcome, garden: Int, eatenAll: Bool) -> String {
        if garden > 0 { return CodingLines.garden }
        switch o {
        case .bump: return bump
        case .dizzy: return dizzy
        default: return eatenAll ? endHome : endCarrots
        }
    }

    static func need(_ token: String) -> String {
        switch token {
        case "rep": return needLoop
        case "S", "T": return needProc
        case "*": return needForever
        default: return needIf
        }
    }
}

enum CodingTutorial {
    static let kit = TutorialKit(
        game: "coding",
        // 和 tools/voice/extra_coding.json 的 lines 一模一样（练习的通用说法、去闯关那句由框架另外收集）
        fixedLines: CodingLines.all,
        practicePrompts: CodingLines.practice,
        // 一道题能换成四种样子：原样、左右翻、上下翻、都翻（花园、程序里的箭头、标记的格子一起翻）
        practiceVariants: 4,
        practiceTransform: { steps, k in CodingLessonLogic.flip(steps, k) },
        // 学完基础去「一步一步」，学完重复去「重复」……
        playLevels: ["basic": 1, "loop": 2, "func": 3, "cond": 4],
        goPlayLine: "这一组学完啦，去闯关吧！",
        goPlayTitle: "去闯关"
    )
}
