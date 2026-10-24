import Foundation

/// Pure snapshot evaluation. Persistence and presentation are deliberately owned by WeightStore.
enum AchievementEngine {
    static let catalog: [AchievementDefinition] = [
        AchievementDefinition(id: .firstWeight, title: "第一笔记录", detail: "保存第一笔体重，留下自己的起点。", symbol: "checkmark.circle.fill", category: .recording),
        AchievementDefinition(id: .streak3, title: "连续记录 3 天", detail: "在连续 3 个日历日记录体重。", symbol: "calendar", category: .recording),
        AchievementDefinition(id: .streak7, title: "连续记录 7 天", detail: "在连续 7 个日历日记录体重。", symbol: "checkmark.seal.fill", category: .recording),
        AchievementDefinition(id: .streak14, title: "连续记录 14 天", detail: "在连续 14 个日历日记录体重。", symbol: "star.fill", category: .recording),
        AchievementDefinition(id: .streak30, title: "连续记录 30 天", detail: "在连续 30 个日历日记录体重。", symbol: "star.circle.fill", category: .recording),
        AchievementDefinition(id: .firstKilogram, title: "向目标前进 1 kg", detail: "按设定的目标方向，累计前进至少 1 kg。", symbol: "leaf.fill", category: .progress),
        AchievementDefinition(id: .threeKilograms, title: "向目标前进 3 kg", detail: "按设定的目标方向，累计前进至少 3 kg。", symbol: "flag.fill", category: .progress),
        AchievementDefinition(id: .progress25, title: "目标进度 25%", detail: "首次完成自己设定目标的四分之一。", symbol: "circle.lefthalf.filled", category: .progress),
        AchievementDefinition(id: .progress50, title: "目标进度 50%", detail: "首次完成自己设定目标的一半。", symbol: "flag.circle.fill", category: .progress),
        AchievementDefinition(id: .progress75, title: "目标进度 75%", detail: "首次完成自己设定目标的四分之三。", symbol: "target", category: .progress),
        AchievementDefinition(id: .goalReached, title: "达成目标", detail: "首次抵达自己设定的体重目标。", symbol: "trophy.fill", category: .progress),
        AchievementDefinition(id: .waterGoal, title: "首次喝水达标", detail: "至少一天的喝水记录达到设定的目标。", symbol: "drop.fill", category: .hydration)
    ]

    static func earnedIDs(
        entries: [WeightEntry], goal: WeightGoal?, baselineKg: Double?,
        waterEntries: [WaterEntry], waterGoalMl: Int,
        policy: DailyWeightPolicy = .latest, now: Date = Date(), calendar: Calendar = .current
    ) -> Set<AchievementID> {
        let daily = dailyEntries(entries, policy: policy, now: now, calendar: calendar)
        var earned: Set<AchievementID> = []

        if !daily.isEmpty { earned.insert(.firstWeight) }
        let bestStreak = longestStreak(daily.map { calendar.startOfDay(for: $0.date) }, calendar: calendar)
        let streakThresholds: [(Int, AchievementID)] = [(3, .streak3), (7, .streak7), (14, .streak14), (30, .streak30)]
        for (days, id) in streakThresholds {
            if bestStreak >= days { earned.insert(id) }
        }

        if let goal,
           let baseline = baselineKg ?? daily.first?.weightKg,
           baseline.isFinite, baseline > 0, goal.targetWeightKg.isFinite, goal.targetWeightKg > 0 {
            let span = goal.targetWeightKg - baseline
            let plannedDistance = abs(span)
            if plannedDistance > 0.000_001 {
                let direction = span > 0 ? 1.0 : -1.0
                let bestDirectedDistance = daily.map { ($0.weightKg - baseline) * direction }.max() ?? 0
                // Crossing a small goal cannot create a larger kg achievement.
                let achievedDistance = min(plannedDistance, max(0, bestDirectedDistance))
                let epsilon = 0.000_001
                if achievedDistance + epsilon >= 1 { earned.insert(.firstKilogram) }
                if achievedDistance + epsilon >= 3 { earned.insert(.threeKilograms) }
                let progress = achievedDistance / plannedDistance
                let progressThresholds: [(Double, AchievementID)] = [
                    (0.25, .progress25), (0.5, .progress50), (0.75, .progress75), (1, .goalReached)
                ]
                for (threshold, id) in progressThresholds {
                    if progress + epsilon >= threshold { earned.insert(id) }
                }
            }
        }

        if waterGoalMl > 0 {
            var totals: [Date: Int] = [:]
            for entry in waterEntries where entry.date <= now && entry.ml > 0 {
                let day = calendar.startOfDay(for: entry.date)
                // Saturating at the goal avoids integer overflow and never rewards excess volume.
                let total = totals[day] ?? 0
                totals[day] = total + min(entry.ml, waterGoalMl - total)
            }
            if totals.values.contains(where: { $0 >= waterGoalMl }) { earned.insert(.waterGoal) }
        }
        return earned
    }

    static func mergedUnlocks(
        existing: [AchievementUnlock], earnedIDs: Set<AchievementID>, earnedAt: Date? = nil
    ) -> [AchievementUnlock] {
        var owned: [AchievementID: AchievementUnlock] = [:]
        for unlock in existing {
            guard let previous = owned[unlock.id] else {
                owned[unlock.id] = unlock
                continue
            }
            // Duplicated imported entries retain their earliest known existing date.
            if let date = unlock.earnedAt {
                if let previousDate = previous.earnedAt {
                    if date < previousDate { owned[unlock.id] = unlock }
                } else {
                    owned[unlock.id] = unlock
                }
            }
        }
        for id in earnedIDs where owned[id] == nil {
            owned[id] = AchievementUnlock(id: id, earnedAt: earnedAt)
        }
        return catalog.compactMap { owned[$0.id] }
    }

    private static func dailyEntries(
        _ entries: [WeightEntry], policy: DailyWeightPolicy, now: Date, calendar: Calendar
    ) -> [WeightEntry] {
        let sorted = entries.filter { $0.date <= now && $0.weightKg.isFinite && $0.weightKg > 0 }.sorted {
            $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date
        }
        var daily: [Date: WeightEntry] = [:]
        for entry in sorted {
            let day = calendar.startOfDay(for: entry.date)
            guard let previous = daily[day] else { daily[day] = entry; continue }
            switch policy {
            case .latest: daily[day] = entry
            case .earliest: break
            case .lowest:
                if entry.weightKg <= previous.weightKg { daily[day] = entry }
            }
        }
        return daily.values.sorted { $0.date < $1.date }
    }

    private static func longestStreak(_ days: [Date], calendar: Calendar) -> Int {
        var longest = 0
        var current = 0
        var previous: Date?
        for day in days.sorted() {
            if let previous,
               calendar.date(byAdding: .day, value: 1, to: previous) == day {
                current += 1
            } else {
                current = 1
            }
            longest = max(longest, current)
            previous = day
        }
        return longest
    }
}
