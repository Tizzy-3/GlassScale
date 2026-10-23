import SwiftUI

/// 新增、补录或编辑一条喝水记录。
struct WaterEntryEditorView: View {
    @Environment(WeightStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let entry: WaterEntry?
    @State private var mlText: String
    @State private var date: Date
    @State private var saveFailed = false

    init(entry: WaterEntry? = nil, initialDate: Date = Date()) {
        self.entry = entry
        _mlText = State(initialValue: entry.map { String($0.ml) } ?? "300")
        _date = State(initialValue: entry?.date ?? min(initialDate, Date()))
    }

    private var milliliters: Int? {
        Int(mlText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var isValid: Bool {
        guard let milliliters else { return false }
        return (1...10000).contains(milliliters) && date <= Date()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        GlassCard(cornerRadius: Theme.heroCorner, contentPadding: 20, tint: Theme.aqua.opacity(0.3)) {
                            VStack(spacing: 16) {
                                Text("这次喝了多少？")
                                    .font(.headline)
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    TextField("300", text: $mlText)
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(maxWidth: 210)
                                        .accessibilityLabel("喝水量，毫升")
                                    Text("ml")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                Text("请输入 1–10000 ml。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 18) {
                            DatePicker("喝水时间", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        }
                        if saveFailed {
                            Text("保存失败，记录尚未保存。请检查存储提示后重试。")
                                .font(.footnote)
                                .foregroundStyle(Theme.coral)
                        }
                    }
                    .padding(Theme.pagePadding)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(entry == nil ? "记录喝水" : "编辑喝水记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", systemImage: "checkmark") { save() }
                        .disabled(!isValid)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func save() {
        guard isValid, let milliliters else { return }
        if store.saveWater(ml: milliliters, at: date, id: entry?.id) {
            dismiss()
        } else {
            saveFailed = true
        }
    }
}
