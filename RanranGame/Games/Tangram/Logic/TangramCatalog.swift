import Foundation

// 七巧板的关卡分组。组和关的 id 会写进存档，定了就不能改（关卡 id = 图形 id，见 tools/tangram/figures.py）。
//
//   入门 start   影子里画出每一块的分界线，只要照着形状放；前几关托盘里的板子已经转好了，拖过去就行
//   进阶 turn    还有分界线，但板子要自己转到对的方向，平行四边形有时要翻面
//   高手 shadow  只有一整块黑影，自己想哪块放哪里；可以「看一眼」分界线
//   大师 master  只有黑影，图形更难（动物、人）
//
// passPacks = 3：前三组都过了才算"学会了"。入门、进阶有分界线，只是照着放（练的是认形状、会转会翻）；
// 真正的七巧板是看着一整块黑影自己想，所以至少要过完「高手」。大师组留给想挑战的时候。

/// 一关怎么玩
struct TangramLevel: Hashable {
    let figure: TangramFigure
    /// 第几组（从 0 开始）
    let pack: Int
    /// 第几关（组内，从 0 开始）
    let index: Int
    /// 影子里画出每一块的分界线
    let outlines: Bool
    /// 托盘里的板子一开始就转成影子里的方向
    let preRotated: Bool

    var id: String { figure.id }

    /// 三颗星的第三颗：没有分界线的组是"没偷看"，有分界线的组是"提示最多用一次"
    var peekStar: Bool { !outlines }

    /// 托盘里一开始的样子（种类、朝向），按 TangramKind.set 的顺序：大、大、中、正方形、平行四边形、小、小
    var trayStart: [TangramPose] {
        guard preRotated else { return TangramKind.set.map { TangramPose(kind: $0) } }
        var refs = figure.poses
        return TangramKind.set.map { kind in
            guard let i = refs.firstIndex(where: { $0.kind == kind }) else { return TangramPose(kind: kind) }
            let r = refs.remove(at: i)
            return TangramPose(kind: kind, rotation: r.rotation, flipped: r.flipped)
        }
    }
}

enum TangramCatalog {
    private struct PackDef {
        let id: String
        let name: String
        let subtitle: String
        let outlines: Bool
        /// 前几关托盘里的板子已经转好
        let preRotated: Int
        let figures: [String]
    }

    private static let defs: [PackDef] = [
        PackDef(id: "start", name: "入门", subtitle: "照着影子里的线，把板子放进去", outlines: true, preRotated: 6,
                figures: ["square", "house", "boat", "arrow", "rocket", "tree",
                          "triangle", "diamond", "cup", "teapot", "heart", "rectangle"]),
        PackDef(id: "turn", name: "进阶", subtitle: "先把板子转一转、翻一翻，再放进去", outlines: true, preRotated: 0,
                figures: ["parallelogram", "trapezoid", "rtrapezoid", "hexagon", "bowtie", "bridge",
                          "train", "kite", "fish", "cat", "swan", "icecream"]),
        PackDef(id: "shadow", name: "高手", subtitle: "影子里没有线了，自己想一想", outlines: false, preRotated: 0,
                figures: ["mushroom", "goldfish", "turtle", "whale", "duck", "penguin", "bird", "umbrella"]),
        PackDef(id: "master", name: "大师", subtitle: "小动物和小朋友，最难的影子", outlines: false, preRotated: 0,
                figures: ["rabbit", "elephant", "dinosaur", "squirrel", "mouse", "rooster", "runner", "cheer"]),
    ]

    static let packs: [PuzzlePack] = defs.map {
        PuzzlePack(id: $0.id, name: $0.name, subtitle: $0.subtitle, art: "pack_tangram_\($0.id)", levels: $0.figures)
    }

    /// 通过前几组算"学会了"（见文件开头）
    static let passPacks = 3

    static func level(_ id: String) -> TangramLevel? {
        for (pi, d) in defs.enumerated() {
            guard let i = d.figures.firstIndex(of: id), let f = TangramFigure.find(id) else { continue }
            return TangramLevel(figure: f, pack: pi, index: i, outlines: d.outlines, preRotated: i < d.preRotated)
        }
        return nil
    }

    static var levels: [TangramLevel] { defs.flatMap(\.figures).compactMap(level) }
}
