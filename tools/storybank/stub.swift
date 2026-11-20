// 题库生成器用的替身：让 StoryModel.swift 在 Mac 命令行里编译，不需要整个 App。
import SwiftUI
extension Color { init(hex: UInt32, opacity: Double = 1) { self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: opacity) } }
enum Palette { static let coral = Color.red, blush = Color.pink, sage = Color.green, honey = Color.yellow, sky = Color.blue, lilac = Color.purple }
final class PlayerStore {
    var c: [String: Int] = [:]
    var totalStars = 0
    var storyMistakes: [StoryMistake] = []
    func count(_ k: String) -> Int { c[k, default: 0] }
    func setCount(_ k: String, _ v: Int) { c[k] = v }
    func increment(_ k: String) { c[k, default: 0] += 1 }
    func addStars(_ n: Int) { totalStars += n }
    func earnStars(_ n: Int, key: String) { c[key, default: 0] += n; totalStars += n }
    func markMistakeFixed(_ id: UUID) {}
}
/// 生成题库时还没有题库
enum StoryBank { static func problemCount(for level: StoryLevel) -> Int? { nil } }
