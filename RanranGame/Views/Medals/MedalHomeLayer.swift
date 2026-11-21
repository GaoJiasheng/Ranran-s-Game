import SwiftUI

// MARK: - 主页上的庆祝队列

/// 主页上要庆祝的一件事
enum HomeCheer: Equatable {
    case gift(stars: Int, badges: Int)
    case medal(Medal)
    case badge(SkillBadge)
    case daily

    static func == (a: HomeCheer, b: HomeCheer) -> Bool {
        switch (a, b) {
        case let (.gift(s1, b1), .gift(s2, b2)): s1 == s2 && b1 == b2
        case let (.medal(m1), .medal(m2)): m1 == m2
        case let (.badge(x), .badge(y)): x == y
        case (.daily, .daily): true
        default: false
        }
    }
}

/// 挂在主页上：回到主页时，把还没庆祝的事一件一件地庆祝，一次只弹一个，顺序是
/// 升级礼物 → 星星奖章 → 本领奖章（最多 3 枚，毕业的先）→ 今天的三颗星做完。
/// 每件事一弹出来就记下"庆祝过了"，所以中途退出也不会重复弹。
/// 游戏进行中不会弹，因为那时主页不在最上面；奖章墙开着的时候也先等着。
struct MedalHomeLayer: ViewModifier {
    let atHome: Bool
    @Binding var wall: WallTab?
    @Environment(PlayerStore.self) private var store
    @State private var showing: HomeCheer?
    /// 每收起一个就加一，让队列再看一眼还有没有下一个
    @State private var round = 0
    #if DEBUG
    /// 调试参数要预览的庆祝，排在最前面，不记录
    @State private var debugQueue: [HomeCheer] = []
    #endif

    /// 一次最多庆祝几枚本领奖章，多出来的直接算看过（去奖章墙能看到）
    private static let maxBadgesAtOnce = 3

    private struct Trigger: Hashable {
        var atHome: Bool
        var wallOpen: Bool
        var showing: Bool
        var round: Int
        var stars: Int
        var celebrated: Int
        var pendingBadges: Int
        var cheer: Bool
        var gift: Bool
    }

    func body(content: Content) -> some View {
        content
            .overlay { overlay }
            .fullScreenCover(item: $wall) { MedalWallView(tab: $0).statusBarHidden() }
            .task(id: Trigger(atHome: atHome, wallOpen: wall != nil, showing: showing != nil, round: round,
                              stars: store.medalStars, celebrated: store.medalsCelebrated,
                              pendingBadges: store.pendingBadges.count, cheer: store.dailyCheerPending(),
                              gift: store.pendingGift != nil)) {
                guard atHome, showing == nil, wall == nil, hasNext else { return }
                // 回到主页先停一下，让页面落定再弹
                try? await Task.sleep(for: .milliseconds(round == 0 ? 700 : 450))
                guard !Task.isCancelled, atHome, showing == nil, wall == nil, let next = takeNext() else { return }
                withAnimation(.spring(duration: 0.4)) { showing = next }
            }
            #if DEBUG
            .onAppear(perform: readDebugArguments)
            #endif
    }

    @ViewBuilder private var overlay: some View {
        switch showing {
        case .gift(let stars, let badges):
            GiftCelebration(stars: stars, badges: badges, openWall: { finish(openWall: .stars) }, onDone: { finish() })
                .transition(.opacity)
        case .medal(let m):
            MedalCelebration(medal: m, stars: store.medalStars) { finish() }
                .transition(.opacity)
        case .badge(let b):
            BadgeCelebration(badge: b) { finish() }
                .transition(.opacity)
                .id(b.id)
        case .daily:
            DailyCheer { finish() }
                .transition(.opacity)
        case nil:
            EmptyView()
        }
    }

    private func finish(openWall tab: WallTab? = nil) {
        withAnimation(.easeOut(duration: 0.25)) { showing = nil }
        if let tab { wall = tab }
        round += 1
    }

    // MARK: 排队

    private var hasNext: Bool {
        #if DEBUG
        if !debugQueue.isEmpty { return true }
        #endif
        return store.pendingGift != nil || store.pendingMedal != nil || !store.pendingBadges.isEmpty || store.dailyCheerPending()
    }

    /// 取出下一件要庆祝的事，并且马上记成"庆祝过了"
    private func takeNext() -> HomeCheer? {
        #if DEBUG
        if !debugQueue.isEmpty { return debugQueue.removeFirst() }
        #endif
        if let g = store.pendingGift {
            store.clearGift()
            return .gift(stars: g.stars, badges: g.badges)
        }
        if let m = store.pendingMedal {
            store.markMedalsCelebrated(through: m)
            return .medal(m)
        }
        let pending = Self.ordered(store.pendingBadges)
        if let first = pending.first {
            // 一下子来了很多枚（比如家长导入了存档）：只庆祝最要紧的 3 枚，其余的直接算看过
            if pending.count > Self.maxBadgesAtOnce {
                for b in pending.dropFirst(Self.maxBadgesAtOnce) { store.markBadgeSeen(b.id) }
            }
            store.markBadgeSeen(first.id)
            return .badge(first)
        }
        if store.dailyCheerPending() {
            store.clearDailyCheer()
            return .daily
        }
        return nil
    }

    /// 最要紧的排前面：毕业 > 打败小伙伴 > 学完一组课 / 一章 > 好习惯；同一种里越往后的越难，排前面
    static func ordered(_ badges: [SkillBadge]) -> [SkillBadge] {
        let all = Subjects.allBadges
        let index = Dictionary(uniqueKeysWithValues: all.enumerated().map { ($1.id, $0) })
        return badges.sorted {
            $0.significance != $1.significance ? $0.significance > $1.significance
                : (index[$0.id] ?? 0) > (index[$1.id] ?? 0)
        }
    }

    #if DEBUG
    /// 调试用的启动参数：
    /// -medals YES 打开奖章墙；-wallTab <stars|daily|科目 id> 打开奖章墙的那一页；
    /// -giftDemo YES 预览升级礼物；-medalUnlock N 预览第 N 枚星星奖章的庆祝；
    /// -badgeUnlock <奖章 id> 预览那枚本领奖章的庆祝；-dailyCheer YES 预览三颗星做完。预览都不记录。
    private func readDebugArguments() {
        let d = UserDefaults.standard
        if let t = d.string(forKey: "wallTab"), WallTab.all.contains(WallTab(id: t)) {
            wall = WallTab(id: t)
        } else if d.bool(forKey: "medals") {
            wall = .stars
        }
        var q: [HomeCheer] = []
        if d.bool(forKey: "giftDemo") { q.append(.gift(stars: 46, badges: 5)) }
        let n = d.integer(forKey: "medalUnlock")
        if (1...Medal.all.count).contains(n) { q.append(.medal(Medal.all[n - 1])) }
        if let id = d.string(forKey: "badgeUnlock"), let b = Subjects.allBadges.first(where: { $0.id == id }) {
            q.append(.badge(b))
        }
        if d.bool(forKey: "dailyCheer") { q.append(.daily) }
        debugQueue = q
        // 队列是在页面出现以后才填的，推一下让上面的 task 再看一眼
        if !q.isEmpty { round += 1 }
    }
    #endif
}

extension View {
    /// 主页的奖章层：庆祝队列 + 奖章墙（wall 不是 nil 就打开在那一页）
    func medalLayer(atHome: Bool, wall: Binding<WallTab?>) -> some View {
        modifier(MedalHomeLayer(atHome: atHome, wall: wall))
    }
}
