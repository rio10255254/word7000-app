import Foundation
import Word7000Core

/// How a word is shown in the current study mode. Learning English: the
/// English word is the question and the Chinese meaning the answer. Learning
/// Chinese: the (concise) Chinese meaning with pinyin is the question and the
/// English word the answer.
struct WordFace {
    var prompt: String
    var promptDetail: String
    var answer: String
    var answerLabel: String
    /// Shown with the answer only (it would give the answer away up front).
    var answerDetail: String
    var supplemental: String
    var examplePrimary: String
    /// Pinyin for the example a learner of Chinese reads; empty otherwise.
    var examplePinyin = ""
    var exampleSecondary: String
    var speakText: String
    var speakLanguage: String

    /// The word's IPA, or nothing where the list only has a placeholder
    /// ("/-/" on 64 words such as "including"), which read as a glitch.
    static func pronunciation(_ word: WordEntry) -> String {
        let trimmed = word.pronunciation.trimmingCharacters(in: .whitespaces)
        let inner = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/-– "))
        return inner.isEmpty ? "" : trimmed
    }

    init(_ word: WordEntry, mode: StudyMode) {
        switch mode {
        case .english:
            prompt = word.word
            promptDetail = Self.pronunciation(word)
            answer = ChineseDisplay.conciseMeaning(word.meaningZh)
            answerLabel = word.partOfSpeech
            answerDetail = ""
            supplemental = Self.supplementalParts(word).joined(separator: " · ")
            examplePrimary = word.example
            exampleSecondary = word.exampleZh
            speakText = word.word
            speakLanguage = "en-US"
        case .chinese:
            let concise = ChineseDisplay.conciseMeaning(word.meaningZh)
            prompt = concise
            promptDetail = ChineseDisplay.pronunciationWithTones(concise)
            answer = word.word
            answerLabel = L.englishWord
            // The Taiwan Mandarin bank keeps the pinyin in `pronunciation`,
            // already shown with the prompt; the English bank keeps IPA there.
            answerDetail = [word.partOfSpeech, Self.pronunciation(word).hasPrefix("/") ? Self.pronunciation(word) : ""]
                .filter { !$0.isEmpty }.joined(separator: "  ")
            supplemental = Self.supplementalParts(word)
                .map { part in
                    let pinyin = ChineseDisplay.pronunciationWithTones(part)
                    return pinyin.isEmpty ? part : "\(part) \(pinyin)"
                }
                .joined(separator: " · ")
            examplePrimary = word.exampleZh
            examplePinyin = ChineseDisplay.sentencePinyin(word.exampleZh)
            exampleSecondary = word.example
            speakText = concise
            speakLanguage = "zh-TW"
        }
    }

    /// Meanings beyond the first: the rest of the main meaning plus the
    /// supplemental field, without repeats.
    static func supplementalParts(_ word: WordEntry) -> [String] {
        var parts: [String] = []
        let rest = ChineseDisplay.supplementalMeaning(word.meaningZh)
        for part in ChineseDisplay.meaningParts(rest) + ChineseDisplay.meaningParts(word.supplementalMeaningZh ?? "") where !parts.contains(part) {
            parts.append(part)
        }
        return parts
    }
}
