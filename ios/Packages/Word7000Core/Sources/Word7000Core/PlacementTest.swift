import Foundation

/// WordCat Next: the first-launch level check as a short adaptive test. A
/// word, four meanings and "don't know"; the next word comes from a harder
/// chapter after a right answer and an easier one after a miss, the jump
/// halving each time the direction turns. It starts at Core 1, so the first
/// answer is almost always right, asks at most fifteen and stops early once
/// it has settled. The level comes from the same estimate the study queue
/// uses, so new words then start where the test left off.
public struct PlacementTest: Equatable, Sendable {
    public static let maxQuestions = 15
    /// It does not stop before this many, however settled.
    public static let minQuestions = 8
    public static let topLevel = 14
    /// Words in a Core level.
    public static let wordsPerLevel = 500

    public struct Answer: Equatable, Sendable {
        public let wordId: String
        public let level: Int
        public let knew: Bool
    }

    public private(set) var answers: [Answer] = []
    /// The Core level to ask next.
    public private(set) var level = 1
    private var jump = 4
    private var lastDirection = 0
    /// How many times the answers turned from right to wrong or back.
    public private(set) var turns = 0

    public init() {}

    /// A test that starts in `chapter`: from what the learner said about
    /// school, so it reaches their level in fewer questions.
    public init(start chapter: Int) {
        level = min(Self.topLevel, max(1, chapter))
    }

    public var asked: Int { answers.count }

    public var isFinished: Bool {
        asked >= Self.maxQuestions || (asked >= Self.minQuestions && jump == 1 && turns >= 3)
    }

    public mutating func record(wordId: String, level asked: Int, knew: Bool) {
        answers.append(Answer(wordId: wordId, level: asked, knew: knew))
        let direction = knew ? 1 : -1
        if lastDirection != 0, direction != lastDirection {
            turns += 1
            jump = max(1, jump / 2)
        }
        lastDirection = direction
        level = min(Self.topLevel, max(1, asked + direction * jump))
    }

    /// The learner's level in half-levels, as `LearningEngine.estimateAbility`.
    public var ability: Int {
        var counts: [Int: (seen: Int, knew: Int)] = [:]
        for answer in answers {
            var count = counts[answer.level] ?? (0, 0)
            count.seen += 1
            if answer.knew { count.knew += 1 }
            counts[answer.level] = count
        }
        return LearningEngine.estimateAbility(counts.keys.sorted().map { (level: $0, seen: counts[$0]!.seen, knew: counts[$0]!.knew) })
    }

    /// The chance a word of `level` is known at this ability, from the same
    /// model as the estimate.
    public static func knownChance(level: Int, ability: Int) -> Double {
        let index = min(6, max(-6, 2 * level - ability)) + 6
        return exp(Double(LearningEngine.knownLog[index]) / 1000)
    }

    /// How much of each Core level the learner likely knows, easy to hard.
    public var levelShares: [Double] {
        let ability = ability
        return (1...Self.topLevel).map { Self.knownChance(level: $0, ability: ability) }
    }

    /// Words in each Core level of the 7000-word list, easy to hard.
    public static let englishLevelSizes = Array(repeating: wordsPerLevel, count: topLevel)

    /// Words in each Core level of `words`, easy to hard: the 7000-word list
    /// has 500 in each; the Taiwan Mandarin bank about 2900 in all, fewer in
    /// its easy levels.
    public static func levelSizes(of words: [WordEntry]) -> [Int] {
        var sizes = Array(repeating: 0, count: topLevel)
        for word in words {
            if let level = LearningEngine.coreLevel(word.group), (1...topLevel).contains(level) { sizes[level - 1] += 1 }
        }
        return sizes
    }

    /// About how many of the list's words the learner knows, to the nearest
    /// fifty (ten for a list under 5000 words).
    public func estimatedKnownWords(levelSizes: [Int] = englishLevelSizes) -> Int {
        let total = zip(levelShares, levelSizes).reduce(0) { $0 + $1.0 * Double($1.1) }
        let step = levelSizes.reduce(0, +) < 5000 ? 10.0 : 50.0
        return Int((total / step).rounded() * step)
    }

    /// The 7000-word list's estimate.
    public var estimatedKnownWords: Int { estimatedKnownWords() }

    /// The chapter to start in: the first one less than about two thirds known.
    public var startChapter: Int {
        (levelShares.firstIndex { $0 < 0.65 } ?? (Self.topLevel - 1)) + 1
    }

    /// The words answered right, to count as known on sight.
    public var knownIds: [String] { answers.filter(\.knew).map(\.wordId) }

    /// A word to ask at `level`: one not asked yet, a single word, in a
    /// seeded order. For learners of Chinese the prompt is the Chinese, so
    /// that is what must be short.
    public static func word(at level: Int, from words: [WordEntry], asked: Set<String>, seed: String, chinese: Bool = false) -> WordEntry? {
        let candidates = words.filter { word in
            guard LearningEngine.coreLevel(word.group) == level, !asked.contains(word.id) else { return false }
            return chinese
                ? (1...4).contains(word.meaningZh.count) && !word.meaningZh.contains(where: { "；;，,、".contains($0) })
                : word.word.count <= 12 && word.word.allSatisfy(\.isLetter)
        }
        return SeededRandom.shuffle(candidates, seed: "\(seed):placement-test:\(level)").first
    }

    /// After the meanings, a few words to spell: from the chapter the test
    /// settled on, single words with a sentence to blank and a Chinese cue,
    /// none of them already asked.
    public func spellingWords(from words: [WordEntry], count: Int = 3, seed: String) -> [WordEntry] {
        let asked = Set(answers.map(\.wordId))
        let chapter = answers.isEmpty ? 1 : startChapter
        for level in [chapter, chapter - 1, chapter + 1, 1] where (1...Self.topLevel).contains(level) {
            let candidates = words.filter { word in
                LearningEngine.coreLevel(word.group) == level && !asked.contains(word.id)
                    && word.word.count <= 10 && word.word.allSatisfy(\.isLetter)
                    && Cloze.sentence(for: word) != nil && Cloze.cue(for: word) != nil
            }
            if candidates.count >= count {
                return Array(SeededRandom.shuffle(candidates, seed: "\(seed):placement-spelling").prefix(count))
            }
        }
        return []
    }

    /// The chapter reached after meeting `newWords` new words from the start
    /// of `chapter` on, through levels of `levelSizes` words: a chapter
    /// counts once all of it has been met.
    public static func chaptersReached(from chapter: Int, newWords: Int, levelSizes: [Int] = englishLevelSizes) -> Int {
        var reached = min(topLevel, max(1, chapter))
        var left = max(0, newWords)
        while reached < topLevel {
            let size = reached - 1 < levelSizes.count ? levelSizes[reached - 1] : wordsPerLevel
            guard left >= size else { break }
            left -= size
            reached += 1
        }
        return reached
    }

    /// How many chapters `wordsPerDay` new words a day covers in `days`.
    public static func chaptersReached(from chapter: Int, wordsPerDay: Int, days: Int, levelSizes: [Int] = englishLevelSizes) -> Int {
        chaptersReached(from: chapter, newWords: max(0, wordsPerDay) * max(0, days), levelSizes: levelSizes)
    }
}
