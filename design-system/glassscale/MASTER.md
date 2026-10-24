# GlassScale native design system

## Scope and source
Approved by the UI/UX review and the user's homepage implementation request. SwiftUI + Swift Charts on iOS 26. UI UX Pro Max `pro-rules.md`, UX touch/contrast guidance and SwiftUI Dynamic Type/reduced-motion guidance apply. Its automatic marketing-page layouts and web font suggestions were not adopted. The initial visual pass changed no data model. The later user-approved collectible-achievement extension adds a backwards-compatible settings ledger; original record models, statistical formulas, services and reminder rules remain in place. No new framework.

The existing ocean/mint identity and all five theme choices remain. This system is opt-in: homepage first; existing pages keep legacy styles until separately reviewed. Native TabView owns navigation material, dimensions, system gestures and safe areas.

## Color roles
Use `AppDesign.Palette`, not raw colors in page bodies. Colors adapt to light/dark and theme. Brand decoration is separate from text/action color.

| Role | Light / ocean | Dark / ocean |
|---|---|---|
| Canvas | #F5F8FC | #0E1722 |
| Content | #FFFFFF | #182635 |
| Weight surface | #EAF5FC | #1B3041 |
| Hydration surface | #E9F8F3 | #17383B |
| Primary text | #16334A | #EEF5FA |
| Secondary text | #536879 | #B5C4D1 |
| Action | #1677D2 | #6AC8FF |
| On action | #FFFFFF | #102333 |
| Text action on tinted surfaces | #1068B9 | #6AC8FF |
| Success text | #147A62 | #63D7B7 |
| Increasing-value text | #B84632 | #FFAA9B |

Other theme action pairs: sunset #A54B13/#F8B77B; forest #267344/#85D89B; grape #7441BF/#C2A4FF; sakura #A73E62/#F4B1C6. Each uses white foreground in light mode and #102333 in dark mode. Contrast-check all pairs: ordinary text >=4.5:1, meaningful lines/control graphics >=3:1. Decorative borders do not carry information by themselves.

## Type
System SF / Chinese system fallback. Use semantic SwiftUI text styles, rounded tabular figures for weight/water, and ScaledMetric for large readings. Default weight reading 56pt, water 30pt, titles `largeTitle`, section labels `headline`, content `body`/`subheadline`, metadata `caption`. At accessibility sizes, stack reading/ring and metrics vertically; preserve full unit and label rather than forcing a smaller font.

## Spacing, shape, elevation
Spacing: 4/8/12/16/20/24/32pt. Phone gutters 20pt, adaptive bounded content width 680pt on wide layouts. Card padding16-20pt, section gaps16pt, adjacent controls8pt. Hero radius28pt, card24pt, compact element14pt. Content panels have a fine decorative border and one restrained shadow (light opacity .035, dark .10, radius12, y4). No repeated nested glass on content.

## Components and states
- `AppSurface`: content/weight/hydration roles; stable readable background, adaptive border/elevation.
- Primary button: native Button semantics, 48pt minimum, contrasting action foreground; pressed state changes fill brightness/scale without relayout or fading the label.
- Secondary/icon buttons: 44pt minimum, explicit accessible name. Standalone header/menu symbols stay 20pt inside the target even at maximum text size. Destructive operations retain their existing handlers and native semantics.
- SF Symbols for structural controls; the original rounded water-cup character is a decorative content illustration. Numbers and text carry the precise amount/status. Its fill derives from the existing water progress.
- Empty: clear first-record action; single-day data: honest no-trend message; no goal: retain settings access and show an explanatory summary.
- Existing storage error/recovery UI remains in RootView. No success animation is shown for a failed water save.

## Motion and accessibility
Press80-150ms; state transitions180-250ms; numeric/progress updates300-450ms. Observe successful existing actions, do not add business events. Disable custom movement under accessibilityReduceMotion. No perpetual decoration on the homepage. Preserve existing system text/VoiceOver settings; label amount+unit and cup presets. Ordinary and accessibility text, light/dark, small phone, long values, empty data and an alternate theme require visual review.

## Acceptance
Existing two-timezone model/persistence regressions, iOS Release build, original simulator screenshots. Check actual tab clearance, cup controls, long numbers/units and accessibility reflow. Never present generated mockups as runtime screenshots. Report homepage results before moving to another page.

## Collectible achievement extension
Twelve vector badges grouped as recording/progress/hydration. Use existing action/success/secondary color roles, system type, card radius24 and spacing16. Locked states retain readable text and state labels; color alone never establishes ownership. Show a known unlock date or explicitly identify recognition from historical records. Use short feedback for routine achievements and a readable manually dismissible celebration for major goal stages. Honor Reduce Motion and largest Dynamic Type. Page content can scroll; add no tab, reward currency, ranking or paid mechanism.
