import Foundation

/// Guards for pairs that did not come from the line parser: rows of a table
/// found on the page, or entries an on-device language model pulled out of
/// messy (often handwritten) text. Only text that is really on the page may
/// become a word or a meaning; nothing is translated or made up.
public enum ScanGrounding {
    /// Each table row becomes one line, so a word and its meaning in
    /// neighbouring cells pair up like a printed "word  meaning" line.
    public static func candidates(fromTableRows rows: [[String]]) -> [ScannedWordCandidate] {
        let lines = rows
            .map { cells in cells.map { $0.replacingOccurrences(of: "\n", with: " ") }.joined(separator: "  ") }
            .joined(separator: "\n")
        return ScanParser.parse(ScanParser.lines(fromPlainText: lines)).map { candidate in
            var copy = candidate
            copy.key = "t-\(candidate.key)"
            return copy
        }
    }

    /// True when both the word and the meaning appear in the recognised text
    /// (ignoring spaces, case and punctuation).
    public static func isGrounded(word: String, meaning: String, in source: String) -> Bool {
        let haystack = normalised(source)
        let needleWord = normalised(word)
        let needleMeaning = normalised(meaning)
        guard needleWord.count >= 2, !needleMeaning.isEmpty,
              word.unicodeScalars.contains(where: { ("a"..."z").contains($0) || ("A"..."Z").contains($0) }),
              meaning.unicodeScalars.contains(where: ScanParser.isCJK)
        else { return false }
        return haystack.contains(needleWord) && haystack.contains(needleMeaning)
    }

    static func normalised(_ text: String) -> String {
        let dropped: Set<Character> = ["；", ";", "，", ",", "、", "。", ".", "：", ":", "（", "）", "(", ")", "-", "–", "—", "/", "·", "'", "’"]
        return String(text.lowercased().filter { !$0.isWhitespace && !dropped.contains($0) })
    }
}
