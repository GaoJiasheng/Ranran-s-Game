// 全局奖励规矩的命令行测试：zsh tools/rewards/test.sh
import Foundation

var failed = 0
func check(_ ok: Bool, _ what: String, line: Int = #line) {
    if !ok { failed += 1; print("✗ \(what)  (test.swift:\(line))") }
}
/// 账要对得上：总数 = 所有 ".stars." 计数加起来
func ledger(_ s: PlayerStore) -> Int { s.counts.filter { $0.key.contains(".stars.") }.reduce(0) { $0 + $1.value } }

// 上课：铜 1 银 2 金 3，变好了补差额，不会重复发
do {
    let s = PlayerStore()
    check(s.payLessonStars(game: "go", lesson: "go1", cup: 1) == 1, "铜杯 1 颗")
    check(s.payLessonStars(game: "go", lesson: "go1", cup: 1) == 0, "同一个杯子不再发")
    check(s.payLessonStars(game: "go", lesson: "go1", cup: 3) == 2, "铜变金补 2 颗")
    check(s.payLessonStars(game: "go", lesson: "go1", cup: 2) == 0, "变差了不扣也不发")
    check(s.payLessonStars(game: "go", lesson: "go2", cup: 3) == 3, "直接金杯 3 颗")
    check(s.totalStars == 6 && s.stars(prefix: "go.stars.") == 6, "课程星星记在这种棋上")
    check(s.stars(prefix: "gomoku.stars.") == 0, "别的棋不受影响（go 不是 gomoku 的前缀）")
}

// 复习：每种棋每天第一次 1 颗
do {
    let s = PlayerStore()
    check(s.payReviewStar(game: "go", day: 10) == 1, "第一次复习给 1 颗")
    check(s.payReviewStar(game: "go", day: 10) == 0, "同一天不再给")
    check(s.payReviewStar(game: "xiangqi", day: 10) == 1, "另一种棋同一天也给")
    check(s.payReviewStar(game: "go", day: 11) == 1, "第二天又给")
    check(s.totalStars == 3 && ledger(s) == 3, "复习的账对得上")
}

// 下棋
do {
    let s = PlayerStore()
    var r = s.recordWin(game: "gomoku", level: 1, earned: 3, day: 5)
    check(r.reward.base == 3 && r.reward.bonus == 5 && !r.reward.low && r.isRecord, "第一次赢第 1 档：3 + 5")
    r = s.recordWin(game: "gomoku", level: 1, earned: 2, day: 5)
    check(r.reward.total == 2 && !r.isRecord, "再赢第 1 档：照常给，没有加奖")
    r = s.recordWin(game: "gomoku", level: 2, earned: 1, day: 5)
    check(r.reward.total == 6, "第一次赢第 2 档：1 + 5")
    check(!RewardRules.isLow(level: 1, topCleared: 2), "最高赢过第 2 档，第 1 档还算在水平附近")
    _ = s.recordWin(game: "gomoku", level: 5, earned: 3, day: 5)
    check(s.topCleared("gomoku") == 5, "最高赢过第 5 档")
    check(!s.winPreview(game: "gomoku", level: 4).low && !s.winPreview(game: "gomoku", level: 5).low
          && !s.winPreview(game: "gomoku", level: 9).low, "第 4 档及以上给全额")
    check(s.winPreview(game: "gomoku", level: 3).low, "第 3 档算低档")
    // 刷第 1 档：每天只有前 3 盘各 1 颗
    let before = s.totalStars
    var got: [Int] = []
    for _ in 0..<6 { got.append(s.recordWin(game: "gomoku", level: 1, earned: 3, day: 5).reward.total) }
    check(got == [1, 1, 1, 0, 0, 0], "低档每天前 3 盘各 1 颗，之后没有：\(got)")
    check(s.totalStars == before + 3, "刷低档一天最多 3 颗")
    check(s.winPreview(game: "gomoku", level: 1, day: 5).base == 0 && s.winPreview(game: "gomoku", level: 1, day: 6).base == 1, "第二天又有了")
    // 低档里第一次赢的那一档还是有加奖
    r = s.recordWin(game: "gomoku", level: 3, earned: 3, day: 6)
    check(r.reward.low && r.reward.base == 1 && r.reward.bonus == 5, "低档第一次赢：1 + 5")
    // 别的棋互不影响
    check(s.topCleared("go") == 0 && s.lowWinsToday("go", day: 6) == 0, "围棋没受五子棋影响")
    check(s.count("gomoku.wins.1") == 8, "胜场照记")
    check(s.totalStars == ledger(s), "下棋的账对得上：\(s.totalStars) / \(ledger(s))")
    // 加奖每一档只有一次，十档最多 50
    for l in 1...10 { for _ in 0..<2 { _ = s.recordWin(game: "gomoku", level: l, earned: 3, day: 7) } }
    check(s.stars(prefix: "gomoku.stars.first.") == 50, "十档的加奖一共 50 颗")
}

// 今天的三颗星
do {
    let s = PlayerStore()
    check(s.dailyCount(day: 20) == 0, "一开始什么都没做")
    check(!s.noteDaily(.learn, day: 20) && s.dailyDone(.learn, day: 20), "学了一课")
    check(!s.noteDaily(.learn, day: 20) && s.dailyCount(day: 20) == 1, "同一件事做两次只算一次")
    check(!s.noteDaily(.math, day: 20), "两件还不够")
    check(s.noteDaily(.play, day: 20), "三件凑齐")
    check(s.totalStars == RewardRules.dailyBonus && s.dailyDays == 1 && s.dailyCheerPending(day: 20), "发加奖、记一天、等主页庆祝")
    check(!s.noteDaily(.play, day: 20) && s.totalStars == RewardRules.dailyBonus, "同一天不重复发")
    s.clearDailyCheer()
    check(!s.dailyCheerPending(day: 20), "庆祝过了")
    check(s.dailyCount(day: 21) == 0 && !s.dailyComplete(day: 21), "第二天从头来")
    _ = s.noteDaily(.math, day: 21)
    check(s.dailyCount(day: 21) == 1 && !s.dailyDone(.learn, day: 21), "第二天只做了一件")
    _ = s.noteDaily(.learn, day: 23); _ = s.noteDaily(.math, day: 23); _ = s.noteDaily(.play, day: 23)
    check(s.dailyDays == 2 && s.totalStars == 2 * RewardRules.dailyBonus, "隔了一天再做完：天数接着加，不清零")
    check(s.totalStars == ledger(s), "每天的账对得上")
}

// 补发的礼物只说一次
do {
    let s = PlayerStore()
    check(s.pendingGift == nil, "没有礼物")
    s.setCount("rewards.gift", 12); s.setCount("rewards.giftBadges", 2)
    check(s.pendingGift?.stars == 12 && s.pendingGift?.badges == 2, "有礼物")
    s.clearGift()
    check(s.pendingGift == nil, "说过就没了")
    s.markBadgeSeen("go.track.basic")
    check(s.badgeSeen("go.track.basic") && !s.badgeSeen("go.track.capture"), "奖章看过的记号")
}

// 解谜类：每关 1~3 颗，只记最好的一次，变好了补差额；过一关算"玩一局"
do {
    let s = PlayerStore()
    let r1 = s.recordPuzzle(game: "sudoku", level: "a1", earned: 2, day: 20)
    check(r1.paid == 2 && r1.best == 2 && r1.first, "第一次过关 2 颗")
    let r2 = s.recordPuzzle(game: "sudoku", level: "a1", earned: 1, day: 20)
    check(r2.paid == 0 && r2.best == 2 && !r2.first, "再过一次、更差：不发也不降")
    let r3 = s.recordPuzzle(game: "sudoku", level: "a1", earned: 3, day: 20)
    check(r3.paid == 1 && r3.best == 3, "变成三星补 1 颗")
    check(s.recordPuzzle(game: "sudoku", level: "a1", earned: 3, day: 21).paid == 0, "三星以后重玩刷不了")
    check(s.recordPuzzle(game: "sudoku", level: "a2", earned: 9, day: 21).paid == 3, "最多 3 颗")
    check(s.stars(prefix: "sudoku.stars.") == 6 && s.totalStars == 6 && ledger(s) == 6, "解谜的账对得上")
    check(s.dailyDone(.play, day: 21), "过一关算玩一局")
    check(s.puzzleBest("sudoku", "a1") == 3 && s.puzzlesCleared("sudoku", ["a1", "a2", "a3"]) == 2, "最好成绩和过关数")
}

// 解谜类的解锁：每组最前面两关没过的开着；前一组过了三分之二才开下一组；全部解锁开关
do {
    let s = PlayerStore()
    let packs = [PuzzlePack(id: "a", name: "一", subtitle: "", art: "", levels: (1...6).map { "a\($0)" }),
                 PuzzlePack(id: "b", name: "二", subtitle: "", art: "", levels: (1...4).map { "b\($0)" })]
    func open(_ l: String) -> Bool { s.puzzleUnlocked("p", packs, l, unlockAll: false) }
    check(open("a1") && open("a2") && !open("a3"), "一开始开两关")
    check(!s.packUnlocked("p", packs, 1, unlockAll: false) && !open("b1"), "第二组锁着")
    check(s.puzzlesNeeded("p", packs, toOpen: 1, unlockAll: false) == 4, "6 关的三分之二是 4 关")
    check(s.nextPuzzle("p", packs, unlockAll: false) == "a1", "接着玩第一关")
    s.recordPuzzle(game: "p", level: "a2", earned: 1)
    check(open("a1") && open("a2") && open("a3") && !open("a4"), "跳着过了第二关：第一、三关开着")
    check(s.puzzleAfter("p", packs, "a2", unlockAll: false) == "a3", "下一关")
    for l in ["a1", "a3", "a4"] { s.recordPuzzle(game: "p", level: l, earned: 1) }
    check(s.packUnlocked("p", packs, 1, unlockAll: false) && open("b1") && open("b2") && !open("b3"), "过了 4 关，第二组打开")
    check(s.puzzlesNeeded("p", packs, toOpen: 1, unlockAll: false) == 0, "打开了就不差了")
    check(s.puzzleAfter("p", packs, "a6", unlockAll: false) == "b1", "一组的最后一关接下一组第一关")
    check(s.puzzleAfter("p", packs, "b4", unlockAll: false) == nil, "最后一关没有下一关")
    let t = PlayerStore()
    check(t.puzzleUnlocked("p", packs, "b4", unlockAll: true) && t.packUnlocked("p", packs, 1, unlockAll: true), "全部解锁")
    t.recordPuzzle(game: "p", level: "b1", earned: 1)
    check(t.packUnlocked("p", packs, 1, unlockAll: false), "后面的组里有过了的关，就一直开着")
}

print(failed == 0 ? "ALL PASSED" : "\(failed) FAILED")
exit(failed == 0 ? 0 : 1)
