import SwiftUI

struct WaterHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    var initialDate: Date = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                WaterHistoryContent(initialDate: initialDate)
            }
            .navigationTitle("喝水明细")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } }
            }
        }
    }
}

/// No navigation container: this list can also live directly in the records tab.
struct WaterHistoryContent: View {
    @Environment(WeightStore.self) private var store
    @State private var selectedDate: Date
    @State private var editing: WaterEntry?
    @State private var newEntryDate = Date()
    @State private var showEditor = false
    @State private var showCups = false
    var searchText: String = ""

    init(initialDate: Date = Date(), searchText: String = "") {
        _selectedDate = State(initialValue: min(initialDate, Date()))
        self.searchText = searchText
    }

    private var entries: [WaterEntry] {
        let source = searchText.isEmpty ? store.waterEntries(on: selectedDate) : store.waterEntries.filter {
            String($0.ml).contains(searchText)
                || $0.date.formatted(.dateTime.year().month().day()).localizedCaseInsensitiveContains(searchText)
                || localDateKey($0.date).contains(searchText)
        }
        return source.sorted { $0.date > $1.date }
    }

    private func localDateKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    var body: some View {
        List {
            Section {
                dateCard
                    .listRowInsets(EdgeInsets(top: 0, leading: Theme.pagePadding, bottom: 8, trailing: Theme.pagePadding))
                WaterWeekSummary()
                    .listRowInsets(EdgeInsets(top: 4, leading: Theme.pagePadding, bottom: 12, trailing: Theme.pagePadding))
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            Section {
                if entries.isEmpty {
                    ContentCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(searchText.isEmpty ? "这一天还没有喝水记录" : "没有找到匹配的记录").font(.subheadline)
                            if searchText.isEmpty {
                                Text("可以补记喝水量和时间。").font(.caption).foregroundStyle(.secondary)
                                Button("记录喝水", systemImage: "plus", action: beginCreate)
                                    .frame(minHeight: 44).buttonStyle(.glass)
                            }
                        }
                    }
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                } else {
                    ForEach(entries) { entry in
                        Button { editing = entry } label: {
                            ContentCard(contentPadding: 16) {
                                WaterRecordRow(entry: entry, showsDate: !searchText.isEmpty)
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("删除", systemImage: "trash", role: .destructive) { store.deleteWater(entry) }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .sheet(item: $editing) { WaterEntryEditorView(entry: $0) }
        .sheet(isPresented: $showEditor) { WaterEntryEditorView(initialDate: newEntryDate) }
        .sheet(isPresented: $showCups) { WaterCupSettingsView() }
    }

    private var dateCard: some View {
        ContentCard {
            VStack(spacing: 14) {
                if searchText.isEmpty {
                    DatePicker("查看日期", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                } else {
                    HStack {
                        Text("搜索结果").font(.headline)
                        Spacer()
                        Text("\(entries.count) 条").foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Text(searchText.isEmpty ? "当日合计" : "搜索合计").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(entries.reduce(0) { $0 + $1.ml }) ml")
                        .font(.title2.weight(.bold)).foregroundStyle(Theme.aqua).contentTransition(.numericText())
                }
                ViewThatFits(in: .horizontal) {
                    HStack { createButton; Spacer(); cupsButton }
                    VStack(alignment: .leading) { createButton; cupsButton }
                }
            }
        }
    }

    private var createButton: some View {
        Button(searchText.isEmpty && !Calendar.current.isDateInToday(selectedDate) ? "补录喝水" : "记录喝水", systemImage: "plus", action: beginCreate)
            .font(.subheadline.weight(.medium)).frame(minHeight: 44).buttonStyle(.glass)
    }
    private var cupsButton: some View {
        Button("常用杯量", systemImage: "cup.and.saucer") { showCups = true }
            .font(.subheadline).frame(minHeight: 44)
    }

    private func beginCreate() {
        let now = Date()
        let date = searchText.isEmpty ? selectedDate : now
        let time = Calendar.current.dateComponents([.hour, .minute, .second], from: now)
        newEntryDate = min(Calendar.current.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: time.second ?? 0, of: date) ?? date, now)
        showEditor = true
    }
}

struct WaterRecordRow: View {
    let entry: WaterEntry
    var showsDate = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "drop.fill").foregroundStyle(Theme.aqua).frame(width: 22)
            Text(entry.date.formatted(date: showsDate ? .abbreviated : .omitted, time: .shortened))
                .font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text("\(entry.ml) ml").font(.headline).foregroundStyle(.primary)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .frame(minHeight: 44)
        .contentShape(.rect)
    }
}

struct WaterWeekSummary: View {
    @Environment(WeightStore.self) private var store

    var body: some View {
        let days = store.waterMlByDay(lastDays: 7)
        let goal = max(1, store.settings.waterGoalMl)
        let total = days.reduce(0) { $0 + $1.ml }
        ContentCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("近 7 天").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("日均 \(total / max(1, days.count)) ml").font(.caption).foregroundStyle(.secondary)
                }
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(days.indices, id: \.self) { index in
                        let item = days[index]
                        let today = Calendar.current.isDateInToday(item.date)
                        VStack(spacing: 7) {
                            Text("\(item.ml)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                                .lineLimit(1).minimumScaleFactor(0.8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(item.ml > 0 ? (today ? Theme.aqua : Theme.mint.opacity(0.65)) : Color.secondary.opacity(0.12))
                                .frame(height: max(4, CGFloat(min(1, Double(item.ml) / Double(goal))) * 48))
                            Text(today ? "今" : item.date.formatted(.dateTime.weekday(.narrow)))
                                .font(.caption2).foregroundStyle(today ? Theme.aqua : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(item.date.formatted(date: .abbreviated, time: .omitted))，\(item.ml) 毫升")
                    }
                }
            }
        }
    }
}
