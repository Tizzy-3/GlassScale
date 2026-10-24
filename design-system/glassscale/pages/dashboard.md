# Homepage application of the master

- Preserve all existing weight/water logging, calendar/backfill, goal, recent records, 30-day chart and BMI/baseline/projection disclosures.
- Header date opens the calendar. Seven-day cells open the selected day in the existing calendar/backfill sheet; today stays distinct from the date being viewed. Cells have >=44pt targets with horizontal scrolling when needed. The strip itself adds no record persistence.
- Compact pale weight hero, mint hydration panel, actionable recent entries, detailed chart and secondary disclosure. At 375pt, hero summaries and its short chart move into an explicit weight-details sheet, preserving readable text and prioritizing weight/water actions.
- Hero: same `WeightStats`, latest timestamp, optional ring, daily-policy sparkline, three summaries. Rename the existing `delta7dKg` display to `较7日前`; do not change its formula.
- Hydration: existing total/goal and cup presets/custom/history/settings. Successful save offers six-second undo of that exact saved WaterEntry UUID; it must not remove a different later entry or show success after a failed save. Cup/receipt share a stable reserved frame.
- Phone content scrolls naturally inside native TabView; never add a custom bottom overlay or a 140pt spacer. Large text may scroll instead of squeezing all content onto one screen.
- Legacy ContentCard/GlassCard and editors retain their appearance. The approved collectible-achievement extension adds an optional settings ledger and pure rules; see the current interaction/achievements spec. Other tabs' complete visual migration remains a separate page task.
