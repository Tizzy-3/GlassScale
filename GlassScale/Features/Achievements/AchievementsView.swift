import SwiftUI

/// The collection is a snapshot of the existing local ledger; opening it never writes data.
struct AchievementsView: View {
    @Environment(WeightStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selection: AchievementFilter = .all
    @State private var selectedBadge: AchievementDefinition?
    @State private var previewDetailOpened = false
    @State private var showGoalEditor = false

    private enum AchievementFilter: String, CaseIterable, Identifiable {
        case all = "全部徽章"
        case history = "解锁记录"
        var id: String { rawValue }
    }

    init() {
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--ui-preview-achievement-history") {
            _selection = State(initialValue: AchievementFilter.history)
        }
        #endif
    }

    var body: some View {
        let unlocks = store.achievementUnlocks
        let owned = unlocks.reduce(into: [AchievementID: AchievementUnlock]()) { $0[$1.id] = $1 }
        let unit = store.unit

        NavigationStack {
            ZStack {
                AppDesign.Palette.canvas.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: AppDesign.Space.section) {
                        progressHeader(ownedCount: owned.count)
                        filterControl
                        if selection == .all {
                            catalog(owned: owned, unit: unit)
                        } else {
                            AchievementHistory(unlocks: unlocks, unit: unit) { selectedBadge = $0 }
                            if unlocks.isEmpty { emptyHistory }
                        }
                        Text("每枚徽章记录第一次达成。目标类成就跟随你设定的方向；已经解锁的成就会保留在记录里。")
                            .font(.caption).foregroundStyle(AppDesign.Palette.secondaryText)
                    }
                    .frame(maxWidth: AppDesign.Space.maximumContentWidth)
                    .padding(AppDesign.Space.page)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .foregroundStyle(AppDesign.Palette.primaryText)
            }
            .navigationTitle("我的成就")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
            .sheet(item: $selectedBadge) { definition in
                AchievementDetail(definition: definition, unlock: owned[definition.id], unit: unit)
            }
            .sheet(isPresented: $showGoalEditor) { GoalEditorView() }
            .task {
                #if DEBUG && targetEnvironment(simulator)
                guard !previewDetailOpened else { return }
                previewDetailOpened = true
                if ProcessInfo.processInfo.arguments.contains("--ui-preview-badge-detail") {
                    do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
                    selectedBadge = AchievementEngine.catalog.first { $0.id == .firstKilogram }
                }
                #endif
            }
        }
        .tint(AppDesign.Palette.action)
    }

    private func progressHeader(ownedCount: Int) -> some View {
        AppSurface(.weight) {
            VStack(alignment: .leading, spacing: AppDesign.Space.md) {
                Label("每一步，都有记录", systemImage: "trophy.fill").font(.headline)
                Text("已解锁 \(ownedCount) / \(AchievementEngine.catalog.count)")
                    .font(.title2.weight(.bold)).monospacedDigit()
                ProgressView(value: Double(ownedCount), total: Double(AchievementEngine.catalog.count))
                    .accessibilityHidden(true)
                Text(ownedCount == 0 ? "从第一笔记录开始，收集属于自己的成就。" : "按自己的节奏，记住一路走来的进展。")
                    .font(.subheadline).foregroundStyle(AppDesign.Palette.secondaryText)
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder private var filterControl: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Picker("成就视图", selection: $selection) { filterOptions }
                .pickerStyle(.menu)
                .frame(minHeight: AppDesign.Control.minimumTarget)
        } else {
            Picker("成就视图", selection: $selection) { filterOptions }
                .pickerStyle(.segmented)
                .frame(minHeight: AppDesign.Control.minimumTarget)
        }
    }

    private var filterOptions: some View {
        ForEach(AchievementFilter.allCases) { filter in Text(filter.rawValue).tag(filter) }
    }

    private func catalog(owned: [AchievementID: AchievementUnlock], unit: WeightUnit) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: AppDesign.Space.md, alignment: .top),
                            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
        return VStack(alignment: .leading, spacing: AppDesign.Space.section) {
            ForEach(AchievementCategory.allCases) { category in
                VStack(alignment: .leading, spacing: AppDesign.Space.md) {
                    Text(category.title).font(.headline).accessibilityAddTraits(.isHeader)
                    if category == .progress {
                        Button(store.goal == nil ? "设置体重目标" : "调整体重目标", systemImage: "target") { showGoalEditor = true }
                            .buttonStyle(AppSecondaryButtonStyle())
                    }
                    LazyVGrid(columns: columns, alignment: .leading, spacing: AppDesign.Space.md) {
                        ForEach(AchievementEngine.catalog.filter { $0.category == category }) { definition in
                            AchievementTile(definition: definition, unlock: owned[definition.id], unit: unit) {
                                selectedBadge = definition
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyHistory: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: AppDesign.Space.md) {
                Text("第一枚成就，等你开启").font(.headline)
                Text("保存第一笔体重，或完成一天的喝水目标，成就会自动出现在这里。")
                    .font(.subheadline).foregroundStyle(AppDesign.Palette.secondaryText)
                Button("查看徽章条件") { selection = .all }.buttonStyle(AppSecondaryButtonStyle())
            }
        }
    }
}

/// The whole card is the native Button target, including its padding.
struct AchievementEntryRow: View {
    @Environment(WeightStore.self) private var store
    let action: () -> Void

    var body: some View {
        let unlocks = store.achievementUnlocks
        Button(action: action) {
          AppSurface {
            HStack(spacing: AppDesign.Space.md) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: AppDesign.Control.iconSize, weight: .semibold))
                    .foregroundStyle(AppDesign.Palette.action).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppDesign.Space.xs) {
                    Text("我的成就").font(.headline).foregroundStyle(AppDesign.Palette.primaryText)
                    Text("已解锁 \(unlocks.count) / \(AchievementEngine.catalog.count)")
                        .font(.subheadline).foregroundStyle(AppDesign.Palette.secondaryText).monospacedDigit()
                }
                Spacer(minLength: AppDesign.Space.sm)
                Image(systemName: "chevron.right").font(.system(size: AppDesign.Control.iconSize))
                    .foregroundStyle(AppDesign.Palette.secondaryText).accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: AppDesign.Control.minimumTarget, alignment: .leading)
            .contentShape(.rect)
          }
        }
        .buttonStyle(AchievementTileButtonStyle())
        .accessibilityLabel("我的成就，已解锁 \(unlocks.count) 枚，共 \(AchievementEngine.catalog.count) 枚")
        .accessibilityHint("查看徽章与解锁记录")
    }
}

private struct AchievementTile: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let definition: AchievementDefinition
    let unlock: AchievementUnlock?
    let unit: WeightUnit
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AppSurface {
                VStack(alignment: .leading, spacing: AppDesign.Space.md) {
                    AchievementEmblem(definition: definition, isUnlocked: unlock != nil)
                    Text(definition.displayTitle(unit: unit)).font(.headline)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                    Label(unlock == nil ? "未解锁" : "已解锁", systemImage: unlock == nil ? "lock.fill" : "checkmark.seal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(unlock == nil ? AppDesign.Palette.secondaryText : AppDesign.Palette.success)
                    Text(definition.displayDetail(unit: unit)).font(.caption)
                        .foregroundStyle(AppDesign.Palette.secondaryText)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                }
                .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 0 : 204, alignment: .topLeading)
            }
        }
        .buttonStyle(AchievementTileButtonStyle())
        .accessibilityLabel("\(definition.displayTitle(unit: unit))，\(unlock == nil ? "未解锁" : "已解锁")。\(definition.displayDetail(unit: unit))")
        .accessibilityHint("查看完整条件与成就详情")
    }
}

private struct AchievementEmblem: View {
    let definition: AchievementDefinition
    let isUnlocked: Bool
    var size: CGFloat = 64

    private var tone: Color {
        definition.category == .progress ? AppDesign.Palette.success : AppDesign.Palette.action
    }

    var body: some View {
        Image(systemName: definition.symbol)
            .font(.system(size: min(size * 0.45, 40), weight: .semibold))
            .foregroundStyle(isUnlocked ? tone : AppDesign.Palette.secondaryText)
            .frame(width: size, height: size)
            .background(tone.opacity(isUnlocked ? 0.13 : 0.05), in: .circle)
            .accessibilityHidden(true)
    }
}

private struct AchievementHistory: View {
    let unlocks: [AchievementUnlock]
    let unit: WeightUnit
    let onSelect: (AchievementDefinition) -> Void

    private var dated: [AchievementUnlock] {
        let order = Dictionary(uniqueKeysWithValues: AchievementEngine.catalog.enumerated().map { ($0.element.id, $0.offset) })
        return unlocks.filter { $0.earnedAt != nil }.sorted {
            let left = $0.earnedAt ?? .distantPast
            let right = $1.earnedAt ?? .distantPast
            return left == right ? (order[$0.id] ?? 0) < (order[$1.id] ?? 0) : left > right
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Space.section) {
            if !dated.isEmpty {
                historySection("解锁记录", records: dated)
            }
            let historical = unlocks.filter { $0.earnedAt == nil }
            if !historical.isEmpty {
                historySection("由历史记录识别", records: historical)
            }
        }
    }

    private func historySection(_ title: String, records: [AchievementUnlock]) -> some View {
        VStack(alignment: .leading, spacing: AppDesign.Space.md) {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            ForEach(records) { unlock in
                if let definition = AchievementEngine.catalog.first(where: { $0.id == unlock.id }) {
                    Button { onSelect(definition) } label: {
                        AppSurface {
                            HStack(spacing: AppDesign.Space.md) {
                                AchievementEmblem(definition: definition, isUnlocked: true, size: 44)
                                VStack(alignment: .leading, spacing: AppDesign.Space.xs) {
                                    Text(definition.displayTitle(unit: unit)).font(.headline)
                                    if let date = unlock.earnedAt {
                                        Text(date, format: .dateTime.year().month().day().hour().minute())
                                            .font(.caption).foregroundStyle(AppDesign.Palette.secondaryText)
                                    } else {
                                        Text("原始解锁日期未知").font(.caption).foregroundStyle(AppDesign.Palette.secondaryText)
                                    }
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.system(size: AppDesign.Control.iconSize))
                                    .foregroundStyle(AppDesign.Palette.secondaryText).accessibilityHidden(true)
                            }
                            .frame(minHeight: AppDesign.Control.minimumTarget)
                        }
                    }
                    .buttonStyle(AchievementTileButtonStyle())
                    .accessibilityHint("查看成就详情")
                }
            }
        }
    }
}

private struct AchievementDetail: View {
    @Environment(\.dismiss) private var dismiss
    let definition: AchievementDefinition
    let unlock: AchievementUnlock?
    let unit: WeightUnit

    var body: some View {
        NavigationStack {
            ZStack {
                AppDesign.Palette.canvas.ignoresSafeArea()
                ScrollView {
                    AppSurface(.weight) {
                        VStack(alignment: .leading, spacing: AppDesign.Space.section) {
                            AchievementEmblem(definition: definition, isUnlocked: unlock != nil, size: 88)
                            Text(definition.displayTitle(unit: unit)).font(.title2.weight(.bold))
                                .accessibilityAddTraits(.isHeader)
                            Label(unlock == nil ? "尚未解锁" : "已解锁", systemImage: unlock == nil ? "lock.fill" : "checkmark.seal.fill")
                                .font(.headline).foregroundStyle(unlock == nil ? AppDesign.Palette.secondaryText : AppDesign.Palette.success)
                            VStack(alignment: .leading, spacing: AppDesign.Space.sm) {
                                Text("解锁条件").font(.headline)
                                Text(definition.displayDetail(unit: unit)).font(.body)
                                    .foregroundStyle(AppDesign.Palette.secondaryText)
                            }
                            if let unlock {
                                if let date = unlock.earnedAt {
                                    Text("解锁于 \(date.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.subheadline).foregroundStyle(AppDesign.Palette.secondaryText)
                                } else {
                                    Text("由历史记录识别，原始解锁日期未知。")
                                        .font(.subheadline).foregroundStyle(AppDesign.Palette.secondaryText)
                                }
                            } else {
                                Text(definition.category == .progress
                                     ? "目标类成就需要先设置一个与起点不同的体重目标，按目标方向前进。"
                                     : "达成条件后，会自动保存在你的成就记录里。")
                                    .font(.subheadline).foregroundStyle(AppDesign.Palette.secondaryText)
                            }
                            Button("知道了") { dismiss() }.buttonStyle(AppPrimaryButtonStyle())
                        }
                    }
                    .frame(maxWidth: AppDesign.Space.maximumContentWidth)
                    .padding(AppDesign.Space.page).frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .foregroundStyle(AppDesign.Palette.primaryText)
            .navigationTitle("成就详情").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
        .tint(AppDesign.Palette.action)
    }
}

private struct AchievementTileButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.Radius.card, style: .continuous)
                    .strokeBorder(configuration.isPressed ? AppDesign.Palette.action : .clear, lineWidth: 1.5)
            }
            .animation(reduceMotion ? nil : AppDesign.Motion.press, value: configuration.isPressed)
    }
}
