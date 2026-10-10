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
    var exampleSecondary: String
    var speakText: String
    var speakLanguage: String

    init(_ word: WordEntry, mode: StudyMode) {
        switch mode {
        case .english:
            prompt = word.word
            promptDetail = word.pronunciation
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
            promptDetail = ChineseDisplay.meaningPinyin(concise)
            answer = word.word
            answerLabel = L.englishWord
            answerDetail = [word.partOfSpeech, word.pronunciation].filter { !$0.isEmpty }.joined(separator: "  ")
            supplemental = Self.supplementalParts(word)
                .map { part in
                    let pinyin = ChineseDisplay.meaningPinyin(part)
                    return pinyin.isEmpty ? part : "\(part) \(pinyin)"
                }
                .joined(separator: " · ")
            examplePrimary = word.exampleZh
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
