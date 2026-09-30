import SwiftUI

/// 常驻在标签栏上方的玻璃快捷条：一眼看到今天的体重，± 微调后直接保存。
struct QuickLogBar: View {
    @Environment(WeightStore.self) private var store
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    @State private var draftKg: Double = 70
    @State private var seeded = false
    @State private var justSaved = false

    private var unit: WeightUnit { store.unit }
    private var displayValue: Double { unit.value(forKg: draftKg) }

    var body: some View {
        HStack(spacing: 12) {
            weightReadout

            GlassEffectContainer(spacing: 14) {
                HStack(spacing: 8) {
                    stepButton(symbol: "minus", delta: -unit.step)
                    stepButton(symbol: "plus", delta: unit.step)
                }
            }

            Button(action: save) {
                Label {
                    Text(justSaved ? "已记录" : "记一笔")
                } icon: {
                    Image(systemName: justSaved ? "checkmark" : "arrow.down")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .tint(justSaved ? Theme.mint : Theme.aqua)
            .frame(maxWidth: 150)
            .animation(.snappy, value: justSaved)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .opacity(placement == .inline ? 0.0 : 1.0)
        .allowsHitTesting(placement != .inline)
        .animation(.easeInOut(duration: 0.2), value: placement)
        .onAppear { seedIfNeeded() }
        .onChange(of: store.entries.count) { _, _ in seedIfNeeded() }
        .onChange(of: store.settings.weightUnit) { _, _ in seedIfNeeded(force: true) }
    }

    private var weightReadout: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(store.todayEntry == nil ? "上次" : "今天")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(Fmt.number(displayValue, decimals: 1))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text(unit.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 86, alignment: .leading)
    }

    private func stepButton(symbol: String, delta: Double) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                let stepped = displayValue + delta
                draftKg = unit.snappedKilograms(fromKg: unit.kilograms(for: stepped))
            }
            justSaved = false
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 38, height: 38)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(delta > 0 ? "增加 \(Fmt.number(delta, decimals: 1)) \(unit.symbol)" : "减少 \(Fmt.number(-delta, decimals: 1)) \(unit.symbol)")
    }

    private func seedIfNeeded(force: Bool = false) {
        guard force || !seeded else { return }
        if let today = store.todayEntry {
            draftKg = today.weightKg
        } else if let last = store.entries.last {
            draftKg = last.weightKg
        } else if let baseline = store.profile.baselineKg {
            draftKg = baseline
        }
        seeded = true
    }

    private func save() {
        let value = unit.snappedKilograms(fromKg: draftKg)
        guard value > 20, value < 400 else { return }

        store.save(entry: WeightEntry(date: Date(), weightKg: value))
        draftKg = value
        withAnimation(.snappy) { justSaved = true }

        Task {
            if store.settings.syncWriteToHealth {
                try? await store.health.save(weightKg: value, at: Date())
            }
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.snappy) { justSaved = false }
        }
    }
}
