import Foundation

public struct LibraryFilterOptions: Equatable, Sendable {
    public var initial: String?
    public var level: String?
    public var sort: LibrarySort
    /// Learn Chinese mode: a search also finds a word by the pinyin of its
    /// Chinese meaning, with or without tones ("xuexi", "xué xí", "xue2xi2").
    public var matchPinyin: Bool

    public init(initial: String? = nil, level: String? = nil, sort: LibrarySort = .default, matchPinyin: Bool = false) {
        self.initial = initial
        self.level = level
        self.sort = sort
        self.matchPinyin = matchPinyin
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
    private let pinyinLock = NSLock()
    private var pinyinKeysStorage: [String]?

    /// Pinyin search keys by record index, built on the first pinyin search.
    func pinyinKeys() -> [String] {
        pinyinLock.lock()
        defer { pinyinLock.unlock() }
        if let pinyinKeysStorage { return pinyinKeysStorage }
        let keys = words.map { word in
            ChineseDisplay.pinyinSearchKey("\(word.meaningZh)；\(word.supplementalMeaningZh ?? "")")
        }
        pinyinKeysStorage = keys
        return keys
    }

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
        // Chinese course words go by pinyin, every other word by its English.
        let sortKey = records.map { record in
            ChineseCourse.isCourseWordId(record.word.id) ? ChineseDisplay.stripTones(record.word.pronunciation) : record.word.word
        }
        let alphabetical = records.sorted { left, right in
            let order = sortKey[left.index].compare(sortKey[right.index], options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en"))
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
        // Every term as pinyin, and the whole query as one word ("xue xi").
        let pinyinTerms = options.matchPinyin ? terms.compactMap(ChineseDisplay.pinyinSearchTerm) : []
        let usesPinyin = !terms.isEmpty && pinyinTerms.count == terms.count
        let pinyinKeys = usesPinyin ? self.pinyinKeys() : []
        let pinyinWhole = usesPinyin && terms.count > 1 ? pinyinTerms.joined() : nil
        // Parse each timestamp once here, not on every comparison while sorting.
        let usesRecency = options.sort != .alphabetical && (filter == .favorites || filter == .review || filter == .mastered)
        var matches: [(record: Record, recency: Double, score: Int)] = []
        for record in source {
            if let level, record.word.group != level { continue }
            if let initial, !record.normalizedWord.uppercased().hasPrefix(initial) { continue }
            var score = Self.searchScore(record, terms: terms)
            if usesPinyin, pinyinKeys.indices.contains(record.index) {
                let key = pinyinKeys[record.index]
                score = max(score, Self.pinyinScore(key, terms: pinyinTerms), pinyinWhole.map { Self.pinyinScore(key, terms: [$0]) } ?? 0)
            }
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

    /// Pinyin matches rank below the English word itself and above examples.
    static func pinyinScore(_ key: String, terms: [String]) -> Int {
        guard !key.isEmpty, !terms.isEmpty else { return 0 }
        let senses = key.split(separator: " ")
        var total = 0
        for term in terms {
            if senses.contains(where: { $0 == term }) { total += 700 }
            else if senses.contains(where: { $0.hasPrefix(term) }) { total += 640 }
            else if key.contains(term) { total += 500 }
            else { return 0 }
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
