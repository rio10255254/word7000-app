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
    /// The last missed day covered by the shared seven-day streak protection.
    public var streakFreezeDate: String?
    /// When the daily goal was last changed, so the newest change wins a
    /// sync instead of whichever device studied more that day.
    public var dailyTargetUpdatedAt: String?

    public init(
        analytics: LearningAnalyticsState? = nil,
        dailyTarget: Int = 20,
        streak: Int = 0,
        studiedToday: Int = 0,
        dailyProgressDate: String? = nil,
        lastStudyDate: String? = nil,
        words: [String: WordProgress] = [:],
        streakFreezeDate: String? = nil,
        dailyTargetUpdatedAt: String? = nil
    ) {
        self.analytics = analytics
        self.dailyTarget = dailyTarget
        self.streak = streak
        self.studiedToday = studiedToday
        self.dailyProgressDate = dailyProgressDate
        self.lastStudyDate = lastStudyDate
        self.words = words
        self.streakFreezeDate = streakFreezeDate
        self.dailyTargetUpdatedAt = dailyTargetUpdatedAt
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
            } else if alreadyGradedToday || !isDue(progress, today: today) {
                // Recalling a word before it is due shows little about whether
                // the longer wait would hold: keep its box and restart the wait
                // from today. Small banks pull such words in every session, and
                // climbing a box each time sent them 120 days out within a week.
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
        // A last study day after today (synced from a device in a zone ahead,
        // travel westwards, a clock set wrong) is not a missed day.
        if let last = next.lastStudyDate, last < today, !DayMath.isPreviousDay(last, of: today) {
            if next.streak > 0, let missed = DayMath.addDays(today, -1), DayMath.isPreviousDay(last, of: missed),
               StreakProtection.covers(missed: missed, in: next) {
                next.streakFreezeDate = missed
            } else {
                next.streak = 0
            }
        }
        return next
    }

    public static func recordPracticeDay(_ state: ProgressState, today: String) -> ProgressState {
        advanceDailyProgress(state, today: today, increment: 0)
    }

    static func advanceDailyProgress(_ state: ProgressState, today: String, increment: Int) -> ProgressState {
        var next = normalizeForDate(state, today: today)
        // Only a first study on a later day moves the streak on. A last study
        // day already today or after it has counted, and is never moved back.
        if next.lastStudyDate.map({ $0 < today }) ?? true {
            if let last = next.lastStudyDate, DayMath.isPreviousDay(last, of: today) || StreakProtection.bridges(last, to: today, in: next) {
                next.streak = max(1, next.streak + 1)
            } else {
                next.streak = 1
            }
            next.lastStudyDate = today
        }
        next.dailyProgressDate = today
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

        // Each device counts only the words it studied itself. The same day on
        // two devices covers every word whose last study is that day.
        var studiedToday = dailySource.studiedToday
        if let day = dailySource.dailyProgressDate {
            studiedToday = max(studiedToday, words.values.reduce(0) { $0 + ($1.lastStudied == day ? 1 : 0) })
        }

        let streak = StreakProtection.reconcile(available, fallback: dailySource)
        // The goal last changed on purpose wins; a goal never changed since
        // this field came in follows the day's source, as before.
        let goalSource = available.filter { $0.dailyTargetUpdatedAt != nil }
            .max { ($0.dailyTargetUpdatedAt ?? "") < ($1.dailyTargetUpdatedAt ?? "") }
        return ProgressState(
            analytics: LearningAnalyticsState.merge(available.map(\.analytics)),
            dailyTarget: goalSource?.dailyTarget ?? dailySource.dailyTarget,
            streak: streak.streak,
            studiedToday: studiedToday,
            dailyProgressDate: dailySource.dailyProgressDate,
            lastStudyDate: streak.lastStudyDate,
            words: words,
            // The latest use on any device, so protection is never used twice in a week.
            streakFreezeDate: streak.streakFreezeDate,
            dailyTargetUpdatedAt: goalSource?.dailyTargetUpdatedAt
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
    /// (oldest due date first), then words never seen before picked at random
    /// from the whole pool, and only when both run out does it pull known
    /// words ahead of their schedule. The chosen cards are then shuffled so reviews and new
    /// words mix.
    /// Share of a session kept for new words while any are left. Without it,
    /// a learner whose reviews pile up stops meeting new words at all: after
    /// a week of 20 a day every session was all reviews, and for anyone who
    /// started when new words came in library order, all of them Core 1.
    /// Two in five, rounded up; whole numbers so no rounding error decides it.
    public static let newWordShare = (numerator: 2, denominator: 5)

    /// The level a group stands for ("Core 7" is 7), or nil for other groups.
    public static func coreLevel(_ group: String) -> Int? {
        guard group.hasPrefix("Core "), let level = Int(group.dropFirst(5)), level >= 0 else { return nil }
        return level
    }

    // For a word `d` half-levels above the learner (-6 to 6), the chance in
    // percent that it is known on sight is 95 92 88 82 73 62 50 38 27 18 12 8 5.
    // These are the natural logs of that chance and of its complement, times
    // 1000 and rounded, so the estimate is the same whole-number sum everywhere.
    static let knownLog = [-51, -83, -128, -198, -315, -478, -693, -968, -1309, -1715, -2120, -2526, -2996]
    static let missedLog = [-2996, -2526, -2120, -1715, -1309, -968, -693, -478, -315, -198, -128, -83, -51]
    /// Where the estimate starts before any answers, in half-levels: Core 4.
    public static let abilityPrior = 8

    /// The learner's level, in half-levels (14 means Core 7), from the words
    /// they have met: the level that best explains which ones they knew on
    /// sight and which they did not, pulled gently towards Core 4 while there
    /// is little to go on. It moves with every answer, so it follows the
    /// learner as they grow.
    public static func estimateAbility(_ levels: [(level: Int, seen: Int, knew: Int)]) -> Int {
        let top = levels.map { $0.level }.max() ?? 0
        guard top > 0 else { return abilityPrior }
        var best = abilityPrior
        var bestScore = Int.min
        for ability in 0...max(2 * top + 2, 2 * abilityPrior) {
            var score = -30 * (ability - abilityPrior) * (ability - abilityPrior)
            for entry in levels where entry.seen > 0 {
                let index = min(6, max(-6, 2 * entry.level - ability)) + 6
                score += entry.knew * knownLog[index] + (entry.seen - entry.knew) * missedLog[index]
            }
            if score > bestScore {
                bestScore = score
                best = ability
            }
        }
        return best
    }

    /// The learner's estimated level over a word list (see `estimateAbility`),
    /// and how many of its Core words they have met, which says how much the
    /// estimate rests on.
    public static func abilityEstimate(words: [WordEntry], state: ProgressState) -> (ability: Int, seen: Int) {
        var counts: [Int: (seen: Int, knew: Int)] = [:]
        for word in words {
            guard let level = coreLevel(word.group) else { continue }
            var count = counts[level] ?? (0, 0)
            if let progress = state.words[word.id], progress.status != .new {
                count.seen += 1
                if progress.status == .mastered, progress.reviewCount == 0 { count.knew += 1 }
            }
            counts[level] = count
        }
        let levels = counts.keys.sorted().map { (level: $0, seen: counts[$0]!.seen, knew: counts[$0]!.knew) }
        return (estimateAbility(levels), levels.reduce(0) { $0 + $1.seen })
    }

    /// The Core levels new words are drawn from most for this ability.
    public static func favouredLevels(ability: Int, top: Int = 14) -> ClosedRange<Int> {
        let low = min(top, max(1, (ability + 2) / 2))
        let high = min(top, max(low, (ability + 4) / 2))
        return low...high
    }

    /// How strongly to draw new words from a level, by how far it is from the
    /// learner (`ability` in half-levels): a level or two above is drawn most,
    /// where words are new but within reach; the learner's own level less;
    /// easier levels less and less the further below they are, even for words
    /// the learner does not know yet; much harder levels only now and then.
    /// Groups that are not Core levels (a scanned bank, your own words) all
    /// count the same.
    public static func newWordLevelWeight(level: Int?, ability: Int) -> Int {
        guard let level else { return 6 }
        let distance = 2 * level - ability
        switch distance {
        case ...(-6): return 1
        case ...(-4): return 2
        case ...(-2): return 4
        case ...0: return 6
        case ...4: return 10
        case ...6: return 3
        default: return 1
        }
    }

    /// Draws `count` new words: each pick chooses a level by its weight among
    /// the levels with new words left, then that level's next word in a seeded
    /// random order. With a single level this is simply the shuffled order.
    static func pickNewWords(_ fresh: [WordEntry], count: Int, levelOrder: [String],
                             levels: [String: (seen: Int, knew: Int)], seed: String) -> [WordEntry] {
        guard count > 0, !fresh.isEmpty else { return [] }
        var buckets: [String: [WordEntry]] = [:]
        for word in SeededRandom.shuffle(fresh, seed: "\(seed):fresh") { buckets[word.group, default: []].append(word) }
        let ability = estimateAbility(levelOrder.compactMap { group -> (level: Int, seen: Int, knew: Int)? in
            guard let level = coreLevel(group), let counts = levels[group] else { return nil }
            return (level, counts.seen, counts.knew)
        })
        let order = levelOrder.filter { buckets[$0] != nil }
        let weights = order.map { newWordLevelWeight(level: coreLevel($0), ability: ability) }
        var taken = Array(repeating: 0, count: order.count)
        var picked: [WordEntry] = []
        var state = SeededRandom.hash("\(seed):levels")
        while picked.count < count {
            var total = 0
            for (index, group) in order.enumerated() where taken[index] < buckets[group]!.count { total += weights[index] }
            guard total > 0 else { break }
            state = SeededRandom.next(state)
            var roll = Int(SeededRandom.scramble(state) % UInt32(total))
            for (index, group) in order.enumerated() {
                let bucket = buckets[group]!
                guard taken[index] < bucket.count else { continue }
                if roll < weights[index] {
                    picked.append(bucket[taken[index]])
                    taken[index] += 1
                    break
                }
                roll -= weights[index]
            }
        }
        return picked
    }

    /// How many of a session's `size` cards go to new words: whatever the
    /// due reviews leave, but at least `newWordShare` of it while any are left.
    /// Reviews that do not fit stay due for the next session.
    static func newWordSlots(size: Int, due: Int, fresh: Int) -> Int {
        let share = (size * newWordShare.numerator + newWordShare.denominator - 1) / newWordShare.denominator
        return min(fresh, max(size - due, share))
    }

    public static func buildStudyQueue(words: [WordEntry], state: ProgressState, today: String, limit: Int, seed: String = SeededRandom.runtimeSeed()) -> [WordEntry] {
        let size = max(0, limit)
        guard size > 0, !words.isEmpty else { return [] }

        var due: [(date: String, word: WordEntry, struggling: Bool, order: Int)] = []
        var fresh: [WordEntry] = []
        // Due words already studied today (a word missed earlier today stays
        // due) wait until after the new ones, so the next session does not
        // open with the cards just practised.
        var seenToday: [(date: String, word: WordEntry, struggling: Bool, order: Int)] = []
        var ahead: [(date: String, word: WordEntry, order: Int)] = []
        // Per level, in the order levels first appear: words seen, and words
        // known the first time they were met (never missed since).
        var levelOrder: [String] = []
        var levels: [String: (seen: Int, knew: Int)] = [:]
        for (order, word) in words.enumerated() {
            let progress = state.words[word.id]
            if levels[word.group] == nil {
                levelOrder.append(word.group)
                levels[word.group] = (0, 0)
            }
            if let progress, progress.status != .new {
                levels[word.group]!.seen += 1
                if progress.status == .mastered, progress.reviewCount == 0 { levels[word.group]!.knew += 1 }
            }
            guard let dueDate = reviewDueDate(progress) else {
                fresh.append(word)
                continue
            }
            if dueDate <= today {
                if progress?.lastStudied == today {
                    seenToday.append((dueDate, word, progress?.status == .review, order))
                } else {
                    due.append((dueDate, word, progress?.status == .review, order))
                }
            } else {
                ahead.append((dueDate, word, order))
            }
        }
        let byDue: ((date: String, word: WordEntry, struggling: Bool, order: Int), (date: String, word: WordEntry, struggling: Bool, order: Int)) -> Bool = {
            if $0.date != $1.date { return $0.date < $1.date }
            if $0.struggling != $1.struggling { return $0.struggling }
            return $0.order < $1.order
        }
        due.sort(by: byDue)
        seenToday.sort(by: byDue)
        ahead.sort { $0.date != $1.date ? $0.date < $1.date : $0.order < $1.order }

        let newCount = newWordSlots(size: size, due: due.count, fresh: fresh.count)
        let chosen = Array((due.prefix(size - newCount).map(\.word)
            + pickNewWords(fresh, count: newCount, levelOrder: levelOrder, levels: levels, seed: seed)
            + seenToday.map(\.word) + ahead.map(\.word)).prefix(size))
        return SeededRandom.shuffle(chosen, seed: "\(seed):queue")
    }

    /// How many new and review cards `buildStudyQueue` would pick, counted
    /// without sorting, copying or shuffling the words.
    public static func studyQueueCounts(words: [WordEntry], state: ProgressState, today: String, limit: Int) -> (fresh: Int, review: Int, total: Int) {
        let size = max(0, limit)
        guard size > 0 else { return (0, 0, 0) }
        var due = 0, fresh = 0, later = 0
        for word in words {
            let progress = state.words[word.id]
            guard let dueDate = reviewDueDate(progress) else {
                fresh += 1
                continue
            }
            if dueDate <= today, progress?.lastStudied != today { due += 1 } else { later += 1 }
        }
        // Due words and new ones (at least their share) fill the queue first,
        // then due words already studied today and words ahead of schedule.
        let total = min(size, due + fresh + later)
        let chosenFresh = newWordSlots(size: size, due: due, fresh: fresh)
        return (chosenFresh, total - chosenFresh, total)
    }
}

/// Forgives one missed day at most once a week, so a single busy day does
/// not wipe out a long streak. The missed day itself does not add to it.
public enum StreakProtection {
    public static let cooldownDays = 7

    /// Carry counts only across evidenced study-day continuity, then expire at
    /// the latest observed day. A legacy daily reset is not a new study event.
    public static func reconcile(_ states: [ProgressState], fallback: ProgressState) -> ProgressState {
        func latestValidDate(_ dates: [String?]) -> String? {
            dates.compactMap { $0 }.filter { DayMath.dayNumber($0) != nil }.max()
        }
        var result = fallback
        result.streakFreezeDate = latestValidDate(states.map(\.streakFreezeDate))
        guard let last = latestValidDate(states.map(\.lastStudyDate)),
              let lastDay = DayMath.dayNumber(last) else { return result }
        result.lastStudyDate = last
        result.streak = 0
        var protectedStreak = 0
        for state in states {
            guard state.streak > 0, let source = state.lastStudyDate,
                  let sourceDay = DayMath.dayNumber(source) else { continue }
            let gap = lastDay - sourceDay
            if gap == 0 || gap == 1 {
                result.streak = max(result.streak, state.streak + gap)
            } else if gap == 2 {
                protectedStreak = max(protectedStreak, state.streak + 1)
            }
        }
        // A stale snapshot must not spend protection when the newer count
        // already accounts for continuity through the intervening day.
        if protectedStreak > result.streak, let missed = DayMath.addDays(last, -1), covers(missed: missed, in: result) {
            result.streak = protectedStreak
            result.streakFreezeDate = missed
        }
        let observedDay = latestValidDate(states.flatMap { [$0.dailyProgressDate, $0.lastStudyDate] }) ?? last
        return LearningEngine.normalizeForDate(result, today: observedDay)
    }

    /// Whether `missed` can be covered: protection is unused for a week, or
    /// already covers that very day.
    public static func covers(missed: String, in state: ProgressState) -> Bool {
        guard let missedDay = DayMath.dayNumber(missed) else { return false }
        guard let used = state.streakFreezeDate, let usedDay = DayMath.dayNumber(used) else { return true }
        return usedDay == missedDay || missedDay - usedDay >= cooldownDays
    }

    /// Whether studying `today` continues a streak last kept on `last`, with
    /// the one day between them covered.
    static func bridges(_ last: String, to today: String, in state: ProgressState) -> Bool {
        guard let covered = state.streakFreezeDate else { return false }
        return DayMath.isPreviousDay(last, of: covered) && DayMath.isPreviousDay(covered, of: today)
    }

    /// Whether protection could cover a missed day starting from `day`.
    public static func isAvailable(on day: String, in state: ProgressState) -> Bool {
        covers(missed: day, in: state) && state.streakFreezeDate != day
    }

    /// Protection covered yesterday and the learner has not studied yet today.
    public static func justUsed(in state: ProgressState, today: String) -> Bool {
        guard state.streak > 0, let covered = state.streakFreezeDate, (state.lastStudyDate ?? "") < today else { return false }
        return DayMath.isPreviousDay(covered, of: today)
    }
}
