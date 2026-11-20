import SwiftUI

// 舞台上的几块板：读题关先选算式（ChoiceBoard）、100 以内加减"数十和一"（TensOnesView），
// 以及"练一练"做完的结算（StoryMixResultOverlay）。

// MARK: - 先选算式

/// "What do we do?"：两三个算式（带一个 ?），点一个。选错的变淡打叉，选对的留在舞台中间。
struct ChoiceBoard: View {
    let choice: StoryChoice
    let chosen: Int?
    let wrong: Set<Int>
    let shake: Int
    let enabled: Bool
    let pick: (Int) -> Void

    var body: some View {
        VStack(spacing: 22) {
            Text(choice.first ? "What do we work out first?" : "Which number sentence fits the story?")
                .font(.kid(22, weight: .bold))
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            if let chosen {
                sentence(choice.options[chosen], size: 56)
                    .padding(.horizontal, 34)
                    .padding(.vertical, 20)
                    .background(Color(hex: 0xE6F2E8), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Palette.sage, lineWidth: 3))
                    .transition(.scale.combined(with: .opacity))
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 18) { cards }
                    VStack(spacing: 14) { cards }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var cards: some View {
        ForEach(Array(choice.options.enumerated()), id: \.offset) { i, calc in
            let isWrong = wrong.contains(i)
            Button { pick(i) } label: {
                sentence(calc, size: 40)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 18)
                    .frame(minWidth: 210)
                    .background(isWrong ? Palette.blush.opacity(0.22) : Palette.cream,
                                in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(isWrong ? Palette.blush : Palette.ink.opacity(0.1), lineWidth: isWrong ? 2.5 : 1.5))
                    .overlay(alignment: .topTrailing) {
                        if isWrong {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(Palette.blush, in: Circle())
                                .offset(x: 8, y: -8)
                        }
                    }
                    .opacity(isWrong ? 0.55 : 1)
            }
            .buttonStyle(PressableStyle(scale: 0.94))
            .disabled(!enabled || isWrong)
            .keyframeAnimator(initialValue: CGFloat(0), trigger: isWrong ? shake : 0) { v, x in
                v.offset(x: x)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(-12, duration: 0.07)
                    CubicKeyframe(10, duration: 0.08)
                    CubicKeyframe(-6, duration: 0.08)
                    CubicKeyframe(0, duration: 0.08)
                }
            }
            .accessibilityLabel(StoryText.spoken(calc.blank))
        }
    }

    private func sentence(_ c: StoryCalc, size: CGFloat) -> some View {
        (Text("\(c.a) \(String(c.op)) \(c.b) = ").foregroundColor(Palette.ink)
            + Text("?").foregroundColor(Palette.honey))
            .font(.kid(size, weight: .heavy))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

// MARK: - 数十和一

/// 100 以内的加减，用"一条十 + 几个一"摆出来（新加坡课本里的 base-ten blocks）。
/// 加法：两个数各摆一行，满十个一就换成一条十；减法：摆出被减数，不够减先把一条十拆成十个一，再划掉要减的。
struct TensOnesView: View {
    let calc: StoryCalc
    let solved: Bool

    private var adding: Bool { calc.op == "+" }
    /// 加法要进位 / 减法要退位
    private var regroup: Bool { adding ? calc.a % 10 + calc.b % 10 >= 10 : calc.a % 10 < calc.b % 10 }

    var body: some View {
        GeometryReader { geo in
            let rows: CGFloat = adding ? 2 : 1
            // 一条十有 10 格高；一行留出数字和间距
            let rowH = (geo.size.height - 92) / rows - 14
            let cell = max(8, min(adding ? 17 : 22, rowH / 10.6, geo.size.width / 52))
            VStack(spacing: 14) {
                if adding {
                    row(label: "\(calc.a)", tens: calc.a / 10, ones: calc.a % 10, cell: cell)
                    row(label: "+ \(calc.b)", tens: calc.b / 10, ones: calc.b % 10, cell: cell)
                } else if regroup {
                    // 拆开一条十：十少一条，一多十个（拆出来的那十个是黄色的）
                    row(label: "\(calc.a)", tens: calc.a / 10 - 1, ones: calc.a % 10 + 10, cell: cell,
                        borrowed: 10, crossTens: calc.b / 10, crossOnes: calc.b % 10)
                } else {
                    row(label: "\(calc.a)", tens: calc.a / 10, ones: calc.a % 10, cell: cell,
                        crossTens: calc.b / 10, crossOnes: calc.b % 10)
                }
                footer
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text(note)
                .font(.kid(18, weight: .bold))
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
            (Text("\(calc.a) \(String(calc.op)) \(calc.b) = ").foregroundColor(Palette.ink)
                + Text(solved ? "\(calc.result)" : "?").foregroundColor(solved ? Color(hex: 0x4E8A5C) : Palette.coral))
                .font(.kid(30, weight: .heavy))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    private var note: String {
        if adding {
            let tens = "Tens: \(calc.a / 10) + \(calc.b / 10).  Ones: \(calc.a % 10) + \(calc.b % 10)."
            return regroup ? tens + "  10 ones make 1 ten!" : tens
        }
        let take = "Take away \(calc.b / 10) tens and \(calc.b % 10) ones."
        return regroup ? "Not enough ones, so change 1 ten for 10 ones. " + take : take
    }

    private func row(label: String, tens: Int, ones: Int, cell: CGFloat,
                     borrowed: Int = 0, crossTens: Int = 0, crossOnes: Int = 0) -> some View {
        HStack(alignment: .bottom, spacing: cell * 0.9) {
            Text(label)
                .font(.kid(30, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 100, alignment: .trailing)
                .padding(.bottom, cell * 3.5)
            HStack(alignment: .bottom, spacing: cell * 0.45) {
                // 划掉的从右边开始
                ForEach(0..<tens, id: \.self) { i in rod(cell, crossed: i >= tens - crossTens) }
            }
            HStack(alignment: .bottom, spacing: cell * 0.3) {
                let columns = (ones + 4) / 5
                ForEach(0..<columns, id: \.self) { col in
                    VStack(spacing: cell * 0.2) {
                        let inCol = min(5, ones - col * 5)
                        ForEach((0..<inCol).reversed(), id: \.self) { r in
                            let k = col * 5 + r
                            // 一的顺序：先是原来的几个，再是拆出来的十个；划掉的从最后面开始
                            cube(cell, borrowed: k >= ones - borrowed, crossed: k >= ones - crossOnes)
                        }
                    }
                }
            }
            .padding(.leading, cell * 0.6)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(tens) tens and \(ones) ones")
    }

    private func rod(_ cell: CGFloat, crossed: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<10, id: \.self) { _ in
                Rectangle()
                    .fill(Palette.sky.opacity(0.55))
                    .overlay(Rectangle().strokeBorder(Palette.sky, lineWidth: 1))
                    .frame(width: cell, height: cell)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cell * 0.25, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cell * 0.25, style: .continuous).strokeBorder(Palette.sky, lineWidth: 2))
        .overlay { if crossed { Cross() } }
        .opacity(crossed ? 0.35 : 1)
    }

    private func cube(_ cell: CGFloat, borrowed: Bool, crossed: Bool) -> some View {
        let tint = borrowed ? Palette.honey : Palette.coral
        return RoundedRectangle(cornerRadius: cell * 0.25, style: .continuous)
            .fill(tint.opacity(0.6))
            .overlay(RoundedRectangle(cornerRadius: cell * 0.25, style: .continuous).strokeBorder(tint, lineWidth: 1.5))
            .frame(width: cell, height: cell)
            .overlay { if crossed { Cross() } }
            .opacity(crossed ? 0.35 : 1)
    }

    /// 划掉：一道斜线
    private struct Cross: View {
        var body: some View {
            GeometryReader { g in
                Path { p in
                    p.move(to: CGPoint(x: 0, y: g.size.height))
                    p.addLine(to: CGPoint(x: g.size.width, y: 0))
                }
                .stroke(Palette.ink.opacity(0.7), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
        }
    }
}

// MARK: - 练一练做完了

struct StoryMixResultOverlay: View {
    let headline: String
    let correct: Int
    let slots: [StoryOutcome.Slot]
    let onAgain: () -> Void
    let onLeave: () -> Void

    @State private var appeared = false
    @State private var lit = 0

    private var newStars: Int { slots.filter { $0 == .new }.count }

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            Color.black.opacity(0.12).ignoresSafeArea()
            if correct == slots.count { ConfettiView() }

            VStack(spacing: 16) {
                Avatar(image: "avatar_owl", fallback: "🦉", tint: Palette.honey, size: 150)
                    .shadow(color: Palette.honey.opacity(0.4), radius: 18, y: 8)
                    .padding(.top, -100)
                Text(correct * 4 >= slots.count * 3 ? "Great practice!" : "Good practice!")
                    .font(.kid(48, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Label(headline, systemImage: "sparkles")
                    .font(.kid(21, weight: .bold))
                    .foregroundStyle(Color(hex: 0x4E8A5C))
                    .multilineTextAlignment(.center)
                Text("Right the first time: \(correct) / \(slots.count)")
                    .font(.kid(23, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                starRow.padding(.vertical, 4)
                Text(newStars > 0 ? "+\(newStars) new stars, each in its own level." : "Every type you practise makes the next level easier!")
                    .font(.kid(19, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                HStack(spacing: 18) {
                    Button { Sound.tap(); onAgain() } label: {
                        Label("Another mix", systemImage: "shuffle")
                    }
                    .buttonStyle(PillButtonStyle(color: Palette.coral, size: 24))
                }
                .padding(.top, 6)
                Button { Sound.tap(); onLeave() } label: {
                    Label("All levels", systemImage: "square.grid.2x2")
                }
                .font(.kid(19, weight: .bold))
                .foregroundStyle(Palette.inkSoft)
            }
            .padding(.horizontal, 56)
            .padding(.bottom, 32)
            .padding(.top, 20)
            .frame(minWidth: 540)
            .softCard(radius: 44)
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)
        }
        .task {
            withAnimation(.spring(duration: 0.5, bounce: 0.4)) { appeared = true }
            var step = 0
            for (i, slot) in slots.enumerated() where slot != .missed {
                try? await Task.sleep(for: .milliseconds(step == 0 ? 500 : 180))
                if slot == .new { Sound.step(min(4 + step, 10)) }
                step += 1
                withAnimation(.spring(duration: 0.45, bounce: 0.6)) { lit = i + 1 }
            }
        }
    }

    private var starRow: some View {
        HStack(spacing: 12) {
            ForEach(Array(slots.enumerated()), id: \.offset) { i, slot in
                let on = i < lit
                ZStack {
                    Image(systemName: "star.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(Palette.ink.opacity(0.08))
                    if slot != .missed {
                        Image(systemName: slot == .new ? "star.fill" : "checkmark.circle.fill")
                            .font(.system(size: slot == .new ? 44 : 30, weight: .bold))
                            .foregroundStyle(slot == .new ? Palette.honey : Palette.sage)
                            .scaleEffect(on ? 1 : 0.3)
                            .opacity(on ? 1 : 0)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(newStars) new stars")
    }
}
