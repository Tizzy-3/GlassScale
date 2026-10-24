# GlassScale UI preview

- Ocean blue and mint use existing AppTheme semantic colors. Lavender is a restrained ambient accent.
- System SF/PingFang typography. Weight readings use rounded tabular digits and adapt to Dynamic Type.
- Native TabView supplies the floating Liquid Glass tab bar. Glass buttons supply key actions; content panels use adaptive secondarySystemGroupedBackground.
- Page margin 20 points; content corner radius 26, hero 34; ordinary tap controls at least 44 points.
- Dashboard: date/header, dominant weight and timestamp, small goal ring, 7-day sparkline, three metrics, inline record button, compact water progress/presets, recent history and secondary details.
- Records: direct weight/water switch and calendar/list control, month view, selected-day records, backfill action. Independent sheets use one NavigationStack; embedded content does not add a nested navigation container.
- Light and dark use semantic colors. Preserve reduced-motion support. Keep sufficient scroll safe-area clearance for system bars and adaptive text.
- Validate on the actual iOS 26 simulator; generated concept images are references, not screenshots of the app.
