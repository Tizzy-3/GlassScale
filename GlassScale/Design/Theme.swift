import SwiftUI

enum Theme {
    /// 当前主题。WeightStore 在启动和切换主题时同步，界面通过 `.id(theme)` 重建来换肤。
    /// 对外仍暴露 aqua/violet/mint/coral 四个名字，调用方不用改。
    static var current: AppTheme = .ocean

    // 品牌色
    static var aqua: Color { current.primary }
    static var violet: Color { current.accent }
    static var mint: Color { current.success }
    static var coral: Color { current.danger }

    // 圆角
    static let heroCorner: CGFloat = 34
    static let cardCorner: CGFloat = 26
    static let tileCorner: CGFloat = 22
    static let chipCorner: CGFloat = 16

    // 间距
    static let pagePadding: CGFloat = 20

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [aqua, mint],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [aqua, violet],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// 涨（变重）用珊瑚色，跌（变轻）用薄荷绿
    static func deltaColor(_ deltaKg: Double?) -> Color {
        guard let deltaKg, abs(deltaKg) > 0.05 else { return .secondary }
        return deltaKg > 0 ? coral : mint
    }
}

extension Color {
    /// 深色模式下提高前景可读性
    static let glassStroke = Color.white.opacity(0.16)
}
