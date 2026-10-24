import SwiftUI

/// Decorative, scalable hydration companion. The adjacent text owns the exact amount/status.
struct WaterCupView: View {
    var progress: Double
    var isAcknowledging: Bool = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var level: CGFloat { progress.isFinite ? CGFloat(min(1, max(0, progress))) : 0 }
    private var full: Bool { level >= 1 }
    private var ink: Color {
        scheme == .dark && level < 0.58 ? .white.opacity(0.92) : Color(red: 0.05, green: 0.25, blue: 0.34)
    }
    private var rim: Color { Color(red: 0.34, green: 0.67, blue: 0.79).opacity(scheme == .dark ? 0.9 : 0.65) }

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 100, proxy.size.height / 110)
            illustration
                .frame(width: 100, height: 110)
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private var illustration: some View {
        ZStack {
            Ellipse().fill(Color.cyan.opacity(scheme == .dark ? 0.13 : 0.10))
                .frame(width: 68, height: 7).offset(y: 47)
            arms.fill(LinearGradient(colors: [.white.opacity(0.75), Color.cyan.opacity(0.3)], startPoint: .top, endPoint: .bottom))
                .overlay { arms.stroke(rim, lineWidth: 1) }
            CupOutline()
                .fill(LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.32 : 0.72),
                                             Color.cyan.opacity(scheme == .dark ? 0.10 : 0.05)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            CupWater(level: level, ripple: isAcknowledging && !reduceMotion ? 2 : 0)
                .fill(LinearGradient(colors: [Color(red: 0.50, green: 0.88, blue: 0.96),
                                             Color(red: 0.27, green: 0.75, blue: 0.87).opacity(0.8)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay {
                    CupWater(level: level, ripple: isAcknowledging && !reduceMotion ? 2 : 0)
                        .stroke(.white.opacity(0.55), lineWidth: 1)
                }
                .clipShape(CupOutline())
                .animation(reduceMotion ? nil : AppDesign.Motion.progress, value: level)
                .animation(reduceMotion ? nil : AppDesign.Motion.state, value: isAcknowledging)
            CupOutline().stroke(rim, lineWidth: 1.15)
            CupOutline().stroke(.white.opacity(scheme == .dark ? 0.38 : 0.8), lineWidth: 0.45).padding(1.5)
            Ellipse().fill(.white.opacity(scheme == .dark ? 0.12 : 0.60))
                .overlay { Ellipse().stroke(rim, lineWidth: 1) }
                .frame(width: 54, height: 12).position(x: 50, y: 24)
            highlights.stroke(.white.opacity(scheme == .dark ? 0.6 : 0.85), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            face
        }
        .scaleEffect(isAcknowledging && !reduceMotion ? 1.035 : 1)
        .rotationEffect(.degrees(isAcknowledging && !reduceMotion ? -3 : 0), anchor: .bottom)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.72), value: isAcknowledging)
    }

    private var arms: Path {
        Path { path in
            let lift: CGFloat = full ? -8 : 0
            path.move(to: CGPoint(x: 18, y: 56))
            path.addQuadCurve(to: CGPoint(x: 8, y: 68 + lift), control: CGPoint(x: 3, y: 60 + lift))
            path.addQuadCurve(to: CGPoint(x: 17, y: 70), control: CGPoint(x: 10, y: 77 + lift))
            path.closeSubpath()
            path.move(to: CGPoint(x: 82, y: 56))
            path.addQuadCurve(to: CGPoint(x: 92, y: 68 + lift), control: CGPoint(x: 97, y: 60 + lift))
            path.addQuadCurve(to: CGPoint(x: 83, y: 70), control: CGPoint(x: 90, y: 77 + lift))
            path.closeSubpath()
        }
    }

    private var highlights: Path {
        Path { path in
            path.move(to: CGPoint(x: 25, y: 39))
            path.addQuadCurve(to: CGPoint(x: 21, y: 56), control: CGPoint(x: 22, y: 46))
            path.move(to: CGPoint(x: 69, y: 89))
            path.addQuadCurve(to: CGPoint(x: 77, y: 80), control: CGPoint(x: 76, y: 86))
        }
    }

    private var face: some View {
        ZStack {
            if full {
                Path { path in
                    for x in [CGFloat(39), CGFloat(61)] {
                        path.move(to: CGPoint(x: x - 3.2, y: 64))
                        path.addQuadCurve(to: CGPoint(x: x + 3.2, y: 64), control: CGPoint(x: x, y: 56))
                    }
                }.stroke(ink, style: StrokeStyle(lineWidth: 2.3, lineCap: .round))
            } else {
                ForEach([39, 61], id: \.self) { x in
                    Ellipse().fill(ink).frame(width: 5.2, height: 7.2).position(x: CGFloat(x), y: 62)
                    Circle().fill(.white.opacity(0.9)).frame(width: 1.6, height: 1.6).position(x: CGFloat(x) - 0.6, y: 60.4)
                }
            }
            Ellipse().fill(Color(red: 1, green: 0.70, blue: 0.65).opacity(0.8))
                .frame(width: 10, height: 4.5).position(x: 29, y: 70)
            Ellipse().fill(Color(red: 1, green: 0.70, blue: 0.65).opacity(0.8))
                .frame(width: 10, height: 4.5).position(x: 71, y: 70)
            Path { path in
                path.move(to: CGPoint(x: 45, y: 69))
                path.addQuadCurve(to: CGPoint(x: 55, y: 69), control: CGPoint(x: 50, y: 77))
            }.stroke(ink, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }
}

private struct CupOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 23, y: 24))
        path.addQuadCurve(to: CGPoint(x: 77, y: 24), control: CGPoint(x: 50, y: 16))
        path.addCurve(to: CGPoint(x: 84, y: 75), control1: CGPoint(x: 81, y: 43), control2: CGPoint(x: 89, y: 60))
        path.addCurve(to: CGPoint(x: 50, y: 99), control1: CGPoint(x: 81, y: 94), control2: CGPoint(x: 68, y: 99))
        path.addCurve(to: CGPoint(x: 16, y: 75), control1: CGPoint(x: 32, y: 99), control2: CGPoint(x: 19, y: 94))
        path.addCurve(to: CGPoint(x: 23, y: 24), control1: CGPoint(x: 11, y: 60), control2: CGPoint(x: 19, y: 43))
        path.closeSubpath()
        return path.applying(CGAffineTransform(scaleX: rect.width / 100, y: rect.height / 110))
    }
}

private struct CupWater: Shape {
    var level: CGFloat
    var ripple: CGFloat
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(level, ripple) }
        set { level = newValue.first; ripple = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        guard level > 0 else { return Path() }
        let y = 96 - min(1, max(0, level)) * 66
        var path = Path()
        path.move(to: CGPoint(x: 8, y: y))
        path.addCurve(to: CGPoint(x: 92, y: y), control1: CGPoint(x: 33, y: y - 3 - ripple), control2: CGPoint(x: 66, y: y + 3 + ripple))
        path.addLine(to: CGPoint(x: 92, y: 104))
        path.addLine(to: CGPoint(x: 8, y: 104))
        path.closeSubpath()
        return path.applying(CGAffineTransform(scaleX: rect.width / 100, y: rect.height / 110))
    }
}
