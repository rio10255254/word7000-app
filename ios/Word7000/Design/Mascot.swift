import SwiftUI

/// The app's little companion: a soft, round blob with big eyes and a sprout on
/// top. It breathes and blinks while it waits, and its face follows the moment:
/// happy after a right answer, cheering when the goal is met, encouraging after
/// a miss, sleepy late at night. Drawn in code, so it is sharp at any size.
/// Decorative only: hidden from VoiceOver, and still under Reduce Motion.
struct Mascot: View {
    enum Mood: Equatable {
        case idle, happy, cheer, encourage, sleepy, thinking
    }

    var mood: Mood = .idle
    var size: CGFloat = 96
    /// Bump to make it hop, e.g. when it is tapped.
    var hop = 0
    /// Where it looks, from -1 to 1 on each axis: toward a finger dragging it.
    var gaze: CGSize = .zero
    /// Rosy cheeks, e.g. while it is being held.
    var blush = false
    /// Waddling along: the body bobs and sways, and the little feet take turns.
    var walking = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    /// Hops of its own, when it turns happy or starts cheering.
    @State private var moodHops = 0

    var body: some View {
        let s = size
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            figure(time: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate)
        }
        .frame(width: s, height: s)
        .keyframeAnimator(initialValue: MascotHop(), trigger: reduceMotion ? 0 : hop + moodHops) { content, frame in
            content
                .scaleEffect(x: frame.width, y: frame.height, anchor: .bottom)
                .offset(y: frame.lift * s)
        } keyframes: { _ in
            KeyframeTrack(\.height) {
                CubicKeyframe(0.86, duration: 0.09)
                CubicKeyframe(1.08, duration: 0.16)
                CubicKeyframe(0.9, duration: 0.14)
                SpringKeyframe(1, duration: 0.35, spring: .bouncy)
            }
            KeyframeTrack(\.width) {
                CubicKeyframe(1.1, duration: 0.09)
                CubicKeyframe(0.94, duration: 0.16)
                CubicKeyframe(1.08, duration: 0.14)
                SpringKeyframe(1, duration: 0.35, spring: .bouncy)
            }
            KeyframeTrack(\.lift) {
                CubicKeyframe(0, duration: 0.09)
                CubicKeyframe(-0.22, duration: 0.16)
                CubicKeyframe(0, duration: 0.14)
                CubicKeyframe(0, duration: 0.35)
            }
        }
        .onChange(of: mood) { _, new in
            if new == .happy || new == .cheer { moodHops += 1 }
        }
        .accessibilityHidden(true)
    }

    // MARK: Figure

    private func figure(time t: Double) -> some View {
        let s = size
        let breathe = sin(t * 2.1) * 0.022
        let step = walking ? t * 9 : 0
        let bounce: CGFloat = mood == .cheer ? CGFloat(abs(sin(t * 5.5))) * s * 0.06
            : walking ? CGFloat(abs(sin(step))) * s * 0.05 : 0
        let tilt: Double = walking ? sin(step) * 6 : mood == .encourage ? -6 : mood == .thinking ? 5 : 0
        return ZStack {
            // The shadow on the ground shrinks while the body is up.
            Ellipse()
                .fill(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.14))
                .frame(width: s * 0.58 - bounce, height: s * 0.08)
                .blur(radius: s * 0.025)
                .offset(y: s * 0.44)
            ZStack {
                // Two little feet, tucked under the body; they step in turn while it walks.
                HStack(spacing: s * 0.2) {
                    foot(s, lift: walking ? CGFloat(max(0, sin(step))) * s * 0.06 : 0)
                    foot(s, lift: walking ? CGFloat(max(0, -sin(step))) * s * 0.06 : 0)
                }
                .offset(y: s * 0.42)
                sprout(s, sway: sin(t * (walking ? 4.5 : 1.6)) * (walking ? 14 : 8))
                    .frame(height: s * 0.16, alignment: .bottom)
                    .offset(y: -s * 0.42)
                shell(s)
                face(s, time: t)
            }
            .scaleEffect(x: 1 - breathe * 0.6, y: 1 + breathe, anchor: .bottom)
            .rotationEffect(.degrees(tilt), anchor: .bottom)
            .offset(y: -bounce)
            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: mood)
            if mood == .cheer { sparkles(s, time: t) }
            if mood == .sleepy { snores(s, time: t) }
        }
    }

    private func foot(_ s: CGFloat, lift: CGFloat) -> some View {
        Capsule()
            .fill(Self.shade.opacity(0.85))
            .frame(width: s * 0.15, height: s * 0.08)
            .offset(y: -lift)
    }

    private func shell(_ s: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: s * 0.36, style: .continuous)
        return shape
            .fill(LinearGradient(colors: [Self.top, Self.bottom], startPoint: .top, endPoint: .bottom))
            .overlay {
                // A little shade low on the body gives it weight.
                shape.fill(LinearGradient(colors: [.clear, Self.shade.opacity(0.35)], startPoint: .center, endPoint: .bottom))
            }
            .overlay(alignment: .topLeading) {
                // The glossy highlight.
                Ellipse()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: s * 0.28, height: s * 0.14)
                    .rotationEffect(.degrees(-24))
                    .blur(radius: s * 0.018)
                    .offset(x: s * 0.1, y: s * 0.08)
            }
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.75), .white.opacity(0)], startPoint: .top, endPoint: .center),
                                   lineWidth: max(1, s * 0.012))
            }
            .frame(width: s * 0.86, height: s * 0.78)
            .offset(y: s * 0.04)
            .shadow(color: Self.bottom.opacity(0.35), radius: s * 0.08, y: s * 0.05)
    }

    private func face(_ s: CGFloat, time t: Double) -> some View {
        let opensEyes = mood == .idle || mood == .encourage || mood == .thinking
        let blink = !reduceMotion && opensEyes && Self.blinking(t)
        let thinking = mood == .thinking ? CGSize(width: s * 0.03, height: -s * 0.03) : .zero
        // While nobody is touching it, it glances to one side and back every few seconds.
        let glance = gaze == .zero && !reduceMotion && opensEyes ? Self.glance(t) : 0
        let look = CGSize(width: thinking.width + (gaze.width + glance) * s * 0.035, height: thinking.height + gaze.height * s * 0.03)
        return ZStack {
            HStack(spacing: s * 0.17) {
                eye(s, blink: blink)
                eye(s, blink: blink)
            }
            .offset(x: look.width, y: -s * 0.02 + look.height)
            HStack(spacing: s * 0.36) {
                cheek(s)
                cheek(s)
            }
            .offset(x: look.width * 0.5, y: s * 0.08)
            mouth(s)
                .offset(x: look.width * 0.6, y: s * 0.11)
        }
    }

    @ViewBuilder
    private func eye(_ s: CGFloat, blink: Bool) -> some View {
        switch mood {
        case .happy, .cheer:
            MascotArc(bulgesUp: true)
                .stroke(Self.ink, style: StrokeStyle(lineWidth: s * 0.035, lineCap: .round))
                .frame(width: s * 0.11, height: s * 0.05)
        case .sleepy:
            MascotArc(bulgesUp: false)
                .stroke(Self.ink, style: StrokeStyle(lineWidth: s * 0.03, lineCap: .round))
                .frame(width: s * 0.11, height: s * 0.035)
        default:
            Capsule()
                .fill(Self.ink)
                .frame(width: s * 0.095, height: s * 0.13)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: s * 0.035, height: s * 0.035)
                        .offset(x: -s * 0.012, y: s * 0.02)
                }
                .scaleEffect(y: blink ? 0.12 : 1)
        }
    }

    private func cheek(_ s: CGFloat) -> some View {
        Ellipse()
            .fill(Self.blush.opacity(blush ? 0.95 : mood == .sleepy ? 0.3 : 0.55))
            .frame(width: s * 0.11, height: s * 0.06)
            .scaleEffect(blush ? 1.35 : 1)
            .blur(radius: s * 0.01)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: blush)
    }

    @ViewBuilder
    private func mouth(_ s: CGFloat) -> some View {
        switch mood {
        case .happy, .cheer:
            MascotOpenMouth()
                .fill(Self.ink)
                .overlay(alignment: .bottom) {
                    Ellipse()
                        .fill(Self.blush)
                        .frame(width: s * 0.07, height: s * 0.04)
                        .offset(y: s * 0.008)
                }
                .clipShape(MascotOpenMouth())
                .frame(width: s * 0.13, height: s * 0.07)
        case .sleepy:
            Circle()
                .stroke(Self.ink, lineWidth: s * 0.022)
                .frame(width: s * 0.04, height: s * 0.04)
        case .thinking:
            Capsule()
                .fill(Self.ink)
                .frame(width: s * 0.07, height: s * 0.022)
                .rotationEffect(.degrees(-8))
        case .idle, .encourage:
            MascotArc(bulgesUp: false)
                .stroke(Self.ink, style: StrokeStyle(lineWidth: s * 0.028, lineCap: .round))
                .frame(width: s * 0.1, height: s * 0.035)
        }
    }

    private func sprout(_ s: CGFloat, sway: Double) -> some View {
        ZStack(alignment: .bottom) {
            Capsule()
                .fill(Self.leafDark)
                .frame(width: s * 0.025, height: s * 0.1)
            Ellipse()
                .fill(LinearGradient(colors: [Self.leafLight, Self.leafDark], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: s * 0.16, height: s * 0.08)
                .rotationEffect(.degrees(-30))
                .offset(x: s * 0.06, y: -s * 0.08)
        }
        .rotationEffect(.degrees(sway), anchor: .bottom)
    }

    private func sparkles(_ s: CGFloat, time t: Double) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let wave = abs(sin(t * 2 + Double(index) * 2.1))
                let spot = Self.sparkleSpots[index]
                Image(systemName: "sparkle")
                    .font(.system(size: s * (index == 1 ? 0.16 : 0.12), weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [Self.gold, Self.amber], startPoint: .top, endPoint: .bottom))
                    .scaleEffect(0.6 + 0.4 * wave)
                    .opacity(0.5 + 0.5 * wave)
                    .offset(x: spot.width * s, y: spot.height * s)
            }
        }
        .transition(.scale.combined(with: .opacity))
    }

    private func snores(_ s: CGFloat, time t: Double) -> some View {
        ZStack {
            ForEach(0..<2, id: \.self) { index in
                let rise = (t * 0.5 + Double(index) * 0.5).truncatingRemainder(dividingBy: 1)
                Text("z")
                    .font(.system(size: s * (0.12 + 0.05 * CGFloat(index)), weight: .bold, design: .rounded))
                    .foregroundStyle(Self.bottom.opacity(1 - rise))
                    .offset(x: s * (0.32 + 0.1 * CGFloat(rise)), y: -s * (0.28 + 0.24 * CGFloat(rise)))
            }
        }
    }

    /// A look to the side, from -1 (left) to 1 (right): held about a second,
    /// eased in and out, once every 7 seconds, alternating sides.
    private static func glance(_ t: Double) -> CGFloat {
        let cycle = t.truncatingRemainder(dividingBy: 7)
        guard cycle > 4.6, cycle < 6.2 else { return 0 }
        let phase = (cycle - 4.6) / 1.6
        let ease = sin(phase * .pi)
        let side: Double = Int(t / 7) % 2 == 0 ? 1 : -1
        return CGFloat(min(1, ease * 1.6) * side)
    }

    /// A blink every few seconds, now and then a double one.
    private static func blinking(_ t: Double) -> Bool {
        let cycle = t.truncatingRemainder(dividingBy: 4.6)
        if cycle < 0.13 { return true }
        return cycle > 0.3 && cycle < 0.42 && Int(t / 4.6) % 3 == 0
    }

    // Apricot and terracotta, like warm clay; the eyes a deep brown.
    private static let top = Color(red: 0.97, green: 0.74, blue: 0.58)
    private static let bottom = Color(red: 0.85, green: 0.47, blue: 0.33)
    private static let shade = Color(red: 0.58, green: 0.27, blue: 0.16)
    private static let ink = Color(red: 0.23, green: 0.15, blue: 0.11)
    private static let blush = Color(red: 0.95, green: 0.5, blue: 0.45)
    private static let leafLight = Color(red: 0.66, green: 0.78, blue: 0.5)
    private static let leafDark = Color(red: 0.39, green: 0.55, blue: 0.32)
    private static let gold = Color(red: 1.0, green: 0.86, blue: 0.4)
    private static let amber = Color(red: 1.0, green: 0.6, blue: 0.3)
    private static let sparkleSpots = [CGSize(width: -0.48, height: -0.3), CGSize(width: 0.46, height: -0.4), CGSize(width: 0.44, height: 0.08)]
}

/// One squash-and-stretch hop.
private struct MascotHop {
    var width: CGFloat = 1
    var height: CGFloat = 1
    var lift: CGFloat = 0
}

/// A soft arc: bulging up for smiling eyes, down for a smile or closed eyes.
private struct MascotArc: Shape {
    var bulgesUp: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if bulgesUp {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY - rect.height))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY + rect.height))
        }
        return path
    }
}

/// A wide-open happy mouth: flat on top, round below.
private struct MascotOpenMouth: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY * 2 - rect.minY))
        path.closeSubpath()
        return path
    }
}

/// A short line from the mascot in a rounded bubble, pointing at it: down when
/// the bubble sits above, right when it sits to its left, left when to its right.
struct MascotBubble: View {
    var text: String
    var pointing: Edge = .bottom
    /// Tapping it opens more (the companion's AI note): a sparkle and a chevron say so.
    var actionable = false
    static let cream = Color(red: 1.0, green: 0.98, blue: 0.94)

    var body: some View {
        HStack(spacing: 5) {
            if actionable {
                Image(systemName: "sparkles")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Palette.accent)
                    .symbolEffect(.pulse, options: .repeat(2))
            }
            Text(text)
            if actionable {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Palette.accent)
            }
        }
            .font(.display(.footnote, weight: .semibold))
            .foregroundStyle(Color(red: 0.23, green: 0.15, blue: 0.11))
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Self.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: tailAlignment) {
                MascotBubbleTail()
                    .fill(Self.cream)
                    .frame(width: 14, height: 8)
                    .rotationEffect(.degrees(pointing == .trailing ? -90 : pointing == .leading ? 90 : 0))
                    .offset(x: pointing == .trailing ? 10 : pointing == .leading ? -10 : 0, y: pointing == .bottom ? 7 : 0)
            }
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var tailAlignment: Alignment {
        switch pointing {
        case .trailing: .trailing
        case .leading: .leading
        default: .bottom
        }
    }
}

/// The little point under a speech bubble.
private struct MascotBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Something the companion can tell you more about: a line for its bubble,
/// and what tapping that bubble opens.
struct MascotTip {
    var text: String
    var action: () -> Void
}

/// The companion you can play with. Tap it and it hops and says one of its
/// lines; drag it and it leans and stretches after your finger, eyes following,
/// then springs back; press and hold and it blushes as little hearts float up.
/// Its speech bubble takes no touches unless it carries the companion's tip,
/// and then only where it floats over nothing tappable.
struct MascotBuddy: View {
    var mood: Mascot.Mood = .idle
    var size: CGFloat = 64
    /// What it may say when tapped; silent when empty.
    var lines: [String] = []
    /// Said once when it first appears, if anything.
    var greeting: String? = nil
    /// Where the bubble shows: above it (.top), to its left (.leading) or right (.trailing).
    var bubbleSide: Edge = .top
    /// Hops from outside, e.g. a greeting or a right answer.
    var hop = 0
    /// Out for a stroll (see `StrollingCompanion`), and which way it faces: -1 left, 1 right.
    var walking = false
    var facing: CGFloat = 0
    /// Something it can tell you more about (its AI note). Said on the first
    /// tap and now and then after; tapping that bubble runs the action.
    var tip: MascotTip? = nil
    /// Told whenever someone taps, holds or drags it, e.g. to stop wandering for a while.
    var onInteract: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppModel.self) private var model
    @State private var pokes = 0
    @State private var bubble: String?
    @State private var bubbleTask: Task<Void, Never>?
    @State private var drag: CGSize = .zero
    @State private var held = false
    @State private var hearts = 0
    @State private var greeted = false

    var body: some View {
        let pull = CGSize(width: max(-1, min(1, drag.width / 80)), height: max(-1, min(1, drag.height / 80)))
        // Eyes on the finger while dragged, else where it is heading.
        let look = drag == .zero ? CGSize(width: facing * 0.8, height: 0) : pull
        let actionable = tip != nil && bubble == tip?.text
        Mascot(mood: held ? .happy : mood, size: size, hop: hop + pokes, gaze: look, blush: held, walking: walking && drag == .zero)
            // Leans after the finger and stretches toward it, like soft clay.
            .scaleEffect(x: 1 + abs(pull.width) * 0.12 - abs(pull.height) * 0.05,
                         y: 1 + abs(pull.height) * 0.1 - abs(pull.width) * 0.06, anchor: .bottom)
            .rotationEffect(.degrees(Double(pull.width) * 12), anchor: .bottom)
            .offset(x: pull.width * size * 0.12, y: min(0, pull.height) * size * 0.1)
            .overlay {
                if hearts > 0 { MascotHearts(size: size).id(hearts) }
            }
            .overlay(alignment: bubbleAnchor) {
                if let bubble {
                    MascotBubble(text: bubble, pointing: bubblePointing, actionable: actionable)
                        .frame(width: actionable ? 200 : 180, alignment: bubbleAnchor)
                        .offset(x: bubbleSide == .leading ? -size - 6 : bubbleSide == .trailing ? size + 6 : 0,
                                y: bubbleSide == .top ? -size * 0.62 : -size * 0.05)
                        .transition(.scale(scale: 0.6, anchor: bubbleSide == .top ? .bottom : bubbleSide == .leading ? .trailing : .leading)
                            .combined(with: .opacity))
                        .onTapGesture { if actionable { tip?.action() } }
                        .allowsHitTesting(actionable)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Circle().inset(by: -size * 0.04))
            .onTapGesture { poke() }
            .onLongPressGesture(minimumDuration: 0.4, maximumDistance: 12) {
                love()
            } onPressingChanged: { pressing in
                if pressing { onInteract?() }
                withAnimation(Motion.pop) { held = pressing && !reduceMotion }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        onInteract?()
                        guard !reduceMotion else { return }
                        withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.7)) { drag = value.translation }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.45)) { drag = .zero }
                    }
            )
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: pokes) { _, _ in haptics }
            .sensoryFeedback(.success, trigger: hearts) { _, new in new > 0 && haptics }
            .task(id: greeting) {
                // Once per appearance, except that a tip arriving later (today's
                // AI note, once worked out) is always said.
                guard let greeting, !greeted || greeting == tip?.text else { return }
                greeted = true
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled else { return }
                // A tip stays up longer, so there is time to tap it.
                say(greeting, for: greeting == tip?.text ? 6 : 3.2)
            }
            // For VoiceOver a button that says hello, so it can be played with too.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L.t("小字團", "Wordling"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { poke() }
            .accessibilityActions {
                if let tip { Button(tip.text) { tip.action() } }
            }
    }

    private var haptics: Bool { model.settings.hapticsEnabled ?? true }

    /// The side of the companion the bubble is pinned to, and so where it grows from.
    private var bubbleAnchor: Alignment {
        switch bubbleSide {
        case .leading: .trailing
        case .trailing: .leading
        default: .top
        }
    }

    private var bubblePointing: Edge {
        switch bubbleSide {
        case .leading: .trailing
        case .trailing: .leading
        default: .bottom
        }
    }

    private func poke() {
        onInteract?()
        pokes += 1
        // The tip first, then every third tap.
        if let tip, pokes == 1 || pokes % 3 == 0 {
            say(tip.text, for: 6)
            return
        }
        guard !lines.isEmpty else { return }
        var next = lines.randomElement() ?? lines[0]
        if next == bubble, let other = lines.first(where: { $0 != bubble }) { next = other }
        say(next, for: 2.4)
    }

    private func love() {
        hearts += 1
        say(L.t("嘿嘿，好癢～", "Hehe, that tickles!"), for: 1.8)
    }

    private func say(_ text: String, for seconds: Double) {
        withAnimation(reduceMotion ? nil : Motion.pop) { bubble = text }
        bubbleTask?.cancel()
        bubbleTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : Motion.reveal) { bubble = nil }
        }
    }
}

/// A few small hearts floating up from the companion and fading.
private struct MascotHearts: View {
    var size: CGFloat
    @State private var risen = false

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                let spread = CGFloat(index) - 1.5
                Image(systemName: "heart.fill")
                    .font(.system(size: size * (index % 2 == 0 ? 0.16 : 0.12)))
                    .foregroundStyle(Color(red: 0.93, green: 0.45, blue: 0.42))
                    .offset(x: spread * size * (risen ? 0.22 : 0.08), y: risen ? -size * (0.75 + 0.1 * CGFloat(index % 2)) : -size * 0.1)
                    .opacity(risen ? 0 : 1)
                    .scaleEffect(risen ? 1.1 : 0.4)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 1.1)) { risen = true }
        }
    }
}

extension Mascot.Mood {
    /// How the companion feels about a result, from 0 (none right) to 1 (all right).
    init(score: Double) {
        self = score >= 0.999 ? .cheer : score >= 0.6 ? .happy : .encourage
    }
}

/// The companion with a short title and line, for empty and finished states.
struct MascotMessage: View {
    var mood: Mascot.Mood
    var title: String
    var text: String

    var body: some View {
        VStack(spacing: 14) {
            Mascot(mood: mood, size: 110)
                .popIn()
            Text(title)
                .font(.display(.title2, weight: .bold))
                .entrance(1)
            Text(text)
                .foregroundStyle(.secondary)
                .entrance(2)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

/// The label of an empty state, with the companion in place of a symbol.
struct MascotLabel: View {
    var mood: Mascot.Mood
    var title: String
    var size: CGFloat = 72

    var body: some View {
        VStack(spacing: 10) {
            Mascot(mood: mood, size: size)
                .popIn()
            Text(title)
        }
    }
}
