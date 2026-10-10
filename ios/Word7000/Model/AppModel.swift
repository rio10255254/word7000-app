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

    func studyWords(filter: FilterSelection) -> [WordEntry] {
        bank.filter(state: progress, query: "", filter: filter.status, options: filter.options)
    }

    /// The current session, or a fresh one when there is none or the bank or
    /// filters changed since it was built.
    func ensureStudySession() {
        let key = studySourceKey
        if let session = studySession, session.sourceKey == key { return }
        startStudySession()
    }

    var studySourceKey: String {
        "\(settings.activeBankId)|\(settings.studyFilter.status.rawValue)|\(settings.studyFilter.level)|\(settings.studyFilter.initial)"
    }

    func startStudySession(onlyIds: [String]? = nil) {
        let candidates: [WordEntry]
        if let onlyIds {
            let wanted = Set(onlyIds)
            candidates = bank.words.filter { wanted.contains($0.id) }
        } else {
            candidates = studyWords(filter: settings.studyFilter)
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
