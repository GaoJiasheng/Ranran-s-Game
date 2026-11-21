import Foundation

/// 一块木块长什么样：小兔、三位小伙伴，或者普通的彩色木块。和规则无关，只管画。
enum KlotskiLook: Hashable {
    case bunny, panda, owl, dragon
    /// 普通木块；数字是同一种形状里的第几块，用来换颜色
    case plain(Int)

    /// 嵌在木块上的头像图
    var avatar: String? {
        switch self {
        case .bunny: "avatar_bunny"
        case .panda: "avatar_panda"
        case .owl: "avatar_owl"
        case .dragon: "avatar_dragon"
        case .plain: nil
        }
    }

    var emoji: String {
        switch self {
        case .bunny: "🐰"
        case .panda: "🐼"
        case .owl: "🦉"
        case .dragon: "🐲"
        case .plain: ""
        }
    }
}

enum KlotskiLooks {
    /// 每块木块配一个样子：大块是小兔；竖块、横块按从上到下、从左到右的顺序，前三块依次是熊猫、猫头鹰、小龙，
    /// 后面的是普通木块；小方块都是普通木块。同一个盘面每次配的都一样。
    static func assign(_ board: KlotskiBoard) -> [KlotskiLook] {
        var friends: [KlotskiLook] = [.panda, .owl, .dragon]
        var counter: [KlotskiKind: Int] = [:]
        return board.pieces.map { p in
            switch p.kind {
            case .big:
                return .bunny
            case .tall, .wide:
                if !friends.isEmpty { return friends.removeFirst() }
                fallthrough
            case .small:
                let n = counter[p.kind, default: 0]
                counter[p.kind] = n + 1
                return .plain(n)
            }
        }
    }
}
