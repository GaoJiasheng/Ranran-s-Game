import Foundation

// 华容道的关卡分组。组和关的 id 会写进存档，定了就不能改。见 docs/new-games.md。
//
// 四组，从易到难（每一步都是"一块木块直直地滑过几格"，见 KlotskiBoard.swift）：
//   入门  木块很少、空地很大，最少 2–10 步：学会"先把挡路的挪开"
//   进阶  木块多起来，最少 10–25 步：要先后挪两三块才能给小兔让路
//   高手  满满一盘木块（只剩 3–4 个空格），最少 25–50 步：要一直盯着空位
//   大师  传统的满盘（两个空格）：从横刀立马一类的布局，60–110 步，是最后的山顶
// 通过前 3 组（入门、进阶、高手）算"学会了"；大师是挑战，不挡毕业。

/// 一关
struct KlotskiLevel: Hashable {
    let pack: String
    let id: String
    /// 起始盘面，写法见 KlotskiBoard
    let layout: String
    /// 最少几步（求解器算的）
    let minMoves: Int
    var name: String = ""

    var board: KlotskiBoard { KlotskiBoard(layout: layout)! }

    /// 「步数不多」这颗星的上限，也是屏幕上写出来的目标：比最少步数多 3 步，或者多一半，取大的。
    /// 例：最少 4 步 → 7 步以内；最少 12 步 → 18 步以内；最少 90 步 → 135 步以内。
    /// 为什么这样：很短的关多 3 步才算得上"没绕路"（2 步的关给 5 步），很长的关按比例放宽（一步错步不会让整关作废），
    /// 而且总比最少步数大，所以一定做得到。
    var starBound: Int { KlotskiCatalog.starBound(minMoves: minMoves) }
}

struct KlotskiPackSpec {
    let id: String
    let name: String
    let subtitle: String
    /// 这一组每一关的最少步数必须落在这个范围里（tools/klotski/test.sh 检查）
    let minRange: ClosedRange<Int>
}

enum KlotskiCatalog {
    static let specs: [KlotskiPackSpec] = [
        KlotskiPackSpec(id: "intro", name: "入门", subtitle: "木块很少，先把挡路的挪开", minRange: 2...10),
        KlotskiPackSpec(id: "grow", name: "进阶", subtitle: "木块多起来，要想好先挪谁", minRange: 10...25),
        KlotskiPackSpec(id: "pro", name: "高手", subtitle: "满满一盘木块，空位不多", minRange: 25...50),
        KlotskiPackSpec(id: "classic", name: "大师", subtitle: "传统的华容道，越走越难", minRange: 60...120),
    ]

    static let levels: [KlotskiLevel] = KlotskiLevelData.all

    static let packs: [PuzzlePack] = specs.map { s in
        PuzzlePack(id: s.id, name: s.name, subtitle: s.subtitle, art: "pack_klotski_\(s.id)",
                   levels: levels.filter { $0.pack == s.id }.map(\.id))
    }

    /// 通过前几组算"学会了"：入门、进阶、高手。大师是最后的挑战，不挡毕业。
    static let passPacks = 3

    static func level(_ id: String) -> KlotskiLevel? { levels.first { $0.id == id } }

    static func starBound(minMoves m: Int) -> Int { max(m + 3, (m * 3 + 1) / 2) }
}
