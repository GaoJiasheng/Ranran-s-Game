import SwiftUI

/// 电脑对手：用三个小动物代表三个难度。
enum Opponent: String, CaseIterable, Identifiable, Hashable {
    case bunny, panda, owl

    var id: String { rawValue }

    var name: String {
        switch self {
        case .bunny: "小兔"
        case .panda: "熊猫"
        case .owl:   "猫头鹰"
        }
    }

    var levelTag: String {
        switch self {
        case .bunny: "入门"
        case .panda: "进阶"
        case .owl:   "高手"
        }
    }

    var level: AILevel {
        switch self {
        case .bunny: .easy
        case .panda: .normal
        case .owl:   .hard
        }
    }

    var image: String { "avatar_\(rawValue)" }

    var emoji: String {
        switch self {
        case .bunny: "🐰"
        case .panda: "🐼"
        case .owl:   "🦉"
        }
    }

    var tint: Color {
        switch self {
        case .bunny: Palette.blush
        case .panda: Palette.sage
        case .owl:   Palette.honey
        }
    }

    /// 赢了这个对手能拿几颗星
    var stars: Int {
        switch self {
        case .bunny: 1
        case .panda: 2
        case .owl:   3
        }
    }

    /// 对手会不会在你快输的时候提醒你
    var coaches: Bool { self != .owl }

    var thinkingTime: Duration {
        switch self {
        case .bunny: .milliseconds(650)
        case .panda: .milliseconds(800)
        case .owl:   .milliseconds(900)
        }
    }

    var greeting: String {
        switch self {
        case .bunny: "我们一起玩吧～"
        case .panda: "请多指教！"
        case .owl:   "咕咕，我可不会让着你哦"
        }
    }

    var warning: String {
        switch self {
        case .bunny: "小心哦，我快连成五个啦！"
        case .panda: "注意！我只差一个了"
        case .owl:   ""
        }
    }

    var winLine: String {
        switch self {
        case .bunny: "嘿嘿，这次我赢啦"
        case .panda: "好险，被我赢了一局"
        case .owl:   "咕咕，再练练吧"
        }
    }

    var loseLine: String {
        switch self {
        case .bunny: "然然好厉害！"
        case .panda: "哇，你赢了我！"
        case .owl:   "咕……你真是高手！"
        }
    }
}

enum GomokuMode: Hashable {
    case vsAI(Opponent)
    case twoPlayer

    var opponent: Opponent? {
        if case let .vsAI(o) = self { return o }
        return nil
    }
}

struct GomokuConfig: Hashable, Identifiable {
    let mode: GomokuMode
    let humanFirst: Bool
    var id: String { "\(mode)-\(humanFirst)" }
}
