import Foundation

/// 「加减乘除」里固定的英文短句。都预先录了音（见 tools/storybank），
/// 改这里的文字以后要重新生成题库和配音清单。
enum StoryVoiceLines {
    static let firstTry = ["Correct!", "Well done!", "Great thinking!", "You got it!"]
    static let laterTry = ["That's right!", "Yes, you got it!"]
    static func streak(_ n: Int) -> String { "\(n) in a row! Amazing!" }
    static let actIt = "Let's act it out!"
    static let drawIt = "Let's draw a model!"
    static func answerIs(_ n: Int) -> String { "The answer is \(n)." }
    static let lookTogether = "Let's look at it together."
    /// 一关做完以后，第一次答错的题再做一遍之前说
    static let retryIntro = "Let's try the tricky ones again."

    // 100 以内：没法演的时候，数十和一
    static let tensIt = "Let's count tens and ones!"

    // 两步题分两问做
    /// 第一问答完，接着问最后的问题
    static let nextQuestion = "Now the next question."
    /// 第一问答错、又没有对应解释时
    static let stepGeneric = "Read the first question again. What does it ask?"

    // 读题关：算之前先选算式
    static let chooseOp = "What do we do? Tap the number sentence."
    static let chooseFirst = "What do we do first? Tap the number sentence."
    static let chooseRight = "Yes! Now work it out."
    static let nudgeAltogether = "Altogether means we put the parts together. So we add."
    static let nudgePart = "We know the whole and one part. Take away to find the other part."
    static let nudgeGain = "Getting more makes more. So we add."
    static let nudgeLose = "Some went away, so there are fewer now. So we take away."
    static let nudgeCompare = "To find the difference, take away the smaller number from the bigger one."
    static let nudgeIsMore = "Read it again. Is the answer more or less? This one is more, so we add."
    static let nudgeIsLess = "Read it again. Is the answer more or less? This one is less, so we take away."
    static let nudgeTimes = "These are equal groups. So we use times."
    static let nudgeShare = "We share them equally, so we divide."
    static let nudgeGroups = "We put the same number in each group, so we divide."
    static let nudgeFirst = "What do we need to find first? Read the story again."

    static var nudges: [String] {
        [nudgeAltogether, nudgePart, nudgeGain, nudgeLose, nudgeCompare, nudgeIsMore, nudgeIsLess,
         nudgeTimes, nudgeShare, nudgeGroups, nudgeFirst]
    }

    static var all: [String] {
        firstTry + laterTry + (3...20).map(streak) + [actIt, drawIt, lookTogether, retryIntro] + (0...120).map(answerIs)
            + [tensIt, nextQuestion, stepGeneric, chooseOp, chooseFirst, chooseRight] + nudges
    }
}
