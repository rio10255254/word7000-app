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
    public var needsReview: Bool
    /// The spelling first read, when another reading of the same entry on
    /// the page was taken instead (the review offers to restore it).
    public var originalWord: String?
    /// A spelling to offer, never applied without the learner's tap.
    public var suggestedWord: String?
    public var id: String { key }

    public init(key: String, meaningZh: String, partOfSpeech: String, word: String, needsReview: Bool = false,
                originalWord: String? = nil, suggestedWord: String? = nil) {
        self.key = key
        self.meaningZh = meaningZh
        self.partOfSpeech = partOfSpeech
        self.word = word
        self.needsReview = needsReview
        self.originalWord = originalWord
        self.suggestedWord = suggestedWord
    }
}

/// Turns text recognised on a photo of a vocabulary sheet into word / meaning
/// pairs. The meaning is the one printed on the paper; nothing is translated.
/// The parser rules first written for the web app.
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

    public static let posTokens: Set<String> = [
        "n", "v", "vt", "vi", "a", "adj", "ad", "adv", "prep", "conj", "pron", "phr", "num", "int", "interj", "art", "aux",
    ]
    static let maxHeadwordTokens = 4

    /// Marks on a list that Vision, reading for Chinese, takes for a Chinese
    /// character: a check box (口 囗 日 曰), a box with heavy edges or a
    /// serifed capital I (工), a dash (一), a bar (丨), a plus (十) or an
    /// equals sign (二). On their own beside English they are not meanings.
    static let markLookalikes: Set<Character> = ["口", "囗", "日", "曰", "工", "一", "丨", "十", "二"]
    /// The marks that stand between a word and its meaning ("abandon – 放棄").
    static let separatorLookalikes: Set<Character> = ["一", "丨", "二"]
    /// Put where a mark was taken out, so the words either side stay apart.
    static let markGap: Unicode.Scalar = "\u{2063}"
    /// Small words that start a new sentence or label when capitalised in the
    /// middle of a lowercase run ("when Starts Since" is a note beside a
    /// headword, not a phrase to learn).
    static let functionWords: Set<String> = [
        "a", "after", "although", "an", "and", "as", "at", "because", "before", "but", "by", "during", "for", "from",
        "how", "if", "in", "of", "on", "or", "since", "so", "than", "the", "though", "to", "until", "what", "when",
        "where", "which", "while", "who", "why", "with",
    ]

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
        let page = PageContext(readingRows(ordered))
        let parsed = ordered.filter { !page.isStrayMark($0, among: ordered) }.map { parseLine($0, page: page) }
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

        var seen: [String: [ReviewedScanWord]] = [:]
        return results.enumerated().compactMap { index, result in
            let dedupeKey = ScanImportPlan.wordKey(result.word)
            let reviewed = ReviewedScanWord(meaningZh: result.meaningZh, partOfSpeech: result.partOfSpeech, word: result.word)
            guard !result.meaningZh.isEmpty,
                  !(seen[dedupeKey] ?? []).contains(where: { ScanImportPlan.sameEntry($0, reviewed) }) else { return nil }
            seen[dedupeKey, default: []].append(reviewed)
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

    /// Pairs from one reading of a page. The boxes on each baseline are
    /// joined into rows first; the boxes on their own come second and only
    /// add what the rows missed (a meaning written under its word). The same
    /// entry paired twice, once with a note beside it, is one entry.
    public static func parsePage(_ lines: [ScannedLine]) -> [ScannedWordCandidate] {
        ScanGrounding.merging(primary: parse(readingRows(lines)), supplemental: parse(lines))
    }

    /// Lines with Chinese on them other than a lone mark (a check box read
    /// as 口), about how many meanings the page should give.
    public static func meaningLineCount(_ lines: [ScannedLine]) -> Int {
        lines.filter { line in
            pieces(stripLeadingNumbering(normalise(line.text))).contains { $0.kind == .cjk && !$0.isLoneMark }
        }.count
    }

    /// Every English word read on the page, lowercased, as evidence for
    /// choosing between two readings of one word.
    public static func latinWords(in lines: [ScannedLine]) -> Set<String> {
        var words = Set<String>()
        for line in lines {
            for token in line.text.split(whereSeparator: { !($0.isASCII && $0.isLetter) }) where token.count >= 2 {
                words.insert(token.lowercased())
            }
        }
        return words
    }

    /// Vision may return the number, headword, part and meaning as separate
    /// boxes. Join non-overlapping boxes on one baseline before pairing them.
    public static func readingRows(_ lines: [ScannedLine]) -> [ScannedLine] {
        let sorted = lines.sorted {
            let left = $0.y + $0.height / 2, right = $1.y + $1.height / 2
            return left == right ? $0.x < $1.x : left < right
        }
        var groups: [[ScannedLine]] = []
        for line in sorted {
            if let anchor = groups.last?.first,
               abs((line.y + line.height / 2) - (anchor.y + anchor.height / 2)) <= max(anchor.height, line.height) * 0.45 {
                groups[groups.count - 1].append(line)
            } else {
                groups.append([line])
            }
        }
        return groups.flatMap { group -> [ScannedLine] in
            let fragments = group.sorted { $0.x < $1.x }
            guard fragments.count > 1 else { return fragments }
            for i in 1..<fragments.count {
                if fragments[i].x < fragments[i - 1].x + fragments[i - 1].width - 0.005 { return fragments }
            }
            let x = fragments.map(\.x).min() ?? 0
            let y = fragments.map(\.y).min() ?? 0
            let right = fragments.map { $0.x + $0.width }.max() ?? x
            let bottom = fragments.map { $0.y + $0.height }.max() ?? y
            return [ScannedLine(text: fragments.map(\.text).joined(separator: " "), x: x, y: y, width: right - x, height: bottom - y)]
        }
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

    // MARK: Marks read as Chinese

    enum PieceKind { case latin, cjk, other }

    /// A run of one kind inside a whitespace-separated token ("工walk" is
    /// two pieces of one token).
    struct Piece {
        var text: String
        var kind: PieceKind
        var token: Int

        var isLoneMark: Bool {
            kind == .cjk && text.count == 1 && markLookalikes.contains(text.first!)
        }
    }

    static func pieces(_ text: String) -> [Piece] {
        var result: [Piece] = []
        for (token, word) in text.split(whereSeparator: { $0.isWhitespace }).enumerated() {
            var current = String.UnicodeScalarView()
            var currentIsCJK = false
            func flush() {
                guard !current.isEmpty else { return }
                let value = String(current)
                let kind: PieceKind = currentIsCJK ? .cjk : value.unicodeScalars.contains(where: isLatinLetter) ? .latin : .other
                result.append(Piece(text: value, kind: kind, token: token))
                current = String.UnicodeScalarView()
            }
            for scalar in word.unicodeScalars {
                let cjk = isCJK(scalar)
                if !current.isEmpty, cjk != currentIsCJK { flush() }
                currentIsCJK = cjk
                current.append(scalar)
            }
            flush()
        }
        return result
    }

    enum Orientation { case englishFirst, chineseFirst, unknown }

    /// What one page says about its marks: which look-alike characters it
    /// uses as bullets or boxes, and whether its entries put the English or
    /// the Chinese first.
    struct PageContext {
        /// Look-alikes set apart from the Chinese on two or more lines: the
        /// page's bullets or boxes, never a meaning on this page.
        var marks: Set<Character> = []
        var orientation: Orientation = .unknown

        init() {}

        /// `rows` are the page's lines joined along each baseline, so a box
        /// read apart from its row counts with that row.
        init(_ rows: [ScannedLine]) {
            let lines = rows.map { ScanParser.pieces(ScanParser.stripLeadingNumbering($0.text)) }
            var englishFirst = 0, chineseFirst = 0
            for parts in lines {
                let words = parts.filter { $0.kind != .other && !$0.isLoneMark }
                guard let first = words.first else { continue }
                if first.kind == .latin, words.contains(where: { $0.kind == .cjk }) { englishFirst += 1 }
                if first.kind == .cjk, words.contains(where: { $0.kind == .latin }) { chineseFirst += 1 }
            }
            orientation = englishFirst > chineseFirst ? .englishFirst : chineseFirst > englishFirst ? .chineseFirst : .unknown
            var lineCounts: [Character: Int] = [:]
            for parts in lines {
                var seen = Set<Character>()
                for index in parts.indices where parts[index].isLoneMark && !Self.isInsideChinese(parts, index) {
                    // "日 rì sun" and "日 rì day" on a Chinese-first page are words.
                    if Self.leadsEnglish(parts, index), orientation != .englishFirst { continue }
                    seen.insert(parts[index].text.first!)
                }
                for mark in seen { lineCounts[mark, default: 0] += 1 }
            }
            marks = Set(lineCounts.filter { $0.value >= 2 }.keys)
        }

        /// Chinese on both sides ("工 作" in the middle of a meaning).
        static func isInsideChinese(_ parts: [Piece], _ index: Int) -> Bool {
            neighbour(parts, index, step: -1).map { parts[$0].kind } == .cjk
                && neighbour(parts, index, step: 1).map { parts[$0].kind } == .cjk
        }

        /// First on the line, right before English ("口 mouth", "□ walk").
        static func leadsEnglish(_ parts: [Piece], _ index: Int) -> Bool {
            neighbour(parts, index, step: -1) == nil && neighbour(parts, index, step: 1).map { parts[$0].kind } == .latin
        }

        /// The nearest word (not a number or punctuation) before or after `index`.
        static func neighbour(_ parts: [Piece], _ index: Int, step: Int) -> Int? {
            var probe = index + step
            while parts.indices.contains(probe) {
                if parts[probe].kind != .other { return probe }
                probe += step
            }
            return nil
        }

        /// A look-alike with no Chinese next to it: between English words or
        /// at the edge of the line. One written inside Chinese ("工 作") is
        /// part of the meaning.
        static func isStandalone(_ parts: [Piece], _ index: Int) -> Bool {
            guard parts[index].isLoneMark else { return false }
            let before = neighbour(parts, index, step: -1).map { parts[$0].kind }
            let after = neighbour(parts, index, step: 1).map { parts[$0].kind }
            return before != .cjk && after != .cjk
        }

        /// The line's text with every mark that is not a meaning taken out.
        func removingMarks(from text: String) -> String {
            let parts = ScanParser.pieces(text)
            var removed = Set<Int>()
            for index in parts.indices where parts[index].isLoneMark && isMark(parts, index) {
                removed.insert(index)
            }
            guard !removed.isEmpty else { return text }
            var tokens: [String] = []
            for (index, part) in parts.enumerated() {
                let piece = removed.contains(index) ? String(Character(ScanParser.markGap)) : part.text
                if tokens.count <= part.token {
                    tokens.append(piece)
                } else {
                    tokens[tokens.count - 1] += piece
                }
            }
            return tokens.joined(separator: " ")
        }

        func isMark(_ parts: [Piece], _ index: Int) -> Bool {
            guard !Self.isInsideChinese(parts, index) else { return false }
            let glyph = parts[index].text.first!
            if marks.contains(glyph) {
                return !(Self.leadsEnglish(parts, index) && orientation == .chineseFirst)
            }
            // Beside Chinese, only a mark the page uses again counts.
            guard Self.isStandalone(parts, index) else { return false }
            let before = Self.neighbour(parts, index, step: -1)
            guard let after = Self.neighbour(parts, index, step: 1), parts[after].kind == .latin else { return false }
            let chineseLater = parts[(after + 1)...].contains { $0.kind == .cjk }
            if before == nil {
                // A bullet before an English word, unless the page lists Chinese first ("口 mouth").
                switch orientation {
                case .englishFirst: return true
                case .chineseFirst: return false
                case .unknown: return chineseLater
                }
            }
            // Between English words: a misread letter in a sentence
            // ("Since 工 was little"), unless more pairs follow ("one 一 two 二").
            return !chineseLater
        }

        /// A box read on its own as a single look-alike: a mark on this page,
        /// or a bullet just before an English word on the same row.
        func isStrayMark(_ line: ScannedLine, among lines: [ScannedLine]) -> Bool {
            let parts = ScanParser.pieces(ScanParser.stripLeadingNumbering(line.text))
            guard parts.count == 1, parts[0].isLoneMark else { return false }
            if marks.contains(parts[0].text.first!) { return true }
            guard orientation != .chineseFirst else { return false }
            let center = line.y + line.height / 2
            let right = line.x + line.width
            return lines.contains { other in
                let otherCenter = other.y + other.height / 2
                guard abs(otherCenter - center) <= max(line.height, other.height) * 0.6,
                      other.x >= right - 0.005, other.x - right <= max(0.06, line.width * 2) else { return false }
                return ScanParser.pieces(ScanParser.stripLeadingNumbering(other.text)).first { $0.kind != .other }?.kind == .latin
            }
        }
    }

    // MARK: One line

    static func parseLine(_ line: ScannedLine, page: PageContext = PageContext()) -> ParsedLine {
        let text = page.removingMarks(from: stripLeadingNumbering(line.text))
        let segments = splitSegments(text)
        var pairs: [Pair] = []
        var pending: Headword?

        // Lists written Chinese first ("學校 xuéxiào school", often for
        // learners of Chinese): each Chinese run pairs with the English after
        // it, any pinyin in between left out.
        if segments.count >= 2, segments[0].kind == .cjk {
            var chineseFirst: [Pair] = []
            var index = 0
            while index + 1 < segments.count {
                defer { index += 1 }
                guard segments[index].kind == .cjk, segments[index + 1].kind == .latin,
                      let headword = parseHeadword(removingPinyin(segments[index + 1].text)) else { continue }
                let meaning = cleanMeaning(segments[index].text)
                guard !meaning.isEmpty else { continue }
                chineseFirst.append(Pair(meaningZh: meaning, partOfSpeech: headword.partOfSpeech, word: headword.word))
                index += 1
            }
            if !chineseFirst.isEmpty {
                return ParsedLine(line: line, pairs: chineseFirst, pendingWord: nil, meaningOnly: nil)
            }
        }

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

    /// Vowels with tone marks. Pinyin that starts with one ("èr", "ài") is
    /// Latin text, not part of the Chinese before it.
    static let tonedVowels = Set("āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ".unicodeScalars)

    /// Splits a line wherever it switches between Latin letters and Chinese
    /// characters. Spaces, digits and punctuation stay with the run they
    /// follow, so "v." stays with its word and "；" with its meaning.
    static func splitSegments(_ text: String) -> [Segment] {
        var segments: [Segment] = []
        var afterMark = false
        for scalar in text.unicodeScalars {
            if scalar == markGap {
                // A mark was here: what follows starts a run of its own.
                afterMark = true
                continue
            }
            let kind: Kind? = isCJK(scalar) ? .cjk : isLatinLetter(scalar) || tonedVowels.contains(scalar) ? .latin : nil
            let char = String(scalar)
            guard let kind else {
                if !segments.isEmpty { segments[segments.count - 1].text += char }
                continue
            }
            if afterMark {
                afterMark = false
                segments.append(Segment(kind: kind, text: char))
            } else if let last = segments.last, last.kind == kind {
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

    /// Drops pinyin with tone marks ("xuéxiào", "lǜ") from a Latin run.
    static func removingPinyin(_ text: String) -> String {
        let toned = Set("āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜü")
        return text.split(whereSeparator: { $0.isWhitespace })
            .filter { token in !token.contains(where: { toned.contains(Character($0.lowercased())) }) }
            .joined(separator: " ")
    }

    static func parseHeadword(_ text: String) -> Headword? {
        let withoutPronunciation = removingPronunciation(text)
        let bracketsAsSpaces = String(withoutPronunciation.map { "()[]{}".contains($0) ? " " : $0 })
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
        // A capitalised small word inside a lowercase run starts another
        // sentence or label ("when Starts Since"), and a number after a word
        // makes a heading ("Unit 3", "Lesson 5").
        let startsLowercase = cleaned.first?.first.map { $0.isLowercase } ?? false
        let restartsMidway = startsLowercase && cleaned.dropFirst().contains { token in
            token.count >= 2 && token.first!.isUppercase && token.dropFirst().allSatisfy(\.isLowercase)
                && functionWords.contains(token.lowercased())
        }
        let numbered = rawTokens.dropFirst().contains { token in
            let core = token.trimmingCharacters(in: .punctuationCharacters)
            return !core.isEmpty && core.allSatisfy { $0.isASCII && $0.isNumber }
        }
        guard !looksLikeSentence, !restartsMidway, !numbered,
              !cleaned.isEmpty,
              cleaned.count <= maxHeadwordTokens,
              cleaned.allSatisfy(isHeadwordToken),
              cleaned.contains(where: { $0.count >= 2 })
        else { return nil }
        return Headword(partOfSpeech: pos.joined(separator: " / "), word: cleaned.joined(separator: " "))
    }

    static let pronunciationPattern = try! NSRegularExpression(pattern: #"(?<!\S)/[^/\n]+/(?=\s|$)|\[[^\]\n]+\]"#)

    static func removingPronunciation(_ text: String) -> String {
        var result = text
        let matches = pronunciationPattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let content = String(result[range].dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
            if !isPosToken(content) { result.replaceSubrange(range, with: " ") }
        }
        return result
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
        let parts = splitPos(base)
        return !parts.isEmpty && parts.allSatisfy { posTokens.contains($0.lowercased()) }
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
        var tokens = value.split(whereSeparator: { $0.isWhitespace })
        // The next entry's number, where two columns are read as one row
        // ("1. abandon 放棄 2. benefit 好處").
        while tokens.count >= 2, stripLeadingNumbering(String(tokens[tokens.count - 1])).isEmpty,
              tokens[tokens.count - 1].contains(where: { $0.isASCII && $0.isNumber }) {
            tokens.removeLast()
        }
        // A dash or equals sign between the word and its meaning, read as 一 or 二.
        func isSeparator(_ token: Substring) -> Bool { token.count == 1 && separatorLookalikes.contains(token.first!) }
        if tokens.count >= 2, isSeparator(tokens[0]) { tokens.removeFirst() }
        if tokens.count >= 2, isSeparator(tokens[tokens.count - 1]) { tokens.removeLast() }
        return tokens.joined(separator: " ")
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
