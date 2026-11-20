import SwiftUI

/// 「我的」里给家长看的：三门棋的教学各学到哪里、每课拿了什么小奖杯、哪几课还不太稳。
struct LessonCupCard: View {
    @Environment(PlayerStore.self) private var store
    private let courses = ["gomoku", "xiangqi", "go"].compactMap { TutorialCourse.bundled[$0] }

    private static let names = ["gomoku": "五子棋", "xiangqi": "象棋", "go": "围棋"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("教学小奖杯")
                    .font(.kid(28, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text("每一课的题都一次做对是金杯，大部分一次做对是银杯，学完是铜杯")
                    .font(.kid(15, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(courses, id: \.game) { course in
                CourseCupRow(course: course, name: Self.names[course.game] ?? course.title)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard(radius: 40)
    }
}

private struct CourseCupRow: View {
    @Environment(PlayerStore.self) private var store
    let course: TutorialCourse
    let name: String

    var body: some View {
        let cups = store.cups(course)
        let counts = store.cupCounts(course)
        // 学完了但还没拿金杯的课：先铜后银，按课程顺序
        let shaky = LessonCup.allCases.flatMap { c in course.lessons.filter { cups[$0.id] == c && c < .gold } }
        let practised = course.lessons.reduce(0) { $0 + store.practiceCount(course.game, $1.id) }
        let reviews = store.reviewCount(course.game)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(name)
                    .font(.kid(22, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text("学会 \(cups.count) / \(course.lessons.count) 课")
                    .font(.kid(16, weight: .bold))
                    .foregroundStyle(Palette.inkSoft)
                    .monospacedDigit()
                Spacer(minLength: 0)
            }
            HStack(spacing: 14) {
                ForEach(LessonCup.allCases.reversed(), id: \.self) { c in
                    HStack(spacing: 4) {
                        CupBadge(cup: c, earned: counts[c, default: 0] > 0, size: 24)
                        Text("\(counts[c, default: 0])")
                            .font(.kid(17, weight: .heavy))
                            .foregroundStyle(Palette.ink.opacity(counts[c, default: 0] > 0 ? 0.85 : 0.35))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(c.name) \(counts[c, default: 0]) 个")
                }
            }
            if cups.isEmpty {
                Text("还没开始学")
                    .font(.kid(15, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft.opacity(0.8))
            } else {
                if !shaky.isEmpty {
                    Text("还不太稳，可以去「练一练」：")
                        .font(.kid(15, weight: .bold))
                        .foregroundStyle(Palette.coral)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(shaky) { l in
                            HStack(spacing: 6) {
                                CupBadge(cup: cups[l.id]!, size: 22)
                                Text(l.title)
                                    .font(.kid(15, weight: .bold))
                                    .foregroundStyle(Palette.ink.opacity(0.85))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(cups[l.id]!.tint.opacity(0.14), in: Capsule())
                        }
                    }
                }
                Text(activity(practised: practised, reviews: reviews))
                    .font(.kid(14, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft.opacity(0.85))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.cream.opacity(0.7), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func activity(practised: Int, reviews: Int) -> String {
        var parts = ["练一练 \(practised) 次", "复习 \(reviews) 次"]
        if let d = store.daysSinceReview(course.game) {
            parts.append(d == 0 ? "今天复习过" : "上次复习是 \(d) 天前")
        }
        return parts.joined(separator: " · ")
    }
}
