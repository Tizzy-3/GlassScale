import Charts
import SwiftUI

struct ChartPoint: Identifiable, Equatable {
    let date: Date
    let kg: Double
    var id: Date { date }
}

/// 体重趋势图。纯 Swift Charts，零依赖。
struct WeightChartView: View {
    let entries: [WeightEntry]
    let goal: WeightGoal?
    let unit: WeightUnit
    var showsAverage: Bool = true
    var height: CGFloat = 230

    @State private var selectedDate: Date?

    private var points: [ChartPoint] {
        entries.map { ChartPoint(date: $0.date, kg: $0.weightKg) }
    }

    /// 7 天滚动均值，用来抹掉每天的水分波动
    private var averagePoints: [ChartPoint] {
        guard entries.count >= 3 else { return [] }
        var result: [ChartPoint] = []
        for i in entries.indices {
            let window = entries[max(0, i - 6)...i]
            let avg = window.reduce(0.0) { $0 + $1.weightKg } / Double(window.count)
            result.append(ChartPoint(date: entries[i].date, kg: avg))
        }
        return result
    }

    private var displayedValues: [Double] {
        var v = points.map { unit.value(forKg: $0.kg) }
        if let goal { v.append(unit.value(forKg: goal.targetWeightKg)) }
        return v
    }

    private var yDomain: ClosedRange<Double> {
        let values = displayedValues
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        let pad = max((hi - lo) * 0.18, 0.8)
        return (lo - pad)...(hi + pad)
    }

    private var axisStride: Int {
        let span = Calendar.current.dateComponents(
            [.day],
            from: points.first?.date ?? Date(),
            to: points.last?.date ?? Date()
        ).day ?? 30

        switch span {
        case 0..<45: return 7
        case 45..<120: return 14
        case 120..<400: return 30
        default: return 90
        }
    }

    private var selectedPoint: ChartPoint? {
        guard let selectedDate, !points.isEmpty else { return nil }
        return points.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    var body: some View {
        Chart {
            ForEach(points) { p in
                AreaMark(
                    x: .value("日期", p.date, unit: .day),
                    yStart: .value("基线", yDomain.lowerBound),
                    yEnd: .value("体重", unit.value(forKg: p.kg))
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.aqua.opacity(0.42), Theme.aqua.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("日期", p.date, unit: .day),
                    y: .value("体重", unit.value(forKg: p.kg))
                )
                .foregroundStyle(Theme.brandGradient)
                .lineStyle(StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }

            if showsAverage, averagePoints.count > 2 {
                ForEach(averagePoints) { p in
                    LineMark(
                        x: .value("日期", p.date, unit: .day),
                        y: .value("趋势", unit.value(forKg: p.kg))
                    )
                    .foregroundStyle(Theme.mint.opacity(0.85))
                    .lineStyle(StrokeStyle(lineWidth: 1.8, dash: [6, 5]))
                }
            }

            if let goal {
                RuleMark(y: .value("目标", unit.value(forKg: goal.targetWeightKg)))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                    .annotation(position: .top, alignment: .leading, spacing: 2) {
                        Text("目标 \(Fmt.weight(goal.targetWeightKg, unit))")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial, in: .capsule)
                    }
            }

            if let selectedPoint {
                RuleMark(x: .value("选中", selectedPoint.date, unit: .day))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                PointMark(
                    x: .value("日期", selectedPoint.date, unit: .day),
                    y: .value("体重", unit.value(forKg: selectedPoint.kg))
                )
                .foregroundStyle(Theme.aqua)
                .symbolSize(70)
                .annotation(position: .top, spacing: 8) {
                    readout(selectedPoint)
                }
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: axisStride)) { _ in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
                AxisTick().foregroundStyle(.secondary.opacity(0.35))
                AxisValueLabel()
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(Fmt.number(v, decimals: 0))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartLegend(.hidden)
        .frame(height: height)
    }

    private func readout(_ p: ChartPoint) -> some View {
        VStack(spacing: 2) {
            Text(Fmt.weight(p.kg, unit))
                .font(.headline.weight(.bold))
                .contentTransition(.numericText())
            Text("\(unit.symbol) · \(p.date.formatted(.dateTime.month().day().hour().minute()))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

