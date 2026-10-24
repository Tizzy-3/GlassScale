import SwiftUI
import UIKit

/// Opt-in native design tokens. Legacy screens retain Theme until migrated separately.
enum AppDesign {
    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let page: CGFloat = 20
        static let section: CGFloat = 24
        static let maximumContentWidth: CGFloat = 680
    }

    enum Radius {
        static let hero: CGFloat = 28
        static let card: CGFloat = 24
        static let compact: CGFloat = 14
    }

    enum TypeScale {
        static let pageTitle = Font.largeTitle.weight(.bold)
        static let section = Font.headline
        static let label = Font.subheadline
        static let metadata = Font.caption
        static let metric = Font.title3.weight(.semibold)
        static let weightSize: CGFloat = 56
        static let waterSize: CGFloat = 30
    }

    enum Control {
        static let minimumTarget: CGFloat = 44
        static let primaryHeight: CGFloat = 48
        static let iconSize: CGFloat = 20
    }

    enum Elevation {
        static let radius: CGFloat = 12
        static let offset: CGFloat = 4
        static func opacity(for scheme: ColorScheme) -> Double { scheme == .dark ? 0.10 : 0.035 }
    }

    enum Motion {
        static let press = Animation.easeOut(duration: 0.12)
        static let state = Animation.easeOut(duration: 0.22)
        static let progress = Animation.smooth(duration: 0.38)
    }

    enum Palette {
        static var canvas: Color { adaptive(0xF5F8FC, 0x0E1722) }
        static var surface: Color { adaptive(0xFFFFFF, 0x182635) }
        static var weightSurface: Color {
            switch Theme.current {
            case .ocean: return adaptive(0xEAF5FC, 0x1B3041)
            case .sunset: return adaptive(0xFFF3E9, 0x392A23)
            case .forest: return adaptive(0xEDF7EF, 0x1D342A)
            case .grape: return adaptive(0xF3EEFC, 0x2B2941)
            case .sakura: return adaptive(0xFDEFF3, 0x382833)
            }
        }
        static var waterSurface: Color { adaptive(0xE9F8F3, 0x17383B) }
        static var primaryText: Color { adaptive(0x16334A, 0xEEF5FA) }
        static var secondaryText: Color { adaptive(0x536879, 0xB5C4D1) }
        static var action: Color {
            switch Theme.current {
            case .ocean: return adaptive(0x1677D2, 0x6AC8FF)
            case .sunset: return adaptive(0xA54B13, 0xF8B77B)
            case .forest: return adaptive(0x267344, 0x85D89B)
            case .grape: return adaptive(0x7441BF, 0xC2A4FF)
            case .sakura: return adaptive(0xA73E62, 0xF4B1C6)
            }
        }
        static var onAction: Color { adaptive(0xFFFFFF, 0x102333) }
        static var success: Color { adaptive(0x147A62, 0x63D7B7) }
        static var increase: Color { adaptive(0xB84632, 0xFFAA9B) }
        static var waterTrack: Color { adaptive(0xC5E6DC, 0x34585B) }
        static var border: Color { adaptive(0xDCE6EE, 0x334653) }

        static func delta(_ value: Double?) -> Color {
            guard let value, abs(value) > 0.05 else { return secondaryText }
            return value > 0 ? increase : success
        }

        private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
            Color(uiColor: UIColor { traits in
                let hex = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                               green: CGFloat((hex >> 8) & 255) / 255,
                               blue: CGFloat(hex & 255) / 255, alpha: 1)
            })
        }
    }
}

struct AppSurface<Content: View>: View {
    enum Role { case content, weight, hydration }
    @Environment(\.colorScheme) private var scheme
    let role: Role
    let padding: CGFloat
    let content: Content

    init(_ role: Role = .content, padding: CGFloat = AppDesign.Space.lg,
         @ViewBuilder content: () -> Content) {
        self.role = role
        self.padding = padding
        self.content = content()
    }

    private var fill: Color {
        switch role {
        case .content: return AppDesign.Palette.surface
        case .weight: return AppDesign.Palette.weightSurface
        case .hydration: return AppDesign.Palette.waterSurface
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: role == .weight ? AppDesign.Radius.hero : AppDesign.Radius.card,
                                     style: .continuous)
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(AppDesign.Palette.primaryText)
            .background(fill, in: shape)
            .overlay { shape.strokeBorder(AppDesign.Palette.border.opacity(0.6), lineWidth: 0.5) }
            .shadow(color: .black.opacity(AppDesign.Elevation.opacity(for: scheme)),
                    radius: AppDesign.Elevation.radius, y: AppDesign.Elevation.offset)
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: AppDesign.Control.primaryHeight)
            .foregroundStyle(AppDesign.Palette.onAction)
            .background {
                Capsule().fill(AppDesign.Palette.action)
                    .overlay {
                        Capsule().fill((scheme == .dark ? Color.white : Color.black)
                            .opacity(configuration.isPressed ? 0.08 : 0))
                    }
            }
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.985)
            .animation(reduceMotion ? nil : AppDesign.Motion.press, value: configuration.isPressed)
    }
}

/// A quiet native Button with a stable 44pt minimum hit area, including icon controls.
struct AppSecondaryButtonStyle: ButtonStyle {
    var iconOnly = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, iconOnly ? 0 : AppDesign.Space.md)
            .frame(minWidth: AppDesign.Control.minimumTarget, minHeight: AppDesign.Control.minimumTarget)
            .foregroundStyle(AppDesign.Palette.action)
            .background(AppDesign.Palette.surface, in: .capsule)
            .overlay {
                Capsule().strokeBorder(configuration.isPressed ? AppDesign.Palette.action : AppDesign.Palette.border.opacity(0.8),
                                       lineWidth: configuration.isPressed ? 1.5 : 0.5)
            }
            .animation(reduceMotion ? nil : AppDesign.Motion.press, value: configuration.isPressed)
    }
}

/// Keeps the full date hit region without adding another capsule behind the day circle.
struct RecordingDayButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(AppDesign.Palette.action.opacity(configuration.isPressed ? 0.08 : 0),
                        in: RoundedRectangle(cornerRadius: AppDesign.Radius.compact, style: .continuous))
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.97)
            .animation(reduceMotion ? nil : AppDesign.Motion.press, value: configuration.isPressed)
    }
}
