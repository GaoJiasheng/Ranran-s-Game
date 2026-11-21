import SwiftUI

/// 解谜类游戏（数独、七巧板、华容道……）共用的首页：上面选一组关卡，左边是这一组的介绍和「继续闯关」，
/// 右边是这一组的全部关卡（一屏放下，不滚动）；右上角进「教学」。
/// 每个游戏只要给出关卡分组、每一关的小图、点开一关时做什么，其余（解锁、星星、新手提示）都在这里。
///
///     PuzzleSetupView(game: "sudoku", title: "数独", subtitle: "每行每列都不重复", accent: tint,
///                     packs: SudokuCatalog.packs, learnFirst: "先跟猫头鹰老师学会怎么填",
///                     thumbnail: { SudokuThumb(level: $0) }, open: { playing = $0 })
///         .navigationDestination(item: $playing) { ... }
struct PuzzleSetupView<Thumb: View>: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PuzzleRules.unlockAllKey) private var unlockAll = false

    /// 游戏的名字（存档前缀、Tutorials/<game>.json）
    let game: String
    let title: String
    let subtitle: String
    let accent: Color
    let packs: [PuzzlePack]
    /// 新手横幅上的第二行，比如"先跟猫头鹰老师学会怎么填"
    let learnFirst: String
    /// 一关的小图，画在正方形里
    @ViewBuilder let thumbnail: (_ level: String) -> Thumb
    /// 点开一关
    let open: (_ level: String) -> Void

    @State private var packIndex = 0
    @State private var showTutorial = false
    @State private var appeared = false

    private var course: TutorialCourse? {
        TutorialCourse.bundled[game].flatMap { $0.lessons.isEmpty ? nil : $0 }
    }

    private var pack: PuzzlePack? { packs.indices.contains(packIndex) ? packs[packIndex] : nil }

    /// 课没学过、关也没过：先建议去学
    private var newcomer: Bool {
        guard let course else { return false }
        return store.lessonsDone(course) == 0 && packs.allSatisfy { store.puzzlesCleared(game, $0.levels) == 0 }
    }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            ZStack {
                CreamBackground(accent: accent)
                VStack(spacing: wide ? 18 : 22) {
                    header
                    if newcomer { learnBanner }
                    panel(wide: wide)
                        .frame(maxHeight: .infinity)
                        .offset(y: appeared ? 0 : 50)
                        .opacity(appeared ? 1 : 0)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 24)
                .frame(maxWidth: 1240, maxHeight: .infinity)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            if !appeared { packIndex = startPack }
            withAnimation(.spring(duration: 0.6, bounce: 0.3)) { appeared = true }
            #if DEBUG
            // 调试截图用：-tutorial YES 进教学，-pack 2 选第二组，-puzzle <关卡 id> 直接打开一关
            let d = UserDefaults.standard
            if d.bool(forKey: "tutorial") { showTutorial = true }
            if d.integer(forKey: "pack") > 0 { packIndex = min(d.integer(forKey: "pack"), packs.count) - 1 }
            if let l = d.string(forKey: "puzzle"), packs.contains(where: { $0.levels.contains(l) }) { open(l) }
            #endif
        }
        .navigationDestination(isPresented: $showTutorial) {
            TutorialHomeView(game: game, accent: accent, onPlay: { n in
                packIndex = min(max(n, 1), max(packs.count, 1)) - 1
                showTutorial = false
            })
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    /// 一进来停在哪一组：接着要玩的那一关所在的组
    private var startPack: Int {
        guard let next = store.nextPuzzle(game, packs, unlockAll: unlockAll) else { return max(packs.count - 1, 0) }
        return packs.firstIndex { $0.levels.contains(next) } ?? 0
    }

    // MARK: 顶上

    private var header: some View {
        ZStack {
            VStack(spacing: 6) {
                Text(title)
                    .font(.kid(54, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text(subtitle)
                    .font(.kid(20, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 230)
            HStack(spacing: 14) {
                RoundIconButton(systemName: "house.fill", label: "回主页") { dismiss() }
                Spacer()
                if course != nil { TutorialButton { showTutorial = true } }
                StarCounter(value: store.stars(prefix: "\(game).stars."))
            }
        }
    }

    private var learnBanner: some View {
        Button {
            Sound.tap()
            showTutorial = true
        } label: {
            HStack(spacing: 16) {
                ArtImage(name: course?.tracks.first?.art ?? "", fallback: "🦉", contentMode: .fit)
                    .frame(width: 70, height: 70)
                VStack(alignment: .leading, spacing: 2) {
                    Text("第一次玩\(title)？")
                        .font(.kid(22, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                    Text(learnFirst)
                        .font(.kid(17, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                Label("去学习", systemImage: "graduationcap.fill")
                    .font(.kid(20, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Palette.coral, in: Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Palette.honey.opacity(0.22), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }

    // MARK: 中间的大卡片

    private func panel(wide: Bool) -> some View {
        VStack(spacing: wide ? 18 : 22) {
            packTabs
            if let pack {
                let open = store.packUnlocked(game, packs, packIndex, unlockAll: unlockAll)
                if wide {
                    HStack(alignment: .center, spacing: 36) {
                        showcase(pack, open: open, row: false).frame(width: 300)
                        grid(pack, open: open)
                    }
                } else {
                    VStack(spacing: 22) {
                        showcase(pack, open: open, row: true)
                        grid(pack, open: open)
                    }
                }
            }
        }
        .padding(wide ? 30 : 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [accent.opacity(0.16), Palette.paper.opacity(0)],
                           startPoint: .topLeading, endPoint: .center),
            in: RoundedRectangle(cornerRadius: 44, style: .continuous)
        )
        .softCard(radius: 44)
    }

    /// 选哪一组
    private var packTabs: some View {
        HStack(spacing: 10) {
            ForEach(Array(packs.enumerated()), id: \.element.id) { i, p in
                let selected = i == packIndex
                let open = store.packUnlocked(game, packs, i, unlockAll: unlockAll)
                Button {
                    guard !selected else { return }
                    Sound.step(i + 1)
                    withAnimation(.spring(duration: 0.35, bounce: 0.25)) { packIndex = i }
                } label: {
                    HStack(spacing: 8) {
                        if !open {
                            Image(systemName: "lock.fill").font(.system(size: 14, weight: .bold))
                        }
                        Text(p.name)
                            .font(.kid(20, weight: .heavy))
                        if open {
                            Text("\(store.puzzlesCleared(game, p.levels))/\(p.levels.count)")
                                .font(.kid(15, weight: .bold))
                                .monospacedDigit()
                                .opacity(0.75)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(selected ? .white : open ? Palette.ink : Palette.inkSoft.opacity(0.7))
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(selected ? AnyShapeStyle(accent) : AnyShapeStyle(Palette.cream), in: Capsule())
                }
                .buttonStyle(PressableStyle(scale: 0.96))
                .accessibilityLabel(open ? p.name : "\(p.name)，还没解锁")
            }
        }
        .frame(maxWidth: 900)
    }

    /// 这一组的介绍：小图、名字、过了几关、「继续闯关」
    private func showcase(_ pack: PuzzlePack, open: Bool, row: Bool) -> some View {
        let cleared = store.puzzlesCleared(game, pack.levels)
        let stars = pack.levels.reduce(0) { $0 + store.puzzleBest(game, $1) }
        let next = pack.levels.first { !store.puzzleCleared(game, $0) }
        let art = ArtImage(name: pack.art, fallback: "🧩", contentMode: .fit)
            .padding(18)
            .background(Circle().fill(RadialGradient(colors: [accent.opacity(0.10), accent.opacity(0.30)],
                                                     center: .center, startRadius: 10, endRadius: 110)))
            .overlay(Circle().strokeBorder(.white, lineWidth: 5))
            .saturation(open ? 1 : 0.2)
            .opacity(open ? 1 : 0.7)
            .id(pack.id)
            .transition(.scale(scale: 0.7).combined(with: .opacity))
        let text = VStack(spacing: 10) {
            Text(pack.name)
                .font(.kid(32, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(pack.subtitle)
                .font(.kid(18, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(height: 48)
            HStack(spacing: 6) {
                Image(systemName: "star.fill").foregroundStyle(Palette.honey)
                Text("\(stars)").foregroundStyle(Palette.ink).monospacedDigit()
                Text("· 过了 \(cleared) / \(pack.levels.count) 关")
            }
            .font(.kid(17, weight: .bold))
            .foregroundStyle(Palette.inkSoft)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(height: 26)
            Group {
                if !open {
                    let need = store.puzzlesNeeded(game, packs, toOpen: packIndex, unlockAll: unlockAll)
                    Label("「\(packs[max(packIndex - 1, 0)].name)」再过 \(need) 关就打开", systemImage: "lock.fill")
                        .font(.kid(18, weight: .bold))
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                } else if let next {
                    Button {
                        Sound.start()
                        self.open(next)
                    } label: {
                        Label(cleared == 0 ? "开始闯关" : "继续闯关", systemImage: "play.fill")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(PillButtonStyle(color: Palette.coral, size: 26))
                } else {
                    Label("这一组全部通过啦", systemImage: "checkmark.seal.fill")
                        .font(.kid(20, weight: .heavy))
                        .foregroundStyle(accent)
                }
            }
            .frame(height: 70)
        }
        return Group {
            if row {
                HStack(spacing: 28) {
                    art.frame(width: 170, height: 170)
                    text.frame(maxWidth: 360)
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 14) {
                    art.frame(minWidth: 90, maxWidth: 200, minHeight: 90, maxHeight: 200)
                        .aspectRatio(1, contentMode: .fit)
                    text
                }
            }
        }
    }

    /// 这一组的全部关卡，格子大小跟着地方走
    private func grid(_ pack: PuzzlePack, open: Bool) -> some View {
        GeometryReader { g in
            let layout = PuzzleGridLayout(count: pack.levels.count, size: g.size)
            let next = pack.levels.first { !store.puzzleCleared(game, $0) }
            VStack(spacing: layout.spacing) {
                ForEach(0..<layout.rows, id: \.self) { r in
                    HStack(spacing: layout.spacing) {
                        ForEach(0..<layout.columns, id: \.self) { c in
                            let i = r * layout.columns + c
                            if i < pack.levels.count {
                                cell(pack.levels[i], number: i + 1, side: layout.side,
                                     isNext: open && pack.levels[i] == next)
                            } else {
                                Color.clear.frame(width: layout.side, height: layout.side + PuzzleGridLayout.footer)
                            }
                        }
                    }
                }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .frame(minHeight: 220)
        .id(pack.id)
        .transition(.opacity)
    }

    private func cell(_ level: String, number: Int, side: CGFloat, isNext: Bool) -> some View {
        let best = store.puzzleBest(game, level)
        let unlocked = store.puzzleUnlocked(game, packs, level, unlockAll: unlockAll)
        let radius = min(24, side * 0.2)
        let pad = max(6, side * 0.08)
        return Button {
            if unlocked {
                Sound.tap()
                open(level)
            } else {
                Sound.nope()
            }
        } label: {
            VStack(spacing: 0) {
                ZStack {
                    thumbnail(level)
                        .frame(width: side - pad * 2, height: side - pad * 2)
                        .opacity(unlocked ? 1 : 0.22)
                        .saturation(unlocked ? 1 : 0)
                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: side * 0.24, weight: .bold))
                            .foregroundStyle(Palette.inkSoft.opacity(0.55))
                    }
                }
                .frame(width: side, height: side)
                HStack(spacing: 6) {
                    Text("\(number)")
                        .font(.system(size: min(19, side * 0.2), weight: .heavy, design: .rounded))
                        .foregroundStyle(unlocked ? Palette.ink : Palette.inkSoft.opacity(0.6))
                        .monospacedDigit()
                    HStack(spacing: 1) {
                        ForEach(1...3, id: \.self) { n in
                            Image(systemName: "star.fill")
                                .font(.system(size: min(14, side * 0.15), weight: .bold))
                                .foregroundStyle(n <= best ? Palette.honey : Palette.ink.opacity(0.12))
                        }
                    }
                }
                .frame(height: PuzzleGridLayout.footer - 6)
                .padding(.bottom, 6)
            }
            .frame(width: side, height: side + PuzzleGridLayout.footer)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(unlocked ? Palette.paper : Palette.cream.opacity(0.8)))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(isNext ? accent : Palette.ink.opacity(0.07), lineWidth: isNext ? 4 : 1.5))
            .shadow(color: isNext ? accent.opacity(0.35) : Color(hex: 0x6B4E2E).opacity(unlocked ? 0.08 : 0),
                    radius: isNext ? 10 : 6, y: 3)
            .overlay(alignment: .topTrailing) {
                if isNext {
                    Text("下一关")
                        .font(.kid(max(11, min(14, side * 0.13)), weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Palette.coral, in: Capsule())
                        .offset(x: 6, y: -8)
                }
            }
        }
        .buttonStyle(PressableStyle(scale: 0.94))
        .accessibilityLabel("第 \(number) 关" + (unlocked ? (best > 0 ? "，\(best) 颗星" : "") : "，还没解锁"))
    }
}

/// 关卡格子怎么排：在给定的地方里，挑一个让格子最大的列数。每格 = 正方形小图 + 底下一行（第几关、三颗星）。
struct PuzzleGridLayout {
    static let footer: CGFloat = 32

    let columns: Int
    let rows: Int
    let side: CGFloat
    let spacing: CGFloat

    init(count: Int, size: CGSize) {
        let n = max(count, 1)
        var best = (columns: 1, rows: n, side: CGFloat(0), spacing: CGFloat(12))
        for c in 1...max(1, min(n, 10)) {
            let r = Int((Double(n) / Double(c)).rounded(.up))
            let s: CGFloat = size.width / CGFloat(c) < 110 ? 10 : 14
            let w = (size.width - s * CGFloat(c - 1)) / CGFloat(c)
            let h = (size.height - s * CGFloat(r - 1)) / CGFloat(r) - Self.footer
            let side = min(w, h, 190)
            if side > best.side + 0.5 { best = (c, r, side, s) }
        }
        columns = best.columns
        rows = best.rows
        side = max(best.side, 40)
        spacing = best.spacing
    }
}
