import SwiftUI

/// 一行记录。
struct EntryRow: View {
    let entry: WeightEntry
    let unit: WeightUnit
    /// 与前一条相比的变化（千克），可为空
    var deltaKg: Double? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.source.symbol)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(Fmt.weight(entry.weightKg, unit))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .contentTransition(.numericText())
                    Text(unit.symbol)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Text(entry.date.formatted(.dateTime.month().day().hour().minute()))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let bodyFat = entry.bodyFatPercent {
                        Text("体脂 \(Fmt.number(bodyFat, decimals: 1))%")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer(minLength: 8)

            if let deltaKg {
                Text(Fmt.signedWeight(deltaKg, unit))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.deltaColor(deltaKg))
                    .contentTransition(.numericText())
            }
        }
        .padding(.vertical, 8)
        .contentShape(.rect)
    }
}
