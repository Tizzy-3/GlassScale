import SwiftUI

@main
struct GlassScaleApp: App {
    @State private var store = WeightStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Theme.aqua)
        }
    }
}
