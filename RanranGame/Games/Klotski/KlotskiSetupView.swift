import SwiftUI

/// 华容道的首页：选组、选关（外壳是共用的 PuzzleSetupView），点开一关进 KlotskiPlayView。
/// 调试：-route klotski 直接进这一页；-pack N 选第 N 组；-puzzle <关卡 id> 直接打开一关；-tutorial YES 进教学；
/// 打开一关以后再加 -klotskiDemo hint|solved|solvedHint|over 看提示和过关页。
struct KlotskiSetupView: View {
    @State private var playing: String?

    var body: some View {
        PuzzleSetupView(game: "klotski", title: "华容道", subtitle: "挪一挪、让一让，帮小兔走到出口",
                        accent: KlotskiPlayView.accent, packs: KlotskiCatalog.packs,
                        learnFirst: "先跟猫头鹰老师学会怎么挪木块",
                        thumbnail: { id in KlotskiThumb(layout: KlotskiCatalog.level(id)?.layout ?? "") },
                        open: { playing = $0 })
            .navigationDestination(item: $playing) { id in
                KlotskiPlayView(levelID: id, onSwitch: { playing = $0 })
                    .id(id)
                    .toolbar(.hidden, for: .navigationBar)
            }
    }
}
