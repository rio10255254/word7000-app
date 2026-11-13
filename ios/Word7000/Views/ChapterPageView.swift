import SwiftUI
import Word7000Core

/// The classic layout's chapter page. It keeps the classic Today's materials
/// (the leather card, coloured paper, tape, the gold stamp, the cat) but not
/// its layout, so the two are never mistaken for each other: Today is a grid
/// of practice to pick from, a chapter is a route to follow. At the top, the
/// chapter's cover on light olive: its number set large on a stitched label,
/// how much of it is known, today's words, a bookmark with the cat on it.
/// Below, today's steps one under another, numbered and joined by a dashed
/// line: a gold stamp on the number once done, the next one ringed and taped
/// with a Start tab. Like Today it fits the phone: the steps grow to a
/// strip's natural size and the route between them lengthens to take the
/// rest, and only very large text scrolls.
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
        GeometryReader { proxy in
            let m = ClassicMetrics(height: proxy.size.height, large: dynamicTypeSize.isAccessibilitySize)
            ViewThatFits(in: .vertical) {
                page(m, fill: true)
                    .frame(maxHeight: .infinity, alignment: .top)
                ScrollView { page(m, fill: false) }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
            }
        }
        .background { AmbientBackground(tint: TodayView.speakingTint) }
        .navigationTitle(chapterTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $studySettingsOpen) { StudySettingsSheet().compactSheet() }
        .sensoryFeedback(.impact(weight: .light), trigger: taps) { _, _ in model.settings.hapticsEnabled ?? true }
        .task {
            try? await Task.sleep(for: .milliseconds(400))
            if !reduceMotion { hops += 1 }
        }
    }

    private var chapterTitle: String {
        chapter.map { L.t("第 \($0 + 1) 章", "Chapter \($0 + 1)") } ?? L.t("今天的單字", "Today's words")
    }

    private func page(_ m: ClassicMetrics, fill: Bool) -> some View {
        let nodes = model.todayNodes
        let current = model.currentTodayNode
        let doneCount = nodes.filter(model.isDone).count
        return VStack(alignment: .leading, spacing: m.spacing) {
            cover(m, current: current)
                .entrance(0, distance: 10)
            HStack(alignment: .firstTextBaseline) {
                Text(L.t("今天的路線", "Today's route"))
                    .font(.display(m.compact ? .headline : .title3, weight: .bold))
                Spacer()
                Text(L.t("完成 \(doneCount) / \(nodes.count)", "\(doneCount) of \(nodes.count) done"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(doneCount)))
                    .animation(reduceMotion ? nil : Motion.fill, value: doneCount)
                    .accessibilityIdentifier("chapter-steps-done")
            }
            .padding(.horizontal, 4)
            route(nodes, current: current, m, fill: fill)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, m.compact ? 6 : 12)
        .padding(.bottom, m.compact ? 8 : 14)
    }

    // MARK: The cover

    private func cover(_ m: ClassicMetrics, current: TodayNode?) -> some View {
        let cream = TodayView.cream
        let progress = model.progress
        let known = chapter.flatMap { index in model.shelfChapters.indices.contains(index) ? model.shelfChapters[index] : nil }
        return HStack(alignment: .center, spacing: m.compact ? 14 : 18) {
            label(m)
            VStack(alignment: .leading, spacing: m.compact ? 6 : 8) {
                Text(L.t("語言學習", "Language learning"))
                    .font(.display(.caption, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(cream.opacity(0.75))
                if let known {
                    Text(L.t("已會 \(known.mastered) / \(known.total) 個字", "\(known.mastered) of \(known.total) known"))
                        .font(.display(m.compact ? .headline : .title3, weight: .bold))
                        .foregroundStyle(cream)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    GeometryReader { bar in
                        ZStack(alignment: .leading) {
                            Capsule().fill(cream.opacity(0.2))
                            Capsule().fill(cream).frame(width: max(8, bar.size.width * known.fraction))
                                .animation(reduceMotion ? nil : Motion.fill, value: known.fraction)
                        }
                    }
                    .frame(height: 8)
                    .accessibilityHidden(true)
                } else {
                    Text(L.t("今天的單字", "Today's words"))
                        .font(.display(.title3, weight: .bold))
                        .foregroundStyle(cream)
                }
                HStack(spacing: 6) {
                    chip(L.t("今天 \(progress.studiedToday)/\(progress.dailyTarget)", "Today \(progress.studiedToday)/\(progress.dailyTarget)"),
                         icon: model.goalDone ? "checkmark.seal.fill" : "target")
                    chip(L.t("\(progress.streak) 天", "\(progress.streak)d"), icon: "flame.fill")
                }
            }
            Spacer(minLength: m.large ? 0 : 36)
        }
        .padding(m.heroPadding)
        .background { HeroBackground(tone: .done) }
        // A bookmark hangs from the top edge, the cat sitting on it.
        .overlay(alignment: .topTrailing) {
            if !m.large {
                VStack(spacing: 0) {
                    Mascot(mood: current == nil ? .cheer : .happy, size: m.mascot * 0.82)
                        .offset(y: 8)
                        .accessibilityHidden(true)
                    BookmarkShape()
                        .fill(LinearGradient(colors: [Palette.miss.opacity(0.85), Palette.miss], startPoint: .top, endPoint: .bottom))
                        .frame(width: 26, height: m.compact ? 40 : 52)
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                }
                .padding(.trailing, 20)
                .offset(y: -m.mascot * 0.7)
            }
        }
        .padding(.top, m.large ? 0 : m.mascot * 0.55)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("chapter-header")
    }

    /// The chapter's number, large, on a stitched label.
    private func label(_ m: ClassicMetrics) -> some View {
        let cream = TodayView.cream
        let size: CGFloat = m.compact ? 70 : 86
        return VStack(spacing: -2) {
            if let chapter {
                Text(L.t("第", "CH."))
                    .font(.display(.caption, weight: .heavy))
                    .opacity(0.8)
                Text("\(chapter + 1)")
                    .font(.displaySize(size * 0.52, weight: .heavy))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if L.zh {
                    Text("章").font(.display(.caption, weight: .heavy)).opacity(0.8)
                }
            } else {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: size * 0.36, weight: .bold))
            }
        }
        .foregroundStyle(cream)
        .frame(width: size, height: size * 1.12)
        .background(cream.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(cream.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .padding(4)
        }
        .rotationEffect(.degrees(-3))
    }

    private func chip(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.display(.footnote, weight: .semibold))
            .foregroundStyle(TodayView.cream)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(TodayView.cream.opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(TodayView.cream.opacity(0.28), lineWidth: 1))
    }

    // MARK: The route

    /// Today's steps one under another, joined by a dashed line. When the
    /// page fits, the steps take the room first, up to a size that still
    /// reads as a strip; past it the dashed line between them lengthens, so a
    /// tall phone gets a longer route rather than fatter steps.
    private func route(_ nodes: [TodayNode], current: TodayNode?, _ m: ClassicMetrics, fill: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(nodes.enumerated()), id: \.element) { index, node in
                let done = model.isDone(node)
                let next = node == current
                HStack(alignment: .center, spacing: 12) {
                    marker(number: index + 1, done: done, next: next, tint: tint(node),
                           first: index == 0, last: index == nodes.count - 1)
                    Button {
                        taps += 1
                        tap(node, current: current)
                    } label: {
                        ChapterStepCard(node: node, icon: icon(node), title: title(node), detail: detail(node), tint: tint(node),
                                        done: done, next: next, startTitle: startTitle(node), compact: m.compact)
                    }
                    .buttonStyle(ClassicTilePressStyle())
                    .accessibilityLabel(title(node))
                    .accessibilityValue(done ? L.t("完成", "Done") : next ? L.t("下一步", "Next") : detail(node))
                    .accessibilityIdentifier("chapter-step-\(node.rawValue)")
                }
                .frame(minHeight: m.compact ? 62 : 74, maxHeight: fill ? (m.compact ? 84 : m.tall ? 112 : 104) : nil)
                .layoutPriority(1)
                .entrance(1 + index, distance: 12)
                if index < nodes.count - 1 {
                    // The route between two steps: short, and longer when there is room.
                    HStack(spacing: 0) {
                        dash.frame(width: 36)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: m.compact ? 8 : 12, maxHeight: fill ? (m.compact ? 28 : 44) : (m.compact ? 8 : 12))
                    .accessibilityHidden(true)
                }
            }
        }
        .animation(reduceMotion ? nil : Motion.reveal, value: current)
    }

    /// The step's number on the dashed line: a gold stamp once done, filled
    /// in the step's colour when it is next.
    private func marker(number: Int, done: Bool, next: Bool, tint: Color, first: Bool, last: Bool) -> some View {
        ZStack {
            VStack(spacing: 0) {
                dash.opacity(first ? 0 : 1)
                dash.opacity(last ? 0 : 1)
            }
            Group {
                if done {
                    DoneStamp(size: 34)
                } else {
                    Text("\(number)")
                        .font(.display(.subheadline, weight: .heavy))
                        .foregroundStyle(next ? .white : Palette.secondaryLabel)
                        .frame(width: 32, height: 32)
                        .background {
                            if next { Circle().fill(tint) } else {
                                Circle().fill(Palette.background)
                                Circle().strokeBorder(Palette.secondaryLabel.opacity(0.45), lineWidth: 1.5)
                            }
                        }
                        .scaleEffect(next && !reduceMotion ? 1.08 : 1)
                }
            }
        }
        .frame(width: 36)
        .accessibilityHidden(true)
    }

    private var dash: some View {
        VerticalLine()
            .stroke(TodayView.speakingTint.opacity(0.6), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 5]))
            .frame(width: 2)
            .frame(maxHeight: .infinity)
    }

    // MARK: A step

    private func icon(_ node: TodayNode) -> String {
        switch node {
        case .cards: "rectangle.on.rectangle.angled"
        case .spell: model.studyMode == .english ? "character.cursor.ibeam" : "pencil.and.scribble"
        case .quiz: "checklist"
        default: "bubble.left.and.text.bubble.right.fill"
        }
    }

    /// The same colours as these practices' tiles on Today.
    private func tint(_ node: TodayNode) -> Color {
        switch node {
        case .cards: Palette.review
        case .spell: Palette.accent
        case .quiz: Palette.chinese
        default: Palette.known
        }
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

    private func startTitle(_ node: TodayNode) -> String {
        node == .cards && model.progress.studiedToday > 0 ? L.t("繼續", "Continue") : L.t("開始", "Start")
    }

    private func detail(_ node: TodayNode) -> String {
        let routine = model.activeRoutine
        let done = model.isDone(node)
        switch node {
        case .cards:
            if done { return L.t("今天翻了 \(model.progress.studiedToday) 個字", "\(model.progress.studiedToday) words today") }
            if model.studyPlan.total == 0, !model.routinePending { return L.t("沒有字了，換個範圍", "Nothing left: change the range") }
            let plan = model.studyPlan
            return L.todayPlan(due: plan.review, fresh: plan.fresh)
        case .spell:
            if done { return L.t("寫完了", "All written") }
            if routine?.step == .spell { return L.t("還剩 \(routine?.spellLeft.count ?? 0) 個字", "\(routine?.spellLeft.count ?? 0) words left") }
            return L.t("翻完卡，寫剛學的字", "The new words, after the cards")
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

/// One step on the chapter's route: a strip of the step's own paper in the
/// collage (a soft card otherwise) with its sign, name and where it stands;
/// the next one ringed in its colour, taped on, with a Start tab.
private struct ChapterStepCard: View {
    @Environment(\.appStyle) private var appStyle
    var node: TodayNode
    var icon: String
    var title: String
    var detail: String
    var tint: Color
    var done: Bool
    var next: Bool
    var startTitle: String
    var compact: Bool

    private var paper: PaperKind {
        switch node {
        case .cards: .mustard
        case .spell: .sage
        case .quiz: .graph
        default: .peach
        }
    }

    private var startKey: some View {
        HStack(spacing: 4) {
            Text(startTitle)
            Image(systemName: "arrow.right")
        }
        .font((compact ? Font.caption : .subheadline).weight(.heavy))
        .foregroundStyle(.white)
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 5 : 6)
        .background(tint, in: Capsule())
    }

    var body: some View {
        let radius: CGFloat = appStyle == .collage ? 0 : 18
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: compact ? 16 : 19, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: compact ? 38 : 44, height: compact ? 38 : 44)
                .background(tint, in: Circle())
            // The next step's key sits on the title's line, so the title and
            // the detail under it keep the card's whole width ("Flip cards",
            // not "Flip car…" beside a Continue key).
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.display(compact ? .headline : .title3, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .layoutPriority(1)
                    if next {
                        Spacer(minLength: 6)
                        startKey
                    }
                }
                Text(detail)
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .layoutPriority(1)
            if !next {
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, compact ? 8 : 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .background {
            if appStyle == .collage {
                PaperSurface(kind: paper)
                    .clipShape(TornEdgeShape(edges: paper == .peach ? [.bottom] : [], depth: 3, seed: title.count + 1))
            } else {
                PremiumSurface(radius: radius)
            }
        }
        .overlay {
            if next { shape.strokeBorder(tint, lineWidth: 2.5) }
        }
        .overlay(alignment: .topLeading) {
            if appStyle == .collage, next { TapeStrip(width: 48, angle: -6).offset(x: 18, y: -9) }
        }
        .opacity(done && !next ? 0.8 : 1)
        .contentShape(shape)
    }
}

/// A ribbon bookmark: a strip with a notch cut into its lower end.
private struct BookmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.width * 0.4))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A line down the middle, for the dashed route between steps.
private struct VerticalLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}
