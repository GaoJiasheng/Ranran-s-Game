import SwiftUI

/// 合集里的游戏。以后新游戏加在这里。
enum GameEntry: String, Hashable, CaseIterable {
    case gomoku
    case story
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

                            let gomoku = GameHeroCard(game: .gomoku) { open(.gomoku) }
                            let story = GameHeroCard(game: .story) { open(.story) }
                            if wide {
                                HStack(spacing: 28) {
                                    gomoku.frame(maxWidth: .infinity)
                                    story.frame(maxWidth: .infinity)
                                }
                                .frame(height: 420)
                                ComingSoonCard().frame(height: 120)
                            } else {
                                VStack(spacing: 28) {
                                    gomoku.frame(height: 400)
                                    story.frame(height: 400)
                                    ComingSoonCard().frame(height: 140)
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
                case .game(.story):
                    StorySetupView().toolbar(.hidden, for: .navigationBar)
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

/// 主页上一个游戏的大卡片：左边是名字，右边是插画。
private struct GameHeroCard: View {
    let game: GameEntry
    let action: () -> Void

    private var title: String { game == .gomoku ? "五子棋" : "小伙伴的故事" }
    private var subtitle: String { game == .gomoku ? "十档难度，从小兔打到龙宝宝" : "听故事、演一演，读懂应用题" }
    private var art: String { game == .gomoku ? "card_gomoku" : "card_story" }
    private var base: Color { game == .gomoku ? Color(hex: 0xF8DCCB) : Color(hex: 0xDDEEDF) }
    private var fade: Color { game == .gomoku ? Color(hex: 0xFBE9DD) : Color(hex: 0xEAF4EA) }
    private var button: Color { game == .gomoku ? Palette.coral : Color(hex: 0x6FA67C) }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                base
                    .overlay(alignment: .trailing) {
                        ArtImage(name: art, fallback: game == .gomoku ? "⚫️⚪️" : "🍎", contentMode: .fill)
                    }
                    .clipped()

                LinearGradient(stops: [.init(color: fade, location: 0),
                                       .init(color: fade.opacity(0.85), location: 0.35),
                                       .init(color: .clear, location: 0.62)],
                               startPoint: .leading, endPoint: .trailing)

                VStack(alignment: .leading, spacing: 14) {
                    Text(title)
                        .font(.kid(60, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(subtitle)
                        .font(.kid(22, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    accessory
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
                    .background(button, in: Capsule())
                    .shadow(color: button.opacity(0.45), radius: 14, y: 8)
                }
                .padding(.horizontal, 40)
                .frame(maxWidth: 400, alignment: .leading)
            }
            .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
            .softCard(radius: 44, fill: .clear)
        }
        .buttonStyle(PressableStyle(scale: 0.97))
    }

    @ViewBuilder private var accessory: some View {
        if game == .gomoku {
            HStack(spacing: -14) {
                ForEach(Opponent.allCases) { o in
                    Avatar(image: o.image, fallback: o.emoji, tint: o.tint, size: 54)
                }
            }
        } else {
            HStack(spacing: 6) {
                ForEach(StoryItem.allCases, id: \.self) { item in
                    ArtImage(name: item.image, fallback: item.emoji)
                        .frame(width: 46, height: 46)
                        .frame(width: 58, height: 58)
                        .background(Palette.paper.opacity(0.8), in: Circle())
                }
            }
        }
    }
}

/// 留给以后的新游戏。
private struct ComingSoonCard: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Palette.lilac)
            Text("更多游戏")
                .font(.kid(28, weight: .heavy))
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
