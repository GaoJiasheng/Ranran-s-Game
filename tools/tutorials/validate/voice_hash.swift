import Foundation
import CryptoKit
final class PlayerStore { func count(_ k: String) -> Int { 0 }; func increment(_ k: String) {} }
func fileName(_ text: String) -> String {
    let digest = Insecure.SHA1.hash(data: Data(text.utf8))
    return "vo_" + digest.map { String(format: "%02x", $0) }.joined().prefix(10)
}
let root = CommandLine.arguments[1]
let manifest = try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: root + "/tools/voice/manifest.json"))) as! [[String: String]]
let files = Dictionary(uniqueKeysWithValues: manifest.map { ($0["text"]!, $0["file"]!) })
var needed: [String] = TutorLines.all
for g in ["gomoku", "xiangqi", "go"] {
    let c = try! JSONDecoder().decode(TutorialCourse.self, from: Data(contentsOf: URL(fileURLWithPath: root + "/RanranGame/Tutorials/\(g).json")))
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
print("checked", Set(needed).count, "lines;", bad == 0 ? "all match" : "\(bad) problems")
