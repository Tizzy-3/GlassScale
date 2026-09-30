import Foundation

/// 一段时间窗口内由记录派生的统计结果，全部为纯计算，不持有状态。
struct WeightStats: Equatable {
    var currentKg: Double?
    /// 与上一条记录的差（正数 = 变重）
    var deltaLastKg: Double?
    /// 与 7 天前最近一条的差
    var delta7dKg: Double?
    /// 与 30 天前最近一条的差
    var delta30dKg: Double?
    /// 最近 7 条记录的均值
    var average7Kg: Double?
    var average30Kg: Double?
    /// 线性回归得到的每周变化速度（kg / 周，负数表示在减）
    var weeklyRateKg: Double?
    var bmi: Double?
    /// 连续记录天数（含今天）
    var streakDays: Int = 0
    /// 最早一条记录的体重
    var startKg: Double?
    /// 记录条数
    var count: Int = 0

    static let empty = WeightStats()

    /// 目标还差多少（正数）
    func remainingKg(to goal: WeightGoal?) -> Double? {
        guard let goal, let currentKg else { return nil }
        return abs(goal.targetWeightKg - currentKg)
    }

    /// 目标完成度 0…1
    func progress(goal: WeightGoal?, baselineKg: Double?) -> Double? {
        guard let goal else { return nil }
        guard let currentKg else { return 0 }
        let base = baselineKg ?? startKg ?? currentKg
        return goal.progress(startKg: base, currentKg: currentKg)
    }

    /// 按当前速度预计到达目标的日期；无法估计时返回 nil
    func projectedGoalDate(goal: WeightGoal?, baselineKg: Double?) -> Date? {
        guard let goal, let weeklyRateKg, let currentKg else { return nil }
        guard abs(weeklyRateKg) > 0.02 else { return nil }
        let remaining = abs(goal.targetWeightKg - currentKg)
        guard remaining > 0.05 else { return Calendar.current.startOfDay(for: Date()) }

        // 方向不一致（目标在增重但实际在减，或反之）时不做预测
        let goingDown = currentKg > goal.targetWeightKg
        if (weeklyRateKg < 0) != goingDown { return nil }

        let weeks = remaining / abs(weeklyRateKg)
        guard weeks.isFinite, weeks < 520 else { return nil }
        return Calendar.current.date(byAdding: .day, value: Int(weeks * 7), to: Date())
    }
}

// MARK: - 统计计算

enum StatsEngine {
    /// `entries` 必须按时间升序。
    static func compute(entries: [WeightEntry], profile: BodyProfile, now: Date = Date()) -> WeightStats {
        guard !entries.isEmpty else { return .empty }

        let current = entries.last!
        var stats = WeightStats()
        stats.currentKg = current.weightKg
        stats.count = entries.count
        stats.startKg = entries.first?.weightKg

        if entries.count >= 2 {
            stats.deltaLastKg = current.weightKg - entries[entries.count - 2].weightKg
        }

        stats.delta7dKg = delta(entries, days: 7, now: current.date)
        stats.delta30dKg = delta(entries, days: 30, now: current.date)

        stats.average7Kg = average(entries, count: 7)
        stats.average30Kg = average(entries, count: 30)
        stats.weeklyRateKg = weeklyRate(entries)
        stats.bmi = profile.bmi(weightKg: current.weightKg)
        stats.streakDays = streak(entries, now: now)
        return stats
    }

    /// 与 N 天之前最近的一条记录比较
    private static func delta(_ entries: [WeightEntry], days: Int, now: Date) -> Double? {
        let cal = Calendar.current
        guard let cutoff = cal.date(byAdding: .day, value: -days, to: now) else { return nil }
        let latest = entries.last!
        // 找到 cutoff 之前最近的一条
        let prior = entries.last { $0.date <= cutoff }
        guard let prior, prior.id != latest.id else { return nil }
        return latest.weightKg - prior.weightKg
    }

    private static func average(_ entries: [WeightEntry], count: Int) -> Double? {
        let slice = entries.suffix(count)
        guard !slice.isEmpty else { return nil }
        return slice.reduce(0.0) { $0 + $1.weightKg } / Double(slice.count)
    }

    /// 最小二乘拟合，返回 kg / 周
    static func weeklyRate(_ entries: [WeightEntry]) -> Double? {
        guard entries.count >= 3 else { return nil }
        let cal = Calendar.current
        let origin = cal.startOfDay(for: entries[0].date)

        var n = 0.0
        var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumXX = 0.0
        for e in entries {
            let days = cal.dateComponents([.day], from: origin, to: e.date).day ?? 0
            let x = Double(days)
            let y = e.weightKg
            n += 1
            sumX += x
            sumY += y
            sumXY += x * y
            sumXX += x * x
        }
        let denom = n * sumXX - sumX * sumX
        guard abs(denom) > 0.0001 else { return nil }
        let slope = (n * sumXY - sumX * sumY) / denom   // kg / day
        return slope * 7.0
    }

    /// 连续记录天数：今天或昨天有记录才算连续。
    static func streak(_ entries: [WeightEntry], now: Date) -> Int {
        let cal = Calendar.current
        let days = Set(entries.map { cal.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return 0 }

        var cursor = cal.startOfDay(for: now)
        if !days.contains(cursor) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: cursor),
                  days.contains(yesterday) else { return 0 }
            cursor = yesterday
        }

        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }
}
