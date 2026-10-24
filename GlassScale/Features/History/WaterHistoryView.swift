import SwiftUI

/// 按日期查看喝水明细，支持编辑、删除和补录。
struct WaterHistoryView: View {
    @Environment(WeightStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date
    @State private var editing: WaterEntry?
    @State private var newEntryDate: Date?
    @State private var showEditor = false
    @State private var showCups = false

    init(initialDate: Date = Date()) {
        _selectedDate = State(initialValue: min(initialDate, Date()))
    }

    private var entries: [WaterEntry] {
        store.waterEntries(on: selectedDate).sorted { $0.date > $1.date }
    }

    private var total: Int { entries.reduce(0) { $0 + $1.ml } }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                VStack(spacing: 12) {
                    dateCard
                        .padding(.horizontal, Theme.pagePadding)
                    if entries.isEmpty {
                        EmptyStateView(
                            symbol: "drop",
                            title: "这一天还没有喝水记录",
                            message: "可以补记喝水量和时间。",
                            actionTitle: "记录喝水",
                            action: beginCreate
                        )
                    } else {
                        recordsList
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle("喝水明细")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("常用杯量", systemImage: "cup.and.saucer") { showCups = true }
                    Button("记录喝水", systemImage: "plus", action: beginCreate)
                }
            }
            .sheet(item: $editing) { WaterEntryEditorView(entry: $0) }
            .sheet(isPresented: $showEditor) {
                WaterEntryEditorView(initialDate: newEntryDate ?? Date())
            }
            .sheet(isPresented: $showCups) { WaterCupSettingsView() }
        }
    }

    private var dateCard: some View {
        GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 18) {
            VStack(spacing: 14) {
                DatePicker("查看日期", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                HStack {
                    Text("当日合计")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(total) ml")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.aqua)
                        .contentTransition(.numericText())
                }
            }
        }
    }

    private var recordsList: some View {
        List {
            ForEach(entries) { entry in
                Button {
                    editing = entry
                } label: {
                    GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "drop.fill")
                                .foregroundStyle(Theme.aqua)
                            Text(entry.date, format: .dateTime.hour().minute())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(entry.ml) ml")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) { store.deleteWater(entry) } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func beginCreate() {
        let now = Date()
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute, .second], from: now)
        newEntryDate = min(calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: selectedDate
        ) ?? selectedDate, now)
        showEditor = true
    }
}
