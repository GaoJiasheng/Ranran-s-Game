import Foundation

/// 一个图形（关卡的目标影子）：七块板子的一种参考摆法。影子 = 这七块拼起来的样子。
struct TangramFigure: Hashable, Identifiable {
    /// 存档里用的名字（也是关卡 id）
    let id: String
    /// 拼完时显示的名字（只显示，不朗读）
    let name: String
    let pieces: [TangramPlacement]

    var poses: [TangramPose] { pieces.map(\.pose) }
    var polygons: [[TangramPoint]] { poses.map(\.vertices) }

    static func find(_ id: String) -> TangramFigure? { all.first { $0.id == id } }
}

/// 拼得对不对：只看形状，不看是不是每块都在参考位置上——两个大三角可以互换、两个小三角可以换成别的拼法……
/// 只要每块板子都在影子里面、板子之间不重叠、加起来的面积正好等于影子，就是拼好了。
enum TangramChecker {
    static let eps = 1e-6

    /// 一块板子落在影子里的面积（影子 = 参考摆法的几块，互不重叠，所以分别相交再加起来）
    static func insideArea(_ piece: [TangramPoint], target: [[TangramPoint]]) -> Double {
        target.reduce(0) { $0 + TangramGeo.overlap(piece, $1) }
    }

    /// 这块板子整块都在影子里
    static func inside(_ piece: [TangramPoint], target: [[TangramPoint]]) -> Bool {
        insideArea(piece, target: target) >= TangramGeo.area(piece) - eps
    }

    /// 这块板子放在这里"合适"：在影子里，也不和别的板子重叠
    static func fits(_ piece: [TangramPoint], target: [[TangramPoint]], others: [[TangramPoint]]) -> Bool {
        guard inside(piece, target: target) else { return false }
        return others.allSatisfy { TangramGeo.overlap(piece, $0) <= eps }
    }

    /// 拼好了：placed 恰好盖满 target（fixed 是本来就摆好的、不能动的几块，也算在里面）
    static func solved(_ placed: [TangramPose], target: [TangramPose], fixed: [TangramPose] = []) -> Bool {
        let t = target.map(\.vertices)
        let all = (placed + fixed).map(\.vertices)
        let need = t.reduce(0) { $0 + TangramGeo.area($1) }
        let have = all.reduce(0) { $0 + TangramGeo.area($1) }
        guard abs(need - have) <= eps else { return false }
        for (i, p) in all.enumerated() {
            guard inside(p, target: t) else { return false }
            for j in (i + 1)..<all.count where TangramGeo.overlap(p, all[j]) > eps { return false }
        }
        return true
    }

    /// 参考摆法里还空着的位置（按大块先来的顺序）：没有同一种板子正好放在那里的
    static func openSlots(_ placed: [TangramPose], target: [TangramPose]) -> [Int] {
        let order: [TangramKind] = [.large, .medium, .square, .parallelogram, .small]
        var used = Set<Int>()
        var open: [Int] = []
        for (i, t) in target.enumerated() {
            if let j = placed.indices.first(where: { !used.contains($0) && placed[$0].sameSpot(t) }) {
                used.insert(j)
            } else {
                open.append(i)
            }
        }
        return open.sorted { (order.firstIndex(of: target[$0].kind) ?? 0, $0) < (order.firstIndex(of: target[$1].kind) ?? 0, $1) }
    }
}

/// 拖动时的"吸附"：板子靠近一个合适的位置时，自己跳过去对齐。
/// 候选位置 = 让板子的某个顶点正好落在一个"目标点"上：影子和别的板子的顶点，以及它们边上的格点
/// （从端点量 1、√2、2……这些长度的地方）。这样吸附以后的位置还在格子上，判断是精确的。
enum TangramSnapper {
    /// 边上可能有别的板子顶点的距离：a + b√2
    private static let steps: [Double] = {
        var out: [Double] = []
        for a in 0...4 { for b in 0...3 where a + b > 0 { out.append(Double(a) + Double(b) * 2.0.squareRoot()) } }
        return out.sorted()
    }()

    /// 一组多边形的顶点和边上的格点
    static func anchors(_ polys: [[TangramPoint]]) -> [TangramPoint] {
        var out: [TangramPoint] = []
        var seen = Set<[Int]>()
        func add(_ p: TangramPoint) { if seen.insert(TangramGeo.key(p)).inserted { out.append(p) } }
        for poly in polys {
            for i in poly.indices {
                let a = poly[i], b = poly[(i + 1) % poly.count]
                add(a)
                let len = a.distance(b)
                let u = (b - a) * (1 / len)
                for d in steps where d < len - 1e-9 {
                    add(a + u * d)
                    add(b - u * d)
                }
            }
        }
        return out
    }

    /// 吸附结果：新的位置，以及这个位置是不是"合适"（在影子里、不和别的重叠）
    struct Result {
        var pose: TangramPose
        var fits: Bool
    }

    /// pose 附近最好的吸附位置。fitRadius 以内优先找"合适"的位置；plainRadius 以内找任何对齐的位置。都没有是 nil。
    static func snap(_ pose: TangramPose, target: [[TangramPoint]], others: [[TangramPoint]],
                     fitRadius: Double = 0.9, plainRadius: Double = 0.4) -> Result? {
        snap(pose, anchors: anchors(target + others), target: target, others: others,
             fitRadius: fitRadius, plainRadius: plainRadius)
    }

    /// 同上，目标点已经算好（拖动时每一帧都要算，界面那边把影子的目标点存起来）
    static func snap(_ pose: TangramPose, anchors points: [TangramPoint], target: [[TangramPoint]], others: [[TangramPoint]],
                     fitRadius: Double = 0.9, plainRadius: Double = 0.4) -> Result? {
        let shape = TangramPose.shape(pose.kind, rotation: pose.rotation, flipped: pose.flipped)
        let here = pose.offset
        var candidates: [(t: TangramPoint, d: Double)] = []
        var seen = Set<[Int]>()
        for p in points {
            for v in shape {
                let t = p - v
                let d = t.distance(here)
                guard d <= max(fitRadius, plainRadius), seen.insert(TangramGeo.key(t)).inserted else { continue }
                candidates.append((t, d))
            }
        }
        candidates.sort { $0.d < $1.d }
        var plain: Result?
        for c in candidates {
            var p = pose
            p.offset = c.t
            let verts = p.vertices
            if c.d <= fitRadius, TangramChecker.fits(verts, target: target, others: others) {
                return Result(pose: p, fits: true)
            }
            if plain == nil, c.d <= plainRadius {
                // 不合适的位置只在不和别的板子重叠时才吸（叠在别的板子上面没有意义）
                if others.allSatisfy({ TangramGeo.overlap(verts, $0) <= TangramChecker.eps }) {
                    plain = Result(pose: p, fits: false)
                }
            }
        }
        return plain
    }
}
