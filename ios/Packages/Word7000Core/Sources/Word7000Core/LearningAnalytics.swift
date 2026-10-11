import Foundation

public struct DailyLearningCounters: Codable, Equatable, Sendable {
    public var activeSeconds = 0
    public var chineseActions = 0
    public var englishActions = 0
    public var otherActions = 0
    public var quizCorrect = 0
    public var quizWrong = 0
    public var speakingCompleted = 0
    public var speakingSkipped = 0
    public var sessions = 0
    public var studyKnown = 0
    public var studyReview = 0

    public init() {}

    static let keyPaths: [WritableKeyPath<DailyLearningCounters, Int>] = [
        \.activeSeconds, \.chineseActions, \.englishActions, \.otherActions, \.quizCorrect, \.quizWrong,
        \.speakingCompleted, \.speakingSkipped, \.sessions, \.studyKnown, \.studyReview,
    ]

    /// Learning actions that count toward the daily goal.
    public var goalActions: Int { otherActions + quizCorrect + quizWrong + studyKnown + studyReview }
    public var practiceActions: Int { goalActions + speakingCompleted }
    public var totalActions: Int { goalActions + speakingCompleted + speakingSkipped }
}

public struct DailyLearningActivity: Identifiable, Equatable, Sendable {
    public var date: String
    public var counters: DailyLearningCounters
    public var id: String { date }
    public var words: Int { counters.studyKnown + counters.studyReview }
    public var speaking: Int { counters.speakingCompleted }
    public var other: Int { counters.otherActions + counters.quizCorrect + counters.quizWrong }
    public var total: Int { words + speaking + other }
}

/// Per-day activity counters, kept per device ("source") so two devices
/// syncing the same day never double count.
public struct LearningAnalyticsState: Codable, Equatable, Sendable {
    public var bestStreak: Int
    public var days: [String: [String: DailyLearningCounters]]
    public var version: Int

    public init(bestStreak: Int = 0, days: [String: [String: DailyLearningCounters]] = [:], version: Int = 1) {
        self.bestStreak = bestStreak
        self.days = days
        self.version = version
    }

    public static func merge(_ states: [LearningAnalyticsState?]) -> LearningAnalyticsState? {
        let available = states.compactMap { $0 }
        guard !available.isEmpty else { return nil }
        var merged = LearningAnalyticsState()
        for state in available {
            merged.bestStreak = max(merged.bestStreak, state.bestStreak)
            for (date, sources) in state.days {
                var mergedSources = merged.days[date] ?? [:]
                for (source, counters) in sources {
                    if let existing = mergedSources[source] {
                        var maximum = DailyLearningCounters()
                        for key in DailyLearningCounters.keyPaths {
                            maximum[keyPath: key] = max(existing[keyPath: key], counters[keyPath: key])
                        }
                        mergedSources[source] = maximum
                    } else {
                        mergedSources[source] = counters
                    }
                }
                merged.days[date] = mergedSources
            }
        }
        return merged
    }

    public func day(_ date: String) -> DailyLearningCounters {
        var total = DailyLearningCounters()
        for counters in (days[date] ?? [:]).values {
            for key in DailyLearningCounters.keyPaths {
                total[keyPath: key] += counters[keyPath: key]
            }
        }
        return total
    }

    public func activity(endingOn date: String, dayCount: Int) -> [DailyLearningActivity] {
        (0..<max(0, dayCount)).reversed().map { back in
            let key = DayMath.addDays(date, -back) ?? date
            return DailyLearningActivity(date: key, counters: day(key))
        }
    }

    public mutating func record(date: String, source: String, _ change: (inout DailyLearningCounters) -> Void) {
        var sources = days[date] ?? [:]
        var counters = sources[source] ?? DailyLearningCounters()
        change(&counters)
        sources[source] = counters
        days[date] = sources
    }
}
