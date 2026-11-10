import SwiftUI
import Word7000Core

/// The classic layout's chapter page, in the classic Today's own look: the
/// chapter's card on light olive (today's ring, how much of the chapter is
/// known, the streak, the button for the next step, the cat on its edge),
/// then today's steps as the same coloured paper tiles as Today's practice
/// (cards, writing, quiz, speaking), each saying where it stands, a gold
/// stamp once done, the next one ringed. Like Today it fits the phone: the
/// tiles share the room down to the tab bar, and only very large text scrolls.
struct ChapterPageView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var studySettingsOpen = false
    @State private var hops = 0
    @State private var tileTaps: [String: Int] = [:]
    @State private var heroWidth: CGFloat = 0

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
        .sensoryFeedback(.impact(weight: .light), trigger: tileTaps) { _, _ in model.settings.hapticsEnabled ?? true }
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
        return VStack(alignment: .leading, spacing: m.spacing) {
            hero(m, current: current)
                .entrance(0, distance: 10)
            HStack(alignment: .firstTextBaseline) {
                Text(L.t("今天要做的", "Today's steps"))
                    .font(.display(m.compact ? .headline : .title3, weight: .bold))
                Spacer()
                Text(L.t("完成 \(nodes.filter(model.isDone).count) / \(nodes.count)", "\(nodes.filter(model.isDone).count) of \(nodes.count) done"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .accessibilityIdentifier("chapter-steps-done")
            }
            .padding(.horizontal, 4)
            grid(nodes, current: current, m, fill: fill)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, m.compact ? 6 : 12)
        .padding(.bottom, m.compact ? 12 : 20)
    }

    // MARK: The card

    /// As Today's card: the ring of today's words, the chapter and how much of
    /// it is known, the streak and the words left, and one button for the next
    /// step; on light olive, the cat standing on its top edge.
    private func hero(_ m: ClassicMetrics, current: TodayNode?) -> some View {
        let progress = model.progress
        let cream = TodayView.cream
        let known = chapter.flatMap { index in model.shelfChapters.indices.contains(index) ? model.shelfChapters[index] : nil }
        let left = max(0, progress.dailyTarget - progress.studiedToday)
        let summary = VStack(alignment: .leading, spacing: m.compact ? 6 : 8) {
            Text(chapterTitle)
                .font(.display(m.compact ? .title3 : .title2, weight: .bold))
                .foregroundStyle(cream)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if let known {
                Text(L.t("這一章已會 \(known.mastered) / \(known.total) 個字", "\(known.mastered) of \(known.total) known"))
                    .font(m.tall ? .subheadline : .footnote)
                    .foregroundStyle(cream.opacity(0.85))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            HStack(spacing: 6) {
                chip {
                    Label {
                        Text(L.t("\(progress.streak) 天", "\(progress.streak)d"))
                    } icon: {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.35), Color(red: 1, green: 0.55, blue: 0.25)],
                                                            startPoint: .top, endPoint: .bottom))
                    }
                }
                .accessibilityLabel(L.t("連續 \(progress.streak) 天", "\(progress.streak)-day streak"))
                chip {
                    if model.goalDone {
                        Label(L.t("達成", "Done"), systemImage: "checkmark.seal.fill")
                    } else {
                        Label(L.t("差 \(left) 個", "\(left) to go"), systemImage: "target")
                    }
                }
            }
        }
        let ring = ProgressRing(fraction: model.dailyFraction, color: cream, lineWidth: m.compact ? 9 : m.tall ? 12 : 11, track: cream.opacity(0.22)) {
            VStack(spacing: 0) {
                Text("\(progress.studiedToday)")
                    .font(.display(m.compact ? .title2 : m.tall ? .largeTitle : .title, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(progress.studiedToday)))
                Text(L.ofTarget(progress.dailyTarget))
                    .font(.display(.caption2, weight: .semibold))
                    .opacity(0.8)
            }
            .foregroundStyle(cream)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .padding(.horizontal, 12)
        }
        .frame(width: m.ring, height: m.ring)

        return VStack(alignment: .leading, spacing: m.compact ? 14 : 18) {
            if m.large {
                summary
                nextButton(m, current: current)
                ring
            } else {
                HStack(alignment: .center, spacing: m.compact ? 14 : 18) {
                    ring
                    summary
                    Spacer(minLength: 0)
                }
                nextButton(m, current: current)
            }
        }
        .padding(m.heroPadding)
        // Light olive, not the caramel of today's words: a chapter is a place.
        .background { HeroBackground(tone: .done) }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { heroWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, width in heroWidth = width }
            }
        }
        .overlay(alignment: .topTrailing) {
            if !m.large {
                StrollingCompanion(mood: current == nil ? .cheer : .smug, size: m.mascot, lines: catLines(current),
                                   greeting: catLines(current).first ?? "", tip: nil,
                                   hop: hops + tileTaps.values.reduce(0, +),
                                   range: m.standsOnCard ? max(0, heroWidth - m.mascot - 28) : 0,
                                   pause: tileTaps.values.reduce(0, +))
                    .offset(x: -12, y: -m.peek)
                    .accessibilityHidden(true)
            }
        }
        .padding(.top, m.heroTop)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chapter-header")
    }

    private func chip<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.display(.footnote, weight: .semibold))
            .foregroundStyle(TodayView.cream)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(TodayView.cream.opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(TodayView.cream.opacity(0.28), lineWidth: 1))
    }

    /// The card's button: the next step, or another set once all are done.
    private func nextButton(_ m: ClassicMetrics, current: TodayNode?) -> some View {
        Button {
            if let current { tap(current, current: current) } else {
                model.ensureStudySession(daySet: true)
                start(.study)
            }
        } label: {
            HStack(spacing: 8) {
                Text(nextTitle(current))
                Image(systemName: "arrow.right").symbolEffect(.bounce, value: hops)
            }
            .font(.headline)
            .foregroundStyle(Color(red: 0.3, green: 0.38, blue: 0.22))
            .frame(maxWidth: .infinity)
            .padding(.vertical, m.compact ? 13 : m.tall ? 17 : 15)
            .background(TodayView.cream, in: Capsule())
            .shadow(color: PremiumSurface.umber.opacity(0.3), radius: 10, y: 5)
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityIdentifier("chapter-next")
    }

    private func nextTitle(_ current: TodayNode?) -> String {
        switch current {
        case .cards: return model.progress.studiedToday > 0 ? L.t("繼續翻卡", "Keep flipping") : L.t("開始翻卡", "Start the cards")
        case .spell: return model.studyMode == .english ? L.t("開始拼字", "Start spelling") : L.t("開始寫字", "Start writing")
        case .quiz: return L.t("開始考考看", "Start the quiz")
        case .speaking: return L.t("開始口說", "Start speaking")
        default: return L.extraAction
        }
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

    // MARK: The steps

    /// Two by two, as Today's practice tiles; they share the room down to the
    /// tab bar when the page fits.
    private func grid(_ nodes: [TodayNode], current: TodayNode?, _ m: ClassicMetrics, fill: Bool) -> some View {
        let items = nodes.map { item($0, current: current) }
        let columns = m.large ? 1 : 2
        let rows = stride(from: 0, to: items.count, by: columns).map { Array(items[$0..<min($0 + columns, items.count)]) }
        return VStack(spacing: m.tileSpacing) {
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: m.tileSpacing) {
                    ForEach(Array(rows[row].enumerated()), id: \.element.id) { offset, item in
                        let tallCard = m.tallCards && rows[row].count == columns
                        let height = m.tileHeight(tallCard: tallCard)
                        Button {
                            tileTaps[item.id, default: 0] += 1
                            item.action()
                        } label: {
                            ClassicTile(item: item, tallCard: tallCard, style: m.tileStyle(tallCard: tallCard),
                                        minHeight: height.min, maxHeight: fill ? .infinity : nil,
                                        bounce: tileTaps[item.id, default: 0])
                        }
                        .buttonStyle(ClassicTilePressStyle())
                        .entrance(1 + row * columns + offset, distance: 12)
                        .accessibilityIdentifier(item.id)
                        .accessibilityValue(item.done ? L.t("完成", "Done") : item.next ? L.t("下一步", "Next") : item.detail)
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : Motion.reveal, value: current)
    }

    /// A step as a tile in its Today colours.
    private func item(_ node: TodayNode, current: TodayNode?) -> ClassicTileItem {
        var icon = "bubble.left.and.text.bubble.right.fill"
        var tint = Palette.known
        switch node {
        case .cards: icon = "rectangle.on.rectangle.angled"; tint = Palette.review
        case .spell: icon = model.studyMode == .english ? "character.cursor.ibeam" : "pencil.and.scribble"; tint = Palette.accent
        case .quiz: icon = "checklist"; tint = Palette.chinese
        default: break
        }
        return ClassicTileItem(id: "chapter-step-\(node.rawValue)", icon: icon, tint: tint, title: title(node), detail: detail(node),
                               done: model.isDone(node), next: node == current) { tap(node, current: current) }
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
            return L.t("翻完卡，寫剛學的字", "After the cards")
        case .quiz:
            if done { return L.t("考完了", "All answered") }
            if routine?.step == .exam { return L.t("還剩 \(routine?.examLeft.count ?? 0) 題", "\(routine?.examLeft.count ?? 0) left") }
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
