import SwiftUI

/// 达成里程碑时的庆祝浮层。
struct CelebrationView: View {
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
        ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

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

            card
                .scaleEffect(appeared ? 1 : 0.82)
                .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.bouncy(duration: 0.5)) { appeared = true }
        }
        .task {
            try? await Task.sleep(for: .seconds(3.2))
            onDismiss()
        }
    }

    private var card: some View {
        VStack(spacing: 16) {
            Image(systemName: milestone.symbol)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.brandGradient)
                .symbolEffect(.bounce, value: appeared)

            Text(milestone.title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text(milestone.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("继续", systemImage: "checkmark") {
                onDismiss()
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .tint(Theme.mint)
            .padding(.top, 4)
        }
        .padding(28)
        .frame(maxWidth: 300)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .padding(.horizontal, 40)
    }
}

/// 轻量提示条。
struct ToastView: View {
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
            .offset(y: appeared ? 0 : 16)
            .onAppear {
                withAnimation(.snappy) { appeared = true }
            }
    }
}
