import Foundation

/// 减重 / 增重目标。
struct WeightGoal: Codable, Hashable {
    /// 目标体重，千克
    var targetWeightKg: Double
    /// 目标达成日期
    var targetDate: Date

    init(targetWeightKg: Double, targetDate: Date) {
        self.targetWeightKg = targetWeightKg
        self.targetDate = targetDate
    }

    /// 从 `startKg` 走到目标还需要减 / 增多少（正数）。
    func remainingKg(from startKg: Double) -> Double {
        (startKg - targetWeightKg).magnitude
    }

    /// 0…1 的完成度，用于进度环。`start` 与 `target` 相同时返回 1。
    func progress(startKg: Double, currentKg: Double) -> Double {
        let span = targetWeightKg - startKg
        guard abs(span) > 0.0001 else { return 1 }
        let done = currentKg - startKg
        return min(max(done / span, 0), 1)
    }
}
