import Foundation

/// One import decision shared by the preview, saved count, and final write.
/// Word endings, accents, and distinct meanings are never guessed away.
public struct ScanImportPlan: Sendable {
    public enum Disposition: Equatable, Sendable {
        case newWord, additionalMeaning, duplicateInBank, duplicateInScan, incomplete

        public var canAdd: Bool { self == .newWord || self == .additionalMeaning }
    }

    public let rows: [ReviewedScanWord]
    public let dispositions: [Disposition]

    public var additions: [ReviewedScanWord] {
        zip(rows, dispositions).compactMap { pair in pair.1.canAdd ? pair.0 : nil }
    }

    public var duplicateCount: Int {
        dispositions.filter { $0 == .duplicateInBank || $0 == .duplicateInScan }.count
    }

    public init(rows: [ReviewedScanWord], existing: [WordEntry] = []) {
        self.rows = rows
        let inBank = Dictionary(grouping: existing.map {
            Identity(word: $0.word, meaning: $0.meaningZh, part: $0.partOfSpeech)
        }, by: \.word)
        var inScan: [String: [Identity]] = [:]
        var decisions: [Disposition] = []
        for row in rows {
            let identity = Identity(word: row.word, meaning: row.meaningZh, part: row.partOfSpeech)
            guard !identity.word.isEmpty, !identity.meanings.isEmpty else {
                decisions.append(.incomplete)
                continue
            }
            let bankMatches = inBank[identity.word] ?? []
            let scanMatches = inScan[identity.word] ?? []
            if bankMatches.contains(where: { $0.matches(identity) }) {
                decisions.append(.duplicateInBank)
            } else if scanMatches.contains(where: { $0.matches(identity) }) {
                decisions.append(.duplicateInScan)
            } else {
                decisions.append(bankMatches.isEmpty && scanMatches.isEmpty ? .newWord : .additionalMeaning)
                inScan[identity.word, default: []].append(identity)
            }
        }
        dispositions = decisions
    }

    public static func wordKey(_ text: String) -> String {
        let normal = text.precomposedStringWithCompatibilityMapping
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2010}", with: "-")
            .replacingOccurrences(of: "\u{2011}", with: "-")
            .replacingOccurrences(of: "\u{2013}", with: "-")
            .replacingOccurrences(of: "\u{2014}", with: "-")
            .replacingOccurrences(of: "\u{200B}", with: "")
            .replacingOccurrences(of: "\u{FEFF}", with: "")
        return normal.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
    }

    public static func sameEntry(_ lhs: ReviewedScanWord, _ rhs: ReviewedScanWord) -> Bool {
        Identity(word: lhs.word, meaning: lhs.meaningZh, part: lhs.partOfSpeech)
            .matches(Identity(word: rhs.word, meaning: rhs.meaningZh, part: rhs.partOfSpeech))
    }

    private struct Identity {
        let word: String
        let meanings: Set<String>
        let parts: Set<String>

        init(word: String, meaning: String, part: String) {
            self.word = ScanImportPlan.wordKey(word)
            meanings = Set(ChineseDisplay.meaningParts(meaning.precomposedStringWithCompatibilityMapping)
                .map { part in
                    let clean = part.replacingOccurrences(of: "\u{200B}", with: "").replacingOccurrences(of: "\u{FEFF}", with: "")
                    let spaced = clean.split(whereSeparator: \.isWhitespace).joined(separator: " ")
                    return spaced.replacingOccurrences(of: "(?<=\\p{Han})\\s+(?=\\p{Han})", with: "", options: .regularExpression)
                }
                .filter { !$0.isEmpty })
            let aliases = ["noun": "n", "verb": "v", "adjective": "adj", "a": "adj",
                           "adverb": "adv", "pronoun": "pron", "preposition": "prep",
                           "conjunction": "conj", "interjection": "int", "interj": "int",
                           "ad": "adv", "determiner": "det"]
            let separators = CharacterSet(charactersIn: "/;,；，、 ")
            parts = Set(part.precomposedStringWithCompatibilityMapping.lowercased()
                .replacingOccurrences(of: ".", with: "").components(separatedBy: separators)
                .filter { !$0.isEmpty }.map { aliases[$0] ?? $0 })
        }

        func matches(_ other: Identity) -> Bool {
            word == other.word && meanings == other.meanings
                && (parts.isEmpty || other.parts.isEmpty || parts == other.parts)
        }
    }
}

extension ScannedWordCandidate {
    public var reviewedWord: ReviewedScanWord {
        ReviewedScanWord(meaningZh: meaningZh, partOfSpeech: partOfSpeech, word: word)
    }
}
