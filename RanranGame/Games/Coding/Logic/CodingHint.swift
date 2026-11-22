import Foundation

// 提示的第二下：拿她现在的程序和参考答案一块一块比（主程序、★、◆ 依次，先外后里），找到第一处不一样的地方：
//   她这一层还少积木 → 在那个空位上用发光的影子摆出参考答案的下一块（带壳的积木只摆壳和次数，里面的下一次再提示）
//   她放的那一块不对（种类不同、次数不同、多出来的）→ 把这一块圈出来
//   都一样 → 没什么可提示的（说"点开始试试"）
// 每次只多给一块，不把整串答案摆出来。只用 Foundation。

enum CodingHint {
    enum Result: Equatable {
        /// 影子：把这一块摆在这个空位上以后的程序（界面上，比她的程序多出来的那一块画成影子）
        case ghost(CodingProgram, CodingSlot)
        /// 这一块不对
        case ring(CodingRef)
        case none
    }

    static func next(current: CodingProgram, reference: CodingProgram) -> Result {
        for t in 0..<3 {
            let r = compare(current, current.tracks[t], reference.tracks[t], track: t, path: [])
            if r != .none { return r }
        }
        return .none
    }

    private static func compare(_ whole: CodingProgram, _ c: [CodingBlock], _ r: [CodingBlock], track: Int, path: [Int]) -> Result {
        for i in 0..<max(c.count, r.count) {
            let here = CodingRef(track: track, path: path + [i])
            if i >= c.count {
                let shell = r[i].body == nil ? r[i] : r[i].withBody([])
                let slot = CodingSlot(track: track, container: path, index: i)
                var g = whole
                _ = g.insert(shell, at: slot)
                return .ghost(g, slot)
            }
            if i >= r.count { return .ring(here) }
            if c[i].piece != r[i].piece { return .ring(here) }
            if case let .loop(a, _) = c[i], case let .loop(b, _) = r[i], a != b { return .ring(here) }
            if let cb = c[i].body, let rb = r[i].body {
                let x = compare(whole, cb, rb, track: track, path: path + [i])
                if x != .none { return x }
            }
        }
        return .none
    }
}
