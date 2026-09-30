import SwiftUI

struct TrendsView: View {
    enum Range: String, CaseIterable, Identifiable {
        case month, threeMonths, halfYear, year, all

        var id: String { rawValue }

        var title: String {
            switch self {
            case .month: return "1 月"
            case .threeMonths: return "3 月"
            case .halfYear: return "6 月"
            case .year: return "1 年"
            case .all: return "全部"
            }
        }

        var days: Int? {
            switch self {
            case .month: return 30
            case .threeMonths: return 90
            case .halfYear: return 180
            case .year: return 365
            case .all: return nil
            }
        }
    }

    @Environment(WeightStore.self) private var store
    @State private var range: Range = .threeMonths
    @State private var showEntryEditor = false
    @Namespace private var segmentNamespace

    private var unit: WeightUnit { store.unit }
    private var stats: WeightStats { store.stats }

    private var entries: [WeightEntry] {
        guard let days = range.days,
              let cutoff = Calendar.current.date(byAdding: .day, value: -(days - 1), to: Date()) else {
            return store.entries
        }
        return store.entries.filter { $0.date >= cutoff }
    }

    private var rangeStats: WeightStats {
        StatsEngine.compute(entries: entries, profile: store.profile)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        if store.entries.count < 2 {
                            EmptyStateView(
                                symbol: "chart.xyaxis.line",
                                title: "数据还不够",
                                message: "至少记录两天体重，这里就会出现趋势曲线。",
                                actionTitle: "去记录",
                                action: { showEntryEditor = true }
                            )
                            .padding(.top, 60)
                        } else {
                            picker
                            mainChart
                            summaryTiles
                            deltaCard
                        }
                    }
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.top, 8)
                    .padding(.bottom, 140)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("趋势")
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showEntryEditor) { EntryEditorView(mode: .create) }
        }
    }

    private var picker: some View {
        GlassSegmented(
            items: Range.allCases.map { SegmentedItem(value: $0, label: $0.title) },
            selection: $range,
            namespace: segmentNamespace
        )
    }

    private var mainChart: some View {
        GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Fmt.weight(rangeStats.currentKg, unit))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text(unit.symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(rangeStats.count) 条记录")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if rangeStats.count >= 2 {
                    WeightChartView(
                        entries: entries,
                        goal: store.goal,
                        unit: unit,
                        showsAverage: rangeStats.count >= 7,
                        height: 260
                    )
                } else {
                    Text("这个区间内只有一条记录")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                }
            }
        }
    }

    private var summaryTiles: some View {
        GlassEffectContainer(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                StatTile(
                    title: "区间净变化",
                    value: Fmt.signedWeight(intervalDelta, unit),
                    unitText: unit.symbol,
                    symbol: "arrow.left.arrow.right",
                    valueColor: Theme.deltaColor(intervalDelta),
                    caption: "\(range.title)累计"
                )
                StatTile(
                    title: "每周速度",
                    value: Fmt.signedWeight(rangeStats.weeklyRateKg, unit),
                    unitText: unit.symbol,
                    symbol: "speedometer",
                    valueColor: Theme.deltaColor(rangeStats.weeklyRateKg),
                    caption: "线性拟合"
                )
                StatTile(
                    title: "区间均重",
                    value: Fmt.weight(rangeStats.average30Kg, unit),
                    unitText: unit.symbol,
                    symbol: "equal.circle",
                    caption: "最近 30 条均值"
                )
                StatTile(
                    title: "最高 / 最低",
                    value: Fmt.number(hiLo.low, decimals: 1),
                    unitText: "/ \(Fmt.number(hiLo.high, decimals: 1))",
                    symbol: "arrow.up.and.down",
                    caption: "区间内极值"
                )
            }
        }
    }

    private var intervalDelta: Double? {
        guard let first = entries.first?.weightKg, let last = entries.last?.weightKg else { return nil }
        return last - first
    }

    private var hiLo: (low: Double, high: Double) {
        let values = entries.map { $0.weightKg }
        return (values.min() ?? 0, values.max() ?? 0)
    }

    private var deltaCard: some View {
        GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: "每日涨跌", symbol: "chart.bar.fill", trailing: "正数=变重")
                if entries.count >= 3 {
                    DailyDeltaChart(entries: entries, unit: unit)
                } else {
                    Text("记录满三天后显示")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                }
            }
        }
    }
}
