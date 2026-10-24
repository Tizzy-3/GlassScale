# Floating glass UI preview implementation

**Goal:** Implement the approved two-screen concept on `ui/floating-glass-preview`, leaving main unchanged.

**Design:** Existing ocean blue/mint identity, dominant current-weight reading and secondary goal ring, seven-day sparkline and compact metrics, inline weight action, water immediately afterward. Records exposes weight/water and calendar/list controls directly. System TabView owns floating Liquid Glass tab bar and safe areas; do not imitate its geometry with a custom bottom overlay.

**Architecture:** SwiftUI views and shared content surface only; keep existing model, persistence, reminders and HealthKit behavior. Retain access to all existing data actions and empty/error states. Dynamic Type adapts compact rows to vertical layouts.

## Tasks
- [x] Dashboard/HeroCard: prominent reading, timestamp, small goal ring, sparkline, three metrics, primary logging; water before secondary history. Preserve goal/BMI/trend access.
- [x] WaterCard: compact progress and cup actions on dashboard, weekly water strip lives in water details.
- [x] History/Calendar/WaterHistory: directly switch data type and display style; embed reusable calendar content without nested NavigationStacks; preserve search, editing, deletion, goal/export/clear and sheet access.
- [x] Shared content surface/background: quiet readable light/dark adaptive content panels; native glass for action/navigation controls. Native TabView remains untouched except semantic icons and normal safe-area behavior.
- [x] CI: build this branch, run existing core regressions; generate debug-only simulator fixture, capture real light/dark dashboard and records screenshots; upload screenshots separately from unsigned IPA.
- [x] Verify exact-head CI, inspect real simulator screenshots, push only this branch and report any device validation limits.

## Verification
Existing two-timezone regression checks; iOS Release build and unsigned IPA; actual simulator rendering for layout/contrast/native tab bar. Screenshot fixtures are DEBUG-only and never populate user data in Release builds. Phone fluid refraction, gesture behavior and scrolling remain device checks.

First pass: commit `8367358`, Actions run `39989826060`: 110 checks passed in each timezone, Release and Simulator builds succeeded, four real iPhone 17 Pro screenshots captured. Image inspection confirmed the native floating tab bar and identified two layout fixes: raise dashboard cup actions above the bar and keep the calendar legend inside its panel. These spacing fixes require a final branch build before delivery.

Final application verification: commit `566cbd92539619981719d0824e558db504332c0f`, [Actions run 40043596741](https://github.com/Tizzy-3/GlassScale/actions/runs/40043596741), completed successfully. Both timezones passed 110 checks each; Release and Debug Simulator builds succeeded. All four original iPhone 17 Pro screenshots were inspected: dashboard cup actions are fully above the native floating bar, the calendar legend stays within its panel, and both light/dark layouts render correctly. The fixture water total varies with the runner's current time; it is demonstration data only. This does not verify phone gestures, device performance, HealthKit permissions or notifications.

Deliverables: unsigned IPA artifact `12540392265` and original screenshot artifact `12540845738`, both built from the verified application commit. Main remained `a84f09956652b0179507fc472b659edac1a744c1`. The closing documentation commit changes no application code or build configuration.
