import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// 导入：CSV 记录合并 / JSON 完整备份恢复。
enum ImportService {

    // MARK: - CSV 解析

    /// 解析本 App 导出的 CSV（含表头）。表头里的单位决定体重列的换算。
    static func parseCSV(_ text: String) -> [WeightEntry] {
        let lines = text
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count >= 2 else { return [] }

        let unit = unitFromHeader(lines[0])

        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "en_US_POSIX")
        dateFmt.dateFormat = "yyyy-MM-dd HH:mm"

        var result: [WeightEntry] = []
        for line in lines.dropFirst() {
            let fields = parseCSVLine(line)
            guard fields.count >= 5 else { continue }
            let dateStr = fields[0].trimmingCharacters(in: .whitespaces)
            let timeStr = fields[1].trimmingCharacters(in: .whitespaces)
            guard let weightValue = Double(fields[2].trimmingCharacters(in: .whitespaces)),
                  let date = dateFmt.date(from: "\(dateStr) \(timeStr)")
            else { continue }
            let fatStr = fields[3].trimmingCharacters(in: .whitespaces)
            let bodyFat = fatStr.isEmpty ? nil : Double(fatStr)
            let source: WeightEntry.Source = fields[4].contains("健康") ? .healthKit : .manual
            let note = fields.count >= 6 ? fields[5] : ""
            result.append(
                WeightEntry(
                    date: date,
                    weightKg: unit.kilograms(for: weightValue),
                    bodyFatPercent: bodyFat,
                    note: note,
                    source: source
                )
            )
        }
        return result.sorted { $0.date < $1.date }
    }

    private static func unitFromHeader(_ header: String) -> WeightUnit {
        if header.contains("体重(斤)") { return .jin }
        if header.contains("体重(lb)") { return .pounds }
        return .kilograms
    }

    /// 按 CSV 规则切分一行（处理引号包裹与转义引号）。
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex
        while i < line.endIndex {
            let c = line[i]
            if c == "\"" {
                let next = line.index(after: i)
                if inQuotes, next < line.endIndex, line[next] == "\"" {
                    current.append("\"")
                    i = line.index(after: next)
                    continue
                }
                inQuotes.toggle()
            } else if c == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(c)
            }
            i = line.index(after: i)
        }
        fields.append(current)
        return fields
    }

    // MARK: - JSON 备份解析

    static func parseBackup(_ data: Data) -> Persistence.Payload? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Persistence.Payload.self, from: data)
    }

    // MARK: - 文件读取

    static func readFile(_ url: URL) -> Data? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try? Data(contentsOf: url)
    }
}

/// 导入选择面板。
struct ImportSheet: View {
    @Environment(WeightStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showCSVPicker = false
    @State private var showJSONPicker = false
    @State private var pendingBackup: Persistence.Payload?
    @State private var showRestoreChoice = false

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                VStack(spacing: 16) {
                    Button { showCSVPicker = true } label: {
                        importRow(
                            title: "从 CSV 导入",
                            detail: "合并体重记录，自动跳过重复",
                            symbol: "tablecells",
                            tint: Theme.mint,
                            trailing: "square.and.arrow.down"
                        )
                    }
                    .buttonStyle(.plain)

                    Button { showJSONPicker = true } label: {
                        importRow(
                            title: "从备份恢复",
                            detail: "选择之前导出的 JSON 完整备份",
                            symbol: "doc.text",
                            tint: Theme.violet,
                            trailing: "square.and.arrow.down"
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(Theme.pagePadding)
            }
            .navigationTitle("导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showCSVPicker,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                handlePicked(result, as: .csv)
            }
            .fileImporter(
                isPresented: $showJSONPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handlePicked(result, as: .json)
            }
            .confirmationDialog(
                "备份中有 \(pendingBackup?.entries.count ?? 0) 条记录",
                isPresented: $showRestoreChoice,
                titleVisibility: .visible
            ) {
                Button("合并导入") { mergeBackup() }
                Button("覆盖恢复", role: .destructive) { restoreBackup() }
                Button("取消", role: .cancel) { pendingBackup = nil }
            } message: {
                Text("合并导入会保留现有数据并跳过重复记录；覆盖恢复会用备份替换全部数据（含档案与目标）。")
            }
        }
        .presentationDetents([.medium])
    }

    private enum PickKind { case csv, json }

    private func handlePicked(_ result: Result<[URL], Error>, as kind: PickKind) {
        switch result {
        case .failure:
            store.toast = "未能读取文件"
        case .success(let urls):
            guard let url = urls.first,
                  let data = ImportService.readFile(url)
            else {
                store.toast = "未能读取文件"
                return
            }
            switch kind {
            case .csv:
                importCSV(data)
            case .json:
                importJSON(data)
            }
        }
    }

    private func importCSV(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else {
            store.toast = "文件编码无法识别"
            return
        }
        let entries = ImportService.parseCSV(text)
        guard !entries.isEmpty else {
            store.toast = "没有解析到有效的体重记录"
            return
        }
        let (added, skipped) = store.importEntries(entries)
        if added > 0 {
            store.toast = "成功导入 \(added) 条记录" + (skipped > 0 ? "（跳过 \(skipped) 条重复）" : "")
        } else {
            store.toast = "没有新的记录（\(skipped) 条重复已跳过）"
        }
    }

    private func importJSON(_ data: Data) {
        guard let payload = ImportService.parseBackup(data) else {
            store.toast = "不是有效的备份文件"
            return
        }
        pendingBackup = payload
        showRestoreChoice = true
    }

    private func mergeBackup() {
        guard let payload = pendingBackup else { return }
        pendingBackup = nil
        let (added, skipped) = store.importEntries(payload.entries)
        if added > 0 {
            store.toast = "成功导入 \(added) 条记录" + (skipped > 0 ? "（跳过 \(skipped) 条重复）" : "")
        } else {
            store.toast = "没有新的记录（\(skipped) 条重复已跳过）"
        }
    }

    private func restoreBackup() {
        guard let payload = pendingBackup else { return }
        pendingBackup = nil
        if store.restore(from: payload) {
            store.toast = "已从备份恢复 \(payload.entries.count) 条记录"
        }
    }

    private func importRow(title: String, detail: String, symbol: String, tint: Color, trailing: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: trailing)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
    }
}
