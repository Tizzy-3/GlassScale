import SwiftUI

/// 主题选择：点选后即时换肤（界面重建），选择会持久化。
struct ThemePickerView: View {
    @Environment(WeightStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AppTheme.allCases) { theme in
                            themeCell(theme)
                        }
                    }
                    .padding(Theme.pagePadding)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("主题")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func themeCell(_ theme: AppTheme) -> some View {
        let selected = store.settings.theme == theme
        return Button {
            var s = store.settings
            s.theme = theme
            store.updateSettings(s)
        } label: {
            VStack(spacing: 10) {
                HStack(spacing: -10) {
                    ForEach(theme.swatches.indices, id: \.self) { i in
                        Circle()
                            .fill(theme.swatches[i])
                            .frame(width: 30, height: 30)
                            .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                    }
                }
                Text(theme.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(theme.success)
                    .opacity(selected ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Theme.tileCorner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.tileCorner, style: .continuous)
                    .stroke(selected ? theme.primary : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
