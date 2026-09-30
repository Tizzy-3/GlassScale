import SwiftUI

/// 首次启动的三步引导。
struct OnboardingView: View {
    @Environment(WeightStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// 从「我的 → 重新查看引导」进入时为 true，此时点完成不会写入任何数据
    var playMode: Bool = false

    @Namespace private var sexNS
    @State private var page = 0
    @State private var heightCm: Double = 170
    @State private var age: Int = 28
    @State private var sex: BodyProfile.Sex = .unspecified
    @State private var weightText = "70.0"
    @State private var targetText = "65.0"
    @State private var targetDate = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var loadSample = false

    private var unit: WeightUnit { store.settings.weightUnit }

    private var weightKg: Double { unit.kilograms(for: Double(weightText) ?? 0) }
    private var targetKg: Double { unit.kilograms(for: Double(targetText) ?? 0) }

    private var canFinish: Bool {
        weightKg > 20 && weightKg < 400 && targetKg > 20 && targetKg < 400
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcomePage.tag(0)
                bodyPage.tag(1)
                goalPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.snappy, value: page)

            bottomBar
        }
        .onAppear {
            if let baseline = store.profile.baselineKg {
                weightText = Fmt.number(unit.value(forKg: baseline), decimals: 1)
            }
        }
    }

    // MARK: - 第 1 页

    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 180, height: 180)
                    .glassEffect(.clear, in: .circle)
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 76, weight: .light))
                    .foregroundStyle(Theme.brandGradient)
            }
            .frame(height: 220)

            Text("琉璃称")
                .font(.system(size: 40, weight: .bold, design: .rounded))
            Text("液态玻璃质感的体重管理记录")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            Spacer()

            VStack(spacing: 10) {
                featureRow("chart.xyaxis.line", "看得清趋势", "日均线抹掉水分波动，只留真实变化")
                featureRow("lock.shield", "只存在这台设备", "没有账号、没有联网，数据不会上传")
                featureRow("heart.text.square", "可对接「健康」", "授权后自动同步 iPhone 与 Apple Watch 的体重")
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 24)
    }

    private func featureRow(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.aqua)
                .frame(width: 40, height: 40)
                .glassEffect(.regular, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - 第 2 页

    private var bodyPage: some View {
        ScrollView {
            VStack(spacing: 16) {
                OnboardingHeader(
                    title: "先了解一下你",
                    subtitle: "身高用来算 BMI，性别年龄暂时只存在本机"
                )

                GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Label("身高", systemImage: "ruler")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text("\(Fmt.height(heightCm, store.settings.lengthUnit, decimals: 0)) \(store.settings.lengthUnit.symbol)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .contentTransition(.numericText())
                        }
                        Slider(value: $heightCm, in: 120...220, step: 1)
                            .tint(Theme.aqua)
                    }
                }

                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        ForEach(BodyProfile.Sex.allCases) { s in
                            Button {
                                withAnimation(.snappy) { sex = s }
                            } label: {
                                Text(s.title)
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background {
                                        if sex == s {
                                            Capsule().fill(.white.opacity(0.22))
                                                .matchedGeometryEffect(id: "sex", in: sexNS)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .glassEffect(.regular, in: .capsule)
                }

                GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 20) {
                    Stepper(value: $age, in: 12...100) {
                        Label("年龄 \(age) 岁", systemImage: "calendar")
                            .font(.subheadline.weight(.medium))
                    }
                }

                GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 20, tint: Theme.aqua.opacity(0.3)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("现在的体重")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            TextField("70.0", text: $weightText)
                                .font(.system(size: 46, weight: .bold, design: .rounded))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 170)
                            Text(unit.symbol)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(Theme.pagePadding)
        }
    }

    // MARK: - 第 3 页

    private var goalPage: some View {
        ScrollView {
            VStack(spacing: 16) {
                OnboardingHeader(
                    title: "定一个目标",
                    subtitle: "可以随时改，先定下来更容易坚持"
                )

                GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 20, tint: Theme.mint.opacity(0.3)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("目标体重")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            TextField("65.0", text: $targetText)
                                .font(.system(size: 46, weight: .bold, design: .rounded))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 170)
                            Text(unit.symbol)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        if weightKg > 0, targetKg > 0 {
                            let delta = targetKg - weightKg
                            Text(delta == 0
                                 ? "保持当前体重"
                                 : "需要\(delta < 0 ? "减" : "增") \(Fmt.number(abs(unit.value(forKg: delta)), decimals: 1)) \(unit.symbol)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 18) {
                    DatePicker(selection: $targetDate, in: Date()..., displayedComponents: .date) {
                        Label("希望达成于", systemImage: "calendar")
                            .font(.subheadline.weight(.medium))
                    }
                }

                GlassCard(cornerRadius: Theme.cardCorner, contentPadding: 16) {
                    Toggle(isOn: $loadSample) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("先放 90 天示例数据")
                                .font(.subheadline.weight(.medium))
                            Text("方便你先看看长什么样，之后可一键清空")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(Theme.violet)
                }
            }
            .padding(Theme.pagePadding)
            .padding(.bottom, 20)
        }
    }

    // MARK: - 底部

    private var bottomBar: some View {
        VStack(spacing: 14) {
            HStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Theme.aqua : .white.opacity(0.22))
                        .frame(width: i == page ? 22 : 7, height: 7)
                        .animation(.snappy, value: page)
                }
            }

            HStack(spacing: 12) {
                if page > 0 {
                    Button("上一步", systemImage: "chevron.left") {
                        withAnimation(.snappy) { page -= 1 }
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                }

                Button(page == 2 ? "开始使用" : "下一步") {
                    if page == 2 {
                        finish()
                    } else {
                        withAnimation(.snappy) { page += 1 }
                    }
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .tint(Theme.aqua)
                .frame(maxWidth: .infinity)
                .disabled(page == 2 && !canFinish)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
    }

    private func finish() {
        if playMode {
            dismiss()
            return
        }

        var profile = store.profile
        profile.heightCm = heightCm
        profile.age = age
        profile.sex = sex
        profile.baselineKg = weightKg > 0 ? weightKg : nil

        store.updateProfile(profile)
        store.settings.hasCompletedOnboarding = true
        store.updateSettings(store.settings)

        if weightKg > 0 {
            store.save(entry: WeightEntry(date: Date(), weightKg: weightKg), silently: true)
        }
        if targetKg > 0 {
            store.setGoal(targetWeightKg: targetKg, targetDate: targetDate)
        }
        if loadSample {
            store.loadSampleData()
        }
    }
}

struct OnboardingHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }
}
