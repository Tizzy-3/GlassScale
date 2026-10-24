import Combine
import SwiftUI

struct HistoryView: View {
    @Environment(WeightStore.self) private var store
    @State private var kind: RecordingKind = .weight
    @State private var showsCalendar = true
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var searchText = ""
    @State private var editing: WeightEntry?
    @State private var showWeightEditor = false
    @State private var showWaterEditor = false
    @State private var showCups = false
    @State private var showGoalEditor = false
    @State private var showExport = false
    @State private var confirmClear = false

    private var query: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var unit: WeightUnit { store.unit }

    private var deltas: [UUID: Double] {
        var result: [UUID: Double] = [:]
        let entries = store.entries.sorted { $0.date < $1.date }
        for index in entries.indices where index > 0 {
            let change = entries[index].weightKg - entries[index - 1].weightKg
            if abs(change) > 0.0001 { result[entries[index].id] = change }
        }
        return result
    }

    private var groups: [MonthGroup] {
        let calendar = Calendar.current
        let filtered = store.entries.filter {
            query.isEmpty || $0.note.localizedCaseInsensitiveContains(query)
                || Fmt.number($0.weightKg, decimals: 1).contains(query)
                || Fmt.weight($0.weightKg, unit).contains(query)
        }
        return Dictionary(grouping: filtered) {
            calendar.dateInterval(of: .month, for: $0.date)?.start ?? $0.date
        }.map { month, entries in
            let sorted = entries.sorted { $0.date > $1.date }
            let change = (sorted.first?.weightKg ?? 0) - (sorted.last?.weightKg ?? 0)
            return MonthGroup(monthStart: month, entries: sorted, netChangeKg: change)
        }.sorted { $0.monthStart > $1.monthStart }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                VStack(spacing: 14) {
                    displayControls.padding(.horizontal, Theme.pagePadding)
                    if showsCalendar && query.isEmpty {
                        RecordingCalendarContent(kind: kind, selectedDay: $selectedDay)
                    } else if kind == .water {
                        WaterHistoryContent(initialDate: selectedDay, searchText: query)
                    } else {
                        weightList
                    }
                }
                .padding(.top, 4)
            }
            .navigationTitle("记录")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: kind == .weight ? "搜索备注或体重" : "搜索水量或日期")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("添加\(kind.title)记录", systemImage: "plus") {
                        if kind == .weight { showWeightEditor = true } else { showWaterEditor = true }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if kind == .water {
                            Button("常用杯量", systemImage: "cup.and.saucer") { showCups = true }
                        }
                        Button("设置目标", systemImage: "target") { showGoalEditor = true }
                        Button("导出数据", systemImage: "square.and.arrow.up") { showExport = true }
                        Divider()
                        Button("清空全部记录", systemImage: "trash", role: .destructive) { confirmClear = true }
                    } label: {
                        Image(systemName: "ellipsis").frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("更多记录操作")
                }
            }
            .sheet(isPresented: $showWeightEditor) { EntryEditorView(mode: .create) }
            .sheet(isPresented: $showWaterEditor) { WaterEntryEditorView() }
            .sheet(item: $editing) { EntryEditorView(mode: .edit($0)) }
            .sheet(isPresented: $showCups) { WaterCupSettingsView() }
            .sheet(isPresented: $showGoalEditor) { GoalEditorView() }
            .sheet(isPresented: $showExport) { ExportSheet() }
            .confirmationDialog("确定清空全部记录？此操作不可撤销。", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("清空", role: .destructive) { store.clearAll() }
                Button("取消", role: .cancel) {}
            }
            .onReceive(NotificationCenter.default.publisher(for: .glassScaleEditGoal)) { _ in showGoalEditor = true }
        }
    }

    private var displayControls: some View {
        HStack(spacing: 16) {
            Picker("记录类型", selection: $kind) {
                ForEach(RecordingKind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(minHeight: 44)
            HStack(spacing: 0) {
                displayButton(symbol: "calendar", title: "日历视图", active: showsCalendar) { showsCalendar = true }
                displayButton(symbol: "list.bullet", title: "列表视图", active: !showsCalendar) { showsCalendar = false }
            }
            .glassEffect(.regular, in: .capsule)
        }
        .onChange(of: kind) { _, _ in searchText = "" }
    }

    private func displayButton(symbol: String, title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(active ? Theme.aqua : .secondary)
                .frame(width: 44, height: 44)
                .background(active ? Theme.aqua.opacity(0.13) : .clear, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    @ViewBuilder private var weightList: some View {
        if groups.isEmpty {
            if !query.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                EmptyStateView(symbol: "scalemass", title: "还没有体重记录", message: "从今天开始，留住每一次变化。", actionTitle: "记一笔") {
                    showWeightEditor = true
                }
            }
        } else {
            List {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.entries) { entry in
                            Button { editing = entry } label: {
                                ContentCard(contentPadding: 14) {
                                    EntryRow(entry: entry, unit: unit, deltaKg: deltas[entry.id])
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("删除", systemImage: "trash", role: .destructive) { store.delete(entry) }
                            }
                        }
                    } header: {
                        HStack {
                            Text(group.monthStart.formatted(.dateTime.year().month(.wide)))
                            Spacer()
                            Text("\(Fmt.signedWeight(group.netChangeKg, unit)) \(unit.symbol)")
                                .foregroundStyle(Theme.deltaColor(group.netChangeKg))
                        }
                        .font(.subheadline.weight(.semibold))
                        .textCase(nil)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

struct MonthGroup: Identifiable {
    let monthStart: Date
    let entries: [WeightEntry]
    let netChangeKg: Double
    var id: Date { monthStart }
}
