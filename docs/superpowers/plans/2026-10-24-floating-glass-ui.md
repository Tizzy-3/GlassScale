# Floating glass UI preview implementation

**Goal:** Implement the approved two-screen concept on `ui/floating-glass-preview`, leaving main unchanged.

**Design:** Existing ocean blue/mint identity, dominant current-weight reading and secondary goal ring, seven-day sparkline and compact metrics, inline weight action, water immediately afterward. Records exposes weight/water and calendar/list controls directly. System TabView owns floating Liquid Glass tab bar and safe areas; do not imitate its geometry with a custom bottom overlay.

**Architecture:** SwiftUI views and shared content surface only; keep existing model, persistence, reminders and HealthKit behavior. Retain access to all existing data actions and empty/error states. Dynamic Type adapts compact rows to vertical layouts.

## Tasks
- [ ] Dashboard/HeroCard: prominent reading, timestamp, small goal ring, sparkline, three metrics, primary logging; water before secondary history. Preserve goal/BMI/trend access.
- [ ] WaterCard: compact progress and cup actions on dashboard, weekly water strip lives in water details.
- [ ] History/Calendar/WaterHistory: directly switch data type and display style; embed reusable calendar content without nested NavigationStacks; preserve search, editing, deletion, goal/export/clear and sheet access.
- [ ] Shared content surface/background: quiet readable light/dark adaptive content panels; native glass for action/navigation controls. Native TabView remains untouched except semantic icons and normal safe-area behavior.
- [ ] CI: build this branch, run existing core regressions; generate debug-only simulator fixture, capture real light/dark dashboard and records screenshots; upload screenshots separately from unsigned IPA.
- [ ] Verify exact-head CI, inspect real simulator screenshots, push only this branch and report any device validation limits.

## Verification
Existing two-timezone regression checks; iOS Release build and unsigned IPA; actual simulator rendering for layout/contrast/native tab bar. Screenshot fixtures are DEBUG-only and never populate user data in Release builds. Phone fluid refraction, gesture behavior and scrolling remain device checks.
