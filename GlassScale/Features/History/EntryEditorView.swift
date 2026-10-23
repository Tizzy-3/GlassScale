import SwiftUI

/// 新增 / 编辑一条体重记录。
struct EntryEditorView: View {
    enum Mode: Equatable {
        case create
        case edit(WeightEntry)

        var title: String {
            switch self {
            case .create: return "记一笔"
            case .edit: return "编辑记录"
            }
        }
    }

    @Environment(WeightStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var weightText: String = ""
    @State private var date: Date = Date()
    @State private var bodyFatText: String = ""
    @State private var note: String = ""
    @State private var syncToHealth = false
    @State private var didLoad = false
    @FocusState private var weightFocused: Bool

    private var unit: WeightUnit { store.unit }

    private var weightKg: Double {
        let cleaned = weightText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let v = Double(cleaned) else { return 0 }
        return unit.kilograms(for: v)
    }

    private var isValid: Bool {
        weightKg > 20 && weightKg < 400
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        weightDial
                        detailsCard
                        if store.settings.syncWriteToHealth || store.health.status.isConnected {
                            syncCard
                        }
                    }
                    .padding(Theme.pagePadding)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", systemImage: "checkmark") { save() }
                        .disabled(!isValid)
                }
                if case .edit = mode {
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive) {
                            if case .edit(let entry) = mode { store.delete(entry) }
                            dismiss()
                        } label: {
                            Label("删除这条记录", systemImage: "trash")
                        }
                    }
                }
            }
            .onAppear(perform: load)
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - 体重输入

    private var weightDial: some View {
        GlassCard(cornerRadius: Theme.heroCorner, contentPadding: 20, tint: Theme.aqua.opacity(0.3)) {
            VStack(spacing: 16) {
                Text("体重")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TextField("0.0", text: $weightText)
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .keyboardType(.decimalPad)
                        .focused($weightFocused)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 190)
                        .foregroundStyle(isValid ? .primary : Theme.coral)

                    Text(unit.symbol)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 18) {
                    GlassEffectContainer(spacing: 14) {
                        HStack(spacing: 10) {
                            stepButton(symbol: "minus", delta: -unit.step)
                            stepButton(symbol: "plus", delta: unit.step)
                        }
                    }

                    Button {
                        syncToHealth.toggle()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 38, height: 38)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .tint(syncToHealth ? Theme.mint : .primary)
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func stepButton(symbol: String, delta: Double) -> some View {
        Button {
            let current = weightKg
            let stepped = current + unit.kilograms(for: delta)
            weightText = Fmt.number(unit.value(forKg: stepped), decimals: 1)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
    }

    // MARK: - 详情

    private var detailsCard: some View {
        GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 18) {
            VStack(spacing: 16) {
                DatePicker(selection: $date, displayedComponents: [.date, .hourAndMinute]) {
                    Label("时间", systemImage: "calendar")
                        .font(.subheadline.weight(.medium))
                }

                Divider().overlay(.white.opacity(0.1))

                HStack {
                    Label("体脂率", systemImage: "percent")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    TextField("选填", text: $bodyFatText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                    Text("%").font(.subheadline).foregroundStyle(.secondary)
                }

                Divider().overlay(.white.opacity(0.1))

                HStack {
                    Label("备注", systemImage: "text.alignleft")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    TextField("选填", text: $note)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 170)
                }
            }
        }
    }

    // MARK: - 健康同步

    private var syncCard: some View {
        GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $syncToHealth) {
                    Label("同时写入「健康」", systemImage: "heart.text.square")
                        .font(.subheadline.weight(.medium))
                }
                .tint(Theme.mint)

                if !store.health.status.isConnected {
                    Text("尚未连接「健康」。可在「我的 → 健康」里授权。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - 读写

    private func load() {
        guard !didLoad else { return }
        didLoad = true

        let base: WeightEntry?
        switch mode {
        case .create:
            base = store.todayEntry ?? store.entries.last
            date = Date()
        case .edit(let entry):
            base = entry
            date = entry.date
        }

        if let base {
            bodyFatText = base.bodyFatPercent.map { Fmt.number($0, decimals: 1) } ?? ""
            note = base.note
        } else {
            bodyFatText = ""
            note = ""
        }
        weightText = Fmt.number(unit.value(forKg: base?.weightKg ?? store.profile.baselineKg ?? 70), decimals: 1)
        syncToHealth = store.settings.syncWriteToHealth
    }

    private func save() {
        guard isValid else { return }
        let bodyFat = Double(bodyFatText.replacingOccurrences(of: ",", with: "."))
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        let entry: WeightEntry
        switch mode {
        case .create:
            entry = WeightEntry(
                date: date,
                weightKg: unit.snappedKilograms(fromKg: weightKg),
                bodyFatPercent: bodyFat,
                note: trimmedNote
            )
        case .edit(let existing):
            entry = WeightEntry(
                id: existing.id,
                date: date,
                weightKg: unit.snappedKilograms(fromKg: weightKg),
                bodyFatPercent: bodyFat,
                note: trimmedNote,
                source: existing.source,
                healthKitUUID: existing.healthKitUUID
            )
        }

        store.save(entry: entry)

        if syncToHealth || store.settings.syncWriteToHealth {
            let value = entry.weightKg
            let when = entry.date
            Task {
                do {
                    try await store.health.save(weightKg: value, at: when)
                } catch {
                    store.toast = "已保存到本机，但写入「健康」失败：\(error.localizedDescription)"
                }
            }
        }

        dismiss()
    }
}
