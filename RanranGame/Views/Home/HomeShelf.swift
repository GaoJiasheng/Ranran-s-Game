import SwiftUI

// 主页上摆哪些游戏、怎么摆。
// 家长可以在「我的」里把学会了的、暂时不玩的游戏从主页收起来（Views/Profile/HomeGamesEditor.swift）。
// 收起来只是不摆在主页上：星星、奖章、进度、棋谱都还在，放回去就接着玩。

extension PlayerStore {
    /// 主页上现在摆着的游戏，顺序固定
    var homeGames: [GameEntry] {
        let shown = GameEntry.allCases.filter { !isHidden($0.rawValue) }
        // 存档里万一把所有游戏都收起来了，就当没收过，主页不能是空的
        return shown.isEmpty ? Array(GameEntry.allCases) : shown
    }

    func isOnHome(_ game: GameEntry) -> Bool { homeGames.contains(game) }

    /// 主页至少留一个：最后一个摆着的不能再收
    func canHide(_ game: GameEntry) -> Bool { homeGames.count > 1 && isOnHome(game) }

    func setOnHome(_ game: GameEntry, _ shown: Bool) {
        if shown {
            setHidden(game.rawValue, false)
        } else if canHide(game) {
            setHidden(game.rawValue, true)
        }
    }

    func showAllOnHome() {
        for g in GameEntry.allCases where isHidden(g.rawValue) { setHidden(g.rawValue, false) }
    }
}

/// 主页的格子怎么分排：几个游戏、横屏还是竖屏 → 每一排放几个。
/// 卡片平分地方，所以排法要让每张卡片不太扁也不太窄。
enum HomeGridPlan {
    /// 比如横屏 7 个 → [3, 4]。不满的那一排放在上面，那几张卡片大一点。
    static func rows(count n: Int, wide: Bool) -> [Int] {
        guard n > 0 else { return [] }
        let rowCount: Int
        if wide {
            rowCount = n <= 3 ? 1 : n <= 8 ? 2 : 3
        } else {
            rowCount = n <= 3 ? n : n <= 8 ? (n + 1) / 2 : (n + 2) / 3
        }
        let base = n / rowCount
        let extra = n % rowCount
        return (0..<rowCount).map { $0 < rowCount - extra ? base : base + 1 }
    }
}
