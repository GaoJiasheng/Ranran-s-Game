// 奖励规矩测试用的替身：让 RewardRules.swift、RewardStore.swift 在 Mac 命令行里编译，不需要整个 App。
import Foundation
final class PlayerStore {
    var counts: [String: Int] = [:]
    var totalStars = 0
    func count(_ k: String) -> Int { counts[k, default: 0] }
    func setCount(_ k: String, _ v: Int) { counts[k] = v }
    func increment(_ k: String) { counts[k, default: 0] += 1 }
    func addStars(_ n: Int) { totalStars += n }
    func earnStars(_ n: Int, key: String) { guard n > 0 else { return }; counts[key, default: 0] += n; totalStars += n }
    static func dayNumber(_ date: Date = Date()) -> Int { 9000 }
}
