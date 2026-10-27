import Foundation

/// How a Chinese meaning is shown on a card: the first two senses, the rest,
/// and toneless pinyin for the first two. Port of `src/lib/chineseDisplay.ts`.
public struct ChineseMeaningDisplay: Equatable, Hashable, Sendable {
    public var primary: String
    public var supplemental: String
    public var pinyin: String

    public init(primary: String, supplemental: String, pinyin: String) {
        self.primary = primary
        self.supplemental = supplemental
        self.pinyin = pinyin
    }
}

public enum ChineseDisplay {
    /// `/[；;，,、]/` in the TypeScript app.
    static let meaningSeparators = CharacterSet(charactersIn: "；;，,、")

    /// Readings the system transliterator gets wrong, matching the
    /// `customPinyin` overrides in the TypeScript app.
    static let pinyinOverrides: [(text: [Character], syllables: [String])] = [
        (Array("調整"), ["tiao", "zheng"]),
        (Array("敢於"), ["gan", "yu"]),
    ]

    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var pinyinCache: [String: String] = [:]

    /// JavaScript `String.prototype.trim()`.
    static func jsTrim(_ text: String) -> String {
        var set = CharacterSet.whitespacesAndNewlines
        set.insert("\u{FEFF}")
        return text.trimmingCharacters(in: set)
    }

    /// Splits on `；;，,、`, trims, drops empty parts and repeats.
    public static func meaningParts(_ meaning: String) -> [String] {
        var seen = Set<String>()
        var parts: [String] = []
        for raw in meaning.components(separatedBy: meaningSeparators) {
            let part = jsTrim(raw)
            if !part.isEmpty, seen.insert(part).inserted {
                parts.append(part)
            }
        }
        return parts
    }

    /// The first two senses joined with `；` (or the trimmed meaning when it has none).
    public static func conciseMeaning(_ meaning: String) -> String {
        let parts = meaningParts(meaning)
        return parts.isEmpty ? jsTrim(meaning) : parts.prefix(2).joined(separator: "；")
    }

    /// Every sense after the first two, joined with `；`.
    public static func supplementalMeaning(_ meaning: String) -> String {
        meaningParts(meaning).dropFirst(2).joined(separator: "；")
    }

    /// Toneless pinyin per sense (`ü` kept), syllables separated by single
    /// spaces, senses joined with `；`, non-Chinese characters removed.
    public static func meaningPinyin(_ meaning: String) -> String {
        cacheLock.lock()
        let cached = pinyinCache[meaning]
        cacheLock.unlock()
        if let cached { return cached }

        let prepared = meaningParts(meaning)
            .map { pinyinSyllables($0).joined(separator: " ") }
            .filter { !$0.isEmpty }
            .joined(separator: "；")

        cacheLock.lock()
        pinyinCache[meaning] = prepared
        cacheLock.unlock()
        return prepared
    }

    public static func display(_ meaning: String) -> ChineseMeaningDisplay {
        let primary = conciseMeaning(meaning)
        return ChineseMeaningDisplay(
            primary: primary,
            supplemental: supplementalMeaning(meaning),
            pinyin: meaningPinyin(primary)
        )
    }

    // MARK: - Readings

    private struct ReadingsDocument: Decodable {
        let schemaVersion: Int
        let readings: [String: String]
    }

    /// Tone-marked pinyin for every sense, example sentence and speaking card
    /// the app ships, written by scripts/build-pinyin-readings.mjs. It reads
    /// whole words in context (長大 zhǎng dà, 銀行 yín háng, 還是 hái shì) and uses
    /// Taiwan's standard readings, which the system transliterator, reading
    /// one character at a time, gets wrong. Words a learner adds fall back to
    /// the transliterator.
    static let readings: [String: String] = {
        guard let url = Bundle.module.url(forResource: "pinyin-readings", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let document = try? JSONDecoder().decode(ReadingsDocument.self, from: data),
              document.schemaVersion == 1 else { return [:] }
        return document.readings
    }()

    /// Loads the bundled readings, so the first card in Learn Chinese mode
    /// does not wait for them. Call it off the main thread.
    public static func prepareReadings() { _ = readings.isEmpty }

    /// Pinyin for a sentence, with Chinese punctuation in its Latin form.
    /// Empty when the text has no Chinese characters.
    public static func sentencePinyin(_ text: String) -> String {
        let trimmed = jsTrim(text)
        guard trimmed.contains(where: isHan) else { return "" }
        if let reading = readings[trimmed] { return reading }
        let key = "sentence:\(trimmed)"
        cacheLock.lock()
        let cached = pinyinCache[key]
        cacheLock.unlock()
        if let cached { return cached }
        var value = ""
        #if canImport(Darwin) || os(Linux)
        let latinPunctuation: [(String, String)] = [("，", ", "), ("。", ". "), ("！", "! "), ("？", "? "), ("：", ": "),
                                                    ("；", "; "), ("、", ", "), ("「", " \u{201C}"), ("」", "\u{201D} ")]
        var marked = trimmed
        for (chinese, latin) in latinPunctuation { marked = marked.replacingOccurrences(of: chinese, with: latin) }
        if let latin = marked.applyingTransform(.mandarinToLatin, reverse: false) {
            value = latin.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").lowercased()
            for mark in [",", ".", "!", "?", ":", ";", "\u{201D}"] {
                value = value.replacingOccurrences(of: " \(mark)", with: mark)
            }
            value = value.replacingOccurrences(of: "\u{201C} ", with: "\u{201C}")
        }
        #endif
        cacheLock.lock()
        pinyinCache[key] = value
        cacheLock.unlock()
        return value
    }

    /// Toneless pinyin for each sense, without spaces and with `ü` as `v`,
    /// separated by single spaces: what a pinyin search is compared with.
    public static func pinyinSearchKey(_ meaning: String) -> String {
        meaningParts(meaning)
            .map { pinyinSearchTerm(pronunciationWithTones($0)) ?? "" }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// What a learner typed as pinyin, the way search keys are written:
    /// tones (marks or numbers), spaces and apostrophes removed, `ü`, `u:`
    /// and `v` all as `v`. Nil when it is not pinyin at all.
    public static func pinyinSearchTerm(_ text: String) -> String? {
        let plain = stripTones(text.lowercased())
            .replacingOccurrences(of: "u:", with: "v")
            .replacingOccurrences(of: "ü", with: "v")
            .filter { !$0.isWhitespace && !"'’012345；;".contains($0) }
        guard !plain.isEmpty, plain.allSatisfy({ $0.isASCII && $0.isLetter }) else { return nil }
        return plain
    }

    /// Native reading support keeps tone marks and the separator between senses.
    public static func pronunciationWithTones(_ meaning: String) -> String {
        let key = "tones:\(meaning)"
        cacheLock.lock()
        let cached = pinyinCache[key]
        cacheLock.unlock()
        if let cached { return cached }
        let value = meaningParts(meaning).compactMap { part -> String? in
            if let reading = readings[part] { return reading }
            let corrected = part.replacingOccurrences(of: "調整", with: "tiáo zhěng")
                .replacingOccurrences(of: "敢於", with: "gǎn yú")
                .replacingOccurrences(of: "為了", with: "wèi le")
                .replacingOccurrences(of: "因為", with: "yīn wèi")
                .replacingOccurrences(of: "為什麼", with: "wèi shén me")
            #if canImport(Darwin) || os(Linux)
            return corrected.applyingTransform(.mandarinToLatin, reverse: false)?
                .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").lowercased()
            #else
            return nil
            #endif
        }.joined(separator: "；")
        cacheLock.lock()
        pinyinCache[key] = value
        cacheLock.unlock()
        return value
    }

    // MARK: - Pinyin

    static func isHan(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3007, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0x20000...0x323AF: return true
            default: return false
            }
        }
    }

    /// Syllables for one sense: overrides first, then the system Mandarin
    /// transliteration of each run of Chinese characters.
    static func pinyinSyllables(_ text: String) -> [String] {
        let characters = Array(text)
        var syllables: [String] = []
        var run = ""

        func flushRun() {
            guard !run.isEmpty else { return }
            syllables.append(contentsOf: transliterate(run))
            run = ""
        }

        var index = 0
        outer: while index < characters.count {
            for override in pinyinOverrides where characters[index...].starts(with: override.text) {
                flushRun()
                syllables.append(contentsOf: override.syllables)
                index += override.text.count
                continue outer
            }
            let character = characters[index]
            if isHan(character) {
                run.append(character)
            } else {
                flushRun()
            }
            index += 1
        }
        flushRun()
        return syllables
    }

    static func transliterate(_ han: String) -> [String] {
        #if canImport(Darwin) || os(Linux)
        guard let latin = han.applyingTransform(.mandarinToLatin, reverse: false) else { return [] }
        return latin
            .split(whereSeparator: { $0.isWhitespace })
            .map { stripTones(String($0)).lowercased() }
            .filter { syllable in !syllable.isEmpty && !syllable.contains(where: isHan) }
        #else
        return []
        #endif
    }

    /// Removes tone marks (macron, acute, caron, grave) but keeps `ü`.
    static func stripTones(_ syllable: String) -> String {
        let toneMarks: Set<UInt32> = [0x0300, 0x0301, 0x0304, 0x030C]
        var scalars = String.UnicodeScalarView()
        for scalar in syllable.decomposedStringWithCanonicalMapping.unicodeScalars where !toneMarks.contains(scalar.value) {
            scalars.append(scalar)
        }
        return String(scalars).precomposedStringWithCanonicalMapping
    }
}

// Free functions named as in the TypeScript module.

public func conciseChineseMeaning(_ meaning: String) -> String { ChineseDisplay.conciseMeaning(meaning) }
public func supplementalChineseMeaning(_ meaning: String) -> String { ChineseDisplay.supplementalMeaning(meaning) }
public func chineseMeaningPinyin(_ meaning: String) -> String { ChineseDisplay.meaningPinyin(meaning) }
public func chineseMeaningDisplay(_ meaning: String) -> ChineseMeaningDisplay { ChineseDisplay.display(meaning) }
