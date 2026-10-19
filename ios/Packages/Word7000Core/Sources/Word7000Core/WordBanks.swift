import Foundation

/// A named list of words the learner made: by hand, or by scanning a sheet.
/// Same JSON shape as the React Native app's `CustomVocabSet`.
public struct CustomVocabSet: Codable, Equatable, Identifiable, Sendable {
    public var color: String
    public var createdAt: String
    public var id: String
    public var name: String
    public var sortOrder: Int
    public var updatedAt: String
    public var wordIds: [String]

    public init(color: String, createdAt: String, id: String, name: String, sortOrder: Int, updatedAt: String, wordIds: [String]) {
        self.color = color
        self.createdAt = createdAt
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.updatedAt = updatedAt
        self.wordIds = wordIds
    }
}

public struct CustomSetState: Codable, Equatable, Sendable {
    public var customWords: [WordEntry]
    public var deletedSetIds: [String: String]?
    public var sets: [CustomVocabSet]

    public init(customWords: [WordEntry] = [], deletedSetIds: [String: String]? = nil, sets: [CustomVocabSet] = []) {
        self.customWords = customWords
        self.deletedSetIds = deletedSetIds
        self.sets = sets
    }

    public static let empty = CustomSetState()
}

public struct ReviewedScanWord: Equatable, Sendable {
    public var meaningZh: String
    public var partOfSpeech: String
    public var word: String

    public init(meaningZh: String, partOfSpeech: String, word: String) {
        self.meaningZh = meaningZh
        self.partOfSpeech = partOfSpeech
        self.word = word
    }
}

public enum WordBanks {
    /// The built-in 7000-word list (plus words added by hand) is always a bank.
    public static let coreBankId = "core"
    /// Words saved from a scanned sheet carry the meaning printed on that
    /// sheet, so they live only in their own bank. The prefix keeps them out
    /// of the core library, where a second "abandon" with a different meaning
    /// would only confuse.
    public static let scannedWordIdPrefix = "scan-"
    public static let scannedWordGroup = "Scan"
    public static let setColors = ["#007AFF", "#34C759", "#5856D6", "#FF2D55", "#FF9500", "#00C7BE"]

    public static func isScannedWordId(_ id: String) -> Bool { id.hasPrefix(scannedWordIdPrefix) }

    /// Turns reviewed scan rows into vocabulary entries. The printed meaning
    /// always wins. When the word is also in the built-in list, its
    /// pronunciation and example sentence are borrowed so the card is not left
    /// half empty.
    public static func buildScannedWords(_ rows: [ReviewedScanWord], coreWords: [WordEntry], stamp: String = String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)) -> [WordEntry] {
        var coreByName: [String: WordEntry] = [:]
        for word in coreWords where coreByName[word.word.lowercased()] == nil {
            coreByName[word.word.lowercased()] = word
        }
        var seen = Set<String>()
        return rows.enumerated().compactMap { index, row in
            let word = row.word.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            let meaning = row.meaningZh.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = word.lowercased()
            guard !word.isEmpty, !meaning.isEmpty, seen.insert(key).inserted else { return nil }
            let core = coreByName[key]
            let slug = slugify(key)
            let pos = row.partOfSpeech.trimmingCharacters(in: .whitespacesAndNewlines)
            return WordEntry(
                id: "\(scannedWordIdPrefix)\(slug)-\(stamp)-\(index)",
                word: word,
                partOfSpeech: pos.isEmpty ? (core?.partOfSpeech ?? "") : pos,
                pronunciation: core?.pronunciation ?? "",
                meaningZh: meaning,
                supplementalMeaningZh: "",
                example: core?.example ?? "",
                exampleZh: core?.exampleZh ?? "",
                group: scannedWordGroup
            )
        }
    }

    public static func slug(_ key: String) -> String { slugify(key) }

    static func slugify(_ key: String) -> String {
        var slug = ""
        var lastWasDash = false
        for scalar in key.unicodeScalars {
            if ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) {
                slug.unicodeScalars.append(scalar)
                lastWasDash = false
            } else if !lastWasDash {
                slug += "-"
                lastWasDash = true
            }
        }
        if slug.hasPrefix("-") { slug.removeFirst() }
        if slug.hasSuffix("-") { slug.removeLast() }
        return slug.isEmpty ? "word" : slug
    }

    public static func defaultScanBankName(date: Date = Date(), chineseMode: Bool = false, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.month, .day], from: date)
        return chineseMode ? "Scan \(parts.month!)/\(parts.day!)" : "掃描 \(parts.month!)/\(parts.day!)"
    }

    /// Words of a set, in the set's order, skipping ids that no longer exist.
    public static func words(of set: CustomVocabSet?, in allWords: [WordEntry]) -> [WordEntry] {
        guard let set else { return [] }
        var byId: [String: WordEntry] = [:]
        for word in allWords where byId[word.id] == nil { byId[word.id] = word }
        return set.wordIds.compactMap { byId[$0] }
    }

    /// Hand-added words that do not clash with the base list, ahead of it.
    public static func mergeCustomWords(base: [WordEntry], custom: [WordEntry], includeBankCopies: Bool = false) -> [WordEntry] {
        let baseIds = Set(base.map(\.id))
        let baseNames = Set(base.map { $0.word.lowercased() })
        return custom.filter { !baseIds.contains($0.id) && (includeBankCopies || !baseNames.contains($0.word.lowercased())) } + base
    }

    public static func nextColor(for sets: [CustomVocabSet]) -> String {
        setColors[sets.count % setColors.count]
    }
}
