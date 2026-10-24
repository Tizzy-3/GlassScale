#if DEBUG && targetEnvironment(simulator)
import Foundation

/// Explicitly launched in the disposable screenshot simulator, before fixtures
/// replace this temporary dataset. Never part of a Release device binary.
@MainActor
enum PreviewStoreChecks {
    private struct Report: Encodable {
        let checks: [String: Bool]
        let failures: [String]
    }

    static func runAndWriteReport() {
        var checks: [String: Bool] = [:]
        var diagnostics: [String] = []
        func check(_ name: String, _ result: Bool) { checks[name] = result }

        do {
            let calendar = Calendar.current
            let now = Date()
            let today = calendar.startOfDay(for: now)
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  let historyDay = calendar.date(byAdding: .day, value: -2, to: today),
                  let targetDate = calendar.date(byAdding: .month, value: 3, to: today) else {
                throw CheckFailure.setup("Calendar could not construct preview dates")
            }
            var profile = BodyProfile()
            profile.baselineKg = 75
            var settings = AppSettings()
            settings.hasCompletedOnboarding = true
            settings.showsDemoData = false
            settings.waterGoalMl = 2000
            let goal = WeightGoal(targetWeightKg: 65, targetDate: targetDate)
            let store = WeightStore(preview: true)
            let original = WeightEntry(date: yesterday, weightKg: 75)
            let restored = store.restore(from: Persistence.Payload(entries: [original], profile: profile,
                                                                   goal: goal, settings: settings))
            check("setup_restore_succeeded", restored)
            guard restored else { throw CheckFailure.setup(store.storageError ?? "Restore failed") }

            let fileBeforeRead = try Data(contentsOf: Persistence.fileURL)
            let backupBeforeRead = try? Data(contentsOf: Persistence.backupURL(for: Persistence.fileURL))
            let attributesBeforeRead = try FileManager.default.attributesOfItem(atPath: Persistence.fileURL.path)
            let recognized = store.achievementUnlocks
            let attributesAfterRead = try FileManager.default.attributesOfItem(atPath: Persistence.fileURL.path)
            check("getter_recognizes_history_silently", recognized.contains { $0.id == .firstWeight && $0.earnedAt == nil })
            check("getter_does_not_mutate_settings", store.settings.achievementUnlocks.isEmpty)
            check("getter_preserves_primary_bytes", try Data(contentsOf: Persistence.fileURL) == fileBeforeRead)
            check("getter_preserves_backup_bytes", (try? Data(contentsOf: Persistence.backupURL(for: Persistence.fileURL))) == backupBeforeRead)
            check("getter_preserves_file_modification_date",
                  (attributesBeforeRead[.modificationDate] as? Date) == (attributesAfterRead[.modificationDate] as? Date))

            let live = WeightEntry(date: Date(), weightKg: 74)
            check("live_weight_saved", store.save(entry: live) != nil)
            check("live_weight_unlocks_first_kg", store.settings.achievementUnlocks.contains {
                $0.id == .firstKilogram && $0.earnedAt != nil
            })
            check("live_weight_feedback_after_success", store.milestone?.kind == .achievement(.firstKilogram))
            check("live_unlock_is_persisted", try Persistence.load()?.settings.achievementUnlocks.contains {
                $0.id == .firstKilogram && $0.earnedAt != nil
            } == true)

            store.consumeMilestone()
            store.consumeToast()
            let entriesBeforeFailure = store.entries
            let settingsBeforeFailure = store.settings
            let bytesBeforeFailure = try Data(contentsOf: Persistence.fileURL)
            let invalid = WeightEntry(date: Date(), weightKg: .nan)
            check("nan_weight_returns_nil", store.save(entry: invalid) == nil)
            check("failed_save_restores_entries", store.entries == entriesBeforeFailure)
            check("failed_save_restores_ledger", store.settings == settingsBeforeFailure)
            check("failed_save_preserves_primary_bytes", try Data(contentsOf: Persistence.fileURL) == bytesBeforeFailure)
            check("failed_save_has_no_success_feedback", store.milestone == nil && store.toast == nil)
            check("failed_save_exposes_storage_error", store.storageError != nil)

            // The edit crosses progress thresholds, so silence here is meaningful.
            var edited = live
            edited.weightKg = 70
            check("edit_saved_without_celebration", store.save(entry: edited) != nil && store.milestone == nil && store.toast == nil)
            check("edited_threshold_recognized_as_history", store.settings.achievementUnlocks.contains {
                $0.id == .progress50 && $0.earnedAt == nil
            })

            // This historical row reaches the goal and joins a three-day streak.
            let backfill = WeightEntry(date: historyDay, weightKg: 65)
            check("backfill_saved_without_celebration", store.save(entry: backfill) != nil && store.milestone == nil && store.toast == nil)
            check("backfill_unlock_has_unknown_date", store.settings.achievementUnlocks.contains {
                $0.id == .goalReached && $0.earnedAt == nil
            })

            let firstWaterID = UUID()
            let secondWaterID = UUID()
            let extraWaterID = UUID()
            check("first_water_saved", store.saveWater(ml: 500, at: Date(), id: firstWaterID))
            check("water_goal_saved", store.saveWater(ml: 1500, at: Date(), id: secondWaterID))
            let waterUnlock = store.settings.achievementUnlocks.first { $0.id == .waterGoal }
            check("water_goal_unlock_has_known_date", waterUnlock?.earnedAt != nil)
            check("water_goal_unlock_is_persisted", try Persistence.load()?.settings.achievementUnlocks.contains {
                $0.id == .waterGoal && $0.earnedAt != nil
            } == true)
            check("first_water_goal_has_feedback", store.toast != nil)
            store.consumeToast()
            check("extra_water_saved", store.saveWater(ml: 100, at: Date(), id: extraWaterID))
            check("water_goal_does_not_repeat", store.settings.achievementUnlocks.filter { $0.id == .waterGoal }.count == 1
                  && store.settings.achievementUnlocks.first { $0.id == .waterGoal } == waterUnlock
                  && store.toast == nil && store.milestone == nil)

            if let firstWater = store.waterEntries.first(where: { $0.id == firstWaterID }) {
                store.deleteWater(firstWater)
            }
            let remainingWaterIDs = Set(store.waterEntries.map(\.id))
            check("exact_water_delete_keeps_other_ids", !remainingWaterIDs.contains(firstWaterID)
                  && remainingWaterIDs.contains(secondWaterID) && remainingWaterIDs.contains(extraWaterID))
            check("water_delete_keeps_earned_badge", store.settings.achievementUnlocks.contains { $0.id == .waterGoal })
            check("water_delete_preserves_correct_total", store.todayWaterMl == 1600)

            store.clearAll()
            check("clear_all_clears_records", store.entries.isEmpty && store.waterEntries.isEmpty)
            check("clear_all_clears_ledger", store.settings.achievementUnlocks.isEmpty && store.achievementUnlocks.isEmpty)
            if let cleared = try Persistence.load() {
                check("clear_all_is_persisted", cleared.entries.isEmpty && cleared.waterEntries.isEmpty
                      && cleared.settings.achievementUnlocks.isEmpty)
            } else {
                check("clear_all_is_persisted", false)
            }
        } catch {
            checks["unexpected_error"] = false
            diagnostics.append(String(describing: error))
        }

        let failures = checks.filter { !$0.value }.map(\.key).sorted() + diagnostics
        let report = Report(checks: checks, failures: failures)
        do {
            let folder = URL.documentsDirectory
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(report).write(to: folder.appendingPathComponent("ui-store-checks.json"), options: .atomic)
            print("Store smoke: \(checks.count) checks, \(failures.count) failures")
        } catch {
            print("Failed to write simulator Store smoke report: \(error)")
        }
    }

    private enum CheckFailure: Error {
        case setup(String)
    }
}
#endif
