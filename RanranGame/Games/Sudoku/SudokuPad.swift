import SwiftUI

/// 数字（水果）按钮：大大的，给小手指按。columns 列排，按钮是正方形，边长 side。
struct SudokuPad: View {
    let n: Int
    let fruit: Bool
    let columns: Int
    let side: CGFloat
    /// 高亮的那一个（选中的格子里的数、"一直用这个"的数、教学里要找的数）
    var highlighted: Int? = nil
    /// "一直用这个"：描一圈粗边
    var sticky: Int? = nil
    /// 已经全部填好的数（变淡）
    var done: Set<Int> = []
    /// 笔记模式：按钮上的数字变小，表示写的是小笔记
    var notesMode = false
    var enabled = true
    let onTap: (Int) -> Void

    var body: some View {
        let rows = (n + columns - 1) / columns
        let gap = max(8, side * 0.1)
        VStack(spacing: gap) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: gap) {
                    ForEach(0..<columns, id: \.self) { c in
                        let v = r * columns + c + 1
                        if v <= n { button(v) } else { Color.clear.frame(width: side, height: side) }
                    }
                }
            }
        }
    }

    private func button(_ v: Int) -> some View {
        let on = highlighted == v
        let isSticky = sticky == v
        return Button {
            onTap(v)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.24, style: .continuous)
                    .fill(on ? SudokuStyle.accent.opacity(0.9) : Palette.paper)
                SudokuToken(value: v, fruit: fruit, size: side * (notesMode ? 0.62 : 0.86), look: on ? .padOn : .pad)
                if notesMode {
                    Image(systemName: "pencil")
                        .font(.system(size: side * 0.18, weight: .bold))
                        .foregroundStyle(on ? .white : Palette.inkSoft)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(side * 0.1)
                }
            }
            .frame(width: side, height: side)
            .overlay(
                RoundedRectangle(cornerRadius: side * 0.24, style: .continuous)
                    .strokeBorder(isSticky ? Palette.coral : Palette.ink.opacity(0.08), lineWidth: isSticky ? max(4, side * 0.06) : 1.5)
            )
            .shadow(color: Color(hex: 0x6B4E2E).opacity(0.12), radius: 6, y: 4)
            .opacity(done.contains(v) ? 0.35 : 1)
        }
        .buttonStyle(PressableStyle(scale: 0.9))
        .disabled(!enabled)
        .accessibilityLabel(SudokuStyle.name(v, fruit: fruit))
    }
}

/// 撤销、擦掉、笔记、提示、重来这一类小按钮：图标 + 字
struct SudokuToolButton: View {
    let icon: String
    let title: String
    var active = false
    var enabled = true
    var height: CGFloat = 70
    let action: () -> Void

    var body: some View {
        Button {
            Sound.tap()
            action()
        } label: {
            // 图标和字并排：字够大，孩子一眼认得出是哪个按钮
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: max(17, height * 0.32), weight: .bold))
                Text(title)
                    .font(.kid(max(17, height * 0.3), weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 6)
            .foregroundStyle(active ? .white : enabled ? Palette.ink : Palette.inkSoft.opacity(0.5))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(active ? AnyShapeStyle(SudokuStyle.accent) : AnyShapeStyle(Palette.paper),
                        in: RoundedRectangle(cornerRadius: height * 0.3, style: .continuous))
            .shadow(color: Color(hex: 0x6B4E2E).opacity(0.10), radius: 6, y: 3)
        }
        .buttonStyle(PressableStyle(scale: 0.93))
        .disabled(!enabled)
        .accessibilityLabel(title)
    }
}
