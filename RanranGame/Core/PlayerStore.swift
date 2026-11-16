import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers

/// 一盘下完的棋。所有棋类共用这一种棋谱格式，靠 `game` 区分是哪种棋。
struct GameRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    /// 哪种棋，比如 "gomoku"
    var game: String
    var date: Date
    var boardSize: Int
    /// 每一手的坐标 [x, y]，黑棋先下
    var moves: [[Int]]
    /// 和电脑下时电脑的档位；和家人下为 nil
    var opponentLevel: Int?
    /// 和电脑下时玩家执哪个颜色（1 黑 2 白）；和家人下为 nil
    var playerColor: Int?
    /// 谁赢了（1 黑 2 白）；平局为 nil
    var winner: Int?
    /// 这盘拿到的星星
    var stars: Int
}

extension Date {
    /// 比如"11月16日 20:31"，不随系统语言变
    var shortChinese: String {
        formatted(Date.FormatStyle(locale: Locale(identifier: "zh_CN")).month(.defaultDigits).day().hour().minute())
    }
}

/// 导出 / 导入用的存档文件内容。
struct SaveArchive: Codable {
    var format = "ranran-save"
    var version = 1
    var exportedAt = Date()
    var playerName: String
    var totalStars: Int
    var counts: [String: Int]
    var settings: [String: Int]
    var records: [GameRecord]
}

/// 玩家的全部本地数据：名字、星星、各种进度、棋谱。不需要登录，只存在这台 iPad 上。
@Observable
final class PlayerStore {
    static let defaultName = "然然"
    static let maxNameLength = 8
    /// 跟着存档一起导出的设置项
    private static let settingKeys = ["gomoku.level", "gomoku.humanFirst"]

    private let defaults: UserDefaults
    private let recordsURL: URL

    private(set) var name: String
    private(set) var totalStars: Int
    private(set) var counts: [String: Int]
    /// 最新的在前
    private(set) var records: [GameRecord]

    init(defaults: UserDefaults = .standard, directory: URL? = nil) {
        self.defaults = defaults
        let dir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        recordsURL = dir.appendingPathComponent("records.json")

        name = defaults.string(forKey: "playerName") ?? Self.defaultName
        totalStars = defaults.integer(forKey: "totalStars")
        counts = (defaults.dictionary(forKey: "counts") as? [String: Int]) ?? [:]
        records = (try? Self.decoder.decode([GameRecord].self, from: Data(contentsOf: recordsURL))) ?? []
    }

    // MARK: 名字

    /// 去掉首尾空格、最多 8 个字；空的就不改
    func rename(_ newName: String) {
        let trimmed = String(newName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxNameLength))
        guard !trimmed.isEmpty else { return }
        name = trimmed
        defaults.set(name, forKey: "playerName")
    }

    // MARK: 星星和计数

    func addStars(_ n: Int) {
        totalStars += n
        defaults.set(totalStars, forKey: "totalStars")
    }

    func count(_ key: String) -> Int { counts[key, default: 0] }

    func setCount(_ key: String, _ value: Int) {
        counts[key] = value
        defaults.set(counts, forKey: "counts")
    }

    func increment(_ key: String) {
        counts[key, default: 0] += 1
        defaults.set(counts, forKey: "counts")
    }

    // MARK: 棋谱

    /// 同一个 id 再存一次就覆盖（比如下完后悔棋又下完）
    func saveRecord(_ record: GameRecord) {
        records.removeAll { $0.id == record.id }
        records.insert(record, at: 0)
        persistRecords()
    }

    func deleteRecord(_ record: GameRecord) {
        records.removeAll { $0.id == record.id }
        persistRecords()
    }

    func records(for game: String) -> [GameRecord] { records.filter { $0.game == game } }

    private func persistRecords() {
        guard let data = try? Self.encoder.encode(records) else { return }
        try? data.write(to: recordsURL, options: .atomic)
    }

    // MARK: 存档导出 / 导入

    func makeArchive() -> SaveArchive {
        var settings: [String: Int] = [:]
        for key in Self.settingKeys where defaults.object(forKey: key) != nil {
            settings[key] = defaults.integer(forKey: key)
        }
        return SaveArchive(playerName: name, totalStars: totalStars, counts: counts,
                           settings: settings, records: records)
    }

    /// 用存档整个替换当前数据
    func restore(_ archive: SaveArchive) {
        name = archive.playerName.isEmpty ? Self.defaultName : archive.playerName
        totalStars = archive.totalStars
        counts = archive.counts
        records = archive.records.sorted { $0.date > $1.date }
        defaults.set(name, forKey: "playerName")
        defaults.set(totalStars, forKey: "totalStars")
        defaults.set(counts, forKey: "counts")
        for key in Self.settingKeys {
            if let v = archive.settings[key] { defaults.set(v, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
        persistRecords()
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

/// 给系统"存储到文件"用的存档文档。
struct SaveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var archive: SaveArchive

    init(archive: SaveArchive) { self.archive = archive }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        archive = try PlayerStore.decoder.decode(SaveArchive.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try PlayerStore.encoder.encode(archive))
    }
}
