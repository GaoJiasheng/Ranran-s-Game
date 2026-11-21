import SwiftUI

/// 「约好的奖励」入口卡：家长给奖章配一个现实里的小奖励，孩子拿到奖章时会看到。
/// 只有长按约 1.5 秒才能打开编辑页，避免孩子随手改动。
struct RewardNotesEntryCard: View {
    @Environment(PlayerStore.self) private var store
    @State private var showing = false
    @State private var pressing = false

    private var count: Int {
        Medal.all.filter { !store.medalReward($0).isEmpty }.count
            + RewardNotesEditor.graduateBadges.filter { !store.badgeReward($0).isEmpty }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("约好的奖励")
                .font(.kid(28, weight: .heavy))
                .foregroundStyle(Palette.ink)
            Text("给奖章配一个小奖励，拿到奖章时会显示给孩子看")
                .font(.kid(17, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 14) {
                Text("已约定 \(count) 个")
                    .font(.kid(18, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Spacer()
                openButton
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard(radius: 40)
        .sheet(isPresented: $showing) { RewardNotesEditor() }
        .onAppear {
            #if DEBUG
            // 调试截图用：启动参数 -rewardNotes YES 直接打开编辑页
            if UserDefaults.standard.string(forKey: "rewardNotes") == "YES" { showing = true }
            #endif
        }
    }

    /// 长按约 1.5 秒才打开；按住时底色从左往右慢慢填满
    private var openButton: some View {
        VStack(spacing: 4) {
            Label("编辑奖励", systemImage: "gift.fill")
                .font(.kid(20, weight: .heavy))
                .foregroundStyle(pressing ? .white : Palette.ink)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(alignment: .leading) {
                    GeometryReader { g in
                        Capsule().fill(Palette.coral)
                            .frame(width: pressing ? g.size.width : 0)
                            // 松手立刻清零，按住时线性填满
                            .animation(pressing ? .linear(duration: 1.5) : .easeOut(duration: 0.15), value: pressing)
                    }
                }
                .background(Capsule().fill(Palette.lilac.opacity(0.3)))
                .clipShape(Capsule())
                .contentShape(Capsule())
                .onLongPressGesture(minimumDuration: 1.5, maximumDistance: 30) {
                    Sound.tap()
                    showing = true
                } onPressingChanged: { pressing = $0 }
            Text("家长长按打开")
                .font(.kid(13, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
        }
    }
}

/// 写奖励的页面：12 枚星星奖章 + 4 枚毕业奖章，每行一个输入框
struct RewardNotesEditor: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var drafts: [String: String] = [:]
    @FocusState private var focus: String?

    /// 每个科目的「学会了」奖章
    static var graduateBadges: [SkillBadge] {
        Subjects.all.compactMap { subject in subject.badges.first { $0.kind == .graduate } }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("约好的奖励")
                            .font(.kid(34, weight: .heavy))
                            .foregroundStyle(Palette.ink)
                        Spacer()
                        Button("完成") { finish() }
                            .buttonStyle(PillButtonStyle(color: Palette.sage, size: 22))
                            .padding(.bottom, 6)
                    }
                    Text("每项最多 20 个字，留空就是不设奖励。")
                        .font(.kid(17, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)

                    section("星星奖章")
                    ForEach(Medal.all) { medal in
                        row(key: "reward.medal.\(medal.id)", title: medal.name,
                            detail: "满 \(medal.threshold) 颗星星") {
                            MedalBadge(medal: medal, size: 72)
                        }
                    }

                    section("毕业奖章")
                    ForEach(Self.graduateBadges) { badge in
                        row(key: "reward.badge.\(badge.id)", title: badge.name, detail: badge.how) {
                            ArtImage(name: badge.art, fallback: "🏆")
                                .padding(10)
                                .frame(width: 72, height: 72)
                                .background(badge.tint.opacity(0.18), in: Circle())
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: focus) { old, new in
                if let old { commit(old) }
                // 键盘弹出后让正在写的这一行留在可见处
                if let new { withAnimation { proxy.scrollTo(new, anchor: .center) } }
            }
        }
        .background(Palette.cream.ignoresSafeArea())
        .onAppear(perform: load)
        .onDisappear { drafts.keys.forEach(commit) }
    }

    private func section(_ title: String) -> some View {
        Text(title)
            .font(.kid(24, weight: .heavy))
            .foregroundStyle(Palette.ink)
            .padding(.top, 14)
    }

    private func row<Icon: View>(key: String, title: String, detail: String,
                                 @ViewBuilder icon: () -> Icon) -> some View {
        HStack(spacing: 16) {
            icon().frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.kid(20, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(.kid(15, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
            }
            .frame(width: 190, alignment: .leading)
            TextField("比如：去游乐园", text: binding(key))
                .font(.kid(20, weight: .semibold))
                .focused($focus, equals: key)
                .submitLabel(.done)
                .onSubmit { commit(key); focus = nil }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Palette.cream, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(14)
        .softCard(radius: 28)
        .id(key)
    }

    /// 输入时就卡住 20 个字；保存（会去掉首尾空格）留到编辑结束
    private func binding(_ key: String) -> Binding<String> {
        Binding(
            get: { drafts[key] ?? "" },
            set: { drafts[key] = String($0.prefix(PlayerStore.maxNoteLength)) }
        )
    }

    private func load() {
        for medal in Medal.all { drafts["reward.medal.\(medal.id)"] = store.medalReward(medal) }
        for badge in Self.graduateBadges { drafts["reward.badge.\(badge.id)"] = store.badgeReward(badge) }
    }

    private func commit(_ key: String) {
        guard let text = drafts[key], text != store.note(key) else { return }
        store.setNote(key, text)
    }

    private func finish() {
        drafts.keys.forEach(commit)
        dismiss()
    }
}

#Preview {
    RewardNotesEditor()
        .environment(PlayerStore())
}

#Preview("入口") {
    RewardNotesEntryCard()
        .padding()
        .environment(PlayerStore())
        .background(Palette.cream)
}
