import SwiftUI

// 积木、程序、积木盒，全用 SwiftUI 画：圆角、厚一点、有一点立体感。
// 颜色按种类：箭头珊瑚色、重复蜂蜜色、绝招紫色、如果天蓝色、一直重复深一点的蜂蜜色。
// 大小全部按 u（一块积木的边长，CodingLayout 算好的）来，和 CodingLayout 里的尺寸一一对应。

enum CodingPaint {
    static func color(_ p: CodingPiece) -> Color {
        switch p {
        case .arrow: Color(hex: 0xE9705F)
        case .loop: Color(hex: 0xE0A23E)
        case .call(.star): Color(hex: 0x9A7BD8)
        case .call(.diamond): Color(hex: 0x7C68C8)
        case .when: Color(hex: 0x4E9FD8)
        case .forever: Color(hex: 0xCF8424)
        }
    }

    static func symbol(_ d: CodingDir) -> String {
        switch d {
        case .up: "arrow.up"
        case .down: "arrow.down"
        case .left: "arrow.left"
        case .right: "arrow.right"
        }
    }

    static func procSymbol(_ p: CodingProc) -> String { p == .star ? "star.fill" : "suit.diamond.fill" }

    static func flowerColor(_ f: CodingFlower) -> Color { f == .blue ? Color(hex: 0x3D7FD6) : Color(hex: 0xF2C230) }

    /// 积木盒上的字
    static func name(_ p: CodingPiece) -> String {
        switch p {
        case .arrow(.up): "上"
        case .arrow(.down): "下"
        case .arrow(.left): "左"
        case .arrow(.right): "右"
        case .loop: "重复"
        case .call(.star): "绝招"
        case .call(.diamond): "绝招"
        case .when(.blue): "蓝花"
        case .when(.yellow): "黄花"
        case .forever: "一直"
        }
    }

    static func trackName(_ t: Int) -> String { t == 0 ? "主程序" : t == 1 ? "绝招 ★" : "绝招 ◆" }
}

/// 一块积木的面（立体的圆角块）
struct CodingFace<Content: View>: View {
    let color: Color
    let size: CGSize
    var radius: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        let depth = max(2, min(size.width, size.height) * 0.07)
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(color)
                .brightness(-0.2)
                .offset(y: depth)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(color)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0)], startPoint: .top, endPoint: .center))
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: max(1, size.height * 0.03))
            content()
        }
        .frame(width: size.width, height: size.height - depth)
        .padding(.bottom, depth)
    }
}

/// 箭头 / 绝招 / 积木盒里的一块：1 × 1
struct CodingTile: View {
    let piece: CodingPiece
    let u: CGFloat
    var label = false

    var body: some View {
        CodingFace(color: CodingPaint.color(piece), size: CGSize(width: u, height: u), radius: u * 0.22) {
            VStack(spacing: u * 0.02) {
                glyph
                if label {
                    Text(CodingPaint.name(piece))
                        .font(.kid(max(17, u * 0.2), weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(.horizontal, u * 0.06)
        }
    }

    @ViewBuilder private var glyph: some View {
        let g = u * (label ? 0.38 : 0.52)
        switch piece {
        case let .arrow(d):
            Image(systemName: CodingPaint.symbol(d)).font(.system(size: g, weight: .black)).foregroundStyle(.white)
        case let .call(p):
            Image(systemName: CodingPaint.procSymbol(p)).font(.system(size: g, weight: .black)).foregroundStyle(.white)
        case .loop:
            Image(systemName: "repeat").font(.system(size: g * 0.9, weight: .black)).foregroundStyle(.white)
        case let .when(f):
            CodingFlowerDot(flower: f, size: g)
        case .forever:
            Image(systemName: "infinity").font(.system(size: g * 0.9, weight: .black)).foregroundStyle(.white)
        }
    }
}

/// 「如果」上画的那朵花（代码画：五个花瓣）
/// 带壳的积木左边那个头上画什么：重复 = 转圈的箭头 + 次数，如果 = 花 + "如果"，一直重复 = ∞。
/// 程序里、提示的影子里、选程序的题里都用这一个，免得同一种积木长得不一样。
struct CodingHeaderGlyph: View {
    let block: CodingBlock
    let u: CGFloat
    var unknown = false

    var body: some View {
        VStack(spacing: 0) {
            switch block {
            case let .loop(n, _):
                Image(systemName: "repeat").font(.system(size: u * 0.22, weight: .black)).foregroundStyle(.white.opacity(0.9))
                Text(unknown ? "?" : "\(n)").font(.kid(u * 0.44, weight: .black)).foregroundStyle(.white).monospacedDigit()
            case let .when(f, _):
                CodingFlowerDot(flower: f, size: u * 0.42)
                Text("如果").font(.kid(max(12, u * 0.18), weight: .heavy)).foregroundStyle(.white)
            default:
                Image(systemName: "infinity").font(.system(size: u * 0.4, weight: .black)).foregroundStyle(.white)
            }
        }
    }
}

struct CodingFlowerDot: View {
    let flower: CodingFlower
    let size: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(CodingPaint.flowerColor(flower))
                    .frame(width: size * 0.42, height: size * 0.42)
                    .offset(y: -size * 0.26)
                    .rotationEffect(.degrees(Double(i) * 72))
            }
            Circle().fill(Color.white).frame(width: size * 0.32, height: size * 0.32)
            Circle().fill(Color(hex: 0xF6D25C)).frame(width: size * 0.22, height: size * 0.22)
        }
        .frame(width: size, height: size)
        .padding(size * 0.06)
        .background(Circle().fill(Color.white.opacity(0.85)))
    }
}

// MARK: - 程序

/// 程序上的装饰：跑的时候哪一块发光、第几次；出错的那一块；提示的影子和圈
struct CodingDecor {
    var active: CodingRef?
    var stack: Set<CodingRef> = []
    var iterations: [CodingRef: Int] = [:]
    var culprit: CodingRef?
    var rings: Set<CodingRef> = []
    /// 影子：这个程序比她的多出来的那些块画成发光的影子
    var ghost: CodingProgram?
    /// 显示光标（排积木的时候）
    var cursor: CodingSlot?
    var shake: (track: Int, container: [Int], tick: Int)?
    /// 教学 count 题：这个重复的次数画成问号
    var unknownCount: CodingRef?
    /// 教学 count 题：这一块旁边画"× ?"（连着几个一样的箭头）
    var timesBadge: CodingRef?
}

/// 点程序的时候做什么
struct CodingProgramActions {
    /// 点一块放好的积木
    var block: (CodingRef) -> Void = { _ in }
    /// 点空位 / 两块中间
    var slot: (CodingSlot) -> Void = { _ in }
    /// 改重复的次数（nil = 这一次不能改）
    var count: ((CodingRef, Int) -> Void)?
    /// 能不能点（跑的时候不能改）
    var enabled = true
}

private struct CountTarget: Identifiable, Equatable {
    let ref: CodingRef
    var id: String { ref.description }
}

/// 整个程序：每一栏一张卡片，上面写着"主程序""绝招 ★"
struct CodingProgramView: View {
    let program: CodingProgram
    let limits: CodingLimits
    let u: CGFloat
    var decor = CodingDecor()
    var actions = CodingProgramActions()
    /// 只显示前几栏（教学里选程序的题只画主程序）
    var tracks: Int? = nil

    @State private var counting: CountTarget?

    private var gap: CGFloat { u * CGFloat(CodingLayout.gap) }
    private var pad: CGFloat { u * CGFloat(CodingLayout.pad) }
    private var header: CGFloat { u * CGFloat(CodingLayout.header) }

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat(CodingLayout.trackSpacing)) {
            ForEach(0..<(tracks ?? limits.trackCount), id: \.self) { t in
                trackCard(t)
            }
        }
    }

    private func trackCard(_ t: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(CodingPaint.trackName(t))
                    .font(.kid(19, weight: .heavy))
                    .foregroundStyle(t == 0 ? Palette.ink : CodingPaint.color(.call(t == 1 ? .star : .diamond)))
                Spacer(minLength: 0)
            }
            .frame(height: CGFloat(CodingLayout.labelHeight) - 4)
            list(program.tracks[t], ghost: decor.ghost?.tracks[t], track: t, container: [], capacity: t == 0 ? limits.main : limits.proc, top: true)
        }
        .padding(CGFloat(CodingLayout.trackInset))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.paper))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(t == 0 ? Palette.ink.opacity(0.08) : CodingPaint.color(.call(t == 1 ? .star : .diamond)).opacity(0.45), lineWidth: 2))
        .shadow(color: Color(hex: 0x6B4E2E).opacity(0.08), radius: 10, y: 5)
    }

    // MARK: 一层

    private func list(_ blocks: [CodingBlock], ghost: [CodingBlock]?, track: Int, container: [Int], capacity: Int, top: Bool) -> AnyView {
        let ghostExtra = ghost.map { Array($0.dropFirst(blocks.count)) } ?? []
        let pits = max(0, capacity - blocks.count - ghostExtra.count)
        let cursorHere = decor.cursor.flatMap { $0.track == track && $0.container == container ? $0.index : nil }
        let shaking = decor.shake.flatMap { $0.track == track && $0.container == container ? $0.tick : nil } ?? 0
        let items = Group {
            ForEach(Array(blocks.enumerated()), id: \.offset) { i, b in
                let ref = CodingRef(track: track, path: container + [i])
                let g: [CodingBlock]? = {
                    guard let gl = ghost, gl.indices.contains(i), gl[i].piece == b.piece else { return nil }
                    return gl[i].body
                }()
                blockView(b, ref: ref, ghostBody: g)
                    .overlay(alignment: .leading) { gapZone(CodingSlot(track: track, container: container, index: i), cursor: cursorHere == i) }
                    .overlay(alignment: .trailing) {
                        // 这一层满了，光标停在最后：画在最后一块的后面
                        if i == blocks.count - 1, pits == 0, ghostExtra.isEmpty, cursorHere == blocks.count {
                            cursorBar.offset(x: gap / 2 + max(5, u * 0.08) / 2)
                        }
                    }
            }
            ForEach(Array(ghostExtra.enumerated()), id: \.offset) { k, b in
                let slot = CodingSlot(track: track, container: container, index: blocks.count)
                ghostView(b, track: track)
                    .overlay(alignment: .leading) { if k == 0 && cursorHere == blocks.count { cursorBar } }
                    .onTapGesture { if actions.enabled { actions.slot(slot) } }
            }
            ForEach(0..<pits, id: \.self) { k in
                let slot = CodingSlot(track: track, container: container, index: blocks.count)
                pit(cursor: k == 0 && ghostExtra.isEmpty && cursorHere == blocks.count)
                    .onTapGesture { if actions.enabled { actions.slot(slot) } }
            }
        }
        let shake = CGFloat(0)
        if top {
            return AnyView(
                CodingFlow(spacing: gap) { items }
                    .keyframeAnimator(initialValue: shake, trigger: shaking) { v, x in v.offset(x: x) } keyframes: { _ in
                        SpringKeyframe(10, duration: 0.08); SpringKeyframe(-8, duration: 0.1); SpringKeyframe(0, duration: 0.2)
                    }
            )
        }
        return AnyView(
            HStack(alignment: .center, spacing: gap) { items }
                .keyframeAnimator(initialValue: shake, trigger: shaking) { v, x in v.offset(x: x) } keyframes: { _ in
                    SpringKeyframe(8, duration: 0.08); SpringKeyframe(-6, duration: 0.1); SpringKeyframe(0, duration: 0.2)
                }
        )
    }

    /// 两块中间的那条缝：点一下把光标挪过来；光标在这里就画一条闪着的竖线
    private func gapZone(_ slot: CodingSlot, cursor: Bool) -> some View {
        ZStack {
            Color.clear
            if cursor { cursorBar.offset(x: 0) }
        }
        .frame(width: u * 0.36)
        .contentShape(Rectangle())
        .offset(x: -u * 0.18 - gap / 2)
        .onTapGesture { if actions.enabled { actions.slot(slot) } }
    }

    private var cursorBar: some View {
        CodingBlink {
            Capsule().fill(Palette.coral).frame(width: max(5, u * 0.08), height: u * 0.9)
        }
    }

    private func pit(cursor: Bool) -> some View {
        RoundedRectangle(cornerRadius: u * 0.2, style: .continuous)
            .fill(Color(hex: 0xEFE6D6))
            .overlay(RoundedRectangle(cornerRadius: u * 0.2, style: .continuous)
                .strokeBorder(Color(hex: 0xC9B89C), style: StrokeStyle(lineWidth: 2, dash: [6, 5])))
            .overlay {
                if cursor {
                    CodingBlink {
                        RoundedRectangle(cornerRadius: u * 0.2, style: .continuous)
                            .strokeBorder(Palette.coral, lineWidth: max(4, u * 0.07))
                    }
                }
            }
            .frame(width: u, height: u)
            .contentShape(Rectangle())
    }

    // MARK: 一块

    private func state(_ ref: CodingRef) -> (glow: Bool, inside: Bool, bad: Bool, ring: Bool) {
        (decor.active == ref, decor.stack.contains(ref), decor.culprit == ref, decor.rings.contains(ref))
    }

    private func blockView(_ b: CodingBlock, ref: CodingRef, ghostBody: [CodingBlock]?) -> AnyView {
        let s = state(ref)
        let core: AnyView
        if let body = b.body {
            core = AnyView(containerView(b, body: body, ref: ref, ghostBody: ghostBody))
        } else {
            core = AnyView(
                CodingTile(piece: b.piece, u: u)
                    .contentShape(Rectangle())
                    .onTapGesture { if actions.enabled { actions.block(ref) } }
            )
        }
        return AnyView(
            core
                .scaleEffect(s.glow ? 1.08 : 1)
                .overlay {
                    if s.glow || s.inside || s.bad || s.ring {
                        RoundedRectangle(cornerRadius: u * 0.26, style: .continuous)
                            .strokeBorder(s.bad ? Palette.coral : s.ring ? Palette.coral : Color.white,
                                          lineWidth: s.glow || s.bad || s.ring ? max(4, u * 0.08) : max(3, u * 0.05))
                            .padding(-u * 0.05)
                            .shadow(color: s.bad || s.ring ? Palette.coral.opacity(0.7) : Color(hex: 0xFFE27A), radius: s.glow ? 10 : 5)
                            .allowsHitTesting(false)
                    }
                }
                // "第 2 次"骑在壳的右上角：左上角是这一栏的名字（"主程序"），不能压着它
                .overlay(alignment: .topTrailing) {
                    if let iter = decor.iterations[ref] {
                        Text("第 \(iter) 次")
                            .font(.kid(17, weight: .heavy))
                            .foregroundStyle(Palette.ink)
                            .fixedSize()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color(hex: 0xFFE27A)))
                            .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                            .offset(x: u * 0.14, y: -13)
                            .allowsHitTesting(false)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if decor.timesBadge == ref {
                        Text("× ?")
                            .font(.kid(max(17, u * 0.26), weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .background(Capsule().fill(Palette.ink))
                            .offset(x: u * 0.3, y: u * 0.12)
                            .allowsHitTesting(false)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if s.bad {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: u * 0.3, weight: .bold))
                            .foregroundStyle(.white, Palette.coral)
                            .offset(x: u * 0.12, y: -u * 0.12)
                            .allowsHitTesting(false)
                    }
                }
                .animation(.spring(duration: 0.2), value: s.glow)
        )
    }

    private func containerView(_ b: CodingBlock, body: [CodingBlock], ref: CodingRef, ghostBody: [CodingBlock]?) -> some View {
        let color = CodingPaint.color(b.piece)
        let cap = limits.capacity(track: ref.track, container: b)
        let iter = decor.iterations[ref]
        return HStack(alignment: .center, spacing: gap) {
            headerView(b, ref: ref, color: color, iteration: iter)
            list(body, ghost: ghostBody, track: ref.track, container: ref.path, capacity: cap, top: false)
        }
        .padding(pad)
        .background(RoundedRectangle(cornerRadius: u * 0.26, style: .continuous).fill(color.opacity(0.22)))
        .overlay(RoundedRectangle(cornerRadius: u * 0.26, style: .continuous).strokeBorder(color, lineWidth: max(3, u * 0.05)))
    }

    private func headerView(_ b: CodingBlock, ref: CodingRef, color: Color, iteration: Int?) -> some View {
        CodingFace(color: color, size: CGSize(width: header, height: u), radius: u * 0.2) {
            CodingHeaderGlyph(block: b, u: u, unknown: decor.unknownCount == ref)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard actions.enabled else { return }
            if case .loop = b, actions.count != nil {
                Sound.tap()
                counting = CountTarget(ref: ref)
            } else {
                actions.block(ref)
            }
        }
        .popover(item: Binding(get: { counting?.ref == ref ? counting : nil }, set: { counting = $0 })) { target in
            countPopover(target.ref)
                .presentationCompactAdaptation(.popover)
        }
    }

    private func countPopover(_ ref: CodingRef) -> some View {
        let n: Int = { if case let .loop(k, _)? = program.block(at: ref) { return k }; return 2 }()
        return VStack(spacing: 16) {
            Text("重复几次？").font(.kid(22, weight: .heavy)).foregroundStyle(Palette.ink)
            HStack(spacing: 18) {
                stepButton("minus", enabled: n > 2) { actions.count?(ref, n - 1) }
                Text("\(n)")
                    .font(.kid(48, weight: .black))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .frame(width: 70)
                    .contentTransition(.numericText())
                stepButton("plus", enabled: n < 9) { actions.count?(ref, n + 1) }
            }
            Button {
                counting = nil
                actions.block(ref)
            } label: {
                Label("拿掉这一块", systemImage: "trash")
                    .font(.kid(19, weight: .bold))
                    .foregroundStyle(Palette.coral)
                    .frame(minHeight: 56)
                    .padding(.horizontal, 16)
            }
            .buttonStyle(PressableStyle())
        }
        .padding(22)
    }

    private func stepButton(_ icon: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 68, height: 68)
                .background(Circle().fill(enabled ? CodingPaint.color(.loop) : Palette.inkSoft.opacity(0.3)))
        }
        .buttonStyle(PressableStyle(scale: 0.9))
        .disabled(!enabled)
    }

    // MARK: 影子

    private func ghostView(_ b: CodingBlock, track: Int) -> AnyView {
        let v: AnyView
        if let body = b.body {
            let cap = limits.capacity(track: track, container: b)
            let color = CodingPaint.color(b.piece)
            v = AnyView(
                HStack(spacing: gap) {
                    CodingFace(color: color, size: CGSize(width: header, height: u), radius: u * 0.2) {
                        CodingHeaderGlyph(block: b, u: u)
                    }
                    ForEach(Array(body.enumerated()), id: \.offset) { _, x in ghostView(x, track: track) }
                    ForEach(0..<max(0, cap - body.count), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: u * 0.2).fill(Color.white.opacity(0.4)).frame(width: u, height: u)
                    }
                }
                .padding(pad)
                .background(RoundedRectangle(cornerRadius: u * 0.26, style: .continuous).fill(color.opacity(0.2)))
            )
        } else {
            v = AnyView(CodingTile(piece: b.piece, u: u))
        }
        return AnyView(
            v.opacity(0.45)
                .overlay(RoundedRectangle(cornerRadius: u * 0.24, style: .continuous)
                    .strokeBorder(Color(hex: 0xFFC83D), style: StrokeStyle(lineWidth: max(3, u * 0.06), dash: [u * 0.12, u * 0.08])))
                .shadow(color: Color(hex: 0xFFD75A).opacity(0.8), radius: 8)
                .contentShape(Rectangle())
        )
    }
}

/// 闪一闪（光标）
struct CodingBlink<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @State private var on = false

    var body: some View {
        content()
            .opacity(on ? 1 : 0.25)
            .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
            .allowsHitTesting(false)
    }
}

/// 一行放不下就换行（带壳的积木不拆开）
struct CodingFlow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = arrange(subviews, width: width)
        let h = rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * spacing
        let w = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? w, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for i in row.items {
                let s = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y + (row.height - s.height) / 2), proposal: ProposedViewSize(s))
                x += s.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var items: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for i in subviews.indices {
            let s = subviews[i].sizeThatFits(.unspecified)
            if !rows[rows.count - 1].items.isEmpty, rows[rows.count - 1].width + spacing + s.width > width + 0.5 {
                rows.append(Row())
            }
            var r = rows[rows.count - 1]
            r.width += (r.items.isEmpty ? 0 : spacing) + s.width
            r.height = max(r.height, s.height)
            r.items.append(i)
            rows[rows.count - 1] = r
        }
        return rows
    }
}

// MARK: - 积木盒

struct CodingPaletteView: View {
    let limits: CodingLimits
    let side: CGFloat
    let rows: Int
    /// 这一块现在能不能放（不能的画灰）
    var available: (CodingPiece) -> Bool = { _ in true }
    var enabled = true
    let onTap: (CodingPiece) -> Void

    var body: some View {
        let pieces = limits.palette
        let per = rows > 1 ? (pieces.count + 1) / 2 : pieces.count
        VStack(spacing: 10) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 10) {
                    ForEach(Array(pieces.dropFirst(r * per).prefix(per)), id: \.self) { p in
                        Button {
                            onTap(p)
                        } label: {
                            CodingTile(piece: p, u: side, label: true)
                                .saturation(available(p) && enabled ? 1 : 0)
                                .opacity(available(p) && enabled ? 1 : 0.45)
                        }
                        .buttonStyle(PressableStyle(scale: 0.9))
                        .disabled(!enabled)
                        .accessibilityLabel(CodingPaint.name(p))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// 下面那一排大按钮（开始、一步、快、提示、清空）
struct CodingToolButton: View {
    let systemName: String
    let label: String
    var height: CGFloat = 92
    var tint: Color = Palette.paper
    var foreground: Color = Palette.ink
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: height > 80 ? 6 : 2) {
                Image(systemName: systemName)
                    .font(.system(size: height > 80 ? 28 : 22, weight: .bold))
                Text(label)
                    .font(.kid(height > 80 ? 19 : 17, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(tint))
            .shadow(color: Color(hex: 0x6B4E2E).opacity(0.12), radius: 10, y: 5)
        }
        .buttonStyle(PressableStyle(scale: 0.93))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .animation(.easeInOut(duration: 0.2), value: enabled)
    }
}
