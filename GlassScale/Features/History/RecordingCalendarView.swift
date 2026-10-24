import SwiftUI

/// 月历标记体重和喝水记录；选择日期后查看或补录。
struct RecordingCalendarView: View {
    @Environment(WeightStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var month = Calendar.current.startOfDay(for: Date())
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var newWeight = false
    @State private var newWater = false
    @State private var editingWeight: WeightEntry?
    @State private var editingWater: WaterEntry?

    private var calendar: Calendar { .current }
    private var startOfMonth: Date {
        calendar.dateInterval(of: .month, for: month)?.start ?? month
    }
    private var weights: [WeightEntry] {
        Array(store.entries.filter { calendar.isDate($0.date, inSameDayAs: selectedDay) }.reversed())
    }
    private var waters: [WaterEntry] { Array(store.waterEntries(on: selectedDay).reversed()) }
    private var backfillDate: Date {
        let time = calendar.dateComponents([.hour, .minute], from: Date())
        return min(Date(), calendar.date(bySettingHour: time.hour ?? 12, minute: time.minute ?? 0, second: 0, of: selectedDay) ?? selectedDay)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        monthCard
                        dayDetails
                    }
                    .padding(Theme.pagePadding)
                }
            }
            .navigationTitle("日历与补录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) {
                    Button("今天") {
                        selectedDay = calendar.startOfDay(for: Date())
                        month = selectedDay
                    }
                }
            }
            .sheet(isPresented: $newWeight) { EntryEditorView(mode: .create, initialDate: backfillDate) }
            .sheet(isPresented: $newWater) { WaterEntryEditorView(initialDate: backfillDate) }
            .sheet(item: $editingWeight) { EntryEditorView(mode: .edit($0)) }
            .sheet(item: $editingWater) { WaterEntryEditorView(entry: $0) }
        }
    }

    private var monthCard: some View {
        GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 16) {
            VStack(spacing: 14) {
                HStack {
                    Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("上个月")
                    Spacer()
                    Text(startOfMonth.formatted(.dateTime.year().month(.wide))).font(.headline)
                    Spacer()
                    Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }
                        .accessibilityLabel("下个月")
                        .disabled(calendar.isDate(month, equalTo: Date(), toGranularity: .month))
                }
                .buttonStyle(.glass)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                    ForEach(0..<7, id: \.self) { column in
                        Text(calendar.veryShortStandaloneWeekdaySymbols[(calendar.firstWeekday - 1 + column) % 7])
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    let offset = (calendar.component(.weekday, from: startOfMonth) - calendar.firstWeekday + 7) % 7
                    let days = calendar.range(of: .day, in: .month, for: startOfMonth)?.count ?? 30
                    ForEach(0..<(offset + days), id: \.self) { cell in
                        if cell < offset {
                            Color.clear.frame(height: 48)
                        } else if let day = calendar.date(byAdding: .day, value: cell - offset, to: startOfMonth) {
                            dayButton(day)
                        }
                    }
                }
                HStack(spacing: 16) {
                    Label("体重", systemImage: "circle.fill").foregroundStyle(Theme.aqua)
                    Label("喝水", systemImage: "drop.fill").foregroundStyle(Theme.mint)
                }
                .font(.caption2)
            }
        }
    }

    private func dayButton(_ date: Date) -> some View {
        let hasWeight = store.entries.contains { calendar.isDate($0.date, inSameDayAs: date) }
        let hasWater = !store.waterEntries(on: date).isEmpty
        let selected = calendar.isDate(date, inSameDayAs: selectedDay)
        return Button { selectedDay = date } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))").font(.subheadline.weight(selected ? .bold : .regular))
                HStack(spacing: 4) {
                    Circle().fill(hasWeight ? Theme.aqua : .clear).frame(width: 5, height: 5)
                    Circle().fill(hasWater ? Theme.mint : .clear).frame(width: 5, height: 5)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(selected ? Theme.aqua.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(date > Date())
        .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted))，\(hasWeight ? "有体重记录" : "无体重记录")，\(hasWater ? "有喝水记录" : "无喝水记录")")
    }

    private var dayDetails: some View {
        GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                Text(selectedDay.formatted(.dateTime.month().day().weekday(.wide))).font(.headline)
                HStack {
                    Button("记体重", systemImage: "plus") { newWeight = true }
                    Button("记喝水", systemImage: "drop") { newWater = true }
                }
                .buttonStyle(.glass)
                Text("体重 · \(weights.count) 条").font(.subheadline.weight(.semibold))
                if weights.isEmpty { Text("这一天还没有称重记录").font(.caption).foregroundStyle(.secondary) }
                ForEach(weights) { entry in
                    Button { editingWeight = entry } label: { EntryRow(entry: entry, unit: store.unit) }
                        .buttonStyle(.plain)
                }
                Divider()
                Text("喝水 · \(waters.reduce(0) { $0 + $1.ml }) ml").font(.subheadline.weight(.semibold))
                if waters.isEmpty { Text("这一天还没有喝水记录").font(.caption).foregroundStyle(.secondary) }
                ForEach(waters) { entry in
                    HStack {
                        Button { editingWater = entry } label: {
                            HStack {
                                Text(entry.date.formatted(date: .omitted, time: .shortened)).foregroundStyle(.secondary)
                                Spacer()
                                Text("\(entry.ml) ml").fontWeight(.semibold)
                            }
                        }
                        .buttonStyle(.plain)
                        Button(role: .destructive) { store.deleteWater(entry) } label: { Image(systemName: "trash") }
                            .accessibilityLabel("删除这条喝水记录")
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func moveMonth(_ direction: Int) {
        if let next = calendar.date(byAdding: .month, value: direction, to: startOfMonth) {
            month = next
            selectedDay = next
        }
    }
}
