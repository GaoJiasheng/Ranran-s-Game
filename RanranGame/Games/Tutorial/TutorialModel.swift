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

    /// 需要预先生成配音的全部固定台词
    static var all: [String] {
        praise + [retry, showAnswer, wrongPick, illegal, notThisPiece, trackUnlocked, kingUnsafe, exposesKing,
                  foundOne, goKo, goNoLiberty]
    }
}

/// 教学进度：哪一课学完了，哪一组解锁了。存在 PlayerStore 里，跟着存档走。
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

    /// 第一组一直开着；后面每一组要等前一组全部学完
    func trackUnlocked(_ course: TutorialCourse, _ index: Int) -> Bool {
        index == 0 || trackDone(course, course.tracks[index - 1])
    }

    /// 推荐下一课：已解锁的组里第一节没学的
    func nextLesson(_ course: TutorialCourse) -> TutorialLesson? {
        for (i, t) in course.tracks.enumerated() where trackUnlocked(course, i) {
            if let l = t.lessons.first(where: { !lessonDone(course.game, $0.id) }) { return l }
        }
        return nil
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
