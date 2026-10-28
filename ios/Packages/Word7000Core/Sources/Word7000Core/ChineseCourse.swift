import Foundation

/// One word of the Learn Chinese course: a Chinese word written for adult
/// learners of Mandarin as used in Taiwan, with its own level, example and
/// speaking question (see scripts/build-chinese-course.mjs).
public struct ChineseCourseEntry: Codable, Hashable, Sendable {
    public let id: String
    public let hanzi: String
    public let pinyin: String
    public let english: String
    public let partOfSpeech: String
    public let measureWord: String
    public let level: Int
    public let example: String
    public let examplePinyin: String
    public let exampleEnglish: String
    public let question: String
    public let questionPinyin: String
    public let questionEnglish: String
    public let answer: String
    public let answerPinyin: String
    public let answerEnglish: String
    /// The English words this Chinese word came from.
    public let sources: [String]

    /// The course word in the shape every drill uses: the English gloss as
    /// the word, the characters as the meaning, the pinyin as pronunciation.
    public var word: WordEntry {
        WordEntry(id: id, word: english, partOfSpeech: partOfSpeech, pronunciation: pinyin, meaningZh: hanzi,
                  example: exampleEnglish, exampleZh: example, group: ChineseCourse.levelName(level))
    }
}

public enum ChineseCourse {
    private struct Document: Decodable {
        let schemaVersion: Int
        let entries: [ChineseCourseEntry]
    }

    /// Easiest first. Empty until the course file is bundled.
    public static let entries: [ChineseCourseEntry] = {
        guard let url = Bundle.module.url(forResource: "chinese-course", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let document = try? JSONDecoder().decode(Document.self, from: data),
              document.schemaVersion == 1 else { return [] }
        return document.entries
    }()

    public static let words: [WordEntry] = entries.map(\.word)

    private static let byId = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

    public static var isAvailable: Bool { !entries.isEmpty }

    public static func entry(id: String) -> ChineseCourseEntry? { byId[id] }

    public static func isCourseWordId(_ id: String) -> Bool { id.hasPrefix("zh-") }

    /// Course levels, roughly the TOCFL vocabulary bands.
    public static let levelNames = ["Starter", "Beginner", "Elementary", "Intermediate", "Upper intermediate", "Advanced"]

    public static func levelName(_ level: Int) -> String {
        levelNames[min(max(level, 1), levelNames.count) - 1]
    }

    /// Readings the course itself carries, for ChineseDisplay.
    static var readings: [String: String] {
        var readings: [String: String] = [:]
        for entry in entries {
            readings[entry.hanzi] = entry.pinyin
            readings[entry.example] = entry.examplePinyin
            readings[entry.question] = entry.questionPinyin
            readings[entry.answer] = entry.answerPinyin
        }
        return readings
    }
}
