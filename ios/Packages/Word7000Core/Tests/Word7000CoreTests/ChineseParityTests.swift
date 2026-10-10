import Foundation
import XCTest
@testable import Word7000Core

/// Replays golden results from src/nativeParityChinese.test.ts for the ports of
/// chineseDisplay.ts and conversationPrompts.ts. Pinyin comes from the system
/// transliterator instead of pinyin-pro, so it is checked by match rate.
final class ChineseParityTests: XCTestCase {
    struct Case: Decodable {
        let id: String
        let word: String
        let concise: String
        let supplemental: String
        let english: ConversationPromptCard
        let chinese: ConversationPromptCard
    }
    struct PinyinCase: Decodable { let text: String; let pinyin: String }
    struct Fixtures: Decodable { let cases: [Case]; let pinyin: [PinyinCase] }

    static let fixtures: Fixtures = {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("parity-chinese.json")
        return try! JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url))
    }()

    static let wordsById: [String: WordEntry] = {
        Dictionary(uniqueKeysWithValues: ParityTests.words.map { ($0.id, $0) })
    }()

    var f: Fixtures { Self.fixtures }

    func word(_ testCase: Case) -> WordEntry {
        let word = Self.wordsById[testCase.id]
        XCTAssertEqual(word?.word, testCase.word, testCase.id)
        return word!
    }

    func testFixturesCoverExactQuestionsAndBranches() {
        XCTAssertGreaterThanOrEqual(f.cases.count, 60)
        let covered = Set(f.cases.map { $0.word.lowercased() })
        XCTAssertTrue(Set(ConversationPrompts.exactQuestionWords).isSubset(of: covered))
    }

    func testConciseAndSupplementalMeaning() {
        for testCase in f.cases {
            let meaning = word(testCase).meaningZh
            XCTAssertEqual(conciseChineseMeaning(meaning), testCase.concise, testCase.word)
            XCTAssertEqual(supplementalChineseMeaning(meaning), testCase.supplemental, testCase.word)
            let display = chineseMeaningDisplay(meaning)
            XCTAssertEqual(display.primary, testCase.concise, testCase.word)
            XCTAssertEqual(display.supplemental, testCase.supplemental, testCase.word)
        }
    }

    func testMeaningPartsEdgeCases() {
        XCTAssertEqual(conciseChineseMeaning("  放棄；遺棄, 放棄、拋棄 ;  "), "放棄；遺棄")
        XCTAssertEqual(supplementalChineseMeaning("放棄；遺棄, 放棄、拋棄；中止"), "拋棄；中止")
        XCTAssertEqual(conciseChineseMeaning(" ；, "), "；,")
        XCTAssertEqual(conciseChineseMeaning(""), "")
    }

    func testEnglishPrompts() {
        for testCase in f.cases {
            XCTAssertEqual(buildConversationPrompt(word(testCase), .english), testCase.english, testCase.word)
        }
    }

    func testChinesePromptsExceptPinyin() {
        for testCase in f.cases {
            var card = buildConversationPrompt(word(testCase), .chinese)
            card.keywordPronunciation = testCase.chinese.keywordPronunciation
            XCTAssertEqual(card, testCase.chinese, testCase.word)
        }
    }

    func testPinyinOverridesAndFormat() {
        XCTAssertEqual(chineseMeaningPinyin("調整"), "tiao zheng")
        XCTAssertEqual(chineseMeaningPinyin("敢於"), "gan yu")
        XCTAssertEqual(chineseMeaningPinyin("調整好；敢於說"), "tiao zheng hao；gan yu shuo")
        XCTAssertEqual(chineseMeaningPinyin("綠色"), "lü se")
        XCTAssertEqual(chineseMeaningPinyin("A型（的）"), "xing de")
        XCTAssertEqual(chineseMeaningPinyin("abc；123"), "")
    }

    /// pinyin-pro and the system transliterator disagree on some heteronyms,
    /// so pinyin (including the Chinese-mode keyword pronunciation) must match
    /// for at least 90% of texts rather than all of them.
    func testPinyinMatchRate() {
        var texts = f.pinyin.map { ($0.text, $0.pinyin) }
        texts += f.cases.map { ($0.chinese.keyword, $0.chinese.keywordPronunciation) }
        var mismatches: [String] = []
        for (text, expected) in texts {
            let actual = chineseMeaningPinyin(text)
            if actual != expected { mismatches.append("\(text): \(actual) ≠ \(expected)") }
        }
        for testCase in f.cases {
            let card = buildConversationPrompt(word(testCase), .chinese)
            XCTAssertEqual(card.keywordPronunciation, chineseMeaningPinyin(card.keyword), testCase.word)
        }

        let rate = Double(texts.count - mismatches.count) / Double(texts.count)
        print("Pinyin match rate: \(texts.count - mismatches.count)/\(texts.count) (\(Int((rate * 100).rounded()))%)")
        mismatches.forEach { print("  pinyin mismatch \($0)") }
        XCTAssertGreaterThanOrEqual(rate, 0.9, mismatches.joined(separator: "\n"))
    }
}
