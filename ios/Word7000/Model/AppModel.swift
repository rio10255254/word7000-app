import Foundation
import Observation
import SwiftUI
import Word7000Core

/// The single source of truth for the app: the word lists, the learner's
/// progress and the current study session. Views read it from the
/// environment and call its methods; every change is saved in the background.
@MainActor
@Observable
final class AppModel {
    /// The 7000 English words learners of English study, with the
    /// developer's published corrections (see `RemoteContent`).
    private(set) var englishCoreWords: [WordEntry]
    /// Everyday Taiwan Mandarin, in TOCFL-style bands, for learners of
    /// Chinese (`words-zh.json`), corrected the same way.
    private(set) var chineseCoreWords: [WordEntry]
    @ObservationIgnored private let bundledEnglishWords: [WordEntry]
    @ObservationIgnored private let bundledChineseWords: [WordEntry]
    /// Corrections and official banks published without an app update.
    private(set) var remoteContent = RemoteContent.empty
    @ObservationIgnored private var officialBanksByMode: [String: [OfficialBank]] = [:]
    private var contentRevision = 0
    /// The built-in words for the current study mode.
    var coreWords: [WordEntry] {
        studyMode == .chinese && !chineseCoreWords.isEmpty ? chineseCoreWords : englishCoreWords
    }
    private(set) var progress: ProgressState {
        didSet {
            libraryRevision &+= 1
            // Undo restores a whole snapshot, so any other change since (a quiz
            // answer, a favourite, the daily goal) would be rolled back with it.
            if !gradingStudyCard { studyUndoStack = [] }
            if !replacing { onDataChange?(SyncDirty(progress: true)) }
        }
    }
    private(set) var customSets: CustomSetState {
        didSet {
            preparedCache = nil
            mergedWordsCache = nil
            vocabularyCache = nil
            libraryRevision &+= 1
            if !replacing { onDataChange?(SyncDirty(customSets: true)) }
        }
    }
    /// Told about every local change so it can be synced.
    @ObservationIgnored var onDataChange: ((SyncDirty) -> Void)?
    @ObservationIgnored private var replacing = false
    @ObservationIgnored private var gradingStudyCard = false
    var settings: AppSettings {
        didSet {
            L.mode = settings.studyMode ?? .english
            scheduleSave()
        }
    }
    private(set) var today: String

    // Study session state survives switching tabs.
    private(set) var studySession: StudySession?
    /// The day the current set was built: a set left half done last night is
    /// replaced by today's (with today's reviews and checks), not carried on.
    private(set) var studySessionDay: String?
    /// WordCat Next: whether the current set is the day's own (built from the
    /// schedule), not a chosen list such as the missed words.
    private var studySessionIsDaySet = false
    /// Today's set, put aside unfinished while a round of missed words (or
    /// another chosen list) runs, and taken back when Today starts the
    /// cards again: a detour does not throw away the day's place or checks.
    private var parkedDaySet: (session: StudySession, routine: WordRoutine?, day: String)?
    /// WordCat Next: the flip cards of a "today's words" session followed by
    /// spot checks. See `activeRoutine` for the one that belongs to the
    /// current session.
    private(set) var wordRoutine: WordRoutine?
    @ObservationIgnored private var examPoolCache: (key: String, pool: ExamPool)?
    private(set) var storageFailed = false
    private(set) var libraryRevision = 0
    private(set) var deletedSetUndo: CustomVocabSet?
    private var studyUndoStack: [(progress: ProgressState, session: StudySession)] = []
    var canUndoStudy: Bool { !studyUndoStack.isEmpty }

    /// The other study mode's words, as stored (see `ModeProgress`):
    /// `progress` holds only the current mode's.
    @ObservationIgnored private var otherModeWords: [String: WordProgress] = [:]

    /// Both modes' progress in one record, as it is saved and synced.
    var syncedProgress: ProgressState {
        ModeProgress.store(progress, chinese: studyMode == .chinese, otherWords: otherModeWords)
    }

    @ObservationIgnored private let persistence: Persistence
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var preparedCache: (key: String, vocabulary: PreparedVocabulary)?
    @ObservationIgnored private var mergedWordsCache: [WordEntry]?
    @ObservationIgnored private var vocabularyCache: [WordEntry]?

    init(coreWords: [WordEntry], chineseWords: [WordEntry] = [], progress: ProgressState, customSets: CustomSetState, settings: AppSettings, persistence: Persistence, today: String = DayMath.today()) {
        var settings = settings
        settings.migrateSpeakingHistory()
        self.englishCoreWords = coreWords
        self.chineseCoreWords = chineseWords
        self.bundledEnglishWords = coreWords
        self.bundledChineseWords = chineseWords
        let normalized = LearningEngine.normalizeForDate(progress, today: today)
        let chinese = settings.studyMode == .chinese
        self.progress = ModeProgress.view(normalized, chinese: chinese)
        otherModeWords = ModeProgress.storedWords(of: normalized, excluding: chinese)
        self.customSets = customSets
        savedLearning = (normalized, customSets)
        self.settings = settings
        L.mode = settings.studyMode ?? .english
        self.persistence = persistence
        self.today = today
    }

    /// Whether this learner's progress and banks are saved. Guests' are not
    /// (signing in with Apple keeps them); set by the account. Without an
    /// account service (UI tests, local builds) everything is saved.
    @ObservationIgnored var keepsLearningRecords = true {
        didSet { if keepsLearningRecords != oldValue { scheduleSave() } }
    }
    /// What is on disk: for a guest it stays as it was when they became one,
    /// so what they study now is not kept.
    @ObservationIgnored private var savedLearning: (progress: ProgressState, customSets: CustomSetState)

    static func launch() -> AppModel {
        let persistence = Persistence.live
        let words = loadBundledWords()
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestingReset") {
            try? FileManager.default.removeItem(at: persistence.directory)
        }
        let snapshot = persistence.load(AppSnapshot.self, from: "snapshot.json")
        var settings = snapshot?.settings ?? persistence.load(AppSettings.self, from: "settings.json") ?? AppSettings()
        var progress = snapshot?.progress ?? persistence.load(ProgressState.self, from: "progress.json") ?? .empty
        var sets = snapshot?.customSets ?? persistence.load(CustomSetState.self, from: "custom-sets.json") ?? .empty

        if !settings.migratedLegacyData {
            if let legacy = LegacyImport.load() {
                progress = LearningEngine.merge([progress, legacy.progress])
                sets = CustomSetState.merge([sets, legacy.customSets])
                if let bank = legacy.activeBankId { settings.activeBankId = bank }
                if let theme = legacy.theme { settings.theme = theme }
                // Keep the old device id: it is the per-device key in the
                // activity counters and for lock screen reminders.
                if let deviceId = legacy.deviceId { settings.deviceSourceId = deviceId }
                settings.streakReminder = legacy.streakReminder
                settings.studyMode = legacy.studyMode
                if let filters = legacy.filters {
                    settings.studyFilter = filters.study
                    settings.quizFilter = filters.quiz
                    settings.libraryFilter = filters.library
                    if let count = filters.questionCount, QuizBuilder.questionCounts.contains(count) {
                        settings.quizQuestionCount = count
                    }
                }
            }
            settings.migratedLegacyData = true
        }
        // Learning English and learning Chinese now keep their own progress;
        // someone already learning Chinese keeps what they had there too.
        if settings.splitModeProgress != true {
            if settings.studyMode == .chinese { progress = ModeProgress.seedChinese(progress) }
            settings.splitModeProgress = true
        }
        if arguments.contains("-uiTestingSampleProgress") {
            progress = SampleData.progress(words: words, today: DayMath.today())
            // The routine's exam questions need older words that are due.
            if arguments.contains("-uiTestingRoutine") {
                progress = SampleData.olderWordsDue(progress, words: words, today: DayMath.today())
            }
        }
        if arguments.contains("-uiTestingHistoryData") {
            var analytics = LearningAnalyticsState()
            for back in 0..<90 {
                guard let date = DayMath.addDays(DayMath.today(), -back) else { continue }
                analytics.record(date: date, source: settings.deviceSourceId) { counters in
                    counters.studyKnown = (back * 7 + 9) % 24
                    counters.studyReview = back % 4
                    counters.quizCorrect = back % 3
                    counters.quizWrong = back % 2
                    counters.speakingCompleted = (back * 3 + 2) % 6
                    counters.otherActions = back % 3
                }
            }
            progress.analytics = analytics
        }
        if arguments.contains("-uiTestingDark") { settings.theme = .dark }
        if arguments.contains("-uiTestingChineseMode") {
            settings.studyMode = .chinese
            // Sample progress on the Chinese side too, over the Taiwan Mandarin words.
            if arguments.contains("-uiTestingSampleProgress") {
                let taiwan = loadBundledWords(named: "words-zh")
                let sample = SampleData.progress(words: taiwan.isEmpty ? words : taiwan, today: DayMath.today())
                for (id, entry) in sample.words { progress.words[ModeProgress.chinesePrefix + id] = entry }
            }
        }
        if arguments.contains("-uiTestingLight") { settings.theme = .light }
        if arguments.contains("-uiTestingCollage") { settings.appStyle = .collage }
        // UI tests see the default look, the paper collage, unless they ask
        // for leather.
        if arguments.contains("-uiTestingLeather") { settings.appStyle = .leather }
        // UI tests never meet the one-time style chooser unless they ask for it.
        if arguments.contains("-uiTestingReset"), !arguments.contains("-uiTestingStyleChooser") { settings.stylePicked = true }
        if settings.onboardingComplete == nil {
            settings.onboardingComplete = snapshot != nil || !progress.words.isEmpty || !sets.sets.isEmpty
        }
        if arguments.contains("-uiTestingReset"), !arguments.contains("-uiTestingOnboarding") {
            settings.onboardingComplete = true
        }

        let model = AppModel(coreWords: words, chineseWords: loadBundledWords(named: "words-zh"), progress: progress, customSets: sets,
                             settings: settings, persistence: persistence)
        if snapshot?.sessionDay == model.today, let saved = snapshot?.studySession {
            model.restoreStudySession(saved)
            model.wordRoutine = snapshot?.wordRoutine
            model.studySessionDay = model.today
            model.studySessionIsDaySet = snapshot?.wordRoutine != nil
        }
        if let cached = persistence.load(RemoteContent.self, from: "remote-content.json"), !AppRuntime.uiTesting {
            model.applyRemoteContent(cached)
        }
        #if DEBUG
        if arguments.contains("-uiTestingOfficialBank") { model.applyRemoteContent(SampleData.officialContent) }
        #endif
        model.saveNow()
        return model
    }

    /// Keeps published word list content for the next launch and offline use.
    func saveRemoteContent() {
        _ = persistence.save(remoteContent, to: "remote-content.json")
    }

    static func loadBundledWords(named name: String = "words") -> [WordEntry] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? WordData.decode(data)
        else { return [] }
        return words
    }

    /// Applies word list content the developer published: corrected built-in
    /// words and official banks. Progress is keyed by word id, so nothing a
    /// learner has done is lost; a bank taken down falls back to the built-in words.
    func applyRemoteContent(_ content: RemoteContent) {
        guard content != remoteContent else { return }
        remoteContent = content
        englishCoreWords = content.corrected(bundledEnglishWords, mode: StudyMode.english.rawValue)
        chineseCoreWords = content.corrected(bundledChineseWords, mode: StudyMode.chinese.rawValue)
        officialBanksByMode = Dictionary(uniqueKeysWithValues: StudyMode.allCases.map { ($0.rawValue, content.banks(for: $0.rawValue)) })
        preparedCache = nil
        mergedWordsCache = nil
        vocabularyCache = nil
        contentRevision &+= 1
        libraryRevision &+= 1
        if settings.activeBankId.hasPrefix(OfficialBank.selectionPrefix), activeOfficialBank == nil {
            selectBank(WordBanks.coreBankId)
        }
    }

    /// Swaps in merged data (after sign-in or sign-out) without echoing it
    /// back to the sync queue, and drops a session built from the old data.
    func replaceData(progress newProgress: ProgressState, customSets newSets: CustomSetState, preserveSession: Bool = false) {
        let previousSession = preserveSession ? studySession : nil
        replacing = true
        let normalized = LearningEngine.normalizeForDate(newProgress, today: today)
        otherModeWords = ModeProgress.storedWords(of: normalized, excluding: studyMode == .chinese)
        progress = ModeProgress.view(normalized, chinese: studyMode == .chinese)
        customSets = newSets
        replacing = false
        if settings.activeBankId != WordBanks.coreBankId, !newSets.sets.contains(where: { $0.id == settings.activeBankId }) {
            selectBank(WordBanks.coreBankId)
        }
        studySession = nil
        studyUndoStack = []
        deletedSetUndo = nil
        if let previousSession { restoreStudySession(previousSession) }
        scheduleSave()
    }

    // MARK: Reminders

    /// Chooses the app's look; the home-screen icon is switched to match.
    func setAppStyle(_ style: AppStyle) {
        settings.appStyle = style
        settings.stylePicked = true
        if settings.iconFollowsStyle ?? true { AppIconSwitcher.apply(style) }
    }

    func setIconFollowsStyle(_ follows: Bool) {
        settings.iconFollowsStyle = follows
        AppIconSwitcher.apply(follows ? settings.appStyle ?? .standard : .standard)
    }

    /// The main icon is now the collage's: a learner who chose the leather
    /// look (with the icon following it) gets its icon back, once.
    func syncAppIcon() {
        guard settings.stylePicked == true, settings.iconFollowsStyle ?? true else { return }
        AppIconSwitcher.apply(settings.appStyle ?? .standard)
    }

    /// The one-time style chooser (master asks once, on a day after the
    /// first practice). WordCat Next: never; nothing gets in the way of a
    /// day's learning, and the style is changed in Settings › App style.
    var styleChoiceDue: Bool { false }

    var reminderEnabled: Bool { settings.streakReminder ?? true }

    func setReminderEnabled(_ enabled: Bool) {
        settings.streakReminder = enabled
    }

    var streakPlan: StreakReminderPlan {
        StreakReminderPlan.make(progress: progress, enabled: reminderEnabled)
    }

    // MARK: Study mode

    var studyMode: StudyMode { settings.studyMode ?? .english }
    /// What a word means, for the AI: the Chinese for a learner of English,
    /// the English word for a learner of Chinese (whose prompt is already the Chinese).
    func aiGloss(_ word: WordEntry) -> String {
        studyMode == .chinese ? word.word : ChineseDisplay.conciseMeaning(word.meaningZh)
    }

    /// Switching what is learned rebuilds the study session (the cards face
    /// the other way) and brings up that mode's own word progress; the
    /// streak and daily goal carry over.
    func setStudyMode(_ mode: StudyMode) {
        guard mode != studyMode else { return }
        Usage.log("mode_switch", mode.rawValue)
        let stored = syncedProgress
        settings.studyMode = mode
        replacing = true
        otherModeWords = ModeProgress.storedWords(of: stored, excluding: mode == .chinese)
        progress = ModeProgress.view(stored, chinese: mode == .chinese)
        replacing = false
        // Each mode has its own built-in words.
        mergedWordsCache = nil
        vocabularyCache = nil
        preparedCache = nil
        libraryRevision &+= 1
        studySession = nil
        studyUndoStack = []
        // An official bank belongs to one mode.
        if settings.activeBankId.hasPrefix(OfficialBank.selectionPrefix), activeOfficialBank == nil {
            selectBank(WordBanks.coreBankId)
        }
    }

    func face(_ word: WordEntry) -> WordFace { WordFace(word, mode: studyMode) }

    // MARK: Word lists and banks

    /// Built-in words plus hand-added ones; scanned words only live in their own bank.
    var allWords: [WordEntry] {
        if let cached = mergedWordsCache { return cached }
        let words = WordBanks.mergeCustomWords(base: coreWords, custom: customSets.customWords, includeBankCopies: true)
            + officialBanks.flatMap(\.words)
        mergedWordsCache = words
        return words
    }
    var vocabularyWords: [WordEntry] {
        if let cached = vocabularyCache { return cached }
        let words = WordBanks.mergeCustomWords(base: coreWords, custom: customSets.customWords.filter { !WordBanks.isScannedWordId($0.id) })
        vocabularyCache = words
        return words
    }

    var activeSet: CustomVocabSet? {
        settings.activeBankId == WordBanks.coreBankId ? nil : customSets.sets.first { $0.id == settings.activeBankId }
    }

    /// The developer's official banks for the current study mode.
    var officialBanks: [OfficialBank] { officialBanksByMode[studyMode.rawValue] ?? [] }

    var activeOfficialBank: OfficialBank? {
        guard settings.activeBankId.hasPrefix(OfficialBank.selectionPrefix) else { return nil }
        return officialBanks.first { $0.selectionId == settings.activeBankId }
    }

    /// Whether a bank other than the built-in words is chosen.
    var usesOtherBank: Bool { activeSet != nil || activeOfficialBank != nil }

    var bankName: String { activeSet?.name ?? activeOfficialBank.map(\.localizedName) ?? L.coreBankName }
    var bankIsScan: Bool { activeSet.map { set in set.wordIds.contains(where: WordBanks.isScannedWordId) } ?? false }

    var bankWords: [WordEntry] {
        if let set = activeSet { return WordBanks.words(of: set, in: allWords) }
        if let official = activeOfficialBank { return official.words }
        return vocabularyWords
    }

    var bank: PreparedVocabulary {
        let key = "\(studyMode.rawValue)|\(settings.activeBankId)|\(customSets.customWords.count)|\(activeSet?.updatedAt ?? "")|\(coreWords.count)|\(contentRevision)"
        if let cached = preparedCache, cached.key == key { return cached.vocabulary }
        let prepared = PreparedVocabulary(bankWords)
        preparedCache = (key, prepared)
        return prepared
    }

    var levels: [String] { WordData.levels(in: bank.words) }

    func selectBank(_ id: String) {
        guard settings.activeBankId != id else { return }
        var next = settings
        var saved = next.savedBankFilters ?? [:]
        saved[next.activeBankId] = BankFilterSettings(study: next.studyFilter, quiz: next.quizFilter,
                                                      library: next.libraryFilter, speaking: next.speakingFilter ?? FilterSelection())
        let filters = saved[id] ?? BankFilterSettings()
        next.savedBankFilters = saved
        next.activeBankId = id
        next.studyFilter = filters.study
        next.quizFilter = filters.quiz
        next.libraryFilter = filters.library
        next.speakingFilter = filters.speaking
        settings = next
        studySession = nil
        studyUndoStack = []
    }

    // MARK: Scanning

    /// Saves reviewed scan rows into a new bank and switches to it.
    func saveScannedWords(_ rows: [ReviewedScanWord], newBankName: String) -> (setId: String, added: Int, name: String)? {
        guard !ScanImportPlan(rows: rows).additions.isEmpty else { return nil }
        let created = customSets.creatingSet(named: newBankName.trimmed.isEmpty ? WordBanks.defaultScanBankName() : newBankName)
        customSets = created.state
        return saveScannedWords(rows, intoSet: created.id)
    }

    /// Saves reviewed scan rows into an existing bank and switches to it.
    /// Words already in that bank are skipped, so scanning the same sheet
    /// twice does not fill it with copies.
    func saveScannedWords(_ rows: [ReviewedScanWord], intoSet setId: String) -> (setId: String, added: Int, name: String)? {
        guard let set = customSets.sets.first(where: { $0.id == setId }) else { return nil }
        let plan = ScanImportPlan(rows: rows, existing: WordBanks.words(of: set, in: allWords))
        let words = WordBanks.buildScannedWords(plan.additions, coreWords: vocabularyWords, requireMatchingExample: true)
        // New words go first in a set, so add them in reverse to keep the
        // order they were printed in.
        customSets = customSets.addingCustomWords(Array(words.reversed()), toSet: setId)
        selectBank(setId)
        studySession = nil
        studyUndoStack = []
        scheduleSave()
        Usage.log("scan_saved", studyMode.rawValue)
        Usage.log("scan_words", "", count: words.count)
        return (setId, words.count, set.name)
    }

    func renameSet(_ id: String, to name: String) {
        customSets = customSets.renamingSet(id, to: name)
        scheduleSave()
    }

    func deleteSet(_ id: String) {
        deletedSetUndo = customSets.sets.first { $0.id == id }
        customSets = customSets.deletingSet(id)
        if settings.activeBankId == id { selectBank(WordBanks.coreBankId) }
        scheduleSave()
    }

    func restoreDeletedSet() {
        guard let deleted = deletedSetUndo else { return }
        customSets = customSets.restoringSet(deleted)
        deletedSetUndo = nil
        selectBank(deleted.id)
        scheduleSave()
    }

    func dismissDeletedSetUndo() { deletedSetUndo = nil }

    func transferWords(_ ids: Set<String>, from source: String, to target: String, move: Bool) {
        customSets = customSets.transferringWords(ids, from: source, to: target, move: move)
        scheduleSave()
    }

    func editCustomWord(_ word: WordEntry) {
        customSets = customSets.editingWord(word)
        scheduleSave()
    }

    // MARK: Insights

    func activity(days: Int) -> [DailyLearningActivity] {
        (progress.analytics ?? LearningAnalyticsState()).activity(endingOn: today, dayCount: days)
    }

    struct HistorySummary {
        var activeDays = 0
        var actions = 0
        var studied = 0
        var quizCorrect = 0
        var quizWrong = 0
        var speakingCompleted = 0
        /// Fewer answers than this say little, so no percentage is shown yet.
        static let minimumAnswers = 5
        var accuracy: Int? {
            let total = quizCorrect + quizWrong
            return total >= Self.minimumAnswers ? Int((Double(quizCorrect) / Double(total) * 100).rounded()) : nil
        }
    }

    func history(days: Int) -> HistorySummary {
        let analytics = progress.analytics ?? LearningAnalyticsState()
        var summary = HistorySummary()
        for back in 0..<days {
            let day = analytics.day(DayMath.addDays(today, -back) ?? today)
            if day.practiceActions > 0 { summary.activeDays += 1 }
            summary.actions += day.practiceActions
            summary.studied += day.studyKnown + day.studyReview
            summary.quizCorrect += day.quizCorrect
            summary.quizWrong += day.quizWrong
            summary.speakingCompleted += day.speakingCompleted
        }
        return summary
    }

    /// Words that keep slipping back: most lapses, then most reviews.
    func weakWords(limit: Int = 20) -> [WordEntry] {
        let ranked = progress.words
            .filter { $0.value.status == .review || ($0.value.lapses ?? 0) > 0 }
            .sorted { a, b in
                let la = a.value.lapses ?? 0, lb = b.value.lapses ?? 0
                if la != lb { return la > lb }
                if a.value.reviewCount != b.value.reviewCount { return a.value.reviewCount > b.value.reviewCount }
                return a.key < b.key
            }
            .prefix(limit)
        return ranked.compactMap { word(id: $0.key) }
    }

    /// Share of correct quiz answers in the last seven days, once there are enough of them.
    var quizAccuracy: (percent: Int, correct: Int, total: Int)? {
        let analytics = progress.analytics ?? LearningAnalyticsState()
        var correct = 0, wrong = 0
        for back in 0..<7 {
            let day = analytics.day(DayMath.addDays(today, -back) ?? today)
            correct += day.quizCorrect
            wrong += day.quizWrong
        }
        guard correct + wrong >= HistorySummary.minimumAnswers else { return nil }
        return (Int((Double(correct) / Double(correct + wrong) * 100).rounded()), correct, correct + wrong)
    }

    // MARK: Streak protection

    /// Protection covered yesterday; studying today keeps the streak going.
    var streakProtectionJustUsed: Bool { StreakProtection.justUsed(in: progress, today: today) }

    /// The day protection could next cover, or nil when it is ready now.
    var streakProtectionReadyOn: String? {
        guard let used = progress.streakFreezeDate, let ready = DayMath.addDays(used, StreakProtection.cooldownDays) else { return nil }
        return ready > today ? ready : nil
    }

    // MARK: Today

    var stats: ProgressStats { LearningEngine.stats(vocabulary: bank, state: progress, today: today) }
    var goalDone: Bool { progress.studiedToday >= progress.dailyTarget }
    var dailyFraction: Double {
        guard progress.dailyTarget > 0 else { return 0 }
        return min(1, Double(progress.studiedToday) / Double(progress.dailyTarget))
    }
    var newWordsLeftToday: Int { studyPlan.fresh }

    /// WordCat Next: the chapter the level test placed the learner at, for
    /// the built-in words of the mode it was taken in; new words start there.
    var placementStart: Int? {
        guard settings.activeBankId == WordBanks.coreBankId, let profile = settings.learnerProfile,
              profile.startMode == nil || profile.startMode == studyMode.rawValue else { return nil }
        return profile.startChapter
    }

    var studyPlan: (fresh: Int, review: Int, total: Int) {
        // Today's set, also while it is put aside for a round of missed words.
        let parked = parkedDaySet.flatMap { $0.day == today ? $0.session : nil }
        guard let session = parked ?? (studySessionDay == today ? studySession : nil),
              session.sourceKey == studySourceKey, !session.isComplete else {
            // Only the counts are shown, so skip building and shuffling the queue.
            return LearningEngine.studyQueueCounts(words: studyCandidates, state: progress, today: today, limit: nextSessionLimit,
                                                   startLevel: placementStart)
        }
        var seen = Set<String>()
        let words = session.cardIds.dropFirst(session.index).filter { seen.insert($0).inserted }.compactMap { word(id: $0) }
        let fresh = words.filter { progress.progress(for: $0.id).status == .new }.count
        return (fresh, words.count - fresh, words.count)
    }

    private var nextSessionLimit: Int {
        max(1, goalDone ? progress.dailyTarget : progress.dailyTarget - progress.studiedToday)
    }

    var studyCandidates: [WordEntry] {
        let filter = settings.studyFilter
        return bank.filter(state: progress, query: "", filter: filter.status, options: filter.options)
    }

    var primaryActionTitle: String {
        if routinePending, let routine = activeRoutine {
            return routine.step == .exam ? L.t("繼續考考看", "Continue the quiz") : L.t("繼續拼字", "Continue spelling")
        }
        return goalDone ? L.extraAction : progress.studiedToday > 0 ? L.continueAction : L.primaryAction
    }

    func refreshToday() {
        let now = DayMath.today()
        guard now != today else { return }
        today = now
        progress = LearningEngine.normalizeForDate(progress, today: now)
        studyUndoStack = []
        scheduleSave()
    }

    /// The words the learner said they know on the first launch count as
    /// known on sight, so new words start near their level.
    /// WordCat Next: words recognised but not spelled start as words being learned.
    func applyPlacement(knownIds: [String], learningIds: [String] = []) {
        guard !knownIds.isEmpty || !learningIds.isEmpty else { return }
        refreshToday()
        progress = Placement.apply(knownIds: knownIds, learningIds: learningIds, to: progress, today: today)
        scheduleSave()
        Usage.log("placement", studyMode.rawValue)
    }

    func setDailyTarget(_ target: Int) {
        progress.dailyTarget = target
        scheduleSave()
    }

    func progress(for wordId: String) -> WordProgress { progress.progress(for: wordId) }

    func toggleFavorite(_ wordId: String) {
        progress = LearningEngine.toggleFavorite(progress, wordId: wordId)
        scheduleSave()
    }

    // MARK: Study

    /// The current session, or a fresh one when there is none or the bank or
    /// filters changed since it was built.
    func ensureStudySession() {
        refreshToday()
        // Back from a detour: today's set carries on where it was left.
        if let parked = parkedDaySet {
            parkedDaySet = nil
            if parked.day == today, parked.session.sourceKey == studySourceKey {
                studySession = parked.session
                wordRoutine = parked.routine
                studySessionDay = parked.day
                studySessionIsDaySet = true
                studyUndoStack = []
                scheduleSave()
                return
            }
        }
        if let session = studySession, studySessionDay == today, session.sourceKey == studySourceKey,
           !session.isComplete || routinePending { return }
        startStudySession()
    }

    /// The schedule decides what to study, so a session depends only on the bank.
    var studySourceKey: String {
        let filter = settings.studyFilter
        return "\(settings.activeBankId)|\(studyMode.rawValue)|\(filter.status.rawValue)|\(filter.level)|\(filter.initial)"
    }

    private func restoreStudySession(_ saved: StudySession) {
        // A finished set is kept too: signing in from its summary must not
        // leave the summary with nothing to show.
        guard saved.sourceKey == studySourceKey,
              saved.isComplete || saved.cardIds.allSatisfy({ bank.index(of: $0) != nil }) else { return }
        studySession = saved
    }

    func startStudySession(onlyIds: [String]? = nil, limit: Int? = nil) {
        refreshToday()
        // A chosen list over an unfinished day set: keep the day set aside.
        if onlyIds != nil, studySessionIsDaySet, let session = studySession, studySessionDay == today,
           !session.isComplete || routinePending {
            parkedDaySet = (session, wordRoutine, today)
        } else if onlyIds == nil {
            parkedDaySet = nil
        }
        let candidates: [WordEntry]
        if let onlyIds {
            let wanted = Set(onlyIds)
            candidates = bank.words.filter { wanted.contains($0.id) }
        } else {
            candidates = studyCandidates
        }
        let queue = LearningEngine.buildStudyQueue(words: candidates, state: progress, today: today,
                                                  limit: limit ?? (onlyIds == nil ? nextSessionLimit : max(1, candidates.count)),
                                                  startLevel: onlyIds == nil ? placementStart : nil)
        studySession = StudySession(cardIds: queue.map(\.id), sourceKey: studySourceKey)
        studySessionDay = today
        studySessionIsDaySet = onlyIds == nil
        wordRoutine = onlyIds == nil && studyMode == .english && AppRuntime.wordRoutine
            ? WordRoutine(cardIds: queue.map(\.id),
                          stagesBefore: Dictionary(queue.compactMap { word -> (String, Int)? in
                              guard let saved = progress.words[word.id], saved.status != .new else { return nil }
                              return (word.id, LearningEngine.reviewStage(saved))
                          }, uniquingKeysWith: { first, _ in first }),
                          sourceKey: studySourceKey, day: today)
            : nil
        studyUndoStack = []
        scheduleSave()
        Usage.log("study_session", usageScope)
    }

    /// Which word bank and levels are in use, for the usage report:
    /// "english.core:Level1,Level2", "chinese.core:all", "english.custom".
    var usageScope: String {
        if let official = activeOfficialBank { return "\(studyMode.rawValue).official:\(official.id)" }
        let bankKind = settings.activeBankId == WordBanks.coreBankId ? "core" : "custom"
        guard bankKind == "core" else { return "\(studyMode.rawValue).custom" }
        let levels = settings.studyFilter.levels
        return "\(studyMode.rawValue).core:" + (levels.isEmpty ? "all" : levels.joined(separator: ","))
    }

    func word(id: String) -> WordEntry? {
        if let index = bank.index(of: id) { return bank.words[index] }
        return allWords.first { $0.id == id }
    }

    func gradeCurrentCard(_ grade: StudyGrade, expectedWordId: String? = nil) {
        refreshToday()
        guard let session = studySession, let cardId = session.currentCardId else { return }
        guard expectedWordId == nil || expectedWordId == cardId else { return }
        let changed = grade == .known
            ? LearningEngine.markKnown(progress, wordId: cardId, today: today)
            : LearningEngine.markReview(progress, wordId: cardId, today: today)
        let graded = recordActivity(in: changed) { counters in
            if grade == .known { counters.studyKnown += 1 } else { counters.studyReview += 1 }
            if studyMode == .english { counters.englishActions += 1 } else { counters.chineseActions += 1 }
        }
        studyUndoStack.append((progress, session))
        if studyUndoStack.count > 20 { studyUndoStack.removeFirst() }
        gradingStudyCard = true
        progress = graded
        gradingStudyCard = false
        studySession = session.grading(cardId, as: grade)
        scheduleSave()
        Usage.log("study_card", studyMode.rawValue)
    }

    func undoStudyGrade() {
        refreshToday()
        guard let last = studyUndoStack.popLast() else { return }
        gradingStudyCard = true
        progress = last.progress
        gradingStudyCard = false
        studySession = last.session
        scheduleSave()
    }

    // MARK: Quiz

    /// Set when a finished study set offers a quiz on the words just learned;
    /// the next quiz takes it.
    @ObservationIgnored private var todayQuizRequested = false

    func requestQuizOnTodaysWords() { todayQuizRequested = true }

    /// A quiz closed before it started must not leave the next one on today's words.
    func cancelQuizOnTodaysWords() { todayQuizRequested = false }

    /// Questions come from words the learner has met, topped up with new
    /// words only if there are too few.
    func quizQuestions(count: Int, seed: String) -> [WordEntry] {
        if todayQuizRequested {
            todayQuizRequested = false
            let studied = bank.words.filter { progress.words[$0.id]?.lastStudied == today }
            if !studied.isEmpty { return QuizBuilder.session(words: studied, count: count, seed: seed) }
        }
        return seenWordsFirst(count: count, seed: seed)
    }

    /// Spelling draws from the same words as a quiz.
    func spellingQuestions(seed: String) -> [WordEntry] {
        guard studyMode == .chinese else { return seenWordsFirst(count: Spelling.sessionLength, seed: seed) }
        // Learners of Chinese write the meaning, so it must be in Chinese.
        let filter = settings.quizFilter
        let candidates = bank.filter(state: progress, query: "", filter: filter.status, options: filter.options)
            .filter { !ChineseSpelling.targets($0.meaningZh).isEmpty }
        return QuizBuilder.seenFirstSession(words: candidates, state: progress, count: Spelling.sessionLength, seed: seed)
    }

    private func seenWordsFirst(count: Int, seed: String) -> [WordEntry] {
        let filter = settings.quizFilter
        let candidates = bank.filter(state: progress, query: "", filter: filter.status, options: filter.options)
        return QuizBuilder.seenFirstSession(words: candidates, state: progress, count: count, seed: seed)
    }

    /// The numbers the AI learning analysis reads: totals, the last 14 days
    /// and the words forgotten most often. No word lists beyond those.
    func insightsInput() -> [String: JSONValue] {
        let stats = self.stats
        let days = activity(days: 14)
        let quizCorrect = days.reduce(0) { $0 + $1.counters.quizCorrect }
        let quizTotal = days.reduce(0) { $0 + $1.counters.quizCorrect + $1.counters.quizWrong }
        let struggling = bank.words
            .compactMap { word -> (WordEntry, WordProgress)? in
                guard let progress = progress.words[word.id], progress.status == .review || (progress.lapses ?? 0) > 0 else { return nil }
                return (word, progress)
            }
            .sorted { ($0.1.lapses ?? 0, $0.1.reviewCount) > ($1.1.lapses ?? 0, $1.1.reviewCount) }
            .prefix(12)
        var input: [String: JSONValue] = [
            "mode": .string(studyMode.rawValue),
            "streak": .number(Double(max(0, progress.streak))),
            "mastered": .number(Double(stats.mastered)),
            "reviewing": .number(Double(stats.review)),
            "due": .number(Double(stats.due)),
            "dailyTarget": .number(Double(max(1, progress.dailyTarget))),
            "quizCorrect": .number(Double(quizCorrect)),
            "quizTotal": .number(Double(quizTotal)),
            "days": .array(days.map { day in
                .object([
                    "date": .string(day.date),
                    "words": .number(Double(day.words)),
                    "quiz": .number(Double(day.other)),
                    "speaking": .number(Double(day.speaking)),
                ])
            }),
            "struggling": .array(struggling.map { word, progress in
                let face = self.face(word)
                return .object([
                    "word": .string(String(face.prompt.prefix(80))),
                    "meaning": .string(String(self.aiGloss(word).prefix(120))),
                    "misses": .number(Double(min(999, max(progress.lapses ?? 0, progress.status == .review ? 1 : 0)))),
                ])
            }),
        ]
        // WordCat Next: where the level test placed them, so a new learner
        // with few words marked known is not read as a beginner.
        if let placementStart { input["placementChapter"] = .number(Double(placementStart)) }
        return input
    }

    /// Bank words shown with these prompts in the current study mode, such as
    /// the focus words the AI picked from `insightsInput`.
    func wordIds(forPrompts prompts: [String]) -> [String] {
        let wanted = Set(prompts.map { String($0.prefix(80)).lowercased() })
        return bank.words.filter { wanted.contains(String(face($0).prompt.prefix(80)).lowercased()) }.map(\.id)
    }

    var reviewWordIds: [String] {
        bank.words.filter { progress.words[$0.id]?.status == .review }.map(\.id)
    }

    /// WordCat Next: one round of the missed words, the most often forgotten
    /// first, at most fifteen, so a month's misses are not one long sitting.
    var missedRoundIds: [String] {
        let ranked = reviewWordIds.enumerated().sorted { a, b in
            let la = progress.words[a.element]?.lapses ?? 0, lb = progress.words[b.element]?.lapses ?? 0
            return la != lb ? la > lb : a.offset < b.offset
        }
        return ranked.prefix(15).map(\.element)
    }

    func recordQuizAnswer(wordId: String, correct: Bool) {
        refreshToday()
        let changed = correct
            ? LearningEngine.markQuizCorrect(progress, wordId: wordId, today: today)
            : LearningEngine.markReview(progress, wordId: wordId, today: today)
        progress = recordActivity(in: changed) { counters in
            if correct { counters.quizCorrect += 1 } else { counters.quizWrong += 1 }
            if studyMode == .english { counters.englishActions += 1 } else { counters.chineseActions += 1 }
        }
        scheduleSave()
        Usage.log("quiz_answer", studyMode.rawValue)
    }

    /// A typed answer. Right with at most the first letter given counts as a
    /// right quiz answer; with more help it is practice that leaves the
    /// schedule alone; anything else sends the word back to review.
    func recordSpellingAnswer(wordId: String, result: Spelling.Result, hints: Int) {
        Usage.log("spelling_answer", studyMode.rawValue)
        guard result == .correct, hints >= 2 else {
            recordQuizAnswer(wordId: wordId, correct: result == .correct)
            return
        }
        refreshToday()
        progress = recordActivity(in: LearningEngine.recordPracticeDay(progress, today: today)) { counters in
            counters.otherActions += 1
            if studyMode == .english { counters.englishActions += 1 } else { counters.chineseActions += 1 }
        }
        scheduleSave()
    }

    // MARK: Fill in the blank

    /// A round of fill-in-the-blank questions, from the words a study session
    /// would pick (due reviews and new words at the learner's level), keeping
    /// those whose example sentence has the word in it. Learners of English
    /// only: the sentences are English.
    func clozeRound(seed: String) -> (round: ClozeRound, words: [WordEntry]) {
        refreshToday()
        guard studyMode == .english else { return (ClozeRound(entries: []), []) }
        let candidates = studyCandidates.filter { Cloze.sentence(for: $0) != nil }
        let queue = LearningEngine.buildStudyQueue(words: candidates, state: progress, today: today,
                                                  limit: nextSessionLimit, seed: seed, startLevel: placementStart)
        let entries = queue.map { word in
            let saved = progress.words[word.id]
            return ClozeRound.Entry(wordId: word.id, isNew: (saved?.status ?? .new) == .new,
                                    stage: LearningEngine.reviewStage(saved))
        }
        Usage.log("cloze_round", usageScope)
        return (ClozeRound(entries: entries), queue)
    }

    /// How a fill-in-the-blank word went. Right straight away counts as
    /// known, so a new word the learner already had skips the short waits;
    /// right with a little help counts as a right quiz answer; a miss sends
    /// the word back to review.
    func recordClozeAnswer(wordId: String, outcome: ClozeRound.Outcome) {
        refreshToday()
        let changed: ProgressState
        switch outcome {
        case .knew: changed = LearningEngine.markKnown(progress, wordId: wordId, today: today)
        case .gotIt: changed = LearningEngine.markQuizCorrect(progress, wordId: wordId, today: today)
        case .missed: changed = LearningEngine.markReview(progress, wordId: wordId, today: today)
        }
        progress = recordActivity(in: changed) { counters in
            if outcome == .missed { counters.quizWrong += 1 } else { counters.quizCorrect += 1 }
            if studyMode == .english { counters.englishActions += 1 } else { counters.chineseActions += 1 }
        }
        scheduleSave()
        Usage.log("cloze_answer", "\(studyMode.rawValue).\(outcome.rawValue)")
    }

    // MARK: Words routine (WordCat Next)

    /// The routine of the current flip cards: same day, same source and the
    /// same cards. Anything that replaces the session leaves the routine behind.
    var activeRoutine: WordRoutine? {
        guard let routine = wordRoutine, let session = studySession, routine.day == today,
              routine.sourceKey == session.sourceKey else { return nil }
        var seen = Set<String>()
        guard routine.cardIds == session.cardIds.filter({ seen.insert($0).inserted }) else { return nil }
        return routine
    }

    /// The flip cards are done and their checks are still to come.
    var routinePending: Bool {
        guard let routine = activeRoutine, studySession?.isComplete == true else { return false }
        return routine.step != .done
    }

    /// What the Today card says while checks wait.
    var routineHeroLine: String? {
        guard routinePending, let routine = activeRoutine else { return nil }
        if routine.step == .exam {
            let done = routine.examIds.count - routine.examLeft.count
            return L.t("翻卡完成 · 考考看 \(done)/\(routine.examIds.count)", "Cards done · quiz \(done)/\(routine.examIds.count)")
        }
        return L.t("翻卡完成 · 接下來拼字", "Cards done · spelling next")
    }

    /// After the flip cards: picks today's checks from the cards marked known.
    func planRoutineChecks() {
        guard var routine = activeRoutine, routine.step == .flip, let session = studySession, session.isComplete else { return }
        let profile = settings.learnerProfile ?? LearnerProfile()
        routine.planChecks(knownIds: session.knownIds, unsureIds: session.reviewIds,
                           maxSpell: profile.spellChecks, maxExam: profile.examChecks,
                           canSpell: { [self] id in word(id: id).flatMap { Cloze.sentence(for: $0, chinese: learnsChinese) } != nil },
                           canExam: { [self] id in
                               guard let word = word(id: id), Cloze.sentence(for: word, chinese: learnsChinese) != nil else { return false }
                               if learnsChinese { return true }
                               let text = Spelling.normalized(word.word)
                               return text.count >= 2 && text.allSatisfy(\.isLetter)
                           })
        wordRoutine = routine
        scheduleSave()
    }

    /// One spot check: a spelling (`exam` false) or an exam question.
    func recordRoutineCheck(wordId: String, outcome: ClozeRound.Outcome, exam: Bool) {
        guard var routine = activeRoutine else { return }
        refreshToday()
        let changed = LearningEngine.applyCheck(progress, wordId: wordId, today: today,
                                                wasNew: routine.wasNew(wordId), outcome: outcome)
        progress = recordActivity(in: changed) { counters in
            if outcome == .missed { counters.quizWrong += 1 } else { counters.quizCorrect += 1 }
            if studyMode == .english { counters.englishActions += 1 } else { counters.chineseActions += 1 }
        }
        if exam { routine.recordExam(wordId, correct: outcome != .missed) } else { routine.recordSpell(wordId, outcome: outcome) }
        wordRoutine = routine
        scheduleSave()
        Usage.log("routine_check", "\(exam ? "exam" : "spell").\(outcome.rawValue)")
    }

    /// A check that cannot be asked after all: the next word marked known
    /// takes its place rather than the check being waved through.
    func replaceUnaskableCheck(_ wordId: String) {
        guard var routine = activeRoutine else { return }
        routine.replaceUnaskable(wordId)
        wordRoutine = routine
        scheduleSave()
        Usage.log("routine_check_replaced", studyMode.rawValue)
    }

    /// Checks and questions are in the language being learned.
    var learnsChinese: Bool { studyMode == .chinese }

    /// The shape of exam questions, from the exam in the learner's plan.
    var examStyle: ExamStyle { ExamStyle(exam: settings.learnerProfile?.exam) }

    /// Ends the current check step (spelling, then the exam questions).
    func advanceRoutine() {
        guard var routine = activeRoutine else { return }
        switch routine.step {
        case .spell:
            routine.finishSpell()
            // The spelling score follows every routine, so tomorrow's checks
            // grow when spelling slips and shrink when it is solid.
            var profile = settings.learnerProfile ?? LearnerProfile()
            profile.recordSpelling(Array(routine.spellResults.values))
            settings.learnerProfile = profile
        case .exam: routine.finishExam()
        case .flip, .done: return
        }
        wordRoutine = routine
        scheduleSave()
        if routine.step == .done { Usage.log("routine_done", studyMode.rawValue) }
    }

    /// Leaves the rest of today's checks.
    func skipRoutineChecks() {
        guard var routine = activeRoutine else { return }
        routine.skipChecks()
        wordRoutine = routine
        scheduleSave()
    }

    /// The built-in words prepared for picking exam options, built once off
    /// the main thread.
    func examPool() async -> ExamPool {
        let key = "\(studyMode.rawValue)|\(contentRevision)|\(coreWords.count)"
        if let cached = examPoolCache, cached.key == key { return cached.pool }
        let words = coreWords
        let chinese = studyMode == .chinese
        let pool = await Task.detached(priority: .userInitiated) { ExamPool(words, chinese: chinese) }.value
        examPoolCache = (key, pool)
        return pool
    }

    /// A word said in a sentence of the learner's own while speaking: it
    /// counts as a right answer where one would (see LearningEngine.creditUse).
    func creditWordUse(_ wordId: String) {
        refreshToday()
        let changed = LearningEngine.creditUse(progress, wordId: wordId, today: today)
        guard changed != progress else { return }
        progress = changed
        scheduleSave()
        Usage.log("speaking_word_credit", studyMode.rawValue)
    }

    /// New words a learner meets by `days` from now studying every day, by
    /// the same rules sessions are built with, from the reviews already due.
    func projectedNewWords(days: Int) -> Int {
        refreshToday()
        // New words left to meet, the easier chapters skipped as sessions skip them.
        let unseen = studyCandidates.filter { (progress.words[$0.id]?.status ?? .new) == .new }
        var fresh = unseen.count
        if let start = placementStart, start > 1 {
            let fromStart = unseen.filter { LearningEngine.coreLevel($0.group).map { $0 >= start } ?? true }.count
            if fromStart > 0 { fresh = fromStart }
        }
        return LearningEngine.projectedNewWords(state: progress, today: today, dailyTarget: progress.dailyTarget,
                                                days: days, freshAvailable: fresh)
    }

    /// Speaking practice counts as activity; a word used in it is credited
    /// separately (creditWordUse).
    func recordSpeaking(completed: Bool) {
        refreshToday()
        let changed = completed ? LearningEngine.recordPracticeDay(progress, today: today) : progress
        progress = recordActivity(in: changed) { counters in
            if completed { counters.speakingCompleted += 1 } else { counters.speakingSkipped += 1 }
            if completed {
                if studyMode == .english { counters.englishActions += 1 } else { counters.chineseActions += 1 }
            }
        }
        scheduleSave()
        Usage.log("speaking", "\(studyMode.rawValue).\(completed ? "completed" : "skipped")")
    }

    var quizMode: QuizAnswerMode { studyMode == .english ? .meaning : .word }

    var recentSpeakingIds: [String] { settings.currentRecentSpeakingIds }
    var speakingHistoryOwnerKey: String { settings.speakingHistoryOwnerKey }

    func setLocalOwner(_ ownerId: String?, anonymous: Bool) {
        settings.setLocalOwner(ownerId, anonymous: anonymous)
        saveNow()
    }

    func forgetSpeakingHistory(ownerId: String, anonymous: Bool) {
        settings.forgetSpeakingHistory(ownerId: ownerId, anonymous: anonymous)
        saveNow()
    }

    /// Remembers a speaking question as practised, so the next sessions ask
    /// about other words first.
    func noteSpeakingPractised(_ wordId: String) {
        settings.rememberSpeaking(wordId)
    }

    /// This learner's speaking path in the current study mode.
    var speakingPath: SpeakingPath.Progress { settings.currentSpeakingPath }

    /// Records a played stage (`stage` is its key; nil for word practice);
    /// one with nothing said is not cleared.
    func finishSpeakingStage(_ stage: String?, result: SpeakingPath.Result) {
        guard result.cleared else { return }
        refreshToday()
        settings.clearSpeakingStage(stage, stars: result.stars, today: today)
    }

    var speakingCandidates: [WordEntry] {
        let filter = settings.speakingFilter ?? FilterSelection()
        return bank.filter(state: progress, query: "", filter: filter.status, options: filter.options)
    }

    // MARK: Word sets

    @discardableResult
    func createSet(named name: String) -> String {
        let created = customSets.creatingSet(named: name.trimmed.isEmpty ? L.newBankDefault : name)
        customSets = created.state
        saveNow()
        return created.id
    }

    func addWord(_ wordId: String, toSet setId: String) {
        customSets = customSets.addingWord(wordId, toSet: setId)
        scheduleSave()
    }

    func removeWord(_ wordId: String, fromSet setId: String) {
        customSets = customSets.removingWord(wordId, fromSet: setId)
        scheduleSave()
    }

    func removeWords(_ ids: Set<String>, fromSet setId: String) {
        customSets = customSets.removingWords(ids, fromSet: setId)
        scheduleSave()
    }

    /// A word typed in by hand, saved into a set.
    @discardableResult
    func addCustomWord(word: String, partOfSpeech: String, meaning: String, toSet setId: String) -> String {
        let stamp = String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)
        let slug = WordBanks.slug(word.lowercased())
        let core = vocabularyWords.first { $0.word.lowercased() == word.trimmed.lowercased() }
        let entry = WordEntry(
            id: "custom-\(slug)-\(stamp)",
            word: word.trimmed,
            partOfSpeech: partOfSpeech.trimmed.isEmpty ? (core?.partOfSpeech ?? "") : partOfSpeech.trimmed,
            pronunciation: core?.pronunciation ?? "",
            meaningZh: meaning.trimmed,
            supplementalMeaningZh: "",
            example: core?.example ?? "",
            exampleZh: core?.exampleZh ?? "",
            group: "Custom"
        )
        customSets = customSets.addingCustomWords([entry], toSet: setId)
        scheduleSave()
        return entry.id
    }

    private func recordActivity(in state: ProgressState, _ change: (inout DailyLearningCounters) -> Void) -> ProgressState {
        var next = state
        var analytics = next.analytics ?? LearningAnalyticsState()
        analytics.record(date: today, source: settings.deviceSourceId, change)
        analytics.bestStreak = max(analytics.bestStreak, next.streak)
        next.analytics = analytics
        return next
    }

    // MARK: Saving

    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        saveTask?.cancel()
        let keep = keepsLearningRecords
        if keep { savedLearning = (syncedProgress, customSets) }
        let snapshot = AppSnapshot(progress: keep ? syncedProgress : savedLearning.progress,
                                   customSets: keep ? customSets : savedLearning.customSets,
                                   settings: settings, studySession: keep ? studySession : nil, sessionDay: studySessionDay ?? today,
                                   wordRoutine: keep ? wordRoutine : nil)
        persistence.store.enqueue(snapshot, to: "snapshot.json") { [weak self] saved in
            Task { @MainActor in self?.storageFailed = !saved }
        }
    }
}

/// Deterministic progress for UI tests and screenshots.
enum SampleData {
    static func progress(words: [WordEntry], today: String) -> ProgressState {
        var state = ProgressState(dailyTarget: 20)
        let yesterday = DayMath.addDays(today, -1) ?? today
        for word in words.prefix(40) {
            state = LearningEngine.markKnown(state, wordId: word.id, today: yesterday)
        }
        for word in words.dropFirst(40).prefix(8) {
            state = LearningEngine.markReview(state, wordId: word.id, today: yesterday)
        }
        for word in words.dropFirst(48).prefix(7) {
            state = LearningEngine.markKnown(state, wordId: word.id, today: today)
        }
        state = LearningEngine.toggleFavorite(state, wordId: words[2].id)
        return state
    }

    /// Six of the sample's known words, learned a while ago and due now.
    static func olderWordsDue(_ state: ProgressState, words: [WordEntry], today: String) -> ProgressState {
        var next = state
        // Other reviews wait till tomorrow, so these six make today's reviews.
        let tomorrow = DayMath.addDays(today, 1) ?? today
        for (id, progress) in next.words where progress.status != .new {
            var later = progress
            later.dueDate = tomorrow
            next.words[id] = later
        }
        for word in words.prefix(6) {
            var progress = next.progress(for: word.id)
            // Known for a while: met two weeks ago, at the 14-day stage.
            progress.status = .mastered
            progress.reviewCount = max(2, progress.reviewCount)
            progress.stage = 4
            progress.lastStudied = DayMath.addDays(today, -15) ?? today
            progress.dueDate = DayMath.addDays(today, -1) ?? today
            next.words[word.id] = progress
        }
        return next
    }

    /// A published official bank and a correction to the first built-in
    /// word ("adapt"), for UI tests of remote word list content.
    static let officialContent = RemoteContent(
        corrections: [WordCorrection(mode: "english", wordId: "w0001", fields: ["meaningZh": "適應（已校正）"])],
        banks: [OfficialBank(id: "medical", mode: "english", nameZh: "醫護英文", nameEn: "Medical English",
                             descriptionZh: "醫院、看診與護理常用字", descriptionEn: "Words for hospitals, check-ups and nursing",
                             icon: "cross.case.fill", color: "#FF2D55", updatedAt: "2026-11-04T00:00:00Z",
                             words: [
                                WordEntry(id: "pack-medical-diagnosis", word: "diagnosis", partOfSpeech: "n", pronunciation: "/ˌdaɪəɡˈnoʊsɪs/",
                                          meaningZh: "診斷", example: "The doctor explained the diagnosis clearly.", exampleZh: "醫生清楚說明了診斷結果。", group: "Level 1"),
                                WordEntry(id: "pack-medical-symptom", word: "symptom", partOfSpeech: "n", pronunciation: "/ˈsɪmptəm/",
                                          meaningZh: "症狀", example: "A fever is a common symptom of the flu.", exampleZh: "發燒是流感常見的症狀。", group: "Level 1"),
                                WordEntry(id: "pack-medical-prescription", word: "prescription", partOfSpeech: "n", pronunciation: "/prɪˈskrɪpʃən/",
                                          meaningZh: "處方", example: "Take this prescription to the pharmacy.", exampleZh: "拿這張處方去藥局。", group: "Level 2"),
                             ])])
}

extension OfficialBank {
    var localizedName: String { L.zh || nameEn.isEmpty ? nameZh : nameEn }
    var localizedDescription: String { L.zh || descriptionEn.isEmpty ? descriptionZh : descriptionEn }
}
