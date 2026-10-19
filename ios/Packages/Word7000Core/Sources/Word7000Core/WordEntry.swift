import Foundation

/// One vocabulary card. The JSON shape matches the React Native app's
/// `WordEntry`, so saved custom words and synced data decode unchanged.
public struct WordEntry: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var word: String
    public var partOfSpeech: String
    public var pronunciation: String
    public var meaningZh: String
    public var supplementalMeaningZh: String?
    public var example: String
    public var exampleZh: String
    public var group: String
    public var updatedAt: String?

    public init(
        id: String,
        word: String,
        partOfSpeech: String,
        pronunciation: String,
        meaningZh: String,
        supplementalMeaningZh: String? = nil,
        example: String,
        exampleZh: String,
        group: String,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.word = word
        self.partOfSpeech = partOfSpeech
        self.pronunciation = pronunciation
        self.meaningZh = meaningZh
        self.supplementalMeaningZh = supplementalMeaningZh
        self.example = example
        self.exampleZh = exampleZh
        self.group = group
        self.updatedAt = updatedAt
    }
}

public enum WordData {
    /// Decodes the bundled word list (`words.json`, generated from the web
    /// app's data by `scripts/export-native-words.mjs`).
    public static func decode(_ data: Data) throws -> [WordEntry] {
        try JSONDecoder().decode([WordEntry].self, from: data)
    }

    /// Levels in the order they first appear ("Core 1" … "Core 14").
    public static func levels(in words: [WordEntry]) -> [String] {
        var seen = Set<String>()
        return words.compactMap { seen.insert($0.group).inserted ? $0.group : nil }
    }
}
