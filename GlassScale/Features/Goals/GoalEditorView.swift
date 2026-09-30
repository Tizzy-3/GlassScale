import SwiftUI

/// 设置减重 / 增重目标。
struct GoalEditorView: View {
    @Environment(WeightStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var targetText: String = ""
    @State private var targetDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var didLoad = false
    @State private var hasGoal = false

    private var unit: WeightUnit { store.unit }

    private var targetKg: Double {
        let cleaned = targetText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let v = Double(cleaned) else { return 0 }
        return unit.kilograms(for: v)
    }

    private var isValid: Bool { targetKg > 20 && targetKg < 400 }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        summaryCard
                        targetCard
                        deadlineCard
                    }
                    .padding(Theme.pagePadding)
                }
            }
            .navigationTitle("目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", systemImage: "checkmark") {
                        store.setGoal(targetWeightKg: targetKg, targetDate: targetDate)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
                if hasGoal {
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive) {
                            store.setGoal(targetWeightKg: nil, targetDate: nil)
                            dismiss()
                        } label: {
                            Label("清除目标", systemImage: "trash")
                        }
                    }
                }
            }
            .onAppear(perform: load)
        }
        .presentationDetents([.large])
    }

    private var summaryCard: some View {
        GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 18) {
            VStack(spacing: 14) {
                if let goal = store.goal {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("当前进度").font(.caption).foregroundStyle(.secondary)
                            Text("\(Int((store.stats.progress(goal: goal, baselineKg: store.baselineKg) ?? 0) * 100))%")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                        }
                        Spacer()
                        if let remaining = store.stats.remainingKg(to: goal) {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("还差").font(.caption).foregroundStyle(.secondary)
                                Text("\(Fmt.weight(remaining, unit)) \(unit.symbol)")
                                    .font(.headline.weight(.semibold))
                            }
                        }
                    }
                    Divider().overlay(.white.opacity(0.1))
                }

                if let start = store.baselineKg {
                    HStack {
                        Label("起点", systemImage: "flag")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Fmt.weight(start, unit)) \(unit.symbol)")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var targetCard: some View {
        GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 20, tint: Theme.mint.opacity(0.3)) {
            VStack(spacing: 14) {
                Text("目标体重")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TextField("0.0", text: $targetText)
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 170)
                    Text(unit.symbol)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 18) {
                    GlassEffectContainer(spacing: 14) {
                        HStack(spacing: 10) {
                            step(symbol: "minus", delta: -unit.step)
                            step(symbol: "plus", delta: unit.step)
                        }
                    }
                    if let current = store.stats.currentKg {
                        Button("用当前体重") {
                            targetText = Fmt.number(unit.value(forKg: current), decimals: 1)
                        }
                        .font(.caption)
                        .buttonStyle(.glass)
                        .buttonBorderShape(.capsule)
                    }
                }
            }
        }
    }

    private func step(symbol: String, delta: Double) -> some View {
        Button {
            let stepped = targetKg + unit.kilograms(for: delta)
            targetText = Fmt.number(unit.value(forKg: stepped), decimals: 1)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
    }

    private var deadlineCard: some View {
        GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 18) {
            VStack(spacing: 14) {
                DatePicker(selection: $targetDate, in: Date()..., displayedComponents: .date) {
                    Label("目标日期", systemImage: "calendar")
                        .font(.subheadline.weight(.medium))
                }

                if let projected = store.stats.projectedGoalDate(
                    goal: WeightGoal(targetWeightKg: targetKg, targetDate: targetDate),
                    baselineKg: store.baselineKg
                ) {
                    Divider().overlay(.white.opacity(0.1))
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                        Text("按目前速度，其实 \(projected.formatted(.dateTime.year().month().day())) 就能到")
                            .font(.caption)
                    }
                    .foregroundStyle(Theme.mint)
                }
            }
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if let goal = store.goal {
            targetText = Fmt.number(unit.value(forKg: goal.targetWeightKg), decimals: 1)
            targetDate = max(goal.targetDate, Date())
            hasGoal = true
        } else if let current = store.stats.currentKg {
            targetText = Fmt.number(unit.value(forKg: (current - 5).rounded()), decimals: 1)
        }
    }
}
