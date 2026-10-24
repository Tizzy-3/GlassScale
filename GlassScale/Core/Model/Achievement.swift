import Foundation

/// Stable lifetime identifiers shared by the catalog, saved ledger and history page.
enum AchievementID: String, Codable, CaseIterable, Hashable {
    case firstWeight
    case streak3
    case streak7
    case streak14
    case streak30
    case firstKilogram
    case threeKilograms
    case progress25
    case progress50
    case progress75
    case goalReached
    case waterGoal
}

enum AchievementCategory: String, CaseIterable, Identifiable {
    case recording
    case progress
    case hydration

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recording: return "坚持记录"
        case .progress: return "目标进展"
        case .hydration: return "喝水达标"
        }
    }
}

struct AchievementDefinition: Identifiable {
    let id: AchievementID
    let title: String
    let detail: String
    let symbol: String
    let category: AchievementCategory

    func displayTitle(unit: WeightUnit) -> String {
        guard let kg = kilogramThreshold else { return title }
        return "向目标前进 \(thresholdLabel(kg, unit: unit))"
    }

    func displayDetail(unit: WeightUnit) -> String {
        guard let kg = kilogramThreshold else { return detail }
        let text = "按设定的目标方向，达成 \(thresholdLabel(kg, unit: unit)) 的进展"
        if unit == .pounds {
            return text + "（解锁节点为 \(Fmt.number(kg, decimals: 0)) kg）。"
        }
        return text + "。"
    }

    private var kilogramThreshold: Double? {
        switch id {
        case .firstKilogram: return 1
        case .threeKilograms: return 3
        default: return nil
        }
    }

    private func thresholdLabel(_ kg: Double, unit: WeightUnit) -> String {
        let value = Fmt.weight(kg, unit, decimals: unit == .pounds ? 1 : 0)
        return "\(unit == .pounds ? "约 " : "")\(value) \(unit.symbol)"
    }
}

struct AchievementUnlock: Codable, Hashable, Identifiable {
    let id: AchievementID
    /// nil means historical records established ownership; the original unlock date is unknown.
    let earnedAt: Date?

    init(id: AchievementID, earnedAt: Date? = nil) {
        self.id = id
        self.earnedAt = earnedAt
    }
}
