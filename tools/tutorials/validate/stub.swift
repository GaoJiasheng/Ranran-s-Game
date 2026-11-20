import Foundation

// 校验程序共用的部分：代替 App 的 PlayerStore（只要计数），以及把一课变成"每段练习题 × 每种变换"。

final class PlayerStore {
    var counts: [String: Int] = [:]
    func count(_ k: String) -> Int { counts[k, default: 0] }
    func setCount(_ k: String, _ v: Int) { counts[k] = v }
    func increment(_ k: String) { counts[k, default: 0] += 1 }
}

func loadCourse(_ root: String, _ g: String) -> TutorialCourse {
    let data = try! Data(contentsOf: URL(fileURLWithPath: root + "/RanranGame/Tutorials/\(g).json"))
    return try! JSONDecoder().decode(TutorialCourse.self, from: data)
}

/// 一课的每一段练习题，配上每一种对称变换（包括不变的那种：练习题去掉了前后步骤，也要单独能做）
func practiceVariants(_ l: TutorialLesson, game: String) -> [(name: String, lesson: TutorialLesson)] {
    var out: [(String, TutorialLesson)] = []
    for (si, seg) in LessonPractice.segments(l, game: game).enumerated() {
        let size = seg.first?.board.map(LessonPractice.boardSize) ?? 9
        for sym in LessonSymmetry.all(game, size: size) {
            var v = l
            v.id = "\(l.id)~练习\(si + 1)~变换\(sym.kind)"
            v.steps = seg.map(sym.step)
            out.append((v.id, v))
        }
    }
    return out
}
