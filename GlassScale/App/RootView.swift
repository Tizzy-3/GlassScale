import Combine
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection: AppTab = .dashboard
    @State private var pendingQuickAdd = false
    @State private var showRecoveryImport = false
    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    init() {
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--ui-preview-records") {
            _selection = State(initialValue: .history)
        }
        #endif
    }

    var body: some View {
        ZStack {
            AuroraBackground()

            if store.requiresStorageRecovery {
                VStack(spacing: 20) {
                    Image(systemName: "externaldrive.badge.exclamationmark").font(.largeTitle)
                    Text("恢复本机数据").font(.title2.bold())
                    Text("数据文件暂时无法读取。原文件已保留，请选择备份恢复后继续使用。")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                    if store.hasRecoverableBackup {
                        Button("恢复自动备份") { store.restoreAutomaticBackup() }.buttonStyle(.glassProminent)
                    }
                    Button("选择 JSON 文件备份") { showRecoveryImport = true }.buttonStyle(.glass)
                }
                .padding(28)
            } else if store.settings.hasCompletedOnboarding {
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
                    withAnimation(reduceMotion ? nil : .snappy) { store.consumeMilestone() }
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
                        do {
                            try await Task.sleep(for: .seconds(UIAccessibility.isVoiceOverRunning ? 8 : 3))
                        } catch { return }
                        guard store.toast == toast else { return }
                        withAnimation(reduceMotion ? nil : .snappy) { store.consumeToast() }
                    }
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: store.milestone?.id)
        .animation(reduceMotion ? nil : .snappy, value: store.toast)
        .sheet(isPresented: $pendingQuickAdd) {
            EntryEditorView(mode: .create)
        }
        .sheet(isPresented: $showRecoveryImport) { ImportSheet() }
        .alert("数据存储提示", isPresented: Binding(
            get: { store.storageError != nil },
            set: { if !$0 { store.storageError = nil } }
        )) {
            Button("重试保存") { store.persistNow() }
            if store.hasRecoverableBackup {
                Button("恢复自动备份") { store.restoreAutomaticBackup() }
            }
            Button("稍后处理", role: .cancel) { store.storageError = nil }
        } message: {
            Text(store.storageError ?? "")
        }
        .task { store.refreshReminders() }
        .onReceive(clock) { _ in
            let day = Calendar.current.startOfDay(for: Date())
            if store.currentDay != day { store.refreshReminders() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            store.refreshReminders()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.health.refreshStatus()
                store.refreshReminders()
            } else {
                store.persistNow()
            }
        }
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            Tab("首页", systemImage: "house", value: AppTab.dashboard) {
                DashboardView(onAdd: { pendingQuickAdd = true }, onShowRecords: { selection = .history })
            }

            Tab("记录", systemImage: "calendar", value: AppTab.history) {
                HistoryView()
            }

            Tab("趋势", systemImage: "chart.xyaxis.line", value: AppTab.trends) {
                TrendsView()
            }

            Tab("我的", systemImage: "person.crop.circle", value: AppTab.settings) {
                SettingsView()
            }
        }
        // 保留 iOS 26 原生悬浮 Liquid Glass Tab Bar；不叠加自绘底栏或白色底板。
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
