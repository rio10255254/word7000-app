import SwiftUI
import UIKit

/// Semantic colors. Blue is the one accent; green means known, orange means
/// review and streaks, red a miss. Surfaces are the system grouped colors so
/// light and dark mode always match the rest of iOS.
enum Palette {
    static let accent = Color.accentColor
    static let known = Color(uiColor: .systemGreen)
    static let review = Color(uiColor: .systemOrange)
    static let miss = Color(uiColor: .systemRed)
    static let chinese = Color(uiColor: .systemIndigo)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let fill = Color(uiColor: .tertiarySystemFill)
    static let secondaryLabel = Color(uiColor: .secondaryLabel)
    static let tertiaryLabel = Color(uiColor: .tertiaryLabel)
    static let separator = Color(uiColor: .separator)
}

/// SF Rounded for headings and numbers, the regular system face for reading.
extension Font {
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .rounded, weight: weight)
    }

    static func roundedSize(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

enum Metrics {
    static let cardRadius: CGFloat = 22
    static let wordCardRadius: CGFloat = 28
    static let gutter: CGFloat = 16
}

enum Motion {
    static let card = Animation.spring(response: 0.38, dampingFraction: 0.88)
    static let reveal = Animation.smooth(duration: 0.3)
    static let press = Animation.easeOut(duration: 0.12)
}

struct SoftPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : Motion.press, value: configuration.isPressed)
    }
}

/// A borderless grouped card, the building block of every screen.
struct CardBackground: ViewModifier {
    var radius: CGFloat = Metrics.cardRadius
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func card(radius: CGFloat = Metrics.cardRadius, padding: CGFloat = 16) -> some View {
        modifier(CardBackground(radius: radius, padding: padding))
    }

    /// The main call to action: a full-width capsule, Liquid Glass on iOS 26.
    @ViewBuilder
    func prominentAction(tint: Color = Palette.accent) -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glassProminent).buttonBorderShape(.capsule).controlSize(.large).tint(tint)
        } else {
            self.buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.large).tint(tint)
        }
    }

    /// A secondary action next to a prominent one.
    @ViewBuilder
    func secondaryAction(tint: Color = Palette.accent) -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass).buttonBorderShape(.capsule).controlSize(.large).tint(tint)
        } else {
            self.buttonStyle(.bordered).buttonBorderShape(.capsule).controlSize(.large).tint(tint)
        }
    }
}

enum AppearancePreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var label: String {
        switch self {
        case .system: L.themeSystem
        case .light: L.themeLight
        case .dark: L.themeDark
        }
    }
}
