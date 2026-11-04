import SwiftUI
import Word7000Core

/// "Stage 12" dropping in over the first word of a stage, then away.
struct StageBanner: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let stage: Int
    let onFinished: () -> Void
    @State private var shown = false

    var body: some View {
        VStack(spacing: 2) {
            Text(L.t("第 \(stage) 關", "Stage \(stage)"))
                .font(.display(.title2, weight: .bold))
            Text(L.t("先跟著說，再用自己的話回答", "Say it after me, then in your own words"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.accent.opacity(0.4), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        .scaleEffect(shown || reduceMotion ? 1 : 0.7)
        .opacity(shown ? 1 : 0)
        .offset(y: shown || reduceMotion ? 56 : 20)
        .allowsHitTesting(false)
        .accessibilityIdentifier("speaking-stage-banner")
        .task {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.5, bounce: 0.35)) { shown = true }
            try? await Task.sleep(for: .milliseconds(1400))
            withAnimation(.easeIn(duration: 0.25)) { shown = false }
            try? await Task.sleep(for: .milliseconds(300))
            onFinished()
        }
    }
}

/// Up to three stars, filling one after another.
struct StageStars: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let count: Int
    @State private var lit = 0

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < lit ? "star.fill" : "star")
                    .font(.system(size: index == 1 ? 44 : 36, weight: .semibold))
                    .foregroundStyle(index < lit ? Palette.review : Palette.khaki)
                    .offset(y: index == 1 ? -6 : 0)
                    .scaleEffect(index < lit && !reduceMotion ? 1 : 0.92)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.t("\(count) 顆星", "\(count) of 3 stars"))
        .accessibilityIdentifier("speaking-stars")
        .task {
            guard !reduceMotion else { lit = count; return }
            for star in 0..<count {
                try? await Task.sleep(for: .milliseconds(star == 0 ? 500 : 320))
                withAnimation(.spring(duration: 0.4, bounce: 0.5)) { lit = star + 1 }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: lit)
    }
}

/// A few stops of the path around the stage just cleared: earlier stages with
/// their stars, the next one to play, and locked ones after it.
struct StagePathView: View {
    /// Stars of every cleared stage, first stage first.
    let stars: [Int]

    private var latest: Int { stars.count }

    var body: some View {
        let first = max(1, latest - 2)
        let stages = Array(first...(first + 4))
        HStack(spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.element) { position, stage in
                if position > 0 {
                    Rectangle()
                        .fill(stage <= latest ? Palette.known : Palette.khaki)
                        .frame(height: 3)
                        .frame(maxWidth: .infinity)
                }
                node(stage)
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.t("已通過 \(latest) 關", "\(latest) stages cleared"))
    }

    @ViewBuilder
    private func node(_ stage: Int) -> some View {
        let cleared = stage <= latest
        let next = stage == latest + 1
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(cleared ? Palette.known : next ? Palette.accent : Palette.fill)
                    .frame(width: next ? 40 : 34, height: next ? 40 : 34)
                if cleared {
                    Image(systemName: "checkmark").font(.subheadline.weight(.bold)).foregroundStyle(.white)
                } else if next {
                    Text("\(stage)").font(.display(.headline, weight: .bold)).foregroundStyle(.white)
                } else {
                    Image(systemName: "lock.fill").font(.caption).foregroundStyle(Palette.secondaryLabel)
                }
            }
            Text(cleared ? String(repeating: "★", count: stars[stage - 1]) : (next ? L.t("下一關", "Next") : " "))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(cleared ? Palette.review : Palette.accent)
                .lineLimit(1)
                .fixedSize()
        }
        .frame(width: 44)
    }
}
