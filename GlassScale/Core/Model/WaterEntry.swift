import Foundation

/// 一条喝水记录。
///
/// 只记「什么时候喝了多少毫升」，一天可以有多条；
/// 统计时按 `dayKey` 聚合成每天的总量。
struct WaterEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var date: Date = Date()
    /// 毫升
    var ml: Int

    init(id: UUID = UUID(), date: Date = Date(), ml: Int) {
        self.id = id
        self.date = date
        self.ml = ml
    }

    var dayKey: Date { Calendar.current.startOfDay(for: date) }
}
