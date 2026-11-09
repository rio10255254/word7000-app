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
    /// The chapter the level test placed the learner at: new Core words come
    /// from it on, and the easier chapters are skipped (nil: no test taken).
    public var startChapter: Int?
    /// The study mode that test was in ("english" or "chinese"): the start
    /// chapter only applies to that mode's words.
    public var startMode: String?
    /// The exam the learner prepares for (`WelcomeExam`'s raw value: gsat,
    /// tvee, cap, proficiency or none), which names the exam-style questions.
    public var exam: String?
    /// Added later: the start chapter and the spelling score for each study
    /// mode ("english", "chinese"), so a test or spelling in one mode leaves
    /// the other's alone. A profile from before has one of each
    /// (`startChapter` for `startMode`, `spelling`); `forMode` reads those
    /// until `update(mode:with:)` first keeps a mode's own.
    public var startChapters: [String: Int]?
    public var spellingScores: [String: Double]?

    /// The study modes a profile keeps a start and a spelling score for.
    public static let modes = ["english", "chinese"]

    public init(stage: Stage? = nil, focus: [Focus] = [], spelling: Double? = nil) {
        self.stage = stage
        self.focus = focus
        self.spelling = spelling
    }

    /// This mode's own start chapter and spelling score, in `startChapter`
    /// and `spelling` (with `startMode` set to the mode); everything else is
    /// shared by both modes.
    public func forMode(_ mode: String) -> LearnerProfile {
        var copy = self
        copy.startChapter = startChapters.map { $0[mode] } ?? legacyStart(for: mode)
        copy.spelling = spellingScores.map { $0[mode] } ?? legacySpelling(for: mode)
        copy.startMode = mode
        return copy
    }

    /// Keeps `changed` (a `forMode(mode)` copy, then changed): its start
    /// chapter and spelling score for this mode only, the rest for both. The
    /// single fields keep the latest too, for builds that know only those.
    public mutating func update(mode: String, with changed: LearnerProfile) {
        var starts = startChapters ?? [:]
        var scores = spellingScores ?? [:]
        // The first time: what the profile had goes to the mode it was for.
        for other in Self.modes where other != mode {
            if startChapters == nil { starts[other] = legacyStart(for: other) }
            if spellingScores == nil { scores[other] = legacySpelling(for: other) }
        }
        starts[mode] = changed.startChapter
        scores[mode] = changed.spelling
        stage = changed.stage
        focus = changed.focus
        exam = changed.exam
        startChapters = starts
        spellingScores = scores
        startChapter = changed.startChapter
        startMode = mode
        spelling = changed.spelling
    }

    /// Before per-mode values: the one start, for the mode its test was in
    /// (any mode when that was not kept).
    private func legacyStart(for mode: String) -> Int? {
        startMode == nil || startMode == mode ? startChapter : nil
    }

    /// Before per-mode values: the one score, measured in the start's mode.
    private func legacySpelling(for mode: String) -> Double? {
        startMode == nil || startMode == mode ? spelling : nil
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
    /// The daily goal: new words and reviews together.
    public let wordsPerDay: Int
    /// New words a day over the first month, on average, by the same rules
    /// a session is built with (`LearningEngine.projectedNewWords`): all of
    /// the goal at first, then less as reviews come back, never under two in five.
    public let newPerDay: Int
    public let spellChecks: Int
    public let examChecks: Int
    public let lead: Pillar
    /// The chapter reached by the exam, when there is a date.
    public let reachChapter: Int?

    /// The level test sets the chapter; words recognised but not spelled
    /// start one chapter lower, so new words are not all too hard to write.
    /// `levelSizes`: words in each chapter of the list studied (see
    /// `PlacementTest.levelSizes(of:)`). `studiedFrom`: words from a chapter
    /// on that are studied already (a retest), covered before the new ones.
    public init(test: PlacementTest, profile: LearnerProfile, target: Int, daysToExam: Int?,
                levelSizes: [Int] = PlacementTest.englishLevelSizes, studiedFrom: (Int) -> Int = { _ in 0 }) {
        var chapter = test.answers.isEmpty ? 1 : test.startChapter
        if let spelling = profile.spelling, spelling < 0.34, chapter > 1 { chapter -= 1 }
        startChapter = chapter
        wordsPerDay = target
        let month = LearningEngine.projectedNewWords(state: ProgressState(), today: "2026-01-01", dailyTarget: target,
                                                     days: 30, freshAvailable: Int.max / 2)
        newPerDay = max(1, (month + 15) / 30)
        spellChecks = profile.spellChecks
        examChecks = profile.examChecks
        lead = profile.lead
        reachChapter = daysToExam.map { days in
            PlacementTest.chaptersReached(from: chapter, newWords: studiedFrom(chapter) + LearningEngine.projectedNewWords(
                state: ProgressState(), today: "2026-01-01", dailyTarget: target, days: days, freshAvailable: Int.max / 2),
                levelSizes: levelSizes)
        }
    }
}
