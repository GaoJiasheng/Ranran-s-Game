import Foundation

/// 预先出好的题库（Content/story_bank.json，由 tools/storybank 生成）。
/// 题库里的每一句都录好了高质量的英文配音；每关有 3 套题，每次进关轮到下一套，套内打乱顺序。
/// 找不到题库时退回现场随机出题（那样就只能用系统语音读）。
enum StoryBank {
    private static let bank: [Int: [StoryProblem]] = {
        guard let url = Bundle.main.url(forResource: "story_bank", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: [StoryProblem]].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in Int(k).map { ($0, v) } })
    }()

    /// 题库里这一关一共有几道题（= 这一关最多几颗星）；没有题库就是 nil
    static func problemCount(for level: StoryLevel) -> Int? {
        guard let all = bank[level.number], all.count >= level.problemCount else { return nil }
        return all.count / level.problemCount * level.problemCount
    }

    /// 这一关下一套题。avoiding：刚做完那套题的 starKey ——"Play again"时跳过那一套，绝不原样再出一遍
    static func problems(for level: StoryLevel, avoiding: Set<String> = []) -> [StoryProblem]? {
        let n = level.problemCount
        guard let all = bank[level.number], all.count >= n else { return nil }
        let sets = all.count / n
        let key = "wp.set.\(level.number)"
        let start = UserDefaults.standard.integer(forKey: key)
        // 从轮到的那套往后找第一套和刚做完的不重叠的（三套题本来互不重复，一般就是轮到的那套）
        let skip = (0..<sets).first { k in
            let s = (start + k) % sets
            return all[s * n ..< (s + 1) * n].allSatisfy { !avoiding.contains($0.starKey(level: level.number)) }
        } ?? 0
        let i = (start + skip) % sets
        UserDefaults.standard.set(i + 1, forKey: key)
        let chunk = Array(all[i * n ..< (i + 1) * n])
        // 读题关里第 3、6、9 题是复习题，位置保留；其余打乱
        let fixed: Set<Int> = level.mode == .read ? [2, 5, 8] : []
        var free = chunk.indices.filter { !fixed.contains($0) }.map { chunk[$0] }.shuffled()
        return chunk.indices.map { fixed.contains($0) ? chunk[$0] : free.removeFirst() }
    }
}
