import SwiftUI

// MARK: - 到下一枚奖章的进度

/// "再拿 N 颗星星" + 一条细细的进度条。
struct NextMedalProgress: View {
    let stars: Int
    var textSize: CGFloat = 24
    var showName = true

    var body: some View {
        if let next = Medal.next(stars: stars) {
            let from = Medal.previousThreshold(before: next)
            let span = max(next.threshold - from, 1)
            let fraction = min(max(Double(stars - from) / Double(span), 0), 1)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("再拿 \(next.threshold - stars) 颗星星")
                        .font(.kid(textSize, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                    if showName {
                        Text("解锁「\(next.name)」")
                            .font(.kid(textSize * 0.72, weight: .semibold))
                            .foregroundStyle(Palette.inkSoft)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.cream)
                        Capsule()
                            .fill(LinearGradient(colors: [Palette.honey, Palette.coral], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(g.size.height, g.size.width * fraction))
                    }
                }
                .frame(height: 10)
                .animation(.spring(duration: 0.6), value: fraction)
            }
        } else {
            Text("所有奖章都拿到啦！")
                .font(.kid(textSize, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

// MARK: - 奖章墙

/// 全屏的奖章墙：12 枚奖章固定排成格子，不滚动。横屏 4×3，竖屏 3×4。
struct MedalWallView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// 点一枚拿到的奖章，再看一遍它的庆祝
    @State private var replay: Medal?

    var body: some View {
        let stars = store.medalStars
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            let cols = wide ? 4 : 3
            let rows = Medal.all.count / cols
            ZStack {
                CreamBackground(accent: Palette.honey)
                VStack(spacing: 20) {
                    ZStack {
                        Text("我的奖章")
                            .font(.kid(40, weight: .heavy))
                            .foregroundStyle(Palette.ink)
                        HStack {
                            Spacer()
                            RoundIconButton(systemName: "xmark", label: "关闭") { dismiss() }
                        }
                    }

                    progressCard(stars: stars)

                    VStack(spacing: 0) {
                        ForEach(0..<rows, id: \.self) { r in
                            HStack(spacing: 0) {
                                ForEach(0..<cols, id: \.self) { c in
                                    cell(Medal.all[r * cols + c], stars: stars)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .softCard(radius: 40)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 28)
                .frame(maxWidth: 1300)
                .frame(maxWidth: .infinity)

                if let m = replay {
                    MedalCelebration(medal: m, stars: stars, replay: true) {
                        withAnimation(.easeOut(duration: 0.25)) { replay = nil }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
    }

    private func progressCard(stars: Int) -> some View {
        let earned = Medal.earned(stars: stars).count
        let shown = Medal.next(stars: stars) ?? Medal.all.last!
        return HStack(spacing: 20) {
            MedalBadge(medal: shown, unlocked: Medal.next(stars: stars) == nil, size: 84)
                .frame(width: 84, height: 84)
            NextMedalProgress(stars: stars, textSize: 26)
            Text("\(earned) / \(Medal.all.count)")
                .font(.kid(30, weight: .heavy))
                .foregroundStyle(Palette.inkSoft)
                .monospacedDigit()
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .softCard(radius: 36)
    }

    private func cell(_ medal: Medal, stars: Int) -> some View {
        let unlocked = stars >= medal.threshold
        return GeometryReader { g in
            let badge = max(56, min(180, g.size.width * 0.82, g.size.height - 62))
            Button {
                guard unlocked else { Sound.nope(); return }
                Sound.pop()
                withAnimation(.spring(duration: 0.4, bounce: 0.3)) { replay = medal }
            } label: {
                VStack(spacing: 4) {
                    MedalBadge(medal: medal, unlocked: unlocked, size: badge)
                    Text(medal.name)
                        .font(.kid(22, weight: .heavy))
                        .foregroundStyle(unlocked ? Palette.ink : Palette.inkSoft.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill").font(.system(size: 13, weight: .bold))
                        Text("\(medal.threshold)").font(.kid(16, weight: .bold)).monospacedDigit()
                    }
                    .foregroundStyle(unlocked ? Palette.honey : Palette.inkSoft.opacity(0.6))
                }
                .frame(width: g.size.width, height: g.size.height)
            }
            .buttonStyle(PressableStyle(scale: 0.94))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 「我的」里的入口

/// 「我的」里的一行：最近拿到的奖章 + 到下一枚的进度，点开是奖章墙。
struct MedalSummaryCard: View {
    @Environment(PlayerStore.self) private var store
    @State private var showWall = false

    var body: some View {
        let stars = store.medalStars
        let latest = Medal.latest(stars: stars)
        Button {
            Sound.tap()
            showWall = true
        } label: {
            HStack(spacing: 18) {
                MedalBadge(medal: latest ?? Medal.all[0], unlocked: latest != nil, size: 92)
                    .frame(width: 92, height: 92)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("我的奖章")
                            .font(.kid(26, weight: .heavy))
                            .foregroundStyle(Palette.ink)
                        Text("\(Medal.earned(stars: stars).count) / \(Medal.all.count)")
                            .font(.kid(18, weight: .bold))
                            .foregroundStyle(Palette.inkSoft)
                            .monospacedDigit()
                    }
                    NextMedalProgress(stars: stars, textSize: 19, showName: false)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Palette.inkSoft)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .softCard(radius: 40)
        }
        .buttonStyle(PressableStyle(scale: 0.97))
        .accessibilityLabel("我的奖章")
        .fullScreenCover(isPresented: $showWall) { MedalWallView() }
    }
}

// MARK: - 主页上的小提示

/// 星星数下面一枚小奖章 + "还差 N 颗"，点一下打开奖章墙。
struct MedalHint: View {
    @Environment(PlayerStore.self) private var store
    let action: () -> Void

    var body: some View {
        let stars = store.medalStars
        let next = Medal.next(stars: stars)
        let shown = next ?? Medal.all.last!
        Button {
            Sound.tap()
            action()
        } label: {
            HStack(spacing: 6) {
                MedalBadge(medal: shown, unlocked: next == nil, size: 28)
                    .frame(width: 28, height: 28)
                Text(next.map { "还差 \($0.threshold - stars) 颗" } ?? "奖章全齐")
                    .font(.kid(16, weight: .bold))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
                    .monospacedDigit()
            }
            .padding(.leading, 8)
            .padding(.trailing, 14)
            .frame(height: 30)
            .background(Palette.paper.opacity(0.75), in: Capsule())
        }
        .buttonStyle(PressableStyle(scale: 0.94))
        .accessibilityLabel(next.map { "还差\($0.threshold - stars)颗星星拿到奖章，打开奖章墙" } ?? "奖章全部拿到了，打开奖章墙")
    }
}

// MARK: - 解锁庆祝

/// 居中的庆祝：奖章弹出来、撒花、名字、一个按钮。
struct MedalCelebration: View {
    let medal: Medal
    let stars: Int
    var replay = false
    let onDone: () -> Void
    @State private var appeared = false

    var body: some View {
        GeometryReader { g in
            let badge = min(280, max(180, min(g.size.width, g.size.height) * 0.36))
            ZStack {
                Color.black.opacity(0.42).ignoresSafeArea()
                    .onTapGesture {}
                ConfettiView()
                VStack(spacing: 14) {
                    Text(replay ? "我的奖章" : "新奖章！")
                        .font(.kid(26, weight: .heavy))
                        .foregroundStyle(Palette.coral)
                    ZStack {
                        Circle()
                            .fill(RadialGradient(colors: [Color(hex: medal.base).opacity(0.5), .clear],
                                                 center: .center, startRadius: 0, endRadius: badge * 0.75))
                            .frame(width: badge * 1.5, height: badge * 1.5)
                            .scaleEffect(appeared ? 1 : 0.3)
                            .opacity(appeared ? 1 : 0)
                        MedalBadge(medal: medal, size: badge)
                            .scaleEffect(appeared ? 1 : 0.15)
                            .rotationEffect(.degrees(appeared ? 0 : -25))
                    }
                    .frame(width: badge * 1.2, height: badge * 1.1)
                    Text(medal.name)
                        .font(.kid(52, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(LinearGradient(colors: [Palette.honey, Palette.coral], startPoint: .top, endPoint: .bottom))
                        Text("满 \(medal.threshold) 颗星星")
                            .foregroundStyle(Palette.inkSoft)
                    }
                    .font(.kid(22, weight: .bold))
                    Button(replay ? "好的" : "太棒了！") {
                        Sound.tap()
                        onDone()
                    }
                    .buttonStyle(PillButtonStyle(color: Palette.coral, size: 26))
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 34)
                .frame(width: min(560, g.size.width - 64))
                .softCard(radius: 48)
                .scaleEffect(appeared ? 1 : 0.9)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            Sound.fanfare()
            withAnimation(.spring(duration: 0.8, bounce: 0.4)) { appeared = true }
        }
    }
}

// MARK: - 主页上的奖章层

/// 挂在主页上：回到主页时，如果有还没庆祝的奖章，就庆祝（只庆祝最高的一枚，并记下来，不会重复）。
/// 游戏进行中不会弹，因为那时主页不在最上面。
struct MedalHomeLayer: ViewModifier {
    let atHome: Bool
    @Binding var showWall: Bool
    @Environment(PlayerStore.self) private var store
    @State private var celebrating: Medal?

    private struct Trigger: Hashable { var atHome: Bool; var stars: Int; var celebrated: Int; var wall: Bool }

    func body(content: Content) -> some View {
        content
            .overlay {
                if let m = celebrating {
                    MedalCelebration(medal: m, stars: store.medalStars) {
                        withAnimation(.easeOut(duration: 0.25)) { celebrating = nil }
                    }
                    .transition(.opacity)
                }
            }
            .fullScreenCover(isPresented: $showWall) { MedalWallView() }
            .task(id: Trigger(atHome: atHome, stars: store.medalStars, celebrated: store.medalsCelebrated, wall: showWall)) {
                guard atHome, celebrating == nil, !showWall, let m = store.pendingMedal else { return }
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled, atHome, celebrating == nil, let m2 = store.pendingMedal, m2 == m else { return }
                store.markMedalsCelebrated(through: m)
                withAnimation(.spring(duration: 0.4)) { celebrating = m }
            }
            #if DEBUG
            .onAppear {
                // 调试用：-medals YES 直接打开奖章墙；-medalUnlock N 预览第 N 枚的庆祝（不记录）；-medalStars N 假装有 N 颗星星
                let d = UserDefaults.standard
                if d.bool(forKey: "medals") { showWall = true }
                let n = d.integer(forKey: "medalUnlock")
                if (1...Medal.all.count).contains(n) { celebrating = Medal.all[n - 1] }
            }
            #endif
    }
}

extension View {
    func medalLayer(atHome: Bool, showWall: Binding<Bool>) -> some View {
        modifier(MedalHomeLayer(atHome: atHome, showWall: showWall))
    }
}

#Preview("奖章墙") {
    MedalWallView().environment(PlayerStore())
}

#Preview("庆祝") {
    MedalCelebration(medal: Medal.all[5], stars: 120) {}
}

#Preview("「我的」入口") {
    MedalSummaryCard().environment(PlayerStore()).padding().frame(width: 460).background(Palette.cream)
}
