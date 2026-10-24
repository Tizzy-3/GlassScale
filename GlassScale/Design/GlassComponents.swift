import SwiftUI

// MARK: - 玻璃卡片

/// 一块液态玻璃面板。
///
/// 遵循 Apple 的建议：玻璃只用在「浮在内容之上的导航 / 关键操作层」，
/// 普通列表行不用玻璃（既省电又避免玻璃叠玻璃）。
struct GlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let contentPadding: CGFloat
    let glass: Glass
    let content: Content

    init(
        cornerRadius: CGFloat = Theme.cardCorner,
        contentPadding: CGFloat = 18,
        tint: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.contentPadding = contentPadding
        self.glass = tint.map { Glass.regular.tint($0) } ?? .regular
        self.content = content()
    }

    var body: some View {
        content
            .padding(contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(glass, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - 统计磁贴

/// 首页 2×2 的小玻璃块。
struct StatTile: View {
    let title: String
    let value: String
    var unitText: String? = nil
    var symbol: String
    var valueColor: Color = .primary
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.caption.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(valueColor)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let unitText {
                    Text(unitText)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Theme.tileCorner, style: .continuous))
    }
}

// MARK: - 标题

struct SectionTitle: View {
    let text: String
    var symbol: String? = nil
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
            }
            Text(text)
                .font(.headline)
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
    }
}

// MARK: - 胶囊标签

struct GlassChip: View {
    let text: String
    var symbol: String? = nil
    var tint: Color? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol).font(.caption2.weight(.semibold))
            }
            Text(text).font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(
            tint.map { Glass.regular.tint($0) } ?? .regular,
            in: .capsule
        )
    }
}

// MARK: - 玻璃按钮

/// 圆形玻璃图标按钮。
struct GlassIconButton: View {
    let systemImage: String
    var size: CGFloat = 44
    var tint: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.4, weight: .semibold))
                .frame(width: size, height: size)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .tint(tint ?? .primary)
    }
}

// MARK: - 分段选择器

/// 分段控件里的一项（用 struct 而不是元组，因为 Swift 的 keyPath 不能指向元组元素）。
struct SegmentedItem<T: Hashable>: Identifiable {
    let value: T
    let label: String
    var id: T { value }

    init(value: T, label: String) {
        self.value = value
        self.label = label
    }
}

/// 玻璃质感的分段控件，用于趋势区间切换。
struct GlassSegmented<T: Hashable>: View {
    let items: [SegmentedItem<T>]
    @Binding var selection: T
    var namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                Button {
                    withAnimation(.snappy(duration: 0.28)) {
                        selection = item.value
                    }
                } label: {
                    Text(item.label)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(.rect)
                        .background {
                            if selection == item.value {
                                Capsule(style: .continuous)
                                    .fill(.white.opacity(0.22))
                                    .matchedGeometryEffect(id: "seg", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .glassEffect(.regular, in: .capsule)
    }
}

// MARK: - 空状态

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(Theme.brandGradient)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) {
                    Label {
                        Text(actionTitle)
                    } icon: {
                        Image(systemName: "plus")
                    }
                }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
                    .tint(Theme.aqua)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
