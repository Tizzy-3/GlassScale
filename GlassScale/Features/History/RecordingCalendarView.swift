import SwiftUI

enum RecordingKind: String, CaseIterable, Identifiable, Hashable {
    case weight, water
    var id: String { rawValue }
    var title: String { self == .weight ? "体重" : "喝水" }
    var symbol: String { self == .weight ? "scalemass" : "drop.fill" }
}

/// Standalone dashboard sheet; the records tab embeds only the content below.
struct RecordingCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kind: RecordingKind = .weight
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                VStack(spacing: 12) {
                    Picker("记录类型", selection: $kind) {
                        ForEach(RecordingKind.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Theme.pagePadding)
                    RecordingCalendarContent(kind: kind, selectedDay: $selectedDay)
                }
            }
            .navigationTitle("日历与补录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
    }
}

/// No NavigationStack here: safe to embed in the records tab or a standalone sheet.
struct RecordingCalendarContent: View {
    @Environment(WeightStore.self) private var store
    let kind: RecordingKind
    @Binding var selectedDay: Date
    @State private var month = Calendar.current.startOfDay(for: Date())
    @State private var newWeight = false
    @State private var newWater = false
    @State private var showCups = false
    @State private var editingWeight: WeightEntry?
    @State private var editingWater: WaterEntry?

    private var calendar: Calendar { .current }
    private var startOfMonth: Date { calendar.dateInterval(of: .month, for: month)?.start ?? month }
    private var weights: [WeightEntry] {
        store.entries.filter { calendar.isDate($0.date, inSameDayAs: selectedDay) }.sorted { $0.date > $1.date }
    }
    private var waters: [WaterEntry] { store.waterEntries(on: selectedDay).sorted { $0.date > $1.date } }
    private var accent: Color { kind == .weight ? Theme.aqua : Theme.mint }
    private var recordedDays: Set<Date> {
        let dates = kind == .weight ? store.entries.map(\.date) : store.waterEntries.map(\.date)
        return Set(dates.map { calendar.startOfDay(for: $0) })
    }
    private var backfillDate: Date {
        let now = Date()
        let time = calendar.dateComponents([.hour, .minute], from: now)
        return min(now, calendar.date(bySettingHour: time.hour ?? 12, minute: time.minute ?? 0, second: 0, of: selectedDay) ?? selectedDay)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                monthCard
                dayDetails
                if kind == .water { WaterWeekSummary() }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .onAppear { month = selectedDay }
        .sheet(isPresented: $newWeight) { EntryEditorView(mode: .create, initialDate: backfillDate) }
        .sheet(isPresented: $newWater) { WaterEntryEditorView(initialDate: backfillDate) }
        .sheet(item: $editingWeight) { EntryEditorView(mode: .edit($0)) }
        .sheet(item: $editingWater) { WaterEntryEditorView(entry: $0) }
        .sheet(isPresented: $showCups) { WaterCupSettingsView() }
    }

    private var monthCard: some View {
        ContentCard(contentPadding: 14) {
            VStack(spacing: 12) {
                HStack(spacing: 2) {
                    Text(startOfMonth.formatted(.dateTime.year().month(.wide))).font(.headline)
                    Spacer(minLength: 2)
                    Button("今天") {
                        selectedDay = calendar.startOfDay(for: Date())
                        month = selectedDay
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(minWidth: 44, minHeight: 44)
                    monthButton("chevron.left", title: "上个月", direction: -1)
                    monthButton("chevron.right", title: "下个月", direction: 1)
                        .disabled(calendar.isDate(month, equalTo: Date(), toGranularity: .month))
                }
                .buttonStyle(.plain)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 5) {
                    ForEach(0..<7, id: \.self) { column in
                        Text(calendar.veryShortStandaloneWeekdaySymbols[(calendar.firstWeekday - 1 + column) % 7])
                            .font(.caption).foregroundStyle(.secondary).frame(height: 24)
                    }
                    let offset = (calendar.component(.weekday, from: startOfMonth) - calendar.firstWeekday + 7) % 7
                    let days = calendar.range(of: .day, in: .month, for: startOfMonth)?.count ?? 30
                    let cells = ((offset + days + 6) / 7) * 7
                    ForEach(0..<cells, id: \.self) { cell in
                        if cell < offset || cell >= offset + days {
                            Color.clear.frame(height: 44)
                        } else if let date = calendar.date(byAdding: .day, value: cell - offset, to: startOfMonth) {
                            dayButton(date)
                        }
                    }
                }
                HStack(spacing: 6) {
                    Circle().fill(accent).frame(width: 5, height: 5)
                    Text("有\(kind.title)记录")
                    Spacer()
                    Text("本月 \(recordedDays.filter { calendar.isDate($0, equalTo: month, toGranularity: .month) }.count) 天")
                }
                .font(.caption2).foregroundStyle(.secondary)
                .padding(.horizontal, 8)
            }
        }
    }

    private func monthButton(_ symbol: String, title: String, direction: Int) -> some View {
        Button { moveMonth(direction) } label: {
            Image(systemName: symbol).font(.subheadline.weight(.semibold)).frame(width: 44, height: 44)
        }
        .accessibilityLabel(title)
    }

    private func dayButton(_ date: Date) -> some View {
        let hasRecord = recordedDays.contains(calendar.startOfDay(for: date))
        let selected = calendar.isDate(date, inSameDayAs: selectedDay)
        let future = date > Date()
        return Button { selectedDay = date } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.subheadline.weight(selected ? .bold : .medium))
                    .foregroundStyle(selected ? accent : .primary)
                Circle().fill(hasRecord ? accent : .clear).frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(selected ? accent.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 13))
            .contentShape(.rect)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .buttonStyle(.plain)
        .disabled(future)
        .opacity(future ? 0.3 : 1)
        .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted))，\(hasRecord ? "有" : "无")\(kind.title)记录")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var dayDetails: some View {
        ContentCard(contentPadding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    HStack { dayHeading; Spacer(); addButton }
                    VStack(alignment: .leading, spacing: 8) { dayHeading; addButton }
                }
                if kind == .weight {
                    if weights.isEmpty { emptyDay("这一天还没有称重记录") }
                    ForEach(weights) { entry in
                        Button { editingWeight = entry } label: { EntryRow(entry: entry, unit: store.unit) }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("编辑", systemImage: "pencil") { editingWeight = entry }
                                Button("删除", systemImage: "trash", role: .destructive) { store.delete(entry) }
                            }
                        if entry.id != weights.last?.id { Divider() }
                    }
                } else {
                    if waters.isEmpty { emptyDay("这一天还没有喝水记录") }
                    ForEach(waters) { entry in
                        HStack {
                            Button { editingWater = entry } label: { WaterRecordRow(entry: entry) }
                                .buttonStyle(.plain)
                            Button("删除", systemImage: "trash", role: .destructive) { store.deleteWater(entry) }
                                .labelStyle(.iconOnly).frame(width: 44, height: 44)
                                .accessibilityLabel("删除 \(entry.date.formatted(date: .omitted, time: .shortened)) 的喝水记录")
                        }
                        if entry.id != waters.last?.id { Divider() }
                    }
                    Button("设置常用杯量", systemImage: "cup.and.saucer") { showCups = true }
                        .font(.subheadline).frame(minHeight: 44)
                }
            }
        }
    }

    private var dayHeading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(selectedDay.formatted(.dateTime.month().day().weekday(.wide))).font(.headline)
            Text(kind == .weight ? "\(weights.count) 条称重记录" : "喝水合计 \(waters.reduce(0) { $0 + $1.ml }) ml")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var addButton: some View {
        Button {
            if kind == .weight { newWeight = true } else { newWater = true }
        } label: {
            Label(calendar.isDateInToday(selectedDay) ? "记录" : "补录", systemImage: "plus")
                .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
        }
        .buttonStyle(.glass)
    }

    private func emptyDay(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 12)
    }

    private func moveMonth(_ direction: Int) {
        guard let next = calendar.date(byAdding: .month, value: direction, to: startOfMonth) else { return }
        month = next
        selectedDay = next
    }
}
