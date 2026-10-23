import SwiftUI
import UIKit
import UserNotifications

struct ReminderSettingsView: View {
    @Environment(WeightStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var draft = ReminderSettings()
    @State private var didLoad = false
    @State private var isSaving = false
    @State private var permissionDenied = false
    @State private var hasSavedPreferences = false
    @State private var saveError: String?
    @State private var permissionError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        card("称重提醒", symbol: "scalemass") {
                            Toggle("每天提醒称重", isOn: $draft.weightEnabled)
                            if draft.weightEnabled {
                                DatePicker("提醒时间", selection: minuteBinding(\.weightMinuteOfDay), displayedComponents: .hourAndMinute)
                                Text("当天已记录体重，就不再提醒。")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        card("喝水提醒", symbol: "drop") {
                            Toggle("定时提醒喝水", isOn: $draft.waterEnabled)
                            if draft.waterEnabled {
                                DatePicker("开始时间", selection: minuteBinding(\.waterStartMinuteOfDay), displayedComponents: .hourAndMinute)
                                DatePicker("结束时间", selection: minuteBinding(\.waterEndMinuteOfDay), displayedComponents: .hourAndMinute)
                                Picker("提醒间隔", selection: $draft.waterIntervalMinutes) {
                                    ForEach(intervals, id: \.self) { minutes in
                                        Text("每 \(minutes) 分钟").tag(minutes)
                                    }
                                }
                                Toggle("当天达标后停止提醒", isOn: $draft.suppressWaterAfterGoal)
                                Text(windowDescription)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        card("通知权限", symbol: "bell") {
                            Text(store.reminders.permissionDescription)
                                .font(.subheadline).foregroundStyle(.secondary)
                            if permissionDenied || store.reminders.authorizationStatus == .denied {
                                Text(hasSavedPreferences
                                     ? "设置已保存，但系统通知权限关闭，提醒暂时无法送达。"
                                     : "系统通知权限关闭，开启权限后才能收到提醒。")
                                    .font(.caption).foregroundStyle(.orange)
                                Button("打开系统设置", systemImage: "arrow.up.right.square") {
                                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                                }
                                .buttonStyle(.glass)
                            }
                            if let saveError {
                                Text(saveError).font(.caption).foregroundStyle(.orange)
                            }
                            if let permissionError {
                                Text(permissionError).font(.caption).foregroundStyle(.orange)
                            }
                            if let error = store.reminders.errorMessage {
                                Text(error).font(.caption).foregroundStyle(.orange)
                            }
                            Text("提醒会提前安排未来几天，每次打开 App 时续排。长时间未打开时，提醒可能暂时停止。通知送达也受系统专注模式影响。")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(Theme.pagePadding)
                }
            }
            .navigationTitle("记录提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.disabled(isSaving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", systemImage: "checkmark") { Task { await save() } }
                        .disabled(isSaving)
                }
            }
            .task {
                if !didLoad {
                    draft = store.settings.reminders.normalized
                    didLoad = true
                }
                await store.reminders.refreshAuthorizationStatus()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task {
                        await store.reminders.refreshAuthorizationStatus()
                        permissionDenied = store.reminders.authorizationStatus == .denied
                    }
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private var intervals: [Int] {
        Array(Set([30, 60, 90, 120, 180, 240] + [draft.waterIntervalMinutes])).sorted()
    }

    private var windowDescription: String {
        if draft.waterStartMinuteOfDay == draft.waterEndMinuteOfDay {
            return "开始与结束时间相同表示全天提醒。"
        }
        if draft.waterEndMinuteOfDay < draft.waterStartMinuteOfDay {
            return "提醒时段跨越午夜，到第二天结束时间为止；其他时间保持安静。"
        }
        return "只在此时段内提醒，结束时间之后保持安静。"
    }

    private func card<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: title, symbol: symbol).padding(.horizontal, 4)
            GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 18) {
                VStack(alignment: .leading, spacing: 14) { content() }
            }
        }
    }

    private func minuteBinding(_ keyPath: WritableKeyPath<ReminderSettings, Int>) -> Binding<Date> {
        Binding {
            let value = draft[keyPath: keyPath]
            return Calendar.current.date(bySettingHour: value / 60, minute: value % 60, second: 0, of: Date()) ?? Date()
        } set: { date in
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            draft[keyPath: keyPath] = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        saveError = nil
        permissionError = nil
        hasSavedPreferences = false
        let needsPermission = draft.weightEnabled || draft.waterEnabled
        var allowed = true
        if needsPermission {
            allowed = await store.reminders.requestPermission()
            permissionError = store.reminders.errorMessage
        }
        var settings = store.settings
        settings.reminders = draft.normalized
        guard store.updateSettings(settings) else {
            saveError = store.storageError ?? "提醒设置没有保存，请重试。"
            permissionDenied = false
            return
        }
        hasSavedPreferences = true
        permissionDenied = needsPermission && !allowed
        if !permissionDenied && permissionError == nil && store.reminders.errorMessage == nil { dismiss() }
    }
}
