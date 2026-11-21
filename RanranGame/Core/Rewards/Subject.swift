import SwiftUI

// 科目、毕业线、本领奖章。
// 一个"科目"就是冉冉要学会的一样本领（五子棋、象棋、围棋、加减乘除……）。
// 每个科目说清楚三件事：星星记在哪、学会要做到什么（毕业线）、路上有哪些本领奖章。
// 以后加新游戏，在 Subjects.all 里加一项就行，主页、奖章墙、「我的」都会自动带上它。

/// 做到了多少
struct RewardProgress: Hashable {
    var done: Int
    var total: Int

    init(_ done: Int, _ total: Int) {
        self.total = max(total, 1)
        self.done = min(max(done, 0), self.total)
    }

    var complete: Bool { done >= total }
    var fraction: Double { Double(done) / Double(total) }
}

/// 毕业线里的一条目标
struct SubjectGoal: Identifiable, Hashable {
    let id: String
    /// 比如"课程拿到银杯以上"
    let title: String
    var progress: RewardProgress
}

/// 一枚本领奖章：学会了一样具体的东西就拿到，和星星多少没关系。
struct SkillBadge: Identifiable {
    enum Kind { case track, opponent, chapter, graduate, habit }

    /// 存档里用的名字，永远不变，比如 "xiangqi.track.material"
    let id: String
    /// 属于哪个科目
    let subject: String
    let kind: Kind
    let name: String
    /// 怎么拿到，一句话
    let how: String
    /// 图片名（Assets 里的）
    let art: String
    let tint: Color
    let progress: (PlayerStore) -> RewardProgress
}

extension SkillBadge: Hashable {
    static func == (a: SkillBadge, b: SkillBadge) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// 一个科目
struct Subject: Identifiable {
    let id: String
    let name: String
    /// 主页卡片上的那张插画
    let art: String
    let tint: Color
    /// 主页上从哪张卡片进去；不是游戏的（好习惯）是 nil
    let entry: GameEntry?
    /// 这个科目的星星计数都以它开头
    let starPrefix: String
    /// 学会了叫什么，比如"象棋小棋手"
    let graduateName: String
    /// 毕业线：全部做到就算学会了。没有毕业线的科目是空的。
    let goals: (PlayerStore) -> [SubjectGoal]
    /// 这个科目的本领奖章，按拿到的先后顺序排
    let badges: [SkillBadge]
}

extension Subject: Hashable {
    static func == (a: Subject, b: Subject) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - 登记在册的科目

enum Subjects {
    /// 要学会的本领，按主页的顺序
    static let all: [Subject] = [
        .board(id: "gomoku", name: "五子棋", art: "card_gomoku", tint: Palette.coral, entry: .gomoku,
               graduateName: "五子棋小高手", graduateLevel: 5),
        .board(id: "xiangqi", name: "象棋", art: "card_xiangqi", tint: Color(hex: 0xC9624F), entry: .xiangqi,
               graduateName: "象棋小棋手", graduateLevel: 4),
        .board(id: "go", name: "围棋", art: "card_go", tint: Color(hex: 0x6FA07A), entry: .go,
               graduateName: "围棋小棋手", graduateLevel: 5),
        math,
    ]

    /// 「今天的三颗星」：不是一门课，没有毕业线，只有坚持了多少天的奖章
    static let habit = Subject(
        id: "daily", name: "好习惯", art: "badge_daily", tint: Palette.honey, entry: nil,
        starPrefix: "daily.stars.", graduateName: "",
        goals: { _ in [] },
        badges: [(3, "小种子"), (7, "发芽啦"), (14, "开花啦"), (30, "小树长大了")].map { days, name in
            SkillBadge(id: "daily.days.\(days)", subject: "daily", kind: .habit, name: name,
                       how: "做完 \(days) 天「今天的三颗星」", art: "badge_habit_\(days)", tint: Palette.honey,
                       progress: { RewardProgress($0.dailyDays, days) })
        })

    /// 全部（科目 + 好习惯）
    static let everything: [Subject] = all + [habit]

    static func find(_ id: String) -> Subject? { everything.first { $0.id == id } }

    static var allBadges: [SkillBadge] { everything.flatMap(\.badges) }

    // MARK: 加减乘除

    /// 每一章的本领奖章用哪张小贴纸
    private static let chapterArt: [StoryChapter: String] = [
        .together: "item_apple", .partWhole: "item_cookie", .compare: "item_pencil", .moreFewer: "item_balloon",
        .giving: "item_candy", .groups: "item_basket", .sharing: "item_strawberry", .hundred: "item_sticker",
        .twoSteps: "item_carrot", .challenge: "item_plate",
    ]

    static let math: Subject = {
        let id = "math"
        let graduate = "数学小能手"
        let goals: (PlayerStore) -> [SubjectGoal] = { store in
            [SubjectGoal(id: "math.levels", title: "通过全部 \(StoryLevel.all.count) 关",
                         progress: RewardProgress(StoryLevel.all.filter(store.storyPassed).count, StoryLevel.all.count))]
        }
        var badges = StoryChapter.allCases.map { chapter in
            SkillBadge(id: "math.chapter.\(chapter.rawValue)", subject: id, kind: .chapter, name: chapter.title,
                       how: "通过这一章的 \(chapter.levels.count) 关", art: chapterArt[chapter] ?? "item_apple",
                       tint: chapter.tint,
                       progress: { store in
                           RewardProgress(chapter.levels.filter(store.storyPassed).count, chapter.levels.count)
                       })
        }
        badges.append(graduateBadge(subject: id, name: graduate, tint: Color(hex: 0x5FA3C9), goals: goals))
        return Subject(id: id, name: "加减乘除", art: "card_math", tint: Color(hex: 0x5FA3C9), entry: .story,
                       starPrefix: "wp.stars.", graduateName: graduate, goals: goals, badges: badges)
    }()

    /// 毕业奖章：毕业线上的每一条都做到
    static func graduateBadge(subject: String, name: String, tint: Color,
                              goals: @escaping (PlayerStore) -> [SubjectGoal]) -> SkillBadge {
        SkillBadge(id: "\(subject).graduate", subject: subject, kind: .graduate, name: name,
                   how: "把「\(name)」的目标全部做到", art: "badge_grad_\(subject)", tint: tint,
                   progress: { store in
                       let g = goals(store)
                       return RewardProgress(g.reduce(0) { $0 + $1.progress.done }, g.reduce(0) { $0 + $1.progress.total })
                   })
    }
}

extension Subject {
    /// 一种棋：有教学课程（Tutorials/<id>.json）和十档电脑对手的，都能这样登记。
    /// 毕业线 = 每一课都拿到银杯以上 + 赢到第 graduateLevel 档。
    /// 本领奖章 = 学完每一组课 + 打败每一位小伙伴 + 毕业。
    static func board(id: String, name: String, art: String, tint: Color, entry: GameEntry,
                      graduateName: String, graduateLevel: Int) -> Subject {
        let course = TutorialCourse.bundled[id]
        let lessons = course?.lessons ?? []
        let goals: (PlayerStore) -> [SubjectGoal] = { store in
            var out: [SubjectGoal] = []
            if !lessons.isEmpty {
                let good = lessons.filter { (store.lessonCup(id, $0.id) ?? .bronze) >= .silver }.count
                out.append(SubjectGoal(id: "\(id).lessons", title: "\(lessons.count) 节课都拿到银杯或金杯",
                                       progress: RewardProgress(good, lessons.count)))
            }
            out.append(SubjectGoal(id: "\(id).level", title: "赢到第 \(graduateLevel) 档",
                                   progress: RewardProgress(store.topCleared(id), graduateLevel)))
            return out
        }
        var badges: [SkillBadge] = (course?.tracks ?? []).map { track in
            SkillBadge(id: "\(id).track.\(track.id)", subject: id, kind: .track, name: track.title,
                       how: "学完「\(track.title)」的 \(track.lessons.count) 节课", art: track.art, tint: tint,
                       progress: { store in
                           RewardProgress(track.lessons.filter { store.lessonDone(id, $0.id) }.count, track.lessons.count)
                       })
        }
        badges += Opponent.allCases.map { o in
            let range = o.levels
            let how = range.count == 1 ? "赢下第 \(range.lowerBound) 档" : "赢到第 \(range.upperBound) 档"
            return SkillBadge(id: "\(id).beat.\(o.rawValue)", subject: id, kind: .opponent, name: "打败\(o.name)",
                              how: how, art: o.image, tint: o.tint,
                              progress: { store in
                                  RewardProgress(store.topCleared(id) - range.lowerBound + 1, range.count)
                              })
        }
        badges.append(Subjects.graduateBadge(subject: id, name: graduateName, tint: tint, goals: goals))
        return Subject(id: id, name: name, art: art, tint: tint, entry: entry, starPrefix: "\(id).stars.",
                       graduateName: graduateName, goals: goals, badges: badges)
    }
}

// MARK: - 存档里的进度

extension PlayerStore {
    /// 这个科目一共拿了多少星星
    func stars(in subject: Subject) -> Int { stars(prefix: subject.starPrefix) }

    /// 离学会还差多少：毕业线上每一条目标加起来
    func progress(of subject: Subject) -> RewardProgress {
        let g = subject.goals(self)
        return RewardProgress(g.reduce(0) { $0 + $1.progress.done }, g.reduce(0) { $0 + $1.progress.total })
    }

    /// 这个科目学会了（没有毕业线的不算）
    func graduated(_ subject: Subject) -> Bool {
        let g = subject.goals(self)
        return !g.isEmpty && g.allSatisfy(\.progress.complete)
    }

    func badgeEarned(_ badge: SkillBadge) -> Bool { badge.progress(self).complete }

    func earnedBadges(in subject: Subject) -> [SkillBadge] { subject.badges.filter(badgeEarned) }

    var earnedBadgeCount: Int { Subjects.allBadges.filter(badgeEarned).count }

    /// 拿到了、还没庆祝过的本领奖章
    var pendingBadges: [SkillBadge] { Subjects.allBadges.filter { badgeEarned($0) && !badgeSeen($0.id) } }

    /// 把存档对齐到现在的规矩（每次启动、导入存档后都跑，可以重复跑）：
    /// 1. 以前上课不给星星：已经拿到的小奖杯补发；
    /// 2. 以前没有"第一次赢下一档"的加奖：赢过的档补发；
    /// 3. 第一次跑的时候，已经够条件的本领奖章直接算看过，和补发的星星一起在主页说一次（pendingGift），不一枚一枚弹。
    func syncRewards() {
        var paid = 0
        for (game, course) in TutorialCourse.bundled {
            for lesson in course.lessons {
                if let cup = lessonCup(game, lesson.id) {
                    paid += payLessonStars(game: game, lesson: lesson.id, cup: cup.rawValue)
                }
            }
        }
        for subject in Subjects.all where TutorialCourse.bundled[subject.id] != nil {
            for level in 1...10 where count("\(subject.id).best.\(level)") > 0 && count("\(subject.id).stars.first.\(level)") == 0 {
                earnStars(RewardRules.firstWinBonus, key: "\(subject.id).stars.first.\(level)")
                paid += RewardRules.firstWinBonus
            }
        }
        guard count("rewards.v1") == 0 else { return }
        let earned = Subjects.allBadges.filter(badgeEarned)
        for b in earned { markBadgeSeen(b.id) }
        if paid > 0 { setCount("rewards.gift", paid) }
        if !earned.isEmpty { setCount("rewards.giftBadges", earned.count) }
        setCount("rewards.v1", 1)
    }
}
