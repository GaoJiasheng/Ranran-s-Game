import Foundation

// 读 tools/klotski/levels.txt，用求解器算出每一关的最少步数，按步数排好、编好号，写成 KlotskiLevelData.swift。
// 用法：zsh tools/klotski/emit.sh（不带参数只打印；带 --write 才写文件）
//
// levels.txt 每行：<组 id> <盘面> [| 名字] [# 备注]
// 关卡 id = 组 id 的第一个字母 + 两位序号（按最少步数从小到大排；步数一样按 levels.txt 里的先后）。
// 关卡 id 会写进存档：发布以后只能往每组末尾加新关，不能再改顺序（所以发布后不要再重新生成已有的组）。

let args = CommandLine.arguments
let root = args[1]
let write = args.contains("--write")

struct Row { var pack: String; var layout: String; var name: String; var order: Int; var min: Int }

var rows: [Row] = []
let text = try! String(contentsOfFile: root + "/tools/klotski/levels.txt", encoding: .utf8)
for (i, raw) in text.split(separator: "\n").enumerated() {
    var line = String(raw)
    if let h = line.firstIndex(of: "#") { line = String(line[..<h]) }
    line = line.trimmingCharacters(in: .whitespaces)
    if line.isEmpty { continue }
    var name = ""
    if let bar = line.firstIndex(of: "|") {
        name = line[line.index(after: bar)...].trimmingCharacters(in: .whitespaces)
        line = String(line[..<bar]).trimmingCharacters(in: .whitespaces)
    }
    let parts = line.split(separator: " ").map(String.init)
    guard parts.count == 2, let b = KlotskiBoard(layout: parts[1]) else { print("第 \(i + 1) 行读不懂：\(raw)"); exit(1) }
    guard let m = KlotskiSolver.minMoves(b) else { print("第 \(i + 1) 行无解：\(raw)"); exit(1) }
    rows.append(Row(pack: parts[0], layout: parts[1], name: name, order: i, min: m))
}

var packs: [String] = []
for r in rows where !packs.contains(r.pack) { packs.append(r.pack) }
var out = """
// 自动生成，不要手改：改 tools/klotski/levels.txt 以后跑 zsh tools/klotski/emit.sh --write
// 每一关：组、关卡 id（存档里用，定了不改）、盘面、最少步数（求解器算的，tools/klotski/test.sh 会再验一遍）、名字

enum KlotskiLevelData {
    static let all: [KlotskiLevel] = [

"""
for p in packs {
    let sorted = rows.filter { $0.pack == p }.sorted { ($0.min, $0.order) < ($1.min, $1.order) }
    out += "        // \(p)\n"
    for (i, r) in sorted.enumerated() {
        let id = "\(p.prefix(1))\(String(format: "%02d", i + 1))"
        out += "        KlotskiLevel(pack: \"\(p)\", id: \"\(id)\", layout: \"\(r.layout)\", minMoves: \(r.min)\(r.name.isEmpty ? "" : ", name: \"\(r.name)\"")),\n"
        print(p, id, r.layout, r.min, r.name)
    }
}
out += "    ]\n}\n"
if write {
    try! out.write(toFile: root + "/RanranGame/Games/Klotski/Logic/KlotskiLevelData.swift", atomically: true, encoding: .utf8)
    print("写好了 KlotskiLevelData.swift")
}
