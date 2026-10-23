# Daily recording implementation plan

> For agentic workers: execute the approved scope task by task; use available subagents for independent modules and review integration in the parent session.

**Goal:** Reliable multi-entry weight and water recording, date-based statistics, local reminders, water history and calendar backfill.

**Architecture:** Keep SwiftUI/Observation and the existing JSON store. Add backward-compatible settings, pure daily selection and reminder scheduling, focused feature screens, and explicit persistence errors. Preserve existing appearance and body-fat fields.

**Tech Stack:** iOS 26, SwiftUI, Foundation, UserNotifications, Swift regression executable, GitHub Actions/Xcode.

## Constraints
- No account, third-party dependency, widgets, reports or new body-fat features.
- Reminders default off; request notification permission only after the user enables them.
- Multiple weight entries survive saving/import; use configurable latest/earliest/lowest daily representative for daily averages and charts.
- Missing days are excluded from averages; averages cover calendar days and not entry counts.
- Keep existing backup compatibility and preserve unreadable original files.

## Tasks
- [x] Statistics: daily representative policy, 7/30 calendar-day averages; regressions cover gaps, same-day samples, policy and future samples.
- [x] Store and persistence: update by ID only; exact-sample import dedup; durable save errors, last-good backup/recovery, flush on background; fix per-entry HealthKit override.
- [x] Water: dated create/update/delete, history and backfill, configurable common cup volumes. Integrate APIs `saveWater(ml:at:id:)`, `deleteWater(_:)`, `waterEntries(on:)`, `setWaterCupSizes(_:)`.
- [x] Reminders: Codable defaults, pure schedule generator, daily weight suppression, quiet water hours including overnight, permission/error UI, reschedule after changes and foreground/day rollover.
- [x] Calendar: month grid, weight/water markers and selected-day detail; create/edit/delete records and backfill selected dates with current time-of-day.
- [x] Verification: add Swift regression executable outside app target; CI runs regression before unsigned IPA build; inspect final diff, push approved project changes, verify exact-head build result.

## Acceptance
Old JSON opens; manual same-day weight entries remain distinct; 7-day mean excludes older samples and ignores missing days; day representatives are configurable; disabling sync on an individual save prevents HealthKit write. Water changes affect only selected record/day. Notification denial is visible and reminders respect saved schedule. Failed storage never claims success or silently overwrites unreadable data; recoverable backup is available. Calendar-selected past dates prefill correctly, while ordinary create uses now. iOS archive/build and functional regression checks are distinct from phone notification/UI verification.

## Verification evidence
- Final application source: `318f28b6300f6d0b27b9b0a54c8f0fe82210c5fd`.
- GitHub Actions run `39979206549`: core regressions in Asia/Shanghai and America/Los_Angeles, iOS Release build, unsigned IPA packaging and artifact upload all succeeded.
- Phone notification delivery, actual HealthKit writes and visual interaction remain device acceptance checks; no claim of phone verification.
