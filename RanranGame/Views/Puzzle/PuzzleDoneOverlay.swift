import SwiftUI

/// 解谜类游戏过了一关的结算页：三颗星分别是怎么来的、这次发了几颗、接下来去哪。
/// 盖在游戏画面上面用（放在 ZStack 最上层）。先调 store.recordPuzzle 拿到 result，再把它显示出来。
///
///     PuzzleDoneOverlay(result: result, stars: [("过关", true), ("没用提示", !usedHint), ("没填错", mistakes == 0)],
///                       accent: tint, detail: "用了 3 分 20 秒", onNext: next, onReplay: restart, onLeave: { dismiss() })
struct PuzzleDoneOverlay: View {
    let result: PuzzleResult
    /// 三颗星各是怎么来的，按顺序三项。got 里 true 的个数应该等于 result.earned。
    let stars: [(label: String, got: Bool)]
    let accent: Color
    var title = "过关啦！"
    /// 标题下面的一行小字，比如"用了 28 步，最少 24 步"
    var detail: String? = nil
    /// 「下一关」；没有下一关（或者还没解锁）传 nil
    let onNext: (() -> Void)?
    let onReplay: () -> Void
    let onLeave: () -> Void

    @State private var appeared = false
    @State private var lit = 0
    @State private var payIn = false

    private var payText: String {
        if result.paid > 0 { return "+\(result.paid) 颗星星" }
        return result.best >= 3 ? "这一关的三颗星都拿到啦" : "这一关的星星拿过啦，再试试拿满三颗"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.35 : 0)
                .ignoresSafeArea()
            if result.paid > 0 || result.first { ConfettiView() }
            VStack(spacing: 18) {
                Text(title)
                    .font(.kid(46, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                if let detail {
                    Text(detail)
                        .font(.kid(19, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center)
                }
                HStack(alignment: .top, spacing: 22) {
                    ForEach(Array(stars.prefix(3).enumerated()), id: \.offset) { i, s in
                        let on = s.got && i < lit
                        VStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 70, weight: .bold))
                                .foregroundStyle(on ? AnyShapeStyle(LinearGradient(colors: [Palette.honey, Palette.coral],
                                                                                    startPoint: .top, endPoint: .bottom))
                                                    : AnyShapeStyle(Palette.ink.opacity(0.10)))
                                .scaleEffect(on ? 1 : 0.82)
                                .shadow(color: on ? Palette.honey.opacity(0.5) : .clear, radius: 12, y: 4)
                            Text(s.label)
                                .font(.kid(17, weight: .bold))
                                .foregroundStyle(s.got ? Palette.ink : Palette.inkSoft.opacity(0.7))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(width: 130)
                    }
                }
                .padding(.vertical, 4)
                HStack(spacing: 8) {
                    if result.paid > 0 {
                        Image(systemName: "star.fill").foregroundStyle(Palette.honey)
                    }
                    Text(payText)
                }
                .font(.kid(20, weight: .heavy))
                .foregroundStyle(result.paid > 0 ? Palette.ink : Palette.inkSoft)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(result.paid > 0 ? Palette.honey.opacity(0.25) : Palette.cream))
                .scaleEffect(payIn ? 1 : 0.6)
                .opacity(payIn ? 1 : 0)

                VStack(spacing: 14) {
                    if let onNext {
                        Button(action: onNext) {
                            Label("下一关", systemImage: "arrow.right").labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(PillButtonStyle(color: Palette.coral, size: 26))
                    }
                    HStack(spacing: 14) {
                        secondary("再玩一次", "arrow.counterclockwise", onReplay)
                        secondary("选关卡", "square.grid.2x2.fill", onLeave)
                    }
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 34)
            .frame(maxWidth: 560)
            .softCard(radius: 44)
            .padding(24)
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
        }
        .task {
            Sound.win()
            withAnimation(.spring(duration: 0.5, bounce: 0.35)) { appeared = true }
            for i in 1...3 {
                try? await Task.sleep(for: .milliseconds(320))
                if stars.indices.contains(i - 1), stars[i - 1].got { Sound.sparkle() }
                withAnimation(.spring(duration: 0.4, bounce: 0.5)) { lit = i }
            }
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.spring(duration: 0.45, bounce: 0.4)) { payIn = true }
        }
    }

    private func secondary(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button {
            Sound.tap()
            action()
        } label: {
            Label(title, systemImage: icon)
                .font(.kid(20, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(Palette.cream, in: Capsule())
                .overlay(Capsule().strokeBorder(Palette.ink.opacity(0.08), lineWidth: 1.5))
        }
        .buttonStyle(PressableStyle(scale: 0.94))
    }
}
