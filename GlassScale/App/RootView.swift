import SwiftUI

enum AppTab: Hashable {
    case dashboard
    case history
    case trends
    case settings
}

struct RootView: View {
    @Environment(WeightStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: AppTab = .dashboard
    @State private var pendingQuickAdd = false

    var body: some View {
        ZStack {
            AuroraBackground()

            if store.settings.hasCompletedOnboarding {
                tabs
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.4), value: store.settings.hasCompletedOnboarding)
        .overlay {
            if let milestone = store.milestone {
                CelebrationView(milestone: milestone) {
                    withAnimation(.snappy) { store.consumeMilestone() }
                }
                .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            if let toast = store.toast {
                ToastView(text: toast)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: toast) {
                        try? await Task.sleep(for: .seconds(3))
                        withAnimation(.snappy) { store.consumeToast() }
                    }
            }
        }
        .animation(.snappy, value: store.milestone?.id)
        .animation(.snappy, value: store.toast)
        .sheet(isPresented: $pendingQuickAdd) {
            EntryEditorView(mode: .create)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.health.refreshStatus()
            }
        }
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            Tab("首页", systemImage: "scalemass", value: AppTab.dashboard) {
                DashboardView(onAdd: { pendingQuickAdd = true })
            }

            Tab("记录", systemImage: "list.bullet.rectangle", value: AppTab.history) {
                HistoryView()
            }

            Tab("趋势", systemImage: "chart.xyaxis.line", value: AppTab.trends) {
                TrendsView()
            }

            Tab("我的", systemImage: "person.crop.circle", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            QuickLogBar()
        }
    }
}
