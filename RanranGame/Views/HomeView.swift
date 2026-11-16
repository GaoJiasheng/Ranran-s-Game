import SwiftUI

/// 合集里的游戏。以后新游戏加在这里。
enum GameEntry: String, Hashable, CaseIterable {
    case gomoku
}

/// 主页上能去的地方
enum Route: Hashable {
    case game(GameEntry)
    case profile
}

/// 主页：游戏屋。
struct HomeView: View {
    @Environment(PlayerStore.self) private var store
    @State private var path: [Route] = []
    @State private var appeared = false

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { geo in
                let wide = geo.size.width > 1000
                ZStack {
                    CreamBackground()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 36) {
                            header
                            Text("我的游戏")
                                .font(.kid(26, weight: .heavy))
                                .foregroundStyle(Palette.inkSoft)
                                .padding(.top, 12)

                            let hero = GameHeroCard { open(.gomoku) }
                            if wide {
                                HStack(spacing: 28) {
                                    hero.frame(maxWidth: .infinity)
                                    ComingSoonCard().frame(width: geo.size.width * 0.26)
                                }
                                .frame(height: 400)
                            } else {
                                VStack(spacing: 28) {
                                    hero.frame(height: 400)
                                    ComingSoonCard().frame(height: 180)
                                }
                            }
                        }
                        .padding(.horizontal, 48)
                        .padding(.vertical, 40)
                        .frame(maxWidth: 1400)
                        .frame(maxWidth: .infinity)
                        .offset(y: appeared ? 0 : 30)
                        .opacity(appeared ? 1 : 0)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .game(.gomoku):
                    GomokuSetupView().toolbar(.hidden, for: .navigationBar)
                case .profile:
                    ProfileView().toolbar(.hidden, for: .navigationBar)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.25)) { appeared = true }
        }
    }

    private func open(_ entry: GameEntry) {
        Sound.tap()
        path.append(.game(entry))
    }

    private var header: some View {
        HStack(spacing: 22) {
            Button {
                Sound.tap()
                path.append(.profile)
            } label: {
                Avatar(image: "avatar_ranran", fallback: "👧", tint: Palette.blush, size: 104)
                    .shadow(color: Palette.coral.opacity(0.25), radius: 16, y: 8)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(Palette.inkSoft)
                            .frame(width: 34, height: 34)
                            .background(Palette.paper, in: Circle())
                            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                            .offset(x: 2, y: 2)
                    }
            }
            .buttonStyle(PressableStyle(scale: 0.92))
            .accessibilityLabel("我的")
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.kid(22, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                Text("\(store.name)的游戏屋")
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .font(.kid(56, weight: .heavy))
                    .foregroundStyle(Palette.ink)
            }
            Spacer()
            StarCounter(size: .large)
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<11:  "早上好，\(store.name)"
        case 11..<14: "中午好，\(store.name)"
        case 14..<18: "下午好，\(store.name)"
        default:      "晚上好，\(store.name)"
        }
    }
}

/// 五子棋的大卡片。
private struct GameHeroCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                Color(hex: 0xF8DCCB)
                    .overlay(alignment: .trailing) {
                        ArtImage(name: "card_gomoku", fallback: "⚫️⚪️", contentMode: .fill)
                    }
                    .clipped()

                LinearGradient(stops: [.init(color: Color(hex: 0xFBE9DD), location: 0),
                                       .init(color: Color(hex: 0xFBE9DD).opacity(0.85), location: 0.35),
                                       .init(color: .clear, location: 0.62)],
                               startPoint: .leading, endPoint: .trailing)

                VStack(alignment: .leading, spacing: 14) {
                    Text("五子棋")
                        .font(.kid(68, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                    Text("十档难度，从小兔一路打到龙宝宝")
                        .font(.kid(24, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                    HStack(spacing: -14) {
                        ForEach(Opponent.allCases) { o in
                            Avatar(image: o.image, fallback: o.emoji, tint: o.tint, size: 58)
                        }
                    }
                    .padding(.top, 6)
                    Spacer().frame(height: 10)
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                        Text("开始玩")
                    }
                    .font(.kid(24, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Palette.coral, in: Capsule())
                    .shadow(color: Palette.coral.opacity(0.45), radius: 14, y: 8)
                }
                .padding(.horizontal, 48)
            }
            .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
            .softCard(radius: 44, fill: .clear)
        }
        .buttonStyle(PressableStyle(scale: 0.97))
    }
}

/// 留给以后的新游戏。
private struct ComingSoonCard: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Palette.lilac)
            Text("新游戏")
                .font(.kid(30, weight: .heavy))
                .foregroundStyle(Palette.ink.opacity(0.7))
            Text("正在精心制作中…")
                .font(.kid(20, weight: .semibold))
                .foregroundStyle(Palette.inkSoft.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.paper.opacity(0.45), in: RoundedRectangle(cornerRadius: 44, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .strokeBorder(Palette.inkSoft.opacity(0.25), style: StrokeStyle(lineWidth: 2.5, dash: [10, 9]))
        )
    }
}

/// 星星数量。
struct StarCounter: View {
    enum Size { case regular, large }
    var size: Size = .regular
    @Environment(PlayerStore.self) private var store

    var body: some View {
        let big = size == .large
        HStack(spacing: 10) {
            Image(systemName: "star.fill")
                .font(.system(size: big ? 30 : 24, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [Palette.honey, Palette.coral], startPoint: .top, endPoint: .bottom))
            Text("\(store.totalStars)")
                .font(.kid(big ? 34 : 28, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
                .monospacedDigit()
        }
        .padding(.horizontal, big ? 26 : 20)
        .padding(.vertical, big ? 14 : 11)
        .softCard(radius: 40)
        .animation(.spring, value: store.totalStars)
    }
}

#Preview {
    HomeView().environment(PlayerStore())
}
