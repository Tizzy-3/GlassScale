import SwiftUI

/// Existing water actions with success-only visual feedback; persistence stays in WeightStore.
struct WaterCard: View {
    @Environment(WeightStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title) private var readingSize = AppDesign.TypeScale.waterSize
    @State private var showGoalSheet = false
    @State private var showCustomSheet = false
    @State private var showHistory = false
    @State private var showCups = false
    @State private var isAcknowledging = false
    @State private var acknowledgment = 0
    @State private var lastCupMl = 0

    private var drunk: Int { store.todayWaterMl }
    private var goal: Int { store.settings.waterGoalMl }
    private var progress: Double { goal > 0 ? min(1, Double(drunk) / Double(goal)) : 0 }

    var body: some View {
        AppSurface(.hydration) {
            VStack(alignment: .leading, spacing: AppDesign.Space.md) {
                if dynamicTypeSize.isAccessibilitySize {
                    summary
                    WaterCupView(progress: progress, isAcknowledging: isAcknowledging).frame(width: 80, height: 88)
                } else {
                    HStack(spacing: AppDesign.Space.md) {
                        summary
                        WaterCupView(progress: progress, isAcknowledging: isAcknowledging).frame(width: 80, height: 88)
                    }
                }
                progressBar
                quickButtons
            }
        }
        .animation(reduceMotion ? nil : AppDesign.Motion.progress, value: drunk)
        .sensoryFeedback(.selection, trigger: acknowledgment)
        .task(id: acknowledgment) {
            guard acknowledgment > 0 else { return }
            do { try await Task.sleep(for: .seconds(1.6)) } catch { return }
            withAnimation(reduceMotion ? nil : AppDesign.Motion.state) { isAcknowledging = false }
        }
        .sheet(isPresented: $showGoalSheet) { WaterGoalSheet() }
        .sheet(isPresented: $showCustomSheet) { WaterEntryEditorView() }
        .sheet(isPresented: $showHistory) { WaterHistoryView() }
        .sheet(isPresented: $showCups) { WaterCupSettingsView() }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: AppDesign.Space.xs) {
            HStack(spacing: AppDesign.Space.xs) {
                Button { showHistory = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "drop.fill").accessibilityHidden(true)
                        Text("今日喝水")
                        Image(systemName: "chevron.right").font(.caption2).accessibilityHidden(true)
                    }
                    .font(.headline).foregroundStyle(AppDesign.Palette.primaryText)
                    .frame(minHeight: AppDesign.Control.minimumTarget)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("今日喝水明细与补录")
                Spacer(minLength: 0)
                Menu {
                    Button("设置喝水目标", systemImage: "target") { showGoalSheet = true }
                    Button("常用杯量", systemImage: "cup.and.saucer") { showCups = true }
                    if !store.todayWaterEntries.isEmpty {
                        Button("撤销今日最后一笔", systemImage: "arrow.uturn.backward") { store.undoLastWater() }
                    }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: AppDesign.Control.iconSize, weight: .semibold))
                        .frame(width: AppDesign.Control.minimumTarget, height: AppDesign.Control.minimumTarget)
                        .foregroundStyle(AppDesign.Palette.action).contentShape(.rect)
                }
                .accessibilityLabel("喝水设置与撤销")
            }
            reading
            if isAcknowledging {
                Label("已记录 \(lastCupMl) ml", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(AppDesign.Palette.success)
            } else {
                Text(progress >= 1 ? "今日已达标" : "已完成 \(Int(progress * 100))%")
                    .font(.caption).foregroundStyle(AppDesign.Palette.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var reading: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: AppDesign.Space.xs) {
                amount.font(.largeTitle.weight(.semibold))
                goalText
            }
            .accessibilityElement(children: .ignore).accessibilityLabel("今日喝水 \(drunk) 毫升，目标 \(goal) 毫升")
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 4) { amount.font(.system(size: readingSize, weight: .semibold, design: .rounded)); goalText }
                VStack(alignment: .leading, spacing: 4) { amount.font(.system(size: readingSize, weight: .semibold, design: .rounded)); goalText }
            }
            .accessibilityElement(children: .ignore).accessibilityLabel("今日喝水 \(drunk) 毫升，目标 \(goal) 毫升")
        }
    }

    private var amount: some View {
        Text(drunk.formatted())
            .monospacedDigit()
            .contentTransition(reduceMotion ? .identity : .numericText())
    }

    private var goalText: some View {
        Text("/ \(goal.formatted()) ml").font(.subheadline).foregroundStyle(AppDesign.Palette.secondaryText)
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            Capsule().fill(AppDesign.Palette.waterTrack)
                .overlay(alignment: .leading) {
                    Capsule().fill(LinearGradient(colors: [AppDesign.Palette.action, AppDesign.Palette.success],
                                                   startPoint: .leading, endPoint: .trailing))
                        .frame(width: proxy.size.width * progress)
                }
        }
        .frame(height: 7)
        .accessibilityLabel("今日喝水完成百分之\(Int(progress * 100))")
    }

    private var quickButtons: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 180 : 84),
                                    spacing: AppDesign.Space.sm)], spacing: AppDesign.Space.sm) {
            ForEach(store.settings.waterCupSizes, id: \.self) { ml in
                Button { recordWater(ml) } label: {
                    Text("+\(ml) ml").frame(maxWidth: .infinity)
                }
                .buttonStyle(AppSecondaryButtonStyle())
                .accessibilityLabel("记录喝水 \(ml) 毫升")
            }
            Button { showCustomSheet = true } label: {
                Text("自定义").frame(maxWidth: .infinity)
            }
            .buttonStyle(AppSecondaryButtonStyle())
            .accessibilityLabel("自定义喝水量和时间")
        }
    }

    private func recordWater(_ ml: Int) {
        let before = store.todayWaterMl
        withAnimation(reduceMotion ? nil : AppDesign.Motion.progress) { store.logWater(ml: ml) }
        guard store.todayWaterMl == before + ml else { return }
        lastCupMl = ml
        isAcknowledging = true
        acknowledgment += 1
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
