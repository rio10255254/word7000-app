import SwiftUI
import Word7000Core

// The classic layout: Today as it was in 2.0.2, one goal, one button and the
// practice tiles to pick from, for learners who would rather choose what to
// practise than follow today's path. It runs on today's rules (the same
// sessions, schedule and fixes as the path); only the page is the old one.
// Today's path lives on in the Language learning tab (LearningPathView).

/// How much room Today has on the phone it runs on, and the sizes that follow.
/// Three heights cover every iPhone: SE-sized (about 600 points between the
/// status bar and the tab bar), the usual 6.1" to 6.3" phones, and the big Plus
/// and Pro Max ones (about 750 and up).
private struct ClassicMetrics {
    enum Tier { case compact, regular, tall }
    var tier: Tier
    /// Accessibility text sizes: one column, nothing peeking over the card.
    var large: Bool

    /// The room between the status bar and the tab bar.
    var height: CGFloat

    init(height: CGFloat, large: Bool) {
        self.large = large
        self.height = height
        tier = height < 630 ? .compact : height < 750 ? .regular : .tall
    }

    var compact: Bool { tier == .compact }
    var tall: Bool { tier == .tall }
    var spacing: CGFloat { compact ? 12 : tall ? 20 : 16 }
    var ring: CGFloat { compact ? 84 : tall ? 116 : 100 }
    var heroPadding: CGFloat { compact ? 16 : tall ? 22 : 20 }
    var mascot: CGFloat { compact ? 58 : tall ? 80 : 70 }
    /// Where there is room, the companion stands on the hero card's top edge
    /// (its feet in the card's top padding) and can stroll along it; on the
    /// SE-sized phones it peeks over the corner and stays put.
    var standsOnCard: Bool { !compact && !large }
    /// How far the companion rises above the hero card's top edge.
    var peek: CGFloat { standsOnCard ? (mascot * 0.94 - 12).rounded() : (mascot * 0.42).rounded() }
    /// Room above the card so the companion stays clear of the header.
    var heroTop: CGFloat { large ? 0 : max(0, peek + (standsOnCard ? 10 : 6) - spacing) }
    /// Practice tiles: tall cards (icon up top, words along the bottom) on the
    /// big phones, short rows elsewhere.
    var tallCards: Bool { tall && !large && height >= 785 }
    var tileSpacing: CGFloat { compact ? 8 : tall ? 12 : 10 }
    /// Type and icon sizes, which grow with the room the tiles have.
    func tileStyle(tallCard: Bool) -> ClassicTileStyle {
        if compact { return ClassicTileStyle(icon: 36, title: .subheadline, detail: .caption) }
        if tallCard { return ClassicTileStyle(icon: 52, title: .title2, detail: .subheadline) }
        // Small enough beside the icon that a four-character title stays on one line.
        return ClassicTileStyle(icon: tall ? 48 : 44, title: .title3, detail: .subheadline)
    }

    /// The shortest and tallest a tile may be. When everything fits, the tiles
    /// grow from the shortest toward the tallest to use the room left over.
    func tileHeight(tallCard: Bool) -> (min: CGFloat, max: CGFloat) {
        if tallCard { return (112, 172) }
        return compact ? (54, 92) : tall ? (70, 112) : (62, 122)
    }
}

/// One goal, one button, and the little companion cheering you on. The page
/// is fitted to the phone: when it all fits, it does not scroll and the
/// practice tiles grow into whatever room is left; only when it does not fit,
/// as with very large text, does it scroll.
struct ClassicTodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(PlusModel.self) private var plus
    @Environment(AccountModel.self) private var account
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var studySettingsOpen = false
    @State private var signInOpen = false
    /// The quiz's few settings, in a half-height sheet before it starts.
    @State private var quizSetupOpen = false
    @State private var quizQueued = false
    /// Bumped to bounce the streak flame: on arrival and when the streak grows.
    @State private var flameBounce = 0
    @State private var greetingHops = 0
    /// What the cat knows and today's AI lines, gathered on arrival.
    @State private var catLines = CatLineSource.none
    /// Taps on each practice tile, to bounce its icon.
    @State private var tileTaps: [String: Int] = [:]
    /// The hero card's width: how far the companion can stroll.
    @State private var heroWidth: CGFloat = 0
    /// Today's AI insight headline, once worked out; the companion says it.
    @State private var insightHeadline: String?
    @State private var mascotChatOpen = false
    /// Focus words to practise once the companion's chat has closed.
    @State private var focusPractice: [String]?

    var start: (Activity) -> Void

    var body: some View {
        let progress = model.progress

        GeometryReader { proxy in
            let metrics = ClassicMetrics(height: proxy.size.height, large: dynamicTypeSize.isAccessibilitySize)
            ViewThatFits(in: .vertical) {
                // It all fits: no scrolling, and the tiles take up the slack.
                page(metrics, fill: true)
                    .frame(maxHeight: .infinity, alignment: .top)
                // It doesn't (very large text, or several notices on a small phone).
                ScrollView {
                    page(metrics, fill: false)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .background { AmbientBackground(tint: model.goalDone ? Palette.known : Palette.accent) }
        .animation(reduceMotion ? nil : Motion.reveal, value: plus.nudge)
        .task {
            // A little hello from the flame and the mascot each time Today comes into view.
            try? await Task.sleep(for: .milliseconds(500))
            guard !reduceMotion else { return }
            if model.progress.streak > 0 { flameBounce += 1 }
            greetingHops += 1
        }
        .onChange(of: progress.streak) { old, new in
            if new > old, !reduceMotion { flameBounce += 1 }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: tileTaps) { _, _ in model.settings.hapticsEnabled ?? true }
        .sheet(isPresented: $studySettingsOpen) { StudySettingsSheet().compactSheet() }
        .sheet(isPresented: $signInOpen) { SignInSheet(reason: .general) }
        .sheet(isPresented: $mascotChatOpen, onDismiss: {
            insightHeadline = InsightsStore.today(mode: model.studyMode)?.headline
            guard let ids = focusPractice else { return }
            focusPractice = nil
            model.startStudySession(onlyIds: ids)
            start(.study)
        }) {
            MascotChatSheet(practise: { ids in
                focusPractice = ids
                mascotChatOpen = false
            })
        }
        .task {
            insightHeadline = InsightsStore.today(mode: model.studyMode)?.headline
            catLines = model.catLines
            // Today's lines, written for this learner, once a day in the background.
            await CatLinePackStore.refreshIfNeeded(model)
            catLines = model.catLines
        }
        .onChange(of: progress.studiedToday) { _, _ in catLines = model.catLines }
        .onChange(of: mascotChatOpen) { _, open in if open { model.noteTried(.chat) } }
        .task(id: model.guideStep) { if let step = model.guideStep { model.noteGuideShown(step) } }
        .sheet(isPresented: $quizSetupOpen, onDismiss: {
            guard quizQueued else { return }
            quizQueued = false
            start(.quizReady)
        }) {
            NavigationStack {
                QuizConfiguration(start: {
                    quizQueued = true
                    quizSetupOpen = false
                })
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L.close) { quizSetupOpen = false }
                    }
                }
            }
            .compactSheet()
        }
    }

    private func page(_ m: ClassicMetrics, fill: Bool) -> some View {
        VStack(alignment: .leading, spacing: m.spacing) {
            header(m)
                // Drawn above the card, so its buttons always win the tap.
                .zIndex(1)
            hero(m)
                .entrance(0, distance: 10)
            notices
            checklist
            practice(m, fill: fill)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, m.compact ? 6 : 12)
        .padding(.bottom, m.compact ? 12 : 20)
    }

    // MARK: Header

    /// The greeting and date, with the language switch and the bank being
    /// studied (a chip that opens the study scope).
    private func header(_ m: ClassicMetrics) -> some View {
        // At accessibility text sizes the controls drop below the greeting.
        let layout = m.large ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                             : AnyLayout(HStackLayout(alignment: .center, spacing: 10))
        return layout {
            VStack(alignment: .leading, spacing: 1) {
                Text(greeting)
                    .font(.display(m.tall ? .title : .title2, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                // Formatted in the interface language, which follows the study mode.
                HStack(spacing: 4) {
                    Image(systemName: daySymbol)
                        .symbolRenderingMode(.multicolor)
                        .symbolEffect(.bounce, value: greetingHops)
                    Text(Date.now, format: .dateTime.month(.abbreviated).day().weekday(.abbreviated))
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            if !m.large { Spacer(minLength: 4) }
            HStack(spacing: 8) {
                languageSwitch
                scopeChip
            }
            .layoutPriority(1)
        }
    }

    private var scopeChip: some View {
        Button { studySettingsOpen = true } label: {
            HStack(spacing: 6) {
                Image(systemName: model.settings.studyFilter.isActive ? "line.3.horizontal.decrease.circle.fill" : "books.vertical.fill")
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(Palette.accent)
                Text(model.bankName)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background { PremiumSurface(radius: 18) }
            .contentShape(Capsule())
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel(L.t("學習範圍：\(model.bankName)", "Study scope: \(model.bankName)"))
        .accessibilityIdentifier("today-study-filter")
    }

    /// Which language is being learned, switched in one tap: EN for English
    /// (with a Chinese interface), 中 for Chinese (with an English one).
    private var languageSwitch: some View {
        HStack(spacing: 2) {
            ForEach([StudyMode.english, StudyMode.chinese], id: \.self) { mode in
                let selected = model.studyMode == mode
                Button {
                    guard !selected else { return }
                    withAnimation(reduceMotion ? nil : Motion.reveal) { model.setStudyMode(mode) }
                } label: {
                    Text(mode == .english ? "EN" : "中")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(selected ? Color.white : Color.secondary)
                        .frame(minWidth: 34, minHeight: 30)
                        .background(selected ? Palette.accent : Color.clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityLabel(mode == .english ? L.t("學英文", "Learn English") : L.t("學中文", "Learn Chinese"))
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier(mode == .english ? "today-language-en" : "today-language-zh")
            }
        }
        .padding(3)
        .background { PremiumSurface(radius: 18) }
        // A small control: with the largest text it would be squeezed and
        // cut "EN" in half, so it keeps its size and stops growing at a point.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L.t("學習語言", "Learning language"))
        .accessibilityIdentifier("today-language")
    }

    // MARK: Hero

    private func hero(_ m: ClassicMetrics) -> some View {
        let progress = model.progress
        let plan = model.studyPlan
        let left = max(0, progress.dailyTarget - progress.studiedToday)
        let summary = VStack(alignment: .leading, spacing: m.compact ? 6 : 8) {
            Text(model.goalDone ? L.goalDoneTitle : L.goalTitle)
                .font(.display(m.compact ? .title3 : .title2, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(Self.cream)
                .contentTransition(.opacity)
            Text(model.routineHeroLine ?? L.todayPlan(due: plan.review, fresh: plan.fresh))
                .font(m.tall ? .subheadline : .footnote)
                .foregroundStyle(Self.cream.opacity(0.85))
            HStack(spacing: 6) {
                heroChip {
                    Label {
                        Text(L.t("\(progress.streak) 天", "\(progress.streak)d"))
                            .contentTransition(.numericText(value: Double(progress.streak)))
                    } icon: {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.35), Color(red: 1, green: 0.55, blue: 0.25)],
                                                            startPoint: .top, endPoint: .bottom))
                            .symbolEffect(.bounce, value: flameBounce)
                    }
                }
                .accessibilityLabel(L.t("連續 \(progress.streak) 天", "\(progress.streak)-day streak"))
                heroChip {
                    if model.goalDone {
                        Label(L.t("達成", "Done"), systemImage: "checkmark.seal.fill")
                    } else {
                        Label(L.t("差 \(left) 個", "\(left) to go"), systemImage: "target")
                            .contentTransition(.numericText(value: Double(left)))
                    }
                }
                .accessibilityLabel(model.goalDone ? L.t("目標達成", "Goal reached") : L.t("還差 \(left) 個", "\(left) to go"))
            }
        }
        let ring = ProgressRing(fraction: model.dailyFraction, color: Self.cream, lineWidth: m.compact ? 9 : m.tall ? 12 : 11, track: Self.cream.opacity(0.22)) {
            VStack(spacing: 0) {
                Text("\(progress.studiedToday)")
                    .font(.display(m.compact ? .title2 : m.tall ? .largeTitle : .title, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(progress.studiedToday)))
                Text(L.ofTarget(progress.dailyTarget))
                    .font(.display(.caption2, weight: .semibold))
                    .opacity(0.8)
            }
            .foregroundStyle(Self.cream)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .padding(.horizontal, 12)
        }
        .frame(width: m.ring, height: m.ring)

        return VStack(alignment: .leading, spacing: m.compact ? 14 : 18) {
            if m.large {
                // With very large text the way in comes first, before it scrolls out of reach.
                summary
                startButton(m)
                ring
            } else {
                HStack(alignment: .center, spacing: m.compact ? 14 : 18) {
                    ring
                    summary
                    Spacer(minLength: 0)
                }
                startButton(m)
            }
        }
        .padding(m.heroPadding)
        .background { HeroBackground(tone: model.goalDone ? .done : .words) }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { heroWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, width in heroWidth = width }
            }
        }
        // The companion stands on (or peeks over) the card's top edge, at home
        // in the right corner, and now and then strolls along it.
        .overlay(alignment: .topTrailing) {
            if !m.large {
                StrollingCompanion(mood: mascotMood, size: m.mascot, lines: mascotLines,
                                   greeting: guideTip?.text ?? insightHeadline ?? mascotGreeting, tip: guideTip ?? mascotTip,
                                   hop: greetingHops + tileTaps.values.reduce(0, +),
                                   range: m.standsOnCard ? max(0, heroWidth - m.mascot - 28) : 0,
                                   pause: tileTaps.values.reduce(0, +), onTap: { mascotChatOpen = true })
                    .offset(x: -12, y: -m.peek)
                    .accessibilityIdentifier("today-mascot")
            }
        }
        .padding(.top, m.heroTop)
        .animation(reduceMotion ? nil : Motion.reveal, value: model.goalDone)
    }

    /// Nothing left in the range studied, and no checks waiting either.
    private var nothingToStudy: Bool { model.studyPlan.total == 0 && !model.routinePending }

    private func startButton(_ m: ClassicMetrics) -> some View {
        Button {
            // Today's set, also when a round of chosen words was opened since.
            model.ensureStudySession(daySet: true)
            start(.study)
        } label: {
            HStack(spacing: 8) {
                Text(model.primaryActionTitle)
                Image(systemName: "arrow.right")
                    .symbolEffect(.bounce, value: greetingHops)
            }
            .font(.headline)
            .foregroundStyle(model.goalDone ? Self.doneDeep : Self.deep)
            .frame(maxWidth: .infinity)
            .padding(.vertical, m.compact ? 13 : m.tall ? 17 : 15)
            .background(Self.cream, in: Capsule())
            .shadow(color: PremiumSurface.umber.opacity(0.3), radius: 10, y: 5)
        }
        .buttonStyle(SoftPressStyle())
        .disabled(nothingToStudy)
        .opacity(nothingToStudy ? 0.55 : 1)
        // A new learner who hasn't finished a round yet: this is where to start.
        .overlay(alignment: .topTrailing) {
            if model.settings.guideActive == true, model.progress.lastStudyDate == nil, !AppRuntime.catShowcase {
                StartHereSticker()
                    .offset(x: -8, y: -16)
            }
        }
        .accessibilityIdentifier("today-start")
    }

    private func heroChip<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.display(.footnote, weight: .semibold))
            .foregroundStyle(Self.cream)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Self.cream.opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(Self.cream.opacity(0.28), lineWidth: 1))
    }

    /// For a new learner: every stop the cat will show them, and the next one.
    @ViewBuilder
    private var checklist: some View {
        if let stops = model.guideStops {
            let firstRound = model.progress.lastStudyDate == nil
            let current = firstRound ? stops.first : stops.first { $0.step == model.guideStep && $0.step != nil }
            GuideChecklist(stops: stops, current: current,
                           line: firstRound
                               ? L.t("先背第一組，背完我再帶你玩別的。", "Learn your first set; then I'll show you the rest.")
                               : model.guideStep.map { $0.line(plus: plus.subscribed || AppRuntime.uiTesting) },
                           go: {
                               if firstRound {
                                   model.ensureStudySession(daySet: true)
                                   start(.study)
                               } else if let step = model.guideStep {
                                   openGuide(step)
                               }
                           },
                           hide: { withAnimation(reduceMotion ? nil : Motion.reveal) { model.hideGuideChecklist() } })
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// The rare one-off notes: a guest's words not saved, the streak kept by
    /// the cat's can, or a Premium reminder.
    @ViewBuilder
    private var notices: some View {
        if account.configured, !account.isPermanent, model.progress.studiedToday > 0 {
            Button { signInOpen = true } label: {
                Label {
                    Text(L.t("訪客模式：今天的 \(model.progress.studiedToday) 個字還沒存，登入才保得住。",
                             "As a guest, today's \(model.progress.studiedToday) words aren't saved. Sign in to keep them."))
                        .font(.footnote)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                } icon: {
                    Image(systemName: "exclamationmark.icloud.fill").foregroundStyle(Palette.miss)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(padding: 12)
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityIdentifier("today-guest")
        }
        if model.streakProtectionJustUsed {
            Label {
                Text(L.t("貓罐頭幫你保住了連續 \(model.progress.streak) 天，今天學 1 個字就能接下去。",
                         "A Cat Can kept your \(model.progress.streak)-day streak. One word today keeps it going."))
                    .font(.footnote)
            } icon: {
                Image(systemName: "shield.lefthalf.filled").foregroundStyle(Palette.review)
            }
            .card(padding: 12)
            .accessibilityIdentifier("today-streak-protected")
        }
        if let nudge = plus.nudge {
            PlusNudgeBanner(nudge: nudge)
                .card(padding: 10)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: Practice

    /// The words still shaky, as a full-width tile above the others.
    private var reviewTile: ClassicTileItem? {
        guard model.stats.review > 0 else { return nil }
        return ClassicTileItem(id: "today-review", icon: "arrow.counterclockwise", tint: Palette.miss,
                               title: L.practiceStruggling, detail: L.t("練到熟為止", "Until they stick"),
                               badge: "\(model.stats.review)") {
            // One round of them at a time, the most often forgotten first.
            model.startStudySession(onlyIds: model.missedRoundIds)
            start(.study)
        }
    }

    /// The speaking path: the stage to play today, or that today's is done.
    private var speakingDetail: String {
        let path = model.speakingPath
        if model.settings.speakingWordsTab == true, !path.clearedToday(model.today) {
            return L.t("單字口說", "Word practice")
        }
        if path.clearedToday(model.today) {
            return L.t("今日已過關 ✓ 連續 \(path.currentStreak(today: model.today)) 天", "Done today ✓ \(path.currentStreak(today: model.today))-day streak")
        }
        guard let next = SpeakingScenarios.next(after: path), let scenario = SpeakingScenarios.scenario(next) else {
            return L.t("開口說說看", "Say it out loud")
        }
        let number = SpeakingScenarios.number(next)
        return L.t("第 \(number) 關 · \(scenario.title.zh)", "Stage \(number) · \(scenario.title.en)")
    }

    private var tiles: [ClassicTileItem] {
        var items: [ClassicTileItem] = []
        items.append(ClassicTileItem(id: "today-quiz", icon: "checklist", tint: Palette.chinese, title: L.quickQuiz,
                                     detail: L.t("\(model.settings.quizQuestionCount) 題", "\(model.settings.quizQuestionCount) questions")) { quizSetupOpen = true })
        items.append(ClassicTileItem(id: "today-speaking", icon: "bubble.left.and.text.bubble.right.fill", tint: Palette.known, title: L.speaking,
                                     detail: speakingDetail) { start(.speaking) })
        // Learners of English spell the word; learners of Chinese write it
        // in characters or pinyin. Writing can be turned off in Settings.
        if !model.skipsWriting {
            items.append(ClassicTileItem(id: "today-spelling", icon: model.studyMode == .english ? "character.cursor.ibeam" : "pencil.and.scribble",
                                         tint: Palette.accent, title: L.spelling,
                                         detail: L.t("\(Spelling.sessionLength) 題", "\(Spelling.sessionLength) words")) { start(.spelling) })
        }
        items.append(ClassicTileItem(id: "today-exam", icon: "timer", tint: Palette.review, title: L.t("模擬考", "Exam"),
                                     detail: L.t("限時 \(ExamView.minutes) 分鐘", "\(ExamView.minutes) min timed"),
                                     locked: plus.decide(.examPractice) != .allowed) { start(.exam) })
        return items
    }

    private func practice(_ m: ClassicMetrics, fill: Bool) -> some View {
        let items = tiles
        let columns = m.large ? 1 : 2
        let rows = stride(from: 0, to: items.count, by: columns).map { Array(items[$0..<min($0 + columns, items.count)]) }
        return VStack(alignment: .leading, spacing: m.tileSpacing) {
            Text(L.practice)
                .font(.display(m.compact ? .headline : .title3, weight: .bold))
                .padding(.leading, 4)
            if let review = reviewTile {
                tile(review, tallCard: false, m, fill: fill, order: 1)
            }
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: m.tileSpacing) {
                    ForEach(Array(rows[row].enumerated()), id: \.element.id) { offset, item in
                        // A tile alone on its row spans it as a short row.
                        tile(item, tallCard: m.tallCards && rows[row].count == columns, m, fill: fill,
                             order: 2 + row * columns + offset)
                    }
                }
            }
        }
    }

    private func tile(_ item: ClassicTileItem, tallCard: Bool, _ m: ClassicMetrics, fill: Bool, order: Int) -> some View {
        let height = m.tileHeight(tallCard: tallCard)
        return Button {
            tileTaps[item.id, default: 0] += 1
            item.action()
        } label: {
            ClassicTile(item: item, tallCard: tallCard, style: m.tileStyle(tallCard: tallCard),
                        minHeight: height.min, maxHeight: fill ? height.max : nil,
                        bounce: tileTaps[item.id, default: 0])
        }
        .buttonStyle(ClassicTilePressStyle())
        .overlay {
            if model.guideStep?.tileId == item.id { GuideRing().transition(.opacity) }
        }
        .entrance(order, distance: 12)
        .accessibilityIdentifier(item.id)
        .accessibilityValue(model.guideStep?.tileId == item.id ? L.t("傻貓推薦", "Silly Cat suggests") : "")
    }

    // MARK: Companion

    /// Unimpressed until you practise, and openly smug about it from noon on.
    private var mascotMood: Mascot.Mood {
        if model.goalDone { return .cheer }
        if model.progress.studiedToday > 0 { return .happy }
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 23 || hour < 5 { return .sleepy }
        return hour >= 12 ? .smug : .idle
    }

    /// What it says on arrival: where today stands, and what it thinks of that.
    private var mascotGreeting: String {
        let progress = model.progress
        let left = max(0, progress.dailyTarget - progress.studiedToday)
        let hour = Calendar.current.component(.hour, from: Date())
        let call = catLines.context?.callout ?? ""
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        if model.goalDone { return L.t("\(call)嗯，勉強及格。不要得意。", L.named(call, "fine. You passed. Don't get cocky.")) }
        // Every other day, a line written for today; the exam countdown when there is one.
        if day % 2 == 0, let line = (progress.studiedToday == 0 ? catLines.pack?.nudge : catLines.pack?.greeting)?.first {
            return line
        }
        if let days = catLines.context?.daysToExam, days <= 120 {
            return progress.studiedToday == 0
                ? L.t("\(call)考試剩 \(days) 天，你今天一個字都還沒背。我不說話，我就看著。", "\(call)\(days) days to the exam and not one word today. I'm not saying anything. Just watching.")
                : L.t("考試剩 \(days) 天，才 \(progress.studiedToday) 個？還差 \(left) 個。", "\(days) days to the exam. Only \(progress.studiedToday)? \(left) to go.")
        }
        if progress.studiedToday == 0 {
            if hour >= 21 { return L.t("都幾點了？今天的字要留給明天的你喔？", "This late? Saving today's words for future you?") }
            if hour >= 12 { return L.t("下午了欸。\(progress.dailyTarget) 個字還在等，我也在等。", "It's afternoon. \(progress.dailyTarget) words are waiting. So am I.") }
            return L.t("早。\(progress.dailyTarget) 個字，別讓我失望。雖然你常常。", "Morning. \(progress.dailyTarget) words. Don't let me down. Again.")
        }
        return L.t("才 \(progress.studiedToday) 個？笑死。還差 \(left) 個。", "Only \(progress.studiedToday)? LOL. \(left) to go.")
    }

    /// For a new learner, the next thing to try, said by the cat; tapping its
    /// bubble opens it.
    private var guideTip: MascotTip? {
        guard let step = model.guideStep else { return nil }
        return MascotTip(text: step.line(plus: plus.subscribed || AppRuntime.uiTesting)) { openGuide(step) }
    }

    private func openGuide(_ step: GuideStep) {
        switch step {
        case .quiz: quizSetupOpen = true
        case .speaking: start(.speaking)
        case .spelling: start(.spelling)
        // Opening a Plus feature without Plus shows what it is and the offer;
        // either way the cat has introduced it and moves on.
        case .exam:
            model.noteTried(.exam)
            start(.exam)
        case .scan:
            model.noteTried(.scan)
            start(.scan)
        // Without Plus the chat introduces the AI and offers Plus.
        case .chat: mascotChatOpen = true
        }
    }

    /// Its AI note: today's insight headline once worked out (tap for the
    /// whole chat), or an offer to work it out. Nothing when online AI is off.
    private var mascotTip: MascotTip? {
        if let insightHeadline {
            return MascotTip(text: insightHeadline) { mascotChatOpen = true }
        }
        guard CloudAssistant.shared.offered else { return nil }
        return MascotTip(text: L.t("要我看看你最近到底有多混嗎？", "Want to know how much you've been slacking?")) { mascotChatOpen = true }
    }

    /// What it says when tapped: grudging praise once the goal is met,
    /// otherwise a gentle stream of guilt.
    private var mascotLines: [String] {
        model.goalDone
            ? [L.t("好啦，你很棒。滿意了吧？", "Fine, you're great. Happy now?"),
               L.t("要不要順便測驗？還是怕了？", "Quick quiz? Or are you scared?"),
               L.t("明天同一時間，我會來找你。", "Same time tomorrow. I'll find you."),
               L.t("今天表現……還可以啦。不要跟別人說我誇你。", "Today was… okay. Don't tell anyone I said that.")]
            : catLines.contextLines + (catLines.pack?.nudge ?? []) + [L.t("我阿嬤背得都比你快。", "My grandma learns faster than you."),
               L.t("你滑手機的時間夠背十個字了。", "That scrolling time? Ten words, easily."),
               L.t("我沒有在催你，我只是一直盯著你。", "I'm not rushing you. I'm just staring."),
               L.t("單字們在哭，你有聽到嗎？", "Hear that? Your words are crying."),
               L.t("蛤？你還沒開始？", "Wait. You haven't even started?"),
               L.t("你是來讀書的，還是來看我的？", "Are you here to study or just to look at me?")]
    }

    private var daySymbol: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<17: return "sun.max.fill"
        case 17..<19: return "sunset.fill"
        default: return "moon.stars.fill"
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        // Short in English too, so it fits beside the controls on a small phone.
        case 5..<12: return L.t("早安！", "Morning!")
        case 12..<18: return L.t("午安！", "Afternoon!")
        default: return L.t("晚安！", "Evening!")
        }
    }

    private static let deep = Color(red: 0.45, green: 0.27, blue: 0.16)
    private static let doneDeep = Color(red: 0.3, green: 0.38, blue: 0.22)
    /// Text and the button on the leather card.
    private static let cream = Color(red: 1.0, green: 0.97, blue: 0.91)
}

/// One way to practise, as a tile.
struct ClassicTileItem: Identifiable {
    var id: String
    var icon: String
    var tint: Color
    var title: String
    var detail: String
    var locked = false
    var badge: String? = nil
    var action: () -> Void
}

/// Pressing a tile sinks it a little and tips it toward the finger's side,
/// like pressing into soft leather.
private struct ClassicTilePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && !reduceMotion
        configuration.label
            .scaleEffect(pressed ? 0.96 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .rotation3DEffect(.degrees(pressed ? 4 : 0), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .animation(reduceMotion ? nil : configuration.isPressed ? Motion.press : Motion.pop, value: configuration.isPressed)
    }
}

/// The icon and type sizes of a practice tile.
struct ClassicTileStyle {
    var icon: CGFloat
    var title: Font.TextStyle
    var detail: Font
}

/// A practice tile, in one of two compositions: a tall card (icon at the top,
/// title and detail along the bottom) or a short row (icon, title and detail
/// side by side), each with a faint, tilted watermark of its icon.
private struct ClassicTile: View {
    @Environment(\.appStyle) private var appStyle
    var item: ClassicTileItem
    var tallCard = false
    var style: ClassicTileStyle
    var minHeight: CGFloat
    var maxHeight: CGFloat?
    var bounce = 0

    private var radius: CGFloat { appStyle == .collage ? 0 : tallCard ? 22 : 18 }

    /// In the collage each way of practising is cut from its own paper.
    private var paper: PaperKind {
        switch item.id {
        case "today-review": .ruled
        case "today-quiz": .graph
        case "today-speaking": .peach
        case "today-spelling": .sage
        default: .mustard
        }
    }

    /// A slight, fixed tilt per tile, so the papers look laid down by hand.
    private var tilt: Double {
        switch item.id {
        case "today-review": -0.5
        case "today-quiz": 0.6
        case "today-speaking": -0.7
        case "today-spelling": 0.5
        default: -0.3
        }
    }
    private var roomy: Bool { style.icon > 40 }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        Group {
            if tallCard {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        icon(size: style.icon)
                        Spacer(minLength: 4)
                        corner
                    }
                    Spacer(minLength: 10)
                    Text(item.title)
                        .font(.display(style.title, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(item.detail)
                        .font(style.detail)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.top, 2)
                }
                .padding(14)
            } else {
                HStack(spacing: roomy ? 12 : 10) {
                    icon(size: style.icon)
                    VStack(alignment: .leading, spacing: 2) {
                        // A Chinese title stays on one line (shrinking a little if it
                        // must); an English one may take two ("Speaking practice").
                        Text(item.title)
                            .font(.display(style.title, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(item.title.contains(" ") ? 2 : 1)
                            .minimumScaleFactor(0.7)
                        Text(item.detail)
                            .font(style.detail)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    // The words come before the badge: a narrow tile keeps
                    // "Exam" whole and shows only the lock.
                    .layoutPriority(1)
                    Spacer(minLength: 2)
                    rowEnd
                }
                .padding(.horizontal, roomy ? 14 : 12)
                .padding(.vertical, roomy ? 10 : 8)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: maxHeight, alignment: tallCard ? .topLeading : .leading)
        .background {
            if appStyle == .collage {
                PaperSurface(kind: paper)
                    .overlay(alignment: .topTrailing) {
                        // A little halftone in a corner of the plainer papers.
                        if paper == .mustard || paper == .peach { Halftone().frame(width: 70, height: 50) }
                    }
                    .clipShape(TornEdgeShape(edges: paper == .peach ? [.bottom] : [], depth: 4, seed: item.id.count))
            } else {
                PremiumSurface(radius: radius)
                    .overlay { watermark }
                    .clipShape(shape)
            }
        }
        .overlay(alignment: .top) {
            if appStyle == .collage, item.id == "today-review" { TapeStrip(width: 58, angle: -4).offset(y: -9) }
        }
        .overlay {
            // A soft ring of the tile's colour spreads from the icon when it is tapped.
            if bounce > 0 {
                ClassicTileRipple(color: item.tint, tallCard: tallCard, iconSize: style.icon)
                    .id(bounce)
                    .clipShape(shape)
            }
        }
        .contentShape(shape)
        .rotationEffect(.degrees(appStyle == .collage ? tilt : 0))
    }

    /// A big, faint copy of the icon, tilted and cropped by the tile's edge.
    private var watermark: some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            let size = tallCard ? h * 0.62 : h * 0.9
            Image(systemName: item.icon)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(item.tint.opacity(0.09))
                .rotationEffect(.degrees(-12))
                .position(x: proxy.size.width - size * (tallCard ? 0.32 : 0.3),
                          y: tallCard ? h - size * 0.3 : h * 0.6)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func icon(size: CGFloat) -> some View {
        if appStyle == .collage {
            // A plain cut-paper disc.
            Image(systemName: item.icon)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, value: bounce)
                .frame(width: size, height: size)
                .background(item.tint, in: Circle())
        } else {
            leatherIcon(size: size)
        }
    }

    private func leatherIcon(size: CGFloat) -> some View {
        Image(systemName: item.icon)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .symbolEffect(.bounce, value: bounce)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [item.tint.opacity(0.7), item.tint], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .top, endPoint: .center), lineWidth: 1)
            }
            .shadow(color: item.tint.opacity(0.3), radius: 5, y: 2)
    }

    /// The tall card's top corner: the Plus mark when locked, else a small arrow.
    @ViewBuilder
    private var corner: some View {
        if item.locked {
            PlusBadgeFitting()
        } else if let badge = item.badge {
            pill(badge)
        } else {
            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(item.tint)
                .frame(width: 26, height: 26)
                .background(item.tint.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
        }
    }

    /// The short row's far end: the Plus mark, a count, or nothing.
    @ViewBuilder
    private var rowEnd: some View {
        if item.locked {
            PlusBadgeFitting()
        } else if let badge = item.badge {
            if roomy {
                // The count, set large: it carries the row's right side.
                VStack(alignment: .trailing, spacing: 0) {
                    Text(badge)
                        .font(.displaySize(style.icon * 0.7, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(item.tint)
                        .contentTransition(.numericText())
                    Text(L.t("個字", "words"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            } else {
                pill(badge)
            }
        }
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.display(.caption, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(item.tint, in: Capsule())
    }
}

/// One ripple from a tile's icon: a ring of its colour growing and fading.
private struct ClassicTileRipple: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var color: Color
    var tallCard: Bool
    var iconSize: CGFloat
    @State private var spread = false

    var body: some View {
        GeometryReader { proxy in
            let origin = tallCard ? CGPoint(x: 14 + iconSize / 2, y: 14 + iconSize / 2)
                                  : CGPoint(x: 14 + iconSize / 2, y: proxy.size.height / 2)
            Circle()
                .fill(RadialGradient(colors: [color.opacity(0.28), color.opacity(0)], center: .center, startRadius: 0, endRadius: iconSize / 2))
                .overlay(Circle().strokeBorder(color.opacity(0.35), lineWidth: 1.5))
                .frame(width: iconSize, height: iconSize)
                .scaleEffect(spread ? proxy.size.width * 2.2 / iconSize : 1)
                .opacity(spread ? 0 : 1)
                .position(origin)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.55)) { spread = true }
        }
    }
}
