import Foundation

// 编程页面的尺寸怎么算（只用 Foundation，界面和测试共用一份）：
// 孩子用的页面不滚动，横竖屏、11 寸和 13 寸都要放得下最大的花园和这一关允许的最长的程序。
// 所以积木的大小不看她现在排了什么，而是按"每一格都放上最宽的积木"来算，一关之内大小不变、不会跳。
// tools/coding/test.sh 在四种屏幕（和教学的小一点的地方）上把每一关都算一遍，积木不能小于 56 点。
//
// 长度单位：u = 一块积木的边长。
//   箭头、绝招：1 × 1
//   带壳的积木（重复、如果、一直重复）：左边一个头（0.9 宽，写着次数 / 花），右边是里面的格子，四周留 0.12
//   积木之间 0.12；一栏排不下就换行（带壳的积木不拆开）

enum CodingLayout {
    static let gap = 0.12
    static let pad = 0.12
    static let header = 0.9

    struct Size: Equatable {
        var w: Double
        var h: Double
    }

    // MARK: 一块积木多大（单位 u）

    /// 一层格子：放着的积木加上剩下的空坑
    static func rowWidth(_ widths: [Double], capacity: Int) -> Double {
        let n = max(capacity, widths.count)
        let pits = Double(max(0, n - widths.count))
        let sum = widths.reduce(0, +) + pits
        return sum + Double(max(0, n - 1)) * gap
    }

    static func size(_ b: CodingBlock, track: Int, limits: CodingLimits) -> Size {
        guard let body = b.body else { return Size(w: 1, h: 1) }
        let kids = body.map { size($0, track: track, limits: limits) }
        let cap = limits.capacity(track: track, container: b)
        let inner = rowWidth(kids.map(\.w), capacity: cap)
        let h = (kids.map(\.h).max() ?? 1)
        return Size(w: pad + header + gap + inner + pad, h: max(1, h) + 2 * pad)
    }

    /// 某一层里一格最宽能有多宽（按套法的规矩，挑最宽的那种积木）
    static func worstCell(track: Int, shells: [CodingPiece], limits: CodingLimits) -> Size {
        var best = Size(w: 1, h: 1)
        let inLoop = shells.contains(.loop) || shells.contains(.forever)
        let inWhen = shells.contains { if case .when = $0 { return true }; return false }
        for p in limits.palette where p.isContainer {
            switch p {
            case .loop: if inLoop || inWhen { continue }
            case .when: if inWhen { continue }
            case .forever: if track != 0 || !shells.isEmpty { continue }
            default: break
            }
            let cap: Int
            switch p {
            case .when: cap = limits.when
            default: cap = limits.loop
            }
            let cell = worstCell(track: track, shells: shells + [p], limits: limits)
            let inner = Double(cap) * cell.w + Double(max(0, cap - 1)) * gap
            let s = Size(w: pad + header + gap + inner + pad, h: cell.h + 2 * pad)
            if s.w > best.w { best.w = s.w }
            if s.h > best.h { best.h = s.h }
        }
        return best
    }

    /// 一栏排成几行（贪心：放不下就换行）
    static func rows(_ widths: [Double], width: Double) -> Int {
        var rows = 1
        var x = 0.0
        for w in widths {
            if x > 0, x + gap + w > width + 1e-9 {
                rows += 1
                x = w
            } else {
                x += (x > 0 ? gap : 0) + w
            }
        }
        return rows
    }

    /// 按最坏的情况（每一格都放最宽的积木），一栏要多高（单位 u）；放不下（一块就比一行宽）是 nil
    static func worstTrackHeight(track: Int, limits: CodingLimits, width: Double) -> Double? {
        let cell = worstCell(track: track, shells: [], limits: limits)
        guard cell.w <= width + 1e-9 else { return nil }
        let cap = track == 0 ? limits.main : limits.proc
        let r = rows(Array(repeating: cell.w, count: cap), width: width)
        return Double(r) * cell.h + Double(r - 1) * gap
    }

    // MARK: 程序那一块地方

    /// 每一栏上面那一行字（"主程序"、"绝招 ★"）多高（点）
    static let labelHeight = 30.0
    /// 栏和栏之间（点）
    static let trackSpacing = 10.0
    /// 每一栏的卡片四周留多少（点）
    static let trackInset = 10.0
    static let maxUnit = 96.0

    /// 在 width × height 点的地方里，最坏的程序也放得下时，一块积木最大多少点
    static func unit(limits: CodingLimits, width: Double, height: Double) -> Double {
        let n = limits.trackCount
        func fits(_ u: Double) -> Bool {
            let inner = (width - 2 * trackInset) / u
            var total = Double(n - 1) * trackSpacing
            for t in 0..<n {
                guard let h = worstTrackHeight(track: t, limits: limits, width: inner) else { return false }
                total += labelHeight + 2 * trackInset + h * u
            }
            return total <= height
        }
        var lo = 8.0, hi = maxUnit
        if fits(hi) { return hi }
        for _ in 0..<40 {
            let mid = (lo + hi) / 2
            if fits(mid) { lo = mid } else { hi = mid }
        }
        return lo.rounded(.down)
    }

    // MARK: 积木盒

    struct Palette: Equatable {
        var side: Double
        var rows: Int
        var height: Double { Double(rows) * side + Double(rows - 1) * 10 }
    }

    static let maxPalette = 92.0

    /// 积木盒：一排放得下就一排，放不下就两排
    static func palette(count: Int, width: Double) -> Palette {
        let n = max(count, 1)
        let one = (width - Double(n - 1) * 10) / Double(n)
        if one >= 68 || n <= 4 { return Palette(side: min(maxPalette, one), rows: 1) }
        let per = (n + 1) / 2
        let two = (width - Double(per - 1) * 10) / Double(per)
        return Palette(side: min(maxPalette, two), rows: 2)
    }

    // MARK: 整个页面

    enum Screen { case play, lesson }

    struct Plan: Equatable {
        var wide: Bool
        /// 花园那一块（不含 1 / 2 / 3 的页签）
        var gardenWidth: Double
        var gardenHeight: Double
        /// 花园一格多大
        var cell: Double
        /// 程序那一块
        var programWidth: Double
        var programHeight: Double
        var unit: Double
        var palette: Palette
        var paletteWidth: Double
    }

    /// 页签（好几个花园时）、跑的按钮、猫头鹰那一条、顶上那一行有多高（点）
    static let tabsHeight = 60.0
    static let controlsHeight = 92.0
    static let lessonControlsHeight = 72.0
    static let owlHeight = 78.0
    static let headerHeight = 64.0
    static let spacing = 14.0

    /// 一关在 width × height 点的地方怎么分。play：整个闯关页面（已经去掉四周的留白）；lesson：教学里给棋盘的那一块。
    /// gardens：花园最大的列数、行数；multi：好几个花园（要页签）；paletteCount：积木盒里几种积木（教学里选程序的题是 0）
    /// minProgramHeight：程序那一块至少要多高（教学 choose 题要摞两三个选项）
    static func plan(screen: Screen, width: Double, height: Double, cols: Int, rows: Int, multi: Bool,
                     limits: CodingLimits, paletteCount: Int, minProgramHeight: Double = 0) -> Plan {
        let wide = screen == .play ? width > height : width > height * 1.25
        let tabs = multi ? tabsHeight + spacing : 0
        var best: Plan?
        // 先保证积木够大（手指点得准，至少 62 点）、花园格子不太小，再让两边都尽量大
        func score(_ p: Plan) -> Double {
            (p.unit >= 62 ? 1000 : 0) + (p.cell >= 50 ? 500 : 0) + (p.programHeight >= minProgramHeight ? 2000 : 0)
                + min(p.cell * 0.9, p.unit)
        }
        if wide {
            // 左边花园，右边程序
            let top = screen == .play ? headerHeight + spacing : 0
            let bodyH = height - top
            for k in stride(from: 0.32, through: 0.6, by: 0.01) {
                let gw = (width - 24) * k
                let pw = width - 24 - gw
                let owl = screen == .play ? owlHeight + spacing : 0
                let gh = bodyH - tabs - owl
                let cell = min(gw / Double(cols), gh / Double(rows))
                let pal = palette(count: paletteCount, width: pw)
                let ctl = screen == .play ? controlsHeight : lessonControlsHeight
                let ph = bodyH - ctl - spacing - (paletteCount > 0 ? pal.height + spacing : 0)
                let u = unit(limits: limits, width: pw, height: ph)
                let p = Plan(wide: true, gardenWidth: gw, gardenHeight: gh, cell: cell, programWidth: pw, programHeight: ph,
                             unit: u, palette: pal, paletteWidth: pw)
                if best == nil || score(p) > score(best!) { best = p }
            }
        } else {
            // 上面花园，下面程序
            let top = screen == .play ? headerHeight + spacing : 0
            let owl = screen == .play ? owlHeight + spacing : 0
            let pal = palette(count: paletteCount, width: width)
            let ctl = screen == .play ? controlsHeight : lessonControlsHeight
            let fixed = top + tabs + owl + ctl + spacing * 2 + (paletteCount > 0 ? pal.height + spacing : 0)
            let free = height - fixed
            for k in stride(from: 0.25, through: 0.62, by: 0.01) {
                let gh = free * k
                let ph = free - gh
                let cell = min(width / Double(cols), gh / Double(rows))
                let u = unit(limits: limits, width: width, height: ph)
                let p = Plan(wide: false, gardenWidth: width, gardenHeight: gh, cell: cell, programWidth: width, programHeight: ph,
                             unit: u, palette: pal, paletteWidth: width)
                if best == nil || score(p) > score(best!) { best = p }
            }
        }
        var p = best!
        p.cell = min(p.cell, 110)
        return p
    }

    /// 排成一行看的程序（教学 choose 题的选项）：没有空坑；绝招那一栏接在主程序后面，前面一个 0.8 宽的"★ ="
    static func inlineSize(_ b: CodingBlock) -> Size {
        guard let body = b.body else { return Size(w: 1, h: 1) }
        let kids = body.map(inlineSize)
        let inner = kids.map(\.w).reduce(0, +) + Double(max(0, kids.count - 1)) * gap
        return Size(w: pad + header + (kids.isEmpty ? 0 : gap + inner) + pad, h: (kids.map(\.h).max() ?? 1) + 2 * pad)
    }

    static func inlineSize(_ p: CodingProgram) -> Size {
        var w = 0.0, h = 1.0
        for (t, list) in p.tracks.enumerated() where t == 0 || !list.isEmpty {
            if t > 0 { w += 0.4 + 0.8 + gap }
            for (i, b) in list.enumerated() {
                let s = inlineSize(b)
                w += (i > 0 ? gap : 0) + s.w
                h = max(h, s.h)
            }
        }
        return Size(w: w, h: h)
    }

    /// 教学 choose 题：选项用 u 点大的积木摞起来，要多高
    static func optionsHeight(_ options: [CodingProgram], u: Double) -> Double {
        options.reduce(0) { $0 + inlineSize($1).h * u + 20 } + Double(max(0, options.count - 1)) * 12
    }

    /// 教学 choose 题：一个选项一张卡片（左边一个圆圈数字 56 点，四周 10），每个选项排成一行
    static func optionUnit(options: [CodingProgram], width: Double, height: Double, cap: Double) -> Double {
        let n = Double(max(1, options.count))
        let cardH = (height - (n - 1) * 12) / n
        var u = cap
        for p in options {
            let s = inlineSize(p)
            u = min(u, (width - 56 - 12 - 20) / max(1, s.w), (cardH - 20) / s.h)
        }
        return u.rounded(.down)
    }

    // MARK: 闯关页面的四周

    static let playPadH = 28.0
    static let playPadV = 20.0

    /// 几种 iPad 的可用大小（去掉状态栏和底部横条那一点）：11 寸 / 13 寸，横 / 竖
    static let devices: [(name: String, w: Double, h: Double)] = [
        ("11 寸横", 1210, 834 - 44), ("11 寸竖", 834, 1210 - 44),
        ("13 寸横", 1376, 1032 - 44), ("13 寸竖", 1032, 1376 - 44),
    ]

    /// 教学里给棋盘的那一块（LessonScaffold：横屏右边 min(420, 0.34 宽) 给老师，四周 28；竖屏上面是标题、老师，下面是按钮）
    static func lessonBoard(w: Double, h: Double) -> (w: Double, h: Double) {
        if w > h {
            return (w - 56 - 28 - min(420, w * 0.34), h - 56)
        }
        // 竖屏：标题 64 + 老师约 150 + 按钮约 90 + 间距 18 × 3
        return (w - 56, h - 56 - 64 - 150 - 90 - 54)
    }
}
