import Foundation

/// Writing the Chinese for an English word, for learners of Chinese: in
/// characters (any keyboard, traditional or simplified) or in pinyin, with
/// tones as marks, as numbers, or left out.
public enum ChineseSpelling {
    /// The senses accepted as the answer; the first is the one taught.
    public static func targets(_ meaning: String) -> [String] {
        ChineseDisplay.meaningParts(meaning).filter { $0.contains(where: ChineseDisplay.isHan) }
    }

    /// Toned syllables of the taught sense, one per character.
    public static func syllables(_ target: String) -> [String] {
        ChineseDisplay.pronunciationWithTones(target)
            .split(whereSeparator: { $0.isWhitespace || $0 == "；" })
            .map(String.init)
            .filter { $0.contains(where: \.isLetter) }
    }

    public static func check(_ answer: String, meaning: String) -> Spelling.Result {
        let typed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        let senses = targets(meaning)
        guard !typed.isEmpty, !senses.isEmpty else { return .wrong }
        if typed.contains(where: ChineseDisplay.isHan) {
            let written = hanOnly(typed)
            let traditional = toTraditional(written)
            var best = Spelling.Result.wrong
            for sense in senses {
                let expected = hanOnly(sense)
                if written == expected || traditional == expected { return .correct }
                if expected.count >= 2, Spelling.isOneEditApart(Array(traditional), Array(expected)) { best = .almost }
            }
            return best
        }
        let letters = toneless(typed)
        let tones = toneSequence(typed)
        var best = Spelling.Result.wrong
        for sense in senses {
            let reading = syllables(sense).joined(separator: " ")
            guard !reading.isEmpty else { continue }
            let expected = toneless(reading)
            if letters == expected {
                // Tones may be left out; given, they must be right.
                if tones.isEmpty || tones == toneSequence(reading) { return .correct }
                best = .almost
            } else if expected.count >= 4, Spelling.isOneEditApart(Array(letters), Array(expected)) {
                best = .almost
            }
        }
        return best
    }

    /// Why an almost-right pinyin answer was not right, for the feedback.
    public static func tonesOnlyWrong(_ answer: String, meaning: String) -> Bool {
        let typed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.contains(where: ChineseDisplay.isHan), !toneSequence(typed).isEmpty else { return false }
        return targets(meaning).contains { toneless(syllables($0).joined(separator: " ")) == toneless(typed) }
    }

    /// One blank per syllable with the first `revealed` filled in, e.g.
    /// "shì _" for 適應 with one revealed.
    public static func pattern(_ syllables: [String], revealed: Int) -> String {
        syllables.enumerated().map { $0.offset < revealed ? $0.element : "_" }.joined(separator: " ")
    }

    /// Hints stop one syllable short (a one-character answer gets none).
    public static func maxHints(_ syllables: [String]) -> Int {
        max(0, syllables.count - 1)
    }

    // MARK: - Normalising

    static func hanOnly(_ text: String) -> String {
        String(text.filter(ChineseDisplay.isHan))
    }

    static func toTraditional(_ text: String) -> String {
        #if canImport(Darwin)
        return text.applyingTransform(StringTransform("Hans-Hant"), reverse: false) ?? text
        #else
        return text
        #endif
    }

    private static let marks: [Character: (Character, Int)] = {
        var table: [Character: (Character, Int)] = [:]
        let rows: [(Character, String)] = [("a", "āáǎà"), ("e", "ēéěè"), ("i", "īíǐì"), ("o", "ōóǒò"), ("u", "ūúǔù"), ("v", "ǖǘǚǜ")]
        for (base, toned) in rows {
            for (index, character) in toned.enumerated() { table[character] = (base, index + 1) }
        }
        return table
    }()

    /// Letters only, lowercase, tone marks and numbers dropped, ü as v.
    static func toneless(_ text: String) -> String {
        var out = ""
        for character in text.lowercased() {
            if let (base, _) = marks[character] { out.append(base); continue }
            switch character {
            case "ü": out.append("v")
            case "a"..."z": out.append(character)
            default: continue
            }
        }
        return out.replacingOccurrences(of: "u:", with: "v")
    }

    /// The tones given, in order: from marks (ā = 1) or digits 1–4; the
    /// neutral tone (no mark, or 5/0) is left out.
    static func toneSequence(_ text: String) -> [Int] {
        var tones: [Int] = []
        for character in text.lowercased() {
            if let (_, tone) = marks[character] { tones.append(tone) }
            else if let digit = character.wholeNumberValue, (1...4).contains(digit) { tones.append(digit) }
        }
        return tones
    }
}
