import Foundation
import Observation
import SwiftUI

/// 整个 App 的唯一数据源。
///
/// 纯本地、单一 `Observable` 对象：改动 → 统计 → 落盘。
@Observable
@MainActor
final class WeightStore {

    // MARK: - 数据

    private(set) var entries: [WeightEntry] = []      // 始终按时间升序
    var profile: BodyProfile = BodyProfile()
    var goal: WeightGoal? = nil
    var settings: AppSettings = AppSettings()

    /// 喝水记录，始终按时间升序
    private(set) var waterEntries: [WaterEntry] = []

    /// 需要弹出的里程碑提示，由视图消费后调用 `consumeMilestone()` 清空
    var milestone: Milestone? = nil
    /// 一次性提示（导入结果、错误等）
    var toast: String? = nil

    /// 头像：存在 Application Support/GlassScale/avatar.jpg，内存里缓存一份
    var avatarImage: UIImage? = nil

    let health = HealthKitManager()
    let reminders = ReminderManager()
    var storageError: String?
    private var storageBlocked = false
    /// 日期变化也触发界面读取，避免跨午夜仍展示昨天的数据。
    var currentDay = Calendar.current.startOfDay(for: Date())

    private var saveWorkItem: DispatchWorkItem?

    // MARK: - 生命周期

    init(preview: Bool = false) {
        if !preview {
            do {
                if let payload = try Persistence.load() { apply(payload) }
            } catch {
                storageBlocked = true
                storageError = "本机数据无法读取，原文件已保留。请从自动备份或文件备份恢复。\n\(error.localizedDescription)"
            }
        }
        if !preview, let data = try? Data(contentsOf: Persistence.avatarURL) {
            avatarImage = UIImage(data: data)
        }
        Theme.current = settings.theme
    }

    // MARK: - 派生数据

    var unit: WeightUnit { settings.weightUnit }

    var stats: WeightStats {
        _ = currentDay
        return StatsEngine.compute(entries: entries, profile: profile, policy: settings.dailyWeightPolicy)
    }

    var baselineKg: Double? {
        profile.baselineKg ?? entries.first?.weightKg
    }

    var todayEntry: WeightEntry? {
        _ = currentDay
        let today = Calendar.current.startOfDay(for: Date())
        return entries.last { $0.dayKey == today }
    }

    /// 最近 n 天（含今天）的记录
    func recentEntries(days: Int) -> [WeightEntry] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -(days - 1), to: Calendar.current.startOfDay(for: Date())) else {
            return entries
        }
        return entries.filter { $0.date >= cutoff && $0.date <= Date() }
    }

    func entries(in range: ClosedRange<Date>) -> [WeightEntry] {
        entries.filter { range.contains($0.date) }
    }

    var isEmpty: Bool { entries.isEmpty }

    // MARK: - 喝水

    /// 今天的喝水记录（按时间升序）
    var todayWaterEntries: [WaterEntry] {
        _ = currentDay
        let today = Calendar.current.startOfDay(for: Date())
        return waterEntries.filter { $0.dayKey == today }
    }

    /// 今日已喝水量（毫升）
    var todayWaterMl: Int { todayWaterEntries.reduce(0) { $0 + $1.ml } }

    /// 记一笔喝水。刚好达标时弹一次庆祝。
    func logWater(ml: Int) {
        _ = saveWater(ml: ml, at: Date())
    }

    func waterEntries(on date: Date) -> [WaterEntry] {
        waterEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    @discardableResult
    func saveWater(ml: Int, at date: Date, id: UUID? = nil) -> Bool {
        guard (1...10000).contains(ml), date <= Date() else { return false }
        let previous = waterEntries
        let wasBelowGoal = todayWaterMl < settings.waterGoalMl
        waterEntries = RecordOperations.upsertWater(WaterEntry(id: id ?? UUID(), date: date, ml: ml), in: waterEntries)
        guard persistNow() else { waterEntries = previous; return false }
        refreshReminders()
        if wasBelowGoal && todayWaterMl >= settings.waterGoalMl {
            toast = "💧 今日喝水目标达成，继续保持！"
        }
        return true
    }

    func deleteWater(_ entry: WaterEntry) {
        let previous = waterEntries
        waterEntries.removeAll { $0.id == entry.id }
        if !persistNow() { waterEntries = previous }
        refreshReminders()
    }

    @discardableResult
    func setWaterCupSizes(_ sizes: [Int]) -> Bool {
        let unique = sizes.reduce(into: [Int]()) { if !$0.contains($1) { $0.append($1) } }
        guard (1...4).contains(unique.count), unique.allSatisfy({ (1...10000).contains($0) }) else { return false }
        var updated = settings
        updated.waterCupSizes = unique
        return updateSettings(updated)
    }

    /// 撤销今日最后一笔喝水记录（点错了用）
    func undoLastWater() {
        guard let last = todayWaterEntries.max(by: { $0.date < $1.date }) else { return }
        deleteWater(last)
    }

    /// 设置每日喝水目标（毫升），限制在 500…6000
    func setWaterGoalMl(_ ml: Int) {
        var s = settings
        s.waterGoalMl = min(6000, max(500, ml))
        updateSettings(s)
    }

    /// 最近 n 天（含今天）每天的喝水量，供首页卡片画小统计条
    func waterMlByDay(lastDays: Int = 7) -> [(date: Date, ml: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<lastDays).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            let ml = waterEntries.filter { $0.dayKey == day }.reduce(0) { $0 + $1.ml }
            return (day, ml)
        }
    }

    // MARK: - 增删改

    /// 仅按记录 ID 更新；同一天新增的早晚记录分别保留。
    @discardableResult
    func save(entry: WeightEntry, silently: Bool = false) -> WeightEntry? {
        let previous = entries
        entries = RecordOperations.upsertWeight(entry, in: entries)
        guard persistNow() else { entries = previous; return nil }

        if !silently {
            checkMilestones(for: entry)
        }
        refreshReminders()
        return entry
    }

    func delete(_ entry: WeightEntry) {
        let previous = entries
        entries.removeAll { $0.id == entry.id }
        if !persistNow() { entries = previous }
        refreshReminders()
    }

    func delete(at offsets: IndexSet, in group: [WeightEntry]) {
        let previous = entries
        let ids = offsets.map { group[$0].id }
        entries.removeAll { ids.contains($0.id) }
        if !persistNow() { entries = previous }
        refreshReminders()
    }

    func replaceAll(_ newEntries: [WeightEntry]) {
        entries = newEntries
        sortEntries()
        persist()
    }

    // MARK: - 导入

    /// 批量导入按 ID、健康样本或完全相同测量去重，保留同日多条。
    /// 返回 (新增条数, 跳过条数)。
    @discardableResult
    func importEntries(_ newEntries: [WeightEntry]) -> (added: Int, skipped: Int) {
        let previous = entries
        let result = RecordOperations.mergeWeights(newEntries, into: entries)
        entries = result.entries
        if result.added > 0, !persistNow() { entries = previous; return (0, result.skipped) }
        refreshReminders()
        return (result.added, result.skipped)
    }

    /// 从完整备份恢复：覆盖记录、档案、目标与设置。
    @discardableResult
    func restore(from payload: Persistence.Payload) -> Bool {
        do {
            try Persistence.save(payload, allowReplacingUnreadable: true)
            apply(payload)
            storageBlocked = false
            storageError = nil
            refreshReminders()
            return true
        } catch {
            storageError = "恢复失败，原文件已保留：\(error.localizedDescription)"
            return false
        }
    }

    private func apply(_ payload: Persistence.Payload) {
        entries = payload.entries
        sortEntries()
        profile = payload.profile
        goal = payload.goal
        settings = payload.settings
        waterEntries = payload.waterEntries.sorted { $0.date < $1.date }
        Theme.current = settings.theme
        milestone = nil
    }

    var hasRecoverableBackup: Bool { (try? Persistence.loadBackup()) != nil }

    func restoreAutomaticBackup() {
        do {
            guard let payload = try Persistence.loadBackup() else { return }
            if restore(from: payload) { toast = "已恢复自动备份" }
        } catch {
            storageError = "自动备份无法读取：\(error.localizedDescription)"
        }
    }

    private func sortEntries() {
        entries.sort { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date }
    }

    // MARK: - 目标与档案

    func setGoal(targetWeightKg: Double?, targetDate: Date?) {
        if let targetWeightKg, let targetDate {
            goal = WeightGoal(targetWeightKg: targetWeightKg, targetDate: targetDate)
        } else {
            goal = nil
        }
        persist()
    }

    func updateProfile(_ profile: BodyProfile) {
        self.profile = profile
        persist()
    }

    // MARK: - 头像

    /// 收到的原图先压到 512px 再存 JPEG，避免 store 目录膨胀
    func saveAvatar(_ image: UIImage) {
        let scaled = image.scaledDown(to: 512)
        guard let data = scaled.jpegData(compressionQuality: 0.8) else { return }
        try? data.write(to: Persistence.avatarURL, options: .atomic)
        avatarImage = scaled
    }

    func removeAvatar() {
        try? FileManager.default.removeItem(at: Persistence.avatarURL)
        avatarImage = nil
    }

    @discardableResult
    func updateSettings(_ settings: AppSettings) -> Bool {
        let previous = self.settings
        self.settings = settings
        Theme.current = settings.theme
        guard persistNow() else { self.settings = previous; Theme.current = previous.theme; return false }
        refreshReminders()
        return true
    }

    func refreshReminders() {
        currentDay = Calendar.current.startOfDay(for: Date())
        Task { @MainActor [weak self] in
            guard let self else { return }
            await reminders.refresh(settings: settings.reminders, weightDates: entries.map(\.date), waterGoalReachedToday: todayWaterMl >= settings.waterGoalMl)
        }
    }

    // MARK: - 里程碑

    func consumeMilestone() { milestone = nil }
    func consumeToast() { toast = nil }

    /// 记录新体重后检查是否跨过了「每 5 kg 一个」或「达成目标」这类节点。
    private func checkMilestones(for entry: WeightEntry) {
        guard let baseline = baselineKg else { return }
        let current = entry.weightKg

        if let goal = goal {
            let target = goal.targetWeightKg
            // 只有真正越过目标线才算达成：减重目标要求当前 <= 目标，增重目标要求当前 >= 目标
            // （之前用的乘积公式，只要朝目标方向动一下就误判为达成）
            func reached(_ weight: Double) -> Bool {
                if target < baseline { return weight <= target }
                if target > baseline { return weight >= target }
                return false
            }
            if reached(current) {
                // 之前没达成过才庆祝，避免之后每记一次体重就弹一次
                let wasReachedBefore = entries
                    .filter { $0.id != entry.id }
                    .contains { reached($0.weightKg) }
                if !wasReachedBefore {
                    milestone = Milestone(
                        kind: .goal,
                        title: "达成目标",
                        detail: "你现在是 \(Fmt.weight(current, unit))，已抵达 \(Fmt.weight(target, unit))",
                        symbol: "trophy.fill"
                    )
                }
                return
            }
        }

        let stepKg = 5.0
        let achievedSteps = Int(abs(baseline - current) / stepKg)
        guard achievedSteps >= 1 else { return }

        // 只在「刷新纪录」时庆祝，避免同一步反复弹
        let bestBefore = entries
            .filter { $0.id != entry.id }
            .compactMap { Int(abs(baseline - $0.weightKg) / stepKg) }
            .max() ?? 0
        guard achievedSteps > bestBefore else { return }

        milestone = Milestone(
            kind: .step(achievedSteps),
            title: "累计\(current <= baseline ? "减" : "增")重 \(achievedSteps * Int(stepKg)) kg",
            detail: "从 \(Fmt.weight(baseline, unit)) 到 \(Fmt.weight(current, unit))，继续保持",
            symbol: "flame.fill"
        )
    }

    // MARK: - 示例数据

    func loadSampleData() {
        let generator = SampleData.make(count: 90)
        replaceAll(generator)
        if profile.baselineKg == nil {
            profile.baselineKg = generator.first?.weightKg
        }
        if goal == nil, let last = generator.last?.weightKg {
            goal = WeightGoal(targetWeightKg: (last - 8).rounded(), targetDate: Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date())
        }
        if persistNow() { refreshReminders() }
    }

    func clearAll() {
        let previousEntries = entries
        let previousWater = waterEntries
        entries = []
        waterEntries = []
        milestone = nil
        if persistNow() { refreshReminders() }
        else { entries = previousEntries; waterEntries = previousWater }
    }

    // MARK: - 落盘

    func persist() {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { _ = self?.persistNow() }
        }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    @discardableResult
    func persistNow() -> Bool {
        saveWorkItem?.cancel()
        guard !storageBlocked else {
            storageError = "数据文件无法读取，暂未写入任何更改。请先从自动备份或文件备份恢复。"
            return false
        }
        do {
            try Persistence.save(
                Persistence.Payload(
                    entries: entries,
                    profile: profile,
                    goal: goal,
                    settings: settings,
                    waterEntries: waterEntries
                )
            )
            storageError = nil
            return true
        } catch {
            storageError = "保存失败，请重试或导出备份：\(error.localizedDescription)"
            return false
        }
    }
}

// MARK: - 里程碑

struct Milestone: Identifiable, Equatable {
    enum Kind: Equatable {
        case step(Int)
        case goal
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let detail: String
    let symbol: String
}

// MARK: - 示例数据

enum SampleData {
    /// 生成一段可信的减重曲线：整体下降 + 周末回升 + 随机噪声。
    static func make(count: Int, endWeightKg: Double = 68.4) -> [WeightEntry] {
        var result: [WeightEntry] = []
        let cal = Calendar.current
        let startWeight = 78.6

        for i in 0..<count {
            let progress = Double(i) / Double(max(count - 1, 1))
            let trend = startWeight + (endWeightKg - startWeight) * progress
            let weekday = cal.component(.weekday, from: cal.date(byAdding: .day, value: -(count - 1 - i), to: Date()) ?? Date())
            // 周六周日容易吃高
            let weekendBump = (weekday == 1 || weekday == 7) ? 0.35 : 0
            let noise = Double.random(in: -0.32...0.32)
            let value = (trend + weekendBump + noise).rounded(toPlaces: 1)

            let date = cal.date(
                bySettingHour: 7,
                minute: Int.random(in: 10...50),
                second: 0,
                of: cal.date(byAdding: .day, value: -(count - 1 - i), to: Date()) ?? Date()
            ) ?? Date()

            result.append(
                WeightEntry(
                    date: date,
                    weightKg: value,
                    bodyFatPercent: (22.4 - progress * 3.1 + Double.random(in: -0.4...0.4)).rounded(toPlaces: 1),
                    note: ""
                )
            )
        }
        return result.sorted { $0.date < $1.date }
    }
}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

private extension UIImage {
    /// 等比压缩到最长边不超过 maxDimension
    func scaledDown(to maxDimension: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension, maxSide > 0 else { return self }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
