# Homepage application of the master

- Preserve all existing weight/water logging, calendar/backfill, goal, recent records, 30-day chart and BMI/baseline/projection disclosures.
- Header + read-only seven-day recording strip, compact pale weight hero, mint hydration panel, recent entries, detailed chart and secondary disclosure. The strip reads existing entries and adds no persistence or new action.
- Hero: same `WeightStats`, latest timestamp, optional ring, daily-policy sparkline, three summaries. Rename the existing `delta7dKg` display to `较7日前`; do not change its formula.
- Hydration: existing total/goal, same cup presets/custom/history/settings/undo handlers. Cute vector cup reflects the existing progress; acknowledgment and haptics occur only if the existing save changes today's total successfully.
- Phone content scrolls naturally inside native TabView; never add a custom bottom overlay or a 140pt spacer. Large text may scroll instead of squeezing all content onto one screen.
- Legacy ContentCard/GlassCard, other tabs, editors, Core and existing models remain unchanged in this stage.
