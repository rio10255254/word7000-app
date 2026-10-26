import Foundation
import XCTest
@testable import Word7000Core

/// Replays golden results from src/nativeParityChinese.test.ts for the port of
/// chineseDisplay.ts. Pinyin comes from the system transliterator instead of
/// pinyin-pro, so it is checked by match rate.
final class ChineseParityTests: XCTestCase {
    struct Case: Decodable {
        let id: String
        let word: String
        let concise: String
        let supplemental: String
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

    func testFixturesCoverManyWords() {
        XCTAssertGreaterThanOrEqual(f.cases.count, 60)
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


    func testPinyinOverridesAndFormat() {
        XCTAssertEqual(chineseMeaningPinyin("調整"), "tiao zheng")
        XCTAssertEqual(chineseMeaningPinyin("敢於"), "gan yu")
        XCTAssertEqual(chineseMeaningPinyin("調整好；敢於說"), "tiao zheng hao；gan yu shuo")
        XCTAssertEqual(chineseMeaningPinyin("綠色"), "lü se")
        XCTAssertEqual(chineseMeaningPinyin("A型（的）"), "xing de")
        XCTAssertEqual(chineseMeaningPinyin("abc；123"), "")
    }

    /// pinyin-pro and the system transliterator disagree on some heteronyms,
    /// so pinyin must match for at least 90% of texts rather than all of them.
    func testPinyinMatchRate() {
        let texts = f.pinyin.map { ($0.text, $0.pinyin) }
        var mismatches: [String] = []
        for (text, expected) in texts {
            let actual = chineseMeaningPinyin(text)
            if actual != expected { mismatches.append("\(text): \(actual) ≠ \(expected)") }
        }

        let rate = Double(texts.count - mismatches.count) / Double(texts.count)
        print("Pinyin match rate: \(texts.count - mismatches.count)/\(texts.count) (\(Int((rate * 100).rounded()))%)")
        mismatches.forEach { print("  pinyin mismatch \($0)") }
        XCTAssertGreaterThanOrEqual(rate, 0.9, mismatches.joined(separator: "\n"))
    }
}
