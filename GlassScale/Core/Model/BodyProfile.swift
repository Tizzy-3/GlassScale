import Foundation

/// 身体档案，只在本机保存。
struct BodyProfile: Codable, Hashable {
    enum Sex: String, Codable, CaseIterable, Identifiable {
        case female
        case male
        case unspecified

        var id: String { rawValue }

        var title: String {
            switch self {
            case .female: return "女"
            case .male: return "男"
            case .unspecified: return "不填"
            }
        }
    }

    /// 身高，厘米
    var heightCm: Double = 170
    var age: Int? = nil
    var sex: Sex = .unspecified
    /// 引导页里填的初始体重，千克（用于计算减重进度）
    var baselineKg: Double? = nil

    func bmi(weightKg: Double) -> Double? {
        guard heightCm > 50 else { return nil }
        let meters = heightCm / 100
        return weightKg / (meters * meters)
    }

    /// 偏瘦 / 正常 / 偏胖 / 肥胖
    func bmiCategory(_ bmi: Double) -> (title: String, symbol: String) {
        switch bmi {
        case ..<18.5: return ("偏瘦", "figure.walk")
        case ..<24: return ("正常", "checkmark.seal.fill")
        case ..<28: return ("偏胖", "exclamationmark.triangle.fill")
        default: return ("肥胖", "exclamationmark.octagon.fill")
        }
    }
}
