import Foundation

// 全局奖励的规矩，全 App 只有这一份。
//
// 星星只有一种，全 App 通用：主页右上角的总数 = 所有游戏里拿到的星星加起来。
// 每颗星都记在一个 "<科目>.stars.<哪里拿的>" 的计数上（见 PlayerStore.earnStars），所以随时能算出每一科拿了多少。
//
//   学一课（棋类教学）   铜杯 1 颗、银杯 2 颗、金杯 3 颗；杯子变好了补差额     <棋>.stars.lesson.<课>
//   复习                 每种棋每天第一次复习 1 颗                             <棋>.stars.review
//   和电脑下棋赢了       1~3 颗（赢 + 没悔棋 + 没用提示）                      <棋>.stars.<档>
//                        只有在"现在的水平"附近（最高赢过的档往下一档及以上）才给全额；
//                        更低的档每盘 1 颗，每天只有前 3 盘有
//   第一次赢下新的一档   另加 5 颗                                             <棋>.stars.first.<档>
//   加减乘除             每道题第一次"第一下就答对"1 颗（见 StoryModel）         wp.stars.<关>
//   今天的三颗星         学一课、算一组题、下一盘棋，三样都做了另加 3 颗        daily.stars.bonus
//
// 以后加新游戏：给它起一个科目名，星星记在 "<科目>.stars.…" 上，再在 Subjects 里登记一下，
// 奖章、毕业线、今天的三颗星就都认识它了。

enum RewardRules {
    /// 一课的小奖杯值几颗星（1 铜 2 银 3 金）
    static func lessonStars(cup: Int) -> Int { min(max(cup, 0), 3) }
    /// 每种棋每天第一次复习给几颗
    static let reviewStarsPerDay = 1
    /// 第一次赢下一档另外加几颗
    static let firstWinBonus = 5
    /// 比现在的水平低的档，每天前几盘有星星
    static let lowWinsPerDay = 3
    /// 今天的三颗星做完另外加几颗
    static let dailyBonus = 3

    /// 这一档算不算"比现在的水平低"：比最高赢过的档低两档以上
    static func isLow(level: Int, topCleared: Int) -> Bool { level < topCleared - 1 }

    /// 赢了一盘该给多少。
    /// - earned: 这盘本身挣到的 1~3 颗
    /// - topCleared: 这盘之前最高赢过第几档（没赢过是 0）
    /// - wonBefore: 这一档以前赢过没有
    /// - lowWinsToday: 今天已经在低档赢了几盘（不算这一盘）
    static func win(earned: Int, level: Int, topCleared: Int, wonBefore: Bool, lowWinsToday: Int) -> WinReward {
        let low = isLow(level: level, topCleared: topCleared)
        let base = low ? (lowWinsToday < lowWinsPerDay ? 1 : 0) : earned
        let left = low ? max(0, lowWinsPerDay - lowWinsToday - 1) : lowWinsPerDay
        return WinReward(base: base, bonus: wonBefore ? 0 : firstWinBonus, earned: earned, low: low, lowLeft: left)
    }
}

/// 赢一盘拿到的星星
struct WinReward: Hashable {
    /// 这盘给的星星（低档时最多 1 颗，可能是 0）
    var base: Int
    /// 第一次赢下这一档的加奖（没有是 0）
    var bonus: Int
    /// 这盘本身的表现：1~3（赢 + 没悔棋 + 没用提示），结果页上亮几颗星用它
    var earned: Int
    /// 这一档比现在的水平低，所以没给全额
    var low: Bool
    /// 今天低档还有几盘有星星
    var lowLeft: Int

    var total: Int { base + bonus }
}

/// 「今天的三颗星」里的一件事。以后加了新游戏，把它的活动算进其中一件就行。
enum DailyTask: String, CaseIterable, Identifiable {
    /// 学：上完一课，或者做完一次练一练 / 复习
    case learn
    /// 算：做完一组加减乘除（一关、练一练、错题本都算）
    case math
    /// 下：下完一盘棋（输赢都算，和家人下也算）
    case play

    var id: String { rawValue }

    var title: String {
        switch self {
        case .learn: "学一课"
        case .math:  "算一组题"
        case .play:  "下一盘棋"
        }
    }

    var icon: String {
        switch self {
        case .learn: "book.fill"
        case .math:  "plus.forwardslash.minus"
        case .play:  "circle.grid.3x3.fill"
        }
    }
}
