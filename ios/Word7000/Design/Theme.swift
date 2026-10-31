import SwiftUI
import UIKit

/// Warm paper and leather, in the spirit of a well-made notebook. Terracotta is
/// the one accent; sage means known, ochre review and streaks, brick a miss.
/// Every colour has a light and a dark tone, so both modes stay warm.
enum Palette {
    static let accent = Color(uiColor: WarmTone.clay)
    static let known = Color(uiColor: WarmTone.sage)
    static let review = Color(uiColor: WarmTone.ochre)
    static let miss = Color(uiColor: WarmTone.brick)
    static let chinese = Color(uiColor: WarmTone.slate)
    static let background = Color(uiColor: WarmTone.paper)
    static let surface = Color(uiColor: WarmTone.ivory)
    static let fill = Color(uiColor: WarmTone.khakiFill)
    static let khaki = Color(uiColor: WarmTone.khaki)
    static let ink = Color(uiColor: WarmTone.ink)
    static let secondaryLabel = Color(uiColor: WarmTone.inkSoft)
    static let tertiaryLabel = Color(uiColor: WarmTone.inkFaint)
    static let separator = Color(uiColor: WarmTone.khaki)
}

/// The palette's tones as UIKit colours, for places SwiftUI does not reach
/// (navigation bar titles) and as the source of `Palette`.
enum WarmTone {
    static let clay = tone(0xC96442, 0xD97757)
    static let paper = tone(0xF3EEE4, 0x22201C)
    static let ivory = tone(0xFBF8F2, 0x2E2B26)
    static let khaki = tone(0xE2D8C6, 0x443F37)
    static let khakiFill = tone(0xE9E1D2, 0x3A362F)
    static let ink = tone(0x2B2620, 0xEDE6DA)
    static let inkSoft = tone(0x7A6F62, 0xA89F91)
    static let inkFaint = tone(0xB0A595, 0x6E665B)
    static let sage = tone(0x6E8F5E, 0x8FAE7E)
    static let ochre = tone(0xC98A2E, 0xDDA552)
    static let brick = tone(0xB4483A, 0xD46A5A)
    static let slate = tone(0x5B6B8C, 0x93A3C6)

    private static func tone(_ light: UInt32, _ dark: UInt32) -> UIColor {
        UIColor { traits in rgb(traits.userInterfaceStyle == .dark ? dark : light) }
    }

    private static func rgb(_ value: UInt32) -> UIColor {
        UIColor(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }

    /// Serif navigation titles in warm ink, matching the display face, and
    /// terracotta for the bars' buttons and the selected tab.
    static func styleSystemBars() {
        let navigation = UINavigationBar.appearance()
        navigation.largeTitleTextAttributes = [.font: serif(.largeTitle), .foregroundColor: ink]
        navigation.titleTextAttributes = [.font: serif(.headline), .foregroundColor: ink]
        navigation.tintColor = clay
        UITabBar.appearance().tintColor = clay
    }

    private static func serif(_ style: UIFont.TextStyle) -> UIFont {
        let base = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style)
        let bold = base.withSymbolicTraits(.traitBold) ?? base
        return UIFont(descriptor: bold.withDesign(.serif) ?? bold, size: 0)
    }
}

/// The serif display face (New York) for headings, numbers and the word on a
/// card; the regular system face stays for reading.
extension Font {
    static func display(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .serif, weight: weight)
    }

    static func displaySize(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
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

/// A raised sheet of good paper: ivory with a faint grain, a khaki hairline
/// that catches the light along the top, and a soft warm shadow.
struct PremiumSurface: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appStyle) private var appStyle
    var radius: CGFloat
    var fill: Color = Palette.surface

    @ViewBuilder
    var body: some View {
        if appStyle == .collage {
            // Collage: a plain cut of paper with a hairline edge; no light, no shadow.
            Rectangle()
                .fill(fill)
                .overlay { PaperGrain(opacity: 0.5) }
                .overlay { Rectangle().strokeBorder(Collage.ink.opacity(0.16), lineWidth: 1) }
        } else {
            leather
        }
    }

    private var leather: some View {
        let dark = colorScheme == .dark
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape
            .fill(fill)
            .overlay { PaperGrain(opacity: 0.35).clipShape(shape) }
            .overlay { shape.strokeBorder(Palette.khaki, lineWidth: 1) }
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(dark ? 0.08 : 0.85), .white.opacity(0)], startPoint: .top, endPoint: .center),
                                   lineWidth: 1)
                    .padding(1)
            }
            .shadow(color: Self.umber.opacity(dark ? 0.35 : 0.06), radius: 1, y: 1)
            .shadow(color: Self.umber.opacity(dark ? 0.3 : 0.09), radius: 12, y: 6)
    }

    /// The warm brown the shadows are cast in.
    static let umber = Color(red: 0.35, green: 0.24, blue: 0.12)
}

/// A faint paper texture, tiled. Decoration only.
struct PaperGrain: View {
    var opacity: Double = 1

    var body: some View {
        Image("PaperGrain")
            .resizable(resizingMode: .tile)
            .opacity(opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The page behind a screen: warm paper with its grain, and two soft glows of
/// colour. They stay still: an animation that never ends would keep the
/// screen busy (and the battery working) for no real gain.
struct AmbientBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appStyle) private var appStyle
    var tint: Color = Palette.accent
    var secondTint: Color = Palette.review

    @ViewBuilder
    var body: some View {
        if appStyle == .collage {
            // Collage: the bare desk paper, no glows.
            Palette.background
                .overlay { PaperGrain(opacity: 0.8) }
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            glowing
        }
    }

    private var glowing: some View {
        let dark = colorScheme == .dark
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack {
                Circle()
                    .fill(tint.opacity(dark ? 0.16 : 0.1))
                    .frame(width: width * 1.1, height: width * 1.1)
                    .blur(radius: 70)
                    .offset(x: -width * 0.38, y: -width * 0.55)
                Circle()
                    .fill(secondTint.opacity(dark ? 0.12 : 0.1))
                    .frame(width: width, height: width)
                    .blur(radius: 70)
                    .offset(x: width * 0.45, y: -width * 0.15)
            }
            .frame(width: width, height: proxy.size.height, alignment: .top)
        }
        .background(Palette.background)
        .overlay { PaperGrain(opacity: 0.55) }
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
    /// A list or form on warm paper, its rows on ivory.
    func warmList(tint: Color = Palette.accent) -> some View {
        scrollContentBackground(.hidden)
            .background { AmbientBackground(tint: tint) }
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

/// How the app was launched.
enum AppRuntime {
    /// Under UI tests: ambient wandering stays put, so elements hold still to be measured and tapped.
    static let uiTesting = ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-uiTesting") }
}

extension View {
    /// A short sheet for a few settings or a note: opens at half height with a
    /// grabber, and can be pulled up to full height when there is more to see.
    func compactSheet() -> some View {
        presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
    }
}
