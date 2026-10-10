import Foundation

/// A line of text recognised on a photo, with its box normalised to the image
/// (0...1, origin at the top left).
public struct ScannedLine: Equatable, Sendable {
    public var text: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(text: String, x: Double, y: Double, width: Double, height: Double) {
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct ScannedWordCandidate: Equatable, Identifiable, Sendable {
    /// Stable within one scan, used as the list key while reviewing.
    public var key: String
    public var meaningZh: String
    public var partOfSpeech: String
    public var word: String
    public var id: String { key }

    public init(key: String, meaningZh: String, partOfSpeech: String, word: String) {
        self.key = key
        self.meaningZh = meaningZh
        self.partOfSpeech = partOfSpeech
        self.word = word
    }
}

/// Turns text recognised on a photo of a vocabulary sheet into word / meaning
/// pairs. The meaning is the one printed on the paper; nothing is translated.
/// Ported one-to-one from `src/lib/scanParser.ts`.
public enum ScanParser {
    struct Pair: Equatable {
        var meaningZh: String
        var partOfSpeech: String
        var word: String
    }

    struct Headword: Equatable {
        var partOfSpeech: String
        var word: String
    }

    struct ParsedLine {
        var line: ScannedLine
        var pairs: [Pair]
        /// English headword with no meaning on the same line.
        var pendingWord: Headword?
        /// The line is nothing but a Chinese meaning.
        var meaningOnly: String?
    }

    enum Kind { case latin, cjk }
    struct Segment { var kind: Kind; var text: String }

    static let posTokens: Set<String> = [
        "n", "v", "vt", "vi", "a", "adj", "ad", "adv", "prep", "conj", "pron", "phr", "num", "int", "interj", "art", "aux",
    ]
    static let maxHeadwordTokens = 4

    public static func parse(_ lines: [ScannedLine]) -> [ScannedWordCandidate] {
        let ordered = lines.enumerated()
            .map { offset, line -> (Int, ScannedLine) in
                var copy = line
                copy.text = normalise(line.text)
                return (offset, copy)
            }
            .filter { !$0.1.text.isEmpty }
            .sorted { left, right in
                if left.1.y != right.1.y { return left.1.y < right.1.y }
                if left.1.x != right.1.x { return left.1.x < right.1.x }
                return left.0 < right.0
            }
            .map(\.1)
        let parsed = ordered.map(parseLine)
        var usedMeaning = Set<Int>()
        var results: [Pair] = []

        for (index, entry) in parsed.enumerated() {
            results.append(contentsOf: entry.pairs)
            guard let pending = entry.pendingWord,
                  let partner = findMeaningPartner(parsed, index: index, used: usedMeaning)
            else { continue }
            usedMeaning.insert(partner)
            results.append(Pair(meaningZh: parsed[partner].meaningOnly ?? "", partOfSpeech: pending.partOfSpeech, word: pending.word))
        }

        var seen = Set<String>()
        return results.enumerated().compactMap { index, result in
            let dedupeKey = result.word.lowercased()
            guard !result.meaningZh.isEmpty, seen.insert(dedupeKey).inserted else { return nil }
            return ScannedWordCandidate(key: "\(index)-\(dedupeKey)", meaningZh: result.meaningZh, partOfSpeech: result.partOfSpeech, word: result.word)
        }
    }

    /// Pasted text (for example copied with Live Text from Photos) has no
    /// positions, only line order. Each line is laid out as its own row, so a
    /// word with its meaning on the line below still pairs up.
    public static func lines(fromPlainText text: String) -> [ScannedLine] {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { index, value in ScannedLine(text: value, x: 0.05, y: 0.02 + Double(index) * 0.035, width: 0.9, height: 0.03) }
    }

    // MARK: Pairing lines

    /// A headword without a meaning on its own line is paired with a
    /// meaning-only line either on the same row to its right (a two-column
    /// table) or directly below it (word on one line, meaning under it).
    static func findMeaningPartner(_ parsed: [ParsedLine], index: Int, used: Set<Int>) -> Int? {
        let source = parsed[index].line
        let sourceCenter = source.y + source.height / 2
        var sameRow: (distance: Double, index: Int)?
        var below: (distance: Double, index: Int)?

        for (candidateIndex, candidate) in parsed.enumerated() {
            guard candidateIndex != index, candidate.meaningOnly != nil, !used.contains(candidateIndex) else { continue }
            let line = candidate.line
            let center = line.y + line.height / 2
            let rowTolerance = max(source.height, line.height) * 0.6
            if abs(center - sourceCenter) <= rowTolerance, line.x > source.x {
                let distance = line.x - (source.x + source.width)
                if sameRow == nil || distance < sameRow!.distance { sameRow = (distance, candidateIndex) }
                continue
            }
            let gap = line.y - (source.y + source.height)
            let lineHeight = max(source.height, 0.005)
            if gap >= -lineHeight * 0.3, gap <= lineHeight * 1.6, abs(line.x - source.x) <= 0.15 {
                if below == nil || gap < below!.distance { below = (gap, candidateIndex) }
            }
        }

        guard let match = sameRow?.index ?? below?.index else { return nil }
        // The headword has to be the closest unclaimed word to that meaning;
        // otherwise a word further up would steal the meaning of the word under it.
        return closestPendingWord(parsed, meaningIndex: match, used: used) == index ? match : nil
    }

    static func closestPendingWord(_ parsed: [ParsedLine], meaningIndex: Int, used: Set<Int>) -> Int? {
        let meaning = parsed[meaningIndex].line
        let meaningCenter = meaning.y + meaning.height / 2
        var best: (index: Int, score: Double)?
        for (candidateIndex, candidate) in parsed.enumerated() {
            guard candidate.pendingWord != nil, !used.contains(candidateIndex) else { continue }
            let line = candidate.line
            let center = line.y + line.height / 2
            let rowTolerance = max(meaning.height, line.height) * 0.6
            let sameRow = abs(center - meaningCenter) <= rowTolerance && meaning.x > line.x
            let gap = meaning.y - (line.y + line.height)
            let above = gap >= -line.height * 0.3 && gap <= max(line.height, 0.005) * 1.6 && abs(meaning.x - line.x) <= 0.15
            guard sameRow || above else { continue }
            let score = sameRow ? meaning.x - (line.x + line.width) : 10 + gap
            if best == nil || score < best!.score { best = (candidateIndex, score) }
        }
        return best?.index
    }

    // MARK: One line

    static func parseLine(_ line: ScannedLine) -> ParsedLine {
        let text = stripLeadingNumbering(line.text)
        let segments = splitSegments(text)
        var pairs: [Pair] = []
        var pending: Headword?

        var index = 0
        while index < segments.count {
            defer { index += 1 }
            let segment = segments[index]
            guard segment.kind == .latin, let headword = parseHeadword(segment.text) else { continue }
            if index + 1 < segments.count, segments[index + 1].kind == .cjk {
                pairs.append(Pair(meaningZh: cleanMeaning(segments[index + 1].text), partOfSpeech: headword.partOfSpeech, word: headword.word))
                index += 1
            } else if segments.count == 1 {
                pending = headword
            }
        }

        var meaningOnly: String?
        if segments.count == 1, segments[0].kind == .cjk {
            let cleaned = cleanMeaning(segments[0].text)
            meaningOnly = cleaned.isEmpty ? nil : cleaned
        }
        return ParsedLine(line: line, pairs: pairs, pendingWord: pending, meaningOnly: meaningOnly)
    }

    /// Splits a line wherever it switches between Latin letters and Chinese
    /// characters. Spaces, digits and punctuation stay with the run they
    /// follow, so "v." stays with its word and "；" with its meaning.
    static func splitSegments(_ text: String) -> [Segment] {
        var segments: [Segment] = []
        for scalar in text.unicodeScalars {
            let kind: Kind? = isCJK(scalar) ? .cjk : isLatinLetter(scalar) ? .latin : nil
            let char = String(scalar)
            guard let kind else {
                if !segments.isEmpty { segments[segments.count - 1].text += char }
                continue
            }
            if let last = segments.last, last.kind == kind {
                segments[segments.count - 1].text += char
            } else if let last = segments.last, kind == .latin, last.kind == .cjk, endsWithOpeningBracket(last.text) {
                // Latin inside a Chinese bracket, like 解釋（sth），belongs to the meaning.
                segments[segments.count - 1].text += char
            } else {
                segments.append(Segment(kind: kind, text: char))
            }
        }
        return segments.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    static func endsWithOpeningBracket(_ text: String) -> Bool {
        let trimmed = String(text.reversed().drop(while: { $0.isWhitespace }).reversed())
        return trimmed.hasSuffix("（") || trimmed.hasSuffix("(")
    }

    static func parseHeadword(_ text: String) -> Headword? {
        let bracketsAsSpaces = String(text.map { "()[]{}".contains($0) ? " " : $0 })
        var rawTokens = bracketsAsSpaces.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        var tokens = rawTokens.map(trimToken).filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return nil }

        var pos: [String] = []
        while tokens.count > 1, isPosToken(tokens[tokens.count - 1]) {
            let token = tokens.removeLast().lowercased()
            pos.insert(contentsOf: splitPos(token), at: 0)
            if !rawTokens.isEmpty { rawTokens.removeLast() }
        }
        // "color/colour" is one headword with two spellings; keep the first.
        let words = tokens.map { String($0.split(separator: "/", omittingEmptySubsequences: false).first ?? "") }.filter { !$0.isEmpty }
        let cleaned = words.map { $0.hasSuffix(".") ? String($0.dropLast()) : $0 }
        // Example sentences sit on the same sheets. A capitalised run of three
        // or more words, or anything ending like a sentence, is not a headword.
        let lastRaw = rawTokens.last ?? ""
        let looksLikeSentence = (cleaned.count >= 2 && endsLikeSentence(lastRaw))
            || (cleaned.count >= 3 && (cleaned[0].first.map { $0.isASCII && $0.isUppercase } ?? false))
        guard !looksLikeSentence,
              !cleaned.isEmpty,
              cleaned.count <= maxHeadwordTokens,
              cleaned.allSatisfy(isHeadwordToken),
              cleaned.contains(where: { $0.count >= 2 })
        else { return nil }
        return Headword(partOfSpeech: pos.joined(separator: " / "), word: cleaned.joined(separator: " "))
    }

    /// Strips leading non-letters and trailing characters that cannot end a
    /// word (letters, apostrophes, dots, slashes and hyphens stay).
    static func trimToken(_ token: String) -> String {
        var scalars = Array(token.unicodeScalars)
        while let first = scalars.first, !isLatinLetter(first) { scalars.removeFirst() }
        let keep: Set<Character> = ["'", "’", ".", "/", "-"]
        while let last = scalars.last, !isLatinLetter(last), !keep.contains(Character(last)) { scalars.removeLast() }
        return String(String.UnicodeScalarView(scalars))
    }

    static func splitPos(_ token: String) -> [String] {
        token.split(whereSeparator: { "/.,&".contains($0) }).map(String.init)
    }

    static func isPosToken(_ token: String) -> Bool {
        let base = token.hasSuffix(".") ? String(token.dropLast()) : token
        return splitPos(base).allSatisfy { posTokens.contains($0.lowercased()) }
    }

    static func isHeadwordToken(_ token: String) -> Bool {
        guard let first = token.unicodeScalars.first, isLatinLetter(first) else { return false }
        return token.unicodeScalars.dropFirst().allSatisfy { isLatinLetter($0) || $0 == "'" || $0 == "’" || $0 == "-" }
    }

    static func endsLikeSentence(_ token: String) -> Bool {
        var characters = Array(token)
        if let last = characters.last, "\"”’'".contains(last) { characters.removeLast() }
        guard let last = characters.last else { return false }
        return ".?!".contains(last)
    }

    static func stripLeadingNumbering(_ text: String) -> String {
        var rest = Substring(text)
        rest = rest.drop(while: { $0.isWhitespace })
        var scalars = Array(rest.unicodeScalars)
        var consumed = 0

        func peek(_ offset: Int = 0) -> Unicode.Scalar? {
            scalars.indices.contains(consumed + offset) ? scalars[consumed + offset] : nil
        }

        let start = consumed
        // [(（]?\d{1,3}[)）.、:]?
        var probe = consumed
        if let s = scalars.indices.contains(probe) ? scalars[probe] : nil, s == "(" || s == "（" { probe += 1 }
        var digits = 0
        while digits < 3, scalars.indices.contains(probe), ("0"..."9").contains(scalars[probe]) {
            digits += 1
            probe += 1
        }
        if digits > 0 {
            if scalars.indices.contains(probe), [")", "）", ".", "、", ":"].contains(scalars[probe]) { probe += 1 }
            consumed = probe
        } else if let s = peek(), ("①"..."⑳").contains(s) || ["•", "·", "・", "-", "*"].contains(s) {
            consumed += 1
        }
        guard consumed > start else { return String(String.UnicodeScalarView(scalars)) }
        scalars.removeFirst(consumed)
        while let first = scalars.first, Character(first).isWhitespace { scalars.removeFirst() }
        return String(String.UnicodeScalarView(scalars))
    }

    static func cleanMeaning(_ text: String) -> String {
        let leading: Set<Character> = [":", "=", "-", "–", "—", ",", "，", ".", "。", "、"]
        let trailing: Set<Character> = [",", "，", ".", "、", ":", "=", "-", "–", "—"]
        var value = Substring(text)
        value = value.drop(while: { $0.isWhitespace || leading.contains($0) })
        while let last = value.last, last.isWhitespace || trailing.contains(last) { value = value.dropLast() }
        return value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    static func normalise(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        let keep: Set<UInt32> = [0xFF1B, 0xFF0C, 0xFF1A, 0xFF08, 0xFF09] // ；，：（）
        for scalar in text.unicodeScalars {
            if (0xFF01...0xFF5E).contains(scalar.value), !keep.contains(scalar.value) {
                scalars.append(Unicode.Scalar(scalar.value - 0xFEE0)!)
            } else if scalar.value == 0x3000 {
                scalars.append(" ")
            } else {
                scalars.append(scalar)
            }
        }
        return String(scalars).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        (0x3400...0x4DBF).contains(scalar.value) || (0x4E00...0x9FFF).contains(scalar.value) || (0xF900...0xFAFF).contains(scalar.value)
    }

    static func isLatinLetter(_ scalar: Unicode.Scalar) -> Bool {
        ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar)
    }
}
