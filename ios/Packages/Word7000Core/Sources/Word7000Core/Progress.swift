import Foundation

public enum WordStatus: String, Codable, Sendable {
    case new, mastered, review
}

public enum LibraryFilter: String, Codable, CaseIterable, Sendable {
    case all, favorites, review, mastered, new
}

public enum LibrarySort: String, Codable, Sendable {
    case `default`, alphabetical
}

/// What the learner has done with one word. Field names and optionality
/// match the stored JSON of the React Native app.
public struct WordProgress: Codable, Equatable, Sendable {
    public var status: WordStatus
    public var favorite: Bool
    public var difficult: Bool
    public var reviewCount: Int
    /// Next date (YYYY-MM-DD) the word should come back for review.
    public var dueDate: String?
    public var favoritedAt: String?
    public var favoriteUpdatedAt: String?
    /// How many times a word that was already known slipped back to review.
    public var lapses: Int?
    public var lastStudied: String?
    /// Spaced-repetition box: 0 means "still learning", higher waits longer.
    public var stage: Int?
    public var statusUpdatedAt: String?

    public init(
        status: WordStatus = .new,
        favorite: Bool = false,
        difficult: Bool = false,
        reviewCount: Int = 0,
        dueDate: String? = nil,
        favoritedAt: String? = nil,
        favoriteUpdatedAt: String? = nil,
        lapses: Int? = nil,
        lastStudied: String? = nil,
        stage: Int? = nil,
        statusUpdatedAt: String? = nil
    ) {
        self.status = status
        self.favorite = favorite
        self.difficult = difficult
        self.reviewCount = reviewCount
        self.dueDate = dueDate
        self.favoritedAt = favoritedAt
        self.favoriteUpdatedAt = favoriteUpdatedAt
        self.lapses = lapses
        self.lastStudied = lastStudied
        self.stage = stage
        self.statusUpdatedAt = statusUpdatedAt
    }

    public static let fresh = WordProgress()
}

public struct ProgressState: Codable, Equatable, Sendable {
    public var analytics: LearningAnalyticsState?
    public var dailyTarget: Int
    public var streak: Int
    public var studiedToday: Int
    public var dailyProgressDate: String?
    public var lastStudyDate: String?
    public var words: [String: WordProgress]

    public init(
        analytics: LearningAnalyticsState? = nil,
        dailyTarget: Int = 20,
        streak: Int = 0,
        studiedToday: Int = 0,
        dailyProgressDate: String? = nil,
        lastStudyDate: String? = nil,
        words: [String: WordProgress] = [:]
    ) {
        self.analytics = analytics
        self.dailyTarget = dailyTarget
        self.streak = streak
        self.studiedToday = studiedToday
        self.dailyProgressDate = dailyProgressDate
        self.lastStudyDate = lastStudyDate
        self.words = words
    }

    public static let empty = ProgressState()

    public func progress(for wordId: String) -> WordProgress {
        words[wordId] ?? .fresh
    }
}

public struct ProgressStats: Equatable, Sendable {
    public var due: Int
    public var mastered: Int
    public var review: Int
    public var favorites: Int
    public var remaining: Int
    public var studiedToday: Int
}

/// The spaced-repetition rules, ported one-to-one from `src/lib/progress.ts`.
public enum LearningEngine {
    /// Days to wait before a word comes back, indexed by stage. A word marked
    /// "still learning" drops to stage 0 and is due again the same day; every
    /// correct recall pushes it one stage further out.
    public static let reviewIntervalDays = [0, 1, 3, 7, 14, 30, 60, 120]
    public static var maxReviewStage: Int { reviewIntervalDays.count - 1 }
    /// A new word the learner already recognises on first sight skips the
    /// short intervals: re-showing it tomorrow would only be noise.
    static let knownOnFirstSightStage = 3
    /// Picking the right meaning out of four is recognition, not recall, so a
    /// first-time correct quiz answer earns a much shorter wait.
    static let recognisedInQuizStage = 1

    public static func reviewStage(_ progress: WordProgress?) -> Int {
        guard let progress, progress.status != .new else { return 0 }
        if let stage = progress.stage {
            return max(0, min(maxReviewStage, stage))
        }
        // Progress saved before scheduling existed: treat mastered words as a
        // week old and struggling words as due now.
        return progress.status == .mastered ? knownOnFirstSightStage : 0
    }

    public static func reviewDueDate(_ progress: WordProgress?) -> String? {
        guard let progress, progress.status != .new else { return nil }
        if let due = progress.dueDate { return due }
        guard let anchor = progress.lastStudied ?? progress.statusUpdatedAt.map({ String($0.prefix(10)) }) else {
            return "0000-00-00"
        }
        return DayMath.addDays(anchor, reviewIntervalDays[reviewStage(progress)]) ?? anchor
    }

    public static func isDue(_ progress: WordProgress?, today: String) -> Bool {
        guard let due = reviewDueDate(progress) else { return false }
        return due <= today
    }

    // MARK: Grading

    public static func markKnown(_ state: ProgressState, wordId: String, today: String, changedAt: String = DayMath.timestamp()) -> ProgressState {
        grade(state, wordId: wordId, today: today, changedAt: changedAt, firstSightStage: knownOnFirstSightStage)
    }

    public static func markQuizCorrect(_ state: ProgressState, wordId: String, today: String, changedAt: String = DayMath.timestamp()) -> ProgressState {
        grade(state, wordId: wordId, today: today, changedAt: changedAt, firstSightStage: recognisedInQuizStage)
    }

    static func grade(_ state: ProgressState, wordId: String, today: String, changedAt: String, firstSightStage: Int) -> ProgressState {
        updateWord(state, wordId: wordId, studiedDate: today) { progress in
            // Seeing a word twice in one day is not spaced practice: keep the
            // stage it earned earlier today instead of climbing several boxes.
            let alreadyGradedToday = progress.lastStudied == today && progress.status == .mastered
            let stage: Int
            if progress.status == .new {
                stage = firstSightStage
            } else if alreadyGradedToday {
                stage = reviewStage(progress)
            } else {
                stage = min(maxReviewStage, max(1, reviewStage(progress) + 1))
            }
            var next = progress
            next.status = .mastered
            next.difficult = false
            next.dueDate = DayMath.addDays(today, reviewIntervalDays[stage]) ?? today
            next.lastStudied = today
            next.stage = stage
            next.statusUpdatedAt = changedAt
            return next
        }
    }

    public static func markReview(_ state: ProgressState, wordId: String, today: String, changedAt: String = DayMath.timestamp()) -> ProgressState {
        updateWord(state, wordId: wordId, studiedDate: today) { progress in
            var next = progress
            next.status = .review
            next.difficult = true
            next.dueDate = today
            next.lapses = (progress.lapses ?? 0) + (progress.status == .mastered ? 1 : 0)
            next.reviewCount = progress.reviewCount + 1
            next.lastStudied = today
            next.stage = 0
            next.statusUpdatedAt = changedAt
            return next
        }
    }

    public static func toggleFavorite(_ state: ProgressState, wordId: String, changedAt: String = DayMath.timestamp()) -> ProgressState {
        updateWord(state, wordId: wordId, studiedDate: nil) { progress in
            var next = progress
            next.favorite.toggle()
            next.favoriteUpdatedAt = changedAt
            next.favoritedAt = next.favorite ? changedAt : nil
            return next
        }
    }

    static func updateWord(
        _ state: ProgressState,
        wordId: String,
        studiedDate: String?,
        update: (WordProgress) -> WordProgress
    ) -> ProgressState {
        let previous = state.progress(for: wordId)
        // The daily goal counts distinct words. Marking the same card again (a
        // re-queued miss, an undo and redo) must not fill the goal by itself.
        var base = state
        if let studiedDate {
            let counts = previous.lastStudied != studiedDate
            base = advanceDailyProgress(state, today: studiedDate, increment: counts ? 1 : 0)
        }
        base.words[wordId] = update(base.progress(for: wordId))
        return base
    }

    // MARK: Daily progress and streak

    public static func normalizeForDate(_ state: ProgressState, today: String) -> ProgressState {
        var next = state
        if next.dailyProgressDate != today {
            next.dailyProgressDate = today
            next.studiedToday = 0
        }
        if let last = next.lastStudyDate, last != today, !DayMath.isPreviousDay(last, of: today) {
            next.streak = 0
        }
        return next
    }

    public static func recordPracticeDay(_ state: ProgressState, today: String) -> ProgressState {
        advanceDailyProgress(state, today: today, increment: 0)
    }

    static func advanceDailyProgress(_ state: ProgressState, today: String, increment: Int) -> ProgressState {
        var next = normalizeForDate(state, today: today)
        if next.lastStudyDate != today {
            if let last = next.lastStudyDate, DayMath.isPreviousDay(last, of: today) {
                next.streak = max(1, next.streak + 1)
            } else {
                next.streak = 1
            }
        }
        next.dailyProgressDate = today
        next.lastStudyDate = today
        next.studiedToday += increment
        return next
    }

    // MARK: Merging (sync)

    public static func merge(_ states: [ProgressState?]) -> ProgressState {
        let available = states.compactMap { $0 }
        guard var dailySource = available.first else { return .empty }
        for candidate in available.dropFirst() {
            let latestDate = dailySource.dailyProgressDate ?? dailySource.lastStudyDate ?? ""
            let candidateDate = candidate.dailyProgressDate ?? candidate.lastStudyDate ?? ""
            if candidateDate > latestDate || (candidateDate == latestDate && candidate.studiedToday > dailySource.studiedToday) {
                dailySource = candidate
            }
        }

        var words: [String: WordProgress] = [:]
        for state in available {
            for (wordId, progress) in state.words {
                words[wordId] = words[wordId].map { mergeWord($0, progress) } ?? progress
            }
        }

        return ProgressState(
            analytics: LearningAnalyticsState.merge(available.map(\.analytics)),
            dailyTarget: dailySource.dailyTarget,
            streak: dailySource.streak,
            studiedToday: dailySource.studiedToday,
            dailyProgressDate: dailySource.dailyProgressDate,
            lastStudyDate: dailySource.lastStudyDate,
            words: words
        )
    }

    static func mergeWord(_ first: WordProgress, _ second: WordProgress) -> WordProgress {
        let firstStatusTime = first.statusUpdatedAt ?? first.lastStudied ?? ""
        let secondStatusTime = second.statusUpdatedAt ?? second.lastStudied ?? ""
        let statusSource = secondStatusTime > firstStatusTime ? second : first
        let firstFavoriteTime = first.favoriteUpdatedAt ?? first.favoritedAt ?? ""
        let secondFavoriteTime = second.favoriteUpdatedAt ?? second.favoritedAt ?? ""
        let favoriteSource = secondFavoriteTime > firstFavoriteTime ? second : first
        let lastStudied = [first.lastStudied, second.lastStudied].compactMap { $0 }.filter { !$0.isEmpty }.max()
        let lapses = (first.lapses ?? 0) != 0 || (second.lapses ?? 0) != 0
            ? max(first.lapses ?? 0, second.lapses ?? 0)
            : nil

        return WordProgress(
            status: statusSource.status,
            favorite: favoriteSource.favorite,
            difficult: statusSource.difficult,
            reviewCount: max(first.reviewCount, second.reviewCount),
            dueDate: statusSource.dueDate,
            favoritedAt: favoriteSource.favorite ? favoriteSource.favoritedAt : nil,
            favoriteUpdatedAt: favoriteSource.favoriteUpdatedAt,
            lapses: lapses,
            lastStudied: lastStudied,
            stage: statusSource.stage,
            statusUpdatedAt: statusSource.statusUpdatedAt
        )
    }

    // MARK: Stats

    public static func stats(words: [WordEntry], state: ProgressState, today: String?) -> ProgressStats {
        let ids = Set(words.map(\.id))
        return stats(wordCount: words.count, contains: ids.contains, state: state, today: today)
    }

    /// The same counts for a prepared list, looked up in its index instead of
    /// a set of every id built on each call.
    public static func stats(vocabulary: PreparedVocabulary, state: ProgressState, today: String?) -> ProgressStats {
        stats(wordCount: vocabulary.words.count, contains: { vocabulary.index(of: $0) != nil }, state: state, today: today)
    }

    static func stats(wordCount: Int, contains: (String) -> Bool, state: ProgressState, today: String?) -> ProgressStats {
        var due = 0, mastered = 0, review = 0, favorites = 0
        for (wordId, progress) in state.words where contains(wordId) {
            if progress.status == .mastered { mastered += 1 } else if progress.status == .review { review += 1 }
            if progress.favorite { favorites += 1 }
            if let today, isDue(progress, today: today) { due += 1 }
        }
        return ProgressStats(
            due: due,
            mastered: mastered,
            review: review,
            favorites: favorites,
            remaining: wordCount - mastered - review,
            studiedToday: state.studiedToday
        )
    }

    // MARK: Study queue

    /// Picks the cards for one study session. Words due for review come first
    /// (oldest due date first), then words never seen before in library
    /// order, and only when both run out does it pull known words ahead of
    /// their schedule. The chosen cards are then shuffled so reviews and new
    /// words mix.
    public static func buildStudyQueue(words: [WordEntry], state: ProgressState, today: String, limit: Int, seed: String = SeededRandom.runtimeSeed()) -> [WordEntry] {
        let size = max(0, limit)
        guard size > 0, !words.isEmpty else { return [] }

        var due: [(date: String, word: WordEntry, struggling: Bool, order: Int)] = []
        var fresh: [WordEntry] = []
        var ahead: [(date: String, word: WordEntry, order: Int)] = []
        for (order, word) in words.enumerated() {
            let progress = state.words[word.id]
            guard let dueDate = reviewDueDate(progress) else {
                fresh.append(word)
                continue
            }
            if dueDate <= today {
                due.append((dueDate, word, progress?.status == .review, order))
            } else {
                ahead.append((dueDate, word, order))
            }
        }
        due.sort {
            if $0.date != $1.date { return $0.date < $1.date }
            if $0.struggling != $1.struggling { return $0.struggling }
            return $0.order < $1.order
        }
        ahead.sort { $0.date != $1.date ? $0.date < $1.date : $0.order < $1.order }

        let chosen = Array((due.map(\.word) + fresh + ahead.map(\.word)).prefix(size))
        return SeededRandom.shuffle(chosen, seed: "\(seed):queue")
    }

    /// How many new and review cards `buildStudyQueue` would pick, counted
    /// without sorting, copying or shuffling the words.
    public static func studyQueueCounts(words: [WordEntry], state: ProgressState, today: String, limit: Int) -> (fresh: Int, review: Int, total: Int) {
        let size = max(0, limit)
        guard size > 0 else { return (0, 0, 0) }
        var due = 0, fresh = 0, ahead = 0
        for word in words {
            guard let dueDate = reviewDueDate(state.words[word.id]) else {
                fresh += 1
                continue
            }
            if dueDate <= today { due += 1 } else { ahead += 1 }
        }
        // Due words fill the queue first, then new ones, then words ahead of schedule.
        let total = min(size, due + fresh + ahead)
        let chosenFresh = min(fresh, max(0, size - due))
        return (chosenFresh, total - chosenFresh, total)
    }
}
