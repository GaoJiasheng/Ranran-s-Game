import Foundation

// 教学的数据：一门课（某个游戏）→ 几组（基础、进攻……）→ 每组几课 → 每课几步。
// 内容写在 Tutorials/<游戏>.json 里，这里只管读进来、记进度、判断解锁。

struct TutorialCourse: Codable {
    var game: String
    var title: String
    var tracks: [TutorialTrack]

    var lessons: [TutorialLesson] { tracks.flatMap(\.lessons) }

    static func load(_ game: String, bundle: Bundle = .main) -> TutorialCourse? {
        guard let url = bundle.url(forResource: game, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(TutorialCourse.self, from: data)
        } catch {
            #if DEBUG
            print("教学内容读不出来：\(game).json — \(error)")
            #endif
            return nil
        }
    }
}

struct TutorialTrack: Codable, Identifiable {
    var id: String
    var title: String
    var subtitle: String
    var art: String
    var lessons: [TutorialLesson]
}

struct TutorialLesson: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var icon: String
    /// 学完这一课学会了什么，结束时说给她听
    var learned: String
    var steps: [TutorialStep]
}

struct TutorialStep: Codable, Hashable {
    /// 老师说的话（有配音）
    var say: String
    /// 新的局面；没有就接着上一步的棋盘
    var board: String?
    /// 棋盘上的标记，比如 "glow:e5"、"label:c3:A"、"arrow:b0:c2"、"palace:red"
    var marks: [String]?
    var task: TutorialTask?
    /// 做错时的提示（有配音）
    var hint: String?
    /// 做对时说的话；没有就用通用的夸奖
    var ok: String?
    /// 做对后对手接着走的棋："block"（五子棋：堵住）、"engine"（象棋：电脑应一步），或者具体的着法
    var reply: [String]?
    /// 对手走完之后老师再说一句
    var after: String?
    /// 围棋：循环这一步（叫吃 → 对方逃），直到这个点上的白棋被吃掉才往下走（征子、枷这种步数不固定的）
    var loop: String?
    /// 练习模式里的题目说明（有配音）。练习时局面会随机镜像、旋转，所以这句话不能提方向（左右上下）和 A/B 标签。
    /// 不写就用按 task.rule 配的通用说法；没有 rule 又没写这句的题，练习模式里不出。
    var drill: String?
    /// 各游戏自己用的其他内容（后来加的游戏放这里，不用再改这个结构）
    var extra: [String: String]?
}

struct TutorialTask: Codable, Hashable {
    /// place（五子棋落子）、move（象棋走子）、pick（点一个地方回答问题）
    var type: String
    /// 判断规则，比如 five、block、winIn:2、mate、mate2、capture、escape:king……
    var rule: String?
    /// 直接列出的正确答案（落点、着法或要点的位置）
    var accept: [String]?
    /// 象棋：只能动这个子
    var piece: String?
    /// 各游戏自己用的其他内容
    var extra: [String: String]?
}

/// 老师的通用台词（都有配音）
enum TutorLines {
    static let praise = ["对啦！", "真棒！", "就是这样！", "太厉害了！", "完全正确！"]
    static let retry = "再想一想。"
    static let showAnswer = "看，亮起来的就是答案，你来试一下。"
    static let wrongPick = "不是这个哦，再看看。"
    static let illegal = "这个子不能这样走哦。"
    static let notThisPiece = "这一步要动发光的那个子。"
    static func lessonDone(_ learned: String) -> String { "这一课学完啦！你学会了\(learned)。" }
    static let trackUnlocked = "新的一组课程解锁啦！"
    static let foundOne = "找到一个，还有呢？"
    static let goKo = "打劫的时候，被提的一方要先在别处下一手，才能提回来。"
    static let goNoLiberty = "这里下进去一口气都没有，是禁入点。"
    static let kingUnsafe = "帅走到这里会被吃掉，或者和将面对面，不可以。"
    static let exposesKing = "走了这一步，帅就会被吃掉，不可以。"

    // 小奖杯：学完一课时按"一次就做对"的题数给金 / 银 / 铜
    static let cupGold = "每一题都是一次做对，拿到金杯啦！"
    static let cupSilver = "拿到银杯！每一题都一次做对，就能拿金杯。"
    static let cupBronze = "拿到铜杯！再来一次，争取拿金杯。"
    // 练一练、复习
    static let practiceDone = "练完啦，真棒！"
    static let reviewDone = "复习完啦，记得真牢！"
    static let goPlay = "这一组学完啦，去和小伙伴下一盘吧！"
    // 走错了以后，先让她看看会发生什么（各个游戏一句）
    static let gomokuWhiteFive = "看，白棋连成五颗了。"
    static let gomokuWhiteOpenFour = "看，白棋变成活四，堵不住了。"
    static let goWhiteEscaped = "看，白棋逃掉了。"
    static let goBlackCaptured = "看，黑子被吃掉了。"
    static let xiangqiCaptured = "看，被黑方吃掉了。"
    static let xiangqiKingEscaped = "看，黑将逃走了。"

    /// 不分游戏的固定台词（tools/voice/build_manifest.py 里的 COMMON 要和它一致）
    static var common: [String] {
        praise + [retry, showAnswer, wrongPick, illegal, notThisPiece, trackUnlocked,
                  foundOne, cupGold, cupSilver, cupBronze, practiceDone, reviewDone, goPlay,
                  gomokuWhiteFive, gomokuWhiteOpenFour]
            + PracticePrompts.gomoku.values.sorted()
    }

    /// 象棋的固定台词：车 / 相 / 将 要按象棋的读音配（build_manifest.py 里的 COMMON_XIANGQI）
    static var xiangqi: [String] {
        [kingUnsafe, exposesKing, xiangqiCaptured, xiangqiKingEscaped] + PracticePrompts.xiangqi.values.sorted()
    }

    /// 围棋的固定台词：术语按围棋的读音配（build_manifest.py 里的 COMMON_GO）
    static var go: [String] {
        [goKo, goNoLiberty, goWhiteEscaped, goBlackCaptured] + PracticePrompts.go.values.sorted()
    }

    /// 需要预先生成配音的全部固定台词
    static var all: [String] {
        // 后来加的游戏：固定台词、练习的通用说法、学完一组去玩的那句，都要配音
        let kits = TutorialKits.all.flatMap { $0.fixedLines + $0.practicePrompts.values.sorted() + [$0.goPlayLine].compactMap { $0 } }
        return common + xiangqi + go + kits
    }
}

// MARK: - 小奖杯（金 / 银 / 铜）

/// 一课学得怎么样：铜杯 = 学完了，银杯 = 大部分题一次就做对，金杯 = 每一题都一次做对。
/// 叫"小奖杯"。拿到奖杯会发星星（铜 1、银 2、金 3，杯子变好了补差额），规矩在 RewardRules，
/// 学完时由 LessonScaffold 调 PlayerStore.payLessonStars 发。
enum LessonCup: Int, Comparable, CaseIterable {
    case bronze = 1, silver = 2, gold = 3

    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    /// tasks 道题里 firstTry 道一次就做对
    static func earned(tasks: Int, firstTry: Int) -> LessonCup {
        if firstTry >= tasks { return .gold }
        return firstTry * 2 > tasks ? .silver : .bronze
    }

    var name: String {
        switch self {
        case .gold: "金杯"
        case .silver: "银杯"
        case .bronze: "铜杯"
        }
    }

    var line: String {
        switch self {
        case .gold: TutorLines.cupGold
        case .silver: TutorLines.cupSilver
        case .bronze: TutorLines.cupBronze
        }
    }
}

/// 一课是正常上课、练一练（打乱方向再做一遍），还是课程表上的「复习」
enum LessonMode: Hashable {
    case lesson
    /// 练习哪一课
    case practice(String)
    case review

    var isLesson: Bool { self == .lesson }
}

/// 教学进度：哪一课学完了，哪一组解锁了。存在 PlayerStore 里，跟着存档走。
/// 计数的名字：
///   tutor.<游戏>.<课>           学完几次（> 0 就是学完了）
///   tutor.cup.<游戏>.<课>       最好的小奖杯 1 铜 2 银 3 金（老存档里学完却没有记录的，算铜杯）
///   tutor.practice.<游戏>.<课>  练一练做完几次
///   tutor.open.<游戏>.<组>      这一组打开过（以后加了新课也不会再锁上）
///   tutor.review.<游戏>         复习做完几次；tutor.reviewDay.<游戏> 最近一次复习是哪一天
extension PlayerStore {
    func lessonDone(_ game: String, _ lesson: String) -> Bool { count("tutor.\(game).\(lesson)") > 0 }

    func markLessonDone(_ game: String, _ lesson: String) {
        increment("tutor.\(game).\(lesson)")
    }

    func lessonsDone(_ course: TutorialCourse) -> Int {
        course.lessons.filter { lessonDone(course.game, $0.id) }.count
    }

    func trackDone(_ course: TutorialCourse, _ track: TutorialTrack) -> Bool {
        track.lessons.allSatisfy { lessonDone(course.game, $0.id) }
    }

    /// 第一组一直开着；后面每一组要等前一组全部学完。
    /// 打开过的组一直开着；哪一组里有学完的课，这一组和它前面的组也都开着——后来加了新课也不会把学过的组锁回去。
    func trackUnlocked(_ course: TutorialCourse, _ index: Int) -> Bool {
        guard course.tracks.indices.contains(index) else { return false }
        if index == 0 || count("tutor.open.\(course.game).\(course.tracks[index].id)") > 0 { return true }
        if trackDone(course, course.tracks[index - 1]) { return true }
        return course.tracks[index...].contains { t in t.lessons.contains { lessonDone(course.game, $0.id) } }
    }

    /// 把现在开着的组记下来（进课程表、学完一课时调用）
    func rememberOpenTracks(_ course: TutorialCourse) {
        for (i, t) in course.tracks.enumerated() where i > 0 {
            let key = "tutor.open.\(course.game).\(t.id)"
            if count(key) == 0, trackUnlocked(course, i) { setCount(key, 1) }
        }
    }

    /// 推荐下一课：已解锁的组里第一节没学的
    func nextLesson(_ course: TutorialCourse) -> TutorialLesson? {
        for (i, t) in course.tracks.enumerated() where trackUnlocked(course, i) {
            if let l = t.lessons.first(where: { !lessonDone(course.game, $0.id) }) { return l }
        }
        return nil
    }

    // MARK: 小奖杯

    /// 这一课最好的小奖杯；没学完是 nil
    func lessonCup(_ game: String, _ lesson: String) -> LessonCup? {
        guard lessonDone(game, lesson) else { return nil }
        return LessonCup(rawValue: count("tutor.cup.\(game).\(lesson)")) ?? .bronze
    }

    /// 学完一课：记一次学完，奖杯只往上换。返回这次是不是比以前的好。
    /// 只记奖杯，不发星星；星星另外用 payLessonStars（Core/Rewards）按最好的奖杯补发。
    @discardableResult
    func recordLesson(_ game: String, _ lesson: String, cup: LessonCup) -> Bool {
        let key = "tutor.cup.\(game).\(lesson)"
        let before = lessonDone(game, lesson) ? max(count(key), 1) : 0
        markLessonDone(game, lesson)
        guard cup.rawValue > before else { return false }
        setCount(key, cup.rawValue)
        return true
    }

    /// 一门课里金 / 银 / 铜各几个
    func cupCounts(_ course: TutorialCourse) -> [LessonCup: Int] {
        var out: [LessonCup: Int] = [:]
        for l in course.lessons { if let c = lessonCup(course.game, l.id) { out[c, default: 0] += 1 } }
        return out
    }

    // MARK: 练一练、复习

    func practiceCount(_ game: String, _ lesson: String) -> Int { count("tutor.practice.\(game).\(lesson)") }

    func recordPractice(_ game: String, _ lesson: String) { increment("tutor.practice.\(game).\(lesson)") }

    func reviewCount(_ game: String) -> Int { count("tutor.review.\(game)") }

    /// 今天是第几天（从 2001 年起算，存成整数跟着存档走）
    static func dayNumber(_ date: Date = Date()) -> Int {
        Calendar.current.dateComponents([.day], from: Date(timeIntervalSinceReferenceDate: 0),
                                        to: Calendar.current.startOfDay(for: date)).day ?? 0
    }

    func recordReview(_ game: String) {
        increment("tutor.review.\(game)")
        setCount("tutor.reviewDay.\(game)", Self.dayNumber())
    }

    /// 上次复习是几天前；没复习过是 nil
    func daysSinceReview(_ game: String) -> Int? {
        guard reviewCount(game) > 0 else { return nil }
        return max(0, Self.dayNumber() - count("tutor.reviewDay.\(game)"))
    }
}

/// 打开一课（正常上课、练一练、复习）。练习题每次随机出，所以每次打开都是新的一个。
struct LessonRoute: Hashable, Identifiable {
    let lesson: TutorialLesson
    let mode: LessonMode
    let id = UUID()

    static func lesson(_ l: TutorialLesson) -> LessonRoute { LessonRoute(lesson: l, mode: .lesson) }

    /// 这一课的「练一练」；没有能练的题就是 nil
    static func practice(_ l: TutorialLesson, game: String) -> LessonRoute? {
        LessonPractice.practiceLesson(l, game: game).map { LessonRoute(lesson: $0, mode: .practice(l.id)) }
    }

    /// 课程表上的「复习」：从学完的课里抽 5 道
    static func review(_ course: TutorialCourse, store: PlayerStore) -> LessonRoute? {
        LessonPractice.reviewLesson(course, cups: store.cups(course)).map { LessonRoute(lesson: $0, mode: .review) }
    }
}

extension TutorialCourse {
    /// 学完一组以后「去下一盘」选哪一档。按每个游戏的档位说明配：
    /// 五子棋 3 档开始认真防守、5 档会自己进攻；象棋 1 档乱走、3 档会保护子；围棋 1–3 档是吃子棋，4 档起是正式对局。
    /// 以后新加的组没写在这里的，按第几组往上加两档。
    static let playLevels: [String: [String: Int]] = [
        "gomoku": ["basic": 1, "attack": 3, "defense": 5, "master": 7],
        "xiangqi": ["basic": 1, "tactics": 3, "material": 4, "opening": 5, "endgame": 6],
        "go": ["basic": 1, "capture": 2, "connect": 3, "life": 4, "opening": 4, "endgame": 5],
    ]

    func playLevel(after track: TutorialTrack) -> Int {
        if let n = Self.playLevels[game]?[track.id] ?? TutorialKits.find(game)?.playLevels[track.id] { return n }
        let i = tracks.firstIndex { $0.id == track.id } ?? 0
        return min(10, 1 + i * 2)
    }

    func track(of lessonID: String) -> TutorialTrack? {
        tracks.first { $0.lessons.contains { $0.id == lessonID } }
    }

    func lesson(_ id: String) -> TutorialLesson? { lessons.first { $0.id == id } }

    /// 有教学的游戏，按主页的顺序
    static let games: [String] = ["gomoku", "xiangqi", "go"] + TutorialKits.all.map(\.game)

    /// App 里自带的课（读一次就记住；给「我的」、奖章、复盘里的「复习这一课」用）
    static let bundled: [String: TutorialCourse] = Dictionary(uniqueKeysWithValues:
        games.compactMap { g in load(g).map { (g, $0) } })

    /// 能进「复习」：学完的课里有能练的题
    func canReview(_ store: PlayerStore) -> Bool {
        lessons.contains { store.lessonDone(game, $0.id) && LessonPractice.canPractice($0, game: game) }
    }
}

extension PlayerStore {
    /// 这一门课每一课的奖杯（没学完的不在里面）
    func cups(_ course: TutorialCourse) -> [String: LessonCup] {
        var out: [String: LessonCup] = [:]
        for l in course.lessons { if let c = lessonCup(course.game, l.id) { out[l.id] = c } }
        return out
    }
}

/// 解析 "kind:arg1:arg2" 形式的标记
struct MarkSpec {
    let kind: String
    let args: [String]

    init(_ s: String) {
        let parts = s.split(separator: ":").map(String.init)
        kind = parts.first ?? ""
        args = Array(parts.dropFirst())
    }
}
