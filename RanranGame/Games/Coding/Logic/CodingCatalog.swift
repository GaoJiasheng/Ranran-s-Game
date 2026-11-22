import Foundation

// 编程的关卡分组。组和关的 id 会写进存档，定了就不能改。见 docs/new-games.md 和 docs/tutorial-coding.md。
//
// 四组，每组 12 关，每组只加一个新想法：
//   一步一步（seq）  指令按顺序一条一条做
//   重复（loop）     一样的事只说一遍
//   绝招（func）     给一小段起个名字，到处用
//   如果（cond）     一个程序管好几种情况（一关有 2–3 个花园）
// 通过前两组算"学会了"；后两组是继续往上的挑战。每一关的性质由 tools/coding/test.sh 一关一关证明。

/// 一关
struct CodingLevel: Hashable {
    enum Kind: String { case build, bug }

    let pack: String
    let id: String
    /// 这一关的小名字（显示在关卡页上，不朗读）
    let name: String
    /// 花园，好几个用 | 隔开（写法见 CodingGarden）
    let gardens: String
    /// 积木盒和格子数，写法见 CodingLimits(spec:)
    let limits: String
    /// 参考答案（测试证明它每个花园都过、放得进格子；提示照着它给）
    let answer: String
    /// 「积木不多」这颗星的界限：最少要几块（测试用穷举证明比它少过不了，见 docs 里的关卡表）
    let par: Int
    /// 捉虫关：一开始就排好的、有一处错的程序
    var given: String? = nil

    var kind: Kind { given == nil ? .build : .bug }
    var gardenList: [CodingGarden] { CodingGardens.parse(gardens)! }
    var limitsValue: CodingLimits { CodingLimits(spec: limits)! }
    var answerProgram: CodingProgram { CodingProgram(text: answer)! }
    var givenProgram: CodingProgram? { given.flatMap { CodingProgram(text: $0) } }
    /// 打开这一关时程序里摆着什么
    var startProgram: CodingProgram { givenProgram ?? CodingProgram() }
}

struct CodingPackSpec {
    let id: String
    let name: String
    let subtitle: String
}

enum CodingCatalog {
    static let specs: [CodingPackSpec] = [
        CodingPackSpec(id: "seq", name: "一步一步", subtitle: "指令按顺序，一条一条做"),
        CodingPackSpec(id: "loop", name: "重复", subtitle: "一样的事，只说一遍"),
        CodingPackSpec(id: "func", name: "绝招", subtitle: "给一小段起个名字，到处用"),
        CodingPackSpec(id: "cond", name: "如果", subtitle: "一个程序，走好几个花园"),
    ]

    static let levels: [CodingLevel] = CodingLevelData.all

    static let packs: [PuzzlePack] = specs.map { s in
        PuzzlePack(id: s.id, name: s.name, subtitle: s.subtitle, art: "pack_coding_\(s.id)",
                   levels: levels.filter { $0.pack == s.id }.map(\.id))
    }

    /// 通过前几组算"学会了"：一步一步、重复
    static let passPacks = 2

    static func level(_ id: String) -> CodingLevel? { levels.first { $0.id == id } }

    static func packName(_ id: String) -> String { specs.first { $0.id == id }?.name ?? "" }

    /// 这一关是这一组的第几关（从 1 开始）
    static func number(_ level: CodingLevel) -> Int {
        (levels.filter { $0.pack == level.pack }.firstIndex(of: level) ?? 0) + 1
    }
}
