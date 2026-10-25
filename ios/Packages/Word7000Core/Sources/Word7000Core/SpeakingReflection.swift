import Foundation

/// Observations about text, not grades or pronunciation judgments.
public struct SpeakingReflection: Equatable, Sendable {
    public let containsTarget: Bool
    public let sentenceCount: Int
    public let unitCount: Int

    public init(answer: String, target: String, chinese: Bool, matchedLemma: Bool = false) {
        let text = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTarget = target.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let words = Self.tokens(text)
        let targetWords = Self.tokens(normalizedTarget)
        if chinese {
            containsTarget = ChineseDisplay.meaningParts(normalizedTarget).contains { text.localizedCaseInsensitiveContains($0) }
            unitCount = text.count
        } else {
            containsTarget = matchedLemma || (!targetWords.isEmpty && words.count >= targetWords.count
                && (0...(words.count - targetWords.count)).contains { start in
                    Array(words[start..<(start + targetWords.count)]) == targetWords
                })
            unitCount = words.count
        }
        sentenceCount = text.split(whereSeparator: { ".!?。！？\n".contains($0) })
            .filter { $0.contains(where: { $0.isLetter || $0.isNumber }) }.count
    }

    public static func tokens(_ text: String) -> [String] {
        text.lowercased().replacingOccurrences(of: "’", with: "'")
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "'" }).map(String.init)
    }
}

public struct LearningWeekSummary: Equatable, Sendable {
    public let activeDays: Int
    public let words: Int
    public let speaking: Int
    public let quizCorrect: Int
    public let quizTotal: Int
    public var accuracy: Int? { quizTotal > 0 ? Int((100 * Double(quizCorrect) / Double(quizTotal)).rounded()) : nil }

    public init(days: [DailyLearningActivity]) {
        let recent = Array(days.suffix(7))
        activeDays = recent.filter { $0.total > 0 }.count
        words = recent.reduce(0) { $0 + $1.words }
        speaking = recent.reduce(0) { $0 + $1.speaking }
        quizCorrect = recent.reduce(0) { $0 + $1.counters.quizCorrect }
        quizTotal = recent.reduce(0) { $0 + $1.counters.quizCorrect + $1.counters.quizWrong }
    }
}

/// Remote controls can disable existing AI features, never add code or grant access.
public struct IntelligencePolicy: Codable, Equatable, Sendable {
    public let version: Int
    public let speakingCoachEnabled: Bool
    public let scanAssistantEnabled: Bool
    /// The online (Groq) AI; missing means on. Off sends every feature back to the on-device model.
    public let cloudEnabled: Bool?

    public static func decode(_ data: Data) -> IntelligencePolicy? {
        guard data.count <= 4096, let policy = try? JSONDecoder().decode(Self.self, from: data),
              policy.version == 1 else { return nil }
        return policy
    }
}
