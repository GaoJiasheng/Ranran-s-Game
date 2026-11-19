import SwiftUI

/// 合集里的游戏。以后新游戏加在这里。
enum GameEntry: String, Hashable, CaseIterable {
    case gomoku
    case xiangqi
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
                // 横屏两张大卡并排；竖屏（或窄窗口）上下叠放。卡片高度跟着屏幕走，不滚动。
                let wide = geo.size.width > geo.size.height && geo.size.width > 900
                let roomy = geo.size.height > 760
                ZStack {
                    CreamBackground()
                    AdaptivePage {
                        VStack(alignment: .leading, spacing: roomy ? 28 : 20) {
                            header
                            if roomy {
                                Text("我的游戏")
                                    .font(.kid(26, weight: .heavy))
                                    .foregroundStyle(Palette.inkSoft)
                                    .padding(.top, 4)
                            }

                            Group {
                                if wide {
                                    HStack(spacing: 24) {
                                        ForEach(GameEntry.allCases, id: \.self) { g in
                                            GameHeroCard(game: g) { open(g) }.frame(maxWidth: .infinity)
                                        }
                                    }
                                    .frame(minHeight: 280, maxHeight: 560)
                                } else {
                                    VStack(spacing: 20) {
                                        ForEach(GameEntry.allCases, id: \.self) { g in
                                            GameHeroCard(game: g) { open(g) }.frame(minHeight: 200, maxHeight: 400)
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: .infinity)
                            ComingSoonCard().frame(height: roomy ? 110 : 84)
                        }
                        .padding(.horizontal, 48)
                        .padding(.vertical, roomy ? 36 : 24)
                        .frame(maxWidth: 1400, maxHeight: .infinity)
                        .frame(maxWidth: .infinity)
                        .offset(y: appeared ? 0 : 30)
                        .opacity(appeared ? 1 : 0)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .game(.gomoku):
                    GomokuSetupView().toolbar(.hidden, for: .navigationBar)
                case .game(.xiangqi):
                    XiangqiSetupView().toolbar(.hidden, for: .navigationBar)
                case .game(.story):
                    StorySetupView().toolbar(.hidden, for: .navigationBar)
                case .profile:
                    ProfileView().toolbar(.hidden, for: .navigationBar)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.25)) { appeared = true }
            #if DEBUG
            // 调试截图用：启动参数 -route gomoku / story / profile 直接打开那一页
            switch UserDefaults.standard.string(forKey: "route") {
            case "gomoku":  path = [.game(.gomoku)]
            case "xiangqi": path = [.game(.xiangqi)]
            case "story":   path = [.game(.story)]
            case "profile": path = [.profile]
            default: break
            }
            #endif
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

    private var title: String {
        switch game {
        case .gomoku: "五子棋"
        case .xiangqi: "象棋"
        case .story: "加减乘除"
        }
    }
    private var subtitle: String {
        switch game {
        case .gomoku: "十档难度，从小兔打到龙宝宝"
        case .xiangqi: "跟猫头鹰老师学，再挑战小伙伴"
        case .story: "英文应用题，演一演、画一画、算一算"
        }
    }
    private var art: String {
        switch game {
        case .gomoku: "card_gomoku"
        case .xiangqi: "card_xiangqi"
        case .story: "card_math"
        }
    }
    private var base: Color {
        switch game {
        case .gomoku: Color(hex: 0xF8DCCB)
        case .xiangqi: Color(hex: 0xF9DDD2)
        case .story: Color(hex: 0xDCEBF5)
        }
    }
    private var fade: Color {
        switch game {
        case .gomoku: Color(hex: 0xFBE9DD)
        case .xiangqi: Color(hex: 0xFBE6DE)
        case .story: Color(hex: 0xEAF3F8)
        }
    }
    private var button: Color {
        switch game {
        case .gomoku: Palette.coral
        case .xiangqi: Color(hex: 0xC9624F)
        case .story: Color(hex: 0x5FA3C9)
        }
    }

    var body: some View {
        Button(action: action) {
            GeometryReader { g in
            if g.size.width < 560 {
                tall(g.size)
            } else {
            ZStack(alignment: .leading) {
                base
                    .overlay(alignment: .trailing) {
                        // 卡片比插画还扁（竖屏三张叠放）时，按高度放下整张插画、靠右，免得把角色的头裁掉
                        if g.size.width / max(g.size.height, 1) > 1.5 {
                            ArtImage(name: art, fallback: "🎲", contentMode: .fit)
                                .frame(width: g.size.height * 1.5, height: g.size.height)
                                .mask(LinearGradient(stops: [.init(color: .clear, location: 0),
                                                             .init(color: .black, location: 0.25)],
                                                     startPoint: .leading, endPoint: .trailing))
                        } else {
                            ArtImage(name: art, fallback: "🎲", contentMode: .fill)
                        }
                    }
                    .clipped()

                LinearGradient(stops: [.init(color: fade, location: 0),
                                       .init(color: fade.opacity(0.85), location: 0.35),
                                       .init(color: .clear, location: 0.62)],
                               startPoint: .leading, endPoint: .trailing)

                // 卡片矮的时候先省掉小头像那一行
                ViewThatFits(in: .vertical) {
                    content(accessory: true)
                    content(accessory: false)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 24)
                // 文字只占卡片左边一部分，窄卡片上也不压到插画
                .frame(width: min(420, g.size.width * 0.6), alignment: .leading)
            }
            .frame(width: g.size.width, height: g.size.height)
            }
            }
            .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
            .softCard(radius: 44, fill: .clear)
        }
        .buttonStyle(PressableStyle(scale: 0.97))
    }

    /// 卡片很窄（横屏三张并排）时：插画在上，文字在下
    private func tall(_ size: CGSize) -> some View {
        VStack(spacing: 0) {
            ArtImage(name: art, fallback: "🎲", contentMode: .fill)
                .frame(width: size.width, height: size.height * 0.5, alignment: .trailing)
                .clipped()
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [fade.opacity(0), fade], startPoint: .top, endPoint: .bottom)
                        .frame(height: size.height * 0.12)
                }
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.kid(46, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(subtitle)
                    .font(.kid(19, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("开始玩")
                }
                .font(.kid(22, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 26)
                .padding(.vertical, 13)
                .background(button, in: Capsule())
                .shadow(color: button.opacity(0.45), radius: 14, y: 8)
            }
            .padding(.horizontal, 28)
            .padding(.top, 10)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(fade)
        }
        .frame(width: size.width, height: size.height)
    }

    private func content(accessory show: Bool) -> some View {
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
            if show {
                accessory
                    .padding(.top, 6)
            }
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
    }

    @ViewBuilder private var accessory: some View {
        if game == .gomoku || game == .xiangqi {
            HStack(spacing: -14) {
                ForEach(Opponent.allCases) { o in
                    Avatar(image: o.image, fallback: o.emoji, tint: o.tint, size: 54)
                }
            }
        } else {
            HStack(spacing: 8) {
                ForEach(["plus", "minus", "multiply", "divide"], id: \.self) { symbol in
                    Image(systemName: symbol)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(button)
                        .frame(width: 54, height: 54)
                        .background(Palette.paper.opacity(0.85), in: Circle())
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

/// 星星数量。主页是全部的星星；游戏页传 value，只显示这个游戏里拿到的（= 各关星星加起来）。
struct StarCounter: View {
    enum Size { case regular, large }
    var size: Size = .regular
    var value: Int? = nil
    @Environment(PlayerStore.self) private var store

    var body: some View {
        let big = size == .large
        let shown = value ?? store.totalStars
        HStack(spacing: 10) {
            Image(systemName: "star.fill")
                .font(.system(size: big ? 30 : 24, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [Palette.honey, Palette.coral], startPoint: .top, endPoint: .bottom))
            Text("\(shown)")
                .font(.kid(big ? 34 : 28, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
                .monospacedDigit()
        }
        .padding(.horizontal, big ? 26 : 20)
        .padding(.vertical, big ? 14 : 11)
        .softCard(radius: 40)
        .animation(.spring, value: shown)
    }
}

#Preview {
    HomeView().environment(PlayerStore())
}
