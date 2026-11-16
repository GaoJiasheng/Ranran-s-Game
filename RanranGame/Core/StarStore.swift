import Foundation
import Observation

/// 保存然然攒到的星星和各种计数（存在 iPad 本地）。
@Observable
final class StarStore {
    private let defaults: UserDefaults
    private(set) var totalStars: Int
    private(set) var counts: [String: Int]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        totalStars = defaults.integer(forKey: "totalStars")
        counts = (defaults.dictionary(forKey: "counts") as? [String: Int]) ?? [:]
    }

    func addStars(_ n: Int) {
        totalStars += n
        defaults.set(totalStars, forKey: "totalStars")
    }

    func count(_ key: String) -> Int { counts[key, default: 0] }

    func increment(_ key: String) {
        counts[key, default: 0] += 1
        defaults.set(counts, forKey: "counts")
    }
}
