import Foundation

/// Learn Chinese mode's typing practice, in place of spelling: read a word's
/// characters and type their pinyin. Tones are optional (marks, numbers or
/// none), so the check compares the letters; the tone-marked reading is shown
/// with the result.
public enum PinyinPractice {
    public struct Target: Equatable, Sendable {
        /// The characters to read, e.g. 適應.
        public var characters: String
        /// The tone-marked reading, e.g. "shì yìng".
        public var reading: String
        /// Each syllable without tones, `ü` kept, e.g. ["shi", "ying"].
        public var syllables: [String]

        /// What a correct answer is compared with ("shiying", `ü` as `v`).
        var letters: String { ChineseDisplay.pinyinSearchTerm(syllables.joined()) ?? "" }
    }

    /// The word's first sense when it is one to four Chinese characters with a
    /// reading for each; longer or mixed senses are left to the other drills.
    public static func target(for word: WordEntry) -> Target? {
        guard let sense = ChineseDisplay.meaningParts(word.meaningZh).first,
              (1...4).contains(sense.count), sense.allSatisfy(ChineseDisplay.isHan) else { return nil }
        let reading = ChineseDisplay.pronunciationWithTones(sense)
        let syllables = reading.split(separator: " ").map { ChineseDisplay.stripTones(String($0)) }
        guard syllables.count == sense.count, syllables.allSatisfy({ ChineseDisplay.pinyinSearchTerm($0) != nil }) else { return nil }
        return Target(characters: sense, reading: reading, syllables: syllables)
    }

    public static func check(_ answer: String, target: Target) -> Spelling.Result {
        guard let typed = ChineseDisplay.pinyinSearchTerm(answer) else { return .wrong }
        let expected = target.letters
        if typed == expected { return .correct }
        return expected.count >= 4 && Spelling.isOneEditApart(Array(typed), Array(expected)) ? .almost : .wrong
    }

    /// Letters as blanks, syllable by syllable, with the first `revealed`
    /// letters filled in, e.g. "s h _   _ _ _ _" for 適應 with two revealed.
    public static func pattern(_ target: Target, revealed: Int) -> String {
        var shown = 0
        return target.syllables.map { syllable in
            syllable.map { letter -> String in
                shown += 1
                return shown <= revealed ? String(letter) : "_"
            }.joined(separator: " ")
        }.joined(separator: "   ")
    }

    /// Hints stop one letter short, so the learner still types the reading.
    public static func maxHints(_ target: Target) -> Int {
        max(0, target.syllables.joined().count - 1)
    }
}
