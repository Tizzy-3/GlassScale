import Foundation

/// 同一天记录多次时，日均值和趋势图采用的代表记录。
enum DailyWeightPolicy: String, Codable, Hashable, Identifiable, CaseIterable {
    case latest
    case earliest
    case lowest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .latest: return "当天最后一次"
        case .earliest: return "当天第一次"
        case .lowest: return "当天最低体重"
        }
    }
}
