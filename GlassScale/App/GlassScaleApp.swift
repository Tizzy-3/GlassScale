import SwiftUI

@main
struct GlassScaleApp: App {
    @State private var store = WeightStore()

    init() {
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--ui-preview") {
            _store = State(initialValue: Self.previewStore())
        }
        #endif
    }

    #if DEBUG && targetEnvironment(simulator)
    /// 仅模拟器截图命令显式启用；Release 安装包不包含示例注入入口。
    private static func previewStore() -> WeightStore {
        let store = WeightStore(preview: true)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var entries = (0..<13).map { offset in
            let day = calendar.date(byAdding: .day, value: offset - 13, to: today) ?? today
            let date = calendar.date(bySettingHour: 8, minute: 16, second: 0, of: day) ?? day
            return WeightEntry(date: date, weightKg: 71.9 - Double(offset) * 0.13)
        }
        let early = min(Date().addingTimeInterval(-120), calendar.date(bySettingHour: 7, minute: 30, second: 0, of: today) ?? today)
        let latest = min(Date().addingTimeInterval(-60), calendar.date(bySettingHour: 8, minute: 16, second: 0, of: today) ?? today)
        entries.append(WeightEntry(date: early, weightKg: 70.5))
        entries.append(WeightEntry(date: latest, weightKg: 70.2))
        var settings = AppSettings()
        settings.hasCompletedOnboarding = true
        settings.showsDemoData = false
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-preview-sunset") { settings.theme = .sunset }
        if arguments.contains("--ui-preview-pounds") { settings.weightUnit = .pounds }
        var profile = BodyProfile()
        profile.baselineKg = 75
        let goal = WeightGoal(targetWeightKg: 65, targetDate: calendar.date(byAdding: .month, value: 3, to: today) ?? today)
        let amounts = arguments.contains("--ui-preview-water-complete") ? [500, 750, 750] : [250, 500, 500]
        let waters = amounts.enumerated().map { index, ml in
            WaterEntry(date: max(today, latest.addingTimeInterval(Double(index + 1) * -600)), ml: ml)
        }
        let empty = arguments.contains("--ui-preview-empty")
        store.restore(from: Persistence.Payload(entries: empty ? [] : entries, profile: profile,
                                               goal: empty ? nil : goal, settings: settings, waterEntries: empty ? [] : waters))
        return store
    }
    #endif

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
