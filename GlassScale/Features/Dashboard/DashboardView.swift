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
    private var previewScrollAnchor: UnitPoint {
        #if DEBUG && targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-preview-bottom") { return .bottom }
        if arguments.contains("--ui-preview-middle") { return .center }
        #endif
        return .top
    }
    private var recordingDays: [(date: Date, recorded: Bool)] {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let recorded = Set(store.entries.filter { $0.date <= now }.map { calendar.startOfDay(for: $0.date) })
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (day, recorded.contains(day))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppDesign.Palette.canvas.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: AppDesign.Space.lg) {
                        header
                        recordingStrip
                        if store.isEmpty {
                            AppSurface(.weight, padding: AppDesign.Space.page) {
                                VStack(alignment: .leading, spacing: AppDesign.Space.lg) {
                                    Label("从今天开始记录", systemImage: "scalemass").font(.title3.weight(.semibold))
                                    Text("记下第一笔体重，慢慢看见自己的变化。")
                                        .font(.subheadline).foregroundStyle(AppDesign.Palette.secondaryText)
                                    Button(action: onAdd) { Label("记体重", systemImage: "plus") }
                                        .buttonStyle(AppPrimaryButtonStyle())
                                }
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
                    .frame(maxWidth: AppDesign.Space.maximumContentWidth)
                    .padding(.horizontal, AppDesign.Space.page)
                    .padding(.top, AppDesign.Space.sm)
                    .padding(.bottom, AppDesign.Space.section)
                    .frame(maxWidth: .infinity)
                }
                .foregroundStyle(AppDesign.Palette.primaryText)
                .tint(AppDesign.Palette.action)
                .scrollIndicators(.hidden)
                .defaultScrollAnchor(previewScrollAnchor, for: .initialOffset)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCalendar) { RecordingCalendarView() }
            .sheet(isPresented: $showGoal) { GoalEditorView() }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: AppDesign.Space.sm) {
            VStack(alignment: .leading, spacing: AppDesign.Space.xs) {
                Text(Date(), format: .dateTime.month().day().weekday(.wide))
                    .font(.subheadline).foregroundStyle(AppDesign.Palette.secondaryText)
                Text("今天").font(AppDesign.TypeScale.pageTitle).accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: AppDesign.Space.xs)
            Button { showCalendar = true } label: { Image(systemName: "calendar").font(.system(size: AppDesign.Control.iconSize, weight: .medium)) }
                .buttonStyle(AppSecondaryButtonStyle(iconOnly: true))
                .accessibilityLabel("打开日历与补录")
            Menu {
                Button("设置体重目标", systemImage: "target") { showGoal = true }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: AppDesign.Control.iconSize, weight: .medium))
                    .frame(width: AppDesign.Control.minimumTarget, height: AppDesign.Control.minimumTarget)
                    .foregroundStyle(AppDesign.Palette.action)
                    .background(AppDesign.Palette.surface, in: .circle)
            }
            .accessibilityLabel("更多设置")
        }
    }

    @ViewBuilder private var recordingStrip: some View {
        let days = recordingDays
        if dynamicTypeSize.isAccessibilitySize {
            Label("近 7 天，\(days.filter { $0.recorded }.count) 天有体重记录", systemImage: "checkmark.circle")
                .font(.subheadline).foregroundStyle(AppDesign.Palette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: AppDesign.Space.sm) {
                ForEach(days.indices, id: \.self) { index in
                    let day = days[index]
                    let isToday = Calendar.current.isDateInToday(day.date)
                    VStack(spacing: AppDesign.Space.xs) {
                        Text(isToday ? "今天" : day.date.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2).foregroundStyle(AppDesign.Palette.secondaryText)
                        ZStack {
                            Circle().fill(isToday ? AppDesign.Palette.action : AppDesign.Palette.surface)
                            if day.recorded {
                                Image(systemName: "checkmark").font(.caption.weight(.bold))
                            } else {
                                Text(day.date, format: .dateTime.day()).font(.caption.weight(.medium)).monospacedDigit()
                            }
                        }
                        .foregroundStyle(isToday ? AppDesign.Palette.onAction : day.recorded ? AppDesign.Palette.success : AppDesign.Palette.secondaryText)
                        .frame(width: 30, height: 30)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(day.date.formatted(date: .complete, time: .omitted))，\(day.recorded ? "已有" : "尚无")体重记录")
                }
            }
        }
    }

    private var trendCard: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: AppDesign.Space.md) {
                Text("近 30 天趋势").font(AppDesign.TypeScale.section).accessibilityAddTraits(.isHeader)
                if StatsEngine.dailyEntries(store.recentEntries(days: 30), policy: store.settings.dailyWeightPolicy).count >= 2 {
                    WeightChartView(entries: store.recentEntries(days: 30), goal: store.goal, unit: unit,
                                    showsAverage: true, height: 180, usesContentPalette: true)
                    Text("实线为体重，长虚线为 7 日均值，短虚线为目标。")
                        .font(.caption).foregroundStyle(AppDesign.Palette.secondaryText)
                } else {
                    Text("再记录一天，就能看到趋势曲线").font(.subheadline)
                        .foregroundStyle(AppDesign.Palette.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                }
            }
        }
    }

    private var recentCard: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: AppDesign.Space.md) {
                ViewThatFits(in: .horizontal) {
                    HStack { Text("最近记录").font(.headline); Spacer(); streakText }
                    VStack(alignment: .leading, spacing: AppDesign.Space.xs) { Text("最近记录").font(.headline); streakText }
                }
                ForEach(Array(store.entries.suffix(3).reversed())) { entry in
                    recentRow(entry)
                    if entry.id != store.entries.suffix(3).first?.id { Divider() }
                }
            }
        }
    }

    private var streakText: some View {
        Text("连续 \(stats.streakDays) 天").font(.caption).foregroundStyle(AppDesign.Palette.secondaryText)
    }

    private func recentRow(_ entry: WeightEntry) -> some View {
        HStack(spacing: AppDesign.Space.md) {
            Image(systemName: entry.source.symbol).foregroundStyle(AppDesign.Palette.secondaryText)
                .frame(width: 22).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppDesign.Space.xs) {
                Text("\(Fmt.weight(entry.weightKg, unit)) \(unit.symbol)").font(.headline).monospacedDigit()
                Text(entry.date, format: .dateTime.month().day().hour().minute())
                    .font(.caption).foregroundStyle(AppDesign.Palette.secondaryText)
                if let bodyFat = entry.bodyFatPercent {
                    Text("体脂 \(Fmt.number(bodyFat, decimals: 1))%").font(.caption).foregroundStyle(AppDesign.Palette.secondaryText)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var detailsCard: some View {
        AppSurface {
            DisclosureGroup(isExpanded: $showDetails) {
                VStack(alignment: .leading, spacing: AppDesign.Space.md) {
                    detailRow("BMI", value: Fmt.bmi(stats.bmi))
                    if let bmi = stats.bmi { Text(store.profile.bmiCategory(bmi).title).font(.caption).foregroundStyle(AppDesign.Palette.secondaryText) }
                    detailRow("起始体重", value: "\(Fmt.weight(store.baselineKg, unit)) \(unit.symbol)")
                    if let goal = store.goal {
                        detailRow("目标体重", value: "\(Fmt.weight(goal.targetWeightKg, unit)) \(unit.symbol)")
                        detailRow("目标日期", value: goal.targetDate.formatted(date: .abbreviated, time: .omitted))
                        if let date = stats.projectedGoalDate(goal: goal, baselineKg: store.baselineKg) {
                            detailRow("按当前速度预计达成", value: date.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                    if let rate = stats.weeklyRateKg { detailRow("每周变化速度", value: "\(Fmt.signedWeight(rate, unit)) \(unit.symbol)") }
                    Button("设置体重目标", systemImage: "target") { showGoal = true }.buttonStyle(AppSecondaryButtonStyle())
                }
                .padding(.top, AppDesign.Space.md)
            } label: {
                Text("目标与身体指标").frame(minHeight: AppDesign.Control.minimumTarget)
            }
            .font(.subheadline.weight(.medium)).tint(AppDesign.Palette.action)
        }
    }

    @ViewBuilder private func detailRow(_ title: String, value: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: AppDesign.Space.xs) {
                Text(title).foregroundStyle(AppDesign.Palette.secondaryText); Text(value)
            }
        } else {
            HStack { Text(title).foregroundStyle(AppDesign.Palette.secondaryText); Spacer(); Text(value).multilineTextAlignment(.trailing) }
        }
    }
}

extension Notification.Name {
    static let glassScaleEditGoal = Notification.Name("glassScale.editGoal")
}
