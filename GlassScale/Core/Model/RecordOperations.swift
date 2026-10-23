import Foundation

/// 记录合并的纯逻辑。日期相同不等于同一条记录。
enum RecordOperations {
    static func upsertWeight(_ entry: WeightEntry, in entries: [WeightEntry]) -> [WeightEntry] {
        var result = entries.filter { $0.id != entry.id }
        result.append(entry)
        return result.sorted(by: weightOrder)
    }

    static func mergeWeights(
        _ incoming: [WeightEntry], into existing: [WeightEntry]
    ) -> (entries: [WeightEntry], added: Int, skipped: Int) {
        var result = existing
        var ids = Set(existing.map(\.id))
        var healthIDs = Set(existing.compactMap(\.healthKitUUID))
        var samples = Set(existing.map(SampleKey.init))
        var added = 0

        for entry in incoming {
            let sample = SampleKey(entry)
            let duplicateHealth = entry.healthKitUUID.map { healthIDs.contains($0) } ?? false
            guard !ids.contains(entry.id), !duplicateHealth, !samples.contains(sample) else { continue }
            result.append(entry)
            ids.insert(entry.id)
            if let healthID = entry.healthKitUUID { healthIDs.insert(healthID) }
            samples.insert(sample)
            added += 1
        }
        return (result.sorted(by: weightOrder), added, incoming.count - added)
    }

    static func upsertWater(_ entry: WaterEntry, in entries: [WaterEntry]) -> [WaterEntry] {
        var result = entries.filter { $0.id != entry.id }
        result.append(entry)
        return result.sorted(by: waterOrder)
    }

    static func mergeWaters(
        _ incoming: [WaterEntry], into existing: [WaterEntry]
    ) -> (entries: [WaterEntry], added: Int, skipped: Int) {
        var result = existing
        var ids = Set(existing.map(\.id))
        var samples = Set(existing.map(WaterSampleKey.init))
        var added = 0

        for entry in incoming {
            let sample = WaterSampleKey(entry)
            guard !ids.contains(entry.id), !samples.contains(sample) else { continue }
            result.append(entry)
            ids.insert(entry.id)
            samples.insert(sample)
            added += 1
        }
        return (result.sorted(by: waterOrder), added, incoming.count - added)
    }

    private static func waterOrder(_ lhs: WaterEntry, _ rhs: WaterEntry) -> Bool {
        lhs.date == rhs.date ? lhs.id.uuidString < rhs.id.uuidString : lhs.date < rhs.date
    }

    private static func weightOrder(_ lhs: WeightEntry, _ rhs: WeightEntry) -> Bool {
        lhs.date == rhs.date ? lhs.id.uuidString < rhs.id.uuidString : lhs.date < rhs.date
    }

    private struct SampleKey: Hashable {
        let date: Date
        let weightKg: Double
        let source: String

        init(_ entry: WeightEntry) {
            date = entry.date
            weightKg = entry.weightKg
            source = entry.source.rawValue
        }
    }

    private struct WaterSampleKey: Hashable {
        let date: Date
        let ml: Int

        init(_ entry: WaterEntry) {
            date = entry.date
            ml = entry.ml
        }
    }
}
