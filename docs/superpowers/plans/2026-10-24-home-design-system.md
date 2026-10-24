# Homepage design-system implementation plan

> Execute the confirmed audit scope inline; missing superpowers dependencies are replaced with existing tools. Review each deliverable before the next. No main merge.

**Goal:** Apply a coherent accessible design system to the existing homepage while preserving business behavior and all entry points.

**Architecture:** Add opt-in SwiftUI tokens/surfaces/styles under Design; update the three dashboard views and one decorative native cup component. Legacy styles and other pages retain their appearance. Only DEBUG simulator fixtures and screenshot tooling may change outside this UI scope to verify empty/large-text/small-screen states.

**Tech Stack:** Existing SwiftUI, Swift Charts, UIKit dynamic colors, GitHub Actions Xcode26 builds. No added runtime dependency.

- [x] Establish MASTER and homepage specification from the approved review, excluding off-topic generated web templates.
- [ ] Add `Design/AppDesign.swift`: dynamic semantic colors for five themes, typography/spacing/radii/elevation/motion, opt-in surface and ButtonStyles. Verify foreground/background ratios using code constants.
- [ ] Add `Design/WaterCupView.swift`: scalable original rounded vector cup, progress-driven water, readable light/dark face, decorative accessibility semantics, reduced-motion-aware short acknowledgment.
- [ ] Update DashboardView/HeroCard/WaterCard: compact hierarchy and summaries, preserve all closures/sheets, label delta accurately, accessible layout and success-only feedback. Do not edit Core, other tabs or shared legacy components.
- [ ] Extend screenshot fixtures/tooling only as needed: stable demo water, light/dark homepage, empty, accessibility text and available small iPhone. Preserve Release exclusion of demo injection.
- [ ] Check diff scope, push this trial branch, run `bash tests/run.sh` and existing iOS build via CI, inspect original before/after simulator captures and fix material overflow/contrast issues.
- [ ] Report homepage changes, actual evidence and remaining device-only checks; wait for the user's next page direction.
