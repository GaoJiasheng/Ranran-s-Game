import SwiftUI

/// 排成一行看的程序（教学 choose 题的选项）：不能点、没有空坑；绝招那一栏接在主程序后面（"★ =" 后面跟着它的积木）。
/// 尺寸和 CodingLayout.inlineSize 一一对应。
struct CodingInlineProgram: View {
    let program: CodingProgram
    let u: CGFloat

    private var gap: CGFloat { u * CGFloat(CodingLayout.gap) }

    var body: some View {
        HStack(alignment: .center, spacing: gap) {
            ForEach(Array(program.tracks.enumerated()), id: \.offset) { t, list in
                if t == 0 || !list.isEmpty {
                    if t > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: CodingPaint.procSymbol(t == 1 ? .star : .diamond))
                                .font(.system(size: u * 0.34, weight: .black))
                            Text("=").font(.kid(u * 0.34, weight: .black))
                        }
                        .foregroundStyle(CodingPaint.color(.call(t == 1 ? .star : .diamond)))
                        .frame(width: u * 0.8)
                        .padding(.leading, max(0, u * 0.4 - gap))
                    }
                    ForEach(Array(list.enumerated()), id: \.offset) { _, b in CodingMiniBlock(block: b, u: u) }
                }
            }
        }
    }
}

struct CodingMiniBlock: View {
    let block: CodingBlock
    let u: CGFloat

    var body: some View {
        if let body = block.body {
            let color = CodingPaint.color(block.piece)
            HStack(spacing: u * CGFloat(CodingLayout.gap)) {
                CodingFace(color: color, size: CGSize(width: u * CGFloat(CodingLayout.header), height: u), radius: u * 0.2) {
                    CodingHeaderGlyph(block: block, u: u)
                }
                ForEach(Array(body.enumerated()), id: \.offset) { _, b in CodingMiniBlock(block: b, u: u) }
            }
            .padding(u * CGFloat(CodingLayout.pad))
            .background(RoundedRectangle(cornerRadius: u * 0.26, style: .continuous).fill(color.opacity(0.22)))
            .overlay(RoundedRectangle(cornerRadius: u * 0.26, style: .continuous).strokeBorder(color, lineWidth: max(2, u * 0.05)))
        } else {
            CodingTile(piece: block.piece, u: u)
        }
    }
}
