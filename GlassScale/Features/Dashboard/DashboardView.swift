import SwiftUI

struct DashboardView: View {
    @Environment(WeightStore.self) private var store
    var onAdd: () -> Void

    @Namespace private var fabNamespace
    @State private var fabOpen = false

    private var stats: WeightStats { store.stats }
    private var unit: WeightUnit { store.unit }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        header

                        if store.isEmpty {
                            EmptyStateView(
                                symbol: "scalemass",
                                title: "还没有记录",
                                message: "点右下角的按钮，或直接用下方快捷条记下第一笔体重。",
                                actionTitle: "记第一笔",
                                action: onAdd
                            )
                            .padding(.top, 40)
                        } else {
                            HeroCard(
                                stats: stats,
                                goal: store.goal,
                                baselineKg: store.baselineKg,
                                unit: unit,
                                projectedDate: stats.projectedGoalDate(goal: store.goal, baselineKg: store.baselineKg)
                            )

                            statGrid
                            trendCard
                            recentCard
                        }
                    }
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.top, 8)
                    .padding(.bottom, 140)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottomTrailing) {
                fabCluster
                    .padding(.trailing, 20)
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.title2.weight(.bold))
                Text(Date().formatted(.dateTime.month().day().weekday(.wide)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            GlassIconButton(systemImage: "target", tint: Theme.aqua) {
                // 跳到目标编辑
                NotificationCenter.default.post(name: .glassScaleEditGoal, object: nil)
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return "早上好"
        case 11..<14: return "中午好"
        case 14..<18: return "下午好"
        default: return "晚上好"
        }
    }

    // MARK: - 统计磁贴

    private var statGrid: some View {
        GlassEffectContainer(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                StatTile(
                    title: "近 7 日均",
                    value: Fmt.weight(stats.average7Kg, unit),
                    unitText: unit.symbol,
                    symbol: "chart.line.uptrend.xyaxis",
                    caption: "抹掉每日水分波动"
                )

                StatTile(
                    title: "本周变化",
                    value: Fmt.signedWeight(stats.delta7dKg, unit),
                    unitText: unit.symbol,
                    symbol: "calendar.badge.minus",
                    valueColor: Theme.deltaColor(stats.delta7dKg),
                    caption: rateCaption
                )

                StatTile(
                    title: "距目标",
                    value: Fmt.weight(stats.remainingKg(to: store.goal), unit),
                    unitText: unit.symbol,
                    symbol: "flag.checkered",
                    caption: store.goal == nil ? "去设置一个目标" : nil
                )

                StatTile(
                    title: "BMI",
                    value: Fmt.bmi(stats.bmi),
                    symbol: "figure",
                    valueColor: bmiColor,
                    caption: stats.bmi.map { store.profile.bmiCategory($0).title }
                )
            }
        }
    }

    private var rateCaption: String? {
        guard let rate = stats.weeklyRateKg, abs(rate) > 0.02 else { return nil }
        let v = Fmt.number(abs(unit.value(forKg: rate)), decimals: 1)
        return "\(rate < 0 ? "↓" : "↑") 每周 \(v) \(unit.symbol)"
    }

    private var bmiColor: Color {
        guard let bmi = stats.bmi else { return .primary }
        switch bmi {
        case ..<18.5: return Theme.aqua
        case ..<24: return Theme.mint
        case ..<28: return Theme.violet
        default: return Theme.coral
        }
    }

    // MARK: - 趋势卡

    private var trendCard: some View {
        GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(
                    text: "近 30 天",
                    symbol: "chart.xyaxis.line",
                    trailing: "虚线为 7 日均线"
                )
                if store.recentEntries(days: 30).count >= 2 {
                    WeightChartView(
                        entries: store.recentEntries(days: 30),
                        goal: store.goal,
                        unit: unit,
                        showsAverage: true,
                        height: 190
                    )
                } else {
                    Text("再记一天就能看到趋势曲线")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                }
            }
        }
    }

    // MARK: - 最近记录

    private var recentCard: some View {
        GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: "最近记录", symbol: "clock.arrow.circlepath", trailing: "连续 \(stats.streakDays) 天")

                if store.entries.isEmpty {
                    Text("暂无").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(store.entries.suffix(3).reversed())) { entry in
                            EntryRow(entry: entry, unit: unit)
                            if entry.id != store.entries.suffix(3).first?.id {
                                Rectangle()
                                    .fill(.white.opacity(0.08))
                                    .frame(height: 1)
                                    .padding(.leading, 34)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 浮动操作按钮（可展开，玻璃会互相形变）

    private var fabCluster: some View {
        GlassEffectContainer(spacing: 16) {
            VStack(spacing: 12) {
                if fabOpen {
                    fabAction("square.and.pencil", "手动记录", Theme.aqua) {
                        fabOpen = false
                        onAdd()
                    }
                    .glassEffectID("manual", in: fabNamespace)
                }

                Button {
                    withAnimation(.bouncy(duration: 0.35)) { fabOpen.toggle() }
                } label: {
                    Image(systemName: fabOpen ? "xmark" : "plus")
                        .font(.system(size: 24, weight: .bold))
                        .frame(width: 58, height: 58)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .clipShape(.circle)
                .tint(Theme.aqua)
                .glassEffectID("toggle", in: fabNamespace)
            }
        }
    }

    private func fabAction(_ symbol: String, _ label: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .tint(tint)
    }
}

// MARK: - 通知名

extension Notification.Name {
    static let glassScaleEditGoal = Notification.Name("glassScale.editGoal")
}
