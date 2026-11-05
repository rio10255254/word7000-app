import SwiftUI
import Word7000Core

/// How much room Today has on the phone it runs on, and the sizes that follow.
/// Three heights cover every iPhone: SE-sized (about 600 points between the
/// status bar and the tab bar), the usual 6.1" to 6.3" phones, and the big Plus
/// and Pro Max ones (about 750 and up).
private struct TodayMetrics {
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
    var spacing: CGFloat { compact ? 10 : tall ? 16 : 13 }
    var ring: CGFloat { compact ? 74 : tall ? 104 : 92 }
    var heroPadding: CGFloat { compact ? 14 : tall ? 20 : 18 }
    var mascot: CGFloat { compact ? 54 : tall ? 76 : 66 }
    /// Where there is room, the companion stands on the big card's top edge
    /// (its feet in the card's top padding) and can stroll along it; on the
    /// SE-sized phones it peeks over the corner and stays put.
    var standsOnCard: Bool { !compact && !large }
    /// How far the companion rises above the big card's top edge.
    var peek: CGFloat { standsOnCard ? (mascot * 0.94 - 12).rounded() : (mascot * 0.42).rounded() }
    /// Room above the card so the companion stays clear of the header.
    var heroTop: CGFloat { large ? 0 : max(0, peek + (standsOnCard ? 10 : 6) - spacing) }
    /// The big buttons along the bottom: the shortest they may be, and the
    /// tallest they grow to when there is room left over.
    var quickHeight: (min: CGFloat, max: CGFloat) { compact ? (64, 84) : tall ? (84, 118) : (76, 104) }
}

/// WordCat Next: the two pillars, words and speaking. The one to do now is
/// the big card (a ring, its steps and one button); the other is a row
/// underneath that can be made the first. Then the week's stamps with the
/// shelf of chapters, the notes that apply today and four big buttons. The
/// page is fitted to the phone: when it all fits, it does not scroll and the
/// big buttons take the room left; only when it does not fit, as with very
/// large text, does it scroll. The companion stands on the big card, always
/// clear of the buttons, and its speech bubble never takes a touch.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(PlusModel.self) private var plus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var studySettingsOpen = false
    /// The meaning quiz's few settings, in a half-height sheet before it starts.
    @State private var quizSetupOpen = false
    @State private var quizQueued = false
    /// Bumped to bounce the streak flame: on arrival and when the streak grows.
    @State private var flameBounce = 0
    @State private var greetingHops = 0
    /// What the cat knows and today's AI lines, gathered on arrival.
    @State private var catLines = CatLineSource.none
    /// The screenshot tests open the cat's chat once, on first arrival.
    @MainActor private static var showcasedChat = false
    /// Taps on each big button, to bounce its icon.
    @State private var quickTaps: [String: Int] = [:]
    /// The big card's width: how far the companion can stroll.
    @State private var heroWidth: CGFloat = 0
    /// Today's AI insight headline, once worked out; the companion says it.
    @State private var insightHeadline: String?
    @State private var mascotChatOpen = false
    /// Focus words to practise once the companion's chat has closed.
    @State private var focusPractice: [String]?
    @State private var memory = CatMemory.shared

    var start: (Activity) -> Void
    /// Opens the Words tab.
    var showWords: () -> Void = {}

    var body: some View {
        let progress = model.progress

        GeometryReader { proxy in
            let metrics = TodayMetrics(height: proxy.size.height, large: dynamicTypeSize.isAccessibilitySize)
            ViewThatFits(in: .vertical) {
                // It all fits: no scrolling, and the big buttons take up the slack.
                page(metrics, fill: true)
                    .frame(maxHeight: .infinity, alignment: .top)
                // It doesn't (very large text, or several notes on a small phone).
                ScrollView {
                    page(metrics, fill: false)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .background { AmbientBackground(tint: model.homeLead == .speaking ? Self.speakingTint : model.goalDone ? Palette.known : Palette.accent) }
        .animation(reduceMotion ? nil : Motion.reveal, value: plus.nudge)
        .animation(reduceMotion ? nil : Motion.reveal, value: model.homeLead)
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
        .sensoryFeedback(.impact(weight: .light), trigger: quickTaps) { _, _ in model.settings.hapticsEnabled ?? true }
        .sheet(isPresented: $studySettingsOpen) { StudySettingsSheet().compactSheet() }
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
            if AppRuntime.catShowcase, !Self.showcasedChat {
                Self.showcasedChat = true
                try? await Task.sleep(for: .milliseconds(600))
                mascotChatOpen = true
            }
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

    private func page(_ m: TodayMetrics, fill: Bool) -> some View {
        VStack(alignment: .leading, spacing: m.spacing) {
            header(m)
                // Drawn above the card, so its buttons always win the tap.
                .zIndex(1)
            pillars(m)
            notices
            checklist
            notes
            HomeProgressCard(compact: m.compact, flameBounce: flameBounce, openShelf: showWords)
                .entrance(2, distance: 12)
            quickButtons(m, fill: fill)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, m.compact ? 6 : 12)
        .padding(.bottom, m.compact ? 10 : 18)
    }

    // MARK: Header

    /// The greeting with the days to the exam (or the date), and the
    /// language switch.
    private func header(_ m: TodayMetrics) -> some View {
        // At accessibility text sizes the switch drops below the greeting.
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
                    Image(systemName: memory.daysToExam == nil ? daySymbol : "graduationcap.fill")
                        .symbolRenderingMode(.multicolor)
                        .symbolEffect(.bounce, value: greetingHops)
                    if let days = memory.daysToExam {
                        Text(L.t("離考試 \(days) 天", "\(days) days to the exam"))
                            .accessibilityIdentifier("today-exam-countdown")
                    } else {
                        Text(Date.now, format: .dateTime.month(.abbreviated).day().weekday(.abbreviated))
                    }
                }
                .font(.subheadline.weight(memory.daysToExam == nil ? .regular : .semibold))
                .foregroundStyle(memory.daysToExam == nil ? Palette.secondaryLabel : Palette.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            if !m.large { Spacer(minLength: 4) }
            languageSwitch
                .layoutPriority(1)
        }
    }

    /// The bank being studied, as a chip on the word card that opens the scope.
    private var bankChip: some View {
        Button { studySettingsOpen = true } label: {
            heroChip {
                HStack(spacing: 4) {
                    Image(systemName: model.settings.studyFilter.isActive ? "line.3.horizontal.decrease.circle.fill" : "books.vertical.fill")
                    Text(model.bankName)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .opacity(0.8)
                }
            }
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

    // MARK: The two pillars

    @ViewBuilder
    private func pillars(_ m: TodayMetrics) -> some View {
        if model.homeLead == .words {
            wordsHero(m)
                .entrance(0, distance: 10)
            if model.homeShowsSpeaking {
                speakingRow(m)
                    .entrance(1, distance: 10)
            }
        } else {
            speakingHero(m)
                .entrance(0, distance: 10)
            wordsRow(m)
                .entrance(1, distance: 10)
        }
    }

    /// Today's words as the big card: the ring (tap to change the goal), the
    /// bank and what is left, the three steps and the button.
    private func wordsHero(_ m: TodayMetrics) -> some View {
        let progress = model.progress
        let plan = model.studyPlan
        let left = max(0, progress.dailyTarget - progress.studiedToday)
        let summary = VStack(alignment: .leading, spacing: m.compact ? 5 : 7) {
            Text(model.goalDone ? L.goalDoneTitle : L.goalTitle)
                .font(.display(m.compact ? .title3 : .title2, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(Self.cream)
                .contentTransition(.opacity)
            Text(model.routineHeroLine ?? L.todayPlan(due: plan.review, fresh: plan.fresh))
                .font(m.tall ? .subheadline : .footnote)
                .foregroundStyle(Self.cream.opacity(0.85))
                .lineLimit(2)
            HStack(spacing: 6) {
                bankChip
                heroChip {
                    if model.goalDone {
                        Label(L.t("達成", "Done"), systemImage: "checkmark.seal.fill")
                    } else {
                        Label(L.t("差 \(left) 個", "\(left) to go"), systemImage: "target")
                            .contentTransition(.numericText(value: Double(left)))
                    }
                }
                .fixedSize()
                .accessibilityLabel(model.goalDone ? L.t("目標達成", "Goal reached") : L.t("還差 \(left) 個", "\(left) to go"))
            }
        }
        let ring = goalRing(m)

        let card = VStack(alignment: .leading, spacing: m.compact ? 12 : 16) {
            if m.large {
                // With very large text the way in comes first, before it scrolls out of reach.
                summary
                wordsButton(m)
                wordSteps(m)
                ring
            } else {
                HStack(alignment: .center, spacing: m.compact ? 12 : 16) {
                    ring
                    summary
                    Spacer(minLength: 0)
                }
                wordSteps(m)
                wordsButton(m)
            }
        }
        .padding(m.heroPadding)
        .background { HeroBackground(tone: model.goalDone ? .done : .words) }
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 30, style: .continuous))
        .contextMenu { wordsMenu }
        return standing(m, card)
            .animation(reduceMotion ? nil : Motion.reveal, value: model.goalDone)
    }

    /// Today's count in a ring; tapping it changes the daily goal.
    private func goalRing(_ m: TodayMetrics) -> some View {
        let progress = model.progress
        return Menu {
            Picker(L.dailyTargetTitle, selection: Binding(get: { model.progress.dailyTarget }, set: { model.setDailyTarget($0) })) {
                ForEach([10, 20, 30, 50], id: \.self) { value in
                    Text(L.t("每天 \(value) 個", "\(value) a day")).tag(value)
                }
            }
        } label: {
            ProgressRing(fraction: model.dailyFraction, color: Self.cream, lineWidth: m.compact ? 9 : m.tall ? 12 : 11, track: Self.cream.opacity(0.22)) {
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
            .overlay(alignment: .bottomTrailing) {
                // Says the ring can be tapped to change the goal.
                Image(systemName: "pencil")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Self.deep)
                    .frame(width: 22, height: 22)
                    .background(Self.cream, in: Circle())
                    .offset(x: 2, y: 2)
            }
            .contentShape(Circle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel(L.t("今天 \(progress.studiedToday) 個，目標 \(progress.dailyTarget) 個", "\(progress.studiedToday) of \(progress.dailyTarget) today"))
        .accessibilityHint(L.t("點兩下改每日目標", "Double-tap to change the daily goal"))
        .accessibilityIdentifier("today-goal")
    }

    /// The steps of today's words. The button leads through them in order;
    /// each one can also be tapped to go straight there.
    private func wordSteps(_ m: TodayMetrics) -> some View {
        let routine = model.activeRoutine
        let flipDone = routine.map { $0.step != .flip } ?? model.goalDone
        let spell: HeroStepChip.Mark = routine?.step == .spell ? .now : (routine?.step == .exam || routine?.step == .done) ? .done : .later
        let exam: HeroStepChip.Mark = routine?.step == .exam ? .now : routine?.step == .done ? .done : .later
        return HStack(spacing: 6) {
            stepButton("today-step-cards", .flip) {
                HeroStepChip(icon: "rectangle.on.rectangle.angled", title: L.t("翻卡", "Cards"), state: flipDone ? .done : .now, compact: m.compact)
            }
            stepButton("today-spelling", .spell) {
                HeroStepChip(icon: "pencil.line", title: model.studyMode == .english ? L.t("拼字", "Spell") : L.t("寫字", "Write"),
                             state: spell, compact: m.compact)
            }
            stepButton("today-quiz", .exam) {
                HeroStepChip(icon: "checklist", title: L.t("考考看", "Quiz"), state: exam, compact: m.compact)
            }
        }
    }

    private func stepButton<Chip: View>(_ id: String, _ step: WordRoutine.Step, @ViewBuilder label: () -> Chip) -> some View {
        Button { openStep(step) } label: { label() }
            .buttonStyle(SoftPressStyle())
            .accessibilityIdentifier(id)
    }

    /// Straight to one step. A step of today's routine that is waiting opens
    /// the routine there; otherwise it is a round of its own.
    private func openStep(_ step: WordRoutine.Step) {
        let routine = model.activeRoutine
        switch step {
        case .flip, .done:
            model.ensureStudySession()
            start(.study)
        case .spell:
            if routine?.step == .spell {
                model.ensureStudySession()
                start(.study)
            } else {
                start(model.studyMode == .english ? .cloze : .spelling)
            }
        case .exam:
            if routine?.step == .exam {
                model.ensureStudySession()
                start(.study)
            } else if model.studyMode == .english {
                start(.quickExam)
            } else {
                quizSetupOpen = true
            }
        }
    }

    /// Pressing and holding the word card: every way to practise words.
    @ViewBuilder
    private var wordsMenu: some View {
        Button { openStep(.flip) } label: { Label(L.t("只翻卡", "Just the cards"), systemImage: "rectangle.on.rectangle.angled") }
        Button { start(model.studyMode == .english ? .cloze : .spelling) } label: {
            Label(model.studyMode == .english ? L.t("只拼字", "Just spelling") : L.t("只寫字", "Just writing"), systemImage: "pencil.line")
        }
        if model.studyMode == .english {
            Button { start(.quickExam) } label: { Label(L.t("考 10 題（學測題型）", "10 exam-style questions"), systemImage: "checklist") }
        }
        Button { quizSetupOpen = true } label: { Label(L.t("看字選意思", "Pick the meaning"), systemImage: "list.bullet.rectangle") }
        Button { start(.exam) } label: { Label(L.t("限時模擬考", "Timed mock exam"), systemImage: "timer") }
        Divider()
        Button { studySettingsOpen = true } label: { Label(L.t("換字庫和範圍", "Bank and scope"), systemImage: "books.vertical") }
    }

    private func wordsButton(_ m: TodayMetrics) -> some View {
        Button {
            model.ensureStudySession()
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
            .padding(.vertical, m.compact ? 12 : m.tall ? 16 : 14)
            .background(Self.cream, in: Capsule())
            .shadow(color: PremiumSurface.umber.opacity(0.3), radius: 10, y: 5)
        }
        .buttonStyle(SoftPressStyle())
        .disabled(model.studyPlan.total == 0 && !model.routinePending)
        .opacity(model.studyPlan.total == 0 && !model.routinePending ? 0.55 : 1)
        // A new learner who hasn't finished a round yet: this is where to start.
        .overlay(alignment: .topTrailing) {
            if model.settings.guideActive == true, model.progress.lastStudyDate == nil, !AppRuntime.catShowcase {
                StartHereSticker()
                    .offset(x: -8, y: -16)
            }
        }
        .accessibilityIdentifier("today-start")
    }

    /// Today's words as a row, under the speaking card.
    private func wordsRow(_ m: TodayMetrics) -> some View {
        let progress = model.progress
        let left = max(0, progress.dailyTarget - progress.studiedToday)
        return PillarRow(icon: "rectangle.on.rectangle.angled", tint: Palette.accent, title: L.goalTitle,
                         detail: model.goalDone
                             ? L.t("完成 ✓ 今天 \(progress.studiedToday) 個", "Done ✓ \(progress.studiedToday) today")
                             : L.t("\(progress.studiedToday) / \(progress.dailyTarget) · 差 \(left) 個", "\(progress.studiedToday) of \(progress.dailyTarget) · \(left) to go"),
                         done: model.goalDone, compact: m.compact,
                         leadTitle: model.goalDone ? nil : L.t("先背", "First"),
                         lead: { model.setHomeLead(.words) },
                         open: {
                             model.ensureStudySession()
                             start(.study)
                         },
                         openId: "today-start", leadId: "today-lead-words")
            .contextMenu { wordsMenu }
    }

    // MARK: Speaking

    /// The stage to play next on the speaking path.
    private var speakingStage: (number: Int?, title: String) {
        let path = model.speakingPath
        if model.settings.speakingWordsTab == true, !model.speakingDoneToday {
            return (nil, L.t("單字口說", "Word practice"))
        }
        guard let next = SpeakingScenarios.next(after: path), let scenario = SpeakingScenarios.scenario(next) else {
            return (nil, L.t("開口說說看", "Say it out loud"))
        }
        return (SpeakingScenarios.number(next), L.t(scenario.title.zh, scenario.title.en))
    }

    private var speakingStageLine: String {
        let stage = speakingStage
        guard let number = stage.number else { return stage.title }
        return L.t("第 \(number) 關・\(stage.title)", "Stage \(number) · \(stage.title)")
    }

    /// Today's speaking as the big card: the stage, its four steps and the button.
    private func speakingHero(_ m: TodayMetrics) -> some View {
        let stage = speakingStage
        let streak = model.speakingPath.currentStreak(today: model.today)
        let disc = ZStack {
            Circle().fill(Self.cream.opacity(0.14))
            Circle().strokeBorder(Self.cream.opacity(0.5), lineWidth: m.compact ? 7 : 9)
            if let number = stage.number {
                VStack(spacing: 0) {
                    Text("\(number)")
                        .font(.display(m.compact ? .title2 : m.tall ? .largeTitle : .title, weight: .bold))
                        .monospacedDigit()
                    Text(L.t("關", "stage"))
                        .font(.display(.caption2, weight: .semibold))
                        .opacity(0.8)
                }
            } else {
                Image(systemName: "mic.fill")
                    .font(.system(size: m.ring * 0.32, weight: .bold))
            }
        }
        .foregroundStyle(Self.cream)
        .frame(width: m.ring, height: m.ring)
        .accessibilityHidden(true)
        let summary = VStack(alignment: .leading, spacing: m.compact ? 5 : 7) {
            Text(L.t("今天的口說", "Today's speaking"))
                .font(.display(m.compact ? .title3 : .title2, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(speakingStageLine)
                .font(m.tall ? .subheadline : .footnote)
                .opacity(0.85)
                .lineLimit(2)
            if streak > 0 {
                heroChip {
                    Label(L.t("口說連續 \(streak) 天", "\(streak)-day speaking streak"), systemImage: "waveform")
                }
                .fixedSize()
            }
        }
        .foregroundStyle(Self.cream)

        let card = VStack(alignment: .leading, spacing: m.compact ? 12 : 16) {
            if m.large {
                summary
                speakingButton(m)
                speakingSteps(m)
            } else {
                HStack(alignment: .center, spacing: m.compact ? 12 : 16) {
                    disc
                    summary
                    Spacer(minLength: 0)
                }
                speakingSteps(m)
                speakingButton(m)
            }
        }
        .padding(m.heroPadding)
        .background { HeroBackground(tone: .speaking) }
        return standing(m, card)
    }

    private func speakingSteps(_ m: TodayMetrics) -> some View {
        HStack(spacing: 5) {
            HeroStepChip(icon: "ear", title: L.t("聽", "Listen"), state: .now, compact: m.compact)
            HeroStepChip(icon: "repeat", title: L.t("跟讀", "Repeat"), state: .later, compact: m.compact)
            HeroStepChip(icon: "bubble.left", title: L.t("回答", "Answer"), state: .later, compact: m.compact)
            HeroStepChip(icon: "sparkles", title: L.t("用今天的字", "Use a word"), state: .later, compact: m.compact)
                .layoutPriority(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.t("聽、跟讀、回答、用今天的字", "Listen, repeat, answer, use today's words"))
    }

    private func speakingButton(_ m: TodayMetrics) -> some View {
        Button { start(.speaking) } label: {
            HStack(spacing: 8) {
                Text(speakingStage.number.map { L.t("開始第 \($0) 關", "Start stage \($0)") } ?? L.t("開始口說", "Start speaking"))
                Image(systemName: "arrow.right")
                    .symbolEffect(.bounce, value: greetingHops)
            }
            .font(.headline)
            .foregroundStyle(Self.speakingDeep)
            .frame(maxWidth: .infinity)
            .padding(.vertical, m.compact ? 12 : m.tall ? 16 : 14)
            .background(Self.cream, in: Capsule())
            .shadow(color: Self.speakingDeep.opacity(0.35), radius: 10, y: 5)
        }
        .buttonStyle(SoftPressStyle())
        .overlay {
            if model.guideStep?.tileId == "today-speaking" { GuideRing().transition(.opacity) }
        }
        .accessibilityValue(model.guideStep?.tileId == "today-speaking" ? L.t("傻貓推薦", "Silly Cat suggests") : "")
        .accessibilityIdentifier("today-speaking")
    }

    /// Today's speaking as a row, under the word card.
    private func speakingRow(_ m: TodayMetrics) -> some View {
        let done = model.speakingDoneToday
        let streak = model.speakingPath.currentStreak(today: model.today)
        return PillarRow(icon: "mic.fill", tint: Self.speakingTint, title: L.t("口說", "Speaking"),
                         detail: done ? L.t("今天過關 ✓ 連續 \(streak) 天", "Done today ✓ \(streak)-day streak") : speakingStageLine,
                         done: done, compact: m.compact,
                         leadTitle: done ? nil : L.t("先說", "First"),
                         lead: { model.setHomeLead(.speaking) },
                         open: { start(.speaking) },
                         openId: "today-speaking", leadId: "today-lead-speaking",
                         suggested: model.guideStep?.tileId == "today-speaking")
            .overlay {
                if model.guideStep?.tileId == "today-speaking" { GuideRing().transition(.opacity) }
            }
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

    /// The big card with the companion standing on (or peeking over) its top
    /// edge, at home in the right corner, now and then strolling along it.
    private func standing<Card: View>(_ m: TodayMetrics, _ card: Card) -> some View {
        card
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { heroWidth = proxy.size.width }
                        .onChange(of: proxy.size.width) { _, width in heroWidth = width }
                }
            }
            .overlay(alignment: .topTrailing) {
                if !m.large {
                    StrollingCompanion(mood: mascotMood, size: m.mascot, lines: mascotLines,
                                       greeting: guideTip?.text ?? insightHeadline ?? mascotGreeting, tip: guideTip ?? mascotTip,
                                       hop: greetingHops + quickTaps.values.reduce(0, +),
                                       range: m.standsOnCard ? max(0, heroWidth - m.mascot - 28) : 0,
                                       pause: quickTaps.values.reduce(0, +))
                        .offset(x: -12, y: -m.peek)
                        .accessibilityIdentifier("today-mascot")
                }
            }
            .padding(.top, m.heroTop)
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
                                   model.ensureStudySession()
                                   start(.study)
                               } else if let step = model.guideStep {
                                   openGuide(step)
                               }
                           },
                           hide: { withAnimation(reduceMotion ? nil : Motion.reveal) { model.hideGuideChecklist() } })
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// The rare one-off notes: streak protection used, or a Plus reminder.
    @ViewBuilder
    private var notices: some View {
        if model.streakProtectionJustUsed {
            Label {
                Text(L.t("貓罐頭幫你保住了 \(model.progress.streak) 天連勝，今天學 1 個字就能延續。",
                         "The cat's can kept your \(model.progress.streak)-day streak. One word today keeps it going."))
                    .font(.footnote)
            } icon: {
                Image(systemName: "fish.fill").foregroundStyle(Palette.review)
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

    /// Notes that only show when they apply: Sunday's quiz on the week's
    /// words, and the full mock exam in the month before the exam.
    @ViewBuilder
    private var notes: some View {
        if model.weeklyQuizDue {
            Button { start(.weeklyExam) } label: {
                HomeNoteCard(icon: "calendar.badge.checkmark", tint: Palette.chinese, title: L.t("週日週考", "Sunday quiz"),
                             detail: L.t("這週學過的字，最多 \(ExamRound.weeklyCount) 題學測題型", "This week's words, up to \(ExamRound.weeklyCount) exam-style questions"))
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityIdentifier("today-weekly-quiz")
            .transition(.move(edge: .top).combined(with: .opacity))
        }
        if let days = memory.daysToExam, days <= 30 {
            Button { start(.exam) } label: {
                HomeNoteCard(icon: "timer", tint: Palette.review, title: L.t("離考試 \(days) 天", "\(days) days to the exam"),
                             detail: L.t("來一場 \(ExamView.minutes) 分鐘的完整模擬考", "Take a full \(ExamView.minutes)-minute mock exam"),
                             locked: plus.decide(.examPractice) != .allowed)
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityIdentifier("today-exam")
        }
    }

    // MARK: Big buttons

    private func quickButtons(_ m: TodayMetrics, fill: Bool) -> some View {
        let review = model.stats.review
        let items = [
            QuickItem(id: "today-words", icon: "books.vertical.fill", title: L.t("單字本", "Words"), tint: Palette.chinese) { showWords() },
            QuickItem(id: "today-review", icon: "arrow.counterclockwise", title: L.t("錯題本", "Missed"), tint: Palette.miss,
                      badge: review > 0 ? "\(review)" : nil) {
                if review > 0 {
                    model.startStudySession(onlyIds: model.reviewWordIds)
                    start(.study)
                } else {
                    showWords()
                }
            },
            QuickItem(id: "today-scan", icon: "doc.text.viewfinder", title: L.t("拍講義", "Scan"), tint: Palette.review,
                      locked: plus.decide(.scan) != .allowed) { start(.scan) },
            QuickItem(id: "today-chat", icon: "bubble.left.and.bubble.right.fill", title: L.t("問傻貓", "Ask the cat"), tint: Palette.accent) {
                mascotChatOpen = true
            },
        ]
        let height = m.quickHeight
        let columns = m.large ? 2 : 4
        let rows = stride(from: 0, to: items.count, by: columns).map { Array(items[$0..<min($0 + columns, items.count)]) }
        return VStack(spacing: m.compact ? 8 : 10) {
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: m.compact ? 8 : 10) {
                    ForEach(rows[row]) { item in
                        Button {
                            quickTaps[item.id, default: 0] += 1
                            item.action()
                        } label: {
                            QuickButton(icon: item.icon, title: item.title, tint: item.tint, badge: item.badge, locked: item.locked,
                                        minHeight: height.min, maxHeight: fill ? height.max : nil, bounce: quickTaps[item.id, default: 0])
                        }
                        .buttonStyle(TilePressStyle())
                        .overlay {
                            if model.guideStep?.tileId == item.id { GuideRing().transition(.opacity) }
                        }
                        .accessibilityLabel(item.badge.map { "\(item.title)，\($0)" } ?? item.title)
                        .accessibilityValue(model.guideStep?.tileId == item.id ? L.t("傻貓推薦", "Silly Cat suggests") : "")
                        .accessibilityIdentifier(item.id)
                    }
                }
            }
        }
        .entrance(3, distance: 12)
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
        if model.goalDone { return L.t("\(call)嗯，勉強及格。不要得意。", "\(call)fine. You passed. Don't get cocky.") }
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
    private static let speakingDeep = Color(red: 0.16, green: 0.3, blue: 0.27)
    /// The speaking card's colour, and its row's.
    static let speakingTint = Color(red: 0.27, green: 0.47, blue: 0.41)
    /// Text and the button on the leather card.
    private static let cream = Color(red: 1.0, green: 0.97, blue: 0.91)
}

/// The companion on Today, free to wander. Every so often it waddles (or
/// runs, kicking up dust) along the top edge of the hero card, eyes on where
/// it is going, stops to look around, shows off a trick (a spin, a flip, a
/// little dance, a big stretch) and later wanders back home to the right
/// corner. Flick it and it slides along the edge, seeing stars if it hits the
/// end; leave it alone long enough and it dozes off until poked. A tap, a
/// hold, a drag or a tapped practice tile keeps it still for a while, so it
/// never walks off just as you reach for it. It stays put with Reduce Motion,
/// on the small phones, and under UI tests.
private struct StrollingCompanion: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var mood: Mascot.Mood
    var size: CGFloat
    var lines: [String]
    var greeting: String
    var tip: MascotTip?
    var hop: Int
    /// How far left of home it may go; 0 keeps it home.
    var range: CGFloat
    /// Bumped by the page (a tile tapped) to keep it still for a while.
    var pause: Int

    @State private var x: CGFloat = 0
    @State private var walking = false
    @State private var pace: Double = 1
    @State private var facing: CGFloat = 0
    @State private var restUntil = Date.distantPast
    @State private var lastTouch = Date()
    @State private var cue: MascotCue?
    /// Dizzy after a fling, or asleep after being left alone.
    @State private var dazed = false
    @State private var asleep = false
    @State private var dazeTask: Task<Void, Never>?

    private var roams: Bool { range > 40 && !reduceMotion && !AppRuntime.uiTesting }

    var body: some View {
        MascotBuddy(mood: dazed ? .dizzy : asleep ? .sleepy : mood, size: size, lines: lines, greeting: greeting,
                    // The bubble opens toward the room: left of it at home, right of it out on the left.
                    bubbleSide: x < -range / 2 ? .trailing : .leading,
                    hop: hop, walking: walking, facing: facing, tip: tip, onInteract: rest,
                    pace: pace, cue: cue, onFling: fling, onBeatenUp: stormOff)
            .offset(x: x)
            .task(id: roams) { await wander() }
            .onChange(of: pause) { _, _ in rest() }
            .onChange(of: range) { _, value in
                if -x > value { x = -value }
            }
            .onDisappear { dazeTask?.cancel() }
    }

    private func rest() {
        restUntil = Date().addingTimeInterval(8)
        lastTouch = Date()
        if asleep {
            // Woken up: a big stretch first.
            asleep = false
            perform(.stretch)
        }
    }

    private func perform(_ antic: MascotAntic) {
        cue = MascotCue(antic: antic, id: (cue?.id ?? 0) + 1)
    }

    /// Sent sliding along the edge by a flick, as far as the flick would carry
    /// it; flung hard into either end, it bumps and sees stars for a moment.
    private func fling(_ distance: CGFloat) {
        guard roams else { return }
        let wanted = x + distance * 0.8
        let target = min(0, max(-range, wanted))
        let travelled = abs(target - x)
        let bumped = abs(wanted - target) > 40
        guard travelled > 20 || bumped else { return }
        walking = false
        facing = distance < 0 ? -1 : 1
        withAnimation(.spring(response: 0.6, dampingFraction: bumped ? 0.5 : 0.85)) { x = target }
        dazeTask?.cancel()
        dazeTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            if bumped || travelled > 120 {
                dazed = true
                try? await Task.sleep(for: .seconds(1.8))
                guard !Task.isCancelled else { return }
                dazed = false
                perform(.spin)
            }
            withAnimation(.easeInOut(duration: 0.3)) { facing = 0 }
        }
    }

    /// Smacked once too often: it sees stars for a moment, then runs off to
    /// the far end of the card and sulks there, facing away, for a while.
    private func stormOff() {
        guard roams else { return }
        dazeTask?.cancel()
        dazeTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            let target: CGFloat = x < -range / 2 ? 0 : -range
            let duration = Double(abs(target - x) / 130)
            facing = target < x ? -1 : 1
            pace = 2
            walking = true
            withAnimation(.linear(duration: duration)) { x = target }
            try? await Task.sleep(for: .seconds(duration))
            walking = false
            pace = 1
            restUntil = Date().addingTimeInterval(12)
        }
    }

    private func wander() async {
        guard roams else {
            x = 0
            walking = false
            pace = 1
            return
        }
        try? await Task.sleep(for: .seconds(7))
        while !Task.isCancelled {
            if Date() < restUntil || dazed || asleep {
                try? await Task.sleep(for: .seconds(1))
                continue
            }
            // Left alone for a good while, it nods off where it is.
            if Date().timeIntervalSince(lastTouch) > 90 {
                asleep = true
                continue
            }
            switch Int.random(in: 0..<10) {
            case 0..<6: await stroll()
            case 6..<9: perform(MascotAntic.allCases.randomElement() ?? .dance)
            default: await lookAround()
            }
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .seconds(Double.random(in: 5...10)))
        }
    }

    /// Mostly short walks, now and then a run; every so often all the way home.
    private func stroll() async {
        let home = x < -10 && Int.random(in: 0..<3) == 0
        let target: CGFloat = home ? 0 : -CGFloat.random(in: 0...range)
        let distance = abs(target - x)
        guard distance > 24 else { return }
        let runs = distance > 90 && Int.random(in: 0..<3) == 0
        facing = target < x ? -1 : 1
        pace = runs ? 2 : 1
        let duration = Double(distance / (runs ? 130 : 46))
        walking = true
        withAnimation(.linear(duration: duration)) { x = target }
        try? await Task.sleep(for: .seconds(duration))
        walking = false
        pace = 1
        guard !Task.isCancelled else { return }
        // A look at the way it came, then back to the front.
        try? await Task.sleep(for: .seconds(1.4))
        withAnimation(.easeInOut(duration: 0.3)) { facing = 0 }
    }

    private func lookAround() async {
        for side: CGFloat in [-1, 1, 0] {
            withAnimation(.easeInOut(duration: 0.25)) { facing = side }
            try? await Task.sleep(for: .seconds(0.8))
            guard !Task.isCancelled else { return }
        }
    }
}

/// One of the big buttons along the bottom of Today.
private struct QuickItem: Identifiable {
    var id: String
    var icon: String
    var title: String
    var tint: Color
    var badge: String? = nil
    var locked = false
    var action: () -> Void
}

/// Pressing a tile sinks it a little and tips it toward the finger's side,
/// like pressing into soft leather.
struct TilePressStyle: ButtonStyle {
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

/// The hero card as a collage: a cut of leather (sage once the goal is met)
/// torn along its bottom, a strip of graph paper peeking out behind its right
/// edge, a piece of tape, a patch of halftone and a loose charcoal loop.
/// No shadow: the overlapping papers give the depth.
private struct CollageHeroBackground: View {
    var tone: HeroTone

    var body: some View {
        let colors: [Color] = switch tone {
        case .done: [Color(red: 0.6, green: 0.65, blue: 0.4), Color(red: 0.36, green: 0.45, blue: 0.27)]
        case .words: [Color(red: 0.79, green: 0.55, blue: 0.37), Color(red: 0.6, green: 0.37, blue: 0.23)]
        case .speaking: [Color(red: 0.43, green: 0.6, blue: 0.52), Color(red: 0.24, green: 0.4, blue: 0.35)]
        }
        ZStack {
            PaperSurface(kind: .graph)
                .frame(width: 96)
                .rotationEffect(.degrees(3))
                .offset(x: 12, y: 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            Rectangle()
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay { PaperGrain(opacity: 1).blendMode(.overlay) }
                .overlay(alignment: .bottomLeading) { Halftone(color: .black.opacity(0.18)).frame(width: 110, height: 60) }
                .overlay(alignment: .topTrailing) {
                    InkLoops(count: 3)
                        .stroke(Color(red: 1, green: 0.94, blue: 0.86).opacity(0.55), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                        .frame(width: 70, height: 16)
                        .padding(.top, 14)
                        .padding(.trailing, 18)
                }
                .clipShape(TornEdgeShape(edges: [.bottom], depth: 5, seed: 3))
            TapeStrip(width: 62, angle: -7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: 18, y: -10)
        }
        .animation(Motion.reveal, value: tone)
    }
}

/// The big card's colour: caramel for words, olive once today's words are
/// done, moss for speaking.
enum HeroTone { case words, done, speaking }

/// The big card's face: caramel leather darkening to brown (moss for
/// speaking), with a fine grain, light pooling in one corner, a glint that
/// sweeps across now and then, and a hairline catching the light. It turns
/// olive once today's goal is met.
private struct HeroBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appStyle) private var appStyle
    var tone: HeroTone

    @ViewBuilder
    var body: some View {
        if appStyle == .collage {
            CollageHeroBackground(tone: tone)
        } else {
            leather
        }
    }

    @ViewBuilder
    private var leather: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        let colors: [Color] = switch tone {
        case .done: [Color(red: 0.6, green: 0.65, blue: 0.4), Color(red: 0.33, green: 0.42, blue: 0.25)]
        case .words: [Color(red: 0.77, green: 0.55, blue: 0.36), Color(red: 0.45, green: 0.29, blue: 0.19)]
        case .speaking: [Color(red: 0.42, green: 0.58, blue: 0.5), Color(red: 0.19, green: 0.33, blue: 0.29)]
        }
        shape
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    ZStack(alignment: .topLeading) {
                        Circle()
                            .fill(Color(red: 1, green: 0.9, blue: 0.75).opacity(0.35))
                            .frame(width: width * 0.8, height: width * 0.8)
                            .blur(radius: 40)
                            .offset(x: width * 0.45, y: -width * 0.45)
                        Circle()
                            .fill(colors[1].opacity(0.7))
                            .frame(width: width * 0.7, height: width * 0.7)
                            .blur(radius: 50)
                            .offset(x: -width * 0.3, y: proxy.size.height * 0.45)
                    }
                }
                .clipShape(shape)
            }
            .overlay { PaperGrain(opacity: 1).blendMode(.overlay).clipShape(shape) }
            .overlay {
                if !reduceMotion { HeroGlint().clipShape(shape) }
            }
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom),
                                   lineWidth: 1)
            }
            .shadow(color: colors[1].opacity(0.35), radius: 20, y: 12)
    }
}

/// A soft band of light that crosses the hero card every few seconds.
private struct HeroGlint: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            LinearGradient(colors: [.white.opacity(0), .white.opacity(0.2), .white.opacity(0)], startPoint: .leading, endPoint: .trailing)
                .frame(width: width * 0.35, height: height * 2)
                .rotationEffect(.degrees(18))
                .phaseAnimator([false, true]) { content, across in
                    content.offset(x: across ? width * 1.3 : -width * 0.6, y: -height * 0.5)
                } animation: { across in
                    across ? Animation.easeInOut(duration: 1.4).delay(4) : Animation.linear(duration: 0.01)
                }
        }
        .allowsHitTesting(false)
    }
}

/// "Start here!", bobbing on the main button until a new learner's first
/// round is done.
private struct StartHereSticker: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "hand.point.down.fill")
            Text(L.t("從這裡開始！", "Start here!"))
        }
        .font(.caption.weight(.heavy))
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Palette.miss, in: Capsule())
        .rotationEffect(.degrees(4))
        .offset(y: bob ? -3 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { bob = true }
        }
    }
}
