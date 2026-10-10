import Foundation

/// The language being practised (see PARITY.md §0.2): `english` asks about the
/// English word, `chinese` asks about its Chinese keyword.
public enum ConversationPromptMode: String, Codable, Sendable, CaseIterable {
    case english
    case chinese
}

/// One speaking-practice card (PARITY.md §3.10). Port of `src/lib/conversationPrompts.ts`.
public struct ConversationPromptCard: Codable, Equatable, Hashable, Sendable {
    public var keyword: String
    public var keywordPronunciation: String
    public var question: String
    public var questionSupport: String
    public var referenceAnswer: String
    public var referenceTranslation: String

    public init(keyword: String, keywordPronunciation: String, question: String, questionSupport: String, referenceAnswer: String, referenceTranslation: String) {
        self.keyword = keyword
        self.keywordPronunciation = keywordPronunciation
        self.question = question
        self.questionSupport = questionSupport
        self.referenceAnswer = referenceAnswer
        self.referenceTranslation = referenceTranslation
    }
}

public enum ConversationPrompts {
    struct Context {
        let chineseKeyword: String
        let primaryChineseKeyword: String
        let word: WordEntry
        let wordLower: String
        let meaningLower: String
    }

    static let politicsTerms = ["politic", "government", "election", "democracy", "vote", "policy", "政治", "政府", "選舉", "民主", "政黨"]
    static let adaptTerms = ["adapt", "adjust", "accommodate", "適應", "調整"]
    static let problemTerms = ["problem", "risk", "danger", "challenge", "困難", "問題", "危險", "挑戰", "風險"]
    static let emotionTerms = ["emotion", "happy", "sad", "angry", "fear", "love", "hope", "情緒", "快樂", "悲傷", "生氣", "害怕", "希望"]
    static let relationshipTerms = ["friend", "family", "relationship", "team", "朋友", "家庭", "關係", "團隊"]
    static let workTerms = ["work", "job", "study", "school", "learn", "工作", "職業", "學習", "學校"]

    static func includesAny(_ source: String, _ terms: [String]) -> Bool {
        terms.contains { source.contains($0) }
    }

    /// `partOfSpeech.toLowerCase().split(/[\/,;]/)[0].trim()`.
    static func primaryPartOfSpeech(_ partOfSpeech: String) -> String {
        let first = partOfSpeech.lowercased().components(separatedBy: CharacterSet(charactersIn: "/,;")).first ?? ""
        return ChineseDisplay.jsTrim(first)
    }

    static let englishExactQuestions: [String: String] = [
        "be": "How would you describe the kind of person you want to be in the future?",
        "and": "What are two things you like to do, and why do they fit together?",
        "of": "What is one part of your daily life that feels important to you?",
        "to": "Where would you like to go to learn something new?",
        "have": "What is something useful you have learned recently?",
        "for": "What is one goal you are working for this year?",
        "that": "What is one decision that changed your day recently?",
        "he": "Who is a person you admire, and what does he do well?",
        "you": "What is something you want to improve this month?",
        "with": "Who do you like to spend time with, and what do you usually do together?",
        "on": "What is something on your desk or table right now, and why is it there?",
        "do": "What do you usually do when you need to focus?",
        "not": "What is one habit you try not to do too often?",
        "they": "Who are people you trust, and why do they matter to you?",
        "this": "What is one thing this week that made you feel proud?",
        "at": "Where do you usually feel most focused at school, work, or home?",
        "say": "What would you say to a friend who feels nervous?",
        "but": "What is something difficult but worth doing?",
        "by": "What is one skill you improved by practicing?",
        "we": "What is something we can do to make a team work better?",
    ]

    static func pickChineseKeyword(_ context: Context, _ preferred: [String]) -> String {
        preferred.first { context.chineseKeyword.contains($0) } ?? context.primaryChineseKeyword
    }

    static let chineseExactQuestionBuilders: [String: @Sendable (Context) -> String] = [
        "be": { "How would you use \(pickChineseKeyword($0, ["是"])) to describe who you are or what something is?" },
        "and": { "What two ideas could you connect with \(pickChineseKeyword($0, ["和", "與"]))?" },
        "of": { "How would you use \(pickChineseKeyword($0, ["的"])) to describe something that belongs to someone?" },
        "to": { "How would you use \(pickChineseKeyword($0, ["到"])) to say where you are going?" },
        "have": { "What is something you can say you \(pickChineseKeyword($0, ["有"])) in your life?" },
        "for": { "How would you use \(pickChineseKeyword($0, ["為"])) to explain who something is for?" },
        "that": { "How would you use \(pickChineseKeyword($0, ["那"])) to point to something far from you?" },
        "he": { "How would you introduce someone using \(pickChineseKeyword($0, ["他"]))?" },
        "you": { "What friendly question could you ask with \(pickChineseKeyword($0, ["你"]))?" },
        "with": { "How would you use \(pickChineseKeyword($0, ["和"])) to talk about someone you spend time with?" },
        "on": { "How would you use \(pickChineseKeyword($0, ["在"])) to say where something is?" },
        "do": { "What is something you often \(pickChineseKeyword($0, ["做"])) on a normal day?" },
        "not": { "What is one thing you would say you \(pickChineseKeyword($0, ["不"])) want to do?" },
        "they": { "How would you describe a group of people using \(pickChineseKeyword($0, ["他們"]))?" },
        "this": { "How would you use \(pickChineseKeyword($0, ["這"])) to talk about something near you?" },
        "at": { "How would you use \(pickChineseKeyword($0, ["在"])) to say where something happens?" },
        "say": { "What would you \(pickChineseKeyword($0, ["說"])) to encourage a friend?" },
        "but": { "How would you use \(pickChineseKeyword($0, ["但是"])) to show two different ideas?" },
        "by": { "How would you use \(pickChineseKeyword($0, ["由", "被"])) to explain who did something?" },
        "we": { "What is something \(pickChineseKeyword($0, ["我們"])) can do together?" },
    ]

    /// Words with a hand-written question (the same 20 in both modes).
    public static var exactQuestionWords: [String] { englishExactQuestions.keys.sorted() }

    static func englishQuestion(_ context: Context) -> String {
        let word = context.word.word
        let topicSource = "\(context.wordLower) \(context.meaningLower)"

        if let exact = englishExactQuestions[context.wordLower] {
            return exact
        }
        if includesAny(topicSource, politicsTerms) {
            return "What do you think is the most important political issue in your community or country right now?"
        }
        if includesAny(topicSource, adaptTerms) {
            return "When have you had to \(word) to a new rule, place, or routine?"
        }
        if includesAny(topicSource, problemTerms) {
            return "What is a real problem where \(word) would be an important idea to explain?"
        }
        if includesAny(topicSource, emotionTerms) {
            return "When might someone feel \(word), and what should they do next?"
        }
        if includesAny(topicSource, relationshipTerms) {
            return "How can \(word) affect a friendship, family, or team?"
        }
        if includesAny(topicSource, workTerms) {
            return "How could \(word) matter at work or in school?"
        }

        let part = primaryPartOfSpeech(context.word.partOfSpeech)
        if part.hasPrefix("v") {
            return "When would someone need to \(word) in real life?"
        }
        if part.hasPrefix("adv") {
            return "How could someone act \(word) in a real conversation or situation?"
        }
        if part.hasPrefix("a") {
            return "Can you describe a \(word) situation you have seen or heard about?"
        }
        return "Why might \(word) be important when people talk about \(context.primaryChineseKeyword)?"
    }

    static func chineseModeQuestion(_ context: Context) -> String {
        let keyword = context.primaryChineseKeyword
        let topicSource = "\(context.wordLower) \(context.meaningLower)"

        if let builder = chineseExactQuestionBuilders[context.wordLower] {
            return builder(context)
        }
        if includesAny(topicSource, politicsTerms) {
            return "What 政治 issue do people around you talk about most often?"
        }
        if includesAny(topicSource, adaptTerms) {
            return "When have you needed to \(keyword) a new place, rule, or routine?"
        }
        if includesAny(topicSource, problemTerms) {
            return "What real-life 問題 could you explain with \(keyword)?"
        }
        if includesAny(topicSource, emotionTerms) {
            return "When might someone feel \(keyword), and why?"
        }

        let part = primaryPartOfSpeech(context.word.partOfSpeech)
        if part.hasPrefix("v") {
            return "When would someone need to \(keyword) in everyday life?"
        }
        if part.hasPrefix("adv") {
            return "How could someone do something \(keyword) in real life?"
        }
        if part.hasPrefix("a") {
            return "Can you describe a \(keyword) situation?"
        }
        return "Why is \(keyword) useful in real conversation?"
    }

    public static func build(_ word: WordEntry, mode: ConversationPromptMode) -> ConversationPromptCard {
        let chineseKeyword = ChineseDisplay.conciseMeaning(word.meaningZh)
        let firstPart = chineseKeyword.components(separatedBy: ChineseDisplay.meaningSeparators).first.map(ChineseDisplay.jsTrim) ?? ""
        let primaryChineseKeyword = firstPart.isEmpty ? chineseKeyword : firstPart
        let context = Context(
            chineseKeyword: chineseKeyword,
            primaryChineseKeyword: primaryChineseKeyword,
            word: word,
            wordLower: word.word.lowercased(),
            meaningLower: word.meaningZh.lowercased()
        )

        switch mode {
        case .chinese:
            return ConversationPromptCard(
                keyword: primaryChineseKeyword,
                keywordPronunciation: ChineseDisplay.meaningPinyin(primaryChineseKeyword),
                question: chineseModeQuestion(context),
                questionSupport: "Try to answer in Chinese and include \"\(primaryChineseKeyword)\" once. English hint: \"\(word.word)\".",
                referenceAnswer: ChineseDisplay.jsTrim("\(word.exampleZh) 我會再補上一個自己的原因或例子，讓回答更像真實對話。"),
                referenceTranslation: ChineseDisplay.jsTrim("\(word.example) I would add one personal reason or example to make the answer sound natural.")
            )
        case .english:
            return ConversationPromptCard(
                keyword: word.word,
                keywordPronunciation: "",
                question: englishQuestion(context),
                questionSupport: "Try to answer in 2-3 sentences and include \"\(word.word)\" naturally.",
                referenceAnswer: ChineseDisplay.jsTrim("\(word.example) I would add one personal reason or example to make the answer sound natural."),
                referenceTranslation: ChineseDisplay.jsTrim("\(word.exampleZh) 我會再補上一個自己的原因或例子，讓回答聽起來更自然。")
            )
        }
    }
}

/// `buildConversationPrompt(word, mode)` from the TypeScript app.
public func buildConversationPrompt(_ word: WordEntry, _ mode: ConversationPromptMode) -> ConversationPromptCard {
    ConversationPrompts.build(word, mode: mode)
}
