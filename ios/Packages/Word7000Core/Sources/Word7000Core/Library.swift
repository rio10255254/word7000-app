import Foundation

public struct LibraryFilterOptions: Equatable, Sendable {
    public var initial: String?
    /// One level ("Core 3"), several separated by commas ("Core 3,Core 5"),
    /// or nil / "all" for every level.
    public var level: String?
    public var sort: LibrarySort

    public init(initial: String? = nil, level: String? = nil, sort: LibrarySort = .default) {
        self.initial = initial
        self.level = level
        self.sort = sort
    }
}

/// A word list prepared once for fast filtering and search. Build it again
/// only when the list itself changes.
public final class PreparedVocabulary: @unchecked Sendable {
    struct Record {
        let example: String
        let exampleZh: String
        let index: Int
        let meaning: String
        let normalizedWord: String
        /// Toneless pinyin of each Chinese sense, run together ("shiying
        /// tiaozheng"), so learners of Chinese can search by sound.
        let pinyin: String
        let word: WordEntry
    }

    public let words: [WordEntry]
    public let alphabeticalWords: [WordEntry]
    let indexById: [String: Int]
    let records: [Record]
    let alphabeticalRecords: [Record]

    public init(_ words: [WordEntry]) {
        self.words = words
        var indexById: [String: Int] = [:]
        for (index, word) in words.enumerated() where indexById[word.id] == nil {
            indexById[word.id] = index
        }
        self.indexById = indexById
        let records = words.enumerated().map { index, word in
            Record(
                example: word.example.lowercased(),
                exampleZh: word.exampleZh.lowercased(),
                index: index,
                meaning: "\(word.meaningZh) \(word.supplementalMeaningZh ?? "")".trimmingCharacters(in: .whitespaces).lowercased(),
                normalizedWord: word.word.lowercased(),
                pinyin: Self.searchPinyin(word),
                word: word
            )
        }
        self.records = records
        let alphabetical = records.sorted { left, right in
            let order = left.word.word.compare(right.word.word, options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en"))
            return order == .orderedSame ? left.index < right.index : order == .orderedAscending
        }
        self.alphabeticalRecords = alphabetical
        self.alphabeticalWords = alphabetical.map(\.word)
    }

    public func index(of wordId: String) -> Int? { indexById[wordId] }

    /// The levels a filter keeps, or nil for all of them.
    public static func levels(_ value: String?) -> Set<String>? {
        guard let value, value != "all" else { return nil }
        let levels = Set(value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
        return levels.isEmpty ? nil : levels
    }

    static func searchPinyin(_ word: WordEntry) -> String {
        let senses = ChineseDisplay.meaningParts(word.meaningZh) + ChineseDisplay.meaningParts(word.supplementalMeaningZh ?? "")
        return senses.filter { $0.contains(where: ChineseDisplay.isHan) }
            .map { ChineseSpelling.toneless(ChineseDisplay.pronunciationWithTones($0)) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    public func filter(state: ProgressState, query: String, filter: LibraryFilter, options: LibraryFilterOptions = .init(), rankedSearch: Bool = false,
                       pinyinSearch: Bool = false) -> [WordEntry] {
        let terms = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let levels = Self.levels(options.level)
        let initial = options.initial.flatMap { $0 == "all" ? nil : $0.uppercased() }

        if terms.isEmpty, filter == .all, levels == nil, initial == nil {
            return options.sort == .alphabetical ? alphabeticalWords : words
        }

        let source = options.sort == .alphabetical ? alphabeticalRecords : records
        // Parse each timestamp once here, not on every comparison while sorting.
        let usesRecency = options.sort != .alphabetical && (filter == .favorites || filter == .review || filter == .mastered)
        var matches: [(record: Record, recency: Double, score: Int)] = []
        for record in source {
            if let levels, !levels.contains(record.word.group) { continue }
            if let initial, !record.normalizedWord.uppercased().hasPrefix(initial) { continue }
            let score = Self.searchScore(record, terms: terms, pinyin: pinyinSearch)
            if !terms.isEmpty, score == 0 { continue }
            let progress = state.progress(for: record.word.id)
            switch filter {
            case .favorites where !progress.favorite: continue
            case .review where progress.status != .review: continue
            case .mastered where progress.status != .mastered: continue
            case .new where progress.status != .new: continue
            default: break
            }
            matches.append((record, usesRecency ? Self.recency(progress, filter: filter) : 0, score))
        }

        if (options.sort != .alphabetical || (rankedSearch && !terms.isEmpty)), !terms.isEmpty || filter == .favorites || filter == .review || filter == .mastered {
            matches.sort { a, b in
                if !terms.isEmpty, a.score != b.score { return a.score > b.score }
                if options.sort == .alphabetical {
                    return a.record.normalizedWord < b.record.normalizedWord
                }
                if a.recency != b.recency { return a.recency > b.recency }
                return a.record.index < b.record.index
            }
        }
        return matches.map(\.record.word)
    }

    static func searchScore(_ record: Record, terms: [String], pinyin: Bool = false) -> Int {
        guard !terms.isEmpty else { return 0 }
        var total = 0
        for term in terms {
            let score: Int
            if record.normalizedWord == term { score = 1000 }
            else if record.normalizedWord.hasPrefix(term) { score = 900 }
            else if record.normalizedWord.contains(term) { score = 760 }
            else if record.meaning.contains(term) { score = 680 }
            else if record.example.contains(term) { score = 540 }
            else if record.exampleZh.contains(term) { score = 520 }
            // By sound, for learners of Chinese: "shiying" or "shi4ying4" finds 適應.
            else if pinyin, term.count >= 2, !record.pinyin.isEmpty, term.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }),
                    record.pinyin.contains(ChineseSpelling.toneless(term)) { score = 500 }
            else { return 0 }
            total += score
        }
        return total
    }

    static func recency(_ progress: WordProgress, filter: LibraryFilter) -> Double {
        let value: String?
        switch filter {
        case .favorites: value = progress.favoritedAt
        case .review, .mastered: value = progress.statusUpdatedAt ?? progress.lastStudied
        default: value = nil
        }
        guard let value else { return 0 }
        return Self.parseDate(value)?.timeIntervalSince1970 ?? 0
    }

    // ISO8601DateFormatter is thread safe and costly to create, so these are shared.
    nonisolated(unsafe) private static let withFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    nonisolated(unsafe) private static let plain = ISO8601DateFormatter()
    nonisolated(unsafe) private static let dayOnly: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    static func parseDate(_ value: String) -> Date? {
        withFraction.date(from: value) ?? plain.date(from: value) ?? dayOnly.date(from: value)
    }
}
