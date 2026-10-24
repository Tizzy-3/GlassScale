import Charts
import SwiftUI

struct GoalRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let progress: Double
    var lineWidth: CGFloat = 6
    var trackOpacity: Double = 0.12

    var body: some View {
        ZStack {
            Circle().stroke(Theme.aqua.opacity(trackOpacity), lineWidth: lineWidth)
            Circle().trim(from: 0, to: max(0.0001, min(1, progress)))
                .stroke(AngularGradient(colors: [Theme.aqua, Theme.mint], center: .center), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .spring(response: 0.75, dampingFraction: 0.82), value: progress)
        }
    }
}

/// 读数优先，目标进度和趋势作为辅助。
struct HeroCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var readingSize: CGFloat = 64
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
        ContentCard(cornerRadius: Theme.heroCorner, contentPadding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 18) { reading; if goal != nil { goalProgress } }
                } else {
                    HStack(spacing: 16) { reading; Spacer(minLength: 0); if goal != nil { goalProgress } }
                }
                sparkline
                Divider()
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 14) { metricItems }
                } else {
                    HStack(alignment: .top, spacing: 12) { metricItems }
                }
                Button(action: onAdd) {
                    Label("记体重", systemImage: "plus").font(.headline)
                        // 原生玻璃按钮会增加内边距，标签 36pt 对应约 50pt 的按钮。
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.glassProminent).buttonBorderShape(.capsule).tint(Theme.aqua)
            }
        }
    }

    private var reading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("当前体重").font(.subheadline).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Fmt.weight(stats.currentKg, unit))
                    .font(.system(size: readingSize, weight: .semibold, design: .rounded))
                    .monospacedDigit().tracking(-2).lineLimit(1).minimumScaleFactor(0.65)
                    .contentTransition(reduceMotion ? .identity : .numericText())
                Text(unit.symbol).font(.title3.weight(.medium)).foregroundStyle(.secondary)
            }
            if let latestEntry {
                Text(latestEntry.date, format: .dateTime.month().day().hour().minute())
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityLabel("最近称重时间，\(latestEntry.date.formatted(date: .abbreviated, time: .shortened))")
            }
        }
    }

    private var goalProgress: some View {
        VStack(spacing: 9) {
            ZStack {
                GoalRing(progress: progress).frame(width: 60, height: 60)
                Text("\(percent)%").font(.caption.weight(.semibold)).monospacedDigit()
            }
            Text("目标进度").font(.caption2).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore).accessibilityLabel("目标完成百分之\(percent)")
    }

    private var sparkline: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack { Text("近 7 天"); Spacer(); deltaText }
                VStack(alignment: .leading, spacing: 4) { Text("近 7 天"); deltaText }
            }
            .font(.caption).foregroundStyle(.secondary)
            if points.count >= 2 {
                Chart(points) { entry in
                    AreaMark(x: .value("日期", entry.date), yStart: .value("基线", chartDomain.lowerBound), yEnd: .value("体重", unit.value(forKg: entry.weightKg)))
                        .foregroundStyle(LinearGradient(colors: [Theme.aqua.opacity(0.16), Theme.aqua.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("日期", entry.date), y: .value("体重", unit.value(forKg: entry.weightKg)))
                        .foregroundStyle(Theme.aqua).lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round)).interpolationMethod(.monotone)
                }
                .chartYScale(domain: chartDomain).chartXAxis(.hidden).chartYAxis(.hidden).chartLegend(.hidden)
                .frame(height: 48).accessibilityLabel("近 7 天体重趋势，\(points.count) 天有记录")
            } else {
                Text("再记一天，就能看到体重趋势").font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
        }
    }

    @ViewBuilder private var deltaText: some View {
        if stats.deltaLastKg != nil {
            Text("较上次 \(Fmt.signedWeight(stats.deltaLastKg, unit)) \(unit.symbol)")
                .foregroundStyle(Theme.deltaColor(stats.deltaLastKg))
        }
    }

    @ViewBuilder private var metricItems: some View {
        metric("7 日均值", value: Fmt.weight(stats.average7Kg, unit))
        metric("本周变化", value: Fmt.signedWeight(stats.delta7dKg, unit), tint: Theme.deltaColor(stats.delta7dKg))
        metric("距目标", value: Fmt.weight(stats.remainingKg(to: goal), unit))
    }

    private func metric(_ title: String, value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold).monospacedDigit()).foregroundStyle(tint)
                .lineLimit(1).minimumScaleFactor(0.8).contentTransition(reduceMotion ? .identity : .numericText())
            Text(unit.symbol).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
