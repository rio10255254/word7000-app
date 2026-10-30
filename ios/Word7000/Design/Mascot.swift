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
        let bounce: CGFloat = mood == .cheer ? CGFloat(abs(sin(t * 5.5))) * s * 0.06 : 0
        let tilt: Double = mood == .encourage ? -6 : mood == .thinking ? 5 : 0
        return ZStack {
            // The shadow on the ground shrinks while the body is up.
            Ellipse()
                .fill(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.14))
                .frame(width: s * 0.58 - bounce, height: s * 0.08)
                .blur(radius: s * 0.025)
                .offset(y: s * 0.44)
            ZStack {
                sprout(s, sway: sin(t * 1.6) * 8)
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
        let look = mood == .thinking ? CGSize(width: s * 0.03, height: -s * 0.03) : .zero
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
            .offset(y: s * 0.08)
            mouth(s)
                .offset(y: s * 0.11)
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
            .fill(Self.blush.opacity(mood == .sleepy ? 0.3 : 0.55))
            .frame(width: s * 0.11, height: s * 0.06)
            .blur(radius: s * 0.01)
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

    /// A blink every few seconds, now and then a double one.
    private static func blinking(_ t: Double) -> Bool {
        let cycle = t.truncatingRemainder(dividingBy: 4.6)
        if cycle < 0.13 { return true }
        return cycle > 0.3 && cycle < 0.42 && Int(t / 4.6) % 3 == 0
    }

    private static let top = Color(red: 0.63, green: 0.79, blue: 1.0)
    private static let bottom = Color(red: 0.31, green: 0.5, blue: 0.98)
    private static let shade = Color(red: 0.16, green: 0.25, blue: 0.7)
    private static let ink = Color(red: 0.09, green: 0.11, blue: 0.24)
    private static let blush = Color(red: 1.0, green: 0.55, blue: 0.62)
    private static let leafLight = Color(red: 0.56, green: 0.87, blue: 0.56)
    private static let leafDark = Color(red: 0.24, green: 0.66, blue: 0.42)
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

/// A short line from the mascot in a rounded bubble, pointing down at it.
struct MascotBubble: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.rounded(.footnote, weight: .semibold))
            .foregroundStyle(Color(red: 0.09, green: 0.11, blue: 0.24))
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .bottom) {
                MascotBubbleTail()
                    .fill(.white)
                    .frame(width: 14, height: 8)
                    .offset(y: 7)
            }
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            .fixedSize(horizontal: false, vertical: true)
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
                .font(.rounded(.title2, weight: .bold))
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
