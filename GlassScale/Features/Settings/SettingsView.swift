import PhotosUI
import SwiftUI

struct SettingsView: View {
    @Environment(WeightStore.self) private var store

    @State private var showGoalEditor = false
    @State private var showProfileEditor = false
    @State private var showExport = false
    @State private var showImport = false
    @State private var showOnboarding = false
    @State private var showThemePicker = false
    @State private var isImporting = false
    @State private var confirmClear = false
    @State private var confirmSample = false

    private var unit: WeightUnit { store.unit }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        profileHeader
                        archiveCard
                        healthCard
                        preferenceCard
                        dataCard
                        aboutCard
                    }
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("我的")
            .sheet(isPresented: $showGoalEditor) { GoalEditorView() }
            .sheet(isPresented: $showProfileEditor) { ProfileEditorView() }
            .sheet(isPresented: $showExport) { ExportSheet() }
            .sheet(isPresented: $showImport) { ImportSheet() }
            .sheet(isPresented: $showOnboarding) { OnboardingView(playMode: true) }
            .sheet(isPresented: $showThemePicker) { ThemePickerView() }
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

    // MARK: - 顶部档案头

    private var profileHeader: some View {
        GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 20) {
            VStack(spacing: 14) {
                Button { showProfileEditor = true } label: {
                    HStack(spacing: 16) {
                        avatarView(size: 62)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.profile.nickname.isEmpty ? "轻点设置昵称" : store.profile.nickname)
                                .font(.headline)
                                .foregroundStyle(store.profile.nickname.isEmpty ? .secondary : .primary)
                                .lineLimit(1)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("当前")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(store.stats.currentKg.map { Fmt.weight($0, unit) } ?? "—")
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .contentTransition(.numericText())
                                Text(unit.symbol)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)

                HStack(spacing: 0) {
                    miniStat(value: "\(store.stats.streakDays)", label: "连续天数")
                    Divider().frame(height: 30)
                    miniStat(value: "\(store.entries.count)", label: "累计记录")
                    Divider().frame(height: 30)
                    miniStat(value: store.stats.bmi.map { Fmt.number($0, decimals: 1) } ?? "—", label: "BMI")
                }
            }
        }
    }

    /// 有头像显示头像，没有显示占位图标
    private func avatarView(size: CGFloat) -> some View {
        Group {
            if let avatar = store.avatarImage {
                Image(uiImage: avatar)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
            } else {
                Image(systemName: "person.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.aqua)
                    .frame(width: size, height: size)
                    .glassEffect(.regular, in: .circle)
            }
        }
    }

    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.headline.weight(.bold))
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 分组卡片

    private func card<Content: View>(
        title: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: title, symbol: symbol)
                .padding(.horizontal, 4)
            GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 8) {
                VStack(spacing: 0) {
                    content()
                }
            }
        }
    }

    private var rowDivider: some View {
        Divider().padding(.leading, 56)
    }

    // MARK: - 档案与目标

    private var archiveCard: some View {
        card(title: "档案与目标", symbol: "person.crop.circle") {
            navRow(symbol: "ruler", title: "身体档案", action: { showProfileEditor = true }) {
                Text("\(Fmt.height(store.profile.heightCm, store.settings.lengthUnit)) \(store.settings.lengthUnit.symbol) · \(store.profile.sex.title)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            rowDivider
            navRow(symbol: "scalemass", title: "起始体重", action: { showProfileEditor = true }) {
                Text(store.baselineKg.map { "\(Fmt.weight($0, unit)) \(unit.symbol)" } ?? "未设置")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            rowDivider
            navRow(symbol: "target", title: "目标体重", tint: Theme.mint, action: { showGoalEditor = true }) {
                Text(store.goal.map { "\(Fmt.weight($0.targetWeightKg, unit)) \(unit.symbol)" } ?? "未设置")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            rowDivider
            navRow(symbol: "calendar", title: "目标日期", tint: Theme.mint, action: { showGoalEditor = true }) {
                Text(store.goal?.targetDate.formatted(.dateTime.year().month().day()) ?? "—")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Apple 健康

    private var healthCard: some View {
        card(title: "Apple 健康", symbol: "heart.text.square") {
            infoRow(symbol: "heart.text.square", title: "连接状态", tint: Theme.mint) {
                Text(healthStatusText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(store.health.status.isConnected ? Theme.mint : .secondary)
            }
            if store.health.status == .notDetermined || store.health.status == .denied {
                rowDivider
                navRow(symbol: "link", title: "连接「健康」", tint: Theme.mint, action: {
                    Task { await store.health.requestAuthorization() }
                }) { EmptyView() }
            }
            rowDivider
            navRow(symbol: "square.and.arrow.down", title: isImporting ? "导入中…" : "从「健康」导入", tint: Theme.mint, action: {
                Task { await importFromHealth() }
            }) { EmptyView() }
            .disabled(isImporting)
            rowDivider
            toggleRow(symbol: "arrow.triangle.2.circlepath", title: "保存时写入「健康」", tint: Theme.mint, isOn: Binding<Bool>(
                get: { store.settings.syncWriteToHealth },
                set: { store.settings.syncWriteToHealth = $0; store.updateSettings(store.settings) }
            ))
            Text("导入只读取体重数据并保存在本机；写入会把本应用的新记录同步给「健康」。两者都需要先点「连接」。")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
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

    // MARK: - 偏好设置

    private var preferenceCard: some View {
        card(title: "偏好设置", symbol: "gearshape") {
            navRow(symbol: "paintpalette", title: "主题", tint: Theme.violet, action: { showThemePicker = true }) {
                HStack(spacing: -6) {
                    ForEach(store.settings.theme.swatches.indices, id: \.self) { i in
                        Circle()
                            .fill(store.settings.theme.swatches[i])
                            .frame(width: 18, height: 18)
                            .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 0.5))
                    }
                }
            }
            rowDivider
            unitPickerRow(symbol: "scalemass", title: "体重单位", selection: Binding<WeightUnit>(
                get: { store.settings.weightUnit },
                set: { store.settings.weightUnit = $0; store.updateSettings(store.settings) }
            ), options: WeightUnit.allCases, label: \.title)
            rowDivider
            unitPickerRow(symbol: "ruler", title: "身高单位", selection: Binding<LengthUnit>(
                get: { store.settings.lengthUnit },
                set: { store.settings.lengthUnit = $0; store.updateSettings(store.settings) }
            ), options: LengthUnit.allCases, label: \.title)
        }
    }

    private func unitPickerRow<U: Hashable>(
        symbol: String,
        title: String,
        selection: Binding<U>,
        options: [U],
        label: KeyPath<U, String>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.aqua)
                .frame(width: 32, height: 32)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(title)
                .font(.subheadline)
            Spacer(minLength: 8)
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { o in
                    Text(o[keyPath: label]).tag(o)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.aqua)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }

    // MARK: - 数据管理

    private var dataCard: some View {
        card(title: "数据管理", symbol: "externaldrive") {
            navRow(symbol: "square.and.arrow.up", title: "导出数据", tint: Theme.violet, action: { showExport = true }) {
                Text("CSV / JSON")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            rowDivider
            navRow(symbol: "square.and.arrow.down", title: "导入数据", tint: Theme.mint, action: { showImport = true }) {
                Text("CSV / JSON")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            rowDivider
            navRow(symbol: "wand.and.sparkles", title: "载入示例数据", tint: Theme.violet, action: { confirmSample = true }) { EmptyView() }
            rowDivider
            navRow(symbol: "trash", title: "清空全部记录", destructive: true, action: { confirmClear = true }) { EmptyView() }
            Text("共 \(store.entries.count) 条记录，全部保存在本机，不上传云端。")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
    }

    // MARK: - 关于

    private var aboutCard: some View {
        card(title: "关于", symbol: "info.circle") {
            navRow(symbol: "sparkles", title: "重新查看引导页", action: { showOnboarding = true }) { EmptyView() }
            rowDivider
            infoRow(symbol: "info.circle", title: "版本") {
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 行组件

    private func navRow<Trailing: View>(
        symbol: String,
        title: String,
        tint: Color = Theme.aqua,
        destructive: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(destructive ? Theme.coral : tint)
                    .frame(width: 32, height: 32)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(destructive ? Theme.coral : .primary)
                Spacer(minLength: 8)
                trailing()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func infoRow<Trailing: View>(
        symbol: String,
        title: String,
        tint: Color = Theme.aqua,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(title)
                .font(.subheadline)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }

    private func toggleRow(symbol: String, title: String, tint: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(title)
                .font(.subheadline)
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
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
    @State private var nickname = ""
    @State private var avatarItem: PhotosPickerItem?
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 20) {
                            VStack(spacing: 14) {
                                HStack(spacing: 16) {
                                    Group {
                                        if let avatar = store.avatarImage {
                                            Image(uiImage: avatar)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 56, height: 56)
                                                .clipShape(Circle())
                                                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                                        } else {
                                            Image(systemName: "person.fill")
                                                .font(.title3)
                                                .foregroundStyle(Theme.aqua)
                                                .frame(width: 56, height: 56)
                                                .glassEffect(.regular, in: .circle)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 8) {
                                        PhotosPicker(selection: $avatarItem, matching: .images) {
                                            Label("更换头像", systemImage: "photo")
                                                .font(.subheadline.weight(.medium))
                                        }
                                        .buttonStyle(.glass)
                                        .buttonBorderShape(.capsule)

                                        if store.avatarImage != nil {
                                            Button("移除头像", role: .destructive) {
                                                store.removeAvatar()
                                            }
                                            .font(.caption)
                                        }
                                    }

                                    Spacer()
                                }

                                Divider()

                                HStack {
                                    Text("昵称")
                                        .font(.subheadline.weight(.medium))
                                    TextField("给自己起个名字", text: $nickname)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                        }

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
            .onChange(of: avatarItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        store.saveAvatar(image)
                    }
                    avatarItem = nil
                }
            }
        }
        .presentationDetents([.large])
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        heightCm = store.profile.heightCm
        age = store.profile.age ?? 28
        sex = store.profile.sex
        nickname = store.profile.nickname
        baselineText = store.baselineKg.map { Fmt.number(store.unit.value(forKg: $0), decimals: 1) } ?? ""
    }

    private func save() {
        var profile = store.profile
        profile.heightCm = heightCm
        profile.age = age
        profile.sex = sex
        profile.nickname = String(nickname.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        if let v = Double(baselineText.replacingOccurrences(of: ",", with: ".")), v > 20, v < 400 {
            profile.baselineKg = store.unit.kilograms(for: v)
        } else {
            profile.baselineKg = nil
        }
        store.updateProfile(profile)
        dismiss()
    }
}
