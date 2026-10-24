import SwiftUI

@main
struct GlassScaleApp: App {
    @State private var store = WeightStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Theme.aqua)
                // 主题是静态读取的，靠重建整个界面来换肤
                .id(store.settings.theme)
        }
    }
}
