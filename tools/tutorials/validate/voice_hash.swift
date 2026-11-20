import Foundation
import CryptoKit

// 配音清单：每一句台词（课文、练习说法、通用台词）都在 tools/voice/manifest.json 里，文件名对得上

func fileName(_ text: String) -> String {
    let digest = Insecure.SHA1.hash(data: Data(text.utf8))
    return "vo_" + digest.map { String(format: "%02x", $0) }.joined().prefix(10)
}
let root = CommandLine.arguments[1]
let manifest = try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: root + "/tools/voice/manifest.json"))) as! [[String: String]]
let files = Dictionary(uniqueKeysWithValues: manifest.map { ($0["text"]!, $0["file"]!) })
let speak = Dictionary(uniqueKeysWithValues: manifest.map { ($0["text"]!, $0["speak"]!) })
var needed: [String] = TutorLines.all
for g in ["gomoku", "xiangqi", "go"] {
    let c = loadCourse(root, g)
    for l in c.lessons {
        needed.append(TutorLines.lessonDone(l.learned))
        for s in l.steps { needed += [s.say, s.hint, s.ok, s.after, s.drill].compactMap { $0 } }
    }
}
var bad = 0
for t in Set(needed) {
    guard let f = files[t] else { print("MISSING in manifest:", t); bad += 1; continue }
    if f != fileName(t) { print("HASH MISMATCH:", t); bad += 1 }
}
// 反过来：清单里多出来的句子 = build_manifest.py 的 COMMON 和 TutorLines 对不上了
for t in files.keys where !Set(needed).contains(t) { print("IN MANIFEST BUT NOT IN TutorLines / lessons:", t); bad += 1 }
// 象棋的固定台词要按象棋读音配（车 / 相 / 将），围棋的按围棋读音——放错了 COMMON 列表就读错
for t in TutorLines.xiangqi where t.contains("车") || t.contains("相") {
    if speak[t] == t { print("NO XIANGQI PRONUNCIATION FIX:", t); bad += 1 }
}
for t in TutorLines.common where ["车", "相", "将", "帅"].contains(where: { t.contains($0) }) {
    print("XIANGQI WORD IN A COMMON LINE (move it to COMMON_XIANGQI / TutorLines.xiangqi):", t); bad += 1
}
print("checked", Set(needed).count, "lines;", bad == 0 ? "all match" : "\(bad) problems")
