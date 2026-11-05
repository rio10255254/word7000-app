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

    var start: (Activity) -> Void
    /// Opens the Words tab.
    var showWords: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 6)
            banner
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 12)
            if let nudge = plus.nudge {
                PlusNudgeBanner(nudge: nudge)
                    .card(padding: 10)
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            path
            mainButton
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 12)
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
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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

    // MARK: Top

    /// The language, the streak and the words mastered; the last two open
    /// the week and the shelf.
    private var topBar: some View {
        HStack {
            languageSwitch
            Spacer(minLength: 8)
            Button { open(.week) } label: {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.75, blue: 0.3), Color(red: 0.93, green: 0.42, blue: 0.2)],
                                                        startPoint: .top, endPoint: .bottom))
                        .symbolEffect(.bounce, value: flameBounce)
                    Text("\(model.progress.streak)")
                        .contentTransition(.numericText(value: Double(model.progress.streak)))
                }
                .font(.display(.title3, weight: .heavy))
                .foregroundStyle(model.progress.streak > 0 ? Palette.ink : Palette.tertiaryLabel)
                .frame(minWidth: 64, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityLabel(L.t("連續 \(model.progress.streak) 天", "\(model.progress.streak)-day streak"))
            .accessibilityIdentifier("today-streak")
            Spacer(minLength: 8)
            Button { open(.shelf) } label: {
                HStack(spacing: 5) {
                    Image(systemName: "books.vertical.fill")
                        .foregroundStyle(Palette.known)
                    Text(model.stats.mastered.formatted())
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(model.stats.mastered)))
                }
                .font(.display(.title3, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .frame(minWidth: 64, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityLabel(L.t("已掌握 \(model.stats.mastered) 個字", "\(model.stats.mastered) words mastered"))
            .accessibilityIdentifier("today-shelf")
        }
    }

    /// Which language is being learned, switched in one tap.
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
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L.t("學習語言", "Learning language"))
        .accessibilityIdentifier("today-language")
    }

    /// The chapter being read and today's count; the book opens the shelf.
    private var banner: some View {
        let progress = model.progress
        let chapters = model.shelfChapters
        let chapter = MasteryShelf.current(chapters).map { $0 + 1 }
        let tint = model.goalDone ? Palette.known : Palette.accent
        return Button { open(.shelf) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(chapter.map { L.t("第 \($0) 章 · \(model.bankName)", "Chapter \($0) · \(model.bankName)") } ?? model.bankName)
                        .font(.subheadline.weight(.bold))
                        .opacity(0.85)
                        .lineLimit(1)
                    Text(model.goalDone
                         ? L.t("單字完成 ✓ \(progress.studiedToday) 個", "Words done ✓ \(progress.studiedToday)")
                         : L.t("今天 \(progress.studiedToday) / \(progress.dailyTarget) 個字", "Today \(progress.studiedToday) of \(progress.dailyTarget) words"))
                        .font(.display(.title2, weight: .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText(value: Double(progress.studiedToday)))
                }
                Spacer(minLength: 4)
                Image(systemName: "book.fill")
                    .font(.title3)
                    .frame(width: 46, height: 46)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.45), lineWidth: 2))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background { RaisedFill(shape: RoundedRectangle(cornerRadius: 20, style: .continuous), tint: tint) }
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityIdentifier("today-chapter")
    }

    // MARK: The path

    /// Today's stops in order: the words (the speaking stage first for a
    /// learner who wants it so), Sunday's quiz, the mock exam in the month
    /// before the exam, and the chest.
    private var nodes: [TodayNode] {
        let words: [TodayNode] = [.cards, .spell, .quiz]
        var list: [TodayNode]
        if model.homeShowsSpeaking {
            if model.settings.homeLead == .speaking { list = [.speaking] + words } else { list = words + [.speaking] }
        } else {
            list = words
        }
        if model.weeklyQuizDue { list.append(.weekly) }
        if let days = memory.daysToExam, days <= 30 { list.append(.mockExam) }
        list.append(.chest)
        return list
    }

    private func isDone(_ node: TodayNode) -> Bool {
        let routine = model.activeRoutine
        let wordsDone = model.goalDone && (routine == nil || routine?.step == .done)
        switch node {
        case .cards: return routine.map { $0.step != .flip } ?? model.goalDone
        case .spell: return wordsDone || routine?.step == .exam || routine?.step == .done
        case .quiz: return wordsDone || routine?.step == .done
        case .speaking: return model.speakingDoneToday
        case .weekly, .mockExam: return false
        case .chest: return model.goalDone && (model.speakingDoneToday || !model.homeShowsSpeaking)
        }
    }

    /// The stop to do now; nil once everything (the chest too) is done.
    private var currentNode: TodayNode? {
        nodes.first { !isDone($0) && $0 != .chest }
    }

    private var path: some View {
        let list = nodes
        let current = currentNode
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(list.enumerated()), id: \.element) { index, node in
                        if let header = sectionTitle(before: node, previous: index > 0 ? list[index - 1] : nil) {
                            sectionDivider(header)
                        }
                        nodeRow(node, index: index, current: node == current)
                            .id(node)
                    }
                }
                .padding(.vertical, 18)
                .padding(.horizontal, Metrics.gutter)
            }
            .scrollIndicators(.hidden)
            .task(id: current) {
                guard let current else { return }
                try? await Task.sleep(for: .milliseconds(250))
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) { proxy.scrollTo(current, anchor: .center) }
            }
        }
    }

    private func sectionTitle(before node: TodayNode, previous: TodayNode?) -> String? {
        if node.isWords, previous == nil || !(previous?.isWords ?? false) {
            return L.t("單字", "Words")
        }
        if node == .speaking { return speakingStageLine }
        return nil
    }

    private func sectionDivider(_ text: String) -> some View {
        HStack(spacing: 10) {
            Rectangle().fill(Palette.separator).frame(height: 2)
            Text(text)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Palette.secondaryLabel)
                .lineLimit(1)
                .fixedSize()
            Rectangle().fill(Palette.separator).frame(height: 2)
        }
        .padding(.vertical, 10)
    }

    /// Stops sway left and right like a trail.
    private static let sway: [CGFloat] = [0, -70, 0, 70]

    private func nodeRow(_ node: TodayNode, index: Int, current: Bool) -> some View {
        let x = Self.sway[index % Self.sway.count]
        return ZStack {
            VStack(spacing: 6) {
                if current {
                    Text(bubbleText(node))
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(tint(node))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.separator, lineWidth: 2))
                        .transition(.scale.combined(with: .opacity))
                }
                PathNodeButton(node: node, state: isDone(node) ? .done : current ? .now : .later, tint: tint(node)) {
                    taps += 1
                    current ? goNext() : open(node)
                }
                .overlay {
                    if model.guideStep?.tileId == node.identifier { GuideRing().transition(.opacity) }
                }
                .accessibilityLabel(isDone(node) ? L.t("\(title(node))，完成", "\(title(node)), done") : title(node))
                .accessibilityValue(model.guideStep?.tileId == node.identifier ? L.t("傻貓推薦", "Silly Cat suggests") : "")
                .accessibilityIdentifier(node.identifier)
                Text(title(node))
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(current ? Palette.ink : Palette.secondaryLabel)
                    .lineLimit(1)
            }
            .offset(x: x)
            if current {
                companion
                    .offset(x: x <= 0 ? 118 : -118, y: 14)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func tint(_ node: TodayNode) -> Color {
        switch node {
        case .speaking: Self.speakingTint
        case .weekly: Palette.chinese
        case .mockExam: Palette.review
        case .chest: Palette.review
        default: Palette.accent
        }
    }

    private func title(_ node: TodayNode) -> String {
        switch node {
        case .cards: L.t("翻卡", "Cards")
        case .spell: model.studyMode == .english ? L.t("拼字", "Spell") : L.t("寫字", "Write")
        case .quiz: L.t("考考看", "Quiz")
        case .speaking: L.t("聽・說・答", "Listen & speak")
        case .weekly: L.t("週考", "Sunday quiz")
        case .mockExam: L.t("模擬考", "Mock exam")
        case .chest: L.t("今天的份", "Today's chest")
        }
    }

    private func bubbleText(_ node: TodayNode) -> String {
        switch node {
        case .speaking: L.t("換開口了！", "Your turn to talk!")
        case .cards where model.progress.studiedToday == 0: L.t("開始！", "Start!")
        default: L.t("繼續！", "Keep going!")
        }
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

    private var mainButton: some View {
        let node = currentNode
        let tint = node.map(tint) ?? Palette.known
        return Button { goNext() } label: {
            Text(mainTitle)
                .font(.title3.weight(.heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background { RaisedFill(shape: RoundedRectangle(cornerRadius: 18, style: .continuous), tint: tint) }
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
            Spacer(minLength: 0)
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
        return ScrollView {
            VStack(spacing: 16) {
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
        }
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

    /// The cat beside the stop to do now: tap it for a line, its bubble for
    /// a chat (or the next thing to try, for a new learner).
    private var companion: some View {
        StrollingCompanion(mood: mascotMood, size: 78, lines: mascotLines,
                           greeting: guideTip?.text ?? insightHeadline ?? mascotGreeting,
                           tip: guideTip ?? mascotTip ?? MascotTip(text: L.t("有問題就問我。", "Ask me anything.")) { mascotChatOpen = true },
                           hop: greetingHops + taps, range: 0, pause: taps)
            .accessibilityIdentifier("today-mascot")
    }

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

    /// Speaking's colour, on the path and in its screens.
    static let speakingTint = Color(red: 0.27, green: 0.47, blue: 0.41)
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
