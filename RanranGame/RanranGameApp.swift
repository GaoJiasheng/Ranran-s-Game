import SwiftUI

@main
struct RanranGameApp: App {
    @State private var store = PlayerStore()

    init() {
        Sound.prepare()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
                .preferredColorScheme(.light)
                .persistentSystemOverlays(.hidden)
        }
    }
}
