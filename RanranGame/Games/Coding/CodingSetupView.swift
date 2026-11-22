import SwiftUI

/// 编程的首页：选组、选关（外壳是共用的 PuzzleSetupView），点开一关进 CodingPlayView。
/// 调试（都只在 DEBUG 里）：-route coding 进这一页；-codingLevel seq03 直接打开一关（-puzzle seq03 也行）；
/// 打开一关以后：-codingProgram "3[R U] R" 预先排好程序；-codingRun YES 打开就跑；-codingStep 3 先跑 3 步停住；
/// -codingDone YES 直接摆出过关的结算页；-codingFail bump|end|dizzy|garden|home 直接摆出没过关的样子；
/// -codingHint 1|2 打开就按一下 / 两下提示。教学：-route coding -tutorial YES -lesson <课的 id>。
struct CodingSetupView: View {
    @State private var playing: String?

    var body: some View {
        PuzzleSetupView(game: "coding", title: "编程", subtitle: "排好指令，让小兔照着走",
                        accent: CodingPlayView.accent, packs: CodingCatalog.packs,
                        learnFirst: "先跟猫头鹰老师学会怎么排指令",
                        thumbnail: { id in CodingThumb(level: CodingCatalog.level(id)) },
                        open: { playing = $0 })
            .navigationDestination(item: $playing) { id in
                CodingPlayView(levelID: id, onSwitch: { playing = $0 })
                    .id(id)
                    .toolbar(.hidden, for: .navigationBar)
            }
            .onAppear {
                #if DEBUG
                if playing == nil, let id = UserDefaults.standard.string(forKey: "codingLevel"), CodingCatalog.level(id) != nil {
                    playing = id
                }
                #endif
            }
    }
}
