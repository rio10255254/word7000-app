import Foundation

public struct LibraryFilterOptions: Equatable, Sendable {
    public var initial: String?
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

    public func filter(state: ProgressState, query: String, filter: LibraryFilter, options: LibraryFilterOptions = .init(), rankedSearch: Bool = false) -> [WordEntry] {
        let terms = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let level = options.level.flatMap { $0 == "all" ? nil : $0 }
        let initial = options.initial.flatMap { $0 == "all" ? nil : $0.uppercased() }

        if terms.isEmpty, filter == .all, level == nil, initial == nil {
            return options.sort == .alphabetical ? alphabeticalWords : words
        }

        let source = options.sort == .alphabetical ? alphabeticalRecords : records
        var matches: [(record: Record, progress: WordProgress, score: Int)] = []
        for record in source {
            if let level, record.word.group != level { continue }
            if let initial, !record.normalizedWord.uppercased().hasPrefix(initial) { continue }
            let score = Self.searchScore(record, terms: terms)
            if !terms.isEmpty, score == 0 { continue }
            let progress = state.progress(for: record.word.id)
            switch filter {
            case .favorites where !progress.favorite: continue
            case .review where progress.status != .review: continue
            case .mastered where progress.status != .mastered: continue
            case .new where progress.status != .new: continue
            default: break
            }
            matches.append((record, progress, score))
        }

        if (options.sort != .alphabetical || (rankedSearch && !terms.isEmpty)), !terms.isEmpty || filter == .favorites || filter == .review || filter == .mastered {
            matches.sort { a, b in
                if !terms.isEmpty, a.score != b.score { return a.score > b.score }
                if options.sort == .alphabetical {
                    return a.record.normalizedWord < b.record.normalizedWord
                }
                let aTime = Self.recency(a.progress, filter: filter)
                let bTime = Self.recency(b.progress, filter: filter)
                if aTime != bTime { return aTime > bTime }
                return a.record.index < b.record.index
            }
        }
        return matches.map(\.record.word)
    }

    static func searchScore(_ record: Record, terms: [String]) -> Int {
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

    static func parseDate(_ value: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: value) { return date }
        let plain = ISO8601DateFormatter()
        if let date = plain.date(from: value) { return date }
        let dayOnly = ISO8601DateFormatter()
        dayOnly.formatOptions = [.withFullDate]
        return dayOnly.date(from: value)
    }
}
