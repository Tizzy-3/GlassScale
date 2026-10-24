# Homepage interactions and collectible achievements

The user approved the UI/UX recommendations and selected collectible achievements (light encouragement plus badges and an unlock history). Continue only `ui/floating-glass-preview`; keep exactly two remote branches and leave the restored `main` untouched. No new framework. Existing weight/water records, import/export and backup compatibility remain valid.

## Delivery order

1. Complete homepage interactions, compact layout, immediate undo and feedback; report that page before implementing another page.
2. Complete the achievements page and add entry points from homepage and My. Other tabs' full visual migration follows separately, page by page.
3. Core achievement policy/storage may be developed alongside homepage work; it is not another page.

## Homepage

- Header date opens existing calendar; each recent date opens its day. Calendar selection does not pretend the whole dashboard is showing that day. Today remains identifiable. Targets >=44pt; compact date strips may scroll horizontally.
- Recent records open existing editor; a clear All Records action selects the records tab. Replace a one-item More menu with an explicit goal control.
- Compact width prioritizes weight logging and water actions. Preserve secondary numbers and charts via an explicit expandable details section rather than shrinking text or removing data.
- Successful water feedback offers undo of that recorded entry. Undo must never remove a different entry; failed persistence must not show success.
- Shared colors/type/spacing/motion remain AppDesign; preserve native TabView. Transitions are brief, interruptible and honor Reduce Motion.

## Achievement rules

Twelve lifetime badges in three groups: firstWeight, streak3, streak7, streak14, streak30; firstKilogram, threeKilograms, progress25, progress50, progress75, goalReached; waterGoal.

- Counting uses unique calendar days, excludes future samples and honors daily weight policy. Streak rewards use the best historical calendar-day run; repeated same-day readings add no streak days.
- Weight progress requires a nonzero configured goal. Its direction follows target minus baseline, including gain goals. Cap kg progress at the planned goal span; no reward for moving away or going beyond a smaller configured loss/gain. No speed-based rewards or negative/shaming messages.
- Goal percentage badges are lifetime first achievements, not a new badge every time target/date changes. Existing earned badges survive fluctuations and individual deletions. Explicit Clear All Records clears badges too.
- Water badge means at least one calendar day meeting the configured positive goal; no reward for exceeding it.
- First unlock is recorded once. Historical records are recognized silently with unknown unlock date displayed as From Historical Records. New successful live saves may attach a known unlock date.
- Do not celebrate edits, backfills, imports, future records, failed writes or already-owned badges. A save crossing multiple thresholds may unlock all badges but presents one highest-priority feedback item; goal reached wins.
- Routine progress and habits use a brief message; goal/meaningful progress stages may use the existing celebration surface. It must support Reduce Motion, Dynamic Type and a manual close; don't auto-dismiss before someone can read it.

## Shared API contract

`AchievementID: String, Codable, CaseIterable, Hashable` cases are exactly the twelve names above.

`AchievementCategory: String, CaseIterable, Identifiable` cases recording, progress, hydration; has title.

`AchievementDefinition: Identifiable` exposes id: AchievementID, title: String, detail: String, symbol: String, category: AchievementCategory.

`AchievementUnlock: Codable, Hashable, Identifiable` exposes id: AchievementID and earnedAt: Date?; initializer defaults earnedAt to nil.

`AchievementEngine.catalog: [AchievementDefinition]` is the canonical order and copy.

`AchievementEngine.earnedIDs(entries: [WeightEntry], goal: WeightGoal?, baselineKg: Double?, waterEntries: [WaterEntry], waterGoalMl: Int, policy: DailyWeightPolicy = .latest, now: Date = Date(), calendar: Calendar = .current) -> Set<AchievementID>`.

`AchievementEngine.mergedUnlocks(existing: [AchievementUnlock], earnedIDs: Set<AchievementID>, earnedAt: Date? = nil) -> [AchievementUnlock]` preserves existing dates, normalizes duplicates and follows catalog order.

Persist additive `AppSettings.achievementUnlocks: [AchievementUnlock] = []` with decodeIfPresent. Existing backup payload already contains settings; do not create another database or separate unbacked store. `WeightStore.achievementUnlocks` exposes normalized owned + silently recognized historical unlocks. All related record/settings mutations must preserve atomic persistence/rollback behavior. New ledger entries are written with normal saves, not unsolicited writes on reading a page.

## Achievements page

One native sheet/page, reachable from home and My. Sections group the twelve readable vector badges. Show owned/total count, clear locked conditions, unlocked status and a history view sorted by known date (unknown historical dates explicitly labeled). Locked text remains readable; don't fade the whole tile. No new bottom tab, account, cloud service, ranking or reward currency.

## Validation

Meaningful pure policy/JSON checks in existing two-timezone regression suite; device Release build and simulator Debug build. Actual homepage light/dark, 375pt and large text; actual achievement page empty/owned/history, light/dark and large text. State runtime limits accurately; screenshots don't prove haptics, VoiceOver or animation performance.
