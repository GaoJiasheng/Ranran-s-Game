import Foundation

// 「练一练」和「复习」：把学过的题换个方向再出一遍，让她靠看懂局面、而不是靠记住点哪里来做对。
//
// 一段题 = 一个摆了新局面的步骤，加上后面接着在这个棋盘上下的步骤。同一段题用同一个随机变换：
// 五子棋、围棋是正方形棋盘的 8 种旋转 / 翻转；象棋只能左右镜像（红方要一直在下面）。
// 局面、标记、答案、对手的应着、loop、piece、规则里的点——所有写着位置的地方一起变。
// 课文里会说"左边""往上""A"，所以练习时不用课文，用每一步的 drill，或者按 task.rule 配的通用说法。

/// 棋盘的一种对称变换
struct LessonSymmetry: Hashable, CustomStringConvertible {
    let game: String
    /// 正方形棋盘的路数（象棋不用）
    let size: Int
    /// 0 不变；正方形 1…7 是各种旋转 / 翻转；象棋 1 是左右镜像
    let kind: Int

    static func identity(_ game: String, size: Int = 9) -> LessonSymmetry {
        LessonSymmetry(game: game, size: size, kind: 0)
    }

    /// 这种棋、这么大的棋盘能用的全部变换（第一个是不变）
    static func all(_ game: String, size: Int) -> [LessonSymmetry] {
        (0..<(game == "xiangqi" ? 2 : 8)).map { LessonSymmetry(game: game, size: size, kind: $0) }
    }

    var description: String { "\(game)#\(kind)" }

    private var xiangqi: Bool { game == "xiangqi" }

    func map(_ x: Int, _ y: Int) -> (Int, Int) {
        if xiangqi { return kind == 1 ? (8 - x, y) : (x, y) }
        let n = size - 1
        switch kind {
        case 1: return (n - x, y)
        case 2: return (x, n - y)
        case 3: return (n - x, n - y)
        case 4: return (y, x)
        case 5: return (n - y, x)
        case 6: return (y, n - x)
        case 7: return (n - y, n - x)
        default: return (x, y)
        }
    }

    /// "c3" → 变换后的点名；不是点名就返回 nil
    func square(_ name: String) -> String? {
        let scalars = Array(name.unicodeScalars)
        guard let first = scalars.first, first.value >= 97, first.value <= 122,
              scalars.count >= 2, let row = Int(String(name.dropFirst())),
              scalars.dropFirst().allSatisfy({ $0.value >= 48 && $0.value <= 57 }) else { return nil }
        let x = Int(first.value) - 97
        if xiangqi {
            guard scalars.count == 2, x < 9, row <= 9 else { return nil }
            let (mx, my) = map(x, row)
            return "\(Character(UnicodeScalar(UInt8(97 + mx))))\(my)"
        }
        guard x < size, row >= 1, row <= size else { return nil }
        let (mx, my) = map(x, row - 1)
        return "\(Character(UnicodeScalar(UInt8(97 + mx))))\(my + 1)"
    }

    /// 一个记号：点名、象棋的着法（"h2e2"），别的原样返回
    func token(_ t: String) -> String {
        if let s = square(t) { return s }
        if xiangqi, t.count == 4, let a = square(String(t.prefix(2))), let b = square(String(t.suffix(2))) { return a + b }
        return t
    }

    /// "kill:d4"、"label:c3:A"、"d6|f6"、"escape:e5"：按 | 和 : 拆开，每一段都变
    func spec(_ s: String) -> String {
        s.split(separator: "|", omittingEmptySubsequences: false).map { alt in
            alt.split(separator: ":", omittingEmptySubsequences: false).map { token(String($0)) }.joined(separator: ":")
        }.joined(separator: "|")
    }

    /// 局面：五子棋 / 围棋是 "size=9;b=c3,d4;w=e5"，象棋是 FEN
    func board(_ b: String) -> String {
        guard kind != 0 else { return b }
        if xiangqi {
            // FEN 每一行倒过来写就是左右镜像（数字表示连着几个空格，倒过来还是对的）
            let parts = b.split(separator: " ", maxSplits: 1)
            let rows = parts[0].split(separator: "/", omittingEmptySubsequences: false).map { String($0.reversed()) }
            return rows.joined(separator: "/") + (parts.count > 1 ? " " + parts[1] : "")
        }
        return b.split(separator: ";", omittingEmptySubsequences: false).map { part -> String in
            let kv = part.split(separator: "=", maxSplits: 1).map(String.init)
            guard kv.count == 2, kv[0].trimmingCharacters(in: .whitespaces) == "b" || kv[0].trimmingCharacters(in: .whitespaces) == "w" else {
                return String(part)
            }
            let list = kv[1].split(separator: ",").map { token($0.trimmingCharacters(in: .whitespaces)) }
            return kv[0] + "=" + list.joined(separator: ",")
        }.joined(separator: ";")
    }

    /// 一整步：所有写着位置的地方一起变
    func step(_ s: TutorialStep) -> TutorialStep {
        guard kind != 0 else { return s }
        var t = s
        t.board = s.board.map(board)
        t.marks = s.marks?.map(spec)
        t.reply = s.reply?.map(spec)
        t.loop = s.loop.map(token)
        if var task = s.task {
            task.accept = task.accept?.map(token)
            task.rule = task.rule.map(spec)
            task.piece = task.piece.map(token)
            t.task = task
        }
        return t
    }
}

/// 没写 drill 的题，按规则配一句不提方向的通用说法。没有在这里的规则（比如 any），练习时不出。
enum PracticePrompts {
    static let gomoku: [String: String] = [
        "five": "找到连成五颗的那一步！",
        "block": "白棋快连成五颗了，快堵住！",
        "openThree": "再下一颗，摆出一个活三！",
        "stopOpenFour": "白棋有一个活三，把它堵住！",
        "winIn:1": "下一颗，做出一个活四！",
        "winIn": "找到一步，让白棋堵不过来！",
    ]

    static let xiangqi: [String: String] = [
        "capture": "吃掉一个黑方的子！",
        "check": "将黑方一军！",
        "mate": "一步将死！",
        "mate2": "先将一军，再将死它！",
        "escape": "被将军了，快解开！",
        "escape:king": "被将军了，把帅躲开！",
        "escape:block": "被将军了，用别的子挡一下！",
        "escape:capture": "被将军了，把将军的子吃掉！",
        "bestCapture": "吃哪一个最划算？",
        "safe": "黑方要吃你的子了，走到安全的地方！",
        "develop": "把一个还没动过的马、炮或者车放出来！",
    ]

    static let go: [String: String] = [
        "capture": "把能吃的白子吃掉！",
        "atari": "叫吃一颗白子！",
        "doubleAtari": "一下子叫吃两颗白子！",
        "escape": "圈出来的黑子被叫吃了，快逃！",
        "kill": "想办法吃掉圈出来的白子！",
        "chase": "一直叫吃，吃掉圈出来的白子！",
        "net": "用枷把圈出来的白子关住！",
        "netChase": "关住它，一直到吃掉为止！",
        "connect": "把圈出来的黑子连在一起！",
        "corner": "占一个空着的角！",
        "safe": "找一个安全的地方下！",
    ]

    /// 这条规则的通用说法
    static func generic(_ rule: String?, game: String) -> String? {
        guard let rule else { return nil }
        let head = String(rule.split(separator: ":").first ?? "")
        switch game {
        case "xiangqi": return xiangqi[rule] ?? xiangqi[head]
        case "go": return go[head]
        default: return gomoku[rule] ?? gomoku[head]
        }
    }
}

enum LessonPractice {
    /// 练习时这一步说什么；nil = 这一步练习时不出
    static func prompt(_ s: TutorialStep, game: String) -> String? {
        guard let task = s.task else { return nil }
        if let d = s.drill, !d.isEmpty { return d }
        return PracticePrompts.generic(task.rule, game: game)
    }

    /// 局面写的是几路棋盘（五子棋、围棋）
    static func boardSize(_ spec: String) -> Int {
        for part in spec.split(separator: ";") {
            let kv = part.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if kv.count == 2, kv[0] == "size", let n = Int(kv[1]) { return n }
        }
        return 9
    }

    /// 一课里能练的段落（还没变换）。每段第一步带着局面；说的话换成练习用的说法，
    /// 课文里的提示、夸奖、"对手走完再说一句"都去掉（里面会提方向）。
    /// 一段里遇到不能练的题就到此为止（那道题会改变棋盘，后面的题接不上）。
    static func segments(_ lesson: TutorialLesson, game: String) -> [[TutorialStep]] {
        var out: [[TutorialStep]] = []
        var current: [TutorialStep] = []
        var spec: String?
        var blocked = false
        for s in lesson.steps {
            if let b = s.board {
                if !current.isEmpty { out.append(current) }
                current = []
                spec = b
                blocked = false
            }
            guard let task = s.task, !blocked else { continue }
            guard let spec, let say = prompt(s, game: game) else { blocked = true; continue }
            var p = s
            p.say = say
            p.hint = nil
            p.ok = nil
            p.after = nil
            p.board = current.isEmpty ? spec : nil
            p.marks = (s.marks ?? []) + extraMarks(task, game: game, existing: s.marks ?? [])
            if p.marks?.isEmpty == true { p.marks = nil }
            current.append(p)
        }
        if !current.isEmpty { out.append(current) }
        return out
    }

    /// 没有课文说明时，把要动的子、要看的那块棋标出来
    private static func extraMarks(_ task: TutorialTask, game: String, existing: [String]) -> [String] {
        var out: [String] = []
        if game == "xiangqi", let piece = task.piece { out.append("glow:\(piece)") }
        if game == "go", let rule = task.rule {
            let parts = rule.split(separator: ":").map(String.init)
            if ["escape", "kill", "chase", "net", "netChase", "connect"].contains(parts[0]) {
                out += parts.dropFirst().map { "ring:\($0)" }
            }
        }
        return out.filter { !existing.contains($0) }
    }

    /// 一段题的题数
    static func taskCount(_ seg: [TutorialStep]) -> Int { seg.filter { $0.task != nil }.count }

    /// 一段题配上一个随机变换
    static func transformed<G: RandomNumberGenerator>(_ seg: [TutorialStep], game: String, using rng: inout G) -> [TutorialStep] {
        let size = seg.first?.board.map(boardSize) ?? 9
        let sym = LessonSymmetry.all(game, size: size).randomElement(using: &rng)!
        return seg.map(sym.step)
    }

    static func canPractice(_ lesson: TutorialLesson, game: String) -> Bool {
        !segments(lesson, game: game).isEmpty
    }

    /// 「练一练」：这一课所有能练的题，每段换一个方向
    static func practiceLesson<G: RandomNumberGenerator>(_ lesson: TutorialLesson, game: String, using rng: inout G) -> TutorialLesson? {
        let segs = segments(lesson, game: game)
        guard !segs.isEmpty else { return nil }
        var l = lesson
        l.steps = segs.flatMap { transformed($0, game: game, using: &rng) }
        return l
    }

    static func practiceLesson(_ lesson: TutorialLesson, game: String) -> TutorialLesson? {
        var g = SystemRandomNumberGenerator()
        return practiceLesson(lesson, game: game, using: &g)
    }

    /// 「复习」：从学完的课里随机抽 count 道题（奖杯越差的课越容易抽到），每段换一个方向
    static func reviewLesson<G: RandomNumberGenerator>(_ course: TutorialCourse, cups: [String: LessonCup],
                                                       count: Int = 5, using rng: inout G) -> TutorialLesson? {
        var pool: [(segment: [TutorialStep], weight: Int)] = []
        for l in course.lessons {
            guard let cup = cups[l.id] else { continue }
            let w = 4 - cup.rawValue // 铜 3、银 2、金 1
            for seg in segments(l, game: course.game) { pool.append((seg, w)) }
        }
        var steps: [TutorialStep] = []
        var tasks = 0
        while tasks < count, !pool.isEmpty {
            let total = pool.reduce(0) { $0 + $1.weight }
            var r = Int.random(in: 0..<total, using: &rng)
            let i = pool.firstIndex { r -= $0.weight; return r < 0 }!
            var seg = pool.remove(at: i).segment
            // 最后一段太长就只取前面几题（后面的题本来就是接着前面下的，截掉不影响前面）
            while taskCount(seg) > count - tasks { seg.removeLast() }
            tasks += taskCount(seg)
            steps += transformed(seg, game: course.game, using: &rng)
        }
        guard !steps.isEmpty, var l = course.lessons.first else { return nil }
        l.id = "review"
        l.title = "复习"
        l.icon = "arrow.triangle.2.circlepath"
        l.learned = ""
        l.steps = steps
        return l
    }

    static func reviewLesson(_ course: TutorialCourse, cups: [String: LessonCup]) -> TutorialLesson? {
        var g = SystemRandomNumberGenerator()
        return reviewLesson(course, cups: cups, using: &g)
    }
}
