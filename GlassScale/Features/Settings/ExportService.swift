import Foundation
import SwiftUI

/// 导出为 CSV / JSON，交给系统分享面板。
enum ExportService {

    static func makeCSV(entries: [WeightEntry], unit: WeightUnit) -> String {
        var lines: [String] = []
        lines.append("日期,时间,体重(\(unit.symbol)),体脂率(%),来源,备注")

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "HH:mm"

        for entry in entries.sorted(by: { $0.date < $1.date }) {
            let weight = escape(Fmt.number(unit.value(forKg: entry.weightKg), decimals: 1))
            let fat = entry.bodyFatPercent.map { Fmt.number($0, decimals: 1) } ?? ""
            let note = escape(entry.note)
            lines.append([
                dateFormatter.string(from: entry.date),
                timeFormatter.string(from: entry.date),
                weight,
                fat,
                entry.source.title,
                note
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    static func writeTemporary(_ content: String, name: String, extension ext: String) -> URL? {
        let safeName = name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(safeName)
            .appendingPathExtension(ext)
        do {
            try content.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    static func csv(entries: [WeightEntry], unit: WeightUnit) -> URL? {
        let stamp = fileStamp()
        return writeTemporary(makeCSV(entries: entries, unit: unit), name: "享瘦-体重记录-\(stamp)", extension: "csv")
    }

    @MainActor
    static func json(store: WeightStore) -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let payload = Persistence.Payload(
            entries: store.entries,
            profile: store.profile,
            goal: store.goal,
            settings: store.settings,
            waterEntries: store.waterEntries
        )
        guard let data = try? encoder.encode(payload),
              let text = String(data: data, encoding: .utf8) else { return nil }
        return writeTemporary(text, name: "享瘦-备份-\(fileStamp())", extension: "json")
    }

    private static func fileStamp() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmm"
        return f.string(from: Date())
    }

    private static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

/// 导出选择面板。
struct ExportSheet: View {
    @Environment(WeightStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                VStack(spacing: 16) {
                    if let url = ExportService.csv(entries: store.entries, unit: store.unit) {
                        ShareLink(
                            item: url,
                            preview: SharePreview("体重记录 CSV", image: Image(systemName: "tablecells"))
                        ) {
                            exportRow(
                                title: "导出 CSV",
                                detail: "可直接在 Excel / Numbers 里打开",
                                symbol: "tablecells",
                                tint: Theme.mint
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if let url = ExportService.json(store: store) {
                        ShareLink(
                            item: url,
                            preview: SharePreview("完整备份 JSON", image: Image(systemName: "doc.text"))
                        ) {
                            exportRow(
                                title: "导出完整备份",
                                detail: "包含档案、目标与所有记录的 JSON",
                                symbol: "doc.text",
                                tint: Theme.violet
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .padding(Theme.pagePadding)
            }
            .navigationTitle("导出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func exportRow(title: String, detail: String, symbol: String, tint: Color) -> some View {
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
            Image(systemName: "square.and.arrow.up")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
    }
}
