# Homepage Interactions and Achievements Implementation Plan

> Use existing tools and executing-plans task-by-task. Core policy and storage have independent ownership and may be delegated; page delivery stays sequential. User already approved recommendations and selected collectible achievements; resolve routine details from the spec without another permission cycle.

**Goal:** Make the homepage actionable and add optional collectible encouragement with a badge history.

**Architecture:** Reuse calendar/editor/tab routing and current local store. Add pure achievement definitions/policy, an additive settings ledger and one native achievements page. Preserve restored main and original record semantics.

**Tech Stack:** Existing SwiftUI, Swift Charts, Foundation, Observation, GitHub Actions Xcode26.

## Global constraints

- Only preview branch; no main commits, merge or new branches.
- Spec: `docs/superpowers/specs/2026-10-24-home-interactions-achievements-design.md`.
- Keep old JSON/backups compatible, no writes on page reads, rollback ledger together with failed saves.
- >=44pt targets, native tabs, semantic colors/fonts, Reduce Motion and Dynamic Type.
- Finish/report homepage before producing achievements UI; other tabs' full restyle is a later page.

## Tasks

- [ ] Policy: add `Core/Model/Achievement.swift`, `AchievementEngine.swift`; tests in `tests/main.swift` for direction, goal boundaries, same-day repetition, future samples, streak gaps/DST, water, ledger dedup, JSON.
- [ ] Store: additive `AppSettings` ledger/default decoding; integrate `WeightStore` success-only unlocks, history seeding, feedback priority, failure rollback and clear-all. Preserve imported/edited data semantics.
- [ ] Homepage: `DashboardView`, `HeroCard`, `WaterCard`, `RecordingCalendarView`, `RootView` for date actions, editor/all-record navigation, compact details, exact-entry undo, explicit goal action. Validate build/screens and report page.
- [ ] Achievements page: new `Features/Achievements/AchievementsView.swift`; home/My entry points. Readable grouped badges and unlock history. Update `CelebrationView` accessibility/motion.
- [ ] Screenshot fixture/tooling: isolate demo states behind DEBUG simulator flags; capture meaningful new page states. Run existing model checks and Release/Debug builds and inspect originals.
- [ ] Review diff/data compatibility and final remote branch count, save project-local verification report, push only preview and deliver actual results/limits.
