import SwiftUI

/// 合集里的游戏。以后新游戏加在这里。
enum GameEntry: String, Hashable, CaseIterable {
    case gomoku
    case xiangqi
    case go
    case chess
    case sudoku
    case tangram
    case klotski
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
                // 卡片大小跟着屏幕走，不滚动。
                let wide = geo.size.width > geo.size.height && geo.size.width > 900
                let roomy = geo.size.height > 760
                ZStack {
                    CreamBackground()
                    AdaptivePage {
                        VStack(alignment: .leading, spacing: roomy ? 28 : 20) {
                            header
                            if roomy && (!wide || geo.size.height > 900) {
                                Text("我的游戏")
                                    .font(.kid(26, weight: .heavy))
                                    .foregroundStyle(Palette.inkSoft)
                                    .padding(.top, 4)
                            }

                            // 摆着的游戏平分地方：八个时横屏四列两排、竖屏两列四排；
                            // 家长收起来几个以后按剩下的个数重新分排（HomeGridPlan）
                            GameGrid(games: store.homeGames, wide: wide, spacing: roomy ? 20 : 16) { open($0) }
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
                case .game(.chess):
                    ChessSetupView().toolbar(.hidden, for: .navigationBar)
                case .game(.sudoku):
                    SudokuSetupView().toolbar(.hidden, for: .navigationBar)
                case .game(.tangram):
                    TangramSetupView().toolbar(.hidden, for: .navigationBar)
                case .game(.klotski):
                    KlotskiSetupView().toolbar(.hidden, for: .navigationBar)
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
            // 游戏的名字就是 GameEntry 的名字：gomoku / xiangqi / go / chess / sudoku / tangram / klotski / story
            let route = UserDefaults.standard.string(forKey: "route") ?? ""
            if route == "profile" { path = [.profile] }
            else if let g = GameEntry(rawValue: route) { path = [.game(g)] }
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

/// 主页上的游戏格子：一排一排平分高度，每排里的卡片平分宽度
private struct GameGrid: View {
    let games: [GameEntry]
    let wide: Bool
    let spacing: CGFloat
    let open: (GameEntry) -> Void

    /// 按 HomeGridPlan 把游戏切成一排一排
    private var rows: [[GameEntry]] {
        var rest = games[...]
        return HomeGridPlan.rows(count: games.count, wide: wide).map { n in
            defer { rest = rest.dropFirst(n) }
            return Array(rest.prefix(n))
        }
    }

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(row, id: \.self) { game in
                        GameTile(game: game) { open(game) }
                    }
                }
            }
        }
    }
}

/// 一个游戏在主页上要交代的东西
extension GameEntry {
    var title: String {
        switch self {
        case .gomoku: "五子棋"
        case .xiangqi: "象棋"
        case .go: "围棋"
        case .chess: "国际象棋"
        case .sudoku: "数独"
        case .tangram: "七巧板"
        case .klotski: "华容道"
        case .story: "加减乘除"
        }
    }

    /// 卡片够大时才显示的一句话
    var tagline: String {
        switch self {
        case .gomoku: "十档难度，从小兔打到龙宝宝"
        case .xiangqi: "跟猫头鹰老师学，再挑战小伙伴"
        case .go: "从吃子棋开始，一步步学会围棋"
        case .chess: "王、后、车、象、马、兵，一个一个学"
        case .sudoku: "从四宫格的水果开始，动脑筋填一填"
        case .tangram: "七块板子，拼出小动物和小房子"
        case .klotski: "挪一挪、让一让，帮小兔走到出口"
        case .story: "英文应用题，演一演、画一画、算一算"
        }
    }

    var cardArt: String {
        switch self {
        case .story: "card_math"
        default: "card_\(rawValue)"
        }
    }

    /// 卡片的底色（和插画的背景接得上）
    var cardColor: Color {
        switch self {
        case .gomoku: Color(hex: 0xFBE9DD)
        case .xiangqi: Color(hex: 0xFBE6DE)
        case .go: Color(hex: 0xEAF4EA)
        case .chess: Color(hex: 0xEEEBF8)
        case .sudoku: Color(hex: 0xFAF0DC)
        case .tangram: Color(hex: 0xE6F4F2)
        case .klotski: Color(hex: 0xF8EADD)
        case .story: Color(hex: 0xEAF3F8)
        }
    }

    var fallbackEmoji: String {
        switch self {
        case .gomoku, .go: "⚫️"
        case .xiangqi, .chess: "♟️"
        case .sudoku: "🔢"
        case .tangram: "🔺"
        case .klotski: "🧩"
        case .story: "➕"
        }
    }
}

/// 主页上一个游戏的卡片：整张都能点。按卡片的形状换三种排法：
/// 扁的（竖屏两列）插画在右、名字在左；方的（横屏四列）插画在上、名字压在底下一条；
/// 高的（只摆着几个游戏时）插画整张在上、名字和一句话在下。
private struct GameTile: View {
    let game: GameEntry
    let action: () -> Void

    /// 这张卡片对应的科目（学会了多少）
    private var subject: Subject? { Subjects.all.first { $0.entry == game } }

    var body: some View {
        Button(action: action) {
            GeometryReader { g in
                let aspect = g.size.width / max(g.size.height, 1)
                Group {
                    if aspect > 1.55 {
                        wide(g.size)
                    } else if aspect < 1.0 {
                        stacked(g.size)
                    } else {
                        tall(g.size)
                    }
                }
                .frame(width: g.size.width, height: g.size.height)
                .background(Rectangle().fill(game.cardColor))
            }
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .softCard(radius: 36, fill: .clear)
        }
        .buttonStyle(PressableStyle(scale: 0.96))
        .accessibilityLabel(game.title)
    }

    /// 插画在上面铺满，底下一条压着名字和"学会了多少"
    private func tall(_ size: CGSize) -> some View {
        let band = min(max(size.height * 0.27, 54), 86)
        let roomy = size.height > 270
        return ZStack(alignment: .bottom) {
            ArtImage(name: game.cardArt, fallback: game.fallbackEmoji, contentMode: .fill)
                .frame(width: size.width, height: size.height - band + 10, alignment: .trailing)
                .clipped()
                .frame(maxHeight: .infinity, alignment: .top)
            VStack(spacing: 0) {
                LinearGradient(colors: [game.cardColor.opacity(0), game.cardColor], startPoint: .top, endPoint: .bottom)
                    .frame(height: 30)
                HStack(spacing: 8) {
                    Text(game.title)
                        .font(.kid(min(roomy ? 38 : 30, band * 0.5), weight: .heavy))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer(minLength: 2)
                    if let subject {
                        SubjectProgressPill(subject: subject, height: roomy ? 42 : 34, compact: true)
                            .fixedSize()
                    }
                }
                .padding(.horizontal, roomy ? 22 : 16)
                .padding(.bottom, 4)
                .frame(height: band)
                .background(game.cardColor)
            }
        }
    }

    /// 卡片比较高：插画整张放在上面，下面是名字、一句话和"学会了多少"
    private func stacked(_ size: CGSize) -> some View {
        // 插画是 3:2 的；卡片特别高时让它再高一点（两边各裁掉一点），不然下面空得太多
        let artHeight = min(max(size.width / 1.5, size.height - 250), size.width / 1.5 * 1.18, size.height * 0.68)
        let textHeight = size.height - artHeight
        let big = size.width > 520
        return VStack(spacing: 0) {
            ArtImage(name: game.cardArt, fallback: game.fallbackEmoji, contentMode: .fill)
                .frame(width: size.width, height: artHeight)
                .clipped()
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [game.cardColor.opacity(0), game.cardColor], startPoint: .top, endPoint: .bottom)
                        .frame(height: 36)
                }
            VStack(alignment: .leading, spacing: big ? 14 : 8) {
                Text(game.title)
                    .font(.kid(big ? 64 : min(40, size.width * 0.115), weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if textHeight > 190 {
                    Text(game.tagline)
                        .font(.kid(big ? 24 : 17, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let subject {
                    SubjectProgressPill(subject: subject, height: big ? 52 : 40, compact: size.width < 330)
                        .fixedSize()
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, big ? 36 : 22)
            .padding(.bottom, 6)
            .frame(width: size.width, height: textHeight, alignment: .leading)
        }
    }

    /// 插画靠右放下整张，名字和一句话在左边
    private func wide(_ size: CGSize) -> some View {
        // 左边留给字的宽度。卡片不够宽时（横屏一排三个）插画会伸过来，字就只留名字和进度，名字也小一点
        let textWidth = max(size.width - size.height * 0.95, 150)
        let roomy = size.height > 205 && textWidth >= 230
        // 只摆着一两个游戏时卡片很大，字跟着大一号
        let big = size.height > 300
        return ZStack(alignment: .leading) {
            ArtImage(name: game.cardArt, fallback: game.fallbackEmoji, contentMode: .fit)
                .frame(width: size.height * 1.5, height: size.height)
                .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.3)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(maxWidth: .infinity, alignment: .trailing)
            VStack(alignment: .leading, spacing: roomy ? 10 : 8) {
                Text(game.title)
                    .font(.kid(min(big ? 64 : 44, size.height * 0.21, (textWidth - 26) / 3.4), weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if roomy {
                    Text(game.tagline)
                        .font(.kid(big ? 22 : 17, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let subject {
                    SubjectProgressPill(subject: subject, height: big ? 50 : roomy ? 42 : 36, compact: !roomy)
                        .fixedSize()
                }
            }
            .padding(.leading, big ? 40 : 26)
            .frame(width: textWidth, alignment: .leading)
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
