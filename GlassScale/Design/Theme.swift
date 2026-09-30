import SwiftUI

enum Theme {
    // 品牌色
    static let aqua = Color(red: 0.29, green: 0.72, blue: 0.98)
    static let violet = Color(red: 0.58, green: 0.40, blue: 0.97)
    static let mint = Color(red: 0.17, green: 0.85, blue: 0.66)
    static let coral = Color(red: 0.98, green: 0.47, blue: 0.42)

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
