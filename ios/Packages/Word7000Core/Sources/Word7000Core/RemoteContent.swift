import Foundation

/// Word list content the developer publishes without an app update: fixes to
/// the built-in words and extra official word banks. Fetched from the
/// `content_corrections` and `official_banks` tables and cached on the iPhone.
public struct RemoteContent: Codable, Equatable, Sendable {
    public var corrections: [WordCorrection]
    public var banks: [OfficialBank]

    public init(corrections: [WordCorrection] = [], banks: [OfficialBank] = []) {
        self.corrections = corrections
        self.banks = banks
    }

    public static let empty = RemoteContent()

    /// `words` with this mode's corrections applied; hidden words are left out.
    public func corrected(_ words: [WordEntry], mode: String) -> [WordEntry] {
        let fixes = Dictionary(corrections.filter { $0.mode == mode }.map { ($0.wordId, $0) }, uniquingKeysWith: { _, last in last })
        guard !fixes.isEmpty else { return words }
        return words.compactMap { word in
            guard let fix = fixes[word.id] else { return word }
            return fix.hidden ? nil : fix.applied(to: word)
        }
    }

    /// The official banks for one study mode, in the developer's order, each
    /// with its corrections applied.
    public func banks(for mode: String) -> [OfficialBank] {
        banks.filter { $0.mode == mode && !$0.words.isEmpty }
            .sorted { ($0.sort, $0.id) < ($1.sort, $1.id) }
            .map { bank in
                var bank = bank
                bank.words = corrected(bank.words, mode: mode)
                return bank
            }
    }
}

/// A fix to one word: only the fields given change.
public struct WordCorrection: Codable, Equatable, Sendable {
    public var mode: String
    public var wordId: String
    public var fields: [String: String]
    public var hidden: Bool

    enum CodingKeys: String, CodingKey {
        case mode
        case wordId = "word_id"
        case fields, hidden
    }

    public init(mode: String, wordId: String, fields: [String: String] = [:], hidden: Bool = false) {
        self.mode = mode
        self.wordId = wordId
        self.fields = fields
        self.hidden = hidden
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(String.self, forKey: .mode)
        wordId = try container.decode(String.self, forKey: .wordId)
        fields = (try? container.decode([String: String].self, forKey: .fields)) ?? [:]
        hidden = (try? container.decode(Bool.self, forKey: .hidden)) ?? false
    }

    public func applied(to word: WordEntry) -> WordEntry {
        var word = word
        for (field, value) in fields {
            let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
            switch field {
            case "word": if !value.isEmpty { word.word = value }
            case "partOfSpeech": word.partOfSpeech = value
            case "pronunciation": word.pronunciation = value
            case "meaningZh": if !value.isEmpty { word.meaningZh = value }
            case "supplementalMeaningZh": word.supplementalMeaningZh = value.isEmpty ? nil : value
            case "example": word.example = value
            case "exampleZh": word.exampleZh = value
            case "group": if !value.isEmpty { word.group = value }
            default: break
            }
        }
        return word
    }
}

/// A word bank the developer publishes, such as medical or business English.
public struct OfficialBank: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var mode: String
    public var nameZh: String
    public var nameEn: String
    public var descriptionZh: String
    public var descriptionEn: String
    public var icon: String
    public var color: String
    public var premium: Bool
    public var sort: Int
    public var updatedAt: String
    public var words: [WordEntry]

    enum CodingKeys: String, CodingKey {
        case id, mode, icon, color, premium, sort, words
        case nameZh = "name_zh"
        case nameEn = "name_en"
        case descriptionZh = "description_zh"
        case descriptionEn = "description_en"
        case updatedAt = "updated_at"
    }

    /// The id the bank goes by in the learner's settings, apart from their own banks.
    public static let selectionPrefix = "official:"
    public var selectionId: String { Self.selectionPrefix + id }
    /// Official words keep ids of their own, so their progress never mixes with the built-in words.
    public static let wordIdPrefix = "pack-"

    public init(id: String, mode: String, nameZh: String, nameEn: String = "", descriptionZh: String = "", descriptionEn: String = "",
                icon: String = "books.vertical.fill", color: String = "#5856D6", premium: Bool = false, sort: Int = 0,
                updatedAt: String = "", words: [WordEntry]) {
        self.id = id; self.mode = mode; self.nameZh = nameZh; self.nameEn = nameEn
        self.descriptionZh = descriptionZh; self.descriptionEn = descriptionEn
        self.icon = icon; self.color = color; self.premium = premium; self.sort = sort
        self.updatedAt = updatedAt; self.words = words
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        mode = try c.decode(String.self, forKey: .mode)
        nameZh = try c.decode(String.self, forKey: .nameZh)
        nameEn = (try? c.decode(String.self, forKey: .nameEn)) ?? ""
        descriptionZh = (try? c.decode(String.self, forKey: .descriptionZh)) ?? ""
        descriptionEn = (try? c.decode(String.self, forKey: .descriptionEn)) ?? ""
        icon = (try? c.decode(String.self, forKey: .icon)) ?? "books.vertical.fill"
        color = (try? c.decode(String.self, forKey: .color)) ?? "#5856D6"
        premium = (try? c.decode(Bool.self, forKey: .premium)) ?? false
        sort = (try? c.decode(Int.self, forKey: .sort)) ?? 0
        updatedAt = (try? c.decode(String.self, forKey: .updatedAt)) ?? ""
        // Words that do not decode, or whose ids could collide with the
        // built-in or the learner's own words, are skipped.
        let raw = (try? c.decode([FailableWord].self, forKey: .words)) ?? []
        var seen = Set<String>()
        words = raw.compactMap(\.word).filter { $0.id.hasPrefix(Self.wordIdPrefix) && seen.insert($0.id).inserted }
    }

    private struct FailableWord: Decodable {
        let word: WordEntry?
        init(from decoder: Decoder) throws { word = try? WordEntry(from: decoder) }
    }
}
