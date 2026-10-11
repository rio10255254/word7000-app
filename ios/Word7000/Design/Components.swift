import SwiftUI

/// Today's progress as a ring, with the count in the middle.
struct ProgressRing<Label: View>: View {
    var fraction: Double
    var color: Color
    var lineWidth: CGFloat = 12
    @ViewBuilder var label: () -> Label

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.fill, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, fraction))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.85), value: fraction)
            label()
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(Int((fraction * 100).rounded()))%")
    }
}

/// A big rounded number over a small caption.
struct StatTile: View {
    var value: Int?
    var label: String
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 2) {
            Text(value.map { String($0) } ?? "–")
                .font(.roundedSize(26, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .accessibilityLabel(value.map { String($0) } ?? L.t("尚無資料", "No data"))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
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

/// Thin linear progress for a session.
struct SessionBar: View {
    var fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.fill)
                Capsule().fill(Palette.accent)
                    .frame(width: max(6, proxy.size.width * fraction))
                    .animation(.spring(response: 0.45, dampingFraction: 0.9), value: fraction)
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}
