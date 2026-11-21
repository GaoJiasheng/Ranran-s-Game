import SwiftUI

/// 占位：数独的首页。真正的版本要换掉小图和打开一关之后的页面，外壳（PuzzleSetupView）不用动。
struct SudokuSetupView: View {
    @Environment(PlayerStore.self) private var store
    @State private var playing: String?
    @State private var result: PuzzleResult?

    var body: some View {
        PuzzleSetupView(game: "sudoku", title: "数独", subtitle: "每一行、每一列、每一宫都不重复",
                        accent: Color(hex: 0xD9973A), packs: SudokuCatalog.packs,
                        learnFirst: "先跟猫头鹰老师学会怎么填",
                        thumbnail: { _ in
                            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.honey.opacity(0.25))
                        },
                        open: { playing = $0 })
            .navigationDestination(item: $playing) { level in
                ZStack {
                    CreamBackground()
                    Text("第 \(level) 关").font(.kid(40, weight: .heavy))
                    if let result {
                        PuzzleDoneOverlay(result: result, stars: [("过关", true), ("没用提示", result.earned >= 2), ("没填错", result.earned >= 3)],
                                          accent: Color(hex: 0xD9973A), detail: "占位：真正的游戏还没做",
                                          onNext: { playing = nil }, onReplay: { self.result = nil }, onLeave: { playing = nil })
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
                .onAppear { result = store.recordPuzzle(game: "sudoku", level: level, earned: 2) }
            }
    }
}
