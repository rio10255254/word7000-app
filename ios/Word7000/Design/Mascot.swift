import SwiftUI
import Word7000Core

/// The app's little companion: a round lump of a ginger cat, a little fluffy
/// at the cheeks, with a resting face of deep, heavy-lidded disinterest. It
/// has opinions about your practice and shares them, and it can be smacked. It
/// breathes, blinks and flicks its ears and tail while it waits, and its face
/// follows the moment: smug when you haven't practised,
/// happy after a right answer, cheering when the goal is met, encouraging after
/// a miss, sleepy late at night. Drawn in code, so it is sharp at any size.
/// Decorative only: hidden from VoiceOver, and still under Reduce Motion.
struct Mascot: View {
    enum Mood: Equatable {
        case idle, happy, cheer, encourage, sleepy, thinking
        /// Seeing stars, e.g. after being flung into the end of the card.
        case dizzy
        /// Lids lowered, smirking: it has noticed you haven't practised.
        case smug
        /// Squeezed-shut >< eyes and a wobbly mouth: it has just been smacked.
        case annoyed
    }

    var mood: Mood = .idle
    var size: CGFloat = 96
    /// Bump to make it hop, e.g. when it is tapped.
    var hop = 0
    /// Where it looks, from -1 to 1 on each axis: toward a finger dragging it.
    var gaze: CGSize = .zero
    /// Rosy cheeks, e.g. while it is being held.
    var blush = false
    /// Waddling along: the body bobs and sways, the paws take turns, the tail swishes.
    var walking = false
    /// How fast the feet go while walking: 1 a waddle, about 2 a run (with dust).
    var pace: Double = 1
    /// A little trick it is doing (a spin, a flip, a dance, a stretch), and
    /// when it began, in `timeIntervalSinceReferenceDate` seconds.
    var antic: MascotAntic? = nil
    var anticStart: Double = 0

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
        let step = walking ? t * 9 * pace : 0
        let pose = anticPose(t)
        let bounce: CGFloat = mood == .cheer ? CGFloat(abs(sin(t * 5.5))) * s * 0.06
            : walking ? CGFloat(abs(sin(step))) * s * (pace > 1.4 ? 0.08 : 0.05) : 0
        let tilt = tiltAngle(time: t, step: step)
        let lift = bounce + pose.lift * s
        return ZStack {
            // The shadow on the ground shrinks while the body is up.
            Ellipse()
                .fill(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.14))
                .frame(width: max(s * 0.2, s * 0.58 - lift * 0.8), height: s * 0.08)
                .blur(radius: s * 0.025)
                .offset(y: s * 0.44)
            if walking && pace > 1.4 { dust(s, time: t) }
            ZStack {
                // The tail curls up behind, swishing: lazily at rest, briskly
                // on the move, wagging when it is pleased.
                tail(s, sway: tailSway(time: t))
                ears(s, time: t)
                furBody(s)
                // Two little front paws peeking out under the chest; they step in turn while it walks.
                HStack(spacing: s * 0.16) {
                    paw(s, lift: walking ? CGFloat(max(0, sin(step))) * s * 0.06 : 0)
                    paw(s, lift: walking ? CGFloat(max(0, -sin(step))) * s * 0.06 : 0)
                }
                .offset(y: s * 0.42)
                face(s, time: t, yawning: pose.yawning)
            }
            .scaleEffect(x: 1 - breathe * 0.6 - pose.stretch * 0.45, y: 1 + breathe + pose.stretch, anchor: .bottom)
            .rotationEffect(.degrees(tilt + pose.sway), anchor: .bottom)
            .rotation3DEffect(.degrees(pose.spin), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
            .rotationEffect(.degrees(pose.roll))
            .offset(y: -lift)
            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: mood)
            if mood == .cheer { sparkles(s, time: t) }
            if mood == .sleepy { snores(s, time: t) }
            if mood == .dizzy { stars(s, time: t) }
        }
    }

    /// How far it leans: side to side while walking (more when running) or
    /// woozy, and a little one way or the other for some moods.
    private func tiltAngle(time t: Double, step: Double) -> Double {
        if walking { return sin(step) * (pace > 1.4 ? 9 : 6) }
        switch mood {
        case .encourage: return -6
        case .thinking: return 5
        case .dizzy: return sin(t * 3.2) * 8
        default: return 0
        }
    }

    /// Where the current trick has the body: up in the air, turning, rolling,
    /// swaying or stretched tall. Nothing outside a trick, or with Reduce Motion.
    private func anticPose(_ t: Double) -> AnticPose {
        guard let antic, !reduceMotion else { return AnticPose() }
        let p = (t - anticStart) / antic.duration
        guard p > 0, p < 1 else { return AnticPose() }
        var pose = AnticPose()
        switch antic {
        case .spin:
            // Once round on the spot, with a little hop.
            let eased = p < 0.5 ? 2 * p * p : 1 - pow(-2 * p + 2, 2) / 2
            pose.spin = eased * 360
            pose.lift = CGFloat(sin(p * .pi)) * 0.12
        case .flip:
            // Crouch, leap, a somersault in the air, and a soft landing.
            let air = max(0, min(1, (p - 0.18) / 0.64))
            pose.lift = CGFloat(sin(air * .pi)) * 0.5
            pose.roll = -air * 360
            if p < 0.18 { pose.stretch = -CGFloat(sin(p / 0.18 * .pi)) * 0.14 }
            if p > 0.82 { pose.stretch = -CGFloat(sin((p - 0.82) / 0.18 * .pi)) * 0.12 }
        case .dance:
            // A little side-to-side jig, bouncing on each beat.
            pose.sway = sin(p * .pi * 6) * 13
            pose.lift = CGFloat(abs(sin(p * .pi * 6))) * 0.07
        case .stretch:
            // Up on tiptoe, eyes shut, a big yawn.
            pose.stretch = CGFloat(sin(p * .pi)) * 0.16
            pose.yawning = p > 0.12 && p < 0.88
        }
        return pose
    }

    /// Puffs of dust kicked up behind it while it runs.
    private func dust(_ s: CGFloat, time t: Double) -> some View {
        let behind: CGFloat = gaze.width < 0 ? 1 : -1
        return ZStack {
            ForEach(0..<3, id: \.self) { index in
                let age = CGFloat((t * 2.4 + Double(index) / 3).truncatingRemainder(dividingBy: 1))
                Circle()
                    .fill(Self.dustTint.opacity(0.55 * Double(1 - age)))
                    .frame(width: s * (0.06 + 0.1 * age), height: s * (0.06 + 0.1 * age))
                    .offset(x: behind * s * (0.24 + 0.26 * age), y: s * (0.42 - 0.1 * age))
            }
        }
    }

    /// Little stars circling its head while it is dizzy.
    private func stars(_ s: CGFloat, time t: Double) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let angle = t * 3.4 + Double(index) * 2.094
                Image(systemName: "star.fill")
                    .font(.system(size: s * 0.1, weight: .bold))
                    .foregroundStyle(Self.gold)
                    .scaleEffect(0.75 + 0.25 * CGFloat(sin(angle)))
                    .offset(x: CGFloat(cos(angle)) * s * 0.3, y: -s * 0.48 + CGFloat(sin(angle)) * s * 0.07)
            }
        }
        .transition(.opacity)
    }

    /// A little cream paw.
    private func paw(_ s: CGFloat, lift: CGFloat) -> some View {
        Ellipse()
            .fill(Self.cream)
            .frame(width: s * 0.14, height: s * 0.07)
            .offset(y: -lift)
    }

    /// The body (and head: it is all one lump): round on top and settled
    /// flat underneath, with a barely ruffled edge, a tuft of fur at each
    /// cheek and on top, and a small cream chest with a tuft of its own.
    /// Deliberately vague, so the face does the talking.
    private func furBody(_ s: CGFloat) -> some View {
        MascotFluff(tufts: 20, puff: 0.015, roundness: 0.9, settle: 0.92)
            .fill(LinearGradient(colors: [Self.top, Self.bottom], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .bottom) {
                // The cream chest, with a little tuft on top.
                VStack(spacing: -s * 0.012) {
                    MascotZigzag(points: 2)
                        .fill(Self.cream)
                        .frame(width: s * 0.09, height: s * 0.04)
                    Ellipse()
                        .fill(Self.cream)
                        .frame(width: s * 0.34, height: s * 0.2)
                }
                .offset(y: -s * 0.05)
            }
            .overlay(alignment: .top) {
                // A tuft of fur sticking up on top.
                MascotTuft()
                    .fill(Self.top)
                    .frame(width: s * 0.08, height: s * 0.09)
                    .offset(y: -s * 0.06)
            }
            .overlay {
                // A tuft at each cheek, sticking out past the outline.
                HStack(spacing: s * 0.8) {
                    MascotCheekTuft().fill(Self.top).frame(width: s * 0.065, height: s * 0.105).scaleEffect(x: -1)
                    MascotCheekTuft().fill(Self.top).frame(width: s * 0.065, height: s * 0.105)
                }
                .offset(y: s * 0.06)
            }
            .frame(width: s * 0.9, height: s * 0.74)
            .offset(y: s * 0.07)
            .shadow(color: Self.bottom.opacity(0.3), radius: s * 0.07, y: s * 0.04)
    }

    /// Two small rounded ears, pink inside. They prick up when it is pleased,
    /// droop when it is sleepy, sad or dizzy, flatten back when it is smug or
    /// has just been smacked, and each flicks now and then.
    private func ears(_ s: CGFloat, time t: Double) -> some View {
        let droop: Double = switch mood {
        case .happy, .cheer: -4
        case .sleepy, .encourage: 12
        case .smug: 8
        case .annoyed: 14
        case .dizzy: 20
        default: 0
        }
        let twitchLeft = reduceMotion ? 0 : Self.twitch(t, every: 6.1, offset: 0)
        let twitchRight = reduceMotion ? 0 : Self.twitch(t, every: 7.3, offset: 2.4)
        return ZStack {
            ear(s).rotationEffect(.degrees(-18 - droop - twitchLeft), anchor: .bottom).offset(x: -s * 0.23)
            ear(s).rotationEffect(.degrees(18 + droop + twitchRight), anchor: .bottom).offset(x: s * 0.23)
        }
        .offset(y: -s * 0.33)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: mood)
    }

    private func ear(_ s: CGFloat) -> some View {
        MascotEar()
            .fill(LinearGradient(colors: [Self.top, Self.bottom], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .bottom) {
                MascotEar()
                    .fill(Self.innerEar)
                    .frame(width: s * 0.11, height: s * 0.12)
                    .offset(y: -s * 0.035)
            }
            .frame(width: s * 0.22, height: s * 0.2)
    }

    /// A short, plain tail curling up behind the right side.
    private func tail(_ s: CGFloat, sway: Double) -> some View {
        MascotTail()
            .stroke(LinearGradient(colors: [Self.top, Self.bottom], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: s * 0.12, lineCap: .round, lineJoin: .round))
            .frame(width: s, height: s)
            .rotationEffect(.degrees(sway), anchor: UnitPoint(x: MascotTail.base.x, y: MascotTail.base.y))
    }

    private func tailSway(time t: Double) -> Double {
        if walking { return sin(t * 7 * pace) * 16 }
        switch mood {
        case .cheer, .happy: return sin(t * 6) * 14
        case .sleepy: return sin(t * 0.8) * 3
        // Unimpressed: just the tail, flicking.
        case .smug, .idle: return sin(t * 2.6) * 6
        default: return sin(t * 1.7) * 9
        }
    }

    /// A quick flick of an ear, once every `every` seconds.
    private static func twitch(_ t: Double, every: Double, offset: Double) -> Double {
        let cycle = (t + offset).truncatingRemainder(dividingBy: every)
        guard cycle < 0.32 else { return 0 }
        return sin(cycle / 0.32 * .pi) * 16
    }

    private func face(_ s: CGFloat, time t: Double, yawning: Bool) -> some View {
        let opensEyes = !yawning && ([.idle, .smug, .encourage, .thinking] as [Mood]).contains(mood)
        let blink = !reduceMotion && opensEyes && Self.blinking(t)
        let thinking = mood == .thinking ? CGSize(width: s * 0.03, height: -s * 0.03) : .zero
        // While nobody is touching it, it glances to one side and back every few seconds.
        let glance = gaze == .zero && !reduceMotion && opensEyes ? Self.glance(t) : 0
        let look = CGSize(width: thinking.width + (gaze.width + glance) * s * 0.035, height: thinking.height + gaze.height * s * 0.03)
        return ZStack {
            HStack(spacing: s * 0.17) {
                eye(s, side: -1, blink: blink, yawning: yawning, time: t)
                eye(s, side: 1, blink: blink, yawning: yawning, time: t)
            }
            .offset(x: look.width, y: look.height)
            HStack(spacing: s * 0.36) {
                cheek(s)
                cheek(s)
            }
            .offset(x: look.width * 0.5, y: s * 0.08)
            whiskers(s, time: t)
                .offset(x: look.width * 0.5, y: s * 0.1)
            MascotNose()
                .fill(Self.nose)
                .overlay { MascotNose().stroke(Self.nose, style: StrokeStyle(lineWidth: s * 0.012, lineJoin: .round)) }
                .frame(width: s * 0.045, height: s * 0.028)
                .offset(x: look.width * 0.6, y: s * 0.075)
            mouth(s, yawning: yawning)
                .offset(x: look.width * 0.6, y: s * 0.125)
        }
    }

    /// Two short whiskers a side, twitching a touch as it breathes.
    private func whiskers(_ s: CGFloat, time t: Double) -> some View {
        let quiver = reduceMotion ? 0 : sin(t * 2.1) * 2
        return HStack(spacing: s * 0.42) {
            whiskerSet(s, side: -1, quiver: quiver)
            whiskerSet(s, side: 1, quiver: quiver)
        }
    }

    private func whiskerSet(_ s: CGFloat, side: Double, quiver: Double) -> some View {
        VStack(spacing: s * 0.025) {
            ForEach([-8.0, 8], id: \.self) { angle in
                Capsule()
                    .fill(Self.ink.opacity(0.35))
                    .frame(width: s * 0.12, height: max(0.6, s * 0.01))
                    .rotationEffect(.degrees(side * (angle - quiver)))
            }
        }
    }

    @ViewBuilder
    private func eye(_ s: CGFloat, side: Double, blink: Bool, yawning: Bool, time t: Double) -> some View {
        if yawning {
            MascotArc(bulgesUp: false)
                .stroke(Self.ink, style: StrokeStyle(lineWidth: s * 0.03, lineCap: .round))
                .frame(width: s * 0.12, height: s * 0.035)
        } else {
            moodEye(s, side: side, blink: blink, time: t)
        }
    }

    @ViewBuilder
    private func moodEye(_ s: CGFloat, side: Double, blink: Bool, time t: Double) -> some View {
        switch mood {
        case .idle:
            // Its resting face: heavy-lidded and thoroughly unimpressed.
            lidEye(s, lid: 0.4, tilt: 0, blink: blink)
        case .smug:
            // Lids lower and slanting in: a knowing, judging look.
            lidEye(s, lid: 0.58, tilt: side * -8, blink: blink)
        case .annoyed:
            // Squeezed shut: > <.
            MascotChevron()
                .stroke(Self.ink, style: StrokeStyle(lineWidth: s * 0.026, lineCap: .round, lineJoin: .round))
                .frame(width: s * 0.085, height: s * 0.09)
                .scaleEffect(x: side < 0 ? 1 : -1)
        case .dizzy:
            // Swirly eyes, turning.
            Circle()
                .trim(from: 0, to: 0.78)
                .stroke(Self.ink, style: StrokeStyle(lineWidth: s * 0.026, lineCap: .round))
                .frame(width: s * 0.1, height: s * 0.1)
                .rotationEffect(.degrees(reduceMotion ? 0 : t * 420))
        case .happy, .cheer:
            MascotArc(bulgesUp: true)
                .stroke(Self.ink, style: StrokeStyle(lineWidth: s * 0.035, lineCap: .round))
                .frame(width: s * 0.12, height: s * 0.05)
        case .sleepy:
            MascotArc(bulgesUp: false)
                .stroke(Self.ink, style: StrokeStyle(lineWidth: s * 0.03, lineCap: .round))
                .frame(width: s * 0.12, height: s * 0.035)
        case .encourage, .thinking:
            // Wide open for once.
            Capsule()
                .fill(Self.ink)
                .frame(width: s * 0.1, height: s * 0.135)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: s * 0.036, height: s * 0.036)
                        .offset(x: -s * 0.014, y: s * 0.022)
                }
                .scaleEffect(y: blink ? 0.12 : 1)
        }
    }

    /// A round eye with a flat lid across its top: `lid` is how much of it the
    /// lid covers, `tilt` how the lid slants.
    private func lidEye(_ s: CGFloat, lid: CGFloat, tilt: Double, blink: Bool) -> some View {
        let d = s * 0.11
        return Circle()
            .fill(Self.ink)
            .overlay(alignment: .topTrailing) {
                // A glint just under the lid.
                Circle()
                    .fill(Color.white)
                    .frame(width: d * 0.26, height: d * 0.26)
                    .offset(x: -d * 0.16, y: d * lid + d * 0.06)
            }
            .frame(width: d, height: d)
            .mask(alignment: .bottom) {
                Rectangle().frame(height: d * (1 - lid))
            }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Self.ink)
                    .frame(width: d * 1.3, height: s * 0.024)
                    .offset(y: d * lid - s * 0.012)
                    .rotationEffect(.degrees(tilt))
            }
            .scaleEffect(y: blink ? 0.15 : 1)
    }

    private func cheek(_ s: CGFloat) -> some View {
        let shown = blush ? 0.9 : (mood == .happy || mood == .cheer) ? 0.5 : 0
        return Ellipse()
            .fill(Self.blush.opacity(shown))
            .frame(width: s * 0.1, height: s * 0.05)
            .scaleEffect(blush ? 1.3 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: blush)
    }

    @ViewBuilder
    private func mouth(_ s: CGFloat, yawning: Bool) -> some View {
        if yawning {
            Ellipse()
                .fill(Self.ink)
                .frame(width: s * 0.08, height: s * 0.09)
        } else {
            moodMouth(s)
        }
    }

    @ViewBuilder
    private func moodMouth(_ s: CGFloat) -> some View {
        switch mood {
        case .happy, .cheer:
            MascotOpenMouth()
                .fill(Self.ink)
                .frame(width: s * 0.12, height: s * 0.06)
        case .annoyed:
            MascotZigzag(points: 2)
                .stroke(Self.ink, style: StrokeStyle(lineWidth: s * 0.02, lineCap: .round, lineJoin: .round))
                .frame(width: s * 0.09, height: s * 0.026)
        case .smug:
            MascotSmirk()
                .stroke(Self.ink, style: StrokeStyle(lineWidth: s * 0.022, lineCap: .round))
                .frame(width: s * 0.1, height: s * 0.04)
        case .sleepy:
            Circle()
                .stroke(Self.ink, lineWidth: s * 0.02)
                .frame(width: s * 0.035, height: s * 0.035)
        case .thinking:
            Capsule()
                .fill(Self.ink)
                .frame(width: s * 0.06, height: s * 0.02)
                .rotationEffect(.degrees(-8))
        case .dizzy:
            MascotArc(bulgesUp: true)
                .stroke(Self.ink, style: StrokeStyle(lineWidth: s * 0.022, lineCap: .round))
                .frame(width: s * 0.08, height: s * 0.025)
                .rotationEffect(.degrees(-10))
        case .idle, .encourage:
            MascotCatMouth()
                .stroke(Self.ink, style: StrokeStyle(lineWidth: s * 0.02, lineCap: .round, lineJoin: .round))
                .frame(width: s * 0.09, height: s * 0.026)
        }
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
                    .foregroundStyle(Self.shade.opacity(1 - rise))
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

    // A ginger kitten in the app's warm apricot and terracotta, with a cream
    // chest, paws and tail tip; the eyes a deep brown.
    private static let top = Color(red: 0.98, green: 0.77, blue: 0.56)
    private static let bottom = Color(red: 0.89, green: 0.54, blue: 0.34)
    private static let shade = Color(red: 0.58, green: 0.29, blue: 0.16)
    private static let cream = Color(red: 1.0, green: 0.95, blue: 0.86)
    private static let innerEar = Color(red: 0.98, green: 0.7, blue: 0.66)
    private static let nose = Color(red: 0.93, green: 0.52, blue: 0.52)
    private static let ink = Color(red: 0.17, green: 0.1, blue: 0.07)
    private static let blush = Color(red: 0.95, green: 0.5, blue: 0.45)
    private static let gold = Color(red: 1.0, green: 0.86, blue: 0.4)
    private static let amber = Color(red: 1.0, green: 0.6, blue: 0.3)
    private static let dustTint = Color(red: 0.8, green: 0.68, blue: 0.55)
    private static let sparkleSpots = [CGSize(width: -0.48, height: -0.3), CGSize(width: 0.46, height: -0.4), CGSize(width: 0.44, height: 0.08)]
}

/// The little tricks the companion does now and then, or when played with.
enum MascotAntic: CaseIterable, Equatable {
    case spin, flip, dance, stretch

    var duration: Double {
        switch self {
        case .spin: 0.8
        case .flip: 1.0
        case .dance: 1.6
        case .stretch: 1.6
        }
    }
}

/// How a trick has the body at one moment.
private struct AnticPose {
    var lift: CGFloat = 0
    var spin: Double = 0
    var roll: Double = 0
    var sway: Double = 0
    var stretch: CGFloat = 0
    var yawning = false
}

/// A trick asked of the companion from outside; a new id plays it again.
struct MascotCue: Equatable {
    var antic: MascotAntic
    var id: Int
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

/// A cloud-edged outline of little tufts of fur around a rounded squircle.
private struct MascotFluff: Shape {
    var tufts = 26
    var puff: CGFloat = 0.06
    /// 1 an ellipse; lower is squarer.
    var roundness: Double = 0.8
    /// Below 1 flattens the bottom half, so it sits like a lump.
    var settle: CGFloat = 1

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width / 2
        let ry = rect.height / 2
        func point(_ angle: Double, _ scale: CGFloat) -> CGPoint {
            let c = cos(angle)
            let s = sin(angle)
            let x = CGFloat((c < 0 ? -1 : 1) * pow(abs(c), roundness))
            var y = CGFloat((s < 0 ? -1 : 1) * pow(abs(s), roundness))
            if y > 0 { y *= settle }
            return CGPoint(x: center.x + x * rx * scale, y: center.y + y * ry * scale)
        }
        let step = 2 * Double.pi / Double(tufts)
        var path = Path()
        path.move(to: point(0, 1 - puff))
        for index in 0..<tufts {
            let from = Double(index) * step
            path.addQuadCurve(to: point(from + step, 1 - puff), control: point(from + step / 2, 1 + puff))
        }
        path.closeSubpath()
        return path
    }
}

/// A few wisps of fur sticking up, like a cowlick.
private struct MascotTuft: Shape {
    func path(in rect: CGRect) -> Path {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        path.move(to: at(0, 1))
        path.addQuadCurve(to: at(0.5, 0), control: at(0.2, 0.1))
        path.addQuadCurve(to: at(0.7, 0.3), control: at(0.45, 0.5))
        path.addQuadCurve(to: at(1, 1), control: at(0.8, 0.7))
        path.closeSubpath()
        return path
    }
}

/// An ear with a softly rounded tip.
private struct MascotEar: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.minY + rect.height * 0.14))
        path.addQuadCurve(to: CGPoint(x: rect.minX + rect.width * 0.64, y: rect.minY + rect.height * 0.14),
                          control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.04))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// The tail's curve, in fractions of the figure's square: from behind the body
/// low on the right, curling up.
private struct MascotTail: Shape {
    static let base = CGPoint(x: 0.74, y: 0.86)

    func path(in rect: CGRect) -> Path {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        path.move(to: at(Self.base.x, Self.base.y))
        path.addQuadCurve(to: at(0.98, 0.52), control: at(1.04, 0.84))
        return path
    }
}

/// A tuft of fur sticking out sideways (to the right; mirror it for the left).
private struct MascotCheekTuft: Shape {
    func path(in rect: CGRect) -> Path {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        path.move(to: at(0, 0))
        path.addLine(to: at(1, 0.28))
        path.addLine(to: at(0.3, 0.52))
        path.addLine(to: at(0.95, 0.78))
        path.addLine(to: at(0, 1))
        path.closeSubpath()
        return path
    }
}

/// A row of little peaks along the top: a tuft (filled) or a wobbly mouth (stroked).
private struct MascotZigzag: Shape {
    var points = 2

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = points * 2
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for index in 1...steps {
            let x = rect.minX + rect.width * CGFloat(index) / CGFloat(steps)
            path.addLine(to: CGPoint(x: x, y: index % 2 == 1 ? rect.minY : rect.maxY))
        }
        return path
    }
}

/// A > shape: one squeezed-shut eye (mirror it for the other).
private struct MascotChevron: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

/// A small, rounded triangle of a nose.
private struct MascotNose: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A cat's ω mouth.
private struct MascotCatMouth: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                          control: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY + rect.height))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                          control: CGPoint(x: rect.minX + rect.width * 0.75, y: rect.maxY + rect.height))
        return path
    }
}

/// A one-sided smirk, rising to the right.
private struct MascotSmirk: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.3))
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

/// The companion you can play with, or smack. Tap it and it takes the hit:
/// knocked sideways away from your finger with a little burst, eyes squeezed
/// shut, and a comeback; keep at it and it gets crosser, until a sixth quick
/// smack leaves it seeing stars (and, on Today, storming off). It keeps count
/// of the day's smacks. Drag it and it leans and stretches after your finger,
/// eyes following, then springs back; press and hold and it blushes as
/// little hearts float up, grudgingly.
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
    /// How fast it walks (see `Mascot.pace`).
    var pace: Double = 1
    /// A trick asked of it from outside, e.g. while it wanders.
    var cue: MascotCue? = nil
    /// Does a little trick of its own every so often while it waits.
    var fidgets = false
    /// Told how far a quick flick would throw it sideways, e.g. to send it sliding.
    var onFling: ((CGFloat) -> Void)? = nil
    /// When given, what it says goes here for the page to show in its own
    /// layout, instead of a bubble floating over whatever is next to it.
    var speech: Binding<String?>? = nil
    /// Told when a run of smacks has been too much, e.g. to storm off.
    var onBeatenUp: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppModel.self) private var model
    @State private var bubble: String?
    @State private var bubbleTask: Task<Void, Never>?
    @State private var drag: CGSize = .zero
    @State private var held = false
    @State private var hearts = 0
    @State private var greeted = false
    @State private var antic: MascotAntic?
    @State private var anticStart: Double = 0
    /// Smacks: how many so far, the current run of quick ones, which way the
    /// last one knocked it (-1 left, 1 right; 0 upright), and how it feels.
    @State private var slaps = 0
    @State private var combo = 0
    @State private var lastSlap = Date.distantPast
    @State private var knock: CGFloat = 0
    @State private var burstSide: CGFloat = 0
    @State private var smarting = false
    @State private var seeingStars = false
    @State private var smartTask: Task<Void, Never>?

    var body: some View {
        let pull = CGSize(width: max(-1, min(1, drag.width / 80)), height: max(-1, min(1, drag.height / 80)))
        // Eyes on the finger while dragged, else where it is heading.
        let look = drag == .zero ? CGSize(width: facing * 0.8, height: 0) : pull
        let actionable = tip != nil && bubble == tip?.text
        Mascot(mood: held ? .happy : seeingStars ? .dizzy : smarting ? .annoyed : mood,
               size: size, hop: hop, gaze: look, blush: held, walking: walking && drag == .zero,
               pace: pace, antic: antic, anticStart: anticStart)
            // Knocked sideways by a smack, squashed a little, then wobbling back upright.
            .scaleEffect(x: 1 + abs(knock) * 0.1, y: 1 - abs(knock) * 0.1, anchor: .bottom)
            .rotationEffect(.degrees(Double(knock) * 18), anchor: .bottom)
            .offset(x: knock * size * 0.16)
            // Leans after the finger and stretches toward it, like soft clay.
            .scaleEffect(x: 1 + abs(pull.width) * 0.12 - abs(pull.height) * 0.05,
                         y: 1 + abs(pull.height) * 0.1 - abs(pull.width) * 0.06, anchor: .bottom)
            .rotationEffect(.degrees(Double(pull.width) * 12), anchor: .bottom)
            .offset(x: pull.width * size * 0.12, y: min(0, pull.height) * size * 0.1)
            .overlay {
                if hearts > 0 { MascotHearts(size: size).id(hearts) }
            }
            .overlay {
                if slaps > 0, !reduceMotion {
                    MascotSmack(size: size)
                        .offset(x: burstSide * size * 0.42, y: -size * 0.12)
                        .id(slaps)
                }
            }
            .overlay(alignment: bubbleAnchor) {
                if let bubble, speech == nil {
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
            .onTapGesture(coordinateSpace: .local) { location in
                // Hit on its left, it flies right, and the other way round.
                smack(from: location.x < size / 2 ? -1 : 1)
            }
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
                    .onEnded { value in
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.45)) { drag = .zero }
                        // A quick sideways flick: the throw goes further than the finger did.
                        let flick = value.predictedEndTranslation.width - value.translation.width
                        if abs(flick) > 60, !reduceMotion { onFling?(value.predictedEndTranslation.width) }
                    }
            )
            .onChange(of: cue) { _, new in
                if let new { play(new.antic) }
            }
            .onChange(of: bubble) { _, new in
                speech?.wrappedValue = new
            }
            .task(id: fidgets) {
                guard fidgets, !reduceMotion, !AppRuntime.uiTesting else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(Double.random(in: 10...20)))
                    guard !Task.isCancelled else { return }
                    if drag == .zero, !held { play(MascotAntic.allCases.randomElement() ?? .spin) }
                }
            }
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.4), trigger: anticStart) { _, _ in haptics && antic == .flip }
            .sensoryFeedback(.impact(weight: .heavy, intensity: 0.9), trigger: slaps) { _, _ in haptics }
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
            .accessibilityHint(L.t("點一下扁它", "Tap to smack it"))
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

    /// VoiceOver's way to play with it.
    private func poke() {
        smack(from: -1)
    }

    /// Takes a smack from one side (-1 its left, 1 its right): it is knocked
    /// the other way, winces and answers back. The first answer is its tip,
    /// if it has one, or one of its lines; quick smacks after that make it
    /// crosser, and a sixth in a row leaves it seeing stars.
    private func smack(from side: CGFloat) {
        onInteract?()
        let now = Date()
        combo = now.timeIntervalSince(lastSlap) < 2.5 ? combo + 1 : 1
        lastSlap = now
        slaps += 1
        burstSide = side
        let today = MascotGrudge.record()
        if !reduceMotion {
            withAnimation(.spring(response: 0.12, dampingFraction: 0.9)) { knock = -side }
        }
        smartTask?.cancel()
        smarting = true
        let beaten = combo >= 6
        if beaten {
            combo = 0
            seeingStars = true
            onBeatenUp?()
        }
        smartTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.35)) { knock = 0 }
            try? await Task.sleep(for: .seconds(beaten ? 1.8 : 1.1))
            guard !Task.isCancelled else { return }
            smarting = false
            seeingStars = false
        }

        if beaten {
            say(L.t("夠了喔！我走！", "That's it. I'm leaving."), for: 2.4)
        } else if MascotGrudge.milestones.contains(today) {
            say(L.t("今天第 \(today) 下了。我都記在小本本上。", "That's \(today) today. I'm keeping a list."), for: 2.6)
        } else if let tip, slaps == 1 || slaps % 5 == 0 {
            say(tip.text, for: 6)
        } else if combo == 1, !lines.isEmpty {
            var next = lines.randomElement() ?? lines[0]
            if next == bubble, let other = lines.first(where: { $0 != bubble }) { next = other }
            say(next, for: 2.4)
        } else {
            say(Self.comeback(combo: combo, avoiding: bubble), for: 2.2)
        }
    }

    /// What it says back to a run of smacks: indignant, then cross.
    private static func comeback(combo: Int, avoiding last: String?) -> String {
        let indignant = [
            L.t("你打我？", "Did you just hit me?"),
            L.t("很痛欸。你背單字有這麼認真就好了。", "Ow. Wish you hit the books this hard."),
            L.t("打我不會加分喔。", "Hitting me isn't worth any points."),
            L.t("有種去背單字啊。", "Hit the books, not me."),
            L.t("蛤？你是來亂的嗎？", "Excuse me? Are you here to study or to fight?"),
        ]
        let cross = [
            L.t("再打我就把你的連續天數吃掉。", "One more and I eat your streak."),
            L.t("好喔，記住了。永遠。", "Noted. Remembered. Forever."),
            L.t("你是不是對我有什麼意見？", "Got a problem with me?"),
            L.t("我要報警了。單字警察。", "I'm calling the vocab police."),
            L.t("你打得這麼爽，單字背了幾個？", "Having fun? How many words have you learned today?"),
        ]
        let pool = combo >= 4 ? cross : indignant
        return pool.filter { $0 != last }.randomElement() ?? pool[0]
    }

    private func play(_ trick: MascotAntic) {
        guard !reduceMotion else { return }
        antic = trick
        anticStart = Date().timeIntervalSinceReferenceDate
    }

    private func love() {
        hearts += 1
        say(L.t("……好啦，可以再摸一下。不要跟別人說。", "…Fine. Keep going. Tell no one."), for: 2)
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

/// The burst of a smack: a yellow star that pops and fades.
private struct MascotSmack: View {
    var size: CGFloat
    @State private var shown = false

    var body: some View {
        MascotStar()
            .fill(Color(red: 1.0, green: 0.85, blue: 0.35))
            .overlay { MascotStar().stroke(Color(red: 0.95, green: 0.55, blue: 0.25), lineWidth: max(1, size * 0.015)) }
            .frame(width: size * 0.32, height: size * 0.32)
            .scaleEffect(shown ? 1.1 : 0.3)
            .opacity(shown ? 0 : 1)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4)) { shown = true }
            }
    }
}

/// A spiky eight-pointed star.
private struct MascotStar: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        var path = Path()
        for index in 0..<16 {
            let angle = Double(index) * .pi / 8
            let radius = index % 2 == 0 ? outer : outer * 0.48
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// The companion keeps count of how often it has been smacked today.
enum MascotGrudge {
    private static let dayKey = "word7000.mascot.smackDay"
    private static let countKey = "word7000.mascot.smacks"
    /// Counts it remarks on.
    static let milestones: Set<Int> = [10, 25, 50, 100, 200]

    /// Smacks so far today.
    static var today: Int {
        UserDefaults.standard.string(forKey: dayKey) == DayMath.today() ? UserDefaults.standard.integer(forKey: countKey) : 0
    }

    /// Counts one more smack and returns today's total.
    @discardableResult
    static func record() -> Int {
        let count = today + 1
        UserDefaults.standard.set(DayMath.today(), forKey: dayKey)
        UserDefaults.standard.set(count, forKey: countKey)
        return count
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
