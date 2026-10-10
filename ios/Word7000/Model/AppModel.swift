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
    private(set) var progress: ProgressState
    private(set) var customSets: CustomSetState
    var settings: AppSettings {
        didSet { scheduleSave() }
    }
    private(set) var today: String

    // Study session state survives switching tabs.
    private(set) var studySession: StudySession?
    private var studyUndoStack: [(progress: ProgressState, session: StudySession)] = []
    var canUndoStudy: Bool { !studyUndoStack.isEmpty }

    @ObservationIgnored private let persistence: Persistence
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var preparedCache: (key: String, vocabulary: PreparedVocabulary)?

    init(coreWords: [WordEntry], progress: ProgressState, customSets: CustomSetState, settings: AppSettings, persistence: Persistence, today: String = DayMath.today()) {
        self.coreWords = coreWords
        self.progress = LearningEngine.normalizeForDate(progress, today: today)
        self.customSets = customSets
        self.settings = settings
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
        var settings = persistence.load(AppSettings.self, from: "settings.json") ?? AppSettings()
        var progress = persistence.load(ProgressState.self, from: "progress.json") ?? .empty
        var sets = persistence.load(CustomSetState.self, from: "custom-sets.json") ?? .empty

        if !settings.migratedLegacyData {
            if let legacy = LegacyImport.load() {
                progress = LearningEngine.merge([progress, legacy.progress])
                sets = CustomSetState.merge([sets, legacy.customSets])
                if let bank = legacy.activeBankId { settings.activeBankId = bank }
                if let theme = legacy.theme { settings.theme = theme }
                // Keep the old device id: it is the per-device key in the
                // activity counters and for lock screen reminders.
                if let deviceId = legacy.deviceId { settings.deviceSourceId = deviceId }
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
        if arguments.contains("-uiTestingDark") { settings.theme = .dark }
        if arguments.contains("-uiTestingLight") { settings.theme = .light }

        let model = AppModel(coreWords: words, progress: progress, customSets: sets, settings: settings, persistence: persistence)
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

    // MARK: Word lists and banks

    /// Built-in words plus hand-added ones; scanned words only live in their own bank.
    var allWords: [WordEntry] { WordBanks.mergeCustomWords(base: coreWords, custom: customSets.customWords) }
    var vocabularyWords: [WordEntry] { allWords.filter { !WordBanks.isScannedWordId($0.id) } }

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
        settings.activeBankId = id
        studySession = nil
        studyUndoStack = []
    }

    // MARK: Scanning

    /// Saves reviewed scan rows into a new bank and switches to it.
    func saveScannedWords(_ rows: [ReviewedScanWord], newBankName: String) -> (setId: String, added: Int, name: String)? {
        let created = customSets.creatingSet(named: newBankName.trimmed.isEmpty ? WordBanks.defaultScanBankName() : newBankName)
        customSets = created.state
        return saveScannedWords(rows, intoSet: created.id)
    }

    /// Saves reviewed scan rows into an existing bank and switches to it.
    /// Words already in that bank are skipped, so scanning the same sheet
    /// twice does not fill it with copies.
    func saveScannedWords(_ rows: [ReviewedScanWord], intoSet setId: String) -> (setId: String, added: Int, name: String)? {
        guard let set = customSets.sets.first(where: { $0.id == setId }) else { return nil }
        let existing = Set(WordBanks.words(of: set, in: allWords).map { $0.word.lowercased() })
        let words = WordBanks.buildScannedWords(rows.filter { !existing.contains($0.word.trimmed.lowercased()) }, coreWords: vocabularyWords)
        // New words go first in a set, so add them in reverse to keep the
        // order they were printed in.
        customSets = customSets.addingCustomWords(Array(words.reversed()), toSet: setId)
        settings.activeBankId = setId
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
        customSets = customSets.deletingSet(id)
        if settings.activeBankId == id { selectBank(WordBanks.coreBankId) }
        scheduleSave()
    }

    // MARK: Insights

    /// Learning actions per day for the last seven days, oldest first.
    var lastSevenDays: [(label: String, count: Int, isToday: Bool)] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh-Hant")
        let symbols = calendar.veryShortWeekdaySymbols
        let analytics = progress.analytics ?? LearningAnalyticsState()
        return (0..<7).reversed().map { back -> (label: String, count: Int, isToday: Bool) in
            let date = DayMath.addDays(today, -back) ?? today
            let weekday = DayMath.dayNumber(date).map { (($0 % 7) + 11) % 7 } ?? 0 // 1970-01-01 was a Thursday
            return (symbols[weekday], analytics.day(date).goalActions, back == 0)
        }
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

    var stats: ProgressStats { LearningEngine.stats(words: bank.words, state: progress, today: today) }
    var goalDone: Bool { progress.studiedToday >= progress.dailyTarget }
    var dailyFraction: Double {
        guard progress.dailyTarget > 0 else { return 0 }
        return min(1, Double(progress.studiedToday) / Double(progress.dailyTarget))
    }
    var newWordsLeftToday: Int { max(0, progress.dailyTarget - progress.studiedToday) }

    var primaryActionTitle: String {
        goalDone ? L.extraAction : progress.studiedToday > 0 ? L.continueAction : L.primaryAction
    }

    func refreshToday() {
        let now = DayMath.today()
        guard now != today else { return }
        today = now
        progress = LearningEngine.normalizeForDate(progress, today: now)
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
    var studySourceKey: String { settings.activeBankId }

    func startStudySession(onlyIds: [String]? = nil) {
        let candidates: [WordEntry]
        if let onlyIds {
            let wanted = Set(onlyIds)
            candidates = bank.words.filter { wanted.contains($0.id) }
        } else {
            candidates = bank.words
        }
        let queue = LearningEngine.buildStudyQueue(words: candidates, state: progress, today: today, limit: max(1, progress.dailyTarget))
        studySession = StudySession(cardIds: queue.map(\.id), sourceKey: studySourceKey)
        studyUndoStack = []
    }

    func word(id: String) -> WordEntry? {
        if let index = bank.index(of: id) { return bank.words[index] }
        return allWords.first { $0.id == id }
    }

    func gradeCurrentCard(_ grade: StudyGrade) {
        guard let session = studySession, let cardId = session.currentCardId else { return }
        studyUndoStack.append((progress, session))
        if studyUndoStack.count > 20 { studyUndoStack.removeFirst() }
        let changed = grade == .known
            ? LearningEngine.markKnown(progress, wordId: cardId, today: today)
            : LearningEngine.markReview(progress, wordId: cardId, today: today)
        progress = recordActivity(in: changed) { counters in
            if grade == .known { counters.studyKnown += 1 } else { counters.studyReview += 1 }
            counters.englishActions += 1
        }
        studySession = session.grading(cardId, as: grade)
        scheduleSave()
    }

    func undoStudyGrade() {
        guard let last = studyUndoStack.popLast() else { return }
        progress = last.progress
        studySession = last.session
        scheduleSave()
    }

    // MARK: Quiz

    /// Questions favour words the learner has met: due and struggling words
    /// first, then known ones, topped up with new words if there are too few.
    func quizQuestions(count: Int, seed: String) -> [WordEntry] {
        let seen = bank.words.filter { progress.words[$0.id].map { $0.status != .new } ?? false }
        let pool = seen.count >= count ? seen : bank.words
        return QuizBuilder.session(words: pool, count: count, seed: seed)
    }

    var reviewWordIds: [String] {
        bank.words.filter { progress.words[$0.id]?.status == .review }.map(\.id)
    }

    func recordQuizAnswer(wordId: String, correct: Bool) {
        let changed = correct
            ? LearningEngine.markQuizCorrect(progress, wordId: wordId, today: today)
            : LearningEngine.markReview(progress, wordId: wordId, today: today)
        progress = recordActivity(in: changed) { counters in
            if correct { counters.quizCorrect += 1 } else { counters.quizWrong += 1 }
            counters.englishActions += 1
        }
        scheduleSave()
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
        let progress = progress, sets = customSets, settings = settings, persistence = persistence
        Task.detached(priority: .utility) {
            persistence.save(progress, to: "progress.json")
            persistence.save(sets, to: "custom-sets.json")
            persistence.save(settings, to: "settings.json")
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
