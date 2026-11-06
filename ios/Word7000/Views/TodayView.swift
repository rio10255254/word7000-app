import SwiftUI
import Word7000Core

/// One stop on today's path.
enum TodayNode: String, Identifiable, Hashable {
    case cards, spell, quiz, speaking, weekly, mockExam, chest
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cards: "rectangle.on.rectangle.angled"
        case .spell: "pencil.line"
        case .quiz: "checklist"
        case .speaking: "mic.fill"
        case .weekly: "trophy.fill"
        case .mockExam: "timer"
        case .chest: "gift.fill"
        }
    }

    /// The UI tests' name for it.
    var identifier: String {
        switch self {
        case .cards: "today-node-cards"
        case .spell: "today-spelling"
        case .quiz: "today-quiz"
        case .speaking: "today-speaking"
        case .weekly: "today-weekly-quiz"
        case .mockExam: "today-exam"
        case .chest: "today-chest"
        }
    }

    var isWords: Bool { self == .cards || self == .spell || self == .quiz }
}

/// The sheets that open from the top of Today.
private enum TodaySheet: String, Identifiable {
    case week, shelf
    var id: String { rawValue }
}

/// WordCat Next: today as one path and one button, the way Duolingo and Epop
/// keep their home to the next step. Along the top, only the language, the
/// streak and the words mastered (each opens a sheet with the rest); under
/// it the chapter and today's count; then the path: cards, spelling, quiz,
/// speaking and today's chest, done ones gold, the one to do now big with
/// the cat beside it. The button at the bottom always does the next thing;
/// any stop on the path can also be tapped to go there.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(PlusModel.self) private var plus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var studySettingsOpen = false
    /// The meaning quiz's few settings, in a half-height sheet before it starts.
    @State private var quizSetupOpen = false
    @State private var quizQueued = false
    @State private var flameBounce = 0
    @State private var greetingHops = 0
    @State private var catLines = CatLineSource.none
    @MainActor private static var showcasedChat = false
    @State private var insightHeadline: String?
    @State private var mascotChatOpen = false
    @State private var focusPractice: [String]?
    @State private var memory = CatMemory.shared
    @State private var sheet: TodaySheet?
    /// What to open once a sheet has closed.
    @State private var afterSheet: (() -> Void)?
    @State private var taps = 0
    /// The card's width: how far the cat can stroll.
    @State private var cardWidth: CGFloat = 0

    var start: (Activity) -> Void
    /// Opens the Words tab.
    var showWords: () -> Void = {}

    var body: some View {
        GeometryReader { proxy in
            let fits = proxy.size.height > 640 && !dynamicTypeSize.isAccessibilitySize
            ViewThatFits(in: .vertical) {
                page(roomy: fits)
                    .frame(maxHeight: .infinity, alignment: .top)
                ScrollView { page(roomy: false) }
                    .scrollIndicators(.hidden)
            }
        }
        .background { AmbientBackground(tint: currentNode == .speaking ? Self.speakingTint : model.goalDone ? Palette.known : Palette.accent) }
        .animation(reduceMotion ? nil : Motion.reveal, value: plus.nudge)
        .animation(reduceMotion ? nil : Motion.reveal, value: currentNode)
        .task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !reduceMotion else { return }
            if model.progress.streak > 0 { flameBounce += 1 }
            greetingHops += 1
        }
        .onChange(of: model.progress.streak) { old, new in
            if new > old, !reduceMotion { flameBounce += 1 }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: taps) { _, _ in model.settings.hapticsEnabled ?? true }
        .sheet(item: $sheet, onDismiss: {
            let next = afterSheet
            afterSheet = nil
            next?()
        }) { which in
            Group {
                switch which {
                case .week: weekSheet
                case .shelf: shelfSheet
                }
            }
            .fittedSheet()
        }
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
            await CatLinePackStore.refreshIfNeeded(model)
            catLines = model.catLines
        }
        .onChange(of: model.progress.studiedToday) { _, _ in catLines = model.catLines }
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

    // MARK: The page

    /// Epop keeps the home to one thing: the greeting, one big card for the
    /// step to do now, and at most one note. Everything else is a tap away.
    private func page(roomy: Bool) -> some View {
        // Roomier now the language switch has left the header: the card sits a
        // little lower instead of leaving the bottom of a tall phone empty.
        VStack(alignment: .leading, spacing: roomy ? 24 : 12) {
            header
            focusCard(roomy: roomy)
            if let nudge = plus.nudge {
                PlusNudgeBanner(nudge: nudge)
                    .card(padding: 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            note
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    // MARK: Header

    /// The greeting and the days to the exam (or the date); the streak and
    /// the words mastered as two small pills.
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            // The language is chosen in Settings: it is not an everyday switch.
            Text(greeting)
                .font(.display(.title, weight: .bold))
                .lineLimit(1)
            HStack(spacing: 8) {
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(memory.daysToExam == nil ? Palette.secondaryLabel : Palette.accent)
                .lineLimit(1)
                Spacer(minLength: 4)
                chip(id: "today-streak", label: L.t("連續 \(model.progress.streak) 天", "\(model.progress.streak)-day streak"), action: { open(.week) }) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.75, blue: 0.3), Color(red: 0.93, green: 0.42, blue: 0.2)],
                                                        startPoint: .top, endPoint: .bottom))
                        .symbolEffect(.bounce, value: flameBounce)
                    Text("\(model.progress.streak)")
                }
                chip(id: "today-shelf", label: L.t("已掌握 \(model.stats.mastered) 個字", "\(model.stats.mastered) words mastered"), action: { open(.shelf) }) {
                    Image(systemName: "books.vertical.fill").foregroundStyle(Palette.known)
                    Text(model.stats.mastered.formatted()).monospacedDigit()
                }
            }
        }
        .zIndex(1)
    }

    private func chip<Content: View>(id: String, label: String, action: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
        Button(action: action) {
            HStack(spacing: 4) { content() }
                .font(.display(.headline, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 12)
                .frame(minHeight: 38)
                .background {
                    // A pill in either style: square boxes looked stiff in the collage.
                    Capsule().fill(Palette.surface)
                        .overlay { PaperGrain(opacity: 0.4).clipShape(Capsule()) }
                        .overlay { Capsule().strokeBorder(Collage.ink.opacity(0.14), lineWidth: 1) }
                        .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(id)
    }

    // MARK: Today's steps

    /// The steps of the day, as stamps on the card.
    private var nodes: [TodayNode] {
        let words: [TodayNode] = [.cards, .spell, .quiz]
        guard model.homeShowsSpeaking else { return words }
        return model.settings.homeLead == .speaking ? [.speaking] + words : words + [.speaking]
    }

    private func isDone(_ node: TodayNode) -> Bool {
        let routine = model.activeRoutine
        let wordsDone = model.goalDone && (routine == nil || routine?.step == .done)
        switch node {
        case .cards: return routine.map { $0.step != .flip } ?? model.goalDone
        case .spell: return wordsDone || routine?.step == .exam || routine?.step == .done
        case .quiz: return wordsDone || routine?.step == .done
        case .speaking: return model.speakingDoneToday
        case .weekly, .mockExam, .chest: return false
        }
    }

    /// The step to do now; nil once all are done.
    private var currentNode: TodayNode? {
        nodes.first { !isDone($0) }
    }

    // MARK: The focus card

    /// One big card for the step to do now, on master's leather: what it
    /// is, today's count, the day's steps as stamps (gold once done) and
    /// the button. The cat stands on its top edge.
    private func focusCard(roomy: Bool) -> some View {
        let node = currentNode
        let tone: HeroTone = node == .speaking ? .speaking : node == nil ? .done : .words
        let card = VStack(spacing: roomy ? 18 : 12) {
            Text(focusKicker(node))
                .font(.display(.subheadline, weight: .bold))
                .foregroundStyle(Self.cream.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
            focusEmblem(node, size: roomy ? 132 : 104)
            VStack(spacing: 6) {
                Text(focusTitle(node))
                    .font(.display(roomy ? .largeTitle : .title, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(focusDetail(node))
                    .font(.headline)
                    .opacity(0.85)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .foregroundStyle(Self.cream)
            stamps
            mainButton(roomy: roomy)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity)
        .background { HeroBackground(tone: tone) }
        return standing(card)
            .animation(reduceMotion ? nil : Motion.reveal, value: node)
    }

    private func focusKicker(_ node: TodayNode?) -> String {
        switch node {
        case .speaking: return L.t("今天的口說", "Today's speaking")
        case nil: return L.t("今天的份", "Today")
        default:
            let chapter = MasteryShelf.current(model.shelfChapters).map { $0 + 1 }
            return chapter.map { L.t("今天的單字 · 第 \($0) 章", "Today's words · chapter \($0)") } ?? L.t("今天的單字", "Today's words")
        }
    }

    private func focusTitle(_ node: TodayNode?) -> String {
        switch node {
        case .cards: return L.t("翻卡", "Flip the cards")
        case .spell: return model.studyMode == .english ? L.t("拼字", "Spell them") : L.t("寫字", "Write them")
        case .quiz: return L.t("考考看", "Quiz time")
        case .speaking: return speakingStage.number.map { L.t("第 \($0) 關・\(speakingStage.title)", "Stage \($0) · \(speakingStage.title)") } ?? speakingStage.title
        case nil: return L.t("今天的份完成！", "All done today!")
        default: return ""
        }
    }

    private func focusDetail(_ node: TodayNode?) -> String {
        let plan = model.studyPlan
        let routine = model.activeRoutine
        switch node {
        case .cards: return model.routineHeroLine ?? L.todayPlan(due: plan.review, fresh: plan.fresh)
        case .spell:
            let left = routine?.spellLeft.count ?? 0
            return left > 0 ? L.t("剛學的 \(left) 個字，寫給貓看", "\(left) new words. Spell them for the cat") : L.t("剛學的字，寫給貓看", "Spell the new words for the cat")
        case .quiz:
            let left = routine?.examLeft.count ?? 0
            return left > 0 ? L.t("學測題型 \(left) 題", "\(left) exam-style questions") : L.t("學測題型", "Exam style")
        case .speaking: return L.t("聽、跟讀、回答、用今天的字", "Listen, repeat, answer, use a word")
        case nil: return L.t("單字 \(model.progress.studiedToday) 個・想加碼就再一組", "\(model.progress.studiedToday) words. One more set?")
        default: return ""
        }
    }

    /// The step's sign in an embossed disc, with today's count as a ring.
    private func focusEmblem(_ node: TodayNode?, size: CGFloat) -> some View {
        let fraction = node == .speaking ? (model.speakingDoneToday ? 1 : 0) : model.dailyFraction
        return ZStack {
            Circle().fill(Color.black.opacity(0.14)).offset(y: 4)
            Circle().fill(Self.cream.opacity(0.14))
            Circle().strokeBorder(Self.cream.opacity(0.35), lineWidth: 1.5).padding(10)
            ProgressRing(fraction: fraction, color: Self.cream, lineWidth: size * 0.075, track: Self.cream.opacity(0.18)) { EmptyView() }
            Image(systemName: node?.icon ?? "checkmark.seal.fill")
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(Self.cream)
                .symbolEffect(.bounce, value: greetingHops)
            if node?.isWords == true {
                Text("\(model.progress.studiedToday)/\(model.progress.dailyTarget)")
                    .font(.display(.caption, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Self.cream)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.22), in: Capsule())
                    .offset(y: size * 0.36)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.t("今天 \(model.progress.studiedToday) / \(model.progress.dailyTarget) 個字", "\(model.progress.studiedToday) of \(model.progress.dailyTarget) words today"))
    }

    /// The day's steps pressed into the leather; done ones get a gold stamp.
    private var stamps: some View {
        let current = currentNode
        return HStack(alignment: .top, spacing: 6) {
            ForEach(nodes) { node in
                let done = isDone(node)
                let now = node == current
                Button {
                    taps += 1
                    now ? goNext() : open(node)
                } label: {
                    VStack(spacing: 5) {
                        ZStack {
                            if done {
                                Circle().fill(LinearGradient(colors: [Color(red: 0.98, green: 0.84, blue: 0.5), Color(red: 0.82, green: 0.6, blue: 0.24)],
                                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                                Circle().strokeBorder(Color.white.opacity(0.45), lineWidth: 1.5).padding(3)
                                Image(systemName: "checkmark").font(.system(size: 17, weight: .heavy)).foregroundStyle(Color(red: 0.42, green: 0.27, blue: 0.1))
                            } else if now {
                                Circle().fill(Self.cream)
                                Image(systemName: node.icon).font(.system(size: 17, weight: .bold)).foregroundStyle(Self.deep)
                            } else {
                                // Pressed into the leather.
                                Circle().fill(Color.black.opacity(0.16))
                                Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1).offset(y: 1)
                                Image(systemName: node.icon).font(.system(size: 16, weight: .bold)).foregroundStyle(Self.cream.opacity(0.6))
                            }
                        }
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(done ? -10 : 0))
                        .scaleEffect(now && !reduceMotion ? 1.08 : 1)
                        Text(title(node))
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(Self.cream.opacity(now ? 1 : 0.75))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftPressStyle())
                .overlay {
                    if model.guideStep?.tileId == node.identifier { GuideRing().transition(.opacity) }
                }
                .accessibilityLabel(done ? L.t("\(title(node))，完成", "\(title(node)), done") : title(node))
                .accessibilityValue(model.guideStep?.tileId == node.identifier ? L.t("傻貓推薦", "Silly Cat suggests") : "")
                .accessibilityIdentifier(node.identifier)
            }
        }
    }

    /// The card with the cat on its top edge, strolling along it now and then.
    private func standing<Card: View>(_ card: Card) -> some View {
        card
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { cardWidth = proxy.size.width }
                        .onChange(of: proxy.size.width) { _, width in cardWidth = width }
                }
            }
            .overlay(alignment: .topTrailing) {
                if !dynamicTypeSize.isAccessibilitySize {
                    StrollingCompanion(mood: mascotMood, size: 70, lines: mascotLines,
                                       greeting: guideTip?.text ?? insightHeadline ?? mascotGreeting,
                                       tip: guideTip ?? mascotTip ?? MascotTip(text: L.t("有問題就問我。", "Ask me anything.")) { mascotChatOpen = true },
                                       hop: greetingHops + taps, range: max(0, cardWidth - 100), pause: taps,
                                       onTap: { mascotChatOpen = true })
                        .offset(x: -14, y: -54)
                        .accessibilityIdentifier("today-mascot")
                }
            }
            .padding(.top, dynamicTypeSize.isAccessibilitySize ? 0 : 44)
    }

    // MARK: The note

    /// At most one note under the card, only when it applies: Sunday's quiz,
    /// the mock exam in the month before the exam, or words still shaky.
    @ViewBuilder
    private var note: some View {
        if model.weeklyQuizDue {
            noteSlip(id: "today-weekly-quiz", icon: "trophy.fill", tint: Palette.chinese, paper: .mustard,
                     title: L.t("週日週考", "Sunday quiz"), detail: L.t("這週學過的字，最多 \(ExamRound.weeklyCount) 題", "This week's words, up to \(ExamRound.weeklyCount)")) {
                start(.weeklyExam)
            }
        } else if let days = memory.daysToExam, days <= 30 {
            noteSlip(id: "today-exam", icon: "timer", tint: Palette.review, paper: .peach,
                     title: L.t("離考試 \(days) 天", "\(days) days to the exam"), detail: L.t("來一場完整模擬考", "Take a full mock exam")) {
                start(.exam)
            }
        } else if model.stats.review > 0 {
            noteSlip(id: "today-review", icon: "arrow.counterclockwise", tint: Palette.miss, paper: .ruled,
                     title: L.t("錯題本", "Missed words"), detail: L.t("\(model.stats.review) 個還不熟的字", "\(model.stats.review) still shaky")) {
                model.startStudySession(onlyIds: model.reviewWordIds)
                start(.study)
            }
        }
    }

    private func noteSlip(id: String, icon: String, tint: Color, paper: PaperKind, title: String, detail: String,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(tint, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.display(.title3, weight: .bold)).foregroundStyle(Palette.ink)
                    Text(detail).font(.subheadline).foregroundStyle(Palette.secondaryLabel).lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.headline).foregroundStyle(tint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background { NoteSlipBackground(paper: paper) }
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityIdentifier(id)
    }

    // MARK: The button

    private var mainTitle: String {
        guard let node = currentNode else { return L.extraAction }
        let routine = model.activeRoutine
        switch node {
        case .cards: return model.progress.studiedToday > 0 || (model.studySession?.index ?? 0) > 0 ? L.t("繼續翻卡", "Keep flipping") : L.t("開始翻卡", "Start the cards")
        case .spell: return routine?.step == .spell ? L.t("繼續拼字", "Continue spelling") : L.t("開始拼字", "Start spelling")
        case .quiz: return L.t("繼續考考看", "Continue the quiz")
        case .speaking: return speakingStage.number.map { L.t("開始第 \($0) 關", "Start stage \($0)") } ?? L.t("開始口說", "Start speaking")
        case .weekly: return L.t("開始週考", "Start the Sunday quiz")
        case .mockExam: return L.t("開始模擬考", "Start the mock exam")
        case .chest: return L.extraAction
        }
    }

    private func mainButton(roomy: Bool) -> some View {
        let node = currentNode
        return Button { goNext() } label: {
            HStack(spacing: 8) {
                Text(mainTitle)
                Image(systemName: "arrow.right").symbolEffect(.bounce, value: greetingHops)
            }
            .font(.title3.weight(.heavy))
            .foregroundStyle(node == .speaking ? Self.speakingDeep : node == nil ? Self.doneDeep : Self.deep)
            .frame(maxWidth: .infinity)
            .padding(.vertical, roomy ? 17 : 14)
            .background(Self.cream, in: Capsule())
            .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
        }
        .buttonStyle(SoftPressStyle())
        .disabled(node?.isWords == true && model.studyPlan.total == 0 && !model.routinePending)
        .overlay(alignment: .topTrailing) {
            if model.settings.guideActive == true, model.progress.lastStudyDate == nil, !AppRuntime.catShowcase {
                StartHereSticker().offset(x: -8, y: -16)
            }
        }
        .accessibilityIdentifier("today-start")
    }

    /// The button: the next stop, or another set once all are done.
    private func goNext() {
        guard let node = currentNode else {
            model.ensureStudySession()
            start(.study)
            return
        }
        switch node {
        case .cards, .spell, .quiz:
            model.ensureStudySession()
            start(.study)
        case .speaking: start(.speaking)
        case .weekly: start(.weeklyExam)
        case .mockExam: start(.exam)
        case .chest: break
        }
    }

    /// A stop tapped out of turn: a round of its own.
    private func open(_ node: TodayNode) {
        switch node {
        case .cards:
            model.ensureStudySession()
            start(.study)
        case .spell: start(model.studyMode == .english ? .cloze : .spelling)
        case .quiz:
            if model.studyMode == .english { start(.quickExam) } else { quizSetupOpen = true }
        case .speaking: start(.speaking)
        case .weekly: start(.weeklyExam)
        case .mockExam: start(.exam)
        case .chest: if isDone(.chest) { open(.week) }
        }
    }

    private func open(_ which: TodaySheet) {
        taps += 1
        sheet = which
    }

    /// Closes the sheet, then does `action`.
    private func afterClosing(_ action: @escaping () -> Void) {
        afterSheet = action
        sheet = nil
    }

    // MARK: Speaking

    private var speakingStage: (number: Int?, title: String) {
        if model.settings.speakingWordsTab == true, !model.speakingDoneToday {
            return (nil, L.t("單字口說", "Word practice"))
        }
        guard let next = SpeakingScenarios.next(after: model.speakingPath), let scenario = SpeakingScenarios.scenario(next) else {
            return (nil, L.t("開口說說看", "Say it out loud"))
        }
        return (SpeakingScenarios.number(next), L.t(scenario.title.zh, scenario.title.en))
    }

    private var speakingStageLine: String {
        let stage = speakingStage
        guard let number = stage.number else { return L.t("口說・\(stage.title)", "Speaking · \(stage.title)") }
        return L.t("口說・第 \(number) 關 \(stage.title)", "Speaking · stage \(number) \(stage.title)")
    }

    // MARK: Sheets

    private var weekSheet: some View {
        VStack(spacing: 18) {
            Text(L.t("🔥 連續 \(model.progress.streak) 天", "🔥 \(model.progress.streak)-day streak"))
                .font(.display(.title2, weight: .heavy))
                .padding(.top, 24)
            HStack(spacing: 8) {
                ForEach(Array(model.weekStamps.enumerated()), id: \.offset) { index, stamp in
                    DayStamp(mark: stamp.mark, weekday: WeekStamps.label(index), size: 40)
                }
            }
            .accessibilityIdentifier("today-week")
            HStack(spacing: 10) {
                CatCan(full: model.catCanReady, size: 34)
                Text(canLine)
                    .font(.headline)
                    .foregroundStyle(Palette.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)
            Button { sheet = nil } label: {
                Text(L.t("知道了", "Got it")).font(.title3.weight(.bold)).frame(maxWidth: .infinity)
            }
            .prominentAction()
            .padding(.bottom, 12)
        }
        .padding(.horizontal, Metrics.gutter)
        .background { Palette.background.ignoresSafeArea() }
    }

    private var canLine: String {
        if model.streakProtectionJustUsed {
            return L.t("貓罐頭剛幫你保住了紀錄，今天學 1 個字就能延續。", "The cat's can just saved your streak. One word today keeps it going.")
        }
        if model.catCanReady {
            return L.t("貓罐頭在你這：漏學 1 天，牠幫你保住紀錄。", "The cat's can is ready: one missed day is covered.")
        }
        guard let ready = model.streakProtectionReadyOn else { return "" }
        let parts = ready.split(separator: "-").compactMap { Int($0) }
        let date = parts.count == 3 ? "\(parts[1])/\(parts[2])" : ready
        return L.t("貓罐頭 \(date) 回來，這幾天別漏掉。", "The cat's can is back on \(date). Don't miss a day till then.")
    }

    private var shelfSheet: some View {
        let chapters = model.shelfChapters
        let mastered = chapters.reduce(0) { $0 + $1.mastered }
        let total = chapters.reduce(0) { $0 + $1.total }
        let current = MasteryShelf.current(chapters)
        return VStack(spacing: 16) {
                Text(L.t("已掌握 \(mastered.formatted()) / \(total.formatted())", "\(mastered.formatted()) of \(total.formatted()) mastered"))
                    .font(.display(.title2, weight: .heavy))
                    .padding(.top, 24)
                Shelf(chapters: chapters, current: current, height: 64, bookWidth: 16)
                if let current {
                    Text(L.t("正在讀第 \(current + 1) 章", "Reading chapter \(current + 1)"))
                        .font(.headline)
                        .foregroundStyle(Palette.secondaryLabel)
                }
                VStack(spacing: 10) {
                    Menu {
                        Picker(L.dailyTargetTitle, selection: Binding(get: { model.progress.dailyTarget }, set: { model.setDailyTarget($0) })) {
                            ForEach([10, 20, 30, 50], id: \.self) { Text(L.t("每天 \($0) 個", "\($0) a day")).tag($0) }
                        }
                    } label: {
                        sheetRow(L.dailyTargetTitle, value: L.t("\(model.progress.dailyTarget) 個", "\(model.progress.dailyTarget)"))
                    }
                    .accessibilityIdentifier("today-goal")
                    Button { afterClosing { studySettingsOpen = true } } label: {
                        sheetRow(L.t("字庫", "Word bank"), value: model.bankName)
                    }
                    .accessibilityIdentifier("today-study-filter")
                    Button { afterClosing { showWords() } } label: {
                        sheetRow(L.t("單字本", "All words"), value: L.t("搜尋、收藏、拍講義", "Search, saved, scan"))
                    }
                    .accessibilityIdentifier("today-words")
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 24)
            .background { Palette.background.ignoresSafeArea() }
    }

    private func sheetRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).font(.headline).foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            Text(value).font(.headline).foregroundStyle(Palette.accent).lineLimit(1).minimumScaleFactor(0.8)
            Image(systemName: "chevron.right").font(.subheadline.weight(.bold)).foregroundStyle(Palette.accent)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
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

    private func title(_ node: TodayNode) -> String {
        switch node {
        case .cards: L.t("翻卡", "Cards")
        case .spell: model.studyMode == .english ? L.t("拼字", "Spell") : L.t("寫字", "Write")
        case .quiz: L.t("考考看", "Quiz")
        case .speaking: L.t("口說", "Speak")
        case .weekly: L.t("週考", "Sunday quiz")
        case .mockExam: L.t("模擬考", "Mock exam")
        case .chest: L.t("今天的份", "Today")
        }
    }

    /// Speaking's colour, on the card and in its screens.
    static let speakingTint = Color(red: 0.27, green: 0.47, blue: 0.41)
    private static let deep = Color(red: 0.45, green: 0.27, blue: 0.16)
    private static let doneDeep = Color(red: 0.3, green: 0.38, blue: 0.22)
    private static let speakingDeep = Color(red: 0.16, green: 0.3, blue: 0.27)
    /// Text and the button on the leather card.
    static let cream = Color(red: 1.0, green: 0.97, blue: 0.91)
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
    /// A tap opens the chat with the cat.
    var onTap: (() -> Void)? = nil

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
                    pace: pace, cue: cue, onFling: fling, onBeatenUp: stormOff, onTap: onTap)
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
struct HeroBackground: View {
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

/// A note under the focus card: a strip of paper torn along its bottom,
/// taped on, in the collage; a soft card otherwise.
private struct NoteSlipBackground: View {
    @Environment(\.appStyle) private var appStyle
    var paper: PaperKind

    var body: some View {
        if appStyle == .collage {
            PaperSurface(kind: paper)
                .clipShape(TornEdgeShape(edges: [.bottom], depth: 4, seed: 7))
                .overlay(alignment: .top) { TapeStrip(width: 54, angle: -4).offset(y: -9) }
                .rotationEffect(.degrees(-0.6))
        } else {
            PremiumSurface(radius: 20)
        }
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
