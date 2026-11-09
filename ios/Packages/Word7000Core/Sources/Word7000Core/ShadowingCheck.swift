import Foundation

/// Saying a model sentence after hearing it, checked against what speech
/// recognition heard. Each word (or, in Chinese, each character) is marked as
/// heard, missed, or, in Chinese, heard with another tone. It compares text,
/// so it is a guide to what came across, not a pronunciation grade.
public struct ShadowingCheck: Equatable, Sendable {
    public enum Mark: Equatable, Sendable {
        /// Came across as written (in Chinese, also a character that sounds the same).
        case heard
        /// The right syllable with another tone: `heard` is what came across.
        case tone(heard: String)
        case missed
    }

    /// One word of an English sentence, or one character of a Chinese one.
    public struct Unit: Equatable, Sendable, Identifiable {
        public let id: Int
        /// As written, with any punctuation that follows it.
        public let text: String
        /// Toned pinyin of a Chinese character; empty otherwise.
        public let pinyin: String
        /// Whether the unit is checked at all (punctuation is not).
        public let scored: Bool
        /// Nil until something was said.
        public var mark: Mark?
    }

    /// Enough of the sentence came across to move on.
    public static let passMark = 0.7

    public let units: [Unit]
    /// 0...1: a heard unit counts fully, a tone slip half.
    public let score: Double
    public var passed: Bool { score >= Self.passMark }
    /// Every word (character) came across as written, tones included.
    public var perfect: Bool { scoredCount > 0 && heardCount == scoredCount }
    /// Every word (character) was recognized, whatever the pitch measured:
    /// enough to move on. Tones measured from pitch are a note to work on,
    /// not a wall, since the measuring is far less sure than recognition.
    public var allRecognized: Bool { scoredCount > 0 && heardCount + toneCount == scoredCount }
    public var heardCount: Int { units.filter { $0.mark == .heard }.count }
    public var toneCount: Int { units.filter { if case .tone = $0.mark { true } else { false } }.count }
    public var scoredCount: Int { units.filter(\.scored).count }

    /// The sentence before anything was said: units without marks.
    public init(target: String, chinese: Bool) {
        units = Self.split(target, chinese: chinese)
        score = 0
    }

    public init(target: String, heard: String, chinese: Bool) {
        var units = Self.split(target, chinese: chinese)
        // What is compared: each Chinese character, or each word of an
        // English unit ("Wi-Fi" and "7:30" are two words, said as two).
        var expected: [String] = [], owner: [Int] = []
        for index in units.indices where units[index].scored {
            for token in chinese ? [units[index].text] : SpeakingReflection.tokens(units[index].text) {
                expected.append(token)
                owner.append(index)
            }
        }
        let said: [String] = chinese
            ? heard.filter(ChineseDisplay.isHan).map(String.init)
            : SpeakingReflection.tokens(heard)
        let saidPinyin = chinese ? said.map(Self.characterPinyin) : []
        let expectedPinyin = owner.map { chinese ? units[$0].pinyin : "" }

        func same(_ i: Int, _ j: Int) -> Bool {
            if expected[i] == said[j] { return true }
            // A character recognized as another one that sounds exactly the same was said right.
            return chinese && !expectedPinyin[i].isEmpty && expectedPinyin[i] == saidPinyin[j]
        }

        // Longest common subsequence: what was said, in order.
        let n = expected.count, m = said.count
        var table = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        if n > 0, m > 0 {
            for i in stride(from: n - 1, through: 0, by: -1) {
                for j in stride(from: m - 1, through: 0, by: -1) {
                    table[i][j] = same(i, j) ? table[i + 1][j + 1] + 1 : max(table[i + 1][j], table[i][j + 1])
                }
            }
        }
        var marks = Array(repeating: Mark.missed, count: n)
        var i = 0, j = 0
        var gapExpected: [Int] = [], gapSaid: [Int] = []
        func closeGap() {
            // Between two matches, a character with the same syllable but
            // another tone is a tone slip rather than a miss.
            if chinese {
                for (e, s) in zip(gapExpected, gapSaid)
                    where !expectedPinyin[e].isEmpty
                    && ChineseDisplay.stripTones(expectedPinyin[e]) == ChineseDisplay.stripTones(saidPinyin[s]) {
                    marks[e] = .tone(heard: saidPinyin[s])
                }
            }
            gapExpected = []; gapSaid = []
        }
        while i < n, j < m {
            if same(i, j) {
                closeGap()
                marks[i] = .heard
                i += 1; j += 1
            } else if table[i + 1][j] >= table[i][j + 1] {
                gapExpected.append(i); i += 1
            } else {
                gapSaid.append(j); j += 1
            }
        }
        gapExpected.append(contentsOf: i..<n)
        gapSaid.append(contentsOf: j..<m)
        closeGap()

        // A unit came across when all of its words did.
        for (position, index) in owner.enumerated() {
            if units[index].mark == nil || marks[position] != .heard { units[index].mark = marks[position] }
        }
        self.units = units
        let points = marks.reduce(0.0) { total, mark in
            switch mark {
            case .heard: total + 1
            case .tone: total + 0.5
            case .missed: total
            }
        }
        score = n == 0 ? 0 : points / Double(n)
    }

    private init(units: [Unit], score: Double) {
        self.units = units
        self.score = score
    }

    /// The same check after measuring pitch: characters recognized right
    /// but said with another tone (by unit id, with the reading heard)
    /// become tone slips, worth half.
    public func withToneSlips(_ slips: [Int: String]) -> ShadowingCheck {
        guard !slips.isEmpty else { return self }
        var units = self.units
        for index in units.indices {
            if let heard = slips[units[index].id], units[index].mark == .heard { units[index].mark = .tone(heard: heard) }
        }
        let scored = units.filter(\.scored)
        let points = scored.reduce(0.0) { total, unit in
            switch unit.mark {
            case .heard: total + 1
            case .tone: total + 0.5
            default: total
            }
        }
        return ShadowingCheck(units: units, score: scored.isEmpty ? 0 : points / Double(scored.count))
    }

    /// The sentence to say after the model: the first sentence of a model
    /// answer, with the next one too when the first is very short.
    public static func sentence(from text: String, chinese: Bool) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var sentences: [String] = []
        var current = ""
        for character in trimmed {
            current.append(character)
            if ".!?。！？".contains(character) {
                sentences.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            }
        }
        let rest = current.trimmingCharacters(in: .whitespaces)
        if !rest.isEmpty { sentences.append(rest) }
        guard var result = sentences.first else { return "" }
        func size(_ sentence: String) -> Int {
            chinese ? sentence.filter(ChineseDisplay.isHan).count : SpeakingReflection.tokens(sentence).count
        }
        if size(result) < (chinese ? 6 : 4), sentences.count > 1 {
            result += (chinese ? "" : " ") + sentences[1]
        }
        return result
    }

    // MARK: Units

    private static func split(_ target: String, chinese: Bool) -> [Unit] {
        if chinese {
            let characters = Array(target.trimmingCharacters(in: .whitespacesAndNewlines))
            let hanCount = characters.filter(ChineseDisplay.isHan).count
            // The sentence's own reading keeps characters with more than one
            // reading right; one character at a time is the fallback.
            let syllables = ChineseDisplay.sentencePinyin(String(characters))
                .split(whereSeparator: { $0.isWhitespace })
                // The reading keeps punctuation on the syllable before it.
                .map { String($0.filter(\.isLetter)) }
                .filter { !$0.isEmpty }
            var next = 0
            var units: [Unit] = []
            for character in characters where !character.isWhitespace {
                if ChineseDisplay.isHan(character) {
                    let pinyin = syllables.count == hanCount ? syllables[next] : characterPinyin(String(character))
                    next += 1
                    units.append(Unit(id: units.count, text: String(character), pinyin: pinyin, scored: true))
                } else {
                    // Punctuation, digits and Latin letters are shown but not checked.
                    units.append(Unit(id: units.count, text: String(character), pinyin: "", scored: false))
                }
            }
            return units
        }
        return target.split(whereSeparator: { $0.isWhitespace }).enumerated().map { index, word in
            let text = String(word)
            return Unit(id: index, text: text, pinyin: "", scored: !SpeakingReflection.tokens(text).isEmpty)
        }
    }


    static func characterPinyin(_ character: String) -> String {
        #if canImport(Darwin) || os(Linux)
        let latin = String((character.applyingTransform(.mandarinToLatin, reverse: false) ?? "")
            .lowercased().filter(\.isLetter))
        return latin.contains(where: ChineseDisplay.isHan) ? "" : latin
        #else
        return ""
        #endif
    }
}
