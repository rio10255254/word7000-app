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
    /// A lively spring with a little overshoot, for things that pop into place.
    static let pop = Animation.spring(response: 0.34, dampingFraction: 0.6)
    /// Rings and bars filling up.
    static let fill = Animation.spring(response: 0.9, dampingFraction: 0.86)

    /// The parts of a screen settling in one after another.
    static func entrance(_ order: Int) -> Animation {
        .spring(response: 0.5, dampingFraction: 0.8).delay(0.05 + Double(order) * 0.06)
    }
}

/// Sinks a little under the finger and springs back when released.
struct SoftPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1)
            .animation(reduceMotion ? nil : configuration.isPressed ? Motion.press : Motion.pop, value: configuration.isPressed)
    }
}

/// Rises into place the first time the view appears, `order` beats after the
/// parts above it. Decoration only: with Reduce Motion the view is simply there.
struct Entrance: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var order: Int
    var distance: CGFloat
    @State private var shown = false

    func body(content: Content) -> some View {
        let settled = shown || reduceMotion
        // Never fully transparent, so VoiceOver and UI tests can reach it mid-flight.
        return content
            .opacity(settled ? 1 : 0.01)
            .offset(y: settled ? 0 : distance)
            .scaleEffect(settled ? 1 : 0.97)
            .onAppear {
                guard !shown, !reduceMotion else { return }
                withAnimation(Motion.entrance(order)) { shown = true }
            }
    }
}

/// A grouped card raised off the page, the building block of every screen.
struct CardBackground: ViewModifier {
    var radius: CGFloat = Metrics.cardRadius
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { PremiumSurface(radius: radius) }
    }
}

/// A raised surface: the card colour with a hairline edge that catches the
/// light at the top, and a soft two-layer shadow beneath.
struct PremiumSurface: View {
    @Environment(\.colorScheme) private var colorScheme
    var radius: CGFloat
    var fill: Color = Palette.surface

    var body: some View {
        let dark = colorScheme == .dark
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape
            .fill(fill)
            .overlay {
                shape.strokeBorder(
                    LinearGradient(colors: dark ? [.white.opacity(0.16), .white.opacity(0.03)] : [.white.opacity(0.9), .black.opacity(0.06)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 1)
            }
            .shadow(color: .black.opacity(dark ? 0.3 : 0.04), radius: 1, y: 1)
            .shadow(color: .black.opacity(dark ? 0.25 : 0.07), radius: 14, y: 8)
    }
}

/// A quiet wash of colour behind a screen: two soft glows over the grouped
/// background that drift very slowly. They hold still under Reduce Motion.
struct AmbientBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    var tint: Color = Palette.accent
    var secondTint: Color = Palette.chinese

    var body: some View {
        let dark = colorScheme == .dark
        GeometryReader { proxy in
            let width = proxy.size.width
            let glows = ZStack {
                Circle()
                    .fill(tint.opacity(dark ? 0.3 : 0.16))
                    .frame(width: width * 1.1, height: width * 1.1)
                    .blur(radius: 70)
                    .offset(x: -width * 0.38, y: -width * 0.55)
                Circle()
                    .fill(secondTint.opacity(dark ? 0.24 : 0.12))
                    .frame(width: width, height: width)
                    .blur(radius: 70)
                    .offset(x: width * 0.45, y: -width * 0.15)
            }
            .frame(width: width, height: proxy.size.height, alignment: .top)
            if reduceMotion {
                glows
            } else {
                glows.phaseAnimator([false, true]) { content, drifted in
                    content
                        .offset(x: drifted ? 24 : -18, y: drifted ? 16 : -10)
                        .scaleEffect(drifted ? 1.06 : 1)
                } animation: { _ in
                    Animation.easeInOut(duration: 9)
                }
            }
        }
        .background(Palette.background)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Pops from small to full size the first time it appears, e.g. a result's
/// checkmark. With Reduce Motion it is simply there.
struct PopIn: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var delay: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        let settled = shown || reduceMotion
        return content
            .scaleEffect(settled ? 1 : 0.3)
            .opacity(settled ? 1 : 0.01)
            .onAppear {
                guard !shown, !reduceMotion else { return }
                withAnimation(Motion.pop.delay(delay)) { shown = true }
            }
    }
}

extension View {
    func card(radius: CGFloat = Metrics.cardRadius, padding: CGFloat = 16) -> some View {
        modifier(CardBackground(radius: radius, padding: padding))
    }

    func entrance(_ order: Int = 0, distance: CGFloat = 16) -> some View {
        modifier(Entrance(order: order, distance: distance))
    }

    func popIn(delay: Double = 0) -> some View {
        modifier(PopIn(delay: delay))
    }

    /// A short side-to-side shake each time `trigger` changes, e.g. on a wrong answer.
    func shake<T: Equatable>(trigger: T, enabled: Bool = true) -> some View {
        keyframeAnimator(initialValue: 0.0, trigger: trigger) { content, x in
            content.offset(x: enabled ? x : 0)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-8, duration: 0.06)
                CubicKeyframe(7, duration: 0.08)
                CubicKeyframe(-5, duration: 0.08)
                CubicKeyframe(3, duration: 0.07)
                CubicKeyframe(0, duration: 0.08)
            }
        }
    }

    /// Swells briefly and settles each time `trigger` changes, e.g. on a right answer.
    func pulse<T: Equatable>(trigger: T, scale: Double = 1.04, enabled: Bool = true) -> some View {
        keyframeAnimator(initialValue: 1.0, trigger: trigger) { content, value in
            content.scaleEffect(enabled ? value : 1)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(scale, duration: 0.14, spring: .snappy)
                SpringKeyframe(1, duration: 0.4, spring: .bouncy)
            }
        }
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
