import SwiftUI
import Word7000Core

/// The classic layout's chapter page: today's words from this chapter as four
/// big tiles (cards, writing, quiz, speaking), each saying where it stands, the
/// one to do next lit up. A tester found the path's row of small stamps under
/// one button hard to read; here every step is its own thing to tap.
struct ChapterPageView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var studySettingsOpen = false
    @State private var hops = 0
    @State private var taps = 0

    /// The chapter (0-based); nil for today's words outside the chapters.
    var chapter: Int?
    var start: (Activity) -> Void

    var body: some View {
        let nodes = model.todayNodes
        let current = model.currentTodayNode
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(current: current)
                    HStack(alignment: .firstTextBaseline) {
                        Text(L.t("今天要做的", "Today's steps"))
                            .font(.display(.title3, weight: .bold))
                            .foregroundStyle(Palette.ink)
                        Spacer()
                        Text(L.t("完成 \(nodes.filter(model.isDone).count) / \(nodes.count)", "\(nodes.filter(model.isDone).count) of \(nodes.count) done"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.secondaryLabel)
                            .monospacedDigit()
                            .accessibilityIdentifier("chapter-steps-done")
                    }
                    .padding(.horizontal, 4)
                    grid(nodes, current: current, compact: proxy.size.height < 620)
                    if current == nil { moreButton }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .background { AmbientBackground(tint: current == .speaking ? TodayView.speakingTint : model.goalDone ? Palette.known : Palette.accent) }
        .navigationTitle(chapter.map { L.t("第 \($0 + 1) 章", "Chapter \($0 + 1)") } ?? L.t("今天的單字", "Today's words"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $studySettingsOpen) { StudySettingsSheet().compactSheet() }
        .sensoryFeedback(.impact(weight: .light), trigger: taps) { _, _ in model.settings.hapticsEnabled ?? true }
        .task {
            try? await Task.sleep(for: .milliseconds(400))
            if !reduceMotion { hops += 1 }
        }
    }

    // MARK: The header

    /// The chapter on leather: today's words as a ring, how much of the
    /// chapter is known, and the cat on top saying what comes next.
    private func header(current: TodayNode?) -> some View {
        let progress = model.progress
        let known = chapter.flatMap { index in model.shelfChapters.indices.contains(index) ? model.shelfChapters[index] : nil }
        let cream = TodayView.cream
        return HStack(alignment: .center, spacing: 18) {
            ProgressRing(fraction: model.dailyFraction, color: cream, lineWidth: 10, track: cream.opacity(0.22)) {
                VStack(spacing: 0) {
                    Text("\(progress.studiedToday)")
                        .font(.display(.title, weight: .bold))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(progress.studiedToday)))
                    Text(L.ofTarget(progress.dailyTarget))
                        .font(.display(.caption2, weight: .semibold))
                        .opacity(0.8)
                }
                .foregroundStyle(cream)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 10)
            }
            .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 6) {
                Text(chapter.map { L.t("第 \($0 + 1) 章", "Chapter \($0 + 1)") } ?? L.t("今天的單字", "Today's words"))
                    .font(.display(.subheadline, weight: .bold))
                    .foregroundStyle(cream.opacity(0.8))
                Text(current == nil ? L.t("今天的份完成！", "All done today!") : model.goalDone ? L.goalDoneTitle : L.goalTitle)
                    .font(.display(.title2, weight: .heavy))
                    .foregroundStyle(cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let known {
                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { bar in
                            ZStack(alignment: .leading) {
                                Capsule().fill(cream.opacity(0.2))
                                Capsule().fill(cream).frame(width: max(6, bar.size.width * known.fraction))
                            }
                        }
                        .frame(height: 6)
                        Text(L.t("這一章已會 \(known.mastered) / \(known.total) 個字", "\(known.mastered) of \(known.total) known in this chapter"))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(cream.opacity(0.85))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .padding(.top, dynamicTypeSize.isAccessibilitySize ? 0 : 8)
        .background { HeroBackground(tone: current == .speaking ? .speaking : current == nil ? .done : .words) }
        .overlay(alignment: .topTrailing) {
            if !dynamicTypeSize.isAccessibilitySize {
                StrollingCompanion(mood: current == nil ? .cheer : .smug, size: 62, lines: catLines(current),
                                   greeting: catLines(current).first ?? "", tip: nil, hop: hops + taps, range: 0, pause: taps)
                    .offset(x: -10, y: -50)
                    .accessibilityHidden(true)
            }
        }
        .padding(.top, dynamicTypeSize.isAccessibilitySize ? 0 : 46)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chapter-header")
    }

    private func catLines(_ current: TodayNode?) -> [String] {
        switch current {
        case .cards: [L.t("先翻卡，翻完我再考你。", "Cards first. Then I'm quizzing you.")]
        case .spell: [model.studyMode == .english ? L.t("剛學的字，拼給我看。", "Those new words? Spell them for me.")
                                                  : L.t("剛學的字，寫給我看。", "Those new words? Write them for me.")]
        case .quiz: [L.t("考考看，是真記得還是假記得。", "Quiz time. Did it really stick?")]
        case .speaking: [L.t("開口說說看，我聽著。", "Say it out loud. I'm listening.")]
        default: [L.t("今天的份做完了，算你厲害。", "All done today. Not bad, I guess.")]
        }
    }

    // MARK: The tiles

    private func grid(_ nodes: [TodayNode], current: TodayNode?, compact: Bool) -> some View {
        let columns = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        let rows = stride(from: 0, to: nodes.count, by: columns).map { Array(nodes[$0..<min($0 + columns, nodes.count)]) }
        return VStack(spacing: 14) {
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: 14) {
                    ForEach(rows[row], id: \.self) { node in
                        let number = (nodes.firstIndex(of: node) ?? 0) + 1
                        Button {
                            taps += 1
                            tap(node, current: current)
                        } label: {
                            ChapterStepTile(node: node, number: number, title: title(node), detail: detail(node),
                                            tint: tint(node), done: model.isDone(node), next: node == current,
                                            minHeight: compact ? 136 : 160)
                        }
                        .buttonStyle(SoftPressStyle())
                        .accessibilityLabel(title(node))
                        .accessibilityValue(model.isDone(node) ? L.t("完成", "Done") : node == current ? L.t("下一步", "Next") : detail(node))
                        .accessibilityIdentifier("chapter-step-\(node.rawValue)")
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : Motion.reveal, value: current)
    }

    /// Another set once today's are done.
    private var moreButton: some View {
        Button {
            model.ensureStudySession(daySet: true)
            start(.study)
        } label: {
            HStack(spacing: 8) {
                Text(L.extraAction)
                Image(systemName: "arrow.right")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
        }
        .prominentAction()
        .accessibilityIdentifier("chapter-more")
    }

    private func title(_ node: TodayNode) -> String {
        switch node {
        case .cards: L.t("翻卡", "Flip cards")
        case .spell: model.studyMode == .english ? L.t("拼字", "Spelling") : L.t("寫字", "Writing")
        case .quiz: L.t("考考看", "Quiz")
        case .speaking: L.t("口說", "Speaking")
        default: ""
        }
    }

    private func detail(_ node: TodayNode) -> String {
        let routine = model.activeRoutine
        let done = model.isDone(node)
        switch node {
        case .cards:
            if done { return L.t("今天 \(model.progress.studiedToday) 個字", "\(model.progress.studiedToday) words today") }
            if model.studyPlan.total == 0, !model.routinePending { return L.t("沒有字了，換個範圍", "Nothing left: change the range") }
            let plan = model.studyPlan
            return L.todayPlan(due: plan.review, fresh: plan.fresh)
        case .spell:
            if done { return L.t("寫完了", "All written") }
            if routine?.step == .spell { return L.t("還剩 \(routine?.spellLeft.count ?? 0) 個字", "\(routine?.spellLeft.count ?? 0) words left") }
            return L.t("翻完卡，寫剛學的字", "After the cards: the new words")
        case .quiz:
            if done { return L.t("考完了", "All answered") }
            if routine?.step == .exam { return L.t("還剩 \(routine?.examLeft.count ?? 0) 題", "\(routine?.examLeft.count ?? 0) questions left") }
            return model.examStyleName
        case .speaking:
            if done { return L.t("今天過關了", "Cleared today") }
            guard let next = SpeakingScenarios.next(after: model.speakingPath), let scenario = SpeakingScenarios.scenario(next) else {
                return L.t("開口說說看", "Say it out loud")
            }
            return L.t("第 \(SpeakingScenarios.number(next)) 關 · \(scenario.title.zh)", "Stage \(SpeakingScenarios.number(next)) · \(scenario.title.en)")
        default: return ""
        }
    }

    private func tint(_ node: TodayNode) -> Color {
        switch node {
        case .cards: Palette.accent
        case .spell: Palette.chinese
        case .quiz: Palette.review
        case .speaking: TodayView.speakingTint
        default: Palette.accent
        }
    }

    /// The step to do next goes on with today's words (the checks follow the
    /// cards in the same screen); any other step is a round of its own.
    private func tap(_ node: TodayNode, current: TodayNode?) {
        switch node {
        case .cards:
            if model.studyPlan.total == 0, !model.routinePending {
                studySettingsOpen = true
                return
            }
            model.ensureStudySession(daySet: true)
            start(.study)
        case .spell, .quiz:
            if node == current {
                model.ensureStudySession(daySet: true)
                start(.study)
            } else if node == .spell {
                start(model.studyMode == .english && model.clozeAvailable ? .cloze : .spelling)
            } else {
                start(.quickExam)
            }
        case .speaking:
            // Today's speaking is always the next scenario stage.
            model.settings.speakingWordsTab = false
            start(.speaking)
        default: break
        }
    }
}

/// One step of the day as a big tile: its number and, once done, a gold
/// stamp; the one to do next ringed in its colour with a "Next" tab; a big
/// icon, the name and where it stands. Cut paper in the collage, a soft
/// leather-edged card otherwise.
private struct ChapterStepTile: View {
    @Environment(\.appStyle) private var appStyle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var node: TodayNode
    var number: Int
    var title: String
    var detail: String
    var tint: Color
    var done: Bool
    var next: Bool
    var minHeight: CGFloat
    @State private var glow = false

    private var radius: CGFloat { appStyle == .collage ? 2 : 24 }

    private var paper: PaperKind {
        switch node {
        case .cards: .ruled
        case .spell: .sage
        case .quiz: .graph
        default: .peach
        }
    }

    private var tilt: Double {
        switch node {
        case .cards: -0.8
        case .spell: 0.7
        case .quiz: 0.5
        default: -0.6
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text("\(number)")
                    .font(.display(.subheadline, weight: .heavy))
                    .foregroundStyle(next ? .white : Palette.secondaryLabel)
                    .frame(width: 28, height: 28)
                    .background {
                        if next { Circle().fill(tint) } else { Circle().strokeBorder(Palette.secondaryLabel.opacity(0.4), lineWidth: 1.5) }
                    }
                Spacer(minLength: 4)
                if done {
                    stamp
                } else if next {
                    Text(L.t("下一步", "Next"))
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(tint, in: Capsule())
                }
            }
            Spacer(minLength: 12)
            icon
            Text(title)
                .font(.display(.title2, weight: .bold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 10)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Palette.secondaryLabel)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .background {
            if appStyle == .collage {
                PaperSurface(kind: paper)
                    .overlay(alignment: .bottomTrailing) {
                        if paper == .peach || paper == .ruled { Halftone().frame(width: 80, height: 54) }
                    }
                    .clipShape(TornEdgeShape(edges: [.bottom], depth: 4, seed: number + 3))
            } else {
                PremiumSurface(radius: radius)
                    .overlay { watermark.clipShape(shape) }
            }
        }
        .overlay(alignment: .top) {
            if appStyle == .collage, next { TapeStrip(width: 56, angle: -5).offset(y: -9) }
        }
        .overlay {
            if next {
                shape.strokeBorder(tint, lineWidth: 2.5)
                    .shadow(color: tint.opacity(glow ? 0.55 : 0.2), radius: glow ? 12 : 4)
            }
        }
        .opacity(done && !next ? 0.82 : 1)
        .contentShape(shape)
        .rotationEffect(.degrees(appStyle == .collage ? tilt : 0))
        .onAppear {
            guard next, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { glow = true }
        }
        .onChange(of: next) { _, now in
            glow = false
            guard now, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { glow = true }
        }
    }

    /// The step's sign: a disc of cut paper in the collage, an embossed tile otherwise.
    @ViewBuilder
    private var icon: some View {
        let size: CGFloat = 54
        if appStyle == .collage {
            Image(systemName: node.icon)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(tint, in: Circle())
        } else {
            Image(systemName: node.icon)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(LinearGradient(colors: [tint.opacity(0.7), tint], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .top, endPoint: .center), lineWidth: 1)
                }
                .shadow(color: tint.opacity(0.3), radius: 5, y: 2)
        }
    }

    /// A gold stamp, pressed in at a slant, once the step is done.
    private var stamp: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Color(red: 0.98, green: 0.84, blue: 0.5), Color(red: 0.82, green: 0.6, blue: 0.24)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().strokeBorder(Color.white.opacity(0.45), lineWidth: 1.5).padding(3)
            Image(systemName: "checkmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(Color(red: 0.42, green: 0.27, blue: 0.1))
        }
        .frame(width: 34, height: 34)
        .rotationEffect(.degrees(-10))
        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
    }

    /// A big, faint copy of the icon in the corner, tilted.
    private var watermark: some View {
        GeometryReader { proxy in
            let size = proxy.size.height * 0.7
            Image(systemName: node.icon)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(tint.opacity(0.08))
                .rotationEffect(.degrees(-12))
                .position(x: proxy.size.width - size * 0.28, y: proxy.size.height - size * 0.3)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
