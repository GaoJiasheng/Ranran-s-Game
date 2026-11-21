import SwiftUI

/// 一组本领奖章排成固定的格子，不滚动。几列几行按地方自动挑：让每枚章尽量大。
struct BadgeGrid: View {
    let badges: [SkillBadge]
    let lens: RewardLens
    /// 好习惯的进度写"天"
    var unit = ""
    let onSelect: (SkillBadge) -> Void

    /// 每格底下名字 + 进度两行文字占的高度
    private static let textHeight: CGFloat = 60

    var body: some View {
        GeometryReader { g in
            let (cols, rows) = Self.layout(count: badges.count, in: g.size)
            let cw = g.size.width / CGFloat(cols), ch = g.size.height / CGFloat(rows)
            let badge = max(56, min(200, cw * 0.78, ch - Self.textHeight - 8))
            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<cols, id: \.self) { c in
                            let i = r * cols + c
                            if i < badges.count {
                                cell(badges[i], badge: badge)
                                    .frame(width: cw, height: ch)
                            } else {
                                Color.clear.frame(width: cw, height: ch)
                            }
                        }
                    }
                }
            }
        }
    }

    /// 挑列数：每格里的章能画多大，就选最大的那种排法
    static func layout(count: Int, in size: CGSize) -> (Int, Int) {
        guard count > 0 else { return (1, 1) }
        var best = (1, count), bestSize: CGFloat = 0
        for cols in 1...min(count, 6) {
            let rows = Int(ceil(Double(count) / Double(cols)))
            let s = min(size.width / CGFloat(cols) * 0.78, size.height / CGFloat(rows) - textHeight - 8)
            // 一样大时少一行更整齐
            if s > bestSize + 0.5 { best = (cols, rows); bestSize = s }
        }
        return best
    }

    private func cell(_ b: SkillBadge, badge: CGFloat) -> some View {
        let p = lens.progress(b)
        let earned = p.complete
        return Button {
            Sound.pop()
            onSelect(b)
        } label: {
            VStack(spacing: 4) {
                SkillBadgeView(badge: b, earned: earned, size: badge)
                Text(b.name)
                    .font(.kid(20, weight: .heavy))
                    .foregroundStyle(earned ? Palette.ink : Palette.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 6)
                BadgeStatusLine(progress: p, tint: b.tint, unit: unit)
                    .frame(height: 22)
            }
        }
        .buttonStyle(PressableStyle(scale: 0.94))
    }
}

/// 一枚本领奖章下面那一行：拿到了是一个勾，没拿到是小进度条 + "2/5"
struct BadgeStatusLine: View {
    let progress: RewardProgress
    let tint: Color
    var unit = ""
    var size: CGFloat = 16

    var body: some View {
        if progress.complete {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text("拿到啦")
            }
            .font(.kid(size, weight: .heavy))
            .foregroundStyle(tint)
        } else {
            HStack(spacing: 6) {
                ProgressBar(fraction: progress.fraction, tint: tint, track: Palette.inkSoft.opacity(0.12))
                    .frame(width: size * 3.4, height: size * 0.5)
                Text("\(progress.done)/\(progress.total)\(unit)")
                    .font(.kid(size, weight: .bold))
                    .foregroundStyle(Palette.inkSoft)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}
