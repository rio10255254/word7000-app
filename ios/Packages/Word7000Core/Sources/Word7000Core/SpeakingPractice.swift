import Foundation

/// Reviewed questions have their own answers; ordinary word examples are a
/// separate practice activity and are never presented as answers to a question.
public enum SpeakingPractice {
    public enum Activity: String, Codable, CaseIterable, Identifiable, Sendable {
        case questions, examples
        public var id: String { rawValue }
    }

    public struct Entry: Decodable, Sendable {
        public let id: String
        public let word: String
        public let keywordZh: String
        public let question: String
        public let answerEn: String
        public let answerZh: String
    }

    private struct Document: Decodable {
        let schemaVersion: Int
        let records: [Entry]
    }

    public static let entries: [Entry] = {
        guard let url = Bundle.module.url(forResource: "speaking-prompts", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let document = try? JSONDecoder().decode(Document.self, from: data), document.schemaVersion == 1 else { return [] }
        return document.records
    }()

    private static let byWord = Dictionary(entries.map { ($0.word.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })

    /// How many recently practised words are remembered, so the next
    /// sessions ask about other words first.
    public static let recentLimit = 300

    /// Words for one session, preferring ones not practised recently. When
    /// too few are left, the words practised longest ago fill the session.
    /// `recent` runs from the oldest to the latest practised word id.
    public static func session(from candidates: [WordEntry], recent: [String], count: Int, seed: String = SeededRandom.runtimeSeed()) -> [WordEntry] {
        let order = Dictionary(recent.enumerated().map { ($1, $0) }, uniquingKeysWith: { _, latest in latest })
        let fresh = candidates.filter { order[$0.id] == nil }
        guard fresh.count < count else { return QuizBuilder.session(words: fresh, count: count, seed: seed) }
        let oldestFirst = candidates.compactMap { word in order[word.id].map { (word, $0) } }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
        return SeededRandom.shuffle(fresh + oldestFirst.prefix(max(0, count - fresh.count)), seed: seed)
    }

    /// `recent` with `wordId` moved to the end, keeping the latest `recentLimit`.
    public static func remembering(_ wordId: String, in recent: [String]) -> [String] {
        var next = recent.filter { $0 != wordId }
        next.append(wordId)
        return Array(next.suffix(recentLimit))
    }

    public static func candidates(from words: [WordEntry], activity: Activity) -> [WordEntry] {
        activity == .examples ? words : words.filter { entry(for: $0) != nil }
    }

    public static func entry(for word: WordEntry) -> Entry? {
        guard let entry = byWord[word.word.lowercased()] else { return nil }
        if entry.id.hasPrefix(word.id + "-") { return entry }
        let senses = ChineseDisplay.meaningParts(word.meaningZh)
        return senses.contains(entry.keywordZh) ? entry : nil
    }

    public static func card(for word: WordEntry, mode: ConversationPromptMode) -> ConversationPromptCard? {
        guard let entry = entry(for: word) else { return nil }
        let chinese = mode == .chinese
        return ConversationPromptCard(
            keyword: chinese ? entry.keywordZh : entry.word,
            keywordPronunciation: chinese ? ChineseDisplay.pronunciationWithTones(entry.keywordZh) : "",
            question: entry.question,
            questionSupport: chinese ? "Answer in Chinese and try to use \u{201C}\(entry.keywordZh)\u{201D}." : "試著用 \(entry.word) 回答兩到三句，說出自己的經驗或想法。",
            referenceAnswer: chinese ? entry.answerZh : entry.answerEn,
            referenceTranslation: chinese ? entry.answerEn : entry.answerZh
        )
    }

    public static func exampleExercise(for word: WordEntry, mode: ConversationPromptMode) -> ConversationPromptCard {
        let chinese = mode == .chinese
        let keyword = chinese ? ChineseDisplay.conciseMeaning(word.meaningZh) : word.word
        let example = chinese ? word.exampleZh : word.example
        return ConversationPromptCard(
            keyword: keyword,
            keywordPronunciation: chinese ? ChineseDisplay.pronunciationWithTones(keyword) : "",
            question: example.isEmpty
                ? "Describe a situation in which you could use \u{201C}\(keyword)\u{201D}."
                : "Add a detail to this example. What could happen next?",
            questionSupport: chinese ? "Try two sentences in Chinese, using the word above." : "以這個字或例句為起點，多說一個人物、地點或原因。",
            referenceAnswer: example,
            referenceTranslation: chinese ? word.example : word.exampleZh
        )
    }
}
