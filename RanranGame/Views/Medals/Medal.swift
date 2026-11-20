import SwiftUI

/// 星星奖章：总星星数到了某个数，就解锁一枚。不要和各游戏课程里的"小奖杯"混在一起。
struct Medal: Identifiable, Hashable {
    /// 1 开始，也是在奖章阶梯上的名次
    let id: Int
    /// 需要的总星星数
    let threshold: Int
    let name: String
    /// SF Symbol 图案
    let emblem: String
    /// 主色、缎带色
    let base: UInt32
    let ribbon: UInt32

    /// 从低到高的奖章阶梯，间隔慢慢拉大。
    static let all: [Medal] = [
        Medal(id: 1,  threshold: 5,   name: "小星芽",   emblem: "leaf.fill",       base: 0x8DB596, ribbon: 0x6FA07A),
        Medal(id: 2,  threshold: 15,  name: "小兔子",   emblem: "hare.fill",       base: 0xF4A9A0, ribbon: 0xEE7B6B),
        Medal(id: 3,  threshold: 30,  name: "暖心花",   emblem: "heart.fill",      base: 0xEE7B6B, ribbon: 0xC9624F),
        Medal(id: 4,  threshold: 50,  name: "月亮船",   emblem: "moon.stars.fill", base: 0xA897DA, ribbon: 0x8472C4),
        Medal(id: 5,  threshold: 80,  name: "小太阳",   emblem: "sun.max.fill",    base: 0xEDB34F, ribbon: 0xE08A3C),
        Medal(id: 6,  threshold: 120, name: "彩虹桥",   emblem: "rainbow",         base: 0x6FB5E0, ribbon: 0x4F96C8),
        Medal(id: 7,  threshold: 170, name: "闪电侠",   emblem: "bolt.fill",       base: 0xF2C14B, ribbon: 0xD9982F),
        Medal(id: 8,  threshold: 230, name: "小火龙",   emblem: "flame.fill",      base: 0xF08A4B, ribbon: 0xD0603A),
        Medal(id: 9,  threshold: 300, name: "小公主",   emblem: "crown.fill",      base: 0xD58BC8, ribbon: 0xB567A9),
        Medal(id: 10, threshold: 400, name: "魔法星",   emblem: "sparkles",        base: 0x5FBFB2, ribbon: 0x3FA095),
        Medal(id: 11, threshold: 520, name: "闪亮钻石", emblem: "diamond.fill",    base: 0x7CC8E8, ribbon: 0x4C9FCB),
        Medal(id: 12, threshold: 650, name: "冉冉冠军", emblem: "trophy.fill",     base: 0xE9B872, ribbon: 0xD0603A),
    ]

    /// 已经拿到的奖章
    static func earned(stars: Int) -> [Medal] { all.filter { stars >= $0.threshold } }
    /// 下一枚还没拿到的
    static func next(stars: Int) -> Medal? { all.first { stars < $0.threshold } }
    /// 最近拿到的一枚
    static func latest(stars: Int) -> Medal? { earned(stars: stars).last }
    /// 上一级的门槛（没有就是 0）
    static func previousThreshold(before m: Medal) -> Int { m.id > 1 ? all[m.id - 2].threshold : 0 }
}

extension PlayerStore {
    /// 奖章用的星星数。调试时可用启动参数 -medalStars N 顶替。
    var medalStars: Int {
        #if DEBUG
        if let s = UserDefaults.standard.string(forKey: "medalStars").flatMap(Int.init) { return s }
        #endif
        return totalStars
    }

    /// 已经庆祝过几枚奖章。存在 counts 里，所以会跟着存档一起导出、导入。
    var medalsCelebrated: Int { count("medals.celebrated") }

    /// 还没庆祝的奖章里最高的一枚。第一次升级后已经拿到的一堆，只庆祝最高的这一枚。
    var pendingMedal: Medal? {
        guard let top = Medal.latest(stars: medalStars), top.id > medalsCelebrated else { return nil }
        return top
    }

    func markMedalsCelebrated(through medal: Medal) {
        if medal.id > medalsCelebrated { setCount("medals.celebrated", medal.id) }
    }
}
