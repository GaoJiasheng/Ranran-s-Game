import SwiftUI
import UniformTypeIdentifiers

/// "我的"：名字、战绩、棋谱（复盘入口）和存档的导入导出。从主页头像进入，不打扰主界面。
struct ProfileView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selected: GameRecord?
    /// 棋谱列表看哪个游戏
    @State private var recordGame = "gomoku"
    @State private var practicing: StoryMistake?
    @State private var exporting = false
    @State private var exportDocument: SaveDocument?
    @State private var importing = false
    @State private var pendingImport: SaveArchive?
    @State private var pendingDelete: GameRecord?
    @State private var toast: String?
    @State private var errorMessage: String?

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            ZStack {
                CreamBackground(accent: Palette.lilac)
                ScrollView {
                    VStack(spacing: 28) {
                        topBar
                        if wide {
                            HStack(alignment: .top, spacing: 28) {
                                VStack(spacing: 28) {
                                    ProfileCard()
                                    MedalSummaryCard()
                                    LessonCupCard()
                                    saveCard
                                }
                                .frame(width: 420)
                                VStack(spacing: 28) {
                                    StoryReportCard { practicing = $0 }
                                    recordsCard
                                }
                            }
                        } else {
                            ProfileCard()
                            MedalSummaryCard()
                            StoryReportCard { practicing = $0 }
                            LessonCupCard()
                            recordsCard
                            saveCard
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 28)
                    .frame(maxWidth: 1300)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)

                if let toast {
                    Text(toast)
                        .font(.kid(20, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Palette.ink.opacity(0.88), in: Capsule())
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 40)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationDestination(item: $selected) { record in
            Group {
                switch record.game {
                case "xiangqi": XiangqiReplayView(record: record)
                case "go": GoReplayView(record: record)
                default: GomokuReplayView(record: record)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .navigationDestination(item: $practicing) { mistake in
            StoryPlayView(mistake: mistake)
                .toolbar(.hidden, for: .navigationBar)
        }
        .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .json,
                      defaultFilename: exportFileName) { result in
            if case .success = result { show("存档已经导出") }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            readImport(result)
        }
        .alert("导入这个存档？", isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
               presenting: pendingImport) { archive in
            Button("取消", role: .cancel) {}
            Button("导入", role: .destructive) {
                withAnimation(.spring(duration: 0.4)) { store.restore(archive) }
                show("存档已经导入")
            }
        } message: { archive in
            Text("存档里是「\(archive.playerName)」的 \(archive.records.count) 盘棋、\(archive.storyMistakes?.count ?? 0) 道错题和 \(archive.totalStars) 颗星星。导入后会替换这台 iPad 上现在的存档。")
        }
        .alert("删除这盘棋？", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
               presenting: pendingDelete) { record in
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                withAnimation(.spring(duration: 0.35)) { store.deleteRecord(record) }
            }
        } message: { _ in
            Text("删除后就不能复盘这盘棋了。")
        }
        .alert("没能导入", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var topBar: some View {
        ZStack {
            Text("我的")
                .font(.kid(40, weight: .heavy))
                .foregroundStyle(Palette.ink)
            HStack {
                RoundIconButton(systemName: "chevron.left", label: "返回") { dismiss() }
                Spacer()
            }
        }
    }

    // MARK: 棋谱

    private var recordsCard: some View {
        let records = store.records(for: recordGame)
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("棋谱")
                    .font(.kid(28, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Picker("游戏", selection: $recordGame) {
                    Text("五子棋").tag("gomoku")
                    Text("象棋").tag("xiangqi")
                    Text("围棋").tag("go")
                }
                .pickerStyle(.segmented)
                .frame(width: 270)
                if !records.isEmpty {
                    Text("\(records.count) 盘")
                        .font(.kid(18, weight: .bold))
                        .foregroundStyle(Palette.inkSoft)
                }
                Spacer()
                if !records.isEmpty {
                    Text("点一盘棋来复盘")
                        .font(.kid(17, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft.opacity(0.85))
                }
            }

            if records.isEmpty {
                VStack(spacing: 14) {
                    ZStack {
                        StoneView(stone: .black, diameter: 54).offset(x: -18, y: 4)
                        StoneView(stone: .white, diameter: 54).offset(x: 18, y: -4)
                    }
                    .frame(height: 70)
                    Text("还没有下完的棋")
                        .font(.kid(22, weight: .bold))
                        .foregroundStyle(Palette.ink.opacity(0.75))
                    Text("每下完一盘都会自动保存在这里，\n可以一步一步复盘，看看哪里下得好")
                        .font(.kid(18, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(records) { record in
                        RecordRow(record: record) {
                            Sound.tap()
                            selected = record
                        }
                        .contextMenu {
                            Button(role: .destructive) { pendingDelete = record } label: {
                                Label("删除这盘棋", systemImage: "trash")
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
            }
        }
        .padding(28)
        .softCard(radius: 40)
    }

    // MARK: 存档

    private var saveCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("存档")
                .font(.kid(28, weight: .heavy))
                .foregroundStyle(Palette.ink)
            Text("名字、星星、进度、棋谱和错题都只保存在这台 iPad 上，不需要登录。换 iPad 或者想备份的时候，可以导出成一个文件。")
                .font(.kid(17, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 14) {
                SaveButton(title: "导出存档", systemName: "square.and.arrow.up", tint: Palette.sage) {
                    exportDocument = SaveDocument(archive: store.makeArchive())
                    exporting = true
                }
                SaveButton(title: "导入存档", systemName: "square.and.arrow.down", tint: Palette.sky) {
                    importing = true
                }
            }
            .padding(.top, 4)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard(radius: 40)
    }

    private var exportFileName: String {
        let day = Date().formatted(.iso8601.year().month().day().dateSeparator(.omitted))
        return "\(store.name)的存档-\(day)"
    }

    private func readImport(_ result: Result<URL, Error>) {
        guard case let .success(url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let archive = try PlayerStore.decoder.decode(SaveArchive.self, from: data)
            guard archive.format == "ranran-save" else { throw CocoaError(.fileReadCorruptFile) }
            pendingImport = archive
        } catch {
            errorMessage = "这个文件不是游戏屋的存档。请选择之前「导出存档」得到的文件。"
        }
    }

    private func show(_ text: String) {
        withAnimation(.spring(duration: 0.4)) { toast = text }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut(duration: 0.3)) { toast = nil }
        }
    }
}

// MARK: - 名字和战绩

private struct ProfileCard: View {
    @Environment(PlayerStore.self) private var store
    @State private var editing = false
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 18) {
            Avatar(image: "avatar_ranran", fallback: "👧", tint: Palette.blush, size: 150)
                .shadow(color: Palette.coral.opacity(0.25), radius: 18, y: 8)

            if editing {
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        TextField("名字", text: $draft)
                            .font(.kid(32, weight: .heavy))
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.center)
                            .focused($focused)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .submitLabel(.done)
                            .onSubmit(commit)
                            .onChange(of: draft) { _, v in
                                if v.count > PlayerStore.maxNameLength { draft = String(v.prefix(PlayerStore.maxNameLength)) }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Palette.cream, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Palette.coral.opacity(0.6), lineWidth: 2.5))
                        Button("好了", action: commit)
                            .buttonStyle(PillButtonStyle(color: Palette.coral, size: 20))
                    }
                    Text("最多 \(PlayerStore.maxNameLength) 个字")
                        .font(.kid(15, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft.opacity(0.8))
                }
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else {
                Button {
                    Sound.tap()
                    draft = store.name
                    withAnimation(.spring(duration: 0.35)) { editing = true }
                    focused = true
                } label: {
                    HStack(spacing: 12) {
                        Text(store.name)
                            .font(.kid(40, weight: .heavy))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Image(systemName: "pencil")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(Palette.inkSoft)
                            .frame(width: 40, height: 40)
                            .background(Palette.cream, in: Circle())
                    }
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("改名字，现在叫\(store.name)")
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            HStack(spacing: 12) {
                StatTile(value: "\(store.totalStars)", label: "颗星星", icon: "star.fill", tint: Palette.honey)
                StatTile(value: "\(gomoku.played)", label: "盘棋", icon: "circle.grid.2x2.fill", tint: Palette.sky)
                StatTile(value: "\(gomoku.wins)", label: "次获胜", icon: "trophy.fill", tint: Palette.coral)
            }
            if gomoku.topLevel > 0 {
                let o = GomokuLevel(gomoku.topLevel).character
                HStack(spacing: 10) {
                    Avatar(image: o.image, fallback: o.emoji, tint: o.tint, size: 40)
                    Text("五子棋最高赢过第 \(gomoku.topLevel) 档 · \(o.name)")
                        .font(.kid(18, weight: .bold))
                        .foregroundStyle(Palette.ink.opacity(0.8))
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .softCard(radius: 40)
    }

    private var gomoku: (played: Int, wins: Int, topLevel: Int) {
        let records = store.records(for: "gomoku")
        let wins = records.filter { $0.playerColor != nil && $0.winner == $0.playerColor }.count
        let top = GomokuLevel.all.last { store.gomokuBest($0) > 0 }?.number ?? 0
        return (records.count, wins, top)
    }

    private func commit() {
        store.rename(draft)
        focused = false
        withAnimation(.spring(duration: 0.35)) { editing = false }
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.kid(28, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(.kid(15, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct SaveButton: View {
    let title: String
    let systemName: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button {
            Sound.tap()
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 26, weight: .bold))
                Text(title)
                    .font(.kid(18, weight: .bold))
            }
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .background(tint.opacity(0.22), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableStyle(scale: 0.93))
    }
}

// MARK: - 一盘棋

private struct RecordRow: View {
    let record: GameRecord
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                leading
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.kid(22, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                    Text(subtitle)
                        .font(.kid(16, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                }
                Spacer(minLength: 8)
                if record.stars > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<record.stars, id: \.self) { _ in
                            Image(systemName: "star.fill").font(.system(size: 13, weight: .bold))
                        }
                    }
                    .foregroundStyle(Palette.honey)
                }
                Text(result.text)
                    .font(.kid(17, weight: .heavy))
                    .foregroundStyle(Palette.ink.opacity(0.8))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(result.tint.opacity(0.35), in: Capsule())
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Palette.inkSoft.opacity(0.5))
            }
            .padding(14)
            .background(Palette.cream.opacity(0.7), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }

    private var xiangqi: Bool { record.game == "xiangqi" }
    private var level: Int? { record.opponentLevel }

    @ViewBuilder private var leading: some View {
        if let level {
            let o = Opponent.forLevel(level)
            Avatar(image: o.image, fallback: o.emoji, tint: o.tint, size: 62)
        } else if xiangqi {
            ZStack {
                XiangqiPieceView(piece: XPiece(.red, .king), diameter: 30).offset(x: -9, y: 3)
                XiangqiPieceView(piece: XPiece(.black, .king), diameter: 30).offset(x: 9, y: -3)
            }
            .frame(width: 62, height: 62)
            .background(Circle().fill(Palette.sky.opacity(0.4)))
            .overlay(Circle().strokeBorder(.white, lineWidth: 4))
        } else {
            ZStack {
                StoneView(stone: .black, diameter: 28).offset(x: -9, y: 3)
                StoneView(stone: .white, diameter: 28).offset(x: 9, y: -3)
            }
            .frame(width: 62, height: 62)
            .background(Circle().fill(Palette.sky.opacity(0.4)))
            .overlay(Circle().strokeBorder(.white, lineWidth: 4))
        }
    }

    private var title: String {
        guard let level else { return "和家人下" }
        return "第 \(level) 档 · \(Opponent.forLevel(level).name)"
    }

    private var subtitle: String {
        var parts = [record.date.shortChinese, xiangqi ? "共 \(record.moves.count) 步" : "共 \(record.moves.count) 手"]
        if let c = record.playerColor {
            parts.append(xiangqi ? (c == 1 ? "执红" : "执黑") : (c == 1 ? "执黑" : "执白"))
        }
        return parts.joined(separator: " · ")
    }

    private var result: (text: String, tint: Color) {
        guard let w = record.winner else { return (xiangqi ? "和棋" : "平局", Palette.sky) }
        guard let me = record.playerColor else {
            return (xiangqi ? (w == 1 ? "红方赢" : "黑方赢") : (w == 1 ? "黑棋赢" : "白棋赢"), Palette.lilac)
        }
        return w == me ? ("赢了", Palette.sage) : ("输了", Palette.blush)
    }
}

// MARK: - 应用题：按题型统计 + 错题本

private struct StoryReportCard: View {
    @Environment(PlayerStore.self) private var store
    let practice: (StoryMistake) -> Void
    @State private var showAll = false
    @AppStorage(StoryLevel.unlockAllKey) private var unlockAll = false

    var body: some View {
        let stats = StorySchema.allCases.map { ($0, store.storyStats($0)) }.filter { $0.1.right + $0.1.wrong > 0 }
        let mistakes = store.storyMistakes.sorted { !$0.fixed && $1.fixed }
        let shown = showAll ? mistakes : Array(mistakes.prefix(5))
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("加减乘除 · 应用题")
                    .font(.kid(28, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                if let summary = summary(stats) {
                    Text(summary)
                        .font(.kid(18, weight: .bold))
                        .foregroundStyle(Palette.inkSoft)
                }
                Spacer()
            }

            if stats.isEmpty {
                Text("做过「加减乘除」以后，这里会按题型显示做对、做错了多少，做错的题也会收进错题本。")
                    .font(.kid(18, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 10)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                    ForEach(stats, id: \.0) { schema, s in
                        let op = store.storyChoiceStats(schema)
                        SchemaTile(schema: schema, right: s.right, wrong: s.wrong,
                                   opRight: op.right, opWrong: op.wrong,
                                   weakest: schema == weakest(stats))
                    }
                }
            }

            if !mistakes.isEmpty {
                HStack(alignment: .firstTextBaseline) {
                    Text("错题本")
                        .font(.kid(22, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                    let open = mistakes.filter { !$0.fixed }.count
                    if open > 0 {
                        Text("\(open) 道待练")
                            .font(.kid(16, weight: .bold))
                            .foregroundStyle(Palette.coral)
                    }
                    Spacer()
                    Text("点一道题，再做一遍")
                        .font(.kid(16, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft.opacity(0.85))
                }
                .padding(.top, 4)
                LazyVStack(spacing: 10) {
                    ForEach(shown) { m in
                        MistakeRow(mistake: m, player: store.name) {
                            Sound.tap()
                            practice(m)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                withAnimation(.spring(duration: 0.35)) { store.deleteMistake(m.id) }
                            } label: {
                                Label("从错题本删除", systemImage: "trash")
                            }
                        }
                    }
                }
                if mistakes.count > 5 {
                    Button {
                        Sound.tap()
                        withAnimation(.spring(duration: 0.4)) { showAll.toggle() }
                    } label: {
                        Text(showAll ? "收起" : "看全部 \(mistakes.count) 道")
                            .font(.kid(17, weight: .bold))
                            .foregroundStyle(Palette.inkSoft)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }

            // 平时要前一关过关（第一下就答对 75%）才能进下一关；家长可以全部打开
            Toggle(isOn: $unlockAll) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("数学关卡全部解锁")
                        .font(.kid(19, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                    Text("关掉时，前一关过关（第一次就答对 75%）才能进下一关")
                        .font(.kid(15, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Palette.sage)
            .padding(.top, 4)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard(radius: 40)
    }

    private func summary(_ stats: [(StorySchema, (right: Int, wrong: Int))]) -> String? {
        let right = stats.reduce(0) { $0 + $1.1.right }, total = stats.reduce(0) { $0 + $1.1.right + $1.1.wrong }
        guard total > 0 else { return nil }
        var text = "答了 \(total) 题 · 一次就对 \(Int((Double(right) / Double(total) * 100).rounded()))%"
        // 读题关里先选算式：选对的比例（和算对分开看）
        let ops = StorySchema.allCases.map { store.storyChoiceStats($0) }
        let opRight = ops.reduce(0) { $0 + $1.right }, opTotal = ops.reduce(0) { $0 + $1.right + $1.wrong }
        if opTotal > 0 { text += " · 列式选对 \(Int((Double(opRight) / Double(opTotal) * 100).rounded()))%" }
        return text
    }

    /// 错得最多（且至少做过 3 题）的题型，提示家长重点练
    private func weakest(_ stats: [(StorySchema, (right: Int, wrong: Int))]) -> StorySchema? {
        stats.filter { $0.1.right + $0.1.wrong >= 3 && $0.1.wrong > 0 }
            .min { Double($0.1.right) / Double($0.1.right + $0.1.wrong) < Double($1.1.right) / Double($1.1.right + $1.1.wrong) }?.0
    }
}

private struct SchemaTile: View {
    let schema: StorySchema
    let right: Int
    let wrong: Int
    /// 读题关里先选算式：第一下选对 / 选错几次（和算错分开看：选错 = 不知道该加还是该减）
    let opRight: Int
    let opWrong: Int
    let weakest: Bool

    /// 选算式错得多：做过 3 次以上，错了三分之一以上
    private var opWeak: Bool { opRight + opWrong >= 3 && opWrong * 3 >= opRight + opWrong }

    var body: some View {
        let total = max(right + wrong, 1)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(schema.zh)
                        .font(.kid(19, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                    Text(schema.title)
                        .font(.kid(13, weight: .bold))
                        .foregroundStyle(Palette.inkSoft)
                }
                Spacer()
                if opWeak {
                    Text("常选错算法")
                        .font(.kid(13, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Palette.lilac, in: Capsule())
                } else if weakest {
                    Text("多练练")
                        .font(.kid(13, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Palette.coral, in: Capsule())
                }
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.blush.opacity(0.55))
                    Capsule().fill(Palette.sage)
                        .frame(width: g.size.width * CGFloat(right) / CGFloat(total))
                }
            }
            .frame(height: 10)
            Text("对 \(right) 题 · 错 \(wrong) 题")
                .font(.kid(15, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
            if opRight + opWrong > 0 {
                Text(opWrong > 0 ? "列式：选对 \(opRight) 次 · 选错 \(opWrong) 次" : "列式：选对 \(opRight) 次")
                    .font(.kid(14, weight: .semibold))
                    .foregroundStyle(opWeak ? Color(hex: 0x7D68B8) : Palette.inkSoft)
            }
        }
        .padding(14)
        .background(schema.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct MistakeRow: View {
    let mistake: StoryMistake
    let player: String
    let action: () -> Void

    var body: some View {
        let p = mistake.problem
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(p.schema.zh)
                            .font(.kid(14, weight: .heavy))
                            .foregroundStyle(Palette.ink.opacity(0.8))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(p.schema.tint.opacity(0.35), in: Capsule())
                        Text(mistake.date.shortChinese)
                            .font(.kid(14, weight: .semibold))
                            .foregroundStyle(Palette.inkSoft)
                    }
                    Text(p.sentences.map { StoryText.plain($0.text, p, player: player) }.joined(separator: " "))
                        .font(.kid(18, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Text(mistake.step == 0 && p.middle != nil
                         ? "第 (a) 问答 \(mistake.answer) · 正确 \(p.middle!.answer)（最后答案 \(p.answer)）"
                         : "当时答 \(mistake.answer) · 正确答案 \(p.answer)")
                        .font(.kid(15, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                }
                Spacer(minLength: 8)
                if mistake.fixed {
                    Label("练会了", systemImage: "checkmark.circle.fill")
                        .font(.kid(15, weight: .heavy))
                        .foregroundStyle(Color(hex: 0x4E8A5C))
                } else {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Palette.coral)
                        .frame(width: 44, height: 44)
                        .background(Palette.coral.opacity(0.14), in: Circle())
                }
            }
            .padding(14)
            .background(Palette.cream.opacity(0.7), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .opacity(mistake.fixed ? 0.7 : 1)
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }
}
