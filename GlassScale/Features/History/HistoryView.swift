import Combine
import SwiftUI

struct HistoryView: View {
    @Environment(WeightStore.self) private var store

    @State private var searchText = ""
    @State private var editing: WeightEntry?
    @State private var showEditor = false
    @State private var showCalendar = false
    @State private var showWaterHistory = false
    @State private var showGoalEditor = false
    @State private var showExport = false
    @State private var confirmClear = false

    private var unit: WeightUnit { store.unit }

    /// 每一行相对「上一条更早的记录」的变化
    private var deltas: [UUID: Double] {
        var map: [UUID: Double] = [:]
        let sorted = store.entries.sorted { $0.date < $1.date }
        for i in sorted.indices where i > 0 {
            let d = sorted[i].weightKg - sorted[i - 1].weightKg
            if abs(d) > 0.0001 { map[sorted[i].id] = d }
        }
        return map
    }

    private var groups: [MonthGroup] {
        let cal = Calendar.current
        let filtered = filteredEntries
        let buckets = Dictionary(grouping: filtered) {
            cal.date(from: cal.dateComponents([.year, .month], from: $0.date)) ?? $0.date
        }
        return buckets
            .map { key, value in
                let sorted = value.sorted { $0.date > $1.date }   // 组内倒序：最新的在上面
                let ascending = sorted.reversed()
                let net = (ascending.last?.weightKg ?? 0) - (ascending.first?.weightKg ?? 0)
                return MonthGroup(monthStart: key, entries: sorted, netChangeKg: net)
            }
            .sorted { $0.monthStart > $1.monthStart }
    }

    private var filteredEntries: [WeightEntry] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return store.entries }
        return store.entries.filter {
            $0.note.localizedCaseInsensitiveContains(query)
            || Fmt.number($0.weightKg, decimals: 1).contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                if store.isEmpty {
                    EmptyStateView(
                        symbol: "list.bullet.rectangle",
                        title: "还没有记录",
                        message: "所有体重记录都会保存在这台设备上。",
                        actionTitle: "记一笔",
                        action: { showEditor = true }
                    )
                } else {
                    listContent
                }
            }
            .navigationTitle("记录")
            .searchable(text: $searchText, prompt: "搜索备注或体重")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("日历与补录", systemImage: "calendar") { showCalendar = true }
                        Button("喝水明细", systemImage: "drop") { showWaterHistory = true }
                        Button("设置目标", systemImage: "target") { showGoalEditor = true }
                        Button("导出数据", systemImage: "square.and.arrow.up") {
                            showExport = true
                        }
                        Divider()
                        Button(role: .destructive) {
                            confirmClear = true
                        } label: {
                            Label("清空全部记录", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("记一笔", systemImage: "plus") { showEditor = true }
                }
            }
            .sheet(isPresented: $showEditor) {
                EntryEditorView(mode: .create)
            }
            .sheet(isPresented: $showCalendar) { RecordingCalendarView() }
            .sheet(isPresented: $showWaterHistory) { WaterHistoryView() }
            .sheet(item: $editing) { entry in
                EntryEditorView(mode: .edit(entry))
            }
            .sheet(isPresented: $showGoalEditor) {
                GoalEditorView()
            }
            .sheet(isPresented: $showExport) {
                ExportSheet()
            }
            .confirmationDialog("确定清空全部记录？此操作不可撤销。", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("清空", role: .destructive) { store.clearAll() }
                Button("取消", role: .cancel) {}
            }
            .onReceive(NotificationCenter.default.publisher(for: .glassScaleEditGoal)) { _ in
                showGoalEditor = true
            }
        }
    }

    private var listContent: some View {
        List {
            ForEach(groups) { group in
                Section {
                    ForEach(group.entries) { entry in
                        Button {
                            editing = entry
                        } label: {
                            EntryRow(entry: entry, unit: unit, deltaKg: deltas[entry.id])
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.delete(entry)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(group.monthStart.formatted(.dateTime.year().month(.wide)))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(Fmt.signedWeight(group.netChangeKg, unit)) \(unit.symbol)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.deltaColor(group.netChangeKg))
                    }
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        // 给底部快捷条 + 标签栏让出空间，否则最后一行会被压住
        .safeAreaPadding(.bottom, 84)
    }
}

// MARK: - 月份分组

struct MonthGroup: Identifiable {
    let monthStart: Date
    let entries: [WeightEntry]
    let netChangeKg: Double

    var id: Date { monthStart }
}
