import Foundation

// 全局奖励记在存档里的部分：发星星、今天的三颗星、还没庆祝的东西。
// 这个文件只用 PlayerStore 最基本的计数接口，不认识任何具体的游戏。

/// 赢一盘之后的结果
struct WinResult: Hashable {
    var reward: WinReward
    /// 是不是这一档的新纪录（星星比以前多）
    var isRecord: Bool
}

extension PlayerStore {
    /// 今天是第几天。测试里可以给各个函数另传一个 day。
    static var today: Int { dayNumber() }

    // MARK: 星星合计

    /// 名字以 prefix 开头的星星计数加起来（比如 "xiangqi.stars."）
    func stars(prefix: String) -> Int {
        counts.reduce(0) { $1.key.hasPrefix(prefix) ? $0 + $1.value : $0 }
    }

    // MARK: 上课

    /// 这一课已经发过几颗星
    func lessonStars(_ game: String, _ lesson: String) -> Int { count("\(game).stars.lesson.\(lesson)") }

    /// 一课拿到了 cup（1 铜 2 银 3 金）：把还没发的星星补上，返回这次发了几颗
    @discardableResult
    func payLessonStars(game: String, lesson: String, cup: Int) -> Int {
        let owed = RewardRules.lessonStars(cup: cup) - lessonStars(game, lesson)
        guard owed > 0 else { return 0 }
        earnStars(owed, key: "\(game).stars.lesson.\(lesson)")
        return owed
    }

    /// 今天这种棋的复习星星拿过了没有
    func reviewStarPaid(_ game: String, day: Int = PlayerStore.today) -> Bool {
        count("rewards.reviewDay.\(game)") == day
    }

    /// 做完一次复习：每种棋每天第一次给星星，返回这次发了几颗
    @discardableResult
    func payReviewStar(game: String, day: Int = PlayerStore.today) -> Int {
        guard !reviewStarPaid(game, day: day) else { return 0 }
        setCount("rewards.reviewDay.\(game)", day)
        earnStars(RewardRules.reviewStarsPerDay, key: "\(game).stars.review")
        return RewardRules.reviewStarsPerDay
    }

    // MARK: 和电脑下棋
    // 所有棋用同一套计数：<棋>.wins.<档> 赢了几盘，<棋>.best.<档> 最好几颗星，<棋>.stars.<档> 这一档一共拿的星星。

    /// 最高赢过第几档（没赢过是 0）
    func topCleared(_ game: String, levels: ClosedRange<Int> = 1...10) -> Int {
        levels.last { count("\(game).best.\($0)") > 0 } ?? 0
    }

    /// 今天在低档已经赢了几盘
    func lowWinsToday(_ game: String, day: Int = PlayerStore.today) -> Int {
        count("\(game).low.day") == day ? count("\(game).low.n") : 0
    }

    /// 现在去赢这一档能拿到什么（给选档位的页面和结果页预告用，不改存档）
    func winPreview(game: String, level: Int, earned: Int = 3, day: Int = PlayerStore.today) -> WinReward {
        RewardRules.win(earned: earned, level: level, topCleared: topCleared(game),
                        wonBefore: count("\(game).best.\(level)") > 0, lowWinsToday: lowWinsToday(game, day: day))
    }

    /// 赢了电脑一盘：记胜场、发星星（按 RewardRules 的规矩）、更新最好成绩。
    /// earned 是这盘本身挣到的 1~3 颗（赢 + 没悔棋 + 没用提示）。
    @discardableResult
    func recordWin(game: String, level: Int, earned: Int, day: Int = PlayerStore.today) -> WinResult {
        let reward = winPreview(game: game, level: level, earned: earned, day: day)
        if reward.low {
            let n = lowWinsToday(game, day: day)
            setCount("\(game).low.day", day)
            setCount("\(game).low.n", n + 1)
        }
        increment("\(game).wins.\(level)")
        earnStars(reward.base, key: "\(game).stars.\(level)")
        earnStars(reward.bonus, key: "\(game).stars.first.\(level)")
        let isRecord = earned > count("\(game).best.\(level)")
        if isRecord { setCount("\(game).best.\(level)", earned) }
        return WinResult(reward: reward, isRecord: isRecord)
    }

    // MARK: 今天的三颗星
    // daily.day 记的是哪一天；daily.<事> 这一天做了没有；daily.paid 这一天的加奖发了没有；
    // daily.days 一共做完过多少天（只增不减，断了也不清零）；daily.cheer 做完了还没在主页庆祝的那一天

    func dailyDone(_ task: DailyTask, day: Int = PlayerStore.today) -> Bool {
        count("daily.day") == day && count("daily.\(task.rawValue)") > 0
    }

    func dailyCount(day: Int = PlayerStore.today) -> Int {
        DailyTask.allCases.filter { dailyDone($0, day: day) }.count
    }

    func dailyComplete(day: Int = PlayerStore.today) -> Bool { dailyCount(day: day) == DailyTask.allCases.count }

    /// 一共做完过多少天「今天的三颗星」
    var dailyDays: Int { count("daily.days") }

    /// 做了一件事。三样刚好凑齐时发加奖并返回 true。
    @discardableResult
    func noteDaily(_ task: DailyTask, day: Int = PlayerStore.today) -> Bool {
        if count("daily.day") != day {
            setCount("daily.day", day)
            for t in DailyTask.allCases { setCount("daily.\(t.rawValue)", 0) }
            setCount("daily.paid", 0)
        }
        guard !dailyDone(task, day: day) else { return false }
        setCount("daily.\(task.rawValue)", 1)
        guard dailyComplete(day: day), count("daily.paid") == 0 else { return false }
        setCount("daily.paid", 1)
        increment("daily.days")
        setCount("daily.cheer", day)
        earnStars(RewardRules.dailyBonus, key: "daily.stars.bonus")
        return true
    }

    /// 今天的三颗星做完了，主页还没庆祝
    func dailyCheerPending(day: Int = PlayerStore.today) -> Bool { count("daily.cheer") == day }
    func clearDailyCheer() { if count("daily.cheer") != 0 { setCount("daily.cheer", 0) } }

    // MARK: 升级时补发的礼物（主页只说一次）

    /// 升级到有全局奖励的版本时，补发了多少星星、已经有几枚本领奖章；说过了就是 nil
    var pendingGift: (stars: Int, badges: Int)? {
        let s = count("rewards.gift"), b = count("rewards.giftBadges")
        return s > 0 || b > 0 ? (s, b) : nil
    }

    func clearGift() {
        if count("rewards.gift") != 0 { setCount("rewards.gift", 0) }
        if count("rewards.giftBadges") != 0 { setCount("rewards.giftBadges", 0) }
    }

    // MARK: 本领奖章看过没有

    func badgeSeen(_ id: String) -> Bool { count("badge.seen.\(id)") > 0 }
    func markBadgeSeen(_ id: String) { if !badgeSeen(id) { setCount("badge.seen.\(id)", 1) } }
}
