import SwiftUI

/// 目标进度环。
struct GoalRing: View {
    /// 0…1
    let progress: Double
    var lineWidth: CGFloat = 16
    var trackOpacity: Double = 0.14

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(trackOpacity), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0.0001, min(1, progress)))
                .stroke(
                    AngularGradient(
                        colors: [Theme.aqua, Theme.mint, Theme.violet, Theme.aqua],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.mint.opacity(0.45), radius: 10)
                .animation(.spring(response: 0.75, dampingFraction: 0.82), value: progress)
        }
    }
}

/// 首页顶部的大玻璃卡：当前体重 + 目标进度。
struct HeroCard: View {
    let stats: WeightStats
    let goal: WeightGoal?
    let baselineKg: Double?
    let unit: WeightUnit
    let projectedDate: Date?

    private var progress: Double {
        stats.progress(goal: goal, baselineKg: baselineKg) ?? 0
    }

    private var progressPercent: Int {
        Int((progress * 100).rounded())
    }

    var body: some View {
        GlassCard(cornerRadius: Theme.heroCorner, contentPadding: 22, tint: Theme.aqua.opacity(0.35)) {
            VStack(spacing: 18) {
                HStack(alignment: .center, spacing: 18) {
                    ZStack {
                        GoalRing(progress: progress)
                            .frame(width: 108, height: 108)
                        VStack(spacing: 0) {
                            Text("\(progressPercent)")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .contentTransition(.numericText())
                            Text("%")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("当前体重")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(Fmt.weight(stats.currentKg, unit))
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .contentTransition(.numericText())
                            Text(unit.symbol)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        deltaLine
                    }
                    Spacer(minLength: 0)
                }

                if let goal {
                    divider
                    goalFooter(goal)
                }
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(height: 1)
    }

    private var deltaLine: some View {
        HStack(spacing: 6) {
            let delta = stats.deltaLastKg
            Image(systemName: deltaIcon(delta))
                .font(.caption2.weight(.bold))
            Text("较上次 \(Fmt.signedWeight(delta, unit)) \(unit.symbol)")
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(Theme.deltaColor(stats.deltaLastKg))
    }

    private func deltaIcon(_ delta: Double?) -> String {
        guard let delta, abs(delta) > 0.05 else { return "equal" }
        return delta > 0 ? "arrow.up.right" : "arrow.down.right"
    }

    @ViewBuilder
    private func goalFooter(_ goal: WeightGoal) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                GlassChip(
                    text: "目标 \(Fmt.weight(goal.targetWeightKg, unit)) \(unit.symbol)",
                    symbol: "target"
                )
                if let remaining = stats.remainingKg(to: goal) {
                    GlassChip(
                        text: "还差 \(Fmt.weight(remaining, unit)) \(unit.symbol)",
                        symbol: "ruler"
                    )
                }
                Spacer(minLength: 0)
            }

            if let projectedDate {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.caption2)
                    Text("按当前速度，预计 \(projectedDate.formatted(.dateTime.month(.abbreviated).day())) 达成")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
