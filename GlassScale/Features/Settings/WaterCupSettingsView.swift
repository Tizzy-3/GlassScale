import SwiftUI

/// 首页一键记录使用的常用杯量。
struct WaterCupSettingsView: View {
    private struct CupDraft: Identifiable {
        let id = UUID()
        var text: String
    }

    @Environment(WeightStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var cups: [CupDraft] = []
    @State private var didLoad = false
    @State private var saveFailed = false

    private var sizes: [Int] {
        cups.compactMap { Int($0.text.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private var isValid: Bool {
        (1...4).contains(cups.count)
            && sizes.count == cups.count
            && sizes.allSatisfy { (1...10000).contains($0) }
            && Set(sizes).count == sizes.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 18) {
                            VStack(spacing: 16) {
                                ForEach($cups) { $cup in
                                    HStack(spacing: 12) {
                                        Image(systemName: "cup.and.saucer.fill")
                                            .foregroundStyle(Theme.aqua)
                                        TextField("杯量", text: $cup.text)
                                            .keyboardType(.numberPad)
                                            .accessibilityLabel("常用杯量，毫升")
                                        Text("ml").foregroundStyle(.secondary)
                                        Button(role: .destructive) {
                                            cups.removeAll { $0.id == cup.id }
                                        } label: {
                                            Image(systemName: "minus.circle")
                                        }
                                        .disabled(cups.count <= 1)
                                        .accessibilityLabel("移除杯量")
                                    }
                                }
                                if cups.count < 4 {
                                    Button("添加杯量", systemImage: "plus.circle") {
                                        cups.append(CupDraft(text: ""))
                                    }
                                }
                            }
                        }
                        Text("设置 1–4 个常用杯量，每个 1–10000 ml，且不能重复。保存后可在首页一键记录。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if saveFailed {
                            Text("杯量保存失败，请检查存储提示后重试。")
                                .font(.footnote)
                                .foregroundStyle(Theme.coral)
                        }
                        Button("恢复默认杯量") {
                            cups = [CupDraft(text: "250"), CupDraft(text: "500")]
                        }
                        .buttonStyle(.glass)
                    }
                    .padding(Theme.pagePadding)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("常用杯量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard isValid else { return }
                        if store.setWaterCupSizes(sizes) {
                            dismiss()
                        } else {
                            saveFailed = true
                        }
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                cups = store.settings.waterCupSizes.map { CupDraft(text: String($0)) }
            }
        }
        .presentationDragIndicator(.visible)
    }
}
