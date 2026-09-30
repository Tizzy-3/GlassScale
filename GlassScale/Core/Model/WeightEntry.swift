import Foundation

/// 一条体重记录。
///
/// 所有重量在内部一律以 **千克** 存储，显示时才按 `WeightUnit` 换算，
/// 这样切换单位不会污染历史数据。
struct WeightEntry: Identifiable, Codable, Hashable {
    enum Source: String, Codable, CaseIterable {
        case manual
        case healthKit

        var title: String {
            switch self {
            case .manual: return "手动"
            case .healthKit: return "健康"
            }
        }

        var symbol: String {
            switch self {
            case .manual: return "hand.tap"
            case .healthKit: return "heart.text.square"
            }
        }
    }

    var id: UUID = UUID()
    /// 记录时间（一天内可以有多条，默认早晨空腹）
    var date: Date = Date()
    /// 体重，千克
    var weightKg: Double
    /// 体脂率，百分比，可选
    var bodyFatPercent: Double?
    var note: String = ""
    var source: Source = .manual
    /// 来自「健康」时保留原始样本 ID，用于导入去重
    var healthKitUUID: UUID?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        weightKg: Double,
        bodyFatPercent: Double? = nil,
        note: String = "",
        source: Source = .manual,
        healthKitUUID: UUID? = nil
    ) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
        self.bodyFatPercent = bodyFatPercent
        self.note = note
        self.source = source
        self.healthKitUUID = healthKitUUID
    }

    /// 同一天再次记录时，保留先录入的那条（多数是自动导入的健康数据）。
    var dayKey: Date { Calendar.current.startOfDay(for: date) }
}
