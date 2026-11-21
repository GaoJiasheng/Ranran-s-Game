import Foundation

// 七巧板教学里的一个局面，以及判题。
//
// 局面写成一串 "键=值"，用分号隔开（Tutorials/tangram.json 里的 board）：
//   target=L.0.0.0.0.0.0|S.2.0.4.0.2.0   影子：参考摆法的几块（影子就是它们拼起来的样子）
//   fixed=...                            已经摆好、不能动的几块（画成彩色，算在影子里）
//   tray=L.0.0,S.3.0                     托盘里给她的板子（只有种类和朝向）
//   lines=1                              影子里画出每一块的分界线（入门的题）；不写就是一整块黑影
//   fig=cat                              直接用一个关卡图形当影子（target 就是它的七块）
//   show=1                               不是题，只是摆给她看：target 的几块直接画成彩色
// 一块板子写成 字母.转角.翻面.mx.nx.my.ny：坐标 x = (mx + nx·√2)/2，y 同理（TangramNum）。字母 L M S Q P。
//
// 题目（task.type / task.rule）：
//   fill        把托盘里的板子全部放进影子，正好盖满（任何一种正确的拼法都算对）
//   pick:<字母>  点一下那种板子（比如 pick:L 点大三角形）

struct TangramLessonBoard: Hashable {
    var target: [TangramPose] = []
    var fixed: [TangramPose] = []
    var tray: [TangramPose] = []
    var lines = false
    var show = false

    init(target: [TangramPose] = [], fixed: [TangramPose] = [], tray: [TangramPose] = [], lines: Bool = false, show: Bool = false) {
        self.target = target
        self.fixed = fixed
        self.tray = tray
        self.lines = lines
        self.show = show
    }

    init?(spec: String) {
        for part in spec.split(separator: ";") {
            let kv = part.split(separator: "=", maxSplits: 1).map(String.init)
            guard kv.count == 2 else { continue }
            switch kv[0] {
            case "target":
                guard let p = Self.poses(kv[1]) else { return nil }
                target = p
            case "fixed":
                guard let p = Self.poses(kv[1]) else { return nil }
                fixed = p
            case "tray":
                guard let p = Self.orientations(kv[1]) else { return nil }
                tray = p
            case "fig":
                guard let f = TangramFigure.find(kv[1]) else { return nil }
                target = f.poses
            case "lines": lines = kv[1] == "1"
            case "show": show = kv[1] == "1"
            default: return nil
            }
        }
    }

    var spec: String {
        var parts: [String] = []
        if !target.isEmpty { parts.append("target=" + target.map(Self.encode).joined(separator: "|")) }
        if !fixed.isEmpty { parts.append("fixed=" + fixed.map(Self.encode).joined(separator: "|")) }
        if !tray.isEmpty { parts.append("tray=" + tray.map { "\($0.kind.letter).\($0.rotation).\($0.flipped ? 1 : 0)" }.joined(separator: ",")) }
        if lines { parts.append("lines=1") }
        if show { parts.append("show=1") }
        return parts.joined(separator: ";")
    }

    static func encode(_ p: TangramPose) -> String {
        let x = TangramNum.near(p.x) ?? TangramNum(0, 0)
        let y = TangramNum.near(p.y) ?? TangramNum(0, 0)
        return "\(p.kind.letter).\(p.rotation).\(p.flipped ? 1 : 0).\(x.m).\(x.n).\(y.m).\(y.n)"
    }

    static func decode(_ s: String) -> TangramPose? {
        let f = s.split(separator: ".").map(String.init)
        guard f.count == 7, let k = TangramKind(letter: f[0]), let r = Int(f[1]), let fl = Int(f[2]),
              let a = Int(f[3]), let b = Int(f[4]), let c = Int(f[5]), let d = Int(f[6]) else { return nil }
        return TangramPose(kind: k, rotation: r, flipped: fl == 1, x: TangramNum(a, b).value, y: TangramNum(c, d).value)
    }

    private static func poses(_ s: String) -> [TangramPose]? {
        let out = s.split(separator: "|").map { decode(String($0)) }
        return out.contains { $0 == nil } ? nil : out.compactMap { $0 }
    }

    private static func orientations(_ s: String) -> [TangramPose]? {
        var out: [TangramPose] = []
        for item in s.split(separator: ",") {
            let f = item.split(separator: ".").map(String.init)
            guard let k = TangramKind(letter: f[0]) else { return nil }
            let r = f.count > 1 ? Int(f[1]) ?? 0 : 0
            let fl = f.count > 2 ? f[2] == "1" : false
            out.append(TangramPose(kind: k, rotation: r, flipped: fl))
        }
        return out
    }

    /// 整个局面换个样子：左右翻（mirror）再逆时针转 quarter × 90°。托盘里的朝向一起变，题目难度不变。
    func transformed(quarter: Int, mirror: Bool) -> TangramLessonBoard {
        var b = self
        b.target = target.map { $0.transformed(quarter: quarter, mirror: mirror) }
        b.fixed = fixed.map { $0.transformed(quarter: quarter, mirror: mirror) }
        b.tray = tray.map {
            var p = $0.transformed(quarter: quarter, mirror: mirror)
            p.x = 0
            p.y = 0
            return p
        }
        return b
    }
}

enum TangramLessonLogic {
    /// fill 题：托盘里的板子放成 placed 以后，是不是正好盖满影子
    static func filled(_ placed: [TangramPose], board: TangramLessonBoard) -> Bool {
        TangramChecker.solved(placed, target: board.target, fixed: board.fixed)
    }

    /// pick 题：点的这一块对不对
    static func picked(_ kind: TangramKind, rule: String?) -> Bool {
        guard let rule, rule.hasPrefix("pick:") else { return false }
        return TangramKind(letter: String(rule.dropFirst(5))) == kind
    }

    /// pick 题要点的那种板子
    static func pickKind(_ rule: String?) -> TangramKind? {
        guard let rule, rule.hasPrefix("pick:") else { return nil }
        return TangramKind(letter: String(rule.dropFirst(5)))
    }

    /// fill 题的一个标准答案：托盘里每一块对应影子里的哪一块（同种板子按顺序配）。配不上是 nil。
    /// 影子里不在托盘里的那几块（比如 fixed 之外、本来就给出来的）不算。
    static func answer(_ board: TangramLessonBoard) -> [TangramPose]? {
        var left = board.target.filter { t in !board.fixed.contains { $0.sameSpot(t) } }
        var out: [TangramPose] = []
        for t in board.tray {
            guard let i = left.firstIndex(where: { $0.kind == t.kind }) else { return nil }
            out.append(left.remove(at: i))
        }
        return left.isEmpty ? out : nil
    }

    /// 一步的局面变换（练习用）：k = 0…7，k % 4 是转几个 90°，k ≥ 4 先左右翻
    static func transform(_ step: TutorialStep, _ k: Int) -> TutorialStep {
        guard k != 0 else { return step }
        var s = step
        if let spec = step.board, let b = TangramLessonBoard(spec: spec) {
            s.board = b.transformed(quarter: k % 4, mirror: k >= 4).spec
        }
        return s
    }
}
