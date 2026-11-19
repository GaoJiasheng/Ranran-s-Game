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

    static var all: [String] {
        firstTry + laterTry + (3...20).map(streak) + [actIt, drawIt, lookTogether] + (0...120).map(answerIs)
    }
}
