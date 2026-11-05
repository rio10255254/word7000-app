import Foundation

// WordCat Next: the rules behind the home page. Two pillars, words and
// speaking, one of them shown as the big card; the week as a card of
// stamps; the words mastered as a shelf of fourteen chapters; and which
// words a quiz outside today's routine asks about.

/// The two things the app teaches.
public enum Pillar: String, Codable, Sendable, CaseIterable {
    case words, speaking
}

public enum HomeLayout {
    /// The pillar shown as the big card. The one the learner wants first
    /// leads until it is done for today, then the other while it is not;
    /// with both done, words (where an extra round waits). Without the
    /// speaking card, always words.
    public static func lead(preferred: Pillar, wordsDone: Bool, speakingDone: Bool, speakingShown: Bool) -> Pillar {
        guard speakingShown else { return .words }
        switch preferred {
        case .words: return wordsDone && !speakingDone ? .speaking : .words
        case .speaking: return speakingDone ? .words : .speaking
        }
    }
}

/// One day on the week's stamp card.
public struct WeekStamp: Equatable, Sendable {
    public enum Mark: String, Sendable {
        /// Studied that day: stamped.
        case studied
        /// Missed, but streak protection kept the streak: the cat's can.
        case covered
        /// Missed.
        case missed
        /// Today, not studied yet.
        case today
        /// Later this week.
        case ahead
    }

    public var date: String
    public var mark: Mark

    public init(date: String, mark: Mark) {
        self.date = date
        self.mark = mark
    }
}

public enum WeekStamps {
    /// Monday is 0, Sunday 6.
    public static func weekdayIndex(_ date: String) -> Int? {
        // Day 0 (1970-01-01) was a Thursday.
        DayMath.dayNumber(date).map { (($0 + 3) % 7 + 7) % 7 }
    }

    /// Monday to Sunday of the week holding `today`.
    public static func week(today: String, analytics: LearningAnalyticsState?, coveredDay: String?) -> [WeekStamp] {
        guard let number = DayMath.dayNumber(today), let weekday = weekdayIndex(today) else { return [] }
        let analytics = analytics ?? LearningAnalyticsState()
        return (0..<7).map { offset in
            let date = DayMath.string(fromDayNumber: number - weekday + offset)
            let studied = analytics.day(date).practiceActions > 0
            let mark: WeekStamp.Mark
            if offset > weekday {
                mark = .ahead
            } else if studied {
                mark = .studied
            } else if offset == weekday {
                mark = .today
            } else {
                mark = date == coveredDay ? .covered : .missed
            }
            return WeekStamp(date: date, mark: mark)
        }
    }
}

/// One chapter of the core list (a Core level, 500 words) on the shelf.
public struct ShelfChapter: Equatable, Sendable {
    public var group: String
    public var total: Int
    public var mastered: Int

    public init(group: String, total: Int, mastered: Int) {
        self.group = group
        self.total = total
        self.mastered = mastered
    }

    public var fraction: Double { total > 0 ? Double(mastered) / Double(total) : 0 }
}

public enum MasteryShelf {
    /// A chapter counts as read once this much of it is mastered.
    public static let readFraction = 0.8

    /// Each level in the order the words list them, with how many of its
    /// words are mastered.
    public static func chapters(words: [WordEntry], state: ProgressState) -> [ShelfChapter] {
        var order: [String] = []
        var totals: [String: (total: Int, mastered: Int)] = [:]
        for word in words {
            if totals[word.group] == nil { order.append(word.group) }
            var count = totals[word.group] ?? (0, 0)
            count.total += 1
            if state.words[word.id]?.status == .mastered { count.mastered += 1 }
            totals[word.group] = count
        }
        return order.map { ShelfChapter(group: $0, total: totals[$0]!.total, mastered: totals[$0]!.mastered) }
    }

    /// The chapter being read: the first one not yet read through.
    public static func current(_ chapters: [ShelfChapter]) -> Int? {
        chapters.firstIndex { $0.fraction < readFraction }
    }
}

/// A short quiz of exam-style questions outside today's routine.
public enum ExamRoundKind: String, Codable, Sendable {
    /// From the word card: words already learned, those due soonest first.
    case quick
    /// Sundays: the words studied this week.
    case weekly
}

public enum ExamRound {
    public static let quickCount = 10
    public static let weeklyCount = 15
    /// Fewer words than this make no quiz worth starting.
    public static let minimumWords = 4

    /// The words to ask about, in the order to ask them. Only words with an
    /// example sentence to blank out are asked.
    public static func pick(_ kind: ExamRoundKind, words: [WordEntry], state: ProgressState, today: String, seed: String) -> [String] {
        let askable = words.filter { Cloze.sentence(for: $0) != nil }
        switch kind {
        case .quick:
            let learned = askable.compactMap { word -> (id: String, due: String, stage: Int)? in
                let saved = state.words[word.id]
                guard let saved, saved.status != .new else { return nil }
                return (word.id, LearningEngine.reviewDueDate(saved) ?? today, LearningEngine.reviewStage(saved))
            }
            // The ones about to slip first; a seeded shuffle among them so two
            // quizzes on the same day differ.
            let soonest = learned.sorted {
                $0.due != $1.due ? $0.due < $1.due : $0.stage != $1.stage ? $0.stage < $1.stage : $0.id < $1.id
            }
            let pool = soonest.prefix(max(quickCount * 2, 20)).map(\.id)
            return Array(SeededRandom.shuffle(pool, seed: seed).prefix(quickCount))
        case .weekly:
            let ids = studiedThisWeek(askable, state: state, today: today)
            return Array(SeededRandom.shuffle(ids, seed: seed).prefix(weeklyCount))
        }
    }

    /// How many words a quiz of this kind could ask about now.
    public static func available(_ kind: ExamRoundKind, words: [WordEntry], state: ProgressState, today: String) -> Int {
        let askable = words.filter { Cloze.sentence(for: $0) != nil }
        switch kind {
        case .quick: return askable.filter { (state.words[$0.id]?.status ?? .new) != .new }.count
        case .weekly: return studiedThisWeek(askable, state: state, today: today).count
        }
    }

    /// Sunday's weekly quiz is offered when the week gave it enough words.
    public static func weeklyDue(words: [WordEntry], state: ProgressState, today: String) -> Bool {
        WeekStamps.weekdayIndex(today) == 6 && available(.weekly, words: words, state: state, today: today) >= minimumWords
    }

    private static func studiedThisWeek(_ words: [WordEntry], state: ProgressState, today: String) -> [String] {
        guard let start = DayMath.addDays(today, -6) else { return [] }
        return words.compactMap { word in
            guard let saved = state.words[word.id], saved.status != .new,
                  let last = saved.lastStudied, last >= start, last <= today else { return nil }
            return word.id
        }
    }
}
