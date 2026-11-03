import SwiftUI

/// A row of bars that rise and fall with the microphone level.
struct CoachLevelMeter: View {
    var level: Double
    var reduceMotion: Bool
    /// Fixed per-bar heights so the row reads as a waveform, not a block.
    private static let weights: [Double] = (0..<28).map { 0.35 + 0.65 * abs(sin(Double($0) * 0.83)) }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Self.weights.indices, id: \.self) { index in
                Capsule()
                    .fill(Palette.miss.opacity(0.35 + 0.65 * min(1, level * 1.3)))
                    .frame(width: 3, height: 4 + 20 * CGFloat(min(1, level * 1.4 * Self.weights[index])))
            }
        }
        .frame(minHeight: 24)
        .animation(reduceMotion ? nil : .spring(response: 0.18, dampingFraction: 0.62), value: level)
    }
}

/// Settles a suggestion into place a beat after the one above it. It never
/// starts fully transparent, so it stays readable while it moves.
struct CoachArrival: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var order: Int
    @State private var arrived = false

    func body(content: Content) -> some View {
        let settled = arrived || reduceMotion
        return content
            .opacity(settled ? 1 : 0.3)
            .offset(y: settled ? 0 : 10)
            .onAppear {
                guard !arrived, !reduceMotion else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.1 + Double(order) * 0.07)) { arrived = true }
            }
    }
}

/// A section's title: in the collage a strip of label tape stuck on at an
/// angle, otherwise the usual small heading.
struct CoachHeader: View {
    @Environment(\.appStyle) private var appStyle
    var title: String
    var icon: String?

    var body: some View {
        if appStyle == .collage {
            HStack(spacing: 5) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(.display(.subheadline, weight: .bold))
            .foregroundStyle(Collage.ink)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background { PaperSurface(kind: .mustard) }
            .rotationEffect(.degrees(-1.5))
        } else {
            Label {
                Text(title)
            } icon: {
                if let icon { Image(systemName: icon) }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
        }
    }
}

/// A round paper key for the recording's small controls in the collage,
/// with a hard ink shadow it is pressed onto; a plain icon in leather.
struct CoachDiscStyle: ButtonStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        CoachDisc(configuration: configuration, tint: tint)
    }
}

private struct CoachDisc: View {
    @Environment(\.appStyle) private var appStyle
    @Environment(\.isEnabled) private var isEnabled
    let configuration: ButtonStyleConfiguration
    var tint: Color

    var body: some View {
        let pressed = configuration.isPressed
        if appStyle == .collage {
            configuration.label
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background { Circle().fill(PaperKind.ivory.color).overlay { Circle().strokeBorder(Collage.ink.opacity(0.85), lineWidth: 1.5) } }
                .background { Circle().fill(Collage.ink.opacity(0.8)).offset(x: pressed ? 0 : 2.5, y: pressed ? 0 : 2.5) }
                .offset(x: pressed ? 2.5 : 0, y: pressed ? 2.5 : 0)
                .opacity(isEnabled ? 1 : 0.45)
                .contentShape(Circle())
        } else {
            configuration.label
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.12), in: Circle())
                .opacity(isEnabled ? (pressed ? 0.5 : 1) : 0.45)
                .contentShape(Circle())
        }
    }
}

/// The big record key: a disc of colour with an ink edge and a hard shadow
/// in the collage, a soft-shadowed disc in leather. It pushes in when held.
struct MicKeyStyle: ButtonStyle {
    var live: Bool

    func makeBody(configuration: Configuration) -> some View {
        MicKey(configuration: configuration, live: live)
    }
}

private struct MicKey: View {
    @Environment(\.appStyle) private var appStyle
    @Environment(\.isEnabled) private var isEnabled
    let configuration: ButtonStyleConfiguration
    var live: Bool

    var body: some View {
        let pressed = configuration.isPressed
        let tint = live ? Palette.miss : Palette.accent
        let collage = appStyle == .collage
        configuration.label
            .foregroundStyle(.white)
            .frame(width: 112, height: 112)
            .background { Circle().fill(tint) }
            .overlay { if collage { Circle().strokeBorder(Collage.ink.opacity(0.85), lineWidth: 2) } }
            .background {
                if collage {
                    Circle().fill(Collage.ink.opacity(0.8)).offset(x: pressed ? 0 : 4, y: pressed ? 0 : 5)
                }
            }
            .shadow(color: collage ? .clear : tint.opacity(0.35), radius: 14, y: 6)
            .offset(x: collage && pressed ? 4 : 0, y: collage && pressed ? 5 : 0)
            .scaleEffect(!collage && pressed ? 0.96 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Circle())
    }
}

/// One part of the answer laid down as paper in the collage (cut from its
/// own stock, a little askew, sometimes taped), a card in leather.
struct AnswerPaper: ViewModifier {
    @Environment(\.appStyle) private var appStyle
    var kind: PaperKind
    var tilt: Double = 0
    var torn: Edge.Set = []
    var tape = false
    var seed = 1

    func body(content: Content) -> some View {
        if appStyle == .collage {
            let shape = TornEdgeShape(edges: torn, depth: torn.isEmpty ? 0 : 4, seed: seed)
            content
                .padding(.horizontal, 16)
                .padding(.top, torn.contains(.top) ? 18 : 14)
                .padding(.bottom, torn.contains(.bottom) ? 18 : 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    PaperSurface(kind: kind)
                        .clipShape(shape)
                        .overlay { shape.stroke(Collage.ink.opacity(0.35), lineWidth: 0.8) }
                }
                .overlay(alignment: .top) {
                    if tape { TapeStrip(width: 64, angle: seed % 2 == 0 ? 4 : -4).offset(y: -10) }
                }
                .rotationEffect(.degrees(tilt))
        } else {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(radius: Metrics.wordCardRadius, padding: 16)
        }
    }
}
