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
    /// Pinyin under the Chinese example when learning Chinese.
    var examplePinyin: String
    var exampleSecondary: String
    var speakText: String
    var speakLanguage: String

    /// `pinyin` off hides pinyin for learners of Chinese who read characters.
    init(_ word: WordEntry, mode: StudyMode, pinyin: Bool = true) {
        switch mode {
        case .english:
            prompt = word.word
            promptDetail = word.pronunciation
            answer = ChineseDisplay.conciseMeaning(word.meaningZh)
            answerLabel = word.partOfSpeech
            answerDetail = ""
            supplemental = Self.supplementalParts(word).joined(separator: " · ")
            examplePrimary = word.example
            examplePinyin = ""
            exampleSecondary = word.exampleZh
            speakText = word.word
            speakLanguage = "en-US"
        case .chinese:
            let concise = ChineseDisplay.conciseMeaning(word.meaningZh)
            prompt = concise
            promptDetail = pinyin ? ChineseDisplay.pronunciationWithTones(concise) : ""
            answer = word.word
            // The answer is plainly English; no label needed.
            answerLabel = ""
            // The English IPA means little to a learner of Chinese; the part
            // of speech tells which of two similar English words fits.
            answerDetail = ChineseCourse.entry(id: word.id).map { course in
                course.measureWord.isEmpty ? course.partOfSpeech
                    : "\(course.partOfSpeech) · measure word \(course.measureWord) \(ChineseDisplay.pronunciationWithTones(course.measureWord))"
            } ?? word.partOfSpeech
            supplemental = Self.supplementalParts(word)
                .map { part in
                    let reading = pinyin ? ChineseDisplay.pronunciationWithTones(part) : ""
                    return reading.isEmpty ? part : "\(part) \(reading)"
                }
                .joined(separator: " · ")
            examplePrimary = word.exampleZh
            examplePinyin = pinyin ? ChineseDisplay.sentencePinyin(word.exampleZh) : ""
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
