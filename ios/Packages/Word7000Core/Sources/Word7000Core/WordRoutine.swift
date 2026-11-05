import Foundation

/// Today's words as one routine: flip the cards, then spell the words just
/// marked "I know it" that are still young, then answer exam-style questions
/// on the older ones. Every self-graded "I know it" can be spot-checked in
/// the way that suits it: spelling for a word just met, a four-choice
/// sentence (the shape of the 學測 vocabulary questions) for one learned a
/// while ago. Words marked "not yet" skip the checks, so a hard day is not
/// made harder.
public struct WordRoutine: Codable, Equatable, Sendable {
    public enum Step: String, Codable, Sendable {
        case flip, spell, exam, done
    }

    /// At most this many spelling questions and exam questions a day: the
    /// checks sample the words marked known rather than test them all.
    public static let maxSpell = 6
    public static let maxExam = 5
    /// From this review stage on, a word is old enough for exam questions.
    public static let examStage = 3

    /// The words of the flip cards, in order.
    public let cardIds: [String]
    /// Each word's review stage when the cards were dealt; a word not here
    /// was new.
    public let stagesBefore: [String: Int]
    /// The study session this routine belongs to (`StudySession.sourceKey`).
    public let sourceKey: String
    public let day: String

    public private(set) var step: Step = .flip
    public private(set) var knownIds: [String] = []
    public private(set) var unsureIds: [String] = []
    public private(set) var spellIds: [String] = []
    public private(set) var examIds: [String] = []
    /// How each spelling check went, and whether each exam question was right.
    public private(set) var spellResults: [String: ClozeRound.Outcome] = [:]
    public private(set) var examResults: [String: Bool] = [:]

    public init(cardIds: [String], stagesBefore: [String: Int], sourceKey: String, day: String) {
        var seen = Set<String>()
        self.cardIds = cardIds.filter { seen.insert($0).inserted }
        self.stagesBefore = stagesBefore
        self.sourceKey = sourceKey
        self.day = day
    }

    public func wasNew(_ wordId: String) -> Bool { stagesBefore[wordId] == nil }

    /// After the flip cards: picks the words to check. `canSpell` and
    /// `canExam` say whether a word can be asked that way (it has an example
    /// sentence with the word in it, and enough look-alike words to choose from).
    public mutating func planChecks(knownIds: [String], unsureIds: [String],
                                    canSpell: (String) -> Bool, canExam: (String) -> Bool) {
        guard step == .flip else { return }
        self.knownIds = knownIds
        self.unsureIds = unsureIds
        let order = Dictionary(uniqueKeysWithValues: cardIds.enumerated().map { ($1, $0) })
        let young = knownIds.filter { (stagesBefore[$0] ?? -1) < Self.examStage }
        let old = knownIds.filter { (stagesBefore[$0] ?? -1) >= Self.examStage }
        // New words first: they are the ones the flip card alone vouches for.
        spellIds = young.filter(canSpell)
            .sorted { (stagesBefore[$0] ?? -1, order[$0] ?? 0) < (stagesBefore[$1] ?? -1, order[$1] ?? 0) }
            .prefix(Self.maxSpell).map { $0 }
        examIds = old.filter(canExam).sorted { (order[$0] ?? 0) < (order[$1] ?? 0) }.prefix(Self.maxExam).map { $0 }
        step = !spellIds.isEmpty ? .spell : !examIds.isEmpty ? .exam : .done
    }

    /// How a spelling check went (the first answer counts).
    public mutating func recordSpell(_ wordId: String, outcome: ClozeRound.Outcome) {
        guard step == .spell, spellIds.contains(wordId), spellResults[wordId] == nil else { return }
        spellResults[wordId] = outcome
    }

    public mutating func finishSpell() {
        guard step == .spell else { return }
        step = examIds.isEmpty ? .done : .exam
    }

    public mutating func recordExam(_ wordId: String, correct: Bool) {
        guard step == .exam, examIds.contains(wordId), examResults[wordId] == nil else { return }
        examResults[wordId] = correct
    }

    public mutating func finishExam() {
        guard step == .exam else { return }
        step = .done
    }

    /// Leaves the rest of the checks for another day.
    public mutating func skipChecks() {
        guard step == .spell || step == .exam else { return }
        step = .done
    }

    /// Spelling questions not yet answered, in order.
    public var spellLeft: [String] { spellIds.filter { spellResults[$0] == nil } }
    public var examLeft: [String] { examIds.filter { examResults[$0] == nil } }

    /// Words marked known that a check showed were not: missed spellings
    /// and wrong exam answers.
    public var caughtIds: [String] {
        spellIds.filter { spellResults[$0] == .missed } + examIds.filter { examResults[$0] == false }
    }

    public struct Summary: Equatable, Sendable {
        /// New words the learner already knew (marked known and not caught).
        public var alreadyKnew = 0
        /// New words learned today: marked not yet, or caught.
        public var learned = 0
        /// Words studied before, seen again.
        public var reviewed = 0
        /// Words marked known that a check caught.
        public var caught = 0
        /// Checks asked.
        public var checked = 0

        public init(alreadyKnew: Int = 0, learned: Int = 0, reviewed: Int = 0, caught: Int = 0, checked: Int = 0) {
            self.alreadyKnew = alreadyKnew
            self.learned = learned
            self.reviewed = reviewed
            self.caught = caught
            self.checked = checked
        }
    }

    public var summary: Summary {
        let caught = Set(caughtIds)
        var summary = Summary()
        for id in cardIds {
            if !wasNew(id) { summary.reviewed += 1; continue }
            if knownIds.contains(id), !caught.contains(id) { summary.alreadyKnew += 1 }
            else if knownIds.contains(id) || unsureIds.contains(id) { summary.learned += 1 }
        }
        summary.caught = caught.count
        summary.checked = spellResults.count + examResults.count
        return summary
    }
}

extension LearningEngine {
    /// The schedule after a spot check of a word just marked known. Right
    /// straight away leaves it as the flip card set it. A new word that took
    /// a little help comes back tomorrow rather than in a week. A miss sends
    /// the word back to review, like "not yet" would have.
    public static func applyCheck(_ state: ProgressState, wordId: String, today: String,
                                  wasNew: Bool, outcome: ClozeRound.Outcome,
                                  changedAt: String = DayMath.timestamp()) -> ProgressState {
        switch outcome {
        case .knew:
            return state
        case .gotIt:
            guard wasNew else { return state }
            var next = state
            var progress = state.progress(for: wordId)
            progress.stage = recognisedInQuizStage
            progress.dueDate = DayMath.addDays(today, reviewIntervalDays[recognisedInQuizStage]) ?? today
            progress.statusUpdatedAt = changedAt
            next.words[wordId] = progress
            return next
        case .missed:
            return markReview(state, wordId: wordId, today: today, changedAt: changedAt)
        }
    }
}

/// A question in the shape of the 學測 vocabulary section: the word's own
/// example sentence with the word taken out, and four words to choose from.
/// The wrong ones look like the answer (adapt, adopt, admit, adjust) but
/// mean something else, so the meaning decides, not the spelling.
public struct ExamQuestion: Equatable, Sendable {
    public let wordId: String
    public let sentence: Cloze.Sentence
    public let options: [String]
    public let answerIndex: Int

    public var answer: String { options[answerIndex] }
}

/// The word list prepared once for picking exam options: each single word's
/// spelling, part of speech, senses and level, grouped by part of speech.
/// Building it walks the whole list; asking for a question then only looks
/// at words of the same part of speech.
public struct ExamPool: Sendable {
    struct Item: Sendable {
        let text: String
        let letters: [Character]
        let senses: [String]
        let level: Int?
        /// The spelling's hash, mixed with a question's seed to order ties.
        let hash: UInt32
    }

    let items: [String: [Item]]

    public init(_ words: [WordEntry]) {
        var items: [String: [Item]] = [:]
        var seen = Set<String>()
        for word in words {
            let text = Spelling.normalized(word.word)
            guard text.count >= 2, text.allSatisfy(\.isLetter), seen.insert(text).inserted else { continue }
            let pos = QuizBuilder.primaryPartOfSpeech(word.partOfSpeech)
            items[pos, default: []].append(Item(text: text, letters: Array(text),
                                                senses: ExamQuestions.trimmedSenses(ExamQuestions.senses(word)),
                                                level: LearningEngine.coreLevel(word.group),
                                                hash: SeededRandom.hash(text)))
        }
        self.items = items
    }
}

public enum ExamQuestions {
    public static let optionCount = 4

    /// A question for `word`, with wrong options drawn from `pool`, or nil
    /// when the word is a phrase, has no sentence with it, or too few words
    /// could stand in for it.
    public static func make(for word: WordEntry, pool: [WordEntry], seed: String) -> ExamQuestion? {
        make(for: word, pool: ExamPool(pool), seed: seed)
    }

    public static func make(for word: WordEntry, pool: ExamPool, seed: String) -> ExamQuestion? {
        guard let sentence = Cloze.sentence(for: word) else { return nil }
        let answer = Spelling.normalized(word.word)
        guard answer.count >= 2, answer.allSatisfy(\.isLetter) else { return nil }
        let pos = QuizBuilder.primaryPartOfSpeech(word.partOfSpeech)
        let senses = trimmedSenses(Self.senses(word) + (Cloze.cue(for: word).map { [$0.cue] } ?? []))
        let contrast = WordNotes.note(for: answer)?.contrast
        let level = LearningEngine.coreLevel(word.group)
        let letters = Array(answer)
        let stem = answer.dropLast()

        // Rank every word of the same part of speech by how much it looks
        // like the answer (ties in a seeded order), then walk down the list
        // and keep the first few that are not another form of the answer and
        // do not share a sense with it. Only those few need the slower checks.
        let seedHash = SeededRandom.hash(seed)
        var scored: [(score: Int, order: UInt32, item: ExamPool.Item)] = []
        for item in pool.items[pos] ?? [] where item.text != answer {
            var score = similarity(letters, item.letters)
            if item.text == contrast { score += 20 }
            if let level, let other = item.level, abs(level - other) <= 2 { score += 1 }
            scored.append((score, SeededRandom.scramble(item.hash ^ seedHash), item))
        }
        scored.sort { $0.score != $1.score ? $0.score > $1.score : $0.order < $1.order }
        var candidates: [(score: Int, order: UInt32, text: String)] = []
        for entry in scored where candidates.count < 12 {
            let item = entry.item
            // Another form of the answer starts like it ("adapt", "adapted").
            if item.text.hasPrefix(stem) || answer.hasPrefix(item.text.dropLast()),
               Cloze.isOtherForm(item.text, of: answer) { continue }
            guard !overlaps(senses, item.senses) else { continue }
            candidates.append((entry.score, entry.order, item.text))
        }
        // The look-alikes first; a seeded shuffle among the closest keeps the
        // same question from always offering the same three.
        let ranked = candidates
        guard ranked.count >= optionCount - 1 else { return nil }
        let pinned = ranked.prefix { $0.text == contrast }.map(\.text)
        let close = ranked.filter { $0.text != contrast }.prefix(6).map(\.text)
        let wrong = Array((pinned + SeededRandom.shuffle(close, seed: "\(seed):pick")).prefix(optionCount - 1))
        guard wrong.count == optionCount - 1 else { return nil }

        // Options take the sentence's capitalisation (a blank that starts it).
        let capitalised = sentence.answer.first?.isUppercase ?? false
        let shape: (String) -> String = { capitalised ? $0.prefix(1).uppercased() + $0.dropFirst() : $0 }
        let options = SeededRandom.shuffle([sentence.answer] + wrong.map(shape), seed: "\(seed):order")
        guard let answerIndex = options.firstIndex(of: sentence.answer) else { return nil }
        return ExamQuestion(wordId: word.id, sentence: sentence, options: options, answerIndex: answerIndex)
    }

    static func senses(_ word: WordEntry) -> [String] {
        ChineseDisplay.meaningParts(word.meaningZh) + ChineseDisplay.meaningParts(word.supplementalMeaningZh ?? "")
    }

    /// Two words share a sense when a meaning of one is, or contains, a
    /// meaning of the other ("調整" in both adapt and adjust). One-character
    /// senses only count when equal, since "有" sits inside many words.
    static func sharesSense(_ a: [String], _ b: [String]) -> Bool {
        overlaps(trimmedSenses(a), trimmedSenses(b))
    }

    /// Senses without "的" (辛辣的 and 辛辣 are the same sense).
    static func trimmedSenses(_ senses: [String]) -> [String] {
        senses.map { $0.replacingOccurrences(of: "的", with: "").trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    static func overlaps(_ left: [String], _ right: [String]) -> Bool {
        for x in left {
            for y in right {
                if x == y { return true }
                if x.count >= 2, y.count >= 2, x.contains(y) || y.contains(x) { return true }
            }
        }
        return false
    }

    /// How much two spellings look alike: a shared start, a small edit
    /// distance, a similar length and a shared ending.
    static func similarity(_ a: String, _ b: String) -> Int {
        similarity(Array(a), Array(b))
    }

    static func similarity(_ x: [Character], _ y: [Character]) -> Int {
        var prefix = 0
        while prefix < min(x.count, y.count), x[prefix] == y[prefix] { prefix += 1 }
        var score = 2 * min(prefix, 3)
        let lengthGap = abs(x.count - y.count)
        // The distance is at least the length gap, and from 3 on it adds
        // nothing, so only close lengths are worth measuring.
        if lengthGap < 3 { score += max(0, 8 - 3 * editDistance(x, y)) }
        score += lengthGap == 0 ? 2 : lengthGap <= 2 ? 1 : 0
        if x.count >= 3, y.count >= 3, x.suffix(2) == y.suffix(2) { score += 1 }
        return score
    }

    static func editDistance(_ a: [Character], _ b: [Character]) -> Int {
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            previous = current
        }
        return previous[b.count]
    }
}
