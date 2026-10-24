import SwiftUI

/// 极光背景。
///
/// 液态玻璃需要「有东西可折射」才好看，所以整个 App 底层都是这层缓慢流动的极光，
/// 玻璃卡片浮在它上面时才会有真实的光线弯折。
///
/// 性能：色块只光栅化一次，流动靠位移动画（repeatForever，由渲染服务在 GPU 上合成），
/// 不再用 TimelineView 逐帧重绘全屏渐变，避免掉帧。
struct AuroraBackground: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var animate = false

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let side = max(w, h)

            ZStack {
                base
                blob(size: side * 0.95, color: Theme.aqua, alpha: 0.55,
                     at: CGPoint(x: w * 0.20, y: h * 0.16),
                     drift: CGSize(width: 46, height: 64), duration: 22)
                blob(size: side * 1.00, color: Theme.violet, alpha: 0.50,
                     at: CGPoint(x: w * 0.88, y: h * 0.28),
                     drift: CGSize(width: -52, height: 58), duration: 26)
                blob(size: side * 0.90, color: Theme.mint, alpha: 0.45,
                     at: CGPoint(x: w * 0.40, y: h * 0.84),
                     drift: CGSize(width: 60, height: -44), duration: 24)
                blob(size: side * 0.55, color: Theme.coral, alpha: 0.22,
                     at: CGPoint(x: w * 0.72, y: h * 0.62),
                     drift: CGSize(width: -40, height: -54), duration: 19)
            }
            .frame(width: w, height: h)
        }
        .ignoresSafeArea()
        .onAppear {
            if !reduceMotion { animate = true }
        }
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

    private func blob(
        size: CGFloat,
        color: Color,
        alpha: Double,
        at center: CGPoint,
        drift: CGSize,
        duration: Double
    ) -> some View {
        RadialGradient(
            colors: [color.opacity(alpha), color.opacity(alpha * 0.45), color.opacity(0)],
            center: .center,
            startRadius: 0,
            endRadius: size / 2
        )
        .frame(width: size, height: size)
        .position(center)
        .offset(x: animate ? drift.width : -drift.width,
                y: animate ? drift.height : -drift.height)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: duration).repeatForever(autoreverses: true),
            value: animate
        )
        .blendMode(scheme == .dark ? .plusLighter : .normal)
    }
}
