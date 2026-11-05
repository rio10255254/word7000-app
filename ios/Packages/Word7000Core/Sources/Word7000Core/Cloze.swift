import Foundation

/// A fill-in-the-blank question built from a word's example sentence: the
/// Chinese translation on top with the word's part highlighted, the English
/// sentence below with the word blanked out, and the learner types the word.
///
/// Typing the word back, in a sentence, is recall rather than recognition, so
/// it is the main question of a round. A miss is never a dead end: the learner
/// can ask for the first letter, then the answer, and still has to type it.
public enum Cloze {

    // MARK: The English sentence

    public enum Piece: Equatable, Sendable {
        case text(String)
        case blank
    }

    public struct Sentence: Equatable, Sendable {
        /// The sentence in order; every place the word appears is a blank.
        public let pieces: [Piece]
        /// The word as the sentence spells it the first time, e.g. "Adapt" at
        /// the start of a sentence.
        public let answer: String
    }

    /// The example sentence with the word blanked out, or nil when the word
    /// does not appear in it as a whole word (a suffix such as "tion", or a
    /// custom word whose example uses another form).
    public static func sentence(for word: WordEntry) -> Sentence? {
        blanked(word.example, word: word.word)
    }

    static func blanked(_ sentence: String, word: String) -> Sentence? {
        let target = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard target.count >= 1, target.contains(where: \.isLetter) else { return nil }
        var pieces: [Piece] = []
        var answer: String?
        var rest = sentence[...]
        while let found = rest.range(of: target, options: [.caseInsensitive]) {
            let before = found.lowerBound == sentence.startIndex ? nil : sentence[sentence.index(before: found.lowerBound)]
            let after = found.upperBound == sentence.endIndex ? nil : sentence[found.upperBound]
            // Whole words only: "art" is not in "start".
            guard !(before?.isLetter ?? false), !(after?.isLetter ?? false) else {
                let skipped = rest[rest.startIndex..<found.upperBound]
                if let last = pieces.last, case .text(let text) = last {
                    pieces[pieces.count - 1] = .text(text + skipped)
                } else {
                    pieces.append(.text(String(skipped)))
                }
                rest = rest[found.upperBound...]
                continue
            }
            let lead = String(rest[rest.startIndex..<found.lowerBound])
            if !lead.isEmpty {
                if let last = pieces.last, case .text(let text) = last {
                    pieces[pieces.count - 1] = .text(text + lead)
                } else {
                    pieces.append(.text(lead))
                }
            }
            pieces.append(.blank)
            if answer == nil { answer = String(sentence[found]) }
            rest = rest[found.upperBound...]
        }
        guard let answer else { return nil }
        if !rest.isEmpty {
            if let last = pieces.last, case .text(let text) = last {
                pieces[pieces.count - 1] = .text(text + rest)
            } else {
                pieces.append(.text(String(rest)))
            }
        }
        return Sentence(pieces: pieces, answer: answer)
    }

    // MARK: The Chinese cue

    public struct Cue: Equatable, Sendable {
        public let before: String
        public let cue: String
        public let after: String
    }

    /// The translation split around the highlighted part, or nil when the
    /// word has no cue or the translation has since changed (a remote fix)
    /// so the cue no longer matches.
    public static func cue(for word: WordEntry) -> Cue? {
        guard let stored = word.exampleZhCue, !stored.isEmpty else { return nil }
        return split(word.exampleZh, cue: stored)
    }

    static func split(_ text: String, cue stored: String) -> Cue? {
        let parts = stored.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        let context = parts.count == 2 ? String(parts[0]) : ""
        let cue = String(parts.count == 2 ? parts[1] : parts[0])
        guard !cue.isEmpty, let whole = text.range(of: context + cue) else { return nil }
        let start = text.index(whole.lowerBound, offsetBy: context.count)
        return Cue(before: String(text[..<start]), cue: cue, after: String(text[whole.upperBound...]))
    }

    // MARK: Judging a typed answer

    public enum Verdict: Equatable, Sendable {
        case correct
        /// The right word in another form ("adapted" where the sentence has
        /// "adapt").
        case otherForm
        /// One letter off: added, missing, wrong or two swapped.
        case almost
        /// Another real word from the learner's list, with its meaning, so
        /// the miss can say what that word actually means.
        case otherWord(word: String, meaning: String)
        case wrong

        public var isCorrect: Bool { self == .correct }
    }

    /// Judges `typed` against the sentence's `answer`. `lookup` finds a word
    /// in the learner's list by its lowercased spelling.
    public static func judge(_ typed: String, answer: String, lookup: (String) -> WordEntry? = { _ in nil }) -> Verdict {
        let given = Spelling.normalized(typed), expected = Spelling.normalized(answer)
        guard !given.isEmpty else { return .wrong }
        if given == expected { return .correct }
        if isOtherForm(given, of: expected) { return .otherForm }
        // A different real word says more than "one letter off": affect and
        // effect are both words, and knowing what was typed is the lesson.
        if let other = lookup(given), Spelling.normalized(other.word) != expected {
            return .otherWord(word: other.word, meaning: other.meaningZh)
        }
        if expected.count >= 4, Spelling.isOneEditApart(Array(given), Array(expected)) { return .almost }
        return .wrong
    }

    /// Whether one is a regular inflection of the other: -s/-es, -ed or
    /// -ing. Comparatives and -ly are left out on purpose: "owner", "corner"
    /// and "early" are words of their own, not forms of "own", "corn", "ear".
    /// Words under three letters are left out too ("be" is not "bed").
    static func isOtherForm(_ a: String, of b: String) -> Bool {
        guard a != b, min(a.count, b.count) >= 3 else { return false }
        return forms(of: b).contains(a) || forms(of: a).contains(b)
    }

    static func forms(of word: String) -> Set<String> {
        var forms: Set<String> = ["\(word)s", "\(word)ed", "\(word)ing"]
        if ["s", "x", "z", "o", "ch", "sh"].contains(where: { word.hasSuffix($0) }) {
            forms.insert("\(word)es")
        }
        if word.hasSuffix("e") {
            forms.formUnion(["\(word)d", "\(word.dropLast())ing"])
        }
        if word.hasSuffix("y"), let before = word.dropLast().last, !"aeiou".contains(before) {
            forms.formUnion(["\(word.dropLast())ies", "\(word.dropLast())ied"])
        }
        // A short vowel before a final consonant doubles it: stop, stopped.
        if let last = word.last, "bdgmnprt".contains(last) {
            forms.formUnion(["\(word)\(last)ed", "\(word)\(last)ing"])
        }
        return forms
    }

    // MARK: When the word comes back

    /// Whole days from `today` until `due` (0 when it is due today or
    /// overdue), or nil when there is no date.
    public static func daysUntil(_ due: String?, today: String) -> Int? {
        guard let due, let end = DayMath.dayNumber(due), let start = DayMath.dayNumber(today) else { return nil }
        return max(0, end - start)
    }
}

/// One question in progress: the help taken and the tries made, and from
/// them how well the word was known.
public struct ClozeAttempt: Equatable, Sendable {
    /// After this many misses the answer is shown, so a question never
    /// becomes a wall.
    public static let missesBeforeAnswer = 3

    public enum Help: Equatable, Sendable {
        case firstLetter
        case answer
    }

    public let answer: String
    public private(set) var misses = 0
    /// Letters given away, from the start of the word.
    public private(set) var lettersShown = 0
    /// The answer has been shown; the learner still types it to finish.
    public private(set) var answerShown = false
    public private(set) var solved = false
    public private(set) var lastVerdict: Cloze.Verdict?

    public init(answer: String) {
        self.answer = answer
    }

    /// The next help on offer: the first letter, then the answer.
    public var nextHelp: Help? {
        guard !solved, !answerShown else { return nil }
        return lettersShown == 0 && answer.filter(\.isLetter).count > 1 ? .firstLetter : .answer
    }

    public mutating func takeHelp() {
        switch nextHelp {
        case .firstLetter: lettersShown = 1
        case .answer: answerShown = true
        case nil: break
        }
    }

    @discardableResult
    public mutating func submit(_ typed: String, lookup: (String) -> WordEntry? = { _ in nil }) -> Cloze.Verdict {
        guard !solved else { return .correct }
        let verdict = Cloze.judge(typed, answer: answer, lookup: lookup)
        lastVerdict = verdict
        if verdict.isCorrect {
            solved = true
        } else {
            misses += 1
            if misses >= Self.missesBeforeAnswer { answerShown = true }
        }
        return verdict
    }

    /// How the word went, once solved: right straight away; right with a
    /// little help (the first letter, or one slip); or missed (the answer was
    /// shown, or it took several tries).
    public var outcome: ClozeRound.Outcome? {
        guard solved else { return nil }
        if misses == 0, lettersShown == 0, !answerShown { return .knew }
        if !answerShown, lettersShown <= 1, misses <= 1 { return .gotIt }
        return .missed
    }
}

/// One round of fill-in-the-blank questions: the order they come in, a
/// missed word coming back a few questions later, and a break from hard words
/// after a run of misses.
public struct ClozeRound: Equatable, Sendable {
    public enum Outcome: String, Codable, Sendable {
        /// Right straight away.
        case knew
        /// Right with a little help.
        case gotIt
        case missed
    }

    public struct Entry: Equatable, Sendable {
        public let wordId: String
        /// Never studied before this round.
        public let isNew: Bool
        /// Its review stage (0 for a new word); a higher stage is an easier word.
        public let stage: Int

        public init(wordId: String, isNew: Bool, stage: Int) {
            self.wordId = wordId
            self.isNew = isNew
            self.stage = stage
        }
    }

    /// A missed word comes back after this many other questions: long enough
    /// that it is recalled, not read off the screen a moment ago.
    public static let requeueGap = 3
    /// After this many misses in a row, the easiest word left comes next.
    public static let missesBeforeBreak = 3

    /// Word ids in the order they will be asked, including second looks.
    public private(set) var order: [String]
    public private(set) var index = 0
    public let initialCount: Int
    let entries: [String: Entry]
    /// The first outcome of each word (a second look does not change it).
    public private(set) var firstOutcome: [String: Outcome] = [:]
    public private(set) var requeued: Set<String> = []
    var missStreak = 0

    /// Up to two well-known review words open the round and one closes it,
    /// so it starts with a win and ends on one; the rest keep their order.
    public init(entries: [Entry]) {
        var seen = Set<String>()
        let unique = entries.filter { seen.insert($0.wordId).inserted }
        self.entries = Dictionary(uniqueKeysWithValues: unique.map { ($0.wordId, $0) })
        self.initialCount = unique.count
        let easy = unique.filter { !$0.isNew }.sorted { $0.stage > $1.stage }.prefix(3).map(\.wordId)
        let openers = Array(easy.prefix(2))
        let closer = unique.count > 3 && easy.count == 3 ? [easy[2]] : []
        let middle = unique.map(\.wordId).filter { !openers.contains($0) && !closer.contains($0) }
        self.order = openers + middle + closer
    }

    public var currentWordId: String? { order.indices.contains(index) ? order[index] : nil }
    public var isComplete: Bool { index >= order.count }
    public var done: Int { min(index, order.count) }
    public var total: Int { order.count }
    /// The word on screen was missed earlier in this round.
    public var isSecondLook: Bool { currentWordId.map { firstOutcome[$0] != nil } ?? false }
    /// Most missed words come back once; at most half the round, so a hard
    /// round does not double in length.
    public var maxRequeues: Int { max(1, (initialCount + 1) / 2) }

    /// Records how the word on screen went and moves on.
    public mutating func record(_ outcome: Outcome) {
        guard let wordId = currentWordId else { return }
        if firstOutcome[wordId] == nil { firstOutcome[wordId] = outcome }
        if outcome == .missed {
            missStreak += 1
            let insertAt = min(order.count, index + 1 + Self.requeueGap)
            // Near the end there may be nothing to put between them; the same
            // question again straight away is not a second look.
            if !requeued.contains(wordId), requeued.count < maxRequeues, insertAt > index + 1 {
                order.insert(wordId, at: insertAt)
                requeued.insert(wordId)
            }
        } else {
            missStreak = 0
        }
        index += 1
        if missStreak >= Self.missesBeforeBreak { bringEasiestForward() }
    }

    /// Whether the word will come back later in this round.
    public func comesBack(_ wordId: String) -> Bool {
        order[min(index, order.count)...].contains(wordId)
    }

    mutating func bringEasiestForward() {
        guard index < order.count else { return }
        let candidates = order.indices.dropFirst(index).filter { firstOutcome[order[$0]] == nil }
        guard let easiest = candidates.max(by: { ease(order[$0]) < ease(order[$1]) }),
              ease(order[easiest]) > ease(order[index]) else { return }
        let wordId = order.remove(at: easiest)
        order.insert(wordId, at: index)
        missStreak = 0
    }

    /// Review words beat new ones; among reviews, a higher stage is easier.
    func ease(_ wordId: String) -> Int {
        guard let entry = entries[wordId], !entry.isNew else { return 0 }
        return 1 + entry.stage
    }

    public struct Summary: Equatable, Sendable {
        /// New words the learner already knew: they skip ahead.
        public var alreadyKnew = 0
        /// New words learned in this round.
        public var learned = 0
        /// Words studied before, asked again.
        public var reviewed = 0
        /// Words missed the first time, due again soon.
        public var missed = 0
    }

    public var summary: Summary {
        var summary = Summary()
        for (wordId, outcome) in firstOutcome {
            if outcome == .missed { summary.missed += 1 }
            guard let entry = entries[wordId] else { continue }
            if !entry.isNew { summary.reviewed += 1 } else if outcome == .knew { summary.alreadyKnew += 1 } else { summary.learned += 1 }
        }
        return summary
    }
}
