import Foundation

/// Fixes English headwords that handwriting recognition got slightly wrong
/// ("abandan" → "abandon") by snapping them to the closest word in the
/// built-in list. Only small edits are allowed, so a real word that is simply
/// not in the list is left alone.
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

    /// Picks the candidate reading that is a dictionary word, if any.
    public func best(of candidates: [String]) -> String? {
        guard let primary = candidates.first else { return nil }
        let preferred = candidates.first { candidate in
            let head = candidate.split(whereSeparator: { !$0.isLetter && $0 != "'" && $0 != "-" }).first.map(String.init) ?? ""
            return !head.isEmpty && words.contains(head.lowercased())
        } ?? primary
        guard preferred != primary, primary.unicodeScalars.contains(where: ScanParser.isCJK) else { return preferred }
        let pattern = Self.leadingWordPattern
        guard let original = pattern.firstMatch(in: primary, range: NSRange(primary.startIndex..., in: primary)),
              let replacement = pattern.firstMatch(in: preferred, range: NSRange(preferred.startIndex..., in: preferred)),
              let originalRange = Range(original.range(at: 1), in: primary),
              let replacementRange = Range(replacement.range(at: 1), in: preferred),
              !primary[..<originalRange.lowerBound].unicodeScalars.contains(where: ScanParser.isCJK)
        else { return primary }
        // A better English reading must not replace the paper's Chinese text.
        return primary.replacingCharacters(in: originalRange, with: String(preferred[replacementRange]))
    }

    static let leadingWordPattern = try! NSRegularExpression(pattern: #"^[^A-Za-z]*([A-Za-z][A-Za-z'’-]*)"#)

    func closest(to word: String) -> String? {
        // Short words have too many neighbours to guess safely.
        guard word.count >= 4, word.allSatisfy({ $0.isASCII && $0.isLetter }) else { return nil }
        let budget = word.count >= 8 ? 2 : 1
        var best: (word: String, distance: Int)?
        var tie = false
        for length in (word.count - budget)...(word.count + budget) {
            for candidate in byLength[length] ?? [] {
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
