import SwiftUI

// 界面看奖励用的"镜头"：主页、奖章墙、庆祝都从这里读进度，不直接问 PlayerStore。
// 这样调试时（-rewardDemo / -dailyDemo）可以只在显示上假装一个状态，存档一个字都不改。

/// 奖章墙上的一页。"stars" 是星星奖章，其余是科目的 id（好习惯是 "daily"）。
struct WallTab: Identifiable, Hashable {
    let id: String

    static let stars = WallTab(id: "stars")
    static let daily = WallTab(id: Subjects.habit.id)
    static func subject(_ s: Subject) -> WallTab { WallTab(id: s.id) }

    /// 顶上的页签：星星奖章 + 每个科目（以后加了新科目自动多一页）
    static var all: [WallTab] { [.stars] + Subjects.everything.map(WallTab.subject) }

    /// 奖章墙上现在显示的页签：家长从主页收起来的游戏，一枚奖章都还没拿到的就不占一页；拿到过的照样留着
    static func shown(_ store: PlayerStore) -> [WallTab] {
        let lens = store.rewards
        return [.stars] + Subjects.everything.filter { s in
            guard let entry = s.entry, !store.isOnHome(entry) else { return true }
            return lens.earnedCount(in: s) > 0
        }.map(WallTab.subject)
    }

    var subject: Subject? { Subjects.find(id) }
}

struct RewardLens {
    let store: PlayerStore
    #if DEBUG
    /// -rewardDemo YES：假装各科学到一半
    var demo = false
    /// -dailyDemo N：假装今天做了 N 样
    var dailyDemo: Int?
    #endif

    // MARK: 本领奖章

    func progress(_ badge: SkillBadge) -> RewardProgress {
        #if DEBUG
        if demo { return demoProgress(badge) }
        #endif
        return badge.progress(store)
    }

    func earned(_ badge: SkillBadge) -> Bool { progress(badge).complete }

    func earnedCount(in subject: Subject) -> Int { subject.badges.filter(earned).count }

    var earnedBadgeCount: Int {
        #if DEBUG
        if demo { return Subjects.allBadges.filter(earned).count }
        #endif
        return store.earnedBadgeCount
    }

    // MARK: 毕业线

    func goals(_ subject: Subject) -> [SubjectGoal] {
        #if DEBUG
        if demo {
            let f = Self.demoFraction(subject.id)
            return subject.goals(store).map { g in
                var g = g
                g.progress = RewardProgress(Int((Double(g.progress.total) * f).rounded()), g.progress.total)
                return g
            }
        }
        #endif
        return subject.goals(store)
    }

    func progress(of subject: Subject) -> RewardProgress {
        let g = goals(subject)
        return RewardProgress(g.reduce(0) { $0 + $1.progress.done }, g.reduce(0) { $0 + $1.progress.total })
    }

    func graduated(_ subject: Subject) -> Bool {
        let g = goals(subject)
        return !g.isEmpty && g.allSatisfy(\.progress.complete)
    }

    func stars(in subject: Subject) -> Int {
        #if DEBUG
        if demo { return ["gomoku": 96, "xiangqi": 58, "go": 21, "math": 74, "daily": 27][subject.id] ?? 12 }
        #endif
        return store.stars(in: subject)
    }

    // MARK: 今天的三颗星

    func dailyDone(_ task: DailyTask) -> Bool {
        #if DEBUG
        if let n = dailyDemo { return (DailyTask.allCases.firstIndex(of: task) ?? 0) < n }
        #endif
        return store.dailyDone(task)
    }

    var dailyCount: Int { DailyTask.allCases.filter(dailyDone).count }
    var dailyComplete: Bool { dailyCount == DailyTask.allCases.count }

    var dailyDays: Int {
        #if DEBUG
        if demo { return 9 }
        #endif
        return store.dailyDays
    }

    // MARK: 调试用的假状态

    #if DEBUG
    /// 每科学到多少：五子棋已经学会，象棋一半多，围棋刚开始，加减乘除大半
    private static func demoFraction(_ id: String) -> Double {
        ["gomoku": 1, "xiangqi": 0.55, "go": 0.25, "math": 0.7][id] ?? 0.4
    }

    private func demoProgress(_ badge: SkillBadge) -> RewardProgress {
        let total = badge.progress(store).total
        if badge.kind == .graduate, let s = Subjects.find(badge.subject) { return progress(of: s) }
        if badge.kind == .habit { return RewardProgress(dailyDays, total) }
        guard let s = Subjects.find(badge.subject),
              let i = s.badges.firstIndex(of: badge) else { return RewardProgress(0, total) }
        let regular = s.badges.filter { $0.kind != .graduate }.count
        let earnedUpTo = Int((Double(regular) * Self.demoFraction(s.id)).rounded())
        if i < earnedUpTo { return RewardProgress(total, total) }
        // 下一枚做了一半，再往后的还没开始
        return RewardProgress(i == earnedUpTo ? max(1, total / 2) : 0, total)
    }
    #endif
}

extension PlayerStore {
    /// 界面上看奖励一律用它（调试参数在这里接上）
    var rewards: RewardLens {
        #if DEBUG
        let d = UserDefaults.standard
        let n = d.object(forKey: "dailyDemo") != nil ? min(max(d.integer(forKey: "dailyDemo"), 0), 3) : nil
        return RewardLens(store: self, demo: d.bool(forKey: "rewardDemo"), dailyDemo: n)
        #else
        return RewardLens(store: self)
        #endif
    }
}

extension SkillBadge {
    /// 庆祝的先后：毕业最重要，然后是打败小伙伴、学完一组课 / 一章，最后是好习惯
    var significance: Int {
        switch kind {
        case .graduate: 4
        case .opponent: 3
        case .track, .chapter: 2
        case .habit: 1
        }
    }

    /// 图片还没画好时用的 emoji
    var fallbackEmoji: String {
        switch kind {
        case .graduate: "🎓"
        case .opponent: "🏅"
        case .track: "📘"
        case .chapter: "✏️"
        case .habit: "🌱"
        }
    }
}
