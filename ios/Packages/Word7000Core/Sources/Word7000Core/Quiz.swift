import Foundation

public enum QuizAnswerMode: String, Sendable {
    /// Show the English word, pick its Chinese meaning.
    case meaning
    /// Show the Chinese meaning, pick the English word.
    case word
}

public struct QuizOption: Equatable, Hashable, Sendable {
    public var text: String
    public var correct: Bool
}

public enum QuizBuilder {
    public static let questionCounts = [10, 20, 50]
    static let optionCount = 4
    static let distractorSample = 48

    public static func session(words: [WordEntry], count requested: Int, seed: String = SeededRandom.runtimeSeed()) -> [WordEntry] {
        let count = max(0, min(requested, words.count))
        guard count > 0 else { return [] }
        if count == words.count || Double(count) > Double(words.count) / 3 {
            return Array(SeededRandom.shuffle(words, seed: seed).prefix(count))
        }
        return SeededRandom.sampleIndexes(length: words.count, count: count, seed: "\(seed):session").map { words[$0] }
    }

    /// Four options. Distractors are drawn from a random sample and ranked by
    /// how plausible they are next to the answer: same part of speech first,
    /// then the same level. Duplicate texts are dropped so two words that
    /// share a meaning can never both look correct.
    public static func options(vocabulary: PreparedVocabulary, wordId: String, seed: String = SeededRandom.runtimeSeed(), mode: QuizAnswerMode = .meaning) -> [QuizOption] {
        let words = vocabulary.words
        let correctIndex = vocabulary.index(of: wordId) ?? 0
        guard words.indices.contains(correctIndex) else { return [] }
        let correctWord = words[correctIndex]
        let correctText = answerText(correctWord, mode: mode)
        let correctPos = primaryPartOfSpeech(correctWord.partOfSpeech)

        let candidates = SeededRandom.sampleIndexes(
            length: words.count,
            count: min(distractorSample, max(0, words.count - 1)),
            seed: "\(seed):wrong:\(wordId)",
            excluding: correctIndex
        ).enumerated().map { order, index -> (order: Int, score: Int, word: WordEntry) in
            let word = words[index]
            let score = (primaryPartOfSpeech(word.partOfSpeech) == correctPos ? 2 : 0) + (word.group == correctWord.group ? 1 : 0)
            return (order, score, word)
        }.sorted { $0.score != $1.score ? $0.score > $1.score : $0.order < $1.order }

        var used: Set<String> = [correctText]
        var wrong: [QuizOption] = []
        for candidate in candidates where wrong.count < optionCount - 1 {
            let text = answerText(candidate.word, mode: mode)
            guard !text.isEmpty, used.insert(text).inserted else { continue }
            wrong.append(QuizOption(text: text, correct: false))
        }
        return SeededRandom.shuffle([QuizOption(text: correctText, correct: true)] + wrong, seed: "\(seed):options:\(wordId)")
    }

    public static func answerText(_ word: WordEntry, mode: QuizAnswerMode) -> String {
        mode == .word ? word.word : word.meaningZh
    }

    /// vt, vi and v are all verbs as far as a plausible wrong answer goes.
    static func primaryPartOfSpeech(_ value: String) -> String {
        let first = value.split(whereSeparator: { $0.isWhitespace || $0 == "/" || $0 == "," || $0 == "." })
            .first.map { $0.lowercased() } ?? ""
        return first.hasPrefix("v") ? "v" : first
    }
}
