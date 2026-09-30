import Foundation

/// 体重显示单位。数据层永远存千克，这里只负责换算与显示。
enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case kilograms
    case jin
    case pounds

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kilograms: return "公斤"
        case .jin: return "市斤"
        case .pounds: return "磅"
        }
    }

    /// 紧凑符号，用于图表轴与角标
    var symbol: String {
        switch self {
        case .kilograms: return "kg"
        case .jin: return "斤"
        case .pounds: return "lb"
        }
    }

    /// 1 个该单位等于多少克
    private var grams: Double {
        switch self {
        case .kilograms: return 1000
        case .jin: return 500
        case .pounds: return 453.592_37
        }
    }

    /// 一次显示的最小步长
    var step: Double {
        switch self {
        case .kilograms, .jin: return 0.1
        case .pounds: return 0.2
        }
    }

    private var stepKilograms: Double {
        switch self {
        case .kilograms, .jin: return 0.1
        case .pounds: return 0.1
        }
    }

    /// 千克 → 显示值
    func value(forKg kg: Double) -> Double { kg * 1000 / grams }

    /// 显示值 → 千克
    func kilograms(for value: Double) -> Double { value * grams / 1000 }

    /// 把显示值按步长对齐（用户用 + / − 按钮微调时用）
    func snap(_ value: Double) -> Double {
        let step = self.step
        return (value / step).rounded() * step
    }

    /// 对应的千克步长，供 `WeightUnit` 内部换算使用。
    func snappedKilograms(fromKg kg: Double) -> Double {
        let stepKg = stepKilograms
        return (kg / stepKg).rounded() * stepKg
    }
}

/// 身高显示单位。
enum LengthUnit: String, Codable, CaseIterable, Identifiable {
    case centimeters
    case inches

    var id: String { rawValue }

    var title: String {
        switch self {
        case .centimeters: return "厘米"
        case .inches: return "英寸"
        }
    }

    var symbol: String {
        switch self {
        case .centimeters: return "cm"
        case .inches: return "in"
        }
    }

    func value(forCm cm: Double) -> Double {
        switch self {
        case .centimeters: return cm
        case .inches: return cm / 2.54
        }
    }

    func centimeters(for value: Double) -> Double {
        switch self {
        case .centimeters: return value
        case .inches: return value * 2.54
        }
    }
}

/// 用户偏好。
struct AppSettings: Codable, Hashable {
    var weightUnit: WeightUnit = .kilograms
    var lengthUnit: LengthUnit = .centimeters

    /// 主题
    var theme: AppTheme = .ocean

    /// 保存时一并写入「健康」
    var syncWriteToHealth: Bool = false
    /// 启动时尝试从「健康」拉取新数据
    var syncReadFromHealth: Bool = false

    var hasCompletedOnboarding: Bool = false
    /// 首页是否显示浮动操作按钮
    var showsDemoData: Bool = true
}

// MARK: - 格式化

enum Fmt {
    /// 体重数值，保留 1 位小数
    static func weight(_ kg: Double?, _ unit: WeightUnit, decimals: Int = 1) -> String {
        guard let kg else { return "—" }
        return number(unit.value(forKg: kg), decimals: decimals)
    }

    /// 带符号的差值，例如 +1.2 / −0.8
    static func signedWeight(_ kg: Double?, _ unit: WeightUnit, decimals: Int = 1) -> String {
        guard let kg else { return "—" }
        let v = unit.value(forKg: kg)
        let sign = v > 0 ? "+" : (v < 0 ? "−" : "")
        return sign + number(abs(v), decimals: decimals)
    }

    static func height(_ cm: Double, _ unit: LengthUnit, decimals: Int = 0) -> String {
        number(unit.value(forCm: cm), decimals: decimals)
    }

    static func bmi(_ value: Double?) -> String {
        guard let value else { return "—" }
        return number(value, decimals: 1)
    }

    static func number(_ value: Double, decimals: Int) -> String {
        String(format: "%.\(decimals)f", value)
    }
}
