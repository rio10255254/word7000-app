import Foundation

/// Speaking practice as a path of short stages, one a day: each stage is a
/// few words, and each word is said after the model first, then answered in
/// the learner's own words.
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
        /// Stars of each cleared stage, first stage first.
        public var stars: [Int]
        /// The day the latest stage was cleared.
        public var lastDay: String?
        /// Days in a row with a cleared stage, up to `lastDay`.
        public var streak: Int

        public init(stars: [Int] = [], lastDay: String? = nil, streak: Int = 0) {
            self.stars = stars
            self.lastDay = lastDay
            self.streak = streak
        }

        public var cleared: Int { stars.count }
        /// The stage being played next.
        public var nextStage: Int { cleared + 1 }

        public func clearedToday(_ today: String) -> Bool { lastDay == today }

        /// The streak as it stands today: kept while today or yesterday had a stage.
        public func currentStreak(today: String) -> Int {
            guard let lastDay else { return 0 }
            return lastDay == today || DayMath.isPreviousDay(lastDay, of: today) ? streak : 0
        }

        /// After clearing the next stage today.
        public func clearing(stars earned: Int, today: String) -> Progress {
            var next = self
            next.stars.append(max(1, min(3, earned)))
            if lastDay != today {
                next.streak = currentStreak(today: today) + 1
                next.lastDay = today
            }
            return next
        }
    }
}
