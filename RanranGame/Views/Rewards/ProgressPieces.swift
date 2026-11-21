import SwiftUI

// 进度的几块小零件：圆环、细长条、毕业小印章、主页卡片上的"学会了多少"。

/// 一个圆环进度。线宽按大小算，24 到 260 都好看。
struct ProgressRing<Center: View>: View {
    let fraction: Double
    var tint: Color
    var lineWidth: CGFloat? = nil
    @ViewBuilder var center: () -> Center

    var body: some View {
        GeometryReader { g in
            let d = min(g.size.width, g.size.height)
            let w = lineWidth ?? max(4, d * 0.085)
            ZStack {
                Circle().stroke(tint.opacity(0.16), lineWidth: w)
                Circle()
                    .trim(from: 0, to: max(0.0001, min(fraction, 1)))
                    .stroke(LinearGradient(colors: [tint.mixed(.white, 0.25), tint], startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: w, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .opacity(fraction > 0 ? 1 : 0)
                center()
            }
            .padding(w / 2)
            .frame(width: d, height: d)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.spring(duration: 0.7), value: fraction)
    }
}

extension ProgressRing where Center == EmptyView {
    init(fraction: Double, tint: Color, lineWidth: CGFloat? = nil) {
        self.init(fraction: fraction, tint: tint, lineWidth: lineWidth) { EmptyView() }
    }
}

/// 一条胶囊进度条
struct ProgressBar: View {
    let fraction: Double
    var tint: Color
    var track: Color = Palette.cream

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                if fraction > 0 {
                    Capsule()
                        .fill(LinearGradient(colors: [tint.mixed(.white, 0.3), tint], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(g.size.height, g.size.width * min(fraction, 1)))
                }
            }
        }
        .animation(.spring(duration: 0.6), value: fraction)
    }
}

/// 学会了的小印章：金色波浪边 + 学士帽
struct GraduateSeal: View {
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Image(systemName: "seal.fill")
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xF7D77F), Color(hex: 0xD99A30)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: Color(hex: 0xB07A20).opacity(0.35), radius: size * 0.08, y: size * 0.06)
            Image(systemName: "graduationcap.fill")
                .font(.system(size: size * 0.42, weight: .heavy))
                .foregroundStyle(.white)
                .shadow(color: Color(hex: 0xB07A20).opacity(0.6), radius: 0, y: size * 0.025)
        }
        .frame(width: size * 1.1, height: size * 1.1)
    }
}

/// 百分比文字：0.375 → "38%"
func percentText(_ fraction: Double) -> String {
    // 没做到 100% 就不显示 100%，免得冉冉以为已经学会了
    let p = Int((fraction * 100).rounded())
    return "\(fraction < 1 ? min(p, 99) : 100)%"
}

/// 主页游戏卡片上的一枚小胶囊：圆环 + "学会 38%"；学会了换成金色印章 + 毕业的名字。
struct SubjectProgressPill: View {
    let subject: Subject
    @Environment(PlayerStore.self) private var store
    var height: CGFloat = 50
    /// 地方小的时候，学会了只写"学会啦"，不写毕业的名字
    var compact = false

    var body: some View {
        let lens = store.rewards
        let p = lens.progress(of: subject)
        let done = lens.graduated(subject)
        HStack(spacing: height * 0.18) {
            if done {
                GraduateSeal(size: height * 0.72)
                Text(compact ? "学会啦" : subject.graduateName)
                    .font(.kid(height * 0.38, weight: .heavy))
                    .foregroundStyle(Color(hex: 0x9A6A1E))
            } else {
                ProgressRing(fraction: p.fraction, tint: subject.tint)
                    .frame(width: height * 0.7, height: height * 0.7)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("学会")
                        .font(.kid(height * 0.32, weight: .bold))
                        .foregroundStyle(Palette.inkSoft)
                    Text(percentText(p.fraction))
                        .font(.kid(height * 0.42, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                        .monospacedDigit()
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.leading, height * 0.16)
        .padding(.trailing, height * 0.34)
        .frame(height: height)
        .background(Capsule().fill(done ? Color(hex: 0xFFF4D6) : Palette.paper.opacity(0.9)))
        .overlay(Capsule().strokeBorder(done ? Color(hex: 0xE9C26A).opacity(0.7) : .white.opacity(0.9), lineWidth: 2))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(done ? "已经学会了，\(subject.graduateName)" : "\(subject.name)学会了百分之\(Int(p.fraction * 100))")
    }
}

#Preview("进度零件") {
    VStack(spacing: 20) {
        ForEach(Subjects.all) { SubjectProgressPill(subject: $0) }
        SubjectProgressPill(subject: Subjects.all[0], height: 40)
        HStack {
            ProgressRing(fraction: 0.62, tint: Palette.coral) { Text("62%").font(.kid(30, weight: .heavy)) }
                .frame(width: 140, height: 140)
            GraduateSeal(size: 80)
        }
        ProgressBar(fraction: 0.4, tint: Palette.sage).frame(width: 300, height: 14)
    }
    .padding()
    .background(Palette.cream)
    .environment(PlayerStore())
}
