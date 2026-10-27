import XCTest
@testable import Word7000Core

final class PinyinReadingsTests: XCTestCase {
    func testBundledReadingsReadWholeWordsTheTaiwanWay() {
        XCTAssertFalse(ChineseDisplay.readings.isEmpty)
        XCTAssertEqual(ChineseDisplay.pronunciationWithTones("適應"), "shì yìng")
        XCTAssertEqual(ChineseDisplay.pronunciationWithTones("銀行"), "yín háng")
        XCTAssertEqual(ChineseDisplay.pronunciationWithTones("簡短的"), "jiǎn duǎn de")
        XCTAssertEqual(ChineseDisplay.pronunciationWithTones("適應；簡短的"), "shì yìng；jiǎn duǎn de")
    }

    func testSentencesReadWithLatinPunctuation() {
        XCTAssertEqual(ChineseDisplay.sentencePinyin("美娜上車前傳了一段簡短的語音訊息。"),
                       "měi nà shàng chē qián chuán le yí duàn jiǎn duǎn de yǔ yīn xùn xí.")
        XCTAssertEqual(ChineseDisplay.sentencePinyin("I like it."), "")
    }

    func testTypedPinyinIgnoresTonesSpacesAndCase() {
        XCTAssertEqual(ChineseDisplay.pinyinSearchTerm("Xué xí"), "xuexi")
        XCTAssertEqual(ChineseDisplay.pinyinSearchTerm("xue2 xi2"), "xuexi")
        XCTAssertEqual(ChineseDisplay.pinyinSearchTerm("lü"), "lv")
        XCTAssertEqual(ChineseDisplay.pinyinSearchTerm("lu:se"), "lvse")
        XCTAssertNil(ChineseDisplay.pinyinSearchTerm("學習"))
        XCTAssertNil(ChineseDisplay.pinyinSearchTerm("  "))
    }

    func testLearnersOfChineseFindWordsByPinyin() {
        let words = [
            WordEntry(id: "w1", word: "adapt", partOfSpeech: "v", pronunciation: "", meaningZh: "適應", supplementalMeaningZh: "調整；改編",
                      example: "", exampleZh: "", group: "Core 1"),
            WordEntry(id: "w2", word: "bank", partOfSpeech: "n", pronunciation: "", meaningZh: "銀行", example: "", exampleZh: "", group: "Core 1"),
        ]
        let vocabulary = PreparedVocabulary(words)
        let pinyin = LibraryFilterOptions(matchPinyin: true)
        for query in ["shiying", "shì yìng", "shi4ying4", "shi ying", "tiaozheng"] {
            XCTAssertEqual(vocabulary.filter(state: ProgressState(), query: query, filter: .all, options: pinyin).map(\.id), ["w1"], query)
        }
        XCTAssertEqual(vocabulary.filter(state: ProgressState(), query: "yinhang", filter: .all, options: pinyin).map(\.id), ["w2"])
        XCTAssertEqual(vocabulary.filter(state: ProgressState(), query: "bank", filter: .all, options: pinyin).map(\.id), ["w2"])
        XCTAssertTrue(vocabulary.filter(state: ProgressState(), query: "shiying", filter: .all, options: .init()).isEmpty)
    }

    func testPinyinPracticeAcceptsAnyToneStyleAndShowsTheReading() throws {
        let word = WordEntry(id: "w1", word: "adapt", partOfSpeech: "v", pronunciation: "", meaningZh: "適應",
                             example: "", exampleZh: "", group: "Core 1")
        let target = try XCTUnwrap(PinyinPractice.target(for: word))
        XCTAssertEqual(target.characters, "適應")
        XCTAssertEqual(target.reading, "shì yìng")
        XCTAssertEqual(target.syllables, ["shi", "ying"])
        for answer in ["shiying", "shì yìng", "Shi4 ying4", "shi ying"] {
            XCTAssertEqual(PinyinPractice.check(answer, target: target), .correct, answer)
        }
        XCTAssertEqual(PinyinPractice.check("shiyin", target: target), .almost)
        XCTAssertEqual(PinyinPractice.check("xuexi", target: target), .wrong)
        XCTAssertEqual(PinyinPractice.check("適應", target: target), .wrong)
        XCTAssertEqual(PinyinPractice.pattern(target, revealed: 2), "s h _   _ _ _ _")
        XCTAssertEqual(PinyinPractice.maxHints(target), 6)
        let long = WordEntry(id: "w2", word: "x", partOfSpeech: "n", pronunciation: "", meaningZh: "中華民國國旗",
                             example: "", exampleZh: "", group: "Core 1")
        XCTAssertNil(PinyinPractice.target(for: long))
        let mixed = WordEntry(id: "w3", word: "x", partOfSpeech: "n", pronunciation: "", meaningZh: "T恤",
                              example: "", exampleZh: "", group: "Core 1")
        XCTAssertNil(PinyinPractice.target(for: mixed))
    }
}
