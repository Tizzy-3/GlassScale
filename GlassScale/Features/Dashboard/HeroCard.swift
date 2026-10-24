import Charts
import SwiftUI

struct GoalRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let progress: Double
    var lineWidth: CGFloat = 5
    var trackOpacity: Double = 0.14

    var body: some View {
        ZStack {
            Circle().stroke(AppDesign.Palette.action.opacity(trackOpacity), lineWidth: lineWidth)
            Circle().trim(from: 0, to: max(0, min(1, progress)))
                .stroke(AppDesign.Palette.success, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : AppDesign.Motion.progress, value: progress)
        }
    }
}

struct HeroCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var readingSize = AppDesign.TypeScale.weightSize
    let stats: WeightStats
    let goal: WeightGoal?
    let baselineKg: Double?
    let unit: WeightUnit
    let projectedDate: Date?
    var latestEntry: WeightEntry? = nil
    var recentEntries: [WeightEntry] = []
    var dailyPolicy: DailyWeightPolicy = .latest
    var onAdd: () -> Void = {}

    private var progress: Double { stats.progress(goal: goal, baselineKg: baselineKg) ?? 0 }
    private var percent: Int { Int((progress * 100).rounded()) }
    private var points: [WeightEntry] { StatsEngine.dailyEntries(recentEntries, policy: dailyPolicy) }
    private var chartDomain: ClosedRange<Double> {
        let values = points.map { unit.value(forKg: $0.weightKg) }
        let lo = values.min() ?? 0
        let hi = values.max() ?? 1
        let padding = max(0.25, (hi - lo) * 0.3)
        return (lo - padding)...(hi + padding)
    }

    var body: some View {
        AppSurface(.weight) {
            VStack(alignment: .leading, spacing: AppDesign.Space.md) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: AppDesign.Space.lg) { reading; if goal != nil { goalProgress } }
                } else {
                    HStack(alignment: .center, spacing: AppDesign.Space.md) {
                        reading
                        Spacer(minLength: 0)
                        if goal != nil { goalProgress }
                    }
                }
                sparkline
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: AppDesign.Space.md) { metricItems }
                } else {
                    HStack(alignment: .top, spacing: AppDesign.Space.md) { metricItems }
                }
                Button(action: onAdd) { Label("记体重", systemImage: "plus") }
                    .buttonStyle(AppPrimaryButtonStyle())
            }
        }
        .animation(reduceMotion ? nil : AppDesign.Motion.progress, value: stats.currentKg)
    }

    private var reading: some View {
        VStack(alignment: .leading, spacing: AppDesign.Space.xs) {
            Text("当前体重").font(AppDesign.TypeScale.label).foregroundStyle(AppDesign.Palette.secondaryText)
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: AppDesign.Space.xs) {
                        weightAmount.font(.largeTitle.weight(.semibold))
                        weightUnit
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        weightAmount.font(.system(size: readingSize, weight: .semibold, design: .rounded))
                            .lineLimit(1).minimumScaleFactor(0.75)
                        weightUnit
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("当前体重 \(Fmt.weight(stats.currentKg, unit)) \(unit.symbol)")
            if let latestEntry {
                Text(latestEntry.date, format: .dateTime.month().day().hour().minute())
                    .font(AppDesign.TypeScale.metadata).foregroundStyle(AppDesign.Palette.secondaryText)
                    .accessibilityLabel("最近称重时间，\(latestEntry.date.formatted(date: .abbreviated, time: .shortened))")
            }
        }
    }

    private var weightAmount: some View {
        Text(Fmt.weight(stats.currentKg, unit)).monospacedDigit()
            .contentTransition(reduceMotion ? .identity : .numericText())
    }

    private var weightUnit: some View {
        Text(unit.symbol).font(.title3.weight(.medium)).foregroundStyle(AppDesign.Palette.secondaryText)
    }

    private var goalProgress: some View {
        VStack(spacing: AppDesign.Space.sm) {
            ZStack {
                GoalRing(progress: progress)
                    .frame(width: dynamicTypeSize.isAccessibilitySize ? 120 : 54,
                           height: dynamicTypeSize.isAccessibilitySize ? 120 : 54)
                Text("\(percent)%").font(.caption.weight(.semibold)).monospacedDigit()
            }
            Text("目标进度").font(AppDesign.TypeScale.metadata).foregroundStyle(AppDesign.Palette.secondaryText)
        }
        .accessibilityElement(children: .ignore).accessibilityLabel("目标完成百分之\(percent)")
    }

    private var sparkline: some View {
        VStack(alignment: .leading, spacing: AppDesign.Space.xs) {
            ViewThatFits(in: .horizontal) {
                HStack { Text("近 7 天"); Spacer(); deltaText }
                VStack(alignment: .leading, spacing: AppDesign.Space.xs) { Text("近 7 天"); deltaText }
            }
            .font(AppDesign.TypeScale.metadata).foregroundStyle(AppDesign.Palette.secondaryText)
            if points.count >= 2 {
                Chart(points) { entry in
                    AreaMark(x: .value("日期", entry.date), yStart: .value("基线", chartDomain.lowerBound), yEnd: .value("体重", unit.value(forKg: entry.weightKg)))
                        .foregroundStyle(LinearGradient(colors: [AppDesign.Palette.action.opacity(0.14), AppDesign.Palette.action.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("日期", entry.date), y: .value("体重", unit.value(forKg: entry.weightKg)))
                        .foregroundStyle(AppDesign.Palette.action)
                        .lineStyle(StrokeStyle(lineWidth: 2.3, lineCap: .round)).interpolationMethod(.monotone)
                }
                .chartYScale(domain: chartDomain).chartXAxis(.hidden).chartYAxis(.hidden).chartLegend(.hidden)
                .frame(height: 36).accessibilityLabel("近 7 天体重趋势，\(points.count) 天有记录")
            } else {
                Text("再记录一天，就能看到趋势").font(AppDesign.TypeScale.metadata)
                    .foregroundStyle(AppDesign.Palette.secondaryText).padding(.vertical, AppDesign.Space.sm)
            }
        }
    }

    @ViewBuilder private var deltaText: some View {
        if stats.deltaLastKg != nil {
            Text("较上次 \(Fmt.signedWeight(stats.deltaLastKg, unit)) \(unit.symbol)")
                .foregroundStyle(AppDesign.Palette.delta(stats.deltaLastKg))
        }
    }

    @ViewBuilder private var metricItems: some View {
        metric("7 日均值", value: Fmt.weight(stats.average7Kg, unit))
        metric("较 7 日前", value: Fmt.signedWeight(stats.delta7dKg, unit), tint: AppDesign.Palette.delta(stats.delta7dKg))
        metric("距目标", value: Fmt.weight(stats.remainingKg(to: goal), unit))
    }

    private func metric(_ title: String, value: String, tint: Color = AppDesign.Palette.primaryText) -> some View {
        VStack(alignment: .leading, spacing: AppDesign.Space.xs) {
            Text(title).font(AppDesign.TypeScale.metadata).foregroundStyle(AppDesign.Palette.secondaryText)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    metricValue(value, tint: tint)
                    metricUnit
                }
                VStack(alignment: .leading, spacing: AppDesign.Space.xs) {
                    metricValue(value, tint: tint)
                    metricUnit
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func metricValue(_ value: String, tint: Color) -> some View {
        Text(value).font(AppDesign.TypeScale.metric).monospacedDigit().foregroundStyle(tint)
            .contentTransition(reduceMotion ? .identity : .numericText())
    }

    private var metricUnit: some View {
        Text(unit.symbol).font(.caption).foregroundStyle(AppDesign.Palette.secondaryText)
    }
}
