import Foundation

/// WordCat Next: what the first launch learns about the learner, and how it
/// shapes each day. Every answer changes something the learner can see:
/// where the level test starts, which exam is counted down, which pillar
/// leads, how many spelling and exam-style checks follow the cards. The
/// spelling score starts from three words spelled on the first launch and
/// then follows every routine's spelling, so the checks grow when spelling
/// slips and shrink when it is solid.
///
/// It is stored beside the settings and only ever added to: a build that
/// does not know it drops it, and the learner gets the defaults back.
public struct LearnerProfile: Codable, Equatable, Sendable {
    /// Where the learner is in school, or that they work.
    public enum Stage: String, Codable, CaseIterable, Sendable {
        case juniorHigh, senior1, senior2, senior3, university, working

        /// The chapter the level test starts in: a little under the usual
        /// for this stage, so the first word is almost always known.
        public var testStart: Int {
            switch self {
            case .juniorHigh, .senior1: 1
            case .senior2, .working: 2
            case .senior3, .university: 3
            }
        }

        /// The exam most learners at this stage prepare for (`WelcomeExam`'s raw value).
        public var suggestedExam: String {
            switch self {
            case .juniorHigh: "cap"
            case .senior1, .senior2, .senior3: "gsat"
            case .university, .working: "proficiency"
            }
        }
    }

    /// What the learner most wants to get better at; each one changes the day.
    public enum Focus: String, Codable, CaseIterable, Sendable {
        /// More new words a day.
        case vocabulary
        /// More spelling checks after the cards.
        case spelling
        /// More exam-style questions after the cards.
        case exam
        /// Speaking first on the home page.
        case speaking
    }

    /// The learner picks at most this many.
    public static let maxFocus = 2

    public var stage: Stage?
    public var focus: [Focus]
    /// How well the words marked known are spelled, 0 to 1 (nil: not measured yet).
    public var spelling: Double?

    public init(stage: Stage? = nil, focus: [Focus] = [], spelling: Double? = nil) {
        self.stage = stage
        self.focus = focus
        self.spelling = spelling
    }

    /// Picks or unpicks a focus; a third pick replaces the oldest.
    public mutating func toggle(_ item: Focus) {
        if let index = focus.firstIndex(of: item) {
            focus.remove(at: index)
        } else {
            focus.append(item)
            if focus.count > Self.maxFocus { focus.removeFirst(focus.count - Self.maxFocus) }
        }
    }

    /// Which pillar leads the day: speaking when it was picked and words were not.
    public var lead: Pillar {
        focus.contains(.speaking) && !focus.contains(.vocabulary) ? .speaking : .words
    }

    /// The daily goal to suggest.
    public var suggestedTarget: Int { focus.contains(.vocabulary) ? 30 : 20 }

    /// Spelling questions after the cards: more for a spelling focus or weak
    /// spelling, fewer when spelling is solid.
    public var spellChecks: Int {
        var count = WordRoutine.maxSpell
        if focus.contains(.spelling) { count += 2 }
        if let spelling {
            if spelling < 0.5 { count += 2 } else if spelling >= 0.9, !focus.contains(.spelling) { count -= 2 }
        }
        return min(10, max(3, count))
    }

    /// Exam-style questions after the cards.
    public var examChecks: Int { WordRoutine.maxExam + (focus.contains(.exam) ? 3 : 0) }

    /// How one spelling went, 0 to 1: right first time, right with help, or missed.
    public static func score(_ outcome: ClozeRound.Outcome) -> Double {
        switch outcome {
        case .knew: 1
        case .gotIt: 0.5
        case .missed: 0
        }
    }

    /// The first measure sets the score; later ones move it a third of the way.
    public mutating func recordSpelling(_ outcomes: [ClozeRound.Outcome]) {
        guard !outcomes.isEmpty else { return }
        let average = outcomes.map(Self.score).reduce(0, +) / Double(outcomes.count)
        spelling = spelling.map { $0 * 2 / 3 + average / 3 } ?? average
    }
}

/// WordCat Next: the plan the first launch ends with, in the learner's own
/// numbers.
public struct PersonalPlan: Equatable, Sendable {
    public let startChapter: Int
    public let newPerDay: Int
    public let spellChecks: Int
    public let examChecks: Int
    public let lead: Pillar
    /// The chapter reached by the exam, when there is a date.
    public let reachChapter: Int?

    /// The level test sets the chapter; words recognised but not spelled
    /// start one chapter lower, so new words are not all too hard to write.
    public init(test: PlacementTest, profile: LearnerProfile, target: Int, daysToExam: Int?) {
        var chapter = test.answers.isEmpty ? 1 : test.startChapter
        if let spelling = profile.spelling, spelling < 0.34, chapter > 1 { chapter -= 1 }
        startChapter = chapter
        newPerDay = target
        spellChecks = profile.spellChecks
        examChecks = profile.examChecks
        lead = profile.lead
        reachChapter = daysToExam.map { PlacementTest.chaptersReached(from: chapter, wordsPerDay: target, days: $0) }
    }
}
