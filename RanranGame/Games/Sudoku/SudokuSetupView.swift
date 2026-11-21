import SwiftUI

/// 数独的首页：五组关卡（共用的 PuzzleSetupView），点一关进 SudokuPlayView。
struct SudokuSetupView: View {
    @State private var playing: String?

    var body: some View {
        PuzzleSetupView(game: "sudoku", title: "数独", subtitle: "每一行、每一列、每一宫都不重复",
                        accent: SudokuStyle.accent, packs: SudokuCatalog.packs,
                        learnFirst: "先跟猫头鹰老师学会怎么填",
                        thumbnail: { SudokuThumb(level: $0) },
                        open: { playing = $0 })
            .navigationDestination(item: $playing) { level in
                SudokuPlayView(levelID: level, onNext: { playing = $0 })
                    .id(level)
            }
    }
}
