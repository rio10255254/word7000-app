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
