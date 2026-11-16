import SwiftUI

/// 五子棋首页：选对手、选谁先下。
struct GomokuSetupView: View {
    @Environment(StarStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("gomoku.humanFirst") private var humanFirst = true
    @State private var config: GomokuConfig?
    @State private var appeared = false

    var body: some View {
        ZStack {
            CreamBackground(accent: Palette.honey)

            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        RoundIconButton(systemName: "house.fill", label: "回主页") { dismiss() }
                        Spacer()
                        StarCounter()
                    }

                    VStack(spacing: 12) {
                        Text("五子棋")
                            .font(.kid(80, weight: .heavy))
                            .foregroundStyle(Palette.ink)
                        Text("横着、竖着、斜着，谁先连成五颗谁就赢")
                            .font(.kid(24, weight: .semibold))
                            .foregroundStyle(Palette.inkSoft)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 40)

                    Text("选一位小伙伴来比赛")
                        .font(.kid(26, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .padding(.bottom, 64)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 24)], spacing: 80) {
                        ForEach(Array(Opponent.allCases.enumerated()), id: \.element) { i, o in
                            OpponentCard(opponent: o, wins: store.count("gomoku.win.\(o.rawValue)")) {
                                config = GomokuConfig(mode: .vsAI(o), humanFirst: humanFirst)
                            }
                            .offset(y: appeared ? 0 : 40)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(duration: 0.6, bounce: 0.35).delay(Double(i) * 0.07), value: appeared)
                        }
                        FamilyCard {
                            config = GomokuConfig(mode: .twoPlayer, humanFirst: true)
                        }
                        .offset(y: appeared ? 0 : 40)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(duration: 0.6, bounce: 0.35).delay(0.21), value: appeared)
                    }

                    FirstMovePicker(humanFirst: $humanFirst)
                        .padding(.top, 48)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 28)
                .frame(maxWidth: 1240)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear { appeared = true }
        .navigationDestination(item: $config) { c in
            GomokuGameView(config: c)
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct OpponentCard: View {
    let opponent: Opponent
    let wins: Int
    let action: () -> Void

    var body: some View {
        Button {
            Sound.tap()
            action()
        } label: {
            VStack(spacing: 10) {
                Avatar(image: opponent.image, fallback: opponent.emoji, tint: opponent.tint, size: 150)
                    .padding(.top, -64)
                Text(opponent.name)
                    .font(.kid(32, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text(opponent.levelTag)
                    .font(.kid(18, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(opponent.tint.opacity(0.95), in: Capsule())
                HStack(spacing: 4) {
                    Text("赢了得")
                    ForEach(0..<opponent.stars, id: \.self) { _ in
                        Image(systemName: "star.fill").foregroundStyle(Palette.honey)
                    }
                }
                .font(.kid(17, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
                .padding(.top, 4)
                Text(wins > 0 ? "已经赢过 \(wins) 次" : "还没赢过哦")
                    .font(.kid(16, weight: .medium))
                    .foregroundStyle(Palette.inkSoft.opacity(0.8))
            }
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [Palette.paper, opponent.tint.opacity(0.22)], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 36, style: .continuous)
            )
            .softCard(radius: 36, fill: .clear)
        }
        .buttonStyle(PressableStyle())
    }
}

private struct FamilyCard: View {
    let action: () -> Void

    var body: some View {
        Button {
            Sound.tap()
            action()
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    StoneView(stone: .black, diameter: 74).offset(x: -24, y: 6)
                    StoneView(stone: .white, diameter: 74).offset(x: 24, y: -6)
                }
                .frame(width: 150, height: 150)
                .background(Circle().fill(RadialGradient(colors: [Palette.sky.opacity(0.35), Palette.sky.opacity(0.7)],
                                                         center: .init(x: 0.4, y: 0.3), startRadius: 0, endRadius: 105)))
                .overlay(Circle().strokeBorder(.white, lineWidth: 7))
                .padding(.top, -64)
                Text("和家人下")
                    .font(.kid(32, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text("双人")
                    .font(.kid(18, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Palette.sky, in: Capsule())
                Text("在同一台 iPad 上\n轮流下棋")
                    .font(.kid(17, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [Palette.paper, Palette.sky.opacity(0.22)], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 36, style: .continuous)
            )
            .softCard(radius: 36, fill: .clear)
        }
        .buttonStyle(PressableStyle())
    }
}

/// "我先下 / 让对手先"切换。
private struct FirstMovePicker: View {
    @Binding var humanFirst: Bool
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 18) {
            Text("和电脑下时")
                .font(.kid(20, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
            HStack(spacing: 0) {
                option(title: "我先下", stone: .black, selected: humanFirst) { humanFirst = true }
                option(title: "让对手先", stone: .white, selected: !humanFirst) { humanFirst = false }
            }
            .padding(6)
            .softCard(radius: 30)
        }
    }

    private func option(title: String, stone: Stone, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Sound.tap()
            withAnimation(.spring(duration: 0.35, bounce: 0.3)) { action() }
        } label: {
            HStack(spacing: 10) {
                StoneView(stone: stone, diameter: 22)
                Text(title).font(.kid(21, weight: .bold))
            }
            .foregroundStyle(selected ? .white : Palette.ink)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background {
                if selected {
                    Capsule().fill(Palette.ink).matchedGeometryEffect(id: "sel", in: ns)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
