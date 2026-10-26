import Foundation

/// What the home and lock screen widgets show. The app writes it to the
/// shared App Group container whenever progress changes; the widget, which
/// has no word list of its own, only reads it.
public struct HomeWidgetSnapshot: Codable, Equatable, Sendable {
    public struct Word: Codable, Equatable, Sendable {
        public var word: String
        public var pronunciation: String
        public var meaning: String
        public var partOfSpeech: String

        public init(word: String, pronunciation: String, meaning: String, partOfSpeech: String) {
            self.word = word
            self.pronunciation = pronunciation
            self.meaning = meaning
            self.partOfSpeech = partOfSpeech
        }
    }

    /// The day the counts below belong to (YYYY-MM-DD).
    public var date: String
    public var studiedToday: Int
    public var dailyTarget: Int
    public var streak: Int
    public var lastStudyDate: String?
    /// The day streak protection last covered, if any.
    public var streakFreezeDate: String?
    public var chineseInterface: Bool
    /// A word for each of the next few days, so the widget can turn over at
    /// midnight without the app.
    public var words: [String: Word]
    /// A bounded offline pool for any day outside `words`. Optional so snapshots
    /// written before this field existed still decode with synthesized Codable.
    public var fallbackWords: [Word]?

    public init(date: String, studiedToday: Int, dailyTarget: Int, streak: Int, lastStudyDate: String?,
                streakFreezeDate: String?, chineseInterface: Bool, words: [String: Word], fallbackWords: [Word]? = nil) {
        self.date = date
        self.studiedToday = studiedToday
        self.dailyTarget = dailyTarget
        self.streak = streak
        self.lastStudyDate = lastStudyDate
        self.streakFreezeDate = streakFreezeDate
        self.chineseInterface = chineseInterface
        self.words = words
        self.fallbackWords = fallbackWords.map { Array($0.prefix(Self.fallbackWordLimit)) }
    }

    public static let daysAhead = 3
    public static let fallbackWordLimit = 128

    /// Days already given a word in `previous` keep it, so the word does not
    /// change during the day as the learner masters words.
    public static func make(progress: ProgressState, today: String, chineseInterface: Bool, words: [WordEntry],
                            previous: HomeWidgetSnapshot? = nil) -> HomeWidgetSnapshot {
        var daily: [String: Word] = [:]
        let days = (0..<daysAhead).compactMap { DayMath.addDays(today, $0) }
        // Progress changes on every card. Reuse today's pool without scanning
        // the library; mastery changes take effect at the next daily refresh.
        let keepFallback = previous?.date == today && previous?.fallbackWords?.isEmpty == false
        let needsPool = !keepFallback || days.contains { previous?.words[$0] == nil }
        let pool = needsPool ? wordPool(words, progress: progress) : []
        // The bundled library already has a stable order; no full-library sort.
        let fallback = keepFallback || pool.isEmpty ? (previous?.rotationPool ?? []) :
            pool.prefix(fallbackWordLimit).map(widgetWord)
        for day in days {
            // After a long absence, today's word may come from the old offline
            // pool. Pin it before refreshing that pool with current progress.
            if let kept = previous?.words[day] ?? (day == today ? previous?.word(on: day) : nil) {
                daily[day] = kept
                continue
            }
            guard let entry = wordOfTheDay(pool, date: day) else { continue }
            daily[day] = widgetWord(entry)
        }
        return HomeWidgetSnapshot(date: today, studiedToday: progress.studiedToday, dailyTarget: max(1, progress.dailyTarget),
                                  streak: progress.streak, lastStudyDate: progress.lastStudyDate,
                                  streakFreezeDate: progress.streakFreezeDate, chineseInterface: chineseInterface,
                                  words: daily, fallbackWords: fallback)
    }

    private static func widgetWord(_ entry: WordEntry) -> Word {
        Word(word: entry.word, pronunciation: entry.pronunciation,
             meaning: ChineseDisplay.conciseMeaning(entry.meaningZh), partOfSpeech: entry.partOfSpeech)
    }

    private var rotationPool: [Word] {
        if let fallbackWords, !fallbackWords.isEmpty {
            return Array(fallbackWords.prefix(Self.fallbackWordLimit))
        }
        // Dictionary iteration order is not stable across widget launches.
        return words.keys.sorted().prefix(Self.fallbackWordLimit).compactMap { words[$0] }
    }

    private func word(on day: String) -> Word? {
        if let scheduled = words[day] { return scheduled }
        let pool = rotationPool
        guard !pool.isEmpty else { return nil }
        let index = Int(SeededRandom.hash("word-of-the-day:\(day)") % UInt32(pool.count))
        return pool[index]
    }

    /// Words not yet mastered, or all of them once everything is.
    public static func wordPool(_ words: [WordEntry], progress: ProgressState) -> [WordEntry] {
        let open = words.filter { progress.words[$0.id]?.status != .mastered }
        return open.isEmpty ? words : open
    }

    /// The same word all day for the same pool.
    public static func wordOfTheDay(_ pool: [WordEntry], date: String) -> WordEntry? {
        guard !pool.isEmpty else { return nil }
        return pool[Int(SeededRandom.hash("word-of-the-day:\(date)") % UInt32(pool.count))]
    }

    /// What to show on `day`, which may be later than the day it was written.
    public struct Display: Equatable, Sendable {
        public var studied: Int
        public var target: Int
        public var streak: Int
        public var studiedToday: Bool
        public var word: Word?

        public var fraction: Double { min(1, Double(studied) / Double(max(1, target))) }
        public var goalDone: Bool { studied >= target }
    }

    public func display(on day: String) -> Display {
        let state = ProgressState(dailyTarget: dailyTarget, streak: streak, studiedToday: studiedToday,
                                  dailyProgressDate: date, lastStudyDate: lastStudyDate, streakFreezeDate: streakFreezeDate)
        let current = LearningEngine.normalizeForDate(state, today: day)
        return Display(studied: current.studiedToday, target: dailyTarget, streak: current.streak,
                       studiedToday: lastStudyDate.map { $0 >= day } ?? false, word: word(on: day))
    }
}

/// Reads and writes the snapshot as a small file in the App Group container.
public struct HomeWidgetStore: Sendable {
    public static let appGroup = "group.com.rio.word7000"
    public static let kind = "Word7000Today"
    static let fileName = "home-widget.json"

    public let directory: URL?

    public init(directory: URL? = HomeWidgetStore.sharedDirectory()) {
        self.directory = directory
    }

    public static func sharedDirectory() -> URL? {
        #if os(iOS) || os(macOS)
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        #else
        nil
        #endif
    }

    public func load() -> HomeWidgetSnapshot? {
        guard let url = directory?.appendingPathComponent(Self.fileName), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(HomeWidgetSnapshot.self, from: data)
    }

    /// Returns whether the file changed, so the caller only reloads widgets when needed.
    @discardableResult
    public func save(_ snapshot: HomeWidgetSnapshot) -> Bool {
        guard let directory, load() != snapshot, let data = try? JSONEncoder().encode(snapshot) else { return false }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try? data.write(to: directory.appendingPathComponent(Self.fileName), options: .atomic)) != nil
    }
}
