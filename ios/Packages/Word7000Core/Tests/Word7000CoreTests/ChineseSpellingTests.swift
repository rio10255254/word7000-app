import XCTest
@testable import Word7000Core

final class ChineseSpellingTests: XCTestCase {
    func testCharactersAreAcceptedForAnySense() {
        XCTAssertEqual(ChineseSpelling.check("適應", meaning: "適應"), .correct)
        XCTAssertEqual(ChineseSpelling.check(" 改編 ", meaning: "適應；改編"), .correct)
        XCTAssertEqual(ChineseSpelling.check("適合", meaning: "適應"), .almost)
        XCTAssertEqual(ChineseSpelling.check("蘋果", meaning: "適應"), .wrong)
    }

    func testPinyinWithOrWithoutTones() {
        XCTAssertEqual(ChineseSpelling.check("shiying", meaning: "適應"), .correct)
        XCTAssertEqual(ChineseSpelling.check("shì yìng", meaning: "適應"), .correct)
        XCTAssertEqual(ChineseSpelling.check("shi4ying4", meaning: "適應"), .correct)
        XCTAssertEqual(ChineseSpelling.check("Shi4 Ying4", meaning: "適應"), .correct)
        XCTAssertEqual(ChineseSpelling.check("shi2ying1", meaning: "適應"), .almost)
        XCTAssertTrue(ChineseSpelling.tonesOnlyWrong("shi2ying1", meaning: "適應"))
        XCTAssertEqual(ChineseSpelling.check("shiyin", meaning: "適應"), .almost)
        XCTAssertEqual(ChineseSpelling.check("pingguo", meaning: "適應"), .wrong)
    }

    func testPolyphonesFollowTheReviewedReading() {
        XCTAssertEqual(ChineseSpelling.check("yinhang", meaning: "銀行"), .correct)
        XCTAssertEqual(ChineseSpelling.check("chongfu", meaning: "重複"), .correct)
    }

    func testUmlautSpellings() {
        XCTAssertEqual(ChineseSpelling.toneless("lǜ"), "lv")
        XCTAssertEqual(ChineseSpelling.toneless("lü"), "lv")
        XCTAssertEqual(ChineseSpelling.toneless("lu:4"), "lv")
    }

    func testHintsRevealSyllables() {
        let syllables = ["shì", "yìng"]
        XCTAssertEqual(ChineseSpelling.pattern(syllables, revealed: 0), "_ _")
        XCTAssertEqual(ChineseSpelling.pattern(syllables, revealed: 1), "shì _")
        XCTAssertEqual(ChineseSpelling.pattern(syllables, revealed: 2), "shì yìng")
        XCTAssertEqual(ChineseSpelling.maxHints(syllables), 2)
        XCTAssertEqual(ChineseSpelling.maxHints(["chī"]), 1)
    }
}

final class PinyinSearchTests: XCTestCase {
    func testLearnersOfChineseCanSearchBySound() {
        let words = [
            WordEntry(id: "w1", word: "adapt", partOfSpeech: "v", pronunciation: "", meaningZh: "適應", supplementalMeaningZh: "調整", example: "", exampleZh: "", group: "Core 1"),
            WordEntry(id: "w2", word: "bank", partOfSpeech: "n", pronunciation: "", meaningZh: "銀行", supplementalMeaningZh: nil, example: "", exampleZh: "", group: "Core 1"),
        ]
        let vocabulary = PreparedVocabulary(words)
        XCTAssertEqual(vocabulary.filter(state: .empty, query: "shiying", filter: .all, pinyinSearch: true).map(\.id), ["w1"])
        XCTAssertEqual(vocabulary.filter(state: .empty, query: "yin2hang2", filter: .all, pinyinSearch: true).map(\.id), ["w2"])
        XCTAssertEqual(vocabulary.filter(state: .empty, query: "tiaozheng", filter: .all, pinyinSearch: true).map(\.id), ["w1"])
        // Learners of English searching letters don't get pinyin matches.
        XCTAssertTrue(vocabulary.filter(state: .empty, query: "shiying", filter: .all).isEmpty)
    }
}

final class ChineseFirstScanTests: XCTestCase {
    func testChineseFirstListsPairWithTheEnglishAfter() {
        let parsed = ScanParser.parse(ScanParser.lines(fromPlainText: "學校 xuéxiào school\n銀行 bank\n蘋果 apple"))
        XCTAssertEqual(parsed.map(\.word), ["school", "bank", "apple"])
        XCTAssertEqual(parsed.map(\.meaningZh), ["學校", "銀行", "蘋果"])
    }

    func testEnglishFirstListsAreUnchanged() {
        let parsed = ScanParser.parse(ScanParser.lines(fromPlainText: "school n. 學校\nbank 銀行"))
        XCTAssertEqual(parsed.map(\.word), ["school", "bank"])
        XCTAssertEqual(parsed.map(\.meaningZh), ["學校", "銀行"])
    }

    func testPinyinIsLeftOutOfTheHeadword() {
        XCTAssertEqual(ScanParser.removingPinyin("xuéxiào school"), "school")
        XCTAssertEqual(ScanParser.removingPinyin("lǜsè green"), "green")
    }
}
