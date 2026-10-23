import Foundation

/// Local reminder preferences. Times are local wall-clock minutes after midnight.
struct ReminderSettings: Codable, Hashable, Sendable {
    var weightEnabled = false
    var weightMinuteOfDay = 8 * 60
    var waterEnabled = false
    var waterStartMinuteOfDay = 9 * 60
    var waterEndMinuteOfDay = 21 * 60
    var waterIntervalMinutes = 120
    var suppressWaterAfterGoal = true

    init() {}

    private enum CodingKeys: String, CodingKey {
        case weightEnabled, weightMinuteOfDay, waterEnabled
        case waterStartMinuteOfDay, waterEndMinuteOfDay, waterIntervalMinutes
        case suppressWaterAfterGoal
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        weightEnabled = try c.decodeIfPresent(Bool.self, forKey: .weightEnabled) ?? false
        weightMinuteOfDay = try c.decodeIfPresent(Int.self, forKey: .weightMinuteOfDay) ?? 480
        waterEnabled = try c.decodeIfPresent(Bool.self, forKey: .waterEnabled) ?? false
        waterStartMinuteOfDay = try c.decodeIfPresent(Int.self, forKey: .waterStartMinuteOfDay) ?? 540
        waterEndMinuteOfDay = try c.decodeIfPresent(Int.self, forKey: .waterEndMinuteOfDay) ?? 1260
        waterIntervalMinutes = try c.decodeIfPresent(Int.self, forKey: .waterIntervalMinutes) ?? 120
        suppressWaterAfterGoal = try c.decodeIfPresent(Bool.self, forKey: .suppressWaterAfterGoal) ?? true
        self = normalized
    }

    var normalized: ReminderSettings {
        var value = self
        value.weightMinuteOfDay = min(1439, max(0, weightMinuteOfDay))
        value.waterStartMinuteOfDay = min(1439, max(0, waterStartMinuteOfDay))
        value.waterEndMinuteOfDay = min(1439, max(0, waterEndMinuteOfDay))
        value.waterIntervalMinutes = min(720, max(30, waterIntervalMinutes))
        return value
    }
}

/// Pure scheduling rules, also used by the standalone regression executable.
enum ReminderSchedule {
    static let identifierPrefix = "glassscale.reminder."
    static let maximumPending = 60
    static let horizonDays = 7

    enum Kind: String, Hashable, Sendable { case weight, water }

    struct Request: Hashable, Sendable {
        let kind: Kind
        let date: Date

        var id: String {
            "\(ReminderSchedule.identifierPrefix)\(kind.rawValue).\(Int(date.timeIntervalSince1970))"
        }
    }

    static func requests(
        settings: ReminderSettings,
        now: Date = Date(),
        calendar: Calendar = .current,
        weightDates: [Date] = [],
        waterGoalReachedToday: Bool = false
    ) -> [Request] {
        let settings = settings.normalized
        let today = calendar.startOfDay(for: now)
        guard let horizon = calendar.date(byAdding: .day, value: horizonDays, to: today) else { return [] }
        let weighedToday = weightDates.contains { $0 <= now && calendar.isDate($0, inSameDayAs: now) }
        var weight: [Request] = []
        var water: [Request] = []

        func time(_ minute: Int, on day: Date) -> Date? {
            calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day)
        }

        if settings.weightEnabled {
            for offset in 0..<horizonDays {
                guard !(offset == 0 && weighedToday),
                      let day = calendar.date(byAdding: .day, value: offset, to: today),
                      let date = time(settings.weightMinuteOfDay, on: day),
                      date > now, date < horizon else { continue }
                weight.append(Request(kind: .weight, date: date))
            }
        }

        if settings.waterEnabled {
            // Yesterday's active window may extend into this morning.
            for offset in -1..<horizonDays {
                guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                      let start = time(settings.waterStartMinuteOfDay, on: day) else { continue }
                let spansMidnight = settings.waterEndMinuteOfDay <= settings.waterStartMinuteOfDay
                guard let endDay = calendar.date(byAdding: .day, value: spansMidnight ? 1 : 0, to: day),
                      let end = time(settings.waterEndMinuteOfDay, on: endDay) else { continue }
                var date = start
                while date < end && date < horizon {
                    let suppress = settings.suppressWaterAfterGoal && waterGoalReachedToday
                        && calendar.isDate(date, inSameDayAs: now)
                    if date > now && !suppress { water.append(Request(kind: .water, date: date)) }
                    guard let next = calendar.date(byAdding: .minute, value: settings.waterIntervalMinutes, to: date),
                          next > date else { break }
                    date = next
                }
            }
        }

        // Reserve room for every upcoming weigh-in, then use the remaining budget for water.
        let waterBudget = max(0, maximumPending - weight.count)
        return (weight + Array(water.sorted { $0.date < $1.date }.prefix(waterBudget))).sorted {
            $0.date == $1.date ? $0.kind.rawValue < $1.kind.rawValue : $0.date < $1.date
        }
    }
}
