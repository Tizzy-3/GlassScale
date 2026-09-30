import Foundation
import Observation
import SwiftUI

/// 整个 App 的唯一数据源。
///
/// 纯本地、单一 `Observable` 对象：改动 → 统计 → 落盘。
@Observable
final class WeightStore {

    // MARK: - 数据

    private(set) var entries: [WeightEntry] = []      // 始终按时间升序
    var profile: BodyProfile = BodyProfile()
    var goal: WeightGoal? = nil
    var settings: AppSettings = AppSettings()

    /// 需要弹出的里程碑提示，由视图消费后调用 `consumeMilestone()` 清空
    var milestone: Milestone? = nil
    /// 一次性提示（导入结果、错误等）
    var toast: String? = nil

    /// 头像：存在 Application Support/GlassScale/avatar.jpg，内存里缓存一份
    var avatarImage: UIImage? = nil

    let health = HealthKitManager()

    private var saveWorkItem: DispatchWorkItem?

    // MARK: - 生命周期

    init(preview: Bool = false) {
        if !preview, let payload = Persistence.load() {
            entries = payload.entries.sorted { $0.date < $1.date }
            profile = payload.profile
            goal = payload.goal
            settings = payload.settings
        }
        if !preview, let data = try? Data(contentsOf: Persistence.avatarURL) {
            avatarImage = UIImage(data: data)
        }
        Theme.current = settings.theme
    }

    // MARK: - 派生数据

    var unit: WeightUnit { settings.weightUnit }

    var stats: WeightStats {
        StatsEngine.compute(entries: entries, profile: profile)
    }

    var baselineKg: Double? {
        profile.baselineKg ?? entries.first?.weightKg
    }

    var todayEntry: WeightEntry? {
        let today = Calendar.current.startOfDay(for: Date())
        return entries.last { $0.dayKey == today }
    }

    /// 最近 n 天（含今天）的记录
    func recentEntries(days: Int) -> [WeightEntry] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -(days - 1), to: Date()) else {
            return entries
        }
        return entries.filter { $0.date >= cutoff }
    }

    func entries(in range: ClosedRange<Date>) -> [WeightEntry] {
        entries.filter { range.contains($0.date) }
    }

    var isEmpty: Bool { entries.isEmpty }

    // MARK: - 增删改

    /// 新增或更新一条记录。同一天已有记录时按「覆盖当天」处理。
    @discardableResult
    func save(entry: WeightEntry, silently: Bool = false) -> WeightEntry? {
        var stored = entry
        let sameDay = entries.first { $0.id == entry.id }
            ?? entries.first { $0.dayKey == entry.dayKey && $0.source == entry.source && entry.source == .manual }

        if let sameDay {
            stored.id = sameDay.id
            stored.source = sameDay.source == .healthKit && entry.source == .manual ? .manual : entry.source
            stored.healthKitUUID = sameDay.healthKitUUID
            entries.removeAll { $0.id == sameDay.id }
        }

        entries.append(stored)
        sortEntries()

        if !silently {
            checkMilestones(for: stored)
        }
        persist()
        return stored
    }

    func delete(_ entry: WeightEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func delete(at offsets: IndexSet, in group: [WeightEntry]) {
        let ids = offsets.map { group[$0].id }
        entries.removeAll { ids.contains($0.id) }
        persist()
    }

    func replaceAll(_ newEntries: [WeightEntry]) {
        entries = newEntries
        sortEntries()
        persist()
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

    func updateSettings(_ settings: AppSettings) {
        self.settings = settings
        Theme.current = settings.theme
        persist()
    }

    // MARK: - 里程碑

    func consumeMilestone() { milestone = nil }
    func consumeToast() { toast = nil }

    /// 记录新体重后检查是否跨过了「每 5 kg 一个」或「达成目标」这类节点。
    private func checkMilestones(for entry: WeightEntry) {
        guard let baseline = baselineKg else { return }
        let current = entry.weightKg

        if let goal {
            let reached = (baseline - current) * (baseline - goal.targetWeightKg) >= 0
            if reached {
                milestone = Milestone(
                    kind: .goal,
                    title: "达成目标",
                    detail: "你现在是 \(Fmt.weight(current, unit))，已抵达 \(Fmt.weight(goal.targetWeightKg, unit))",
                    symbol: "trophy.fill"
                )
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
        persist()
    }

    func clearAll() {
        entries = []
        milestone = nil
        persist()
    }

    // MARK: - 落盘

    func persist() {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Persistence.save(
                Persistence.Payload(
                    entries: self.entries,
                    profile: self.profile,
                    goal: self.goal,
                    settings: self.settings
                )
            )
        }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    func persistNow() {
        saveWorkItem?.cancel()
        Persistence.save(
            Persistence.Payload(
                entries: entries,
                profile: profile,
                goal: goal,
                settings: settings
            )
        )
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
