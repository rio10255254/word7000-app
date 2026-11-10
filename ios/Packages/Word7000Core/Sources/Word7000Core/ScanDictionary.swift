import Foundation

/// The built-in English list's meanings, to tell which of two near spellings
/// a printed meaning belongs to: "daring" read beside 在..期間 is "during",
/// whose meaning that is. A meaning written on the page is never changed, and
/// a word ending is never cut off to reach a listed word.
public struct ScanDictionary: Sendable {
    /// Senses by word, Chinese characters only ("在…期間" and "在..期間" alike).
    private let senses: [String: [String]]
    private let byLength: [Int: [String]]

    public init(words: [WordEntry]) {
        var senses: [String: [String]] = [:]
        for entry in words {
            let key = ScanImportPlan.wordKey(entry.word)
            guard !key.isEmpty else { continue }
            senses[key, default: []] += Self.senses(of: entry.meaningZh) + Self.senses(of: entry.supplementalMeaningZh ?? "")
        }
        var byLength: [Int: [String]] = [:]
        for key in senses.keys where key.allSatisfy({ $0.isASCII && $0.isLetter }) {
            byLength[key.count, default: []].append(key)
        }
        for length in byLength.keys { byLength[length]?.sort() }
        self.senses = senses
        self.byLength = byLength
    }

    static func senses(of meaning: String) -> [String] {
        meaning.components(separatedBy: CharacterSet(charactersIn: "；;，,、/"))
            .map { String($0.filter(ChineseDisplay.isHan)) }
            .filter { !$0.isEmpty }
    }

    /// Whether the list gives `word` a sense the printed meaning has; nil
    /// when the word is not in the list.
    public func fits(_ word: String, meaning: String) -> Bool? {
        guard let known = senses[ScanImportPlan.wordKey(word)] else { return nil }
        let printed = Self.senses(of: meaning)
        return printed.contains { sense in known.contains { Self.same(sense, $0) } }
    }

    static func same(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs { return true }
        let (shorter, longer) = lhs.count <= rhs.count ? (lhs, rhs) : (rhs, lhs)
        return shorter.count >= 2 && longer.contains(shorter)
    }

    /// Of two readings of one entry, the one whose listed meaning is the
    /// printed one, when only one of them has it. Nil when the list cannot
    /// tell, or when one reading only adds an ending to the other.
    public func preferred(_ lhs: String, _ rhs: String, meaning: String) -> String? {
        let left = ScanImportPlan.wordKey(lhs), right = ScanImportPlan.wordKey(rhs)
        guard !left.hasPrefix(right), !right.hasPrefix(left) else { return nil }
        switch (fits(lhs, meaning: meaning) == true, fits(rhs, meaning: meaning) == true) {
        case (true, false): return lhs
        case (false, true): return rhs
        default: return nil
        }
    }

    /// A listed word a letter away (two for words of eight letters or more)
    /// whose meaning is the printed one, when the word as read does not mean
    /// that. Nil when none or more than one fits.
    public func respelling(of word: String, meaning: String) -> String? {
        let key = ScanImportPlan.wordKey(word)
        guard key.count >= 4, key.allSatisfy({ $0.isASCII && $0.isLetter }), fits(key, meaning: meaning) != true else { return nil }
        let budget = key.count >= 8 ? 2 : 1
        var found: [String] = []
        for length in (key.count - budget)...(key.count + budget) {
            for candidate in byLength[length] ?? [] where candidate != key {
                guard !key.hasPrefix(candidate), !candidate.hasPrefix(key),
                      WordSuggester.distance(key, candidate, limit: budget) <= budget,
                      fits(candidate, meaning: meaning) == true else { continue }
                found.append(candidate)
            }
        }
        guard found.count == 1, let match = found.first else { return nil }
        // Keep a capital the page had ("Daring" becomes "During").
        guard let first = word.first, first.isUppercase else { return match }
        return match.prefix(1).uppercased() + match.dropFirst()
    }
}
