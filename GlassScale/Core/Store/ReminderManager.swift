import Foundation
import Observation
import UserNotifications

@MainActor @Observable
final class ReminderManager {
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var errorMessage: String?
    private(set) var pendingCount = 0

    private let center = UNUserNotificationCenter.current()
    private var revision = 0
    private var isRefreshing = false
    private var desired: Snapshot?

    private struct Snapshot {
        let settings: ReminderSettings
        let weightDates: [Date]
        let waterGoalReachedToday: Bool
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional || authorizationStatus == .ephemeral
    }

    var permissionDescription: String {
        switch authorizationStatus {
        case .notDetermined: return "尚未开启通知权限"
        case .denied: return "通知权限已关闭，请前往系统设置开启"
        case .authorized: return "通知权限已开启"
        case .provisional: return "通知会安静送达通知中心"
        case .ephemeral: return "通知权限暂时可用"
        @unknown default: return "请检查系统通知设置"
        }
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    /// Call only from an explicit user action enabling reminders.
    func requestPermission() async -> Bool {
        errorMessage = nil
        await refreshAuthorizationStatus()
        if authorizationStatus == .notDetermined {
            do {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                errorMessage = "无法请求通知权限：\(error.localizedDescription)"
            }
            await refreshAuthorizationStatus()
        }
        return isAuthorized
    }

    /// Coalesce changes in one serial loop so an older asynchronous add can never win.
    func refresh(settings: ReminderSettings, weightDates: [Date], waterGoalReachedToday: Bool) async {
        desired = Snapshot(settings: settings, weightDates: weightDates, waterGoalReachedToday: waterGoalReachedToday)
        revision += 1
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        while let snapshot = desired {
            let currentRevision = revision
            desired = nil
            await refreshAuthorizationStatus()
            let oldRequests = await center.pendingNotificationRequests()
            guard currentRevision == revision else { continue }
            center.removePendingNotificationRequests(withIdentifiers: oldRequests.map(\.identifier).filter {
                $0.hasPrefix(ReminderSchedule.identifierPrefix)
            })
            pendingCount = 0
            errorMessage = nil
            guard isAuthorized else { continue }

            let requests = ReminderSchedule.requests(
                settings: snapshot.settings, weightDates: snapshot.weightDates,
                waterGoalReachedToday: snapshot.waterGoalReachedToday
            )
            for request in requests {
                guard currentRevision == revision else { break }
                let content = UNMutableNotificationContent()
                content.title = request.kind == .weight ? "记下今天的体重" : "喝口水，休息一下"
                content.body = request.kind == .weight ? "保持记录，看看自己的变化。" : "打开 GlassScale 记录这次喝水。"
                content.sound = .default
                var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: request.date)
                components.timeZone = .current
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                do {
                    try await center.add(UNNotificationRequest(identifier: request.id, content: content, trigger: trigger))
                    if currentRevision == revision { pendingCount += 1 }
                } catch {
                    if currentRevision == revision { errorMessage = "提醒安排失败：\(error.localizedDescription)" }
                }
            }
        }
    }
}
