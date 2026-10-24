import SwiftUI

/// 今日喝水：简短进度和杯量操作，周统计放在明细页。
struct WaterCard: View {
    @Environment(WeightStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title) private var readingSize: CGFloat = 28
    @State private var showGoalSheet = false
    @State private var showCustomSheet = false
    @State private var showHistory = false
    @State private var showCups = false

    private var drunk: Int { store.todayWaterMl }
    private var goal: Int { store.settings.waterGoalMl }
    private var progress: Double { goal > 0 ? min(1, Double(drunk) / Double(goal)) : 0 }

    var body: some View {
        ContentCard(cornerRadius: Theme.cardCorner, contentPadding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 6) { title; actions }
                } else {
                    HStack { title; Spacer(minLength: 4); actions }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) { reading; Spacer(); status }
                    VStack(alignment: .leading, spacing: 6) { reading; status }
                }
                progressBar
                quickButtons
            }
        }
        .sheet(isPresented: $showGoalSheet) { WaterGoalSheet() }
        .sheet(isPresented: $showCustomSheet) { WaterEntryEditorView() }
        .sheet(isPresented: $showHistory) { WaterHistoryView() }
        .sheet(isPresented: $showCups) { WaterCupSettingsView() }
    }

    private var title: some View {
        Label("今日喝水", systemImage: "drop.fill").font(.headline)
            .foregroundStyle(Theme.aqua)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button { showHistory = true } label: {
                Text("详情").font(.subheadline.weight(.medium)).padding(.horizontal, 8).frame(minHeight: 30)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("喝水明细与补录")
            Menu {
                Button("设置喝水目标", systemImage: "target") { showGoalSheet = true }
                Button("常用杯量", systemImage: "cup.and.saucer") { showCups = true }
                if !store.todayWaterEntries.isEmpty {
                    Button("撤销今日最后一笔", systemImage: "arrow.uturn.backward") { store.undoLastWater() }
                }
            } label: {
                Image(systemName: "ellipsis").font(.subheadline.weight(.semibold)).frame(width: 32, height: 32)
            }
            .buttonStyle(.glass).buttonBorderShape(.circle).accessibilityLabel("喝水设置与撤销")
        }
    }

    private var reading: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(drunk)").font(.system(size: readingSize, weight: .semibold, design: .rounded))
                .monospacedDigit().contentTransition(reduceMotion ? .identity : .numericText())
            Text("/ \(goal) ml").font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var status: some View {
        Text(progress >= 1 ? "今日已达标" : "\(Int(progress * 100))%")
            .font(.caption.weight(.medium)).foregroundStyle(progress >= 1 ? Theme.mint : .secondary)
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.secondary.opacity(0.12))
                Capsule().fill(Theme.accentGradient).frame(width: proxy.size.width * progress)
                    .animation(reduceMotion ? nil : .snappy, value: progress)
            }
        }
        .frame(height: 7)
        .accessibilityLabel("今日喝水完成百分之\(Int(progress * 100))")
    }

    private var quickButtons: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 170 : 84), spacing: 8)], spacing: 8) {
            ForEach(store.settings.waterCupSizes, id: \.self) { ml in
                Button { store.logWater(ml: ml) } label: {
                    Text("+\(ml) ml").font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.glass)
            }
            Button { showCustomSheet = true } label: {
                Text("自定义").font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.glass)
        }
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
                    ContentCard(cornerRadius: Theme.cardCorner, contentPadding: 18) {
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
