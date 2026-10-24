# Collectible achievements page

User-selected scope: light encouragement plus a collection and unlock history. Apply existing native MASTER tokens. Automated marketing/sports templates and unrelated product matches were rejected; no orange sports rebrand, custom web font or hover interaction is adopted.

- Native NavigationStack sheet opened from homepage/My; preserve the four-tab navigation.
- A quiet progress header shows unlocked/12, then a native picker for all badges vs unlock history. Accessibility sizes use a menu and one-column reading; normal phone widths can use two adaptive columns.
- Three groups: recording, goal progress, hydration. Badge illustrations use SF Symbols inside soft category-color circles. Text uses primary/secondary palette roles; locked status has a lock label, not an opacity reduction across the whole tile.
- Badge tiles are native Buttons opening a detail sheet containing full conditions, ownership and known date or an explicit historical-recognition label. This avoids repeating the homepage's former noninteractive-control affordance problem.
- The history view uses known unlock dates descending, historical recognition grouped separately, and stable catalog ordering for ties. No invented exact historical unlock date.
- Clear empty copy explains the first step. No account, rankings, streak punishment, new tab or reward currency. Lifetime ownership and goal-direction rules are stated in the detail/footer.
- Surface radius24, gutters20, card padding16, structural symbols20-24, decorative badge symbols28-40. >=44pt controls and readable metadata. Long titles/conditions wrap; full conditions remain available in detail and accessibility labels.
- Ordinary records get brief feedback. Goal stages get one readable celebration card, manually dismissed and respecting Reduce Motion. Native graphics and text suffice; no bitmap assets or animation library.
- Validate actual light/dark, empty/earned/history, 375pt and largest Dynamic Type. Check text/owned state, full conditions, sheet close actions and no tab/safe-area collision. Screenshots do not establish VoiceOver/touch/haptic/frame-rate verification.
