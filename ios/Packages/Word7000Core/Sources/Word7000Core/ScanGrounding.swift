import Foundation

/// Guards for pairs that did not come from the line parser: rows of a table
/// found on the page, or entries an on-device language model pulled out of
/// messy (often handwritten) text. Only text that is really on the page may
/// become a word or a meaning; nothing is translated or made up.
public enum ScanGrounding {
    /// Keep different spellings intact. Readers that disagree about an entry
    /// mark both readings for review instead of silently dropping letters,
    /// unless the word list settles it: of "daring" and "during" read beside
    /// 在..期間, only "during" means that (`dictionary`).
    ///
    /// One printed entry is one row. The same word read again with part of
    /// its meaning (a box read on its own, or a note joined to it) is the same
    /// entry, and a second reader that gives a word already found the meaning
    /// of another word has its rows out of step. Different meanings that are
    /// really on the page stay separate.
    public static func merging(primary: [ScannedWordCandidate], supplemental: [ScannedWordCandidate],
                               dictionary: ScanDictionary? = nil) -> [ScannedWordCandidate] {
        var merge = Merge(dictionary: dictionary)
        for candidate in primary { merge.add(candidate, fromAnotherReader: false) }
        for candidate in supplemental { merge.add(candidate, fromAnotherReader: true) }
        return merge.result
    }

    struct Merge {
        let dictionary: ScanDictionary?
        var result: [ScannedWordCandidate] = []
        /// `wordKey` and `normalised` meaning of each row, kept alongside.
        var words: [String] = []
        var meanings: [String] = []

        init(dictionary: ScanDictionary?) { self.dictionary = dictionary }

        mutating func add(_ candidate: ScannedWordCandidate, fromAnotherReader: Bool) {
            let word = ScanImportPlan.wordKey(candidate.word)
            let meaning = ScanGrounding.normalised(candidate.meaningZh)
            let sameWord = result.indices.filter { words[$0] == word }
            if sameWord.contains(where: { ScanImportPlan.sameEntry(result[$0].reviewedWord, candidate.reviewedWord) }) { return }
            if let index = sameWord.first(where: { index in
                let other = meanings[index]
                return !other.isEmpty && !meaning.isEmpty && (other.contains(meaning) || meaning.contains(other))
                    && ScanImportPlan.samePartOfSpeech(result[index].partOfSpeech, candidate.partOfSpeech)
            }) {
                // Keep the fuller meaning, so no sense printed on the page is lost.
                if meaning.count > meanings[index].count {
                    result[index].meaningZh = candidate.meaningZh
                    meanings[index] = meaning
                }
                if result[index].partOfSpeech.isEmpty { result[index].partOfSpeech = candidate.partOfSpeech }
                return
            }
            guard fromAnotherReader else {
                append(candidate, word: word, meaning: meaning)
                return
            }
            if !sameWord.isEmpty, result.indices.contains(where: { words[$0] != word && meanings[$0] == meaning }) {
                return
            }
            let conflicting = result.indices.filter { index in
                words[index] != word && meanings[index] == meaning && ScanGrounding.similarSpelling(words[index], word)
            }
            guard !conflicting.isEmpty else {
                append(candidate, word: word, meaning: meaning)
                return
            }
            if conflicting.count == 1, let dictionary, let index = conflicting.first,
               let chosen = dictionary.preferred(result[index].word, candidate.word, meaning: candidate.meaningZh) {
                if ScanImportPlan.wordKey(chosen) != words[index] {
                    result[index].originalWord = result[index].word
                    result[index].word = chosen
                    words[index] = ScanImportPlan.wordKey(chosen)
                }
                return
            }
            for index in conflicting { result[index].needsReview = true }
            var flagged = candidate
            flagged.needsReview = true
            append(flagged, word: word, meaning: meaning)
        }

        mutating func append(_ candidate: ScannedWordCandidate, word: String, meaning: String) {
            result.append(candidate)
            words.append(word)
            meanings.append(meaning)
        }
    }

    /// Two readings of one printed word: a word ending read or missed
    /// ("objective", "objectively"), or a letter or two read differently
    /// ("daring", "during").
    static func similarSpelling(_ lhs: String, _ rhs: String) -> Bool {
        if abs(lhs.count - rhs.count) <= 4, lhs.hasPrefix(rhs) || rhs.hasPrefix(lhs) { return true }
        let shorter = min(lhs.count, rhs.count)
        guard shorter >= 4 else { return false }
        let budget = shorter >= 8 ? 2 : 1
        return WordSuggester.distance(lhs, rhs, limit: budget) <= budget
    }

    /// Words whose meaning on the page is the list's meaning of a word a
    /// letter or two away. With that word also read on the page, it is taken
    /// (the first reading can be restored); otherwise it is only suggested.
    public static func respelled(_ candidates: [ScannedWordCandidate], pageWords: Set<String>, dictionary: ScanDictionary) -> [ScannedWordCandidate] {
        var result: [ScannedWordCandidate] = []
        for var candidate in candidates {
            if candidate.originalWord == nil, let better = dictionary.respelling(of: candidate.word, meaning: candidate.meaningZh) {
                if pageWords.contains(ScanImportPlan.wordKey(better)) {
                    candidate.originalWord = candidate.word
                    candidate.word = better
                } else if candidate.suggestedWord == nil {
                    candidate.suggestedWord = better
                }
            }
            guard !result.contains(where: { ScanImportPlan.sameEntry($0.reviewedWord, candidate.reviewedWord) }) else { continue }
            result.append(candidate)
        }
        return result
    }

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

    /// The word and meaning must belong to the same entry, not merely occur
    /// somewhere on the page. This also prevents substring headword matches.
    public static func isGrounded(word: String, meaning: String, in source: String) -> Bool {
        let needleWord = normalised(word)
        let needleMeaning = normalised(meaning)
        guard needleWord.count >= 2, !needleMeaning.isEmpty,
              word.unicodeScalars.contains(where: { ("a"..."z").contains($0) || ("A"..."Z").contains($0) }),
              meaning.unicodeScalars.contains(where: ScanParser.isCJK)
        else { return false }
        let pairs = ScanParser.parse(ScanParser.lines(fromPlainText: source.lowercased()))
        return pairs.contains { normalised($0.word) == needleWord && normalised($0.meaningZh).contains(needleMeaning) }
    }

    static func normalised(_ text: String) -> String {
        let dropped: Set<Character> = ["；", ";", "，", ",", "、", "。", ".", "：", ":", "（", "）", "(", ")", "-", "–", "—", "/", "·", "'", "’"]
        return String(text.lowercased().filter { !$0.isWhitespace && !dropped.contains($0) })
    }
}
