import SwiftUI

/// 七巧板的首页：选组、选关（外壳是共用的 PuzzleSetupView），点开一关是 TangramPlayView。
struct TangramSetupView: View {
    @Environment(PlayerStore.self) private var store
    @State private var playing: String?

    var body: some View {
        PuzzleSetupView(game: "tangram", title: "七巧板", subtitle: "七块板子，拼出影子里的样子",
                        accent: TangramStyle.accent, packs: TangramCatalog.packs,
                        learnFirst: "先跟猫头鹰老师认识七块板子",
                        thumbnail: { TangramThumb(level: $0, cleared: store.puzzleCleared("tangram", $0)) },
                        open: { playing = $0 })
            .navigationDestination(item: $playing) { id in
                if let level = TangramCatalog.level(id) {
                    TangramPlayView(level: level, onNext: { playing = $0 })
                        .id(id)
                } else {
                    Color.clear.onAppear { playing = nil }
                }
            }
    }
}

/// 关卡格子里的小图：没过的是黑影，过了的是彩色的板子
struct TangramThumb: View {
    let level: String
    var cleared = false

    var body: some View {
        Canvas { ctx, size in
            guard let f = TangramFigure.find(level) else { return }
            let polys = f.polygons
            let b = TangramGeo.bounds(polys)
            let w = b.max.x - b.min.x, h = b.max.y - b.min.y
            let u = min(size.width / CGFloat(w), size.height / CGFloat(h)) * 0.92
            let ox = (size.width - CGFloat(w) * u) / 2, oy = (size.height + CGFloat(h) * u) / 2
            func pt(_ p: TangramPoint) -> CGPoint {
                CGPoint(x: ox + CGFloat(p.x - b.min.x) * u, y: oy - CGFloat(p.y - b.min.y) * u)
            }
            let inst = TangramStyle.instances(f.pieces.map(\.kind))
            if cleared {
                for (i, poly) in polys.enumerated() {
                    var path = Path()
                    path.addLines(poly.map(pt))
                    path.closeSubpath()
                    ctx.fill(path, with: .color(TangramStyle.color(f.pieces[i].kind, inst[i])))
                    ctx.stroke(path, with: .color(.white.opacity(0.9)), lineWidth: max(0.8, u * 0.05))
                }
            } else {
                var path = Path()
                for poly in polys {
                    path.addLines(poly.map(pt))
                    path.closeSubpath()
                }
                ctx.fill(path, with: .color(TangramStyle.shadow))
            }
        }
    }
}
