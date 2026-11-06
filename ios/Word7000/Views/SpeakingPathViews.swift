import SwiftUI
import Word7000Core

/// "Stage 12" dropping in over the first item of a stage, then away.
struct StageBanner: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let subtitle: String
    let onFinished: () -> Void
    @State private var shown = false

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.display(.title2, weight: .bold))
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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

/// Up to three stars, landing one after another: each pops with a few
/// sparks and a tap that gets firmer, and `onLanded` once the last is down.
struct StageStars: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let count: Int
    var onLanded: () -> Void = {}
    @State private var lit = 0

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < lit ? "star.fill" : "star")
                    .font(.system(size: index == 1 ? 44 : 36, weight: .semibold))
                    .foregroundStyle(index < lit ? Palette.review : Palette.khaki)
                    .offset(y: index == 1 ? -6 : 0)
                    .scaleEffect(index < lit || reduceMotion ? 1 : 0.84)
                    .contentTransition(.symbolEffect(.replace))
                    .overlay {
                        if index < lit, !reduceMotion {
                            SparkleBurst(color: Palette.review, radius: index == 1 ? 42 : 36)
                                .offset(y: index == 1 ? -6 : 0)
                        }
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.t("\(count) 顆星", "\(count) of 3 stars"))
        .accessibilityIdentifier("speaking-stars")
        .task {
            guard !reduceMotion else { lit = count; onLanded(); return }
            do {
                for star in 0..<count {
                    try await Task.sleep(for: .milliseconds(star == 0 ? 500 : 380))
                    withAnimation(.spring(duration: 0.42, bounce: 0.55)) { lit = star + 1 }
                }
                try await Task.sleep(for: .milliseconds(count > 0 ? 220 : 0))
            } catch { return }
            onLanded()
        }
        .sensoryFeedback(trigger: lit) { _, new in
            guard new > 0, model.settings.hapticsEnabled ?? true else { return nil }
            return .impact(weight: new == 1 ? .light : new == 2 ? .medium : .heavy, intensity: 1)
        }
        .soundEffect(trigger: lit) { (old: Int, new: Int) -> SoundEffect? in new > old ? .star(new) : nil }
    }
}

/// A few stops of the path around the stage just played: stages with their
/// stars, the one to play next, and those still ahead.
struct StagePathView: View {
    let current: SpeakingScenarios.StageRef
    let progress: SpeakingPath.Progress

    var body: some View {
        let path = SpeakingScenarios.path
        let at = path.firstIndex(of: current) ?? 0
        let first = max(0, min(at - 2, path.count - 5))
        let stops = Array(path[first..<min(path.count, first + 5)])
        let next = SpeakingScenarios.next(after: progress)
        HStack(spacing: 0) {
            ForEach(Array(stops.enumerated()), id: \.element) { position, ref in
                if position > 0 {
                    Rectangle()
                        .fill(progress.stars(SpeakingScenarios.key(ref)) > 0 ? Palette.known : Palette.khaki)
                        .frame(height: 3)
                        .frame(maxWidth: .infinity)
                }
                node(ref, next: ref == next)
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.t("已通過 \(progress.cleared) 關", "\(progress.cleared) stages cleared"))
    }

    @ViewBuilder
    private func node(_ ref: SpeakingScenarios.StageRef, next: Bool) -> some View {
        let stars = progress.stars(SpeakingScenarios.key(ref))
        let icon = SpeakingScenarios.scenario(ref)?.icon ?? "bubble.left"
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(stars > 0 ? Palette.known : next ? Palette.accent : Palette.fill)
                    .frame(width: next ? 42 : 34, height: next ? 42 : 34)
                Image(systemName: stars > 0 ? "checkmark" : icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(stars > 0 || next ? .white : Palette.secondaryLabel)
            }
            Text(stars > 0 ? String(repeating: "★", count: stars) : (next ? L.t("下一關", "Next") : "\(SpeakingScenarios.number(ref))"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(stars > 0 ? Palette.review : next ? Palette.accent : Palette.secondaryLabel)
                .lineLimit(1)
                .fixedSize()
        }
        .frame(width: 46)
    }
}

/// Every scenario and its stages with their stars, to play any of them.
struct ScenarioPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let progress: SpeakingPath.Progress
    let current: SpeakingScenarios.StageRef?
    let onPick: (SpeakingScenarios.StageRef) -> Void

    var body: some View {
        let next = SpeakingScenarios.next(after: progress)
        NavigationStack {
            List {
              Group {
                ForEach(Array(SpeakingScenarios.all.enumerated()), id: \.element.id) { scenarioIndex, scenario in
                    Section {
                        ForEach(scenario.stages.indices, id: \.self) { stageIndex in
                            let ref = SpeakingScenarios.StageRef(scenario: scenarioIndex, stage: stageIndex)
                            Button { onPick(ref) } label: {
                                row(ref, title: L.t(scenario.stages[stageIndex].title.zh, scenario.stages[stageIndex].title.en), next: ref == next)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("speaking-stage-\(SpeakingScenarios.key(ref))")
                        }
                    } header: {
                        Label(L.t(scenario.title.zh, scenario.title.en), systemImage: scenario.icon)
                            .font(.headline)
                            .foregroundStyle(Palette.accent)
                            .textCase(nil)
                    }
                }
              }
              .listRowBackground(StyledRowBackground())
            }
            .warmList()
            .navigationTitle(L.t("生活情境", "Everyday scenarios"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.close) { dismiss() }.accessibilityIdentifier("speaking-scenarios-close")
                }
            }
        }
    }

    private func row(_ ref: SpeakingScenarios.StageRef, title: String, next: Bool) -> some View {
        let stars = progress.stars(SpeakingScenarios.key(ref))
        return HStack(spacing: 12) {
            Text("\(SpeakingScenarios.number(ref))")
                .font(.display(.subheadline, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(stars > 0 || next ? .white : Palette.secondaryLabel)
                .frame(width: 30, height: 30)
                .background(Circle().fill(stars > 0 ? Palette.known : next ? Palette.accent : Palette.fill))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.primary)
                if next { Text(L.t("下一關", "Up next")).font(.caption.weight(.semibold)).foregroundStyle(Palette.accent) }
            }
            Spacer()
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { star in
                    Image(systemName: star < stars ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundStyle(star < stars ? Palette.review : Palette.khaki)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L.t("\(stars) 顆星", "\(stars) of 3 stars"))
        }
        .contentShape(Rectangle())
    }
}
