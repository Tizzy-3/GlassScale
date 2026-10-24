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

    /// 读取旧记录可静默识别成就；打开页面不会触发落盘或庆祝。
    var achievementUnlocks: [AchievementUnlock] {
        _ = currentDay
        return AchievementEngine.mergedUnlocks(existing: settings.achievementUnlocks,
                                               earnedIDs: earnedAchievementIDs())
    }

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
        let now = Date()
        guard (1...10000).contains(ml), date <= now else { return false }
        let previous = waterEntries
        let previousSettings = settings
        let ownedBefore = achievementUnlocks
        let isNew = id.map { value in !previous.contains { $0.id == value } } ?? true
        let latestBefore = previous.last { $0.date <= now }
        let isLive = isNew && Calendar.current.isDate(date, inSameDayAs: now)
            && date >= (latestBefore?.date ?? .distantPast)
        let wasBelowGoal = todayWaterMl < settings.waterGoalMl
        waterEntries = RecordOperations.upsertWater(WaterEntry(id: id ?? UUID(), date: date, ml: ml), in: waterEntries)
        let newlyUnlocked = updateAchievementLedger(ownedBefore: ownedBefore, earnedAt: isLive ? now : nil)
        guard persistNow() else { waterEntries = previous; settings = previousSettings; return false }
        refreshReminders()
        if isLive, !newlyUnlocked.isEmpty {
            presentAchievementFeedback(newlyUnlocked)
        } else if isLive && wasBelowGoal && todayWaterMl >= settings.waterGoalMl {
            toast = "今日喝水已达标，记录已保存"
        }
        return true
    }

    func deleteWater(_ entry: WaterEntry) {
        let previous = waterEntries
        let previousSettings = settings
        let ownedBefore = achievementUnlocks
        waterEntries.removeAll { $0.id == entry.id }
        updateAchievementLedger(ownedBefore: ownedBefore)
        if !persistNow() { waterEntries = previous; settings = previousSettings }
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
        let now = Date()
        let previous = entries
        let previousSettings = settings
        let ownedBefore = achievementUnlocks
        let calendar = Calendar.current
        let isNew = !previous.contains { $0.id == entry.id }
        let latestBefore = previous.last { $0.date <= now }
        let isLive = !silently && isNew && entry.date <= now
            && calendar.isDate(entry.date, inSameDayAs: now)
            && entry.date >= (latestBefore?.date ?? .distantPast)
        let isFirstToday = !previous.contains { $0.date <= now && calendar.isDate($0.date, inSameDayAs: now) }
        entries = RecordOperations.upsertWeight(entry, in: entries)
        let newlyUnlocked = updateAchievementLedger(ownedBefore: ownedBefore, earnedAt: isLive ? now : nil)
        guard persistNow() else { entries = previous; settings = previousSettings; return nil }

        if isLive && (isFirstToday || newlyUnlocked.contains(where: { $0.id == .goalReached })) {
            if !newlyUnlocked.isEmpty {
                presentAchievementFeedback(newlyUnlocked)
            } else {
                presentWeightEncouragement(for: entry, previous: previous)
            }
        }
        refreshReminders()
        return entry
    }

    func delete(_ entry: WeightEntry) {
        let previous = entries
        let previousSettings = settings
        let ownedBefore = achievementUnlocks
        entries.removeAll { $0.id == entry.id }
        updateAchievementLedger(ownedBefore: ownedBefore)
        if !persistNow() { entries = previous; settings = previousSettings }
        refreshReminders()
    }

    func delete(at offsets: IndexSet, in group: [WeightEntry]) {
        let previous = entries
        let previousSettings = settings
        let ownedBefore = achievementUnlocks
        let ids = offsets.map { group[$0].id }
        entries.removeAll { ids.contains($0.id) }
        updateAchievementLedger(ownedBefore: ownedBefore)
        if !persistNow() { entries = previous; settings = previousSettings }
        refreshReminders()
    }

    func replaceAll(_ newEntries: [WeightEntry]) {
        let previous = entries
        let previousSettings = settings
        let ownedBefore = achievementUnlocks
        entries = newEntries
        sortEntries()
        updateAchievementLedger(ownedBefore: ownedBefore)
        if !persistNow() { entries = previous; settings = previousSettings }
    }

    // MARK: - 导入

    /// 批量导入按 ID、健康样本或完全相同测量去重，保留同日多条。
    /// 返回 (新增条数, 跳过条数)。
    @discardableResult
    func importEntries(_ newEntries: [WeightEntry]) -> (added: Int, skipped: Int) {
        let previous = entries
        let previousSettings = settings
        let ownedBefore = achievementUnlocks
        let result = RecordOperations.mergeWeights(newEntries, into: entries)
        entries = result.entries
        if result.added > 0 {
            updateAchievementLedger(ownedBefore: ownedBefore)
            if !persistNow() { entries = previous; settings = previousSettings; return (0, result.skipped) }
        }
        refreshReminders()
        return (result.added, result.skipped)
    }

    /// 文件备份合并同时保留体重和喝水记录，一次写入失败则整体回滚。
    func importBackupRecords(_ payload: Persistence.Payload) -> (weights: Int, waters: Int)? {
        let previousWeights = entries
        let previousWaters = waterEntries
        let previousSettings = settings
        let ownedBefore = achievementUnlocks
        let weights = RecordOperations.mergeWeights(payload.entries, into: entries)
        let waters = RecordOperations.mergeWaters(payload.waterEntries, into: waterEntries)
        entries = weights.entries
        waterEntries = waters.entries
        updateAchievementLedger(ownedBefore: ownedBefore + payload.settings.achievementUnlocks)
        guard persistNow() else {
            entries = previousWeights
            waterEntries = previousWaters
            settings = previousSettings
            return nil
        }
        refreshReminders()
        return (weights.added, waters.added)
    }

    /// 从完整备份恢复：覆盖记录、档案、目标与设置。
    @discardableResult
    func restore(from payload: Persistence.Payload) -> Bool {
        saveWorkItem?.cancel()
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
    var requiresStorageRecovery: Bool { storageBlocked }

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
        let previous = goal
        let previousSettings = settings
        let ownedBefore = achievementUnlocks
        if let targetWeightKg, let targetDate {
            goal = WeightGoal(targetWeightKg: targetWeightKg, targetDate: targetDate)
        } else {
            goal = nil
        }
        updateAchievementLedger(ownedBefore: ownedBefore)
        if !persistNow() { goal = previous; settings = previousSettings }
    }

    func updateProfile(_ profile: BodyProfile) {
        let previous = self.profile
        let previousSettings = settings
        let ownedBefore = achievementUnlocks
        self.profile = profile
        updateAchievementLedger(ownedBefore: ownedBefore)
        if !persistNow() { self.profile = previous; settings = previousSettings }
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
        let ownedBefore = achievementUnlocks
        self.settings = settings
        updateAchievementLedger(ownedBefore: ownedBefore + settings.achievementUnlocks)
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

    private func earnedAchievementIDs() -> Set<AchievementID> {
        AchievementEngine.earnedIDs(entries: entries, goal: goal, baselineKg: baselineKg,
                                    waterEntries: waterEntries, waterGoalMl: settings.waterGoalMl,
                                    policy: settings.dailyWeightPolicy)
    }

    /// Mutate the ledger only as part of an explicit data transaction. Callers keep
    /// their previous settings and roll this back together with the record on failure.
    @discardableResult
    private func updateAchievementLedger(ownedBefore: [AchievementUnlock], earnedAt: Date? = nil) -> [AchievementUnlock] {
        let previousIDs = Set(ownedBefore.map(\.id))
        let updated = AchievementEngine.mergedUnlocks(existing: ownedBefore,
                                                      earnedIDs: earnedAchievementIDs(), earnedAt: earnedAt)
        settings.achievementUnlocks = updated
        return updated.filter { !previousIDs.contains($0.id) }
    }

    private func presentAchievementFeedback(_ unlocks: [AchievementUnlock]) {
        let priority: [AchievementID] = [.goalReached, .progress75, .threeKilograms, .progress50,
                                         .firstKilogram, .progress25, .streak30, .streak14,
                                         .streak7, .streak3, .waterGoal, .firstWeight]
        let ids = Set(unlocks.map(\.id))
        guard let id = priority.first(where: { ids.contains($0) }),
              let definition = AchievementEngine.catalog.first(where: { $0.id == id }) else { return }
        let stages: Set<AchievementID> = [.goalReached, .progress25, .progress50, .progress75,
                                         .firstKilogram, .threeKilograms]
        if stages.contains(id) {
            toast = nil
            let detail: String
            if id == .goalReached, let goal {
                detail = "已达到你设定的 \(Fmt.weight(goal.targetWeightKg, unit)) \(unit.symbol) 目标。\n为自己庆祝一下，接下来也按自己的节奏记录。"
            } else {
                detail = definition.displayDetail(unit: unit) + "\n这份进展已被记下，继续按自己的节奏前进。"
            }
            milestone = Milestone(kind: id == .goalReached ? .goal : .achievement(id),
                                  title: definition.displayTitle(unit: unit),
                                  detail: detail, symbol: definition.symbol)
        } else {
            toast = "解锁成就：\(definition.displayTitle(unit: unit))"
        }
    }

    private func presentWeightEncouragement(for entry: WeightEntry, previous: [WeightEntry]) {
        guard let goal, let baseline = baselineKg, abs(goal.targetWeightKg - baseline) > 0.0001 else {
            toast = "今天的体重已记录，按自己的节奏继续"
            return
        }
        let progress = goal.progress(startKg: baseline, currentKg: entry.weightKg)
        if progress >= 1 {
            toast = "已达成目标，继续按自己的节奏记录"
        } else if let prior = previous.last(where: { $0.date <= entry.date }),
                  progress > goal.progress(startKg: baseline, currentKg: prior.weightKg) {
            toast = "今天已记录，正在接近你设定的目标"
        } else {
            toast = "今天的体重已记录，按自己的节奏继续"
        }
    }

    // MARK: - 示例数据

    func loadSampleData() {
        let previousEntries = entries
        let previousProfile = profile
        let previousGoal = goal
        let previousSettings = settings
        let ownedBefore = achievementUnlocks
        let generator = SampleData.make(count: 90)
        entries = generator
        sortEntries()
        if profile.baselineKg == nil {
            profile.baselineKg = generator.first?.weightKg
        }
        if goal == nil, let last = generator.last?.weightKg {
            goal = WeightGoal(targetWeightKg: (last - 8).rounded(), targetDate: Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date())
        }
        updateAchievementLedger(ownedBefore: ownedBefore)
        if persistNow() { refreshReminders() }
        else { entries = previousEntries; profile = previousProfile; goal = previousGoal; settings = previousSettings }
    }

    func clearAll() {
        let previousEntries = entries
        let previousWater = waterEntries
        let previousSettings = settings
        let previousMilestone = milestone
        entries = []
        waterEntries = []
        settings.achievementUnlocks = []
        milestone = nil
        if persistNow() { refreshReminders() }
        else { entries = previousEntries; waterEntries = previousWater; settings = previousSettings; milestone = previousMilestone }
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
        case achievement(AchievementID)
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
