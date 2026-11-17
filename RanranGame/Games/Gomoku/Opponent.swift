import SwiftUI

/// 电脑对手的形象。十档难度分成四组，每组由一位小伙伴来下。
enum Opponent: String, CaseIterable, Identifiable, Hashable {
    case bunny, panda, owl, dragon

    var id: String { rawValue }

    var name: String {
        switch self {
        case .bunny:  "小兔"
        case .panda:  "熊猫"
        case .owl:    "猫头鹰"
        case .dragon: "龙宝宝"
        }
    }

    /// 这一组的名字
    var tierName: String {
        switch self {
        case .bunny:  "入门"
        case .panda:  "进阶"
        case .owl:    "高手"
        case .dragon: "棋王"
        }
    }

    var levels: ClosedRange<Int> {
        switch self {
        case .bunny:  1...3
        case .panda:  4...6
        case .owl:    7...9
        case .dragon: 10...10
        }
    }

    var image: String { "avatar_\(rawValue)" }

    var emoji: String {
        switch self {
        case .bunny:  "🐰"
        case .panda:  "🐼"
        case .owl:    "🦉"
        case .dragon: "🐲"
        }
    }

    var tint: Color {
        switch self {
        case .bunny:  Palette.blush
        case .panda:  Palette.sage
        case .owl:    Palette.honey
        case .dragon: Palette.lilac
        }
    }

    var greeting: String {
        switch self {
        case .bunny:  "我们一起玩吧～"
        case .panda:  "请多指教！"
        case .owl:    "咕咕，我可不会让着你哦"
        case .dragon: "我是棋王，来挑战我吧！"
        }
    }

    var warning: String {
        switch self {
        case .bunny:  "小心哦，我快连成五个啦！"
        case .panda:  "注意！我只差一个了"
        case .owl, .dragon: ""
        }
    }

    var winLine: String {
        switch self {
        case .bunny:  "嘿嘿，这次我赢啦"
        case .panda:  "好险，被我赢了一局"
        case .owl:    "咕咕，再练练吧"
        case .dragon: "哼哼，棋王可不是白当的"
        }
    }

    var loseLine: String {
        switch self {
        case .bunny:  "你好厉害呀！"
        case .panda:  "哇，你赢了我！"
        case .owl:    "咕……你真是高手！"
        case .dragon: "我的王冠……送给你啦！"
        }
    }
}

/// 一到十档难度。
struct GomokuLevel: Hashable, Identifiable, Comparable {
    static let range = 1...10
    static let all = range.map(GomokuLevel.init)

    let number: Int

    init(_ number: Int) {
        self.number = min(max(number, Self.range.lowerBound), Self.range.upperBound)
    }

    var id: Int { number }

    static func < (a: Self, b: Self) -> Bool { a.number < b.number }

    var character: Opponent {
        Opponent.allCases.first { $0.levels.contains(number) } ?? .bunny
    }

    var profile: AIProfile { .level(number) }

    var next: GomokuLevel? { number < Self.range.upperBound ? GomokuLevel(number + 1) : nil }
    var previous: GomokuLevel? { number > Self.range.lowerBound ? GomokuLevel(number - 1) : nil }

    /// 对手快赢时，会不会把危险的地方标出来提醒冉冉
    var coaches: Bool { number <= 6 }

    var thinkingTime: Duration { .milliseconds(560 + number * 40) }

    /// 用小朋友听得懂的话说清楚这一档的电脑会做什么
    var blurb: String {
        switch number {
        case 1:  "刚学会下棋，经常走神"
        case 2:  "偶尔会想起来堵你一下"
        case 3:  "开始认真防守啦"
        case 4:  "你连成四个，它基本都会堵"
        case 5:  "会自己攒三个子来进攻"
        case 6:  "攻守都很稳，很少犯错"
        case 7:  "下每一步前会多想一步"
        case 8:  "会想好几步，小心它的陷阱"
        case 9:  "真正的高手，会提前布局"
        default: "会连续冲四抢攻，最强的对手"
        }
    }
}

enum GomokuMode: Hashable {
    case vsAI(GomokuLevel)
    case twoPlayer

    var level: GomokuLevel? {
        if case let .vsAI(l) = self { return l }
        return nil
    }
}

struct GomokuConfig: Hashable, Identifiable {
    let mode: GomokuMode
    let humanFirst: Bool
    var id: String { "\(mode)-\(humanFirst)" }
}

/// 五子棋的进度记录（每档最好成绩、赢了几次），存在 PlayerStore 里。
extension PlayerStore {
    func gomokuBest(_ level: GomokuLevel) -> Int { count("gomoku.best.\(level.number)") }
    func gomokuWins(_ level: GomokuLevel) -> Int { count("gomoku.wins.\(level.number)") }

    /// 推荐挑战的档位：已经赢过的最高一档再往上一档。
    var gomokuRecommended: GomokuLevel {
        let cleared = GomokuLevel.all.last { gomokuBest($0) > 0 }?.number ?? 0
        return GomokuLevel(cleared + 1)
    }

    /// 记一次胜利，返回是不是这一档的新纪录。
    @discardableResult
    func recordGomokuWin(_ level: GomokuLevel, stars: Int) -> Bool {
        increment("gomoku.wins.\(level.number)")
        let isRecord = stars > gomokuBest(level)
        if isRecord { setCount("gomoku.best.\(level.number)", stars) }
        return isRecord
    }
}
