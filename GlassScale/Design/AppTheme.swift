import SwiftUI

/// 可选主题。每套主题定义四个语义色：
///
/// - primary：品牌主色（按钮、强调、tint）
/// - success：健康/正向（减重、达标）
/// - accent：点缀色（数据、导出）
/// - danger：警示/删除
enum AppTheme: String, Codable, CaseIterable, Identifiable, Hashable {
    case ocean
    case sunset
    case forest
    case grape
    case sakura

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ocean: return "海洋"
        case .sunset: return "落日"
        case .forest: return "森林"
        case .grape: return "葡萄"
        case .sakura: return "樱花"
        }
    }

    var primary: Color {
        switch self {
        case .ocean: return Color(red: 0.29, green: 0.72, blue: 0.98)
        case .sunset: return Color(red: 0.98, green: 0.58, blue: 0.24)
        case .forest: return Color(red: 0.28, green: 0.68, blue: 0.42)
        case .grape: return Color(red: 0.60, green: 0.42, blue: 0.96)
        case .sakura: return Color(red: 0.94, green: 0.54, blue: 0.64)
        }
    }

    var success: Color {
        switch self {
        case .ocean: return Color(red: 0.17, green: 0.85, blue: 0.66)
        case .sunset: return Color(red: 0.30, green: 0.75, blue: 0.55)
        case .forest: return Color(red: 0.52, green: 0.82, blue: 0.42)
        case .grape: return Color(red: 0.32, green: 0.80, blue: 0.64)
        case .sakura: return Color(red: 0.38, green: 0.76, blue: 0.60)
        }
    }

    var accent: Color {
        switch self {
        case .ocean: return Color(red: 0.58, green: 0.40, blue: 0.97)
        case .sunset: return Color(red: 0.93, green: 0.36, blue: 0.55)
        case .forest: return Color(red: 0.94, green: 0.72, blue: 0.28)
        case .grape: return Color(red: 0.94, green: 0.46, blue: 0.68)
        case .sakura: return Color(red: 0.64, green: 0.54, blue: 0.94)
        }
    }

    var danger: Color {
        switch self {
        case .ocean: return Color(red: 0.98, green: 0.47, blue: 0.42)
        case .sunset: return Color(red: 0.93, green: 0.32, blue: 0.32)
        case .forest: return Color(red: 0.94, green: 0.44, blue: 0.36)
        case .grape: return Color(red: 0.96, green: 0.44, blue: 0.44)
        case .sakura: return Color(red: 0.94, green: 0.42, blue: 0.42)
        }
    }

    /// 主题选择器预览用色条
    var swatches: [Color] { [primary, success, accent] }
}
