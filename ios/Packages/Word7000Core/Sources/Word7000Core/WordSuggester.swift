import Foundation

/// Optional spelling suggestions for reviewed scans. The dictionary is not
/// exhaustive; its absence must never erase a word's ending.
public struct WordSuggester: Sendable {
    private let words: Set<String>
    private let byLength: [Int: [String]]

    public init(words: [String]) {
        let lowered = words.map { $0.lowercased() }.filter { !$0.isEmpty }
        self.words = Set(lowered)
        var byLength: [Int: [String]] = [:]
        for word in Set(lowered) { byLength[word.count, default: []].append(word) }
        for key in byLength.keys { byLength[key]?.sort() }
        self.byLength = byLength
    }

    public func contains(_ word: String) -> Bool {
        words.contains(word.lowercased())
    }

    public var recognitionVocabulary: [String] {
        words.filter { $0.count <= 40 && $0.unicodeScalars.allSatisfy { $0.isASCII } }.sorted()
    }

    /// The dictionary spelling for `word`, or nil when it is already known or
    /// nothing is close enough. Phrases are corrected word by word.
    public func correction(for word: String) -> String? {
        let lowered = word.lowercased()
        guard !lowered.isEmpty, !words.contains(lowered) else { return nil }
        let parts = lowered.split(separator: " ").map(String.init)
        if parts.count > 1 {
            var changed = false
            let fixed = parts.map { part -> String in
                guard !words.contains(part), let better = closest(to: part) else { return part }
                changed = true
                return better
            }
            return changed ? fixed.joined(separator: " ") : nil
        }
        return closest(to: lowered)
    }

    /// Vision orders readings by confidence. A familiar dictionary stem is
    /// not evidence that a longer, unfamiliar word was read incorrectly.
    public func best(of candidates: [String]) -> String? {
        candidates.first
    }

    private func isWordForm(_ word: String) -> Bool {
        for suffix in ["ly", "ally", "s", "es", "ed", "ing", "er", "est"] where word.hasSuffix(suffix) {
            let stem = String(word.dropLast(suffix.count))
            guard stem.count >= 3 else { continue }
            if words.contains(stem) || words.contains(stem + "e") { return true }
            if stem.hasSuffix("i"), words.contains(String(stem.dropLast()) + "y") { return true }
            if stem.count >= 4, stem.last == stem.dropLast().last, words.contains(String(stem.dropLast())) { return true }
        }
        return false
    }

    func closest(to word: String) -> String? {
        // Short words have too many neighbours to guess safely.
        guard word.count >= 4, word.allSatisfy({ $0.isASCII && $0.isLetter }) else { return nil }
        guard !isWordForm(word) else { return nil }
        let budget = word.count >= 8 ? 2 : 1
        var best: (word: String, distance: Int)?
        var tie = false
        for length in (word.count - budget)...(word.count + budget) {
            for candidate in byLength[length] ?? [] {
                guard !word.hasPrefix(candidate), !word.hasSuffix(candidate) else { continue }
                let distance = Self.distance(word, candidate, limit: budget)
                guard distance <= budget else { continue }
                if best == nil || distance < best!.distance {
                    best = (candidate, distance)
                    tie = false
                } else if distance == best!.distance {
                    tie = true
                }
            }
        }
        // Two equally close words: better to leave it for the learner.
        guard let best, !tie else { return nil }
        return best.word
    }

    /// Damerau–Levenshtein (optimal string alignment) distance, stopping early
    /// once it exceeds `limit`.
    static func distance(_ a: String, _ b: String, limit: Int) -> Int {
        let a = Array(a), b = Array(b)
        if abs(a.count - b.count) > limit { return limit + 1 }
        var previous2 = [Int](repeating: 0, count: b.count + 1)
        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1...max(1, a.count) where !a.isEmpty {
            current[0] = i
            var rowMinimum = current[0]
            for j in 1...max(1, b.count) where !b.isEmpty {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                var value = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    value = min(value, previous2[j - 2] + 1)
                }
                current[j] = value
                rowMinimum = min(rowMinimum, value)
            }
            if rowMinimum > limit { return limit + 1 }
            previous2 = previous
            previous = current
        }
        return a.isEmpty ? b.count : previous[b.count]
    }
}
