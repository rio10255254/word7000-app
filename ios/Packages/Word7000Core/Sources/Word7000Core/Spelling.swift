import Foundation

/// Typing a word from its meaning: how an answer is judged and the letter
/// pattern shown as a hint.
public enum Spelling {
    public static let sessionLength = 10

    public enum Result: Equatable, Sendable {
        case correct
        /// One letter off: added, missing, wrong or two swapped.
        case almost
        case wrong
    }

    /// Case, surrounding spaces and curly apostrophes never count against
    /// the learner.
    public static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            .lowercased()
    }

    public static func check(_ answer: String, word: String) -> Result {
        let typed = Array(normalized(answer)), expected = Array(normalized(word))
        guard !typed.isEmpty else { return .wrong }
        if typed == expected { return .correct }
        return expected.count >= 4 && isOneEditApart(typed, expected) ? .almost : .wrong
    }

    /// Letters as blanks with the first `revealed` filled in, e.g.
    /// "a b _ _ _ _ _" for "abandon" with two revealed.
    public static func pattern(_ word: String, revealed: Int) -> String {
        var shown = 0
        return word.map { character -> String in
            guard character.isLetter else { return String(character) }
            shown += 1
            return shown <= revealed ? String(character) : "_"
        }.joined(separator: " ")
    }

    /// Hints stop one letter short, so the learner still types the word.
    public static func maxHints(_ word: String) -> Int {
        max(0, word.filter(\.isLetter).count - 1)
    }

    static func isOneEditApart(_ a: [Character], _ b: [Character]) -> Bool {
        if a.count == b.count {
            let differences = a.indices.filter { a[$0] != b[$0] }
            if differences.count == 1 { return true }
            // Two neighbouring letters swapped, e.g. "recieve".
            return differences.count == 2 && differences[1] == differences[0] + 1
                && a[differences[0]] == b[differences[1]] && a[differences[1]] == b[differences[0]]
        }
        guard abs(a.count - b.count) == 1 else { return false }
        let (short, long) = a.count < b.count ? (a, b) : (b, a)
        var i = 0, j = 0, skipped = false
        while i < short.count, j < long.count {
            if short[i] == long[j] { i += 1; j += 1; continue }
            if skipped { return false }
            skipped = true
            j += 1
        }
        return true
    }
}
