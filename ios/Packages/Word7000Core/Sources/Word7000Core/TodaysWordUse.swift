import Foundation

/// WordCat Next: the last step of a speaking stage. The learner picks one of
/// the words they studied today and says a sentence of their own with it;
/// the phone checks, from the speech turned into text on the device, that
/// the word was said and that it was a sentence. Whether the sentence is
/// good English is the cat's to judge (Premium), not this check's.
public enum TodaysWordUse {
    /// Words offered to choose from.
    public static let choices = 3
    /// Fewer words than this is not yet a sentence.
    public static let minimumWords = 3

    public enum Verdict: String, Equatable, Sendable {
        /// The word, in a sentence.
        case used
        /// Another form of it (adapted for adapt): good too.
        case usedOtherForm
        /// The word was said, but too little around it to be a sentence.
        case tooShort
        /// The word was not heard.
        case missing

        public var counts: Bool { self == .used || self == .usedOtherForm }
    }

    /// The words to offer: today's, the ones the learner said they knew
    /// first (in `preferred` order, the cards of today's routine), then the
    /// rest studied today; when nothing was studied today, the most recently
    /// studied. Only words that are a single English word, so a sentence can
    /// be checked for them.
    public static func pick(words: [WordEntry], state: ProgressState, today: String, preferred: [String] = []) -> [String] {
        let usable = words.filter { isSingleWord($0.word) }
        let byId = Dictionary(usable.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let studied = usable.compactMap { word -> (id: String, last: String, known: Bool)? in
            guard let saved = state.words[word.id], saved.status != .new, let last = saved.lastStudied else { return nil }
            return (word.id, last, saved.status == .mastered)
        }
        let todays = studied.filter { $0.last == today }
        var picked: [String] = []
        func add(_ id: String) {
            if picked.count < choices, byId[id] != nil, !picked.contains(id) { picked.append(id) }
        }
        let todaysIds = Set(todays.map(\.id))
        for id in preferred where todaysIds.contains(id) && state.words[id]?.status == .mastered { add(id) }
        for item in todays.filter(\.known) { add(item.id) }
        for item in todays { add(item.id) }
        if picked.isEmpty {
            for item in studied.sorted(by: { $0.last != $1.last ? $0.last > $1.last : $0.id < $1.id }) { add(item.id) }
        }
        return picked
    }

    /// Whether `heard` says `word` in a sentence.
    public static func check(heard: String, word: String) -> Verdict {
        let target = Spelling.normalized(word)
        let said = tokens(heard)
        guard !target.isEmpty else { return .missing }
        let exact = said.contains(target)
        let otherForm = !exact && said.contains { Cloze.isOtherForm($0, of: target) }
        guard exact || otherForm else { return .missing }
        guard said.count >= minimumWords else { return .tooShort }
        return exact ? .used : .usedOtherForm
    }

    /// The words of what was heard, lowercased, without punctuation.
    static func tokens(_ text: String) -> [String] {
        Spelling.normalized(text)
            .split(whereSeparator: { !($0.isLetter || $0 == "'" || $0 == "-") })
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "'-")) }
            .filter { !$0.isEmpty }
    }

    static func isSingleWord(_ text: String) -> Bool {
        let normalized = Spelling.normalized(text)
        return !normalized.isEmpty && normalized.allSatisfy { $0.isLetter || $0 == "-" } && normalized.unicodeScalars.allSatisfy(\.isASCII)
    }
}
