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
        // Segmented pickers on the warm paper rather than system grey.
        let segments = UISegmentedControl.appearance()
        segments.selectedSegmentTintColor = ivory
        segments.backgroundColor = khakiFill
        segments.setTitleTextAttributes([.foregroundColor: inkSoft], for: .normal)
        segments.setTitleTextAttributes([.foregroundColor: ink], for: .selected)
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

extension Motion {
    /// One question giving way to the next: the new one comes in from the
    /// right as the old one leaves to the left, both fading.
    static let swap = Animation.spring(response: 0.42, dampingFraction: 0.9)
}

extension AnyTransition {
    static func questionSwap(_ reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .asymmetric(insertion: .offset(x: 36).combined(with: .opacity),
                                              removal: .offset(x: -36).combined(with: .opacity))
    }
}

/// WordCat Next: after a right answer the next question comes by itself,
/// so a run of right answers flows without a tap each time. A wrong answer
/// waits, so the explanation can be read. Off in UI tests: a slow test
/// machine could take longer than the wait between finding Next and tapping
/// it, and the question would move on under the test.
enum AutoAdvance {
    static var enabled: Bool { !AppRuntime.uiTesting }
    static var delay: Duration { .milliseconds(1300) }
    static var seconds: Double { 1.3 }
}

/// A key's face filling from the left while the next question is on its way.
struct CountdownFillOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appStyle) private var appStyle
    var active: Bool
    var seconds: Double = AutoAdvance.seconds
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(.white.opacity(0.24))
                .frame(width: proxy.size.width * progress)
        }
        // The shape of the action button it fills: a paper slip or a capsule.
        .clipShape(appStyle == .collage ? AnyShape(RoundedRectangle(cornerRadius: 7, style: .continuous)) : AnyShape(Capsule()))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: active, initial: true) { _, now in
            progress = 0
            guard now, !reduceMotion else { return }
            withAnimation(.linear(duration: seconds)) { progress = 1 }
        }
    }
}

/// A number that rolls up from zero when it appears.
struct CountUpText: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var value: Int
    var delay: Double = 0
    @State private var shown = 0

    var body: some View {
        Text("\(shown)")
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(shown)))
            .task(id: value) {
                guard !reduceMotion, value > 0 else { shown = value; return }
                try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
                withAnimation(.snappy(duration: 0.7)) { shown = value }
            }
            .accessibilityLabel("\(value)")
    }
}

/// Pressed on like a rubber stamp: big and tilted, then down hard with a
/// small bounce and a thud.
struct StampSlam: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppModel.self) private var model
    var delay: Double = 0
    @State private var down = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(down || reduceMotion ? 1 : 2.2)
            .rotationEffect(.degrees(down || reduceMotion ? 0 : -18))
            .opacity(down || reduceMotion ? 1 : 0)
            .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: down) { _, now in
                now && (model.settings.hapticsEnabled ?? true)
            }
            .soundEffect(trigger: down) { (_: Bool, now: Bool) -> SoundEffect? in now ? .stamp : nil }
            .task {
                guard !reduceMotion else { down = true; return }
                try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
                withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) { down = true }
            }
    }
}

/// A spinner that only appears when loading takes a moment, so a quick swap
/// between questions does not flash it.
struct DelayedProgress: View {
    @State private var shown = false

    var body: some View {
        ZStack { if shown { ProgressView().transition(.opacity) } }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                try? await Task.sleep(for: .milliseconds(450))
                withAnimation { shown = true }
            }
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
            // WordCat Next: a soft tick under the finger as it goes down.
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Feel.tap(.soft, intensity: 0.55) }
            }
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

    @ViewBuilder
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

    @ViewBuilder
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
            // WordCat Next: switches in clay with a paw, not the iPhone's green.
            .toggleStyle(WarmToggleStyle())
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

    /// The main call to action: a full-width capsule, Liquid Glass on iOS 26;
    /// in the collage, a slip of coloured paper with an ink edge.
    func prominentAction(tint: Color = Palette.accent) -> some View {
        modifier(ActionButton(prominent: true, tint: tint))
    }

    /// A secondary action next to a prominent one.
    func secondaryAction(tint: Color = Palette.accent) -> some View {
        modifier(ActionButton(prominent: false, tint: tint))
    }
}

/// The two kinds of action button in each look.
private struct ActionButton: ViewModifier {
    @Environment(\.appStyle) private var appStyle
    @Environment(\.isEnabled) private var isEnabled
    var prominent: Bool
    var tint: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        // WordCat Next: every action key answers with a tap you can feel,
        // firmer for the main one.
        let labelled = content.modifier(OneLineLabel())
            .simultaneousGesture(TapGesture().onEnded {
                if isEnabled { Feel.tap(prominent ? .medium : .light, intensity: prominent ? 0.8 : 0.6) }
            })
        if appStyle == .collage {
            labelled.buttonStyle(CollageButtonStyle(prominent: prominent, tint: tint)).tint(tint)
        } else if #available(iOS 26.0, *) {
            if prominent {
                labelled.buttonStyle(.glassProminent).buttonBorderShape(.capsule).controlSize(.large).tint(tint)
            } else {
                labelled.buttonStyle(.glass).buttonBorderShape(.capsule).controlSize(.large).tint(tint)
            }
        } else if prominent {
            labelled.buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.large).tint(tint)
        } else {
            labelled.buttonStyle(.bordered).buttonBorderShape(.capsule).controlSize(.large).tint(tint)
        }
    }
}

/// A button cut from paper: the main one coloured, the other ivory, both
/// with an ink edge and a hard shadow underneath, as if laid on the desk.
/// Pressing it pushes it down onto its shadow.
struct CollageButtonStyle: ButtonStyle {
    var prominent: Bool
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        CollageButtonBody(configuration: configuration, prominent: prominent, tint: tint)
    }
}

private struct CollageButtonBody: View {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let configuration: ButtonStyleConfiguration
    var prominent: Bool
    var tint: Color

    var body: some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        configuration.label
            .font(.headline)
            // Ivory by day; dark at night, where the tints are lighter and
            // white on green or ochre was hard to read (2.2–2.5:1).
            .foregroundStyle(prominent ? Palette.surface : tint)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(minHeight: 50)
            .background {
                shape
                    .fill(prominent ? AnyShapeStyle(tint) : AnyShapeStyle(PaperKind.ivory.color))
                    .overlay { PaperGrain(opacity: prominent ? 0.9 : 0.6).blendMode(prominent ? .overlay : .multiply).clipShape(shape) }
                    .overlay { shape.strokeBorder(Collage.ink.opacity(0.85), lineWidth: 1.5) }
            }
            .background {
                shape
                    .fill(Collage.ink.opacity(0.8))
                    .offset(x: pressed ? 0 : 3, y: pressed ? 0 : 3)
            }
            .offset(x: pressed ? 3 : 0, y: pressed ? 3 : 0)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(reduceMotion ? nil : .snappy(duration: 0.15), value: pressed)
            .contentShape(shape)
    }
}

/// A capsule button's label stays on one line, a little smaller if it must,
/// so a word is never split across lines ("subscriptio / n") or cut short
/// ("Unlock Premi…"): rows that cannot hold it whole stack instead. At the
/// accessibility text sizes it may wrap instead: there the rows stack.
private struct OneLineLabel: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            content
        } else {
            content.lineLimit(1).minimumScaleFactor(0.8)
        }
    }
}

/// Buttons side by side, or one above the other when their labels would
/// not fit whole (a long translation, a small phone, a larger text size).
/// Side by side they share the row equally when the widest fits its share,
/// else each gets its own label's width plus an even share of what is left
/// ("Sign in" beside "Unlock Premium"). Always stacked at the accessibility
/// sizes.
struct ButtonRow<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        ButtonRowLayout(spacing: spacing, stacked: dynamicTypeSize.isAccessibilitySize) { content }
    }
}

private struct ButtonRowLayout: Layout {
    var spacing: CGFloat
    var stacked: Bool

    /// Room kept beyond each label's measured width. A label measured to
    /// fit exactly can still be cut by a point once drawn, so a near miss
    /// counts as a miss.
    private static let slack: CGFloat = 10

    private func ideals(_ subviews: Subviews) -> [CGFloat] {
        subviews.map { $0.sizeThatFits(.unspecified).width + Self.slack }
    }

    /// The width of each button side by side, or nil to stack them.
    private func widths(_ width: CGFloat?, _ subviews: Subviews) -> [CGFloat]? {
        guard !stacked else { return nil }
        let ideal = ideals(subviews)
        let count = CGFloat(subviews.count)
        guard subviews.count > 1 else { return [width.flatMap { $0.isFinite ? $0 : nil } ?? (ideal.first ?? 0)] }
        let gaps = spacing * (count - 1)
        guard let width, width.isFinite else { return ideal }
        let share = (width - gaps) / count
        if (ideal.max() ?? 0) <= share { return Array(repeating: share, count: subviews.count) }
        let total = ideal.reduce(0, +)
        guard total + gaps <= width else { return nil }
        let extra = (width - gaps - total) / count
        return ideal.map { $0 + extra }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        if let widths = widths(proposal.width, subviews) {
            let width = widths.reduce(0, +) + spacing * CGFloat(max(0, subviews.count - 1))
            let height = zip(subviews, widths).map { $0.sizeThatFits(ProposedViewSize(width: $1, height: nil)).height }.max() ?? 0
            return CGSize(width: width, height: height)
        }
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? (ideals(subviews).max() ?? 0)
        let heights = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
        return CGSize(width: width, height: heights.reduce(0, +) + spacing * CGFloat(max(0, subviews.count - 1)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        if let widths = widths(bounds.width, subviews) {
            var x = bounds.minX
            for (subview, width) in zip(subviews, widths) {
                subview.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading,
                              proposal: ProposedViewSize(width: width, height: bounds.height))
                x += width + spacing
            }
        } else {
            var y = bounds.minY
            for subview in subviews {
                let height = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
                subview.place(at: CGPoint(x: bounds.minX, y: y), anchor: .topLeading,
                              proposal: ProposedViewSize(width: bounds.width, height: height))
                y += height + spacing
            }
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
    /// Screenshot tests of the cat's chat, memory and study tip, which need
    /// the online AI: sample content stands in for it.
    static let catShowcase = ProcessInfo.processInfo.arguments.contains("-uiTestingCatShowcase")
    /// WordCat Next: today's words end with spot checks. Off under UI tests
    /// written for the flip cards alone, unless a test asks for it.
    static let wordRoutine = !uiTesting || ProcessInfo.processInfo.arguments.contains("-uiTestingRoutine")
    /// WordCat Next: a speaking stage opens with listening to the whole
    /// conversation and ends with using one of today's words. UI tests of
    /// the stage itself start straight on its first turn.
    static let speakingRoutine = !uiTesting || ProcessInfo.processInfo.arguments.contains("-uiTestingSpeakingRoutine")
    /// WordCat Next: the first launch asks about the exam and which pillar
    /// comes first, and checks the level with a short adaptive test. UI tests
    /// of the older welcome keep its three scenes.
    static let labOnboarding = !uiTesting || ProcessInfo.processInfo.arguments.contains("-uiTestingLabOnboarding")
    /// WordCat Next: a stamp when today's words and speaking are both done.
    static let dayComplete = !uiTesting || ProcessInfo.processInfo.arguments.contains("-uiTestingDayComplete")
    /// The App Store art: `-uiTestingMascotPoster happy:white` shows only
    /// the cat in that mood on white (or black), still, for cutting out.
    static let mascotPoster: (mood: Mascot.Mood, white: Bool)? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-uiTestingMascotPoster"), index + 1 < arguments.count else { return nil }
        let parts = arguments[index + 1].split(separator: ":").map(String.init)
        let moods: [String: Mascot.Mood] = ["happy": .happy, "cheer": .cheer, "smug": .smug, "cheeky": .cheeky,
                                            "encourage": .encourage, "idle": .idle, "thinking": .thinking]
        guard let first = parts.first, let mood = moods[first] else { return nil }
        return (mood, parts.count > 1 && parts[1] == "white")
    }()
}

/// The cat alone, large and holding still, on plain black or white: the
/// store art cuts it out by comparing the two (see
/// scripts/generate-app-store-screenshots.mjs).
struct MascotPosterView: View {
    let mood: Mascot.Mood
    let white: Bool

    var body: some View {
        ZStack {
            (white ? Color.white : Color.black).ignoresSafeArea()
            Mascot(mood: mood, size: 320)
        }
        // The cat itself is hidden from VoiceOver; the page stands for it.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("WordCat")
        .accessibilityIdentifier("mascot-poster")
        .environment(\.accessibilityReduceMotion, true)
        .environment(\.colorScheme, .light)
        .statusBarHidden(true)
    }
}

/// A sheet exactly as tall as what it holds: a note or a few rows does
/// not open on half a screen of empty paper.
private struct FittedSheet: ViewModifier {
    @State private var height: CGFloat = 300

    func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { height = proxy.size.height }
                        .onChange(of: proxy.size.height) { _, value in height = value }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .presentationDetents([.height(height)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(Palette.background)
    }
}

extension View {
    func fittedSheet() -> some View { modifier(FittedSheet()) }

    /// A short sheet for a few settings or a note: opens at half height with a
    /// grabber, and can be pulled up to full height when there is more to see.
    func compactSheet() -> some View {
        presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
    }
}
