import SwiftUI

struct DashboardView: View {
    @Environment(WeightStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var onAdd: () -> Void
    @State private var showCalendar = false
    @State private var showGoal = false
    @State private var showDetails = false

    private var stats: WeightStats { store.stats }
    private var unit: WeightUnit { store.unit }
    private var latestEntry: WeightEntry? { store.entries.last { $0.date <= Date() } }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        header
                        if store.isEmpty {
                            ContentCard(cornerRadius: Theme.heroCorner, contentPadding: 22) {
                                EmptyStateView(symbol: "scalemass", title: "从今天开始记录", message: "记下第一笔体重，慢慢看见自己的变化。", actionTitle: "记体重", action: onAdd)
                            }
                        } else {
                            HeroCard(stats: stats, goal: store.goal, baselineKg: store.baselineKg, unit: unit,
                                     projectedDate: stats.projectedGoalDate(goal: store.goal, baselineKg: store.baselineKg),
                                     latestEntry: latestEntry, recentEntries: store.recentEntries(days: 7),
                                     dailyPolicy: store.settings.dailyWeightPolicy, onAdd: onAdd)
                        }
                        WaterCard()
                        if !store.isEmpty { recentCard; trendCard; detailsCard }
                    }
                    .padding(.horizontal, Theme.pagePadding).padding(.top, 12).padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCalendar) { RecordingCalendarView() }
            .sheet(isPresented: $showGoal) { GoalEditorView() }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date(), format: .dateTime.month().day().weekday(.wide)).font(.subheadline).foregroundStyle(.secondary)
                Text("今天").font(.largeTitle.weight(.bold))
            }
            Spacer(minLength: 0)
            Button { showCalendar = true } label: {
                Image(systemName: "calendar").font(.title3.weight(.medium)).frame(width: 32, height: 32)
            }
            .buttonStyle(.glass).buttonBorderShape(.circle).accessibilityLabel("打开日历与补录")
            Menu {
                Button("设置体重目标", systemImage: "target") { showGoal = true }
            } label: {
                Image(systemName: "ellipsis").font(.title3.weight(.medium)).frame(width: 32, height: 32)
            }
            .buttonStyle(.glass).buttonBorderShape(.circle).accessibilityLabel("更多设置")
        }
        .padding(.bottom, 2)
    }

    private var trendCard: some View {
        ContentCard(cornerRadius: Theme.cardCorner, contentPadding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                Text("近 30 天趋势").font(.headline)
                if store.recentEntries(days: 30).count >= 2 {
                    WeightChartView(entries: store.recentEntries(days: 30), goal: store.goal, unit: unit, showsAverage: true, height: 180)
                    Text("虚线为 7 日均线").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("再记一天就能看到趋势曲线").font(.subheadline).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                }
            }
        }
    }

    private var recentCard: some View {
        ContentCard(cornerRadius: Theme.cardCorner, contentPadding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    HStack { Text("最近记录").font(.headline); Spacer(); Text("连续 \(stats.streakDays) 天").font(.caption).foregroundStyle(.secondary) }
                    VStack(alignment: .leading, spacing: 4) { Text("最近记录").font(.headline); Text("连续 \(stats.streakDays) 天").font(.caption).foregroundStyle(.secondary) }
                }
                ForEach(Array(store.entries.suffix(3).reversed())) { entry in
                    EntryRow(entry: entry, unit: unit)
                    if entry.id != store.entries.suffix(3).first?.id { Divider() }
                }
            }
        }
    }

    private var detailsCard: some View {
        ContentCard(cornerRadius: Theme.cardCorner, contentPadding: 18) {
            DisclosureGroup(isExpanded: $showDetails) {
                VStack(alignment: .leading, spacing: 14) {
                    detailRow("BMI", value: Fmt.bmi(stats.bmi))
                    if let bmi = stats.bmi { Text(store.profile.bmiCategory(bmi).title).font(.caption).foregroundStyle(.secondary) }
                    detailRow("起始体重", value: "\(Fmt.weight(store.baselineKg, unit)) \(unit.symbol)")
                    if let goal = store.goal {
                        detailRow("目标体重", value: "\(Fmt.weight(goal.targetWeightKg, unit)) \(unit.symbol)")
                        detailRow("目标日期", value: goal.targetDate.formatted(date: .abbreviated, time: .omitted))
                        if let date = stats.projectedGoalDate(goal: goal, baselineKg: store.baselineKg) {
                            detailRow("按当前速度预计达成", value: date.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                    if let rate = stats.weeklyRateKg { detailRow("每周变化速度", value: "\(Fmt.signedWeight(rate, unit)) \(unit.symbol)") }
                    Button("设置体重目标", systemImage: "target") { showGoal = true }.frame(minHeight: 44)
                }
                .padding(.top, 16)
            } label: {
                Text("目标与身体指标").frame(minHeight: 44)
            }
            .font(.subheadline.weight(.medium)).tint(Theme.aqua)
        }
    }

    @ViewBuilder private func detailRow(_ title: String, value: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) { Text(title).foregroundStyle(.secondary); Text(value) }
        } else {
            HStack { Text(title).foregroundStyle(.secondary); Spacer(); Text(value).multilineTextAlignment(.trailing) }
        }
    }
}

extension Notification.Name {
    static let glassScaleEditGoal = Notification.Name("glassScale.editGoal")
}
