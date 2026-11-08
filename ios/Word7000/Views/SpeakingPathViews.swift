import SwiftUI
import Word7000Core

/// WordCat Next: the curtain going up on a stage, each time one starts (the
/// next on the path, one picked on the map, the same one again). The
/// scenario's sign pops in over turning rays, "第 12 關" lands with a thump,
/// and the stars still to win show under it. Nothing is read aloud until it
/// has gone, so a new stage is unmistakably a new one. A tap skips it.
struct StageCurtain: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let ref: SpeakingScenarios.StageRef
    let onFinished: () -> Void
    /// 0 coming in, 1 the sign, 2 the stage's number, 3 going.
    @State private var phase = 0
    @State private var spin = false
    @State private var done = false

    private var number: Int { SpeakingScenarios.number(ref) }
    private var best: Int { model.speakingPath.stars(SpeakingScenarios.key(ref)) }

    private var scenarioTitle: String {
        guard let scenario = SpeakingScenarios.scenario(ref) else { return "" }
        return L.t(scenario.title.zh, scenario.title.en)
    }

    private var stageTitle: String {
        guard let stage = SpeakingScenarios.stage(ref) else { return "" }
        return L.t(stage.title.zh, stage.title.en)
    }

    private var dare: String {
        switch best {
        case 0: L.t("挑戰三顆星！", "Go for three stars!")
        case 3: L.t("已經三顆星了，再來一次", "Three stars already. Once more")
        default: L.t("上次 \(best) 顆星，這次拿更多", "\(best) last time. Get more this time")
        }
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Palette.background.opacity(0.6))
                .ignoresSafeArea()
            VStack(spacing: 16) {
                sign
                VStack(spacing: 6) {
                    Text(L.t("第 \(number) 關", "Stage \(number)"))
                        .font(.display(.largeTitle, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                        .monospacedDigit()
                        .scaleEffect(phase >= 2 || reduceMotion ? 1 : 1.9)
                    Text(scenarioTitle)
                        .font(.display(.title3, weight: .bold))
                        .foregroundStyle(TodayView.speakingTint)
                    Text(stageTitle)
                        .font(.headline)
                        .foregroundStyle(Palette.secondaryLabel)
                        .multilineTextAlignment(.center)
                }
                .opacity(phase >= 2 ? 1 : 0)
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { star in
                            Image(systemName: star < best ? "star.fill" : "star")
                                .font(.system(size: star == 1 ? 30 : 24, weight: .semibold))
                                .foregroundStyle(star < best ? Palette.review : Palette.khaki)
                                .offset(y: star == 1 ? -4 : 0)
                        }
                    }
                    Text(dare)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Palette.accent)
                }
                .opacity(phase >= 2 ? 1 : 0)
                .offset(y: phase >= 2 || reduceMotion ? 0 : 14)
            }
            .padding(.horizontal, 32)
            .scaleEffect(phase == 3 && !reduceMotion ? 0.92 : 1)
            .offset(y: phase == 3 && !reduceMotion ? -30 : 0)
        }
        .opacity(phase == 3 ? 0 : 1)
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.t("第 \(number) 關，\(scenarioTitle)，\(stageTitle)。\(dare)", "Stage \(number), \(scenarioTitle), \(stageTitle). \(dare)"))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(L.t("點一下開始", "Tap to begin"))
        .accessibilityIdentifier("speaking-stage-curtain")
        .sensoryFeedback(trigger: phase) { _, new in
            guard model.settings.hapticsEnabled ?? true else { return nil }
            return new == 1 ? .impact(weight: .light) : new == 2 ? .impact(weight: .heavy, intensity: 1) : nil
        }
        .soundEffect(trigger: phase) { (_: Int, new: Int) -> SoundEffect? in new == 2 ? .stamp : nil }
        .task {
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.2)) { phase = 2 }
            } else {
                withAnimation(.spring(duration: 0.5, bounce: 0.45)) { phase = 1 }
                withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) { spin = true }
                try? await Task.sleep(for: .milliseconds(420))
                withAnimation(.spring(duration: 0.38, bounce: 0.4)) { phase = 2 }
            }
            try? await Task.sleep(for: .milliseconds(1500))
            finish()
        }
    }

    /// The scenario's sign on its tile, rays turning behind it.
    private var sign: some View {
        ZStack {
            if !reduceMotion {
                ZStack {
                    ForEach(0..<12, id: \.self) { ray in
                        Capsule()
                            .fill(LinearGradient(colors: [Palette.review.opacity(0.35), Palette.review.opacity(0)],
                                                 startPoint: .bottom, endPoint: .top))
                            .frame(width: 16, height: 120)
                            .offset(y: -66)
                            .rotationEffect(.degrees(Double(ray) * 30))
                    }
                }
                .rotationEffect(.degrees(spin ? 360 : 0))
                .opacity(phase >= 1 ? 1 : 0)
                .scaleEffect(phase >= 1 ? 1 : 0.4)
            }
            Image(systemName: SpeakingScenarios.scenario(ref)?.icon ?? "bubble.left.and.bubble.right.fill")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(Palette.surface)
                .frame(width: 104, height: 104)
                .background { RaisedFill(shape: RoundedRectangle(cornerRadius: 30, style: .continuous), tint: TodayView.speakingTint, depth: 6) }
                .scaleEffect(phase >= 1 || reduceMotion ? 1 : 0.3)
                .rotationEffect(.degrees(phase >= 1 || reduceMotion ? 0 : -16))
            if phase >= 2, !reduceMotion {
                SparkleBurst(color: Palette.review, radius: 86)
                SparkleBurst(color: TodayView.speakingTint, radius: 64).rotationEffect(.degrees(22))
            }
        }
        .frame(height: 210)
    }

    private func finish() {
        guard !done else { return }
        done = true
        withAnimation(.easeIn(duration: 0.28)) { phase = 3 }
        Task {
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

/// Every scenario and its stages with their stars, to play any of them:
/// how far along the path is and the next stage on top, then each scenario
/// on its own card in its own colour, the stage up next marked.
struct ScenarioPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let progress: SpeakingPath.Progress
    let current: SpeakingScenarios.StageRef?
    let onPick: (SpeakingScenarios.StageRef) -> Void

    private static let tints: [Color] = [Palette.accent, TodayView.speakingTint, Palette.chinese, Palette.review, Palette.known, Palette.miss]

    var body: some View {
        let next = SpeakingScenarios.next(after: progress)
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    hero(next: next)
                    ForEach(Array(SpeakingScenarios.all.enumerated()), id: \.element.id) { index, scenario in
                        card(scenario, index: index, next: next)
                    }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background { AmbientBackground(tint: TodayView.speakingTint) }
            .navigationTitle(L.t("生活情境", "Everyday scenarios"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.close) { dismiss() }.accessibilityIdentifier("speaking-scenarios-close")
                }
            }
        }
    }

    // MARK: The path so far

    private func hero(next: SpeakingScenarios.StageRef?) -> some View {
        let total = SpeakingScenarios.path.count
        let cleared = progress.cleared
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Mascot(mood: cleared == 0 ? .smug : .happy, size: 60)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L.t("已過 \(cleared) / \(total) 關", "\(cleared) of \(total) stages"))
                        .font(.display(.title3, weight: .heavy))
                        .foregroundStyle(TodayView.cream)
                        .monospacedDigit()
                    Text(cleared == 0 ? L.t("從點餐開始，開口就對了。", "Start with ordering. Just open your mouth.")
                                      : L.t("一關一關來，我記著你的星星。", "One stage at a time. I'm counting your stars."))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TodayView.cream.opacity(0.85))
                }
            }
            GeometryReader { proxy in
                Capsule().fill(TodayView.cream.opacity(0.2))
                    .overlay(alignment: .leading) {
                        Capsule().fill(TodayView.cream)
                            .frame(width: max(cleared > 0 ? 8 : 0, proxy.size.width * Double(cleared) / Double(max(1, total))))
                    }
            }
            .frame(height: 8)
            if let next, let scenario = SpeakingScenarios.scenario(next) {
                Button { onPick(next) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                        Text(L.t("下一關：\(stageTitle(next))", "Next: \(stageTitle(next))"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 4)
                        Image(systemName: scenario.icon)
                    }
                    .font(.headline)
                    .foregroundStyle(TodayView.speakingTint)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(TodayView.cream, in: Capsule())
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityIdentifier("speaking-scenarios-next")
            }
        }
        .padding(18)
        .background { HeroBackground(tone: .speaking) }
        .accessibilityElement(children: .contain)
    }

    // MARK: A scenario

    private func card(_ scenario: SpeakingScenarios.Scenario, index: Int, next: SpeakingScenarios.StageRef?) -> some View {
        let tint = Self.tints[index % Self.tints.count]
        let refs = scenario.stages.indices.map { SpeakingScenarios.StageRef(scenario: index, stage: $0) }
        let done = refs.filter { progress.stars(SpeakingScenarios.key($0)) > 0 }.count
        let stars = refs.map { progress.stars(SpeakingScenarios.key($0)) }.reduce(0, +)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: scenario.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Palette.surface)
                    .frame(width: 42, height: 42)
                    .background { RaisedFill(shape: RoundedRectangle(cornerRadius: 12, style: .continuous), tint: tint, depth: 3) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.t(scenario.title.zh, scenario.title.en))
                        .font(.display(.headline, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text(L.t("\(done)/\(refs.count) 關 · ★ \(stars)/\(refs.count * 3)", "\(done)/\(refs.count) stages · ★ \(stars)/\(refs.count * 3)"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.secondaryLabel)
                        .monospacedDigit()
                }
                Spacer(minLength: 4)
                if done == refs.count, !refs.isEmpty {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(Palette.known)
                        .accessibilityLabel(L.t("全部過關", "All cleared"))
                }
            }
            ForEach(refs, id: \.self) { ref in
                Button { onPick(ref) } label: {
                    row(ref, title: stageTitle(ref), tint: tint, next: ref == next, current: ref == current)
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityIdentifier("speaking-stage-\(SpeakingScenarios.key(ref))")
            }
        }
        .padding(14)
        .background { PremiumSurface(radius: 22) }
    }

    private func stageTitle(_ ref: SpeakingScenarios.StageRef) -> String {
        guard let scenario = SpeakingScenarios.scenario(ref), scenario.stages.indices.contains(ref.stage) else { return "" }
        let title = scenario.stages[ref.stage].title
        return L.t(title.zh, title.en)
    }

    private func row(_ ref: SpeakingScenarios.StageRef, title: String, tint: Color, next: Bool, current: Bool) -> some View {
        let stars = progress.stars(SpeakingScenarios.key(ref))
        return HStack(spacing: 12) {
            Text("\(SpeakingScenarios.number(ref))")
                .font(.display(.subheadline, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(stars > 0 || next ? Palette.surface : Palette.secondaryLabel)
                .frame(width: 30, height: 30)
                .background(Circle().fill(stars > 0 ? Palette.known : next ? tint : Palette.fill))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(next ? .bold : .regular))
                    .foregroundStyle(Palette.ink)
                if next {
                    Text(L.t("下一關", "Up next")).font(.caption.weight(.heavy)).foregroundStyle(tint)
                } else if current {
                    Text(L.t("正在練", "Playing now")).font(.caption.weight(.semibold)).foregroundStyle(Palette.secondaryLabel)
                }
            }
            Spacer(minLength: 4)
            if next {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(tint)
            } else {
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(next ? tint.opacity(0.14) : Palette.fill.opacity(0.5))
        }
        .overlay {
            if next {
                RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(tint.opacity(0.6), lineWidth: 1.5)
            }
        }
        .contentShape(Rectangle())
    }
}
