import SwiftUI

/// 「学到哪了」：给家长看的目标进度。每个科目一块，棋类赢下目标档位、数学通过全部关卡就算「学会了」。
struct LearningProgressCard: View {
    /// 宽屏时 2×2，竖屏时一列
    var wide: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("学到哪了")
                    .font(.kid(28, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text("棋类赢下目标那一档就算学会，加减乘除要通过全部关卡。")
                    .font(.kid(17, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
            }
            let columns = Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top), count: wide ? 2 : 1)
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Subjects.all) { SubjectTile(subject: $0) }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard(radius: 40)
    }
}

/// 一个科目的小卡：名字、总进度条、每条目标、星星数
private struct SubjectTile: View {
    @Environment(PlayerStore.self) private var store
    let subject: Subject

    var body: some View {
        let progress = store.progress(of: subject)
        let learned = store.graduated(subject)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(subject.name)
                    .font(.kid(22, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 4)
                Label("\(store.stars(in: subject))", systemImage: "star.fill")
                    .font(.kid(16, weight: .bold))
                    .foregroundStyle(Palette.honey)
            }
            HStack(spacing: 10) {
                // 进度条和奖章墙上用的是同一个（Views/Rewards/ProgressPieces.swift）
                ProgressBar(fraction: progress.fraction, tint: subject.tint, track: Palette.ink.opacity(0.08))
                    .frame(height: 12)
                Text("\(Int((progress.fraction * 100).rounded()))%")
                    .font(.kid(16, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .monospacedDigit()
            }
            if learned {
                Label("学会了：\(subject.graduateName)", systemImage: "checkmark.seal.fill")
                    .font(.kid(16, weight: .heavy))
                    .foregroundStyle(Palette.sage)
            }
            VStack(alignment: .leading, spacing: 5) {
                ForEach(subject.goals(store)) { goal in
                    HStack(spacing: 8) {
                        Image(systemName: goal.progress.complete ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(goal.progress.complete ? Palette.sage : Palette.inkSoft.opacity(0.5))
                        Text(goal.title)
                            .lineLimit(2)
                        Spacer(minLength: 4)
                        Text("\(goal.progress.done)/\(goal.progress.total)")
                            .monospacedDigit()
                            .foregroundStyle(Palette.inkSoft)
                    }
                    .font(.kid(15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(subject.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

#Preview {
    LearningProgressCard()
        .padding()
        .frame(width: 800)
        .environment(PlayerStore())
        .background(Palette.cream)
}
