import SwiftUI

/// 极光背景。
///
/// 液态玻璃需要「有东西可折射」才好看，所以整个 App 底层都是这层缓慢流动的极光，
/// 玻璃卡片浮在它上面时才会有真实的光线弯折。
struct AuroraBackground: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { context in
            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height
                let t = context.date.timeIntervalSinceReferenceDate

                ZStack {
                    base
                    blob(square(w, h, nx: 0.20 + 0.10 * sin(t * 0.17),
                                    ny: 0.16 + 0.10 * cos(t * 0.23),
                                    scale: 0.95),
                         color: Theme.aqua, alpha: 0.55)
                    blob(square(w, h, nx: 0.88 + 0.10 * cos(t * 0.14),
                                    ny: 0.28 + 0.12 * sin(t * 0.19),
                                    scale: 1.00),
                         color: Theme.violet, alpha: 0.50)
                    blob(square(w, h, nx: 0.40 + 0.14 * sin(t * 0.11 + 1.2),
                                    ny: 0.84 + 0.10 * cos(t * 0.16),
                                    scale: 0.90),
                         color: Theme.mint, alpha: 0.45)
                    blob(square(w, h, nx: 0.72 + 0.10 * cos(t * 0.19 + 0.6),
                                    ny: 0.62 + 0.12 * sin(t * 0.13),
                                    scale: 0.55),
                         color: Theme.coral, alpha: 0.22)
                }
                .frame(width: w, height: h)
            }
        }
        .ignoresSafeArea()
    }

    private var base: some View {
        LinearGradient(
            colors: scheme == .dark
                ? [Color(red: 0.03, green: 0.04, blue: 0.09),
                   Color(red: 0.09, green: 0.06, blue: 0.18)]
                : [Color(red: 0.93, green: 0.95, blue: 1.00),
                   Color(red: 0.90, green: 0.92, blue: 0.99)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// 以 `nx` / `ny`（0…1 相对坐标）为中心、`scale` 为边长的正方形区域。
    private func square(_ w: CGFloat, _ h: CGFloat, nx: Double, ny: Double, scale: Double) -> CGRect {
        let side = Double(max(w, h)) * scale
        return CGRect(
            x: CGFloat(Double(w) * nx - side / 2),
            y: CGFloat(Double(h) * ny - side / 2),
            width: CGFloat(side),
            height: CGFloat(side)
        )
    }

    private func blob(_ rect: CGRect, color: Color, alpha: Double) -> some View {
        RadialGradient(
            colors: [color.opacity(alpha), color.opacity(alpha * 0.45), color.opacity(0)],
            center: .center,
            startRadius: 0,
            endRadius: rect.width / 2
        )
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .blendMode(scheme == .dark ? .plusLighter : .normal)
    }
}
