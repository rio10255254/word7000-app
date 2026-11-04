import Foundation

/// Speaking practice as a path of short stages, one a day (the everyday
/// scenarios, in order), each item said after a model first and then in the
/// learner's own words. Word practice clears stages too, for the streak.
public enum SpeakingPath {
    public static let wordsPerStage = 5

    /// How a cleared stage went, for its stars.
    public struct Result: Equatable, Sendable {
        public var words: Int
        /// Model sentences said well enough.
        public var shadowed: Int
        /// Questions answered out loud or in writing.
        public var answered: Int

        public init(words: Int, shadowed: Int = 0, answered: Int = 0) {
            self.words = words
            self.shadowed = shadowed
            self.answered = answered
        }

        /// Anything said at all clears the stage.
        public var cleared: Bool { shadowed + answered > 0 }

        /// One for clearing it, one for saying every model sentence, one for
        /// answering every question.
        public var stars: Int {
            guard cleared else { return 0 }
            return 1 + (shadowed >= words ? 1 : 0) + (answered >= words ? 1 : 0)
        }
    }

    /// One learner's path in one study mode.
    public struct Progress: Codable, Equatable, Sendable {
        /// The best stars of each played stage, by stage key.
        public var best: [String: Int]
        /// The day the latest stage was cleared.
        public var lastDay: String?
        /// Days in a row with a cleared stage, up to `lastDay`.
        public var streak: Int

        public init(best: [String: Int] = [:], lastDay: String? = nil, streak: Int = 0) {
            self.best = best
            self.lastDay = lastDay
            self.streak = streak
        }

        public func stars(_ key: String) -> Int { best[key] ?? 0 }
        public var cleared: Int { best.values.filter { $0 > 0 }.count }

        public func clearedToday(_ today: String) -> Bool { lastDay == today }

        /// The streak as it stands today: kept while today or yesterday had a stage.
        public func currentStreak(today: String) -> Int {
            guard let lastDay else { return 0 }
            return lastDay == today || DayMath.isPreviousDay(lastDay, of: today) ? streak : 0
        }

        /// After clearing a stage today: its best stars (when it is a stage
        /// of the path; word practice has none) and the day's streak.
        public func clearing(_ key: String?, stars earned: Int, today: String) -> Progress {
            var next = self
            if let key, !key.isEmpty {
                next.best[key] = max(stars(key), max(1, min(3, earned)))
            }
            if lastDay != today {
                next.streak = currentStreak(today: today) + 1
                next.lastDay = today
            }
            return next
        }
    }
}
