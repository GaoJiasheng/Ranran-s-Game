import SwiftUI

/// 合集里的游戏。以后新游戏加在这里。
enum GameEntry: String, Hashable, CaseIterable {
    case gomoku
    case xiangqi
    case go
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
    /// 奖章墙开在哪一页；nil 是没开
    @State private var wall: WallTab?

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
                                            // 11 寸竖屏放四张卡，每张只有 180 左右；最小高度定得太大，底下的「今天的三颗星」会被挤出屏幕
                                            GameHeroCard(game: g) { open(g) }.frame(minHeight: 150, maxHeight: 400)
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: .infinity)
                            DailyStarsCard { wall = .daily }.frame(height: roomy ? 110 : 84)
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
                case .game(.go):
                    GoSetupView().toolbar(.hidden, for: .navigationBar)
                case .game(.story):
                    StorySetupView().toolbar(.hidden, for: .navigationBar)
                case .profile:
                    ProfileView().toolbar(.hidden, for: .navigationBar)
                }
            }
        }
        .medalLayer(atHome: path.isEmpty, wall: $wall)
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.25)) { appeared = true }
            #if DEBUG
            // 调试截图用：启动参数 -route gomoku / story / profile 直接打开那一页
            switch UserDefaults.standard.string(forKey: "route") {
            case "gomoku":  path = [.game(.gomoku)]
            case "xiangqi": path = [.game(.xiangqi)]
            case "go":      path = [.game(.go)]
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
            VStack(alignment: .trailing, spacing: 5) {
                StarCounter(size: .large)
                MedalHint { wall = .stars }
            }
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
        case .go: "围棋"
        case .story: "加减乘除"
        }
    }
    private var subtitle: String {
        switch game {
        case .gomoku: "十档难度，从小兔打到龙宝宝"
        case .xiangqi: "跟猫头鹰老师学，再挑战小伙伴"
        case .go: "从吃子棋开始，一步步学会围棋"
        case .story: "英文应用题，演一演、画一画、算一算"
        }
    }
    private var art: String {
        switch game {
        case .gomoku: "card_gomoku"
        case .xiangqi: "card_xiangqi"
        case .go: "card_go"
        case .story: "card_math"
        }
    }
    private var base: Color {
        switch game {
        case .gomoku: Color(hex: 0xF8DCCB)
        case .xiangqi: Color(hex: 0xF9DDD2)
        case .go: Color(hex: 0xDDEEDF)
        case .story: Color(hex: 0xDCEBF5)
        }
    }
    private var fade: Color {
        switch game {
        case .gomoku: Color(hex: 0xFBE9DD)
        case .xiangqi: Color(hex: 0xFBE6DE)
        case .go: Color(hex: 0xEAF4EA)
        case .story: Color(hex: 0xEAF3F8)
        }
    }
    private var button: Color {
        switch game {
        case .gomoku: Palette.coral
        case .xiangqi: Color(hex: 0xC9624F)
        case .go: Color(hex: 0x6FA07A)
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

                // 卡片矮的时候依次省掉：小头像那一行 → 副标题 → 标题变小 → 学会了多少
                ViewThatFits(in: .vertical) {
                    content(subtitle: true, accessory: true)
                    content(subtitle: true, accessory: false)
                    content(subtitle: false, accessory: false)
                    content(subtitle: false, accessory: false, compact: true)
                    content(subtitle: false, accessory: false, compact: true, pill: false)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, min(24, g.size.height * 0.08))
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

    /// 这张卡片对应的科目（学会了多少）
    private var subject: Subject? { Subjects.all.first { $0.entry == game } }

    /// 卡片很窄（横屏三张并排）时：插画在上，文字在下。
    /// "学会了多少"放在文字区、开始玩按钮的上面，不压插画；放不下先省副标题，最后才省它。
    private func tall(_ size: CGSize) -> some View {
        VStack(spacing: 0) {
            ArtImage(name: art, fallback: "🎲", contentMode: .fill)
                .frame(width: size.width, height: size.height * 0.5, alignment: .trailing)
                .clipped()
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [fade.opacity(0), fade], startPoint: .top, endPoint: .bottom)
                        .frame(height: size.height * 0.12)
                }
            ViewThatFits(in: .vertical) {
                tallText(subtitleLines: 2, pill: true)
                tallText(subtitleLines: 1, pill: true)
                tallText(subtitleLines: 0, pill: true)
                tallText(subtitleLines: 0, pill: true, titleSize: 36)
                tallText(subtitleLines: 2, pill: false)
            }
            .padding(.horizontal, 28)
            .padding(.top, 10)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(fade)
        }
        .frame(width: size.width, height: size.height)
    }

    private func tallText(subtitleLines: Int, pill: Bool, titleSize: CGFloat = 46) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.kid(titleSize, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if subtitleLines > 0 {
                Text(subtitle)
                    .font(.kid(19, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(subtitleLines)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)
            if pill, let subject {
                SubjectProgressPill(subject: subject, height: 44)
            }
            playButton(size: 22)
        }
    }

    private func content(subtitle showSubtitle: Bool, accessory show: Bool, compact: Bool = false, pill: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 14) {
            Text(title)
                .font(.kid(compact ? 46 : 60, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if showSubtitle {
                Text(subtitle)
                    .font(.kid(22, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            if show {
                accessory
                    .padding(.top, 6)
            }
            Spacer().frame(height: compact ? 2 : 10)
            // 开始玩 + 学会了多少，并排一行
            HStack(spacing: 14) {
                playButton(size: compact ? 22 : 24)
                if pill, let subject {
                    SubjectProgressPill(subject: subject, height: compact ? 46 : 52)
                }
            }
        }
    }

    private func playButton(size: CGFloat) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "play.fill")
            Text("开始玩")
        }
        .font(.kid(size, weight: .heavy))
        .foregroundStyle(.white)
        .padding(.horizontal, size * 1.2)
        .padding(.vertical, size * 0.6)
        .background(button, in: Capsule())
        .shadow(color: button.opacity(0.45), radius: 14, y: 8)
        .fixedSize()
    }

    @ViewBuilder private var accessory: some View {
        if game == .gomoku || game == .xiangqi || game == .go {
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
