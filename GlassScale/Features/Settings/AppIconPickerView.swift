import SwiftUI
import UIKit

/// App 图标选择：默认 + 两款胖嘟嘟备选。点选后调用系统换图标（会弹一次系统确认框），选择会持久化。
struct AppIconPickerView: View {
    @Environment(WeightStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?
    @State private var switchingName: String? = nil  // 正在切换中的 iconName（防重复点击）

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AppIconChoice.allCases) { choice in
                            iconCell(choice)
                        }
                    }
                    .padding(Theme.pagePadding)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("App 图标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("切换失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear(perform: syncFromSystem)
        }
        .presentationDetents([.medium])
    }

    private func iconCell(_ choice: AppIconChoice) -> some View {
        let selected = store.settings.appIcon == choice
        let switching = switchingName == choice.iconName
        return Button {
            apply(choice)
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    iconPreview(choice)
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(.white.opacity(0.25), lineWidth: 0.5)
                        )
                    if switching {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .frame(width: 76, height: 76)
                        ProgressView()
                    }
                }
                Text(choice.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.aqua)
                    .opacity(selected ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Theme.tileCorner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.tileCorner, style: .continuous)
                    .stroke(selected ? Theme.aqua : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(switchingName != nil)
    }

    @ViewBuilder
    private func iconPreview(_ choice: AppIconChoice) -> some View {
        // 备选图标是构建脚本拷进包根目录的散装 PNG（不在 asset catalog 里），
        // 用明确路径加载最可靠；Image("name") 对这类文件的查找不可靠。
        if let name = choice.previewResourceName,
           let path = Bundle.main.path(forResource: name, ofType: "png"),
           let uiImage = UIImage(contentsOfFile: path) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            // 默认图标取不到内置预览，用玻璃拟物 tile 占位
            ZStack {
                LinearGradient(
                    colors: [Theme.aqua.opacity(0.55), Theme.violet.opacity(0.55)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                Image(systemName: "scalemass")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    /// 打开时以系统的实际图标为准（防止在系统设置里改过之后不同步）
    private func syncFromSystem() {
        let current = AppIconChoice.allCases.first(where: {
            $0.iconName == UIApplication.shared.alternateIconName
        }) ?? .default
        if store.settings.appIcon != current {
            var s = store.settings
            s.appIcon = current
            store.updateSettings(s)
        }
    }

    private func apply(_ choice: AppIconChoice) {
        guard store.settings.appIcon != choice else { return }
        guard switchingName == nil else { return }  // 切换中，忽略重复点击
        guard UIApplication.shared.supportsAlternateIcons else {
            errorMessage = "当前设备不支持更换 App 图标"
            return
        }
        switchingName = choice.iconName
        applyWithRetry(choice, attempt: 0)
    }

    /// iOS 26 的 LSIconAlertManager 在 LaunchServices 尚未索引完新安装 App 的备选图标
    /// 等情况下，会报 NSPOSIXErrorDomain Code 35 (EAGAIN)「资源暂时不可用」。
    /// EAGAIN 本意即"稍后再试"，属瞬时性错误，按 0.5s / 1s / 2s / 4s 退避重试（最多 5 次）。
    private func applyWithRetry(_ choice: AppIconChoice, attempt: Int) {
        // 系统会自动弹一次确认框
        UIApplication.shared.setAlternateIconName(choice.iconName) { error in
            if let nsError = error as NSError?,
               nsError.domain == NSPOSIXErrorDomain,
               nsError.code == 35,  // EAGAIN
               attempt < 4 {
                let backoff: [Double] = [0.5, 1.0, 2.0, 4.0]
                DispatchQueue.main.asyncAfter(deadline: .now() + backoff[attempt]) {
                    self.applyWithRetry(choice, attempt: attempt + 1)
                }
                return
            }
            DispatchQueue.main.async {
                self.switchingName = nil
                if let error {
                    let nsError = error as NSError
                    self.errorMessage = "\(error.localizedDescription)（\(nsError.domain) \(nsError.code)，已重试 \(attempt) 次）"
                } else {
                    var s = self.store.settings
                    s.appIcon = choice
                    self.store.updateSettings(s)
                }
            }
        }
    }
}
