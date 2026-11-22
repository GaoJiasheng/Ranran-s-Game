import SwiftUI

// 「主页上的游戏」：家长挑哪些游戏摆在主页上。
// 游戏越加越多，学会了的、暂时不玩的可以先收起来；收起来只是不摆出来，星星、奖章、进度都不动。
// 规矩（至少留一个、怎么分排）在 Views/Home/HomeShelf.swift。

/// 「我的」里的入口卡。和「约好的奖励」一样，长按才打开。
struct HomeGamesEntryCard: View {
    @Environment(PlayerStore.self) private var store
    @State private var showing = false

    var body: some View {
        let total = GameEntry.allCases.count
        let shown = store.homeGames.count
        VStack(alignment: .leading, spacing: 14) {
            Text("主页上的游戏")
                .font(.kid(28, weight: .heavy))
                .foregroundStyle(Palette.ink)
            Text("学会了的、暂时不玩的游戏，可以先从主页收起来。星星和奖章都还在，随时能放回去")
                .font(.kid(17, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 14) {
                Text(shown == total ? "\(total) 个都摆着" : "摆着 \(shown) 个，收起 \(total - shown) 个")
                    .font(.kid(18, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                ParentHoldButton(title: "选择游戏", systemImage: "square.grid.2x2.fill") { showing = true }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard(radius: 40)
        .fullScreenCover(isPresented: $showing) { HomeGamesEditor().statusBarHidden() }
        .onAppear {
            #if DEBUG
            // 调试截图用：启动参数 -homeGames YES 直接打开这一页
            if UserDefaults.standard.string(forKey: "homeGames") == "YES" { showing = true }
            #endif
        }
    }
}

/// 挑游戏的页面：每个游戏一行，一个开关。
struct HomeGamesEditor: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            let total = GameEntry.allCases.count
            let shown = store.homeGames.count
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("主页上的游戏")
                            .font(.kid(34, weight: .heavy))
                            .foregroundStyle(Palette.ink)
                        Spacer()
                        Button("完成") { dismiss() }
                            .buttonStyle(PillButtonStyle(color: Palette.sage, size: 22))
                            .padding(.bottom, 6)
                    }
                    Text("关掉的游戏不会出现在主页上。星星、奖章和进度都留着，再打开就能接着玩。")
                        .font(.kid(17, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Text(shown == total ? "\(total) 个游戏都摆在主页上" : "主页上摆着 \(shown) 个，收起了 \(total - shown) 个")
                            .font(.kid(20, weight: .heavy))
                            .foregroundStyle(Palette.ink)
                            .contentTransition(.numericText())
                        Spacer()
                        if shown < total {
                            Button {
                                Sound.tap()
                                withAnimation(.spring(duration: 0.35)) { store.showAllOnHome() }
                            } label: {
                                Label("全部打开", systemImage: "arrow.uturn.backward")
                                    .font(.kid(18, weight: .heavy))
                                    .foregroundStyle(Palette.ink)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 10)
                                    .background(Palette.paper, in: Capsule())
                                    .overlay(Capsule().strokeBorder(Palette.ink.opacity(0.08), lineWidth: 1.5))
                            }
                            .buttonStyle(PressableStyle(scale: 0.94))
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                    }
                    .frame(minHeight: 44)
                    .padding(.top, 10)

                    let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: wide ? 2 : 1)
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(GameEntry.allCases, id: \.self) { HomeGameRow(game: $0) }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
                .frame(maxWidth: wide ? 1100 : 760)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Palette.cream.ignoresSafeArea())
    }
}

/// 一个游戏一行：卡片上的插画、名字、学到哪了、开关
private struct HomeGameRow: View {
    @Environment(PlayerStore.self) private var store
    let game: GameEntry

    private var subject: Subject? { Subjects.all.first { $0.entry == game } }

    var body: some View {
        let on = store.isOnHome(game)
        // 主页上只剩它一个的时候不能再关
        let locked = on && !store.canHide(game)
        HStack(spacing: 16) {
            ArtImage(name: game.cardArt, fallback: game.fallbackEmoji, contentMode: .fill)
                .frame(width: 114, height: 76)
                .background(game.cardColor)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .saturation(on ? 1 : 0)
                .opacity(on ? 1 : 0.55)
            VStack(alignment: .leading, spacing: 5) {
                Text(game.title)
                    .font(.kid(22, weight: .heavy))
                    .foregroundStyle(on ? Palette.ink : Palette.inkSoft)
                status(on: on, locked: locked)
            }
            Spacer(minLength: 8)
            Toggle(game.title, isOn: Binding(
                get: { on },
                set: { value in
                    Sound.tap()
                    withAnimation(.spring(duration: 0.35)) { store.setOnHome(game, value) }
                }))
                .labelsHidden()
                .tint(Palette.sage)
                .disabled(locked)
                .scaleEffect(1.15)
                .padding(.trailing, 6)
        }
        .padding(14)
        .softCard(radius: 28)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func status(on: Bool, locked: Bool) -> some View {
        let lens = store.rewards
        HStack(spacing: 10) {
            if locked {
                Text("主页至少留一个")
                    .foregroundStyle(Palette.coral)
            } else if let subject {
                if lens.graduated(subject) {
                    Label("学会了", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(Palette.sage)
                } else {
                    Text("学会 \(percentText(lens.progress(of: subject).fraction))")
                        .foregroundStyle(Palette.inkSoft)
                }
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").foregroundStyle(Palette.honey)
                    Text("\(lens.stars(in: subject))").foregroundStyle(Palette.inkSoft)
                }
                if !on {
                    Text("已收起")
                        .foregroundStyle(Palette.inkSoft.opacity(0.8))
                }
            }
        }
        .font(.kid(16, weight: .bold))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .monospacedDigit()
    }
}

#Preview {
    HomeGamesEditor().environment(PlayerStore())
}
