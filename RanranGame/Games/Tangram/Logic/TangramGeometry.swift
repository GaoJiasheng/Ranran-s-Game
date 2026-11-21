import Foundation

// 七巧板的几何：七块板子、转和翻、多边形面积和相交。只用 Foundation（命令行测试也编译这个文件夹）。
//
// 单位：大正方形边长 4（面积 16），y 轴朝上。这样最常见的摆法坐标都是整数：
//   大三角 large：斜边 4、直角边 2√2      (0,0) (4,0) (2,2)
//   中三角 medium：直角边 2、斜边 2√2     (0,0) (2,0) (0,2)
//   小三角 small：斜边 2、直角边 √2       (0,0) (2,0) (1,1)
//   正方形 square：边长 √2（摆成菱形）    (0,1) (1,0) (2,1) (1,2)
//   平行四边形 parallelogram：边 2 和 √2   (0,0) (2,0) (3,1) (1,1)
// 一块板子的摆法 = 先翻面（x 变成 -x，只有平行四边形需要），再绕原点逆时针转 rotation × 45°，再平移。
// 图形里的坐标都在"格子"上：(m + n√2) / 2，m、n 是整数（TangramNum），转 45° 的倍数、平移以后还在格子上。
// 拼的时候浮点误差在 1e-12 左右；格子上两个不同的位置（系数不大时）至少差 1e-3，所以判断用 1e-6 的容差。

struct TangramPoint: Hashable, Codable {
    var x: Double
    var y: Double

    init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    static func + (a: Self, b: Self) -> Self { .init(a.x + b.x, a.y + b.y) }
    static func - (a: Self, b: Self) -> Self { .init(a.x - b.x, a.y - b.y) }
    static func * (a: Self, k: Double) -> Self { .init(a.x * k, a.y * k) }

    var length: Double { (x * x + y * y).squareRoot() }

    func distance(_ o: Self) -> Double { (self - o).length }

    /// 绕原点逆时针转 steps × 45°
    func rotated(_ steps: Int) -> Self {
        let k = ((steps % 8) + 8) % 8
        let h = 0.5.squareRoot()
        switch k {
        case 0: return self
        case 1: return .init((x - y) * h, (x + y) * h)
        case 2: return .init(-y, x)
        case 3: return .init((-x - y) * h, (x - y) * h)
        case 4: return .init(-x, -y)
        case 5: return .init((y - x) * h, (-x - y) * h)
        case 6: return .init(y, -x)
        default: return .init((x + y) * h, (y - x) * h)
        }
    }
}

/// 格子上的一个坐标：(m + n√2) / 2
struct TangramNum: Hashable, Codable {
    var m: Int
    var n: Int

    init(_ m: Int, _ n: Int) {
        self.m = m
        self.n = n
    }

    static let sqrt2 = 2.0.squareRoot()
    var value: Double { (Double(m) + Double(n) * Self.sqrt2) / 2 }

    static func + (a: Self, b: Self) -> Self { .init(a.m + b.m, a.n + b.n) }
    static prefix func - (a: Self) -> Self { .init(-a.m, -a.n) }

    /// 找一个系数不大的格子坐标等于 v（找不到是 nil）
    static func near(_ v: Double, maxN: Int = 40) -> TangramNum? {
        for n in -maxN...maxN {
            let m = (2 * v - Double(n) * sqrt2).rounded()
            let t = TangramNum(Int(m), n)
            if abs(t.value - v) < 1e-7 { return t }
        }
        return nil
    }
}

enum TangramKind: String, CaseIterable, Codable, Hashable {
    case large, medium, small, square, parallelogram

    /// 写在教学局面里的字母
    var letter: String {
        switch self {
        case .large: "L"
        case .medium: "M"
        case .small: "S"
        case .square: "Q"
        case .parallelogram: "P"
        }
    }

    init?(letter: String) {
        guard let k = Self.allCases.first(where: { $0.letter == letter }) else { return nil }
        self = k
    }

    var name: String {
        switch self {
        case .large: "大三角形"
        case .medium: "中三角形"
        case .small: "小三角形"
        case .square: "正方形"
        case .parallelogram: "平行四边形"
        }
    }

    /// 一套七巧板里有几块
    var count: Int { self == .large || self == .small ? 2 : 1 }

    var area: Double {
        switch self {
        case .large: 4
        case .medium, .square, .parallelogram: 2
        case .small: 1
        }
    }

    var canonical: [TangramPoint] {
        switch self {
        case .large: [.init(0, 0), .init(4, 0), .init(2, 2)]
        case .medium: [.init(0, 0), .init(2, 0), .init(0, 2)]
        case .small: [.init(0, 0), .init(2, 0), .init(1, 1)]
        case .square: [.init(0, 1), .init(1, 0), .init(2, 1), .init(1, 2)]
        case .parallelogram: [.init(0, 0), .init(2, 0), .init(3, 1), .init(1, 1)]
        }
    }

    /// 翻过来以后和原来不一样（只有平行四边形）
    var chiral: Bool { self == .parallelogram }

    /// 一整套，按托盘里的顺序：大、大、中、正方形、平行四边形、小、小
    static let set: [TangramKind] = [.large, .large, .medium, .square, .parallelogram, .small, .small]
}

/// 一块板子放在哪（浮点，拖动中用）
struct TangramPose: Hashable, Codable {
    var kind: TangramKind
    /// 0…7，逆时针 × 45°
    var rotation: Int
    var flipped: Bool
    var x: Double
    var y: Double

    init(kind: TangramKind, rotation: Int = 0, flipped: Bool = false, x: Double = 0, y: Double = 0) {
        self.kind = kind
        self.rotation = ((rotation % 8) + 8) % 8
        self.flipped = flipped
        self.x = x
        self.y = y
    }

    var offset: TangramPoint {
        get { .init(x, y) }
        set {
            x = newValue.x
            y = newValue.y
        }
    }

    /// 没有平移时的形状（转好、翻好）
    static func shape(_ kind: TangramKind, rotation: Int, flipped: Bool) -> [TangramPoint] {
        var pts = kind.canonical
        if flipped { pts = pts.map { .init(-$0.x, $0.y) } }
        pts = pts.map { $0.rotated(rotation) }
        return TangramGeo.ccw(pts)
    }

    var vertices: [TangramPoint] {
        Self.shape(kind, rotation: rotation, flipped: flipped).map { $0 + offset }
    }

    /// 板子的重心
    var centroid: TangramPoint { TangramGeo.centroid(vertices) }

    /// 原样不动的板子转 steps × 45°，重心不动
    func turned(_ steps: Int) -> TangramPose {
        let c = centroid
        var p = self
        p.rotation = ((rotation + steps) % 8 + 8) % 8
        p.offset = .init(0, 0)
        p.offset = c - p.centroid
        return p
    }

    /// 翻面（左右翻），重心不动
    func mirrored() -> TangramPose {
        let c = centroid
        var p = self
        // 翻面后转角也要左右翻：形状 = R(r) F c 镜像以后 = R(-r) F' c
        p.flipped.toggle()
        p.rotation = (8 - rotation) % 8
        p.offset = .init(0, 0)
        p.offset = c - p.centroid
        return p.normalized()
    }

    /// 对称的板子（除了平行四边形）翻面等于转一下：统一成不翻面的写法
    func normalized() -> TangramPose {
        guard flipped, !kind.chiral else { return self }
        let target = Set(vertices.map(TangramGeo.key))
        for r in 0..<8 {
            let sh = Self.shape(kind, rotation: r, flipped: false)
            for v in sh {
                // 让 sh 的某个顶点对上 vertices[0]
                let t = vertices[0] - v
                if Set(sh.map { TangramGeo.key($0 + t) }) == target {
                    return TangramPose(kind: kind, rotation: r, flipped: false, x: t.x, y: t.y)
                }
            }
        }
        return self
    }

    /// 两块板子放得一模一样（形状和位置都一样）
    func sameSpot(_ o: TangramPose) -> Bool {
        kind == o.kind && Set(vertices.map(TangramGeo.key)) == Set(o.vertices.map(TangramGeo.key))
    }

    /// 整体变换（练习时用）：先左右翻（mirror），再逆时针转 quarter × 90°
    func transformed(quarter: Int, mirror: Bool) -> TangramPose {
        var p = self
        if mirror {
            p.flipped.toggle()
            p.rotation = (8 - p.rotation) % 8
            p.x = -p.x
        }
        let o = TangramPoint(p.x, p.y).rotated(2 * quarter)
        p.rotation = (p.rotation + 2 * quarter) % 8
        p.x = o.x
        p.y = o.y
        return p.normalized()
    }
}

/// 图形里的一块板子（精确的格子坐标）
struct TangramPlacement: Hashable {
    var kind: TangramKind
    var rotation: Int
    var flipped: Bool
    var x: TangramNum
    var y: TangramNum

    var pose: TangramPose { TangramPose(kind: kind, rotation: rotation, flipped: flipped, x: x.value, y: y.value) }
}

/// 多边形工具（凸多边形：七块板子都是凸的）
enum TangramGeo {
    static let eps = 1e-6

    /// 比较顶点用的键（四舍五入到 1e-6）
    static func key(_ p: TangramPoint) -> [Int] { [Int((p.x * 1e6).rounded()), Int((p.y * 1e6).rounded())] }

    static func signedArea(_ p: [TangramPoint]) -> Double {
        var s = 0.0
        for i in p.indices {
            let a = p[i], b = p[(i + 1) % p.count]
            s += a.x * b.y - b.x * a.y
        }
        return s / 2
    }

    static func area(_ p: [TangramPoint]) -> Double { abs(signedArea(p)) }

    /// 统一成逆时针
    static func ccw(_ p: [TangramPoint]) -> [TangramPoint] { signedArea(p) >= 0 ? p : p.reversed() }

    static func centroid(_ p: [TangramPoint]) -> TangramPoint {
        var cx = 0.0, cy = 0.0, a = 0.0
        for i in p.indices {
            let u = p[i], v = p[(i + 1) % p.count]
            let c = u.x * v.y - v.x * u.y
            a += c
            cx += (u.x + v.x) * c
            cy += (u.y + v.y) * c
        }
        guard abs(a) > 1e-12 else { return p.first ?? .init(0, 0) }
        return .init(cx / (3 * a), cy / (3 * a))
    }

    /// 凸多边形相交（Sutherland–Hodgman），两个都要逆时针
    static func clip(_ subject: [TangramPoint], _ clipper: [TangramPoint]) -> [TangramPoint] {
        var out = subject
        for i in clipper.indices {
            let a = clipper[i], b = clipper[(i + 1) % clipper.count]
            let input = out
            out = []
            guard !input.isEmpty else { break }
            func side(_ p: TangramPoint) -> Double { (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x) }
            for j in input.indices {
                let p = input[j], q = input[(j + 1) % input.count]
                let sp = side(p), sq = side(q)
                if sp >= 0 { out.append(p) }
                if (sp >= 0) != (sq >= 0) {
                    let t = sp / (sp - sq)
                    out.append(.init(p.x + (q.x - p.x) * t, p.y + (q.y - p.y) * t))
                }
            }
        }
        return out
    }

    /// 两个凸多边形重叠的面积
    static func overlap(_ a: [TangramPoint], _ b: [TangramPoint]) -> Double {
        let c = clip(ccw(a), ccw(b))
        return c.count >= 3 ? area(c) : 0
    }

    /// 点在凸多边形里（含边上，容差 tol）
    static func contains(_ poly: [TangramPoint], _ p: TangramPoint, tol: Double = 0) -> Bool {
        let q = ccw(poly)
        for i in q.indices {
            let a = q[i], b = q[(i + 1) % q.count]
            let cross = (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)
            let len = a.distance(b)
            if cross / len < -tol { return false }
        }
        return true
    }

    static func segmentDistance(_ p: TangramPoint, _ a: TangramPoint, _ b: TangramPoint) -> Double {
        let d = b - a
        let l2 = d.x * d.x + d.y * d.y
        let t = l2 == 0 ? 0 : max(0, min(1, ((p.x - a.x) * d.x + (p.y - a.y) * d.y) / l2))
        return p.distance(a + d * t)
    }

    /// 点到凸多边形的距离（在里面是 0）
    static func distance(_ poly: [TangramPoint], _ p: TangramPoint) -> Double {
        if contains(poly, p) { return 0 }
        var best = Double.infinity
        for i in poly.indices { best = min(best, segmentDistance(p, poly[i], poly[(i + 1) % poly.count])) }
        return best
    }

    static func bounds(_ polys: [[TangramPoint]]) -> (min: TangramPoint, max: TangramPoint) {
        let pts = polys.flatMap { $0 }
        guard let f = pts.first else { return (.init(0, 0), .init(0, 0)) }
        var lo = f, hi = f
        for p in pts {
            lo = .init(min(lo.x, p.x), min(lo.y, p.y))
            hi = .init(max(hi.x, p.x), max(hi.y, p.y))
        }
        return (lo, hi)
    }

    /// 两块板子挨着（共边或者共点）
    static func touching(_ a: [TangramPoint], _ b: [TangramPoint], tol: Double = 1e-6) -> Bool {
        for v in a { for i in b.indices where segmentDistance(v, b[i], b[(i + 1) % b.count]) < tol { return true } }
        for v in b { for i in a.indices where segmentDistance(v, a[i], a[(i + 1) % a.count]) < tol { return true } }
        return false
    }
}
