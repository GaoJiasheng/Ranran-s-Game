import Foundation

// 解谜类游戏记在存档里的部分：每一关的最好成绩、发星星、解锁。
//
// 每一关按表现给 1~3 颗星：过关 1 颗，另外两颗各游戏自己定（比如"没用提示""没填错""步数不超过目标"），
// 只记最好的一次，变好了补差额（和教学的小奖杯一样）——重玩已经三星的关不再给星，刷不了。
//   <游戏>.pz.<关>         最好几颗（0 = 还没过）
//   <游戏>.pz.n.<关>       过了几次
//   <游戏>.stars.pz.<关>   这一关发过的星星
// 过一关也算「今天的三颗星」里的"玩一局"。

/// 过一关之后的结果
struct PuzzleResult: Hashable {
    /// 这一次的表现 1~3
    var earned: Int
    /// 这一关现在的最好成绩
    var best: Int
    /// 这一次发了几颗星
    var paid: Int
    /// 第一次过这一关
    var first: Bool
}

extension PlayerStore {
    /// 这一关最好几颗星；没过是 0
    func puzzleBest(_ game: String, _ level: String) -> Int { count("\(game).pz.\(level)") }

    func puzzleCleared(_ game: String, _ level: String) -> Bool { puzzleBest(game, level) > 0 }

    /// 这些关里过了几关
    func puzzlesCleared(_ game: String, _ levels: [String]) -> Int {
        levels.filter { puzzleCleared(game, $0) }.count
    }

    /// 过了一关。earned 是这一次的表现（1~3）。发星星、记最好成绩、算进今天的三颗星。
    @discardableResult
    func recordPuzzle(game: String, level: String, earned: Int, day: Int = PlayerStore.today) -> PuzzleResult {
        let e = min(max(earned, 1), 3)
        let before = puzzleBest(game, level)
        increment("\(game).pz.n.\(level)")
        if e > before { setCount("\(game).pz.\(level)", e) }
        let owed = max(0, e - count("\(game).stars.pz.\(level)"))
        earnStars(owed, key: "\(game).stars.pz.\(level)")
        noteDaily(.play, day: day)
        return PuzzleResult(earned: e, best: max(before, e), paid: owed, first: before == 0)
    }

    /// 这一组开了没有：第一组一直开着；后面的要等前一组过了三分之二。
    /// 这一组或者后面的组里已经有过了的关，也算开着（以后调整关卡不会把玩过的锁回去）。
    func packUnlocked(_ game: String, _ packs: [PuzzlePack], _ index: Int,
                      unlockAll: Bool = UserDefaults.standard.bool(forKey: PuzzleRules.unlockAllKey)) -> Bool {
        guard packs.indices.contains(index) else { return false }
        if index == 0 || unlockAll { return true }
        let prev = packs[index - 1]
        if packUnlocked(game, packs, index - 1, unlockAll: unlockAll),
           puzzlesCleared(game, prev.levels) >= PuzzleRules.needed(toOpenAfter: prev) { return true }
        return packs[index...].contains { puzzlesCleared(game, $0.levels) > 0 }
    }

    /// 还差几关才能打开这一组（已经开了是 0）
    func puzzlesNeeded(_ game: String, _ packs: [PuzzlePack], toOpen index: Int,
                       unlockAll: Bool = UserDefaults.standard.bool(forKey: PuzzleRules.unlockAllKey)) -> Int {
        guard index > 0, packs.indices.contains(index), !packUnlocked(game, packs, index, unlockAll: unlockAll) else { return 0 }
        let prev = packs[index - 1]
        return max(1, PuzzleRules.needed(toOpenAfter: prev) - puzzlesCleared(game, prev.levels))
    }

    /// 这一关能不能玩：过了的一直能玩；没过的里面，每组最前面的两关开着。
    func puzzleUnlocked(_ game: String, _ packs: [PuzzlePack], _ level: String,
                        unlockAll: Bool = UserDefaults.standard.bool(forKey: PuzzleRules.unlockAllKey)) -> Bool {
        if unlockAll || puzzleCleared(game, level) { return true }
        guard let pi = packs.firstIndex(where: { $0.levels.contains(level) }),
              packUnlocked(game, packs, pi, unlockAll: unlockAll) else { return false }
        let open = packs[pi].levels.filter { !puzzleCleared(game, $0) }.prefix(PuzzleRules.openAhead)
        return open.contains(level)
    }

    /// 接着玩哪一关：开着的组里第一关没过的；全都过了是 nil
    func nextPuzzle(_ game: String, _ packs: [PuzzlePack],
                    unlockAll: Bool = UserDefaults.standard.bool(forKey: PuzzleRules.unlockAllKey)) -> String? {
        for (i, p) in packs.enumerated() where packUnlocked(game, packs, i, unlockAll: unlockAll) {
            if let l = p.levels.first(where: { !puzzleCleared(game, $0) }) { return l }
        }
        return nil
    }

    /// 同一组里的下一关（过关页上的「下一关」）；这一组最后一关之后，接下一组第一关（要已经解锁）
    func puzzleAfter(_ game: String, _ packs: [PuzzlePack], _ level: String,
                     unlockAll: Bool = UserDefaults.standard.bool(forKey: PuzzleRules.unlockAllKey)) -> String? {
        let all = packs.flatMap(\.levels)
        guard let i = all.firstIndex(of: level), i + 1 < all.count else { return nil }
        let next = all[i + 1]
        return puzzleUnlocked(game, packs, next, unlockAll: unlockAll) ? next : nil
    }
}
