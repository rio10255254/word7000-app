import SwiftUI

/// The new learner's checklist on Today: every stop the cat will show them,
/// the ones done ticked, the next one stamped and a button straight to it.
struct GuideChecklist: View {
    @Environment(\.appStyle) private var appStyle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let stops: [GuideStop]
    /// The stop to do next (the first round, or the cat's suggestion), if any.
    let current: GuideStop?
    let line: String?
    let go: () -> Void
    let hide: () -> Void
    @State private var pulse = false

    private var doneCount: Int { stops.filter(\.done).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Mascot(mood: .happy, size: 30)
                Text(L.t("小笨貓的新手任務", "Silly Cat's starter quests"))
                    .font(.display(.headline, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("\(doneCount)/\(stops.count)")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.accent)
                Spacer(minLength: 4)
                Button(action: hide) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L.t("隱藏新手任務", "Hide starter quests"))
                .accessibilityIdentifier("guide-checklist-hide")
            }
            HStack(spacing: 0) {
                ForEach(stops) { stop in
                    stamp(stop)
                        .frame(maxWidth: .infinity)
                }
            }
            if let current {
                HStack(alignment: .center, spacing: 10) {
                    if let line {
                        Text(line)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button(action: go) {
                        HStack(spacing: 4) {
                            Text(L.t("去\(current.title)", "Go: \(current.title)"))
                            Image(systemName: "arrow.right")
                        }
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                        .fixedSize()
                    }
                    .prominentAction()
                    .accessibilityIdentifier("guide-checklist-go")
                }
            }
        }
        .card(padding: 14)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guide-checklist")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private func stamp(_ stop: GuideStop) -> some View {
        let isCurrent = stop.id == current?.id
        let tint = stop.done ? Palette.known : isCurrent ? Palette.accent : Color.secondary
        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(stop.done ? Palette.known.opacity(0.16) : isCurrent ? Palette.accent.opacity(0.16) : Color.secondary.opacity(0.08))
                Circle()
                    .strokeBorder(tint.opacity(stop.done || isCurrent ? 0.9 : 0.3),
                                  style: StrokeStyle(lineWidth: isCurrent ? 2.2 : 1.2, dash: stop.done || isCurrent ? [] : [3, 3]))
                Image(systemName: stop.done ? "checkmark" : stop.icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(tint)
            }
            .frame(width: 38, height: 38)
            .scaleEffect(isCurrent && pulse ? 1.1 : 1)
            Text(stop.title)
                .font(.caption2.weight(isCurrent ? .bold : .medium))
                .foregroundStyle(isCurrent ? Palette.accent : stop.done ? .primary : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stop.title)
        .accessibilityValue(stop.done ? L.t("完成", "Done") : isCurrent ? L.t("下一步", "Next") : "")
    }
}
