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
    let coreWords: [WordEntry]
    private(set) var progress: ProgressState {
        didSet { libraryRevision &+= 1; if !replacing { onDataChange?(SyncDirty(progress: true)) } }
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
    var settings: AppSettings {
        didSet {
            L.mode = settings.studyMode ?? .english
            scheduleSave()
        }
    }
    private(set) var today: String

    // Study session state survives switching tabs.
    private(set) var studySession: StudySession?
    private(set) var storageFailed = false
    private(set) var libraryRevision = 0
    private(set) var deletedSetUndo: CustomVocabSet?
    private var studyUndoStack: [(progress: ProgressState, session: StudySession)] = []
    var canUndoStudy: Bool { !studyUndoStack.isEmpty }

    @ObservationIgnored private let persistence: Persistence
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var preparedCache: (key: String, vocabulary: PreparedVocabulary)?
    @ObservationIgnored private var mergedWordsCache: [WordEntry]?
    @ObservationIgnored private var vocabularyCache: [WordEntry]?

    init(coreWords: [WordEntry], progress: ProgressState, customSets: CustomSetState, settings: AppSettings, persistence: Persistence, today: String = DayMath.today()) {
        self.coreWords = coreWords
        self.progress = LearningEngine.normalizeForDate(progress, today: today)
        self.customSets = customSets
        self.settings = settings
        L.mode = settings.studyMode ?? .english
        self.persistence = persistence
        self.today = today
    }

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
        if arguments.contains("-uiTestingSampleProgress") {
            progress = SampleData.progress(words: words, today: DayMath.today())
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
        if arguments.contains("-uiTestingChineseMode") { settings.studyMode = .chinese }
        if arguments.contains("-uiTestingLight") { settings.theme = .light }
        if settings.onboardingComplete == nil {
            settings.onboardingComplete = snapshot != nil || !progress.words.isEmpty || !sets.sets.isEmpty
        }
        if arguments.contains("-uiTestingReset"), !arguments.contains("-uiTestingOnboarding") {
            settings.onboardingComplete = true
        }

        let model = AppModel(coreWords: words, progress: progress, customSets: sets, settings: settings, persistence: persistence)
        if snapshot?.sessionDay == model.today, let saved = snapshot?.studySession {
            model.restoreStudySession(saved)
        }
        model.saveNow()
        return model
    }

    static func loadBundledWords() -> [WordEntry] {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? WordData.decode(data)
        else { return [] }
        return words
    }

    /// Swaps in merged data (after sign-in or sign-out) without echoing it
    /// back to the sync queue, and drops a session built from the old data.
    func replaceData(progress newProgress: ProgressState, customSets newSets: CustomSetState, preserveSession: Bool = false) {
        let previousSession = preserveSession ? studySession : nil
        replacing = true
        progress = LearningEngine.normalizeForDate(newProgress, today: today)
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

    var reminderEnabled: Bool { settings.streakReminder ?? true }

    func setReminderEnabled(_ enabled: Bool) {
        settings.streakReminder = enabled
    }

    var streakPlan: StreakReminderPlan {
        StreakReminderPlan.make(progress: progress, enabled: reminderEnabled)
    }

    // MARK: Study mode

    var studyMode: StudyMode { settings.studyMode ?? .english }

    /// Switching what is learned rebuilds the study session (the cards face
    /// the other way) but keeps all progress.
    func setStudyMode(_ mode: StudyMode) {
        guard mode != studyMode else { return }
        settings.studyMode = mode
        studySession = nil
        studyUndoStack = []
    }

    func face(_ word: WordEntry) -> WordFace { WordFace(word, mode: studyMode) }

    // MARK: Word lists and banks

    /// Built-in words plus hand-added ones; scanned words only live in their own bank.
    var allWords: [WordEntry] {
        if let cached = mergedWordsCache { return cached }
        let words = WordBanks.mergeCustomWords(base: coreWords, custom: customSets.customWords, includeBankCopies: true)
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

    var bankName: String { activeSet?.name ?? L.coreBankName }
    var bankIsScan: Bool { activeSet.map { set in set.wordIds.contains(where: WordBanks.isScannedWordId) } ?? false }

    var bankWords: [WordEntry] {
        if let set = activeSet { return WordBanks.words(of: set, in: allWords) }
        return vocabularyWords
    }

    var bank: PreparedVocabulary {
        let key = "\(settings.activeBankId)|\(customSets.customWords.count)|\(activeSet?.updatedAt ?? "")|\(coreWords.count)"
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
        var accuracy: Int? { quizCorrect + quizWrong > 0 ? Int((Double(quizCorrect) / Double(quizCorrect + quizWrong) * 100).rounded()) : nil }
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

    /// Share of correct quiz answers in the last seven days, if any.
    var quizAccuracy: Int? {
        let analytics = progress.analytics ?? LearningAnalyticsState()
        var correct = 0, wrong = 0
        for back in 0..<7 {
            let day = analytics.day(DayMath.addDays(today, -back) ?? today)
            correct += day.quizCorrect
            wrong += day.quizWrong
        }
        guard correct + wrong > 0 else { return nil }
        return Int((Double(correct) / Double(correct + wrong) * 100).rounded())
    }

    // MARK: Today

    var stats: ProgressStats { LearningEngine.stats(vocabulary: bank, state: progress, today: today) }
    var goalDone: Bool { progress.studiedToday >= progress.dailyTarget }
    var dailyFraction: Double {
        guard progress.dailyTarget > 0 else { return 0 }
        return min(1, Double(progress.studiedToday) / Double(progress.dailyTarget))
    }
    var newWordsLeftToday: Int { studyPlan.fresh }

    var studyPlan: (fresh: Int, review: Int, total: Int) {
        guard let session = studySession, session.sourceKey == studySourceKey, !session.isComplete else {
            // Only the counts are shown, so skip building and shuffling the queue.
            return LearningEngine.studyQueueCounts(words: studyCandidates, state: progress, today: today, limit: nextSessionLimit)
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
        goalDone ? L.extraAction : progress.studiedToday > 0 ? L.continueAction : L.primaryAction
    }

    func refreshToday() {
        let now = DayMath.today()
        guard now != today else { return }
        today = now
        progress = LearningEngine.normalizeForDate(progress, today: now)
        studyUndoStack = []
        scheduleSave()
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
        if let session = studySession, session.sourceKey == studySourceKey, !session.isComplete { return }
        startStudySession()
    }

    /// The schedule decides what to study, so a session depends only on the bank.
    var studySourceKey: String {
        let filter = settings.studyFilter
        return "\(settings.activeBankId)|\(studyMode.rawValue)|\(filter.status.rawValue)|\(filter.level)|\(filter.initial)"
    }

    private func restoreStudySession(_ saved: StudySession) {
        guard !saved.isComplete, saved.sourceKey == studySourceKey,
              saved.cardIds.allSatisfy({ bank.index(of: $0) != nil }) else { return }
        studySession = saved
    }

    func startStudySession(onlyIds: [String]? = nil, limit: Int? = nil) {
        refreshToday()
        let candidates: [WordEntry]
        if let onlyIds {
            let wanted = Set(onlyIds)
            candidates = bank.words.filter { wanted.contains($0.id) }
        } else {
            candidates = studyCandidates
        }
        let queue = LearningEngine.buildStudyQueue(words: candidates, state: progress, today: today,
                                                  limit: limit ?? (onlyIds == nil ? nextSessionLimit : max(1, candidates.count)))
        studySession = StudySession(cardIds: queue.map(\.id), sourceKey: studySourceKey)
        studyUndoStack = []
        scheduleSave()
    }

    func word(id: String) -> WordEntry? {
        if let index = bank.index(of: id) { return bank.words[index] }
        return allWords.first { $0.id == id }
    }

    func gradeCurrentCard(_ grade: StudyGrade, expectedWordId: String? = nil) {
        refreshToday()
        guard let session = studySession, let cardId = session.currentCardId else { return }
        guard expectedWordId == nil || expectedWordId == cardId else { return }
        studyUndoStack.append((progress, session))
        if studyUndoStack.count > 20 { studyUndoStack.removeFirst() }
        let changed = grade == .known
            ? LearningEngine.markKnown(progress, wordId: cardId, today: today)
            : LearningEngine.markReview(progress, wordId: cardId, today: today)
        progress = recordActivity(in: changed) { counters in
            if grade == .known { counters.studyKnown += 1 } else { counters.studyReview += 1 }
            if studyMode == .english { counters.englishActions += 1 } else { counters.chineseActions += 1 }
        }
        studySession = session.grading(cardId, as: grade)
        scheduleSave()
    }

    func undoStudyGrade() {
        refreshToday()
        guard let last = studyUndoStack.popLast() else { return }
        progress = last.progress
        studySession = last.session
        scheduleSave()
    }

    // MARK: Quiz

    /// Questions favour words the learner has met: due and struggling words
    /// first, then known ones, topped up with new words if there are too few.
    func quizQuestions(count: Int, seed: String) -> [WordEntry] {
        let filter = settings.quizFilter
        let candidates = bank.filter(state: progress, query: "", filter: filter.status, options: filter.options)
        let seen = candidates.filter { progress.words[$0.id].map { $0.status != .new } ?? false }
        let pool = seen.count >= count ? seen : candidates
        return QuizBuilder.session(words: pool, count: count, seed: seed)
    }

    var reviewWordIds: [String] {
        bank.words.filter { progress.words[$0.id]?.status == .review }.map(\.id)
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
    }

    /// Speaking practice counts as activity but does not change word progress.
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
    }

    var quizMode: QuizAnswerMode { studyMode == .english ? .meaning : .word }

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
        let snapshot = AppSnapshot(progress: progress, customSets: customSets, settings: settings,
                                   studySession: studySession, sessionDay: today)
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
}
