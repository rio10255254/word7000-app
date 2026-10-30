import SwiftUI

/// Today's progress as a ring, with the count in the middle. It fills up from
/// empty the first time it appears and glows softly once the goal is met.
struct ProgressRing<Label: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var fraction: Double
    var color: Color
    var lineWidth: CGFloat = 12
    /// The unfilled part of the ring.
    var track: Color = Palette.fill
    @ViewBuilder var label: () -> Label
    /// What the ring draws right now; nil until it has appeared.
    @State private var shown: Double? = nil

    var body: some View {
        let drawn = min(1, max(0, reduceMotion ? fraction : shown ?? 0))
        let complete = fraction >= 1
        ZStack {
            Circle()
                .stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, drawn))
                .stroke(AngularGradient(colors: [color.opacity(0.6), color], center: .center, startAngle: .degrees(0), endAngle: .degrees(360)),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(complete ? 0.45 : 0), radius: complete ? lineWidth * 0.7 : 0)
                .animation(reduceMotion ? nil : Motion.reveal, value: complete)
            label()
        }
        .onAppear {
            guard shown == nil else { return }
            withAnimation(Motion.fill.delay(0.12)) { shown = fraction }
        }
        .onChange(of: fraction) { _, value in
            withAnimation(Motion.fill) { shown = value }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(Int((fraction * 100).rounded()))%")
    }
}

/// A big rounded number over a small caption. The number rolls up from zero
/// the first time it appears.
struct StatTile: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var value: Int?
    var label: String
    var color: Color = .primary
    @State private var rolled = false

    var body: some View {
        let shown = rolled || reduceMotion ? value : value.map { _ in 0 }
        VStack(spacing: 2) {
            Text(shown.map { String($0) } ?? "–")
                .font(.roundedSize(26, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText(value: Double(shown ?? 0)))
                .accessibilityLabel(value.map { String($0) } ?? L.t("尚無資料", "No data"))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .onAppear {
            guard !rolled else { return }
            withAnimation(Motion.entrance(2)) { rolled = true }
        }
    }
}

/// A Settings-style row: tinted icon square, title, optional value, chevron.
struct ActionRow: View {
    var icon: String
    var tint: Color
    var title: String
    var value: String? = nil
    /// A "Plus" badge for features locked right now.
    var locked = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if locked { PlusBadge() }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.tertiaryLabel)
        }
        .contentShape(Rectangle())
    }
}

/// A capsule tag, e.g. the level of a word.
struct Tag: View {
    var text: String
    var color: Color = Palette.accent

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
    }
}

/// Thin linear progress for a session, with a soft glow on the filled part.
struct SessionBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var fraction: Double
    var tint: Color = Palette.accent

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.fill)
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.65), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(6, proxy.size.width * min(1, fraction)))
                    .shadow(color: tint.opacity(0.35), radius: 4)
                    .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.78), value: fraction)
                    .animation(reduceMotion ? nil : Motion.reveal, value: tint)
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

/// A small burst of sparks flying out from a point and fading, e.g. from the
/// check mark of a right answer. Purely decorative.
struct SparkleBurst: View {
    var color: Color = Palette.known
    var radius: CGFloat = 34
    @State private var spread = false

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) / 8 * 2 * Double.pi
                Image(systemName: index % 2 == 0 ? "sparkle" : "circle.fill")
                    .font(.system(size: index % 2 == 0 ? 12 : 5, weight: .bold))
                    .foregroundStyle(color)
                    .offset(x: spread ? CGFloat(cos(angle)) * radius : 0, y: spread ? CGFloat(sin(angle)) * radius : 0)
                    .scaleEffect(spread ? 0.4 : 1)
                    .opacity(spread ? 0 : 1)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.7)) { spread = true } }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
