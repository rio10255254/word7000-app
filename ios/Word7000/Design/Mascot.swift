import SwiftUI

/// The app's little companion: a round, fluffy ginger kitten with twitching
/// ears, whiskers and a swishing tail, and a resting face of deep, heavy-lidded
/// disinterest. It has opinions about your practice and shares them. It
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
                HStack(spacing: s * 0.14) {
                    paw(s, lift: walking ? CGFloat(max(0, sin(step))) * s * 0.06 : 0)
                    paw(s, lift: walking ? CGFloat(max(0, -sin(step))) * s * 0.06 : 0)
                }
                .offset(y: s * 0.4)
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

    /// A soft cream paw.
    private func paw(_ s: CGFloat, lift: CGFloat) -> some View {
        Ellipse()
            .fill(Self.cream)
            .overlay { Ellipse().strokeBorder(Self.shade.opacity(0.35), lineWidth: max(0.5, s * 0.01)) }
            .frame(width: s * 0.17, height: s * 0.09)
            .offset(y: -lift)
    }

    /// The round, fluffy body (and head: a kitten is mostly head): a cloud-edged
    /// outline of fur tufts, a fluffy cream chest, tabby stripes on the brow, a
    /// little tuft sticking up on top and a soft sheen on the fur.
    private func furBody(_ s: CGFloat) -> some View {
        let fluff = MascotFluff(tufts: 26, puff: 0.06)
        return fluff
            .fill(LinearGradient(colors: [Self.top, Self.bottom], startPoint: .top, endPoint: .bottom))
            .overlay {
                // A little shade low on the body gives it weight.
                fluff.fill(LinearGradient(colors: [.clear, Self.shade.opacity(0.28)], startPoint: .center, endPoint: .bottom))
            }
            .overlay(alignment: .bottom) {
                // The fluffy cream chest.
                MascotFluff(tufts: 16, puff: 0.07)
                    .fill(Self.cream)
                    .frame(width: s * 0.42, height: s * 0.26)
                    .offset(y: -s * 0.04)
            }
            .overlay(alignment: .top) {
                // Tabby stripes on the brow.
                HStack(alignment: .top, spacing: s * 0.035) {
                    stripe(s, length: 0.08).rotationEffect(.degrees(-12))
                    stripe(s, length: 0.11)
                    stripe(s, length: 0.08).rotationEffect(.degrees(12))
                }
                .offset(y: s * 0.05)
            }
            .overlay(alignment: .top) {
                // A tuft of fur sticking up on top.
                MascotTuft()
                    .fill(Self.top)
                    .frame(width: s * 0.1, height: s * 0.1)
                    .offset(y: -s * 0.05)
            }
            .overlay(alignment: .topLeading) {
                // A soft sheen on the fur.
                Ellipse()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: s * 0.24, height: s * 0.1)
                    .rotationEffect(.degrees(-24))
                    .blur(radius: s * 0.03)
                    .offset(x: s * 0.1, y: s * 0.12)
            }
            .frame(width: s * 0.86, height: s * 0.78)
            .offset(y: s * 0.04)
            .shadow(color: Self.bottom.opacity(0.35), radius: s * 0.08, y: s * 0.05)
    }

    private func stripe(_ s: CGFloat, length: CGFloat) -> some View {
        Capsule()
            .fill(Self.stripeTint.opacity(0.5))
            .frame(width: s * 0.03, height: s * length)
    }

    /// Two pointed ears, pink inside with a few wisps of fur. They prick up
    /// when it is pleased, droop when it is sleepy, sad or dizzy, flatten back
    /// when it is being smug, and each flicks now and then.
    private func ears(_ s: CGFloat, time t: Double) -> some View {
        let droop: Double = switch mood {
        case .happy, .cheer: -4
        case .sleepy, .encourage: 12
        case .smug: 8
        case .dizzy: 20
        default: 0
        }
        let twitchLeft = reduceMotion ? 0 : Self.twitch(t, every: 6.1, offset: 0)
        let twitchRight = reduceMotion ? 0 : Self.twitch(t, every: 7.3, offset: 2.4)
        return ZStack {
            ear(s).rotationEffect(.degrees(-20 - droop - twitchLeft), anchor: .bottom).offset(x: -s * 0.24)
            ear(s).rotationEffect(.degrees(20 + droop + twitchRight), anchor: .bottom).offset(x: s * 0.24)
        }
        .offset(y: -s * 0.31)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: mood)
    }

    private func ear(_ s: CGFloat) -> some View {
        MascotEar()
            .fill(LinearGradient(colors: [Self.top, Self.bottom], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .bottom) {
                MascotEar()
                    .fill(Self.innerEar)
                    .overlay(alignment: .bottom) {
                        // Wisps of fur inside the ear.
                        HStack(alignment: .bottom, spacing: s * 0.008) {
                            ForEach([-1.0, 0, 1], id: \.self) { lean in
                                Capsule()
                                    .fill(Self.cream)
                                    .frame(width: s * 0.012, height: s * 0.06)
                                    .rotationEffect(.degrees(lean * 12), anchor: .bottom)
                            }
                        }
                    }
                    .frame(width: s * 0.13, height: s * 0.15)
                    .offset(y: -s * 0.04)
            }
            .frame(width: s * 0.25, height: s * 0.25)
            .offset(y: -s * 0.085)
    }

    /// A fluffy tail curling up behind the right side, with a tufted cream tip.
    private func tail(_ s: CGFloat, sway: Double) -> some View {
        ZStack(alignment: .topLeading) {
            MascotTail()
                .stroke(LinearGradient(colors: [Self.top, Self.bottom], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: s * 0.13, lineCap: .round, lineJoin: .round))
            MascotFluff(tufts: 9, puff: 0.12)
                .fill(Self.cream)
                .frame(width: s * 0.15, height: s * 0.15)
                .offset(x: s * (MascotTail.tip.x - 0.075), y: s * (MascotTail.tip.y - 0.075))
        }
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
            HStack(spacing: s * 0.16) {
                eye(s, side: -1, blink: blink, yawning: yawning, time: t)
                eye(s, side: 1, blink: blink, yawning: yawning, time: t)
            }
            .offset(x: look.width, y: -s * 0.02 + look.height)
            HStack(spacing: s * 0.36) {
                cheek(s)
                cheek(s)
            }
            .offset(x: look.width * 0.5, y: s * 0.08)
            whiskers(s, time: t)
                .offset(x: look.width * 0.5, y: s * 0.09)
            MascotNose()
                .fill(Self.nose)
                .overlay { MascotNose().stroke(Self.nose, style: StrokeStyle(lineWidth: s * 0.014, lineJoin: .round)) }
                .frame(width: s * 0.055, height: s * 0.035)
                .offset(x: look.width * 0.6, y: s * 0.07)
            // The little line from the nose down to the mouth.
            Capsule()
                .fill(Self.ink)
                .frame(width: s * 0.02, height: s * 0.03)
                .offset(x: look.width * 0.6, y: s * 0.095)
            mouth(s, yawning: yawning)
                .offset(x: look.width * 0.6, y: s * 0.12)
        }
    }

    /// Three whiskers a side, twitching a touch as it breathes.
    private func whiskers(_ s: CGFloat, time t: Double) -> some View {
        let quiver = reduceMotion ? 0 : sin(t * 2.1) * 2
        return HStack(spacing: s * 0.35) {
            whiskerSet(s, side: -1, quiver: quiver)
            whiskerSet(s, side: 1, quiver: quiver)
        }
    }

    private func whiskerSet(_ s: CGFloat, side: Double, quiver: Double) -> some View {
        VStack(spacing: s * 0.022) {
            ForEach([-11.0, 0, 11], id: \.self) { angle in
                Capsule()
                    .fill(Self.ink.opacity(0.4))
                    .frame(width: s * 0.16, height: max(0.6, s * 0.011))
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
            lidEye(s, lid: 0.35, tilt: 0, blink: blink)
        case .smug:
            // Lids lower and slanting in: a knowing, judging look.
            lidEye(s, lid: 0.55, tilt: side * -7, blink: blink)
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
        let d = s * 0.12
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
                .frame(width: s * 0.1, height: s * 0.03)
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
    private static let stripeTint = Color(red: 0.76, green: 0.4, blue: 0.22)
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

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width / 2
        let ry = rect.height / 2
        func point(_ angle: Double, _ scale: CGFloat) -> CGPoint {
            let c = cos(angle)
            let s = sin(angle)
            let x = CGFloat((c < 0 ? -1 : 1) * pow(abs(c), 0.8))
            let y = CGFloat((s < 0 ? -1 : 1) * pow(abs(s), 0.8))
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

/// A pointed ear with a softly rounded tip.
private struct MascotEar: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.minY + rect.height * 0.1))
        path.addQuadCurve(to: CGPoint(x: rect.minX + rect.width * 0.62, y: rect.minY + rect.height * 0.1),
                          control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.06))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// The tail's curve, in fractions of the figure's square: from behind the body
/// low on the right, out and up, curling back in at the tip.
private struct MascotTail: Shape {
    static let base = CGPoint(x: 0.74, y: 0.84)
    static let tip = CGPoint(x: 0.95, y: 0.3)

    func path(in rect: CGRect) -> Path {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        path.move(to: at(Self.base.x, Self.base.y))
        path.addQuadCurve(to: at(1.06, 0.48), control: at(1.1, 0.8))
        path.addQuadCurve(to: at(Self.tip.x, Self.tip.y), control: at(1.04, 0.3))
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppModel.self) private var model
    @State private var pokes = 0
    @State private var bubble: String?
    @State private var bubbleTask: Task<Void, Never>?
    @State private var drag: CGSize = .zero
    @State private var held = false
    @State private var hearts = 0
    @State private var greeted = false
    @State private var antic: MascotAntic?
    @State private var anticStart: Double = 0

    var body: some View {
        let pull = CGSize(width: max(-1, min(1, drag.width / 80)), height: max(-1, min(1, drag.height / 80)))
        // Eyes on the finger while dragged, else where it is heading.
        let look = drag == .zero ? CGSize(width: facing * 0.8, height: 0) : pull
        let actionable = tip != nil && bubble == tip?.text
        Mascot(mood: held ? .happy : mood, size: size, hop: hop + pokes, gaze: look, blush: held, walking: walking && drag == .zero,
               pace: pace, antic: antic, anticStart: anticStart)
            // Leans after the finger and stretches toward it, like soft clay.
            .scaleEffect(x: 1 + abs(pull.width) * 0.12 - abs(pull.height) * 0.05,
                         y: 1 + abs(pull.height) * 0.1 - abs(pull.width) * 0.06, anchor: .bottom)
            .rotationEffect(.degrees(Double(pull.width) * 12), anchor: .bottom)
            .offset(x: pull.width * size * 0.12, y: min(0, pull.height) * size * 0.1)
            .overlay {
                if hearts > 0 { MascotHearts(size: size).id(hearts) }
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
        // Every fourth tap it shows off a trick.
        if pokes % 4 == 0, !reduceMotion, let trick = MascotAntic.allCases.randomElement() {
            play(trick)
            say(Self.trickLine(trick), for: 2)
            return
        }
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

    private func play(_ trick: MascotAntic) {
        guard !reduceMotion else { return }
        antic = trick
        anticStart = Date().timeIntervalSinceReferenceDate
    }

    private static func trickLine(_ trick: MascotAntic) -> String {
        switch trick {
        case .spin: L.t("看什麼看，轉圈而已。", "What? It's just a spin.")
        case .flip: L.t("後空翻。你會嗎？不會就去背單字。", "A backflip. Can you? No? Go study.")
        case .dance: L.t("跳完了，換你去練習。", "Dance done. Your turn: practice.")
        case .stretch: L.t("伸懶腰中，不要吵。", "Stretching. Don't.")
        }
    }

    private func love() {
        hearts += 1
        say(L.t("……好啦，可以再摸一下。", "…Fine. You may continue."), for: 1.8)
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
