import SwiftUI

/// 达成里程碑时的庆祝浮层。
struct CelebrationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var titleFocused: Bool
    let milestone: Milestone
    let onDismiss: () -> Void

    @State private var appeared = false

    private struct Confetto: Identifiable {
        let id = UUID()
        let symbol: String
        let color: Color
        let size: CGFloat
        let dx: CGFloat
        let lift: CGFloat
    }

    private let confetti: [Confetto] = [
        Confetto(symbol: "sparkle", color: Theme.mint, size: 16, dx: -70, lift: 160),
        Confetto(symbol: "star.fill", color: Theme.violet, size: 22, dx: 0, lift: 196),
        Confetto(symbol: "sparkle", color: Theme.aqua, size: 19, dx: 70, lift: 172),
        Confetto(symbol: "circle.fill", color: Theme.coral, size: 14, dx: -110, lift: 150),
        Confetto(symbol: "circle.fill", color: Theme.mint, size: 17, dx: 110, lift: 184)
    ]

    var body: some View {
        GeometryReader { proxy in
          ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
                .accessibilityHidden(true)

            if !reduceMotion {
            ZStack {
                ForEach(confetti) { item in
                    Image(systemName: item.symbol)
                        .font(.system(size: item.size, weight: .bold))
                        .foregroundStyle(item.color)
                        .offset(x: appeared ? item.dx * 1.4 : 0,
                                y: appeared ? -item.lift : 0)
                        .opacity(appeared ? 0 : 1)
                        .scaleEffect(appeared ? 0.4 : 1)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            }

            card
                .frame(maxHeight: min(proxy.size.height - 32, dynamicTypeSize.isAccessibilitySize ? proxy.size.height - 32 : 400))
                .scaleEffect(reduceMotion || appeared ? 1 : 0.92)
                .opacity(appeared ? 1 : 0)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) { appeared = true }
        }
        .sensoryFeedback(.success, trigger: appeared)
        .task {
            titleFocused = true
        }
    }

    private var card: some View {
        ScrollView {
          VStack(spacing: AppDesign.Space.lg) {
            Image(systemName: milestone.symbol)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(AppDesign.Palette.action)
                .symbolEffect(.bounce, value: reduceMotion ? false : appeared)
                .accessibilityHidden(true)

            Text(milestone.title)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader).accessibilityFocused($titleFocused)

            Text(milestone.detail)
                .font(.subheadline)
                .foregroundStyle(AppDesign.Palette.secondaryText)
                .multilineTextAlignment(.center)

            Button("继续", systemImage: "checkmark") {
                onDismiss()
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .padding(.top, 4)
        }
          .padding(AppDesign.Space.section)
        }
        .scrollBounceBehavior(.basedOnSize).scrollIndicators(.hidden)
        .foregroundStyle(AppDesign.Palette.primaryText)
        .frame(maxWidth: 520)
        .background(AppDesign.Palette.surface, in: RoundedRectangle(cornerRadius: AppDesign.Radius.hero, style: .continuous))
        .padding(.horizontal, AppDesign.Space.page)
        .accessibilityAddTraits(.isModal)
    }
}

/// 轻量提示条。
struct ToastView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let text: String
    @State private var appeared = false

    var body: some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(maxWidth: 320)
            .glassEffect(.regular, in: .capsule)
            .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
            .opacity(appeared ? 1 : 0)
            .offset(y: reduceMotion || appeared ? 0 : 16)
            .onAppear {
                withAnimation(reduceMotion ? nil : .snappy) { appeared = true }
            }
    }
}
