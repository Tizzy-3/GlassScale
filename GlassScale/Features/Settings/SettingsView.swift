import SwiftUI

struct SettingsView: View {
    @Environment(WeightStore.self) private var store

    @State private var showGoalEditor = false
    @State private var showProfileEditor = false
    @State private var showExport = false
    @State private var showOnboarding = false
    @State private var isImporting = false
    @State private var confirmClear = false
    @State private var confirmSample = false

    private var unit: WeightUnit { store.unit }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                List {
                    profileSection
                    goalSection
                    unitSection
                    healthSection
                    dataSection
                    aboutSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                // 给底部快捷条 + 标签栏让出空间
                .safeAreaPadding(.bottom, 84)
            }
            .navigationTitle("我的")
            .sheet(isPresented: $showGoalEditor) { GoalEditorView() }
            .sheet(isPresented: $showProfileEditor) { ProfileEditorView() }
            .sheet(isPresented: $showExport) { ExportSheet() }
            .sheet(isPresented: $showOnboarding) { OnboardingView(playMode: true) }
            .confirmationDialog("确定清空全部记录？此操作不可撤销。", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("清空", role: .destructive) { store.clearAll() }
                Button("取消", role: .cancel) {}
            }
            .confirmationDialog("载入示例数据会覆盖现有记录，确定继续？", isPresented: $confirmSample, titleVisibility: .visible) {
                Button("覆盖并载入", role: .destructive) { store.loadSampleData() }
                Button("取消", role: .cancel) {}
            }
        }
    }

    // MARK: - 身体档案

    private var profileSection: some View {
        Section("身体档案") {
            row(symbol: "ruler", title: "身高 / 年龄 / 性别", action: { showProfileEditor = true }) {
                Text("\(Fmt.height(store.profile.heightCm, store.settings.lengthUnit)) \(store.settings.lengthUnit.symbol)")
                    .foregroundStyle(.secondary)
            }

            row(symbol: "scalemass", title: "起始体重", action: { showProfileEditor = true }) {
                Text(store.baselineKg.map { "\(Fmt.weight($0, unit)) \(unit.symbol)" } ?? "未设置")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 目标

    private var goalSection: some View {
        Section("目标") {
            row(symbol: "target", title: "目标体重", action: { showGoalEditor = true }) {
                Text(store.goal.map { "\(Fmt.weight($0.targetWeightKg, unit)) \(unit.symbol)" } ?? "未设置")
                    .foregroundStyle(.secondary)
            }

            row(symbol: "calendar", title: "目标日期", action: { showGoalEditor = true }) {
                Text(store.goal?.targetDate.formatted(.dateTime.year().month().day()) ?? "—")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 单位

    private var unitSection: some View {
        Section("单位") {
            Picker("体重", selection: Binding<WeightUnit>(
                get: { store.settings.weightUnit },
                set: { store.settings.weightUnit = $0; store.updateSettings(store.settings) }
            )) {
                ForEach(WeightUnit.allCases) { u in
                    Text(u.title).tag(u)
                }
            }

            Picker("身高", selection: Binding<LengthUnit>(
                get: { store.settings.lengthUnit },
                set: { store.settings.lengthUnit = $0; store.updateSettings(store.settings) }
            )) {
                ForEach(LengthUnit.allCases) { u in
                    Text(u.title).tag(u)
                }
            }
        }
    }

    // MARK: - 健康

    private var healthSection: some View {
        Section {
            HStack {
                Label("状态", systemImage: "heart.text.square")
                Spacer()
                Text(healthStatusText)
                    .font(.subheadline)
                    .foregroundStyle(store.health.status.isConnected ? Theme.mint : .secondary)
            }

            if store.health.status == .notDetermined || store.health.status == .denied {
                row(symbol: "link", title: "连接「健康」", tint: Theme.mint, action: {
                    Task { await store.health.requestAuthorization() }
                }) {
                    EmptyView()
                }
            }

            row(symbol: "square.and.arrow.down", title: isImporting ? "导入中…" : "从「健康」导入", tint: Theme.mint, action: {
                Task { await importFromHealth() }
            }) {
                EmptyView()
            }
            .disabled(isImporting)

            Toggle("保存时同时写入「健康」", isOn: Binding<Bool>(
                get: { store.settings.syncWriteToHealth },
                set: { store.settings.syncWriteToHealth = $0; store.updateSettings(store.settings) }
            ))
        } header: {
            Text("Apple 健康")
        } footer: {
            Text("导入只读取体重数据并保存在本机；写入会把本应用的新记录同步给「健康」。两者都需要先点「连接」。")
        }
    }

    private var healthStatusText: String {
        switch store.health.status {
        case .unsupported: return "本机不可用"
        case .notDetermined: return "未连接"
        case .authorized: return "已连接"
        case .denied: return "已拒绝"
        case .failed: return "连接失败"
        }
    }

    // MARK: - 数据

    private var dataSection: some View {
        Section {
            row(symbol: "square.and.arrow.up", title: "导出数据", tint: Theme.violet, action: { showExport = true }) {
                EmptyView()
            }

            row(symbol: "wand.and.sparkles", title: "载入示例数据", tint: Theme.violet, action: { confirmSample = true }) {
                EmptyView()
            }

            row(symbol: "trash", title: "清空全部记录", tint: Theme.coral, action: { confirmClear = true }) {
                EmptyView()
            }
        } header: {
            Text("数据")
        } footer: {
            Text("共 \(store.entries.count) 条记录，全部保存在本机 Application Support 目录。")
        }
    }

    // MARK: - 关于

    private var aboutSection: some View {
        Section("关于") {
            HStack {
                Label("连续记录", systemImage: "flame")
                Spacer()
                Text("\(store.stats.streakDays) 天")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Label("最早记录", systemImage: "calendar.badge.clock")
                Spacer()
                Text(store.entries.first?.date.formatted(.dateTime.year().month().day()) ?? "—")
                    .foregroundStyle(.secondary)
            }
            row(symbol: "sparkles", title: "重新查看引导页", tint: Theme.aqua, action: { showOnboarding = true }) {
                EmptyView()
            }
            HStack {
                Label("版本", systemImage: "info.circle")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 组件

    private func row<Trailing: View>(
        symbol: String,
        title: String,
        tint: Color = Theme.aqua,
        action: @escaping () -> Void = {},
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                trailing()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 14)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Theme.tileCorner, style: .continuous))
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
    }

    // MARK: - 导入

    private func importFromHealth() async {
        isImporting = true
        defer { isImporting = false }

        if store.health.status == .notDetermined {
            await store.health.requestAuthorization()
        }

        do {
            let samples = try await store.health.fetchBodyMass(since: store.entries.first?.date)
            let existing = Set(store.entries.compactMap(\.healthKitUUID))
            let cal = Calendar.current
            var byDay: [Date: WeightEntry] = [:]
            for entry in store.entries { byDay[cal.startOfDay(for: entry.date)] = entry }

            var added = 0
            for sample in samples {
                let uuid = sample.uuid
                guard !existing.contains(uuid) else { continue }
                let day = cal.startOfDay(for: sample.startDate)
                // 一天内以「健康」里最晚的一条为准
                if let old = byDay[day], old.source == .healthKit, old.date >= sample.startDate { continue }
                if byDay[day] != nil, byDay[day]?.source == .manual { continue }

                let entry = WeightEntry(
                    date: sample.startDate,
                    weightKg: sample.quantity.doubleValue(for: .gramUnit(with: .kilo)),
                    source: .healthKit,
                    healthKitUUID: uuid
                )
                byDay[day] = entry
                added += 1
            }

            store.replaceAll(byDay.values.sorted { $0.date < $1.date })
            store.toast = added > 0 ? "已从「健康」导入 \(added) 条记录" : "没有新的体重数据"
        } catch {
            store.toast = "导入失败：\(error.localizedDescription)"
        }
    }
}

// MARK: - 档案编辑

struct ProfileEditorView: View {
    @Environment(WeightStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var heightCm: Double = 170
    @State private var age: Int = 28
    @State private var sex: BodyProfile.Sex = .unspecified
    @State private var baselineText = ""
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 20) {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Label("身高", systemImage: "ruler").font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text("\(Fmt.height(heightCm, store.settings.lengthUnit, decimals: 0)) \(store.settings.lengthUnit.symbol)")
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                        .contentTransition(.numericText())
                                }
                                Slider(value: $heightCm, in: 120...220, step: 1).tint(Theme.aqua)
                            }
                        }

                        GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 20) {
                            VStack(alignment: .leading, spacing: 14) {
                                Picker("性别", selection: $sex) {
                                    ForEach(BodyProfile.Sex.allCases) { s in
                                        Text(s.title).tag(s)
                                    }
                                }
                                .pickerStyle(.segmented)

                                Stepper(value: $age, in: 12...100) {
                                    Label("年龄 \(age) 岁", systemImage: "calendar")
                                        .font(.subheadline.weight(.medium))
                                }
                            }
                        }

                        GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 20) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("起始体重")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    TextField("选填", text: $baselineText)
                                        .font(.system(size: 40, weight: .bold, design: .rounded))
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(maxWidth: 160)
                                    Text(store.settings.weightUnit.symbol)
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                Text("用于计算目标完成度，默认取你最早一条记录。")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(Theme.pagePadding)
                }
            }
            .navigationTitle("身体档案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", systemImage: "checkmark") { save() }
                }
            }
            .onAppear(perform: load)
        }
        .presentationDetents([.large])
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        heightCm = store.profile.heightCm
        age = store.profile.age ?? 28
        sex = store.profile.sex
        baselineText = store.baselineKg.map { Fmt.number(store.unit.value(forKg: $0), decimals: 1) } ?? ""
    }

    private func save() {
        var profile = store.profile
        profile.heightCm = heightCm
        profile.age = age
        profile.sex = sex
        if let v = Double(baselineText.replacingOccurrences(of: ",", with: ".")), v > 20, v < 400 {
            profile.baselineKg = store.unit.kilograms(for: v)
        } else {
            profile.baselineKg = nil
        }
        store.updateProfile(profile)
        dismiss()
    }
}
