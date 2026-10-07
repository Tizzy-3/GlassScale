import SwiftUI

/// 首页喝水卡片：今日进度 + 一键记录 + 近 7 天小统计。
struct WaterCard: View {
    @Environment(WeightStore.self) private var store
    @State private var showGoalSheet = false
    @State private var showCustomSheet = false

    private var drunk: Int { store.todayWaterMl }
    private var goal: Int { store.settings.waterGoalMl }
    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(1, Double(drunk) / Double(goal))
    }

    var body: some View {
        GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                header
                numberRow
                progressBar
                quickButtons
                weekStrip
            }
        }
        .sheet(isPresented: $showGoalSheet) { WaterGoalSheet() }
        .sheet(isPresented: $showCustomSheet) { WaterCustomSheet() }
    }

    // MARK: - 标题行

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "drop.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.aqua)
            Text("今日喝水")
                .font(.headline)
            Spacer(minLength: 8)
            if !store.todayWaterEntries.isEmpty {
                Button("撤销") { store.undoLastWater() }
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button { showGoalSheet = true } label: {
                Image(systemName: "gearshape")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("设置喝水目标")
        }
    }

    // MARK: - 数字行

    private var numberRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(drunk)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            Text("/ \(goal) ml")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if progress >= 1 {
                Label("已达标", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.mint)
            } else {
                Text("\(Int(progress * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
    }

    // MARK: - 进度条

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.secondary.opacity(0.15))
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.aqua, Theme.mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(12, proxy.size.width * progress))
                    .animation(.snappy, value: progress)
            }
        }
        .frame(height: 10)
    }

    // MARK: - 快捷记录

    private var quickButtons: some View {
        HStack(spacing: 10) {
            quickButton(title: "+250 ml", ml: 250)
            quickButton(title: "+500 ml", ml: 500)
            Button { showCustomSheet = true } label: {
                Text("自定义")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.glass)
        }
    }

    private func quickButton(title: String, ml: Int) -> some View {
        Button { store.logWater(ml: ml) } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.glass)
    }

    // MARK: - 近 7 天

    private var weekStrip: some View {
        let days = store.waterMlByDay(lastDays: 7)
        let goal = max(1, store.settings.waterGoalMl)
        return VStack(alignment: .leading, spacing: 8) {
            Text("近 7 天")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(days.indices, id: \.self) { i in
                    let item = days[i]
                    let isToday = i == days.count - 1
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(
                                item.ml > 0
                                    ? (isToday ? Theme.aqua : Theme.aqua.opacity(0.55))
                                    : .secondary.opacity(0.18)
                            )
                            .frame(height: max(4, CGFloat(min(1.0, Double(item.ml) / Double(goal))) * 44))
                        Text(weekdayLabel(for: item.date, isToday: isToday))
                            .font(.caption2)
                            .foregroundStyle(isToday ? Theme.aqua : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func weekdayLabel(for date: Date, isToday: Bool) -> String {
        if isToday { return "今" }
        let w = Calendar.current.component(.weekday, from: date) // 1 = 周日
        return ["日", "一", "二", "三", "四", "五", "六"][w - 1]
    }
}

// MARK: - 目标设置

/// 每日喝水目标设置。
struct WaterGoalSheet: View {
    @Environment(WeightStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var goal: Int = 2000

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                VStack(spacing: 18) {
                    GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 18) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("每日喝水目标")
                                .font(.headline)
                            Stepper("\(goal) ml", value: $goal, in: 500...6000, step: 250)
                                .font(.title3.weight(.semibold))
                            Text("一般建议每天 1500–2500 ml，运动量大或天气热可以适当增加。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(Theme.pagePadding)
            }
            .navigationTitle("喝水目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.setWaterGoalMl(goal)
                        dismiss()
                    }
                }
            }
            .onAppear { goal = store.settings.waterGoalMl }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 自定义水量

/// 自定义一次喝了多少。
struct WaterCustomSheet: View {
    @Environment(WeightStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var ml: Int = 300

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                VStack(spacing: 18) {
                    GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 18) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("这次喝了多少？")
                                .font(.headline)
                            Stepper("\(ml) ml", value: $ml, in: 50...2000, step: 50)
                                .font(.title3.weight(.semibold))
                            Text("一杯水约 250 ml，一瓶矿泉水约 500 ml。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(Theme.pagePadding)
            }
            .navigationTitle("记录喝水")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.logWater(ml: ml)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
