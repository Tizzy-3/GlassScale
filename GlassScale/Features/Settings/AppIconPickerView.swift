import SwiftUI
import UIKit

/// App 图标选择：默认 + 两款胖嘟嘟备选。点选后调用系统换图标（会弹一次系统确认框），选择会持久化。
struct AppIconPickerView: View {
    @Environment(WeightStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

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
        return Button {
            apply(choice)
        } label: {
            VStack(spacing: 10) {
                iconPreview(choice)
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.25), lineWidth: 0.5)
                    )
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
        guard UIApplication.shared.supportsAlternateIcons else {
            errorMessage = "当前设备不支持更换 App 图标"
            return
        }
        // 系统会自动弹一次确认框
        UIApplication.shared.setAlternateIconName(choice.iconName) { error in
            DispatchQueue.main.async {
                if let error {
                    errorMessage = error.localizedDescription
                } else {
                    var s = store.settings
                    s.appIcon = choice
                    store.updateSettings(s)
                }
            }
        }
    }
}
