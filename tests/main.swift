import Foundation

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

var failures = 0
var checks = 0

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    checks += 1
    if !condition() { throw TestFailure(description: message) }
}

func near(_ actual: Double?, _ expected: Double, _ message: String) throws {
    try expect(actual.map { abs($0 - expected) < 0.000_001 } ?? false, "\(message): \(String(describing: actual)) != \(expected)")
}

func run(_ name: String, _ body: () throws -> Void) {
    do {
        try body()
        print("PASS \(name)")
    } catch {
        failures += 1
        print("FAIL \(name): \(error)")
    }
}

let cal = Calendar.current
let today = cal.date(from: DateComponents(year: 2026, month: 10, day: 23))!
let now = cal.date(bySettingHour: 12, minute: 0, second: 0, of: today)!

func date(_ offset: Int, hour: Int = 8, minute: Int = 0) -> Date {
    let day = cal.date(byAdding: .day, value: offset, to: today)!
    return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
}

func entry(_ kg: Double, day: Int = 0, hour: Int = 8) -> WeightEntry {
    WeightEntry(date: date(day, hour: hour), weightKg: kg)
}

run("calendar averages include six prior days and ignore gaps / future") {
    let entries = [entry(10, day: -30), entry(90, day: -29), entry(80, day: -7),
                   entry(70, day: -6), entry(60, day: -2), entry(50),
                   entry(999, hour: 13), entry(999, day: 1)]
    let stats = StatsEngine.compute(entries: Array(entries.reversed()), profile: BodyProfile(), now: now)
    try near(stats.average7Kg, 60, "7-day mean excludes day -7")
    try near(stats.average30Kg, 70, "30-day mean excludes day -30")
    try near(stats.currentKg, 50, "future reading must not become current")
    try expect(stats.count == 6, "count excludes future samples")
    let stale = StatsEngine.compute(entries: [entry(70, day: -10)], profile: BodyProfile(), now: now)
    try expect(stale.average7Kg == nil, "no recent samples means no 7-day mean")
    try near(stale.currentKg, 70, "last known reading survives gaps")
    try expect(StatsEngine.compute(entries: [entry(90, day: 1)], profile: BodyProfile(), now: now) == .empty,
               "future-only statistics are empty")
}

run("daily policy selects one representative without changing latest reading") {
    let samples = [entry(80, day: -1), entry(74, hour: 7), entry(70, hour: 9), entry(76, hour: 11)]
    let expected: [(DailyWeightPolicy, Double)] = [(.latest, 76), (.earliest, 74), (.lowest, 70)]
    for (policy, kg) in expected {
        let daily = StatsEngine.dailyEntries(Array(samples.reversed()), policy: policy, now: now)
        try expect(daily.count == 2, "one representative for each day")
        try near(daily.last?.weightKg, kg, "policy \(policy)")
        let stats = StatsEngine.compute(entries: samples, profile: BodyProfile(), now: now, policy: policy)
        try near(stats.average7Kg, (80 + kg) / 2, "daily weighting \(policy)")
        try near(stats.currentKg, 76, "latest actual reading stays current")
        try near(stats.deltaLastKg, 6, "delta compares actual adjacent readings")
        try expect(stats.count == 4, "all readings remain counted")
    }
    let earliest = StatsEngine.dailyEntries(samples, policy: .earliest, now: now)
    let roundTrip = try JSONDecoder().decode(DailyWeightPolicy.self, from: JSONEncoder().encode(DailyWeightPolicy.lowest))
    try expect(roundTrip == .lowest, "policy survives Codable")
    try expect(earliest.first!.date < earliest.last!.date, "representatives are ascending")
}

run("rolling mean uses calendar dates and streak counts unique days") {
    let daily = [entry(100, day: -20), entry(70, day: -6), entry(60, day: -2), entry(50)]
    try near(StatsEngine.calendarAverage(daily, days: 7, now: daily.last!.date), 60,
             "chart rolling average excludes old isolated reading")
    try expect(StatsEngine.calendarAverage(daily, days: 0, now: now) == nil, "invalid window is empty")
    let streak = [entry(70, day: -2), entry(69, day: -1), entry(68), entry(67, hour: 9)]
    try expect(StatsEngine.compute(entries: streak, profile: BodyProfile(), now: now).streakDays == 3,
               "same-day duplicates do not inflate streak")
    try expect(StatsEngine.streak([entry(70, day: -1)], now: now) == 1, "yesterday keeps streak alive")
    try expect(StatsEngine.streak([entry(70, day: -2)], now: now) == 0, "older gap breaks streak")
}

run("trend regression has one vote per day") {
    let normal = [entry(72, day: -2), entry(71, day: -1), entry(70)]
    let extra = normal + [entry(150, day: -1, hour: 6)]
    let baseline = StatsEngine.compute(entries: normal, profile: BodyProfile(), now: now)
    let repeated = StatsEngine.compute(entries: extra, profile: BodyProfile(), now: now)
    try near(baseline.weeklyRateKg, -7, "known linear slope")
    try near(repeated.weeklyRateKg, -7, "same-day early outlier cannot bias latest policy")
}

run("calendar window remains correct across daylight saving transition") {
    let anchor = cal.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 12))!
    let anchorDay = cal.startOfDay(for: anchor)
    let oldestIncluded = cal.date(byAdding: .day, value: -6, to: anchorDay)!
    let excluded = cal.date(byAdding: .day, value: -7, to: anchorDay)!
    let samples = [WeightEntry(date: excluded, weightKg: 100),
                   WeightEntry(date: oldestIncluded, weightKg: 70),
                   WeightEntry(date: anchor, weightKg: 60)]
    try near(StatsEngine.compute(entries: samples, profile: BodyProfile(), now: anchor).average7Kg, 65,
             "window uses calendar days rather than seconds")
}

run("weight upsert keeps same-day records and updates only matching ID") {
    let first = entry(70)
    let second = entry(69, hour: 10)
    let inserted = RecordOperations.upsertWeight(second, in: [first])
    try expect(inserted.count == 2, "same-day create must not overwrite")
    var edited = first
    edited.date = date(-1)
    edited.weightKg = 71
    let updated = RecordOperations.upsertWeight(edited, in: inserted)
    try expect(updated.count == 2, "editing does not duplicate ID")
    try expect(updated.first == edited && updated.last == second, "edit preserves unrelated entry and sorts")
}

run("import deduplicates exact samples / IDs / health UUID but keeps daily readings") {
    let first = entry(70)
    var sameID = entry(71, hour: 9)
    sameID.id = first.id
    let exactSample = WeightEntry(date: first.date, weightKg: first.weightKg)
    let later = entry(70, hour: 10)
    let otherSource = WeightEntry(date: first.date, weightKg: first.weightKg, source: .healthKit)
    let healthID = UUID()
    let health = WeightEntry(date: date(-1), weightKg: 72, source: .healthKit, healthKitUUID: healthID)
    let sameHealth = WeightEntry(date: date(-2), weightKg: 73, source: .healthKit, healthKitUUID: healthID)
    let merged = RecordOperations.mergeWeights([sameID, exactSample, later, otherSource, health, sameHealth, later], into: [first])
    try expect(merged.added == 3 && merged.skipped == 4, "import counts exact duplicate causes")
    try expect(merged.entries.count == 4, "distinct time or source is retained")
    try expect(merged.entries.contains(first), "import does not overwrite existing data")
}

run("water upsert edits a selected ID while preserving same-time records") {
    let first = WaterEntry(date: date(0), ml: 200)
    let second = WaterEntry(date: date(0), ml: 300)
    let inserted = RecordOperations.upsertWater(second, in: [first])
    try expect(inserted.count == 2, "two cups at same instant remain distinct")
    var edited = first
    edited.date = date(-1)
    edited.ml = 450
    let updated = RecordOperations.upsertWater(edited, in: inserted)
    try expect(updated.count == 2 && updated.first == edited && updated.last == second,
               "water edit changes one ID and preserves unrelated cup")
}

run("water import deduplicates IDs and exact samples while preserving distinct cups") {
    let first = WaterEntry(date: date(0), ml: 250)
    let sameID = WaterEntry(id: first.id, date: date(-1), ml: 500)
    let exactSample = WaterEntry(date: first.date, ml: first.ml)
    let later = WaterEntry(date: date(0, hour: 10), ml: 250)
    let differentAmount = WaterEntry(date: first.date, ml: 500)
    let earlier = WaterEntry(date: date(-1), ml: 300)
    let repeatedIncomingSample = WaterEntry(date: later.date, ml: later.ml)
    let merged = RecordOperations.mergeWaters(
        [sameID, exactSample, later, differentAmount, earlier, later, repeatedIncomingSample], into: [first]
    )
    try expect(merged.added == 3 && merged.skipped == 4, "water import counts both existing and in-batch duplicates")
    try expect(merged.entries.count == 4 && merged.entries.contains(first), "existing water record stays unchanged")
    try expect(merged.entries.contains(later) && merged.entries.contains(differentAmount),
               "different time or water amount remains a distinct record")
    try expect(merged.entries.first == earlier, "merged water history is sorted chronologically")
    let repeatedImport = RecordOperations.mergeWaters(merged.entries, into: merged.entries)
    try expect(repeatedImport.added == 0 && repeatedImport.skipped == 4 && repeatedImport.entries == merged.entries,
               "reimporting the same backup is idempotent")
    let empty = RecordOperations.mergeWaters([], into: [])
    try expect(empty.entries.isEmpty && empty.added == 0 && empty.skipped == 0, "empty water backup is valid")
}

run("old settings and payload decode without new fields") {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let oldSettings = try decoder.decode(AppSettings.self, from: Data("{}".utf8))
    try expect(oldSettings.dailyWeightPolicy == .latest, "old settings default daily policy")
    try expect(oldSettings.waterGoalMl == 2000, "old settings retain previous water goal default")
    try expect(!oldSettings.reminders.weightEnabled && !oldSettings.reminders.waterEnabled,
               "old settings never opt users into notifications")
    try expect(oldSettings.waterCupSizes == [250, 500], "old settings receive standard cups")
    let fixture = """
    {"entries":[{"id":"D05E0FA0-95DD-440C-A771-34EA4D1CA8EB","date":"2026-10-22T00:00:00Z","weightKg":70,"note":"旧记录","source":"manual"}],"settings":{"weightUnit":"jin","syncWriteToHealth":true}}
    """
    let payload = try decoder.decode(Persistence.Payload.self, from: Data(fixture.utf8))
    try expect(payload.entries.count == 1 && payload.entries[0].note == "旧记录", "old record remains readable")
    try expect(payload.waterEntries.isEmpty, "missing water history defaults empty")
    try expect(payload.settings.weightUnit == .jin && payload.settings.syncWriteToHealth,
               "existing preferences are retained")
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let restored = try decoder.decode(Persistence.Payload.self, from: encoder.encode(payload))
    try expect(restored.entries == payload.entries && restored.settings == payload.settings, "backup round trip preserves model")
}

run("cup settings migration filters invalid sizes and falls back when empty") {
    let decoder = JSONDecoder()
    for cups in ["[]", "[0,-1,10001]"] {
        let settings = try decoder.decode(AppSettings.self, from: Data("{\"waterCupSizes\":\(cups)}".utf8))
        try expect(settings.waterCupSizes == [250, 500], "empty or entirely invalid cup sizes use safe defaults")
    }
    let mixed = try decoder.decode(AppSettings.self, from: Data("{\"waterCupSizes\":[0,350,350,-20,10000,250,500,750,10001]}".utf8))
    try expect(mixed.waterCupSizes == [350, 10000, 250, 500], "valid sizes keep order, deduplicate, and limit to four cups")
}

run("persistence keeps last-good backup and preserves corrupt original on recovery") {
    let fm = FileManager.default
    let folder = fm.temporaryDirectory.appendingPathComponent("GlassScale-tests-\(UUID().uuidString)", isDirectory: true)
    try fm.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: folder) }
    let url = folder.appendingPathComponent("store.json")
    let missing = try Persistence.load(from: url)
    try expect(missing == nil, "missing file is first launch")
    let original = Persistence.Payload(entries: [entry(70)])
    try Persistence.save(original, to: url)
    try Persistence.save(Persistence.Payload(entries: [entry(69)]), to: url)
    let backup = try Persistence.loadBackup(for: url)
    try expect(backup?.entries == original.entries, "second save preserves prior valid payload")
    let corrupt = Data("{unreadable original".utf8)
    try corrupt.write(to: url)
    var loadRejected = false
    do { _ = try Persistence.load(from: url) } catch { loadRejected = true }
    try expect(loadRejected, "corrupt data is reported rather than treated as empty")
    var saveRejected = false
    do { try Persistence.save(Persistence.Payload(), to: url) } catch { saveRejected = true }
    try expect(saveRejected, "normal save cannot replace unreadable original")
    let unchanged = try Data(contentsOf: url)
    try expect(unchanged == corrupt, "failed save leaves original bytes intact")
    let preservedBackup = try Persistence.loadBackup(for: url)
    try expect(preservedBackup?.entries == original.entries, "failed save preserves valid backup")
    try Persistence.save(backup!, to: url, allowReplacingUnreadable: true)
    let recovered = try Persistence.load(from: url)
    try expect(recovered?.entries == original.entries, "explicit recovery installs valid backup")
    let files = try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
    let archiveFound = files.filter { $0 != url && $0 != Persistence.backupURL(for: url) }
        .contains { (try? Data(contentsOf: $0)) == corrupt }
    try expect(archiveFound, "explicit recovery archives corrupt original for inspection")
}

run("missing primary preserves valid backup through repeated saves until explicit recovery") {
    let fm = FileManager.default
    let folder = fm.temporaryDirectory.appendingPathComponent("GlassScale-missing-\(UUID().uuidString)", isDirectory: true)
    try fm.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: folder) }
    let url = folder.appendingPathComponent("store.json")
    let original = Persistence.Payload(entries: [entry(70)], waterEntries: [WaterEntry(date: date(0), ml: 350)])
    try Persistence.save(original, to: url)
    let backupURL = Persistence.backupURL(for: url)
    let backupBytes = try Data(contentsOf: backupURL)
    try fm.removeItem(at: url)

    var recoveryRequired = false
    do { _ = try Persistence.load(from: url) }
    catch Persistence.RecoveryError.missingPrimary { recoveryRequired = true }
    try expect(recoveryRequired, "missing primary with backup is a recovery state, not first launch")
    let backup = try Persistence.loadBackup(for: url)
    try expect(backup?.entries == original.entries && backup?.waterEntries == original.waterEntries,
               "remaining backup still contains both kinds of history")
    for attempt in 1...2 {
        var saveRejected = false
        do { try Persistence.save(Persistence.Payload(), to: url) }
        catch Persistence.RecoveryError.missingPrimary { saveRejected = true }
        try expect(saveRejected, "ordinary save \(attempt) cannot silently rebuild empty primary")
        try expect(!fm.fileExists(atPath: url.path), "rejected save \(attempt) leaves primary absent")
        let remainingBytes = try Data(contentsOf: backupURL)
        try expect(remainingBytes == backupBytes, "ordinary save \(attempt) preserves only remaining backup bytes")
    }

    try Persistence.save(backup!, to: url, allowReplacingUnreadable: true)
    let restored = try Persistence.load(from: url)
    try expect(restored?.entries == original.entries && restored?.waterEntries == original.waterEntries,
               "explicit backup recovery recreates weight and water history")
    let retainedBackupBytes = try Data(contentsOf: backupURL)
    try expect(retainedBackupBytes == backupBytes, "explicit recovery preserves source backup")
    try Persistence.save(original, to: url)
    let savedAgain = try Persistence.load(from: url)
    try expect(savedAgain?.entries == original.entries, "ordinary saves resume after explicit recovery")
}

run("missing primary with invalid backup still requires recovery and preserves evidence") {
    let fm = FileManager.default
    let folder = fm.temporaryDirectory.appendingPathComponent("GlassScale-invalid-backup-\(UUID().uuidString)", isDirectory: true)
    try fm.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: folder) }
    let url = folder.appendingPathComponent("store.json")
    let backupURL = Persistence.backupURL(for: url)
    let corrupt = Data("{unreadable remaining backup".utf8)
    try corrupt.write(to: backupURL)
    var recoveryRequired = false
    do { _ = try Persistence.load(from: url) }
    catch Persistence.RecoveryError.missingPrimary { recoveryRequired = true }
    try expect(recoveryRequired, "unreadable backup also prevents treating missing primary as new installation")
    var backupRejected = false
    do { _ = try Persistence.loadBackup(for: url) }
    catch { backupRejected = true }
    try expect(backupRejected, "invalid automatic backup is reported as unreadable")
    for attempt in 1...2 {
        var saveRejected = false
        do { try Persistence.save(Persistence.Payload(), to: url) }
        catch Persistence.RecoveryError.missingPrimary { saveRejected = true }
        try expect(saveRejected && !fm.fileExists(atPath: url.path),
                   "ordinary save \(attempt) cannot replace missing primary / invalid backup state")
        let remainingBytes = try Data(contentsOf: backupURL)
        try expect(remainingBytes == corrupt, "ordinary save \(attempt) preserves invalid backup for inspection")
    }
    let externalBackup = Persistence.Payload(entries: [entry(69)], waterEntries: [WaterEntry(date: date(-1), ml: 500)])
    try Persistence.save(externalBackup, to: url, allowReplacingUnreadable: true)
    let recovered = try Persistence.load(from: url)
    try expect(recovered?.entries == externalBackup.entries && recovered?.waterEntries == externalBackup.waterEntries,
               "explicit external-file recovery works when automatic backup is invalid")
    let retainedEvidence = try Data(contentsOf: backupURL)
    try expect(retainedEvidence == corrupt, "external recovery retains unreadable backup evidence")
}

run("persistence reports storage failure and cannot replace good data with invalid JSON") {
    let fm = FileManager.default
    let folder = fm.temporaryDirectory.appendingPathComponent("GlassScale-errors-\(UUID().uuidString)", isDirectory: true)
    try fm.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: folder) }
    let blocker = folder.appendingPathComponent("file-instead-of-folder")
    try Data("occupied".utf8).write(to: blocker)
    var pathRejected = false
    do { try Persistence.save(Persistence.Payload(), to: blocker.appendingPathComponent("store.json")) }
    catch { pathRejected = true }
    try expect(pathRejected, "unwritable destination reports failure")

    let url = folder.appendingPathComponent("store.json")
    let original = Persistence.Payload(entries: [entry(70)])
    try Persistence.save(original, to: url)
    var invalidRejected = false
    do { try Persistence.save(Persistence.Payload(entries: [entry(.infinity)]), to: url) }
    catch { invalidRejected = true }
    try expect(invalidRejected, "non-JSON numeric value reports encoding failure")
    let retained = try Persistence.load(from: url)
    try expect(retained?.entries == original.entries, "failed encoding preserves saved record")
}

run("reminders default off and suppress today's weight after a real weigh-in") {
    try expect(ReminderSchedule.requests(settings: ReminderSettings(), now: now).isEmpty,
               "no reminders until explicitly enabled")
    var settings = ReminderSettings()
    settings.weightEnabled = true
    settings.weightMinuteOfDay = 13 * 60
    let ordinary = ReminderSchedule.requests(settings: settings, now: now, calendar: cal)
    try expect(ordinary.count == 7, "one weight reminder per day in horizon")
    let recorded = ReminderSchedule.requests(settings: settings, now: now, calendar: cal,
                                             weightDates: [date(0, hour: 9)])
    try expect(recorded.count == 6 && !recorded.contains { cal.isDate($0.date, inSameDayAs: now) },
               "today's record cancels only today's reminder")
    let futureOnly = ReminderSchedule.requests(settings: settings, now: now, calendar: cal,
                                               weightDates: [date(0, hour: 14)])
    try expect(futureOnly.count == 7, "future-dated weigh-in does not suppress today's reminder")
}

run("water reminders honor quiet hours / goal suppression / overnight windows") {
    var settings = ReminderSettings()
    settings.waterEnabled = true
    settings.waterStartMinuteOfDay = 9 * 60
    settings.waterEndMinuteOfDay = 21 * 60
    let ordinary = ReminderSchedule.requests(settings: settings, now: now, calendar: cal)
    try expect(!ordinary.isEmpty && ordinary.allSatisfy {
        let hour = cal.component(.hour, from: $0.date)
        return $0.kind == .water && $0.date > now && hour >= 9 && hour < 21
    }, "daytime schedule avoids quiet hours and past times")
    let reached = ReminderSchedule.requests(settings: settings, now: now, calendar: cal,
                                            waterGoalReachedToday: true)
    try expect(!reached.contains { cal.isDate($0.date, inSameDayAs: now) }, "goal pauses today's water reminders")
    try expect(!reached.isEmpty, "goal does not pause future days")
    settings.suppressWaterAfterGoal = false
    let continuing = ReminderSchedule.requests(settings: settings, now: now, calendar: cal,
                                               waterGoalReachedToday: true)
    try expect(continuing.contains { cal.isDate($0.date, inSameDayAs: now) }, "goal suppression can be disabled")
    settings.waterStartMinuteOfDay = 22 * 60
    settings.waterEndMinuteOfDay = 6 * 60
    let overnightNow = date(0, hour: 1, minute: 5)
    let overnight = ReminderSchedule.requests(settings: settings, now: overnightNow, calendar: cal)
    try expect(overnight.contains { cal.isDate($0.date, inSameDayAs: overnightNow) && cal.component(.hour, from: $0.date) == 2 },
               "overnight schedule includes previous night's continuation")
    try expect(overnight.allSatisfy {
        let hour = cal.component(.hour, from: $0.date)
        return hour >= 22 || hour < 6
    }, "overnight schedule respects daytime quiet hours")
}

run("notification budget reserves daily weight and uses unique request IDs") {
    var settings = ReminderSettings()
    settings.weightEnabled = true
    settings.weightMinuteOfDay = 13 * 60
    settings.waterEnabled = true
    settings.waterStartMinuteOfDay = 0
    settings.waterEndMinuteOfDay = 0
    settings.waterIntervalMinutes = 30
    let requests = ReminderSchedule.requests(settings: settings, now: now, calendar: cal)
    try expect(requests.count == ReminderSchedule.maximumPending, "pending request budget enforced")
    try expect(requests.filter { $0.kind == .weight }.count == 7, "dense water schedule cannot crowd out weight")
    try expect(Set(requests.map(\.id)).count == requests.count, "request identifiers are unique")
    try expect(requests.allSatisfy { $0.date > now }, "no request fires in the past")
    let decoded = try JSONDecoder().decode(ReminderSettings.self, from: Data("{}".utf8))
    try expect(decoded == ReminderSettings(), "partial old reminder JSON receives defaults")
}

run("reminder migration clamps invalid time fields and schedule excludes exact boundaries") {
    let invalid = """
    {"weightMinuteOfDay":-1,"waterStartMinuteOfDay":9999,"waterEndMinuteOfDay":-50,"waterIntervalMinutes":0}
    """
    let decoded = try JSONDecoder().decode(ReminderSettings.self, from: Data(invalid.utf8))
    try expect(decoded.weightMinuteOfDay == 0 && decoded.waterStartMinuteOfDay == 1439
               && decoded.waterEndMinuteOfDay == 0 && decoded.waterIntervalMinutes == 30,
               "invalid persisted schedule is clamped to valid times and a positive interval")
    try expect(!decoded.weightEnabled && !decoded.waterEnabled, "partial legacy schedule never enables reminders")
    var settings = ReminderSettings()
    settings.weightEnabled = true
    settings.weightMinuteOfDay = 9 * 60
    settings.waterEnabled = true
    settings.waterStartMinuteOfDay = 9 * 60
    settings.waterEndMinuteOfDay = 13 * 60
    settings.waterIntervalMinutes = 120
    let boundaryNow = date(0, hour: 9)
    let requests = ReminderSchedule.requests(settings: settings, now: boundaryNow, calendar: cal,
                                              weightDates: [date(-1)])
    try expect(requests.allSatisfy { $0.date > boundaryNow }, "exact-now triggers are not rescheduled in the past")
    let todayWater = requests.filter { $0.kind == .water && cal.isDate($0.date, inSameDayAs: boundaryNow) }
    try expect(todayWater.count == 1 && cal.component(.hour, from: todayWater[0].date) == 11,
               "active window's end is exclusive and start equal to now is skipped")
    try expect(requests.filter { $0.kind == .weight }.count == 6,
               "weight time equal to now rolls forward to the next six days")
}

func achievements(
    _ weights: [WeightEntry] = [], goal: WeightGoal? = nil, baseline: Double? = nil,
    waters: [WaterEntry] = [], waterGoal: Int = 2000, policy: DailyWeightPolicy = .latest
) -> Set<AchievementID> {
    AchievementEngine.earnedIDs(entries: weights, goal: goal, baselineKg: baseline,
                               waterEntries: waters, waterGoalMl: waterGoal, policy: policy,
                               now: now, calendar: cal)
}

run("achievement catalog has twelve stable unique badges and complete categories") {
    let ids = AchievementEngine.catalog.map(\.id)
    try expect(ids.count == 12 && Set(ids) == Set(AchievementID.allCases), "each stable ID has exactly one catalog definition")
    try expect(AchievementCategory.allCases.allSatisfy { category in
        AchievementEngine.catalog.contains { $0.category == category }
    }, "all three groups contain badges")
    try expect(AchievementEngine.catalog.allSatisfy { !$0.title.isEmpty && !$0.detail.isEmpty && !$0.symbol.isEmpty },
               "locked and owned badge copy is complete")
}

run("achievement direction follows configured loss or gain goal") {
    let loss = WeightGoal(targetWeightKg: 70, targetDate: date(90))
    let gain = WeightGoal(targetWeightKg: 90, targetDate: date(90))
    let lossIDs = achievements([entry(80, day: -1), entry(77)], goal: loss, baseline: 80)
    try expect(lossIDs.contains(.firstKilogram) && lossIDs.contains(.threeKilograms) && lossIDs.contains(.progress25),
               "three kg toward a loss goal unlocks matching stages")
    try expect(!lossIDs.contains(.progress50) && !lossIDs.contains(.goalReached), "partial progress is not a goal completion")
    let away = achievements([entry(80, day: -1), entry(85)], goal: loss, baseline: 80)
    try expect(away == [.firstWeight], "moving away from a loss goal does not earn weight progress")
    let gainIDs = achievements([entry(80, day: -1), entry(85)], goal: gain, baseline: 80)
    try expect(gainIDs.contains(.progress50) && gainIDs.contains(.threeKilograms), "gain direction is supported")
    try expect(!achievements([entry(75)], goal: gain, baseline: 80).contains(.firstKilogram),
               "weight loss is not rewarded when the configured goal is gain")
}

run("achievement threshold labels respect selected units without changing canonical stages") {
    let first = AchievementEngine.catalog.first { $0.id == .firstKilogram }!
    let third = AchievementEngine.catalog.first { $0.id == .threeKilograms }!
    try expect(first.displayTitle(unit: .kilograms).contains("1 kg"), "kg title retains its canonical threshold")
    try expect(first.displayTitle(unit: .jin).contains("2 斤") && third.displayDetail(unit: .jin).contains("6 斤"),
               "jin copy converts both kg achievement thresholds")
    try expect(first.displayTitle(unit: .pounds).contains("2.2 lb") && third.displayTitle(unit: .pounds).contains("6.6 lb"),
               "pounds copy converts the actual kg milestones")
    try expect(first.displayDetail(unit: .pounds).contains("1 kg"), "rounded pounds copy discloses the exact canonical unlock node")
    let goalBadge = AchievementEngine.catalog.first { $0.id == .goalReached }!
    try expect(goalBadge.displayTitle(unit: .pounds) == goalBadge.title && goalBadge.displayDetail(unit: .jin) == goalBadge.detail,
               "non-weight thresholds keep their existing copy")
}

run("achievement progress requires a real goal and caps kg stages at planned distance") {
    let weights = [entry(80, day: -1), entry(70)]
    try expect(achievements(weights) == [.firstWeight], "no goal means no assumed weight direction")
    let zero = WeightGoal(targetWeightKg: 80, targetDate: date(90))
    try expect(achievements(weights, goal: zero, baseline: 80) == [.firstWeight], "zero-span goal cannot award free progress")
    let small = WeightGoal(targetWeightKg: 79.5, targetDate: date(90))
    let ids = achievements(weights, goal: small, baseline: 80)
    try expect(ids.contains(.goalReached) && ids.contains(.progress75), "crossing the small goal completes its percentages")
    try expect(!ids.contains(.firstKilogram) && !ids.contains(.threeKilograms), "excess loss cannot earn stages beyond the planned half kg")
    let missingBaseline = achievements([entry(80, day: -1), entry(79)],
                                      goal: WeightGoal(targetWeightKg: 76, targetDate: date(90)))
    try expect(missingBaseline.contains(.firstKilogram) && missingBaseline.contains(.progress25),
               "earliest daily weight is a fallback when baseline is absent")
    try expect(achievements(weights, goal: small, baseline: .nan) == [.firstWeight], "nonfinite baseline does not produce progress")
}

run("achievement thresholds are inclusive and historical progress survives current fluctuations") {
    let goal = WeightGoal(targetWeightKg: 76, targetDate: date(90))
    let thresholds: [(Double, AchievementID)] = [(79, .progress25), (78, .progress50), (77, .progress75), (76, .goalReached)]
    for (kg, expected) in thresholds {
        try expect(achievements([entry(kg)], goal: goal, baseline: 80).contains(expected), "exact boundary \(kg) unlocks \(expected.rawValue)")
    }
    let historical = achievements([entry(76, day: -20), entry(81)], goal: goal, baseline: 80)
    try expect(historical.contains(.goalReached), "recognition uses previously achieved daily progress, not only today's value")
}

run("achievement snapshots honor daily policy and exclude future or invalid readings") {
    let goal = WeightGoal(targetWeightKg: 76, targetDate: date(90))
    let sameDay = [entry(76, hour: 7), entry(80, hour: 8)]
    try expect(!achievements(sameDay, goal: goal, baseline: 80).contains(.goalReached), "latest policy does not reward an earlier same-day low")
    try expect(achievements(sameDay, goal: goal, baseline: 80, policy: .earliest).contains(.goalReached), "earliest policy chooses the first reading")
    try expect(achievements(sameDay, goal: goal, baseline: 80, policy: .lowest).contains(.goalReached), "lowest policy chooses the lowest reading")
    let future = [entry(76, day: 1), entry(76, hour: 13), entry(.nan), entry(-1)]
    try expect(achievements(future, goal: goal, baseline: 80).isEmpty, "future/invalid data cannot unlock even firstWeight")
    try expect(!achievements((0..<8).map { entry(80, hour: $0) }).contains(.streak3), "many readings on one day are still one recording day")
}

run("achievement streaks use unique historical calendar days and respect gaps") {
    let thirty = (0..<30).map { entry(80, day: -60 + $0) }
    let ids = achievements(Array(thirty.reversed()) + [thirty[4], thirty[8]])
    try expect([AchievementID.streak3, .streak7, .streak14, .streak30].allSatisfy { ids.contains($0) },
               "a historical 30-day run survives a recent recording gap and duplicate samples")
    let gapped = [-8, -7, -5, -4, -2, -1, 0].map { entry(80, day: $0) }
    try expect(achievements(gapped).contains(.streak3), "the most recent three calendar days qualify")
    try expect(!achievements(gapped).contains(.streak7), "seven total days with gaps are not a seven-day run")
    try expect(!achievements([entry(80, day: -1), entry(80), entry(80, day: 1)]).contains(.streak3),
               "tomorrow's record cannot extend a streak")
}

run("achievement calendar injection handles DST day boundaries") {
    var dstCalendar = Calendar(identifier: .gregorian)
    dstCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    func dstDate(_ day: Int, hour: Int) -> Date {
        dstCalendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour))!
    }
    let weights = [WeightEntry(date: dstDate(7, hour: 22), weightKg: 80),
                   WeightEntry(date: dstDate(8, hour: 1), weightKg: 80),
                   WeightEntry(date: dstDate(8, hour: 23), weightKg: 80),
                   WeightEntry(date: dstDate(9, hour: 1), weightKg: 80)]
    let ids = AchievementEngine.earnedIDs(entries: weights, goal: nil, baselineKg: nil,
                                        waterEntries: [], waterGoalMl: 2000,
                                        now: dstDate(9, hour: 12), calendar: dstCalendar)
    try expect(ids.contains(.streak3), "three local recording days cross the 23-hour DST day")
    let sameLocalDay = [WeightEntry(date: dstDate(8, hour: 1), weightKg: 80),
                        WeightEntry(date: dstDate(8, hour: 23), weightKg: 80)]
    try expect(!AchievementEngine.earnedIDs(entries: sameLocalDay, goal: nil, baselineKg: nil,
                                          waterEntries: [], waterGoalMl: 2000,
                                          now: dstDate(9, hour: 12), calendar: dstCalendar).contains(.streak3),
               "UTC dates cannot split one injected local day into multiple days")
    let localWater = [WaterEntry(date: dstDate(8, hour: 1), ml: 1000), WaterEntry(date: dstDate(8, hour: 23), ml: 1000)]
    try expect(AchievementEngine.earnedIDs(entries: [], goal: nil, baselineKg: nil,
                                         waterEntries: localWater, waterGoalMl: 2000,
                                         now: dstDate(9, hour: 12), calendar: dstCalendar).contains(.waterGoal),
               "water aggregation also honors injected local days across different UTC dates")
}

run("water achievement aggregates each calendar day and ignores future / nonpositive entries") {
    let waters = [WaterEntry(date: date(-3), ml: 1000), WaterEntry(date: date(-3, hour: 9), ml: 1000)]
    try expect(achievements(waters: waters).contains(.waterGoal), "a historical day at its exact goal is recognized")
    try expect(!achievements(waters: [WaterEntry(date: date(-1), ml: 1000), WaterEntry(date: date(0), ml: 1000)]).contains(.waterGoal),
               "volume from different days cannot combine into a target")
    try expect(!achievements(waters: [WaterEntry(date: date(1), ml: 3000), WaterEntry(date: date(0, hour: 13), ml: 3000), WaterEntry(date: date(0), ml: -2000)]).contains(.waterGoal),
               "future and negative entries never earn water goal")
    try expect(!achievements(waters: waters, waterGoal: 0).contains(.waterGoal), "disabled or malformed zero target cannot award a badge")
    try expect(achievements(waters: [WaterEntry(date: date(0), ml: Int.max), WaterEntry(date: date(0), ml: Int.max)], waterGoal: Int.max).contains(.waterGoal),
               "daily sum saturates safely instead of overflowing")
}

run("achievement ledger preserves ownership dates, deduplicates and follows catalog order") {
    let oldDate = date(-20)
    let existing = [AchievementUnlock(id: .waterGoal, earnedAt: oldDate),
                    AchievementUnlock(id: .firstWeight),
                    AchievementUnlock(id: .waterGoal, earnedAt: date(-19))]
    let merged = AchievementEngine.mergedUnlocks(existing: existing, earnedIDs: [.firstWeight, .streak3, .waterGoal], earnedAt: now)
    try expect(merged.map(\.id) == [.firstWeight, .streak3, .waterGoal], "ledger is unique and follows catalog order")
    try expect(merged.first { $0.id == .waterGoal }?.earnedAt == oldDate, "existing earliest known ownership date is retained")
    try expect(merged.first { $0.id == .firstWeight }?.earnedAt == nil, "unknown historical date is not replaced with today's save date")
    try expect(merged.first { $0.id == .streak3 }?.earnedAt == now, "a newly earned badge receives the live save date")
    let unchanged = AchievementEngine.mergedUnlocks(existing: merged, earnedIDs: [], earnedAt: date(5))
    try expect(unchanged == merged, "fluctuations, individual deletions or a goal change cannot revoke persisted ownership")
    let duplicate = AchievementEngine.mergedUnlocks(existing: [AchievementUnlock(id: .streak7), AchievementUnlock(id: .streak7, earnedAt: oldDate)], earnedIDs: [])
    try expect(duplicate.count == 1 && duplicate.first?.earnedAt == oldDate, "a known existing date wins over an unknown duplicate")
    try expect(AchievementEngine.mergedUnlocks(existing: [], earnedIDs: [.firstWeight]).first?.earnedAt == nil,
               "historical recognition does not invent an exact unlock time")
}

run("achievement settings migrate old JSON and roundtrip with full backup payload") {
    let decoder = JSONDecoder()
    let legacy = try decoder.decode(AppSettings.self, from: Data("{}".utf8))
    try expect(legacy.achievementUnlocks.isEmpty, "old settings have an empty persisted ledger")
    var settings = legacy
    settings.achievementUnlocks = [AchievementUnlock(id: .firstWeight), AchievementUnlock(id: .progress25, earnedAt: now)]
    let encoded = try JSONEncoder().encode(settings)
    let decodedSettings = try decoder.decode(AppSettings.self, from: encoded)
    try expect(decodedSettings.achievementUnlocks == settings.achievementUnlocks,
               "known and unknown achievement dates roundtrip through settings")
    let payload = Persistence.Payload(entries: [entry(79)], profile: BodyProfile(), goal: nil,
                                      settings: settings, waterEntries: [])
    let restored = try decoder.decode(Persistence.Payload.self, from: JSONEncoder().encode(payload))
    try expect(restored.settings.achievementUnlocks == settings.achievementUnlocks, "the existing full backup carries the ledger")
}

print("\(checks) checks, \(failures) failures; timezone \(TimeZone.current.identifier)")
if failures > 0 { exit(1) }
