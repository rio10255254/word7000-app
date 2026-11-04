import Foundation

/// The language being practised (see PARITY.md §0.2): `english` asks about the
/// English word, `chinese` asks about its Chinese keyword.
public enum ConversationPromptMode: String, Codable, Sendable, CaseIterable {
    case english
    case chinese
}

/// One speaking-practice card (PARITY.md §3.10), built by `SpeakingPractice`.
public struct ConversationPromptCard: Codable, Equatable, Hashable, Sendable {
    public var keyword: String
    public var keywordPronunciation: String
    public var question: String
    public var questionSupport: String
    public var referenceAnswer: String
    public var referenceTranslation: String
    /// The question in the learner's own language (Chinese for learners of
    /// English, English for learners of Chinese), revealed by tapping the
    /// question. It says nothing about which language the question is in.
    public var questionGloss: String?

    public init(keyword: String, keywordPronunciation: String, question: String, questionSupport: String, referenceAnswer: String, referenceTranslation: String,
                questionGloss: String? = nil) {
        self.questionGloss = questionGloss
        self.keyword = keyword
        self.keywordPronunciation = keywordPronunciation
        self.question = question
        self.questionSupport = questionSupport
        self.referenceAnswer = referenceAnswer
        self.referenceTranslation = referenceTranslation
    }
}
