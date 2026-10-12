import XCTest
@testable import Word7000Core

final class ScanRecognitionTests: XCTestCase {
    func testPronunciationDoesNotBecomePartOfHeadword() {
        let found = ScanParser.parse(ScanParser.lines(fromPlainText: "abandon /əˈbændən/ v. 放棄\nbenefit [ˈbenɪfɪt] n. 好處\nbed /bed/ n. 床\ncolour/color n./v. 顏色\nability [n.] 能力"))
        XCTAssertEqual(found.map(\.word), ["abandon", "benefit", "bed", "colour", "ability"])
        XCTAssertEqual(found.map(\.partOfSpeech), ["v", "n", "n", "n / v", "n"])
    }

    func testSeparateWordAndPartOfSpeechBoxesStayInTheSameRow() {
        let lines = [
            ScannedLine(text: "1", x: 0.03, y: 0.10, width: 0.03, height: 0.02),
            ScannedLine(text: "abandon", x: 0.10, y: 0.101, width: 0.18, height: 0.02),
            ScannedLine(text: "v.", x: 0.33, y: 0.10, width: 0.04, height: 0.02),
            ScannedLine(text: "放棄", x: 0.45, y: 0.10, width: 0.13, height: 0.022),
            ScannedLine(text: "benefit", x: 0.10, y: 0.16, width: 0.18, height: 0.02),
            ScannedLine(text: "n.", x: 0.33, y: 0.16, width: 0.04, height: 0.02),
            ScannedLine(text: "好處", x: 0.45, y: 0.16, width: 0.13, height: 0.022),
        ]
        let found = ScanParser.parse(ScanParser.readingRows(lines))
        XCTAssertEqual(found.map(\.word), ["abandon", "benefit"])
        XCTAssertEqual(found.map(\.partOfSpeech), ["v", "n"])
        XCTAssertEqual(found.map(\.meaningZh), ["放棄", "好處"])
    }

    func testTwoVocabularyColumnsDoNotMixMeanings() {
        let lines = [
            ScannedLine(text: "abandon", x: 0.05, y: 0.1, width: 0.15, height: 0.02),
            ScannedLine(text: "放棄", x: 0.25, y: 0.102, width: 0.13, height: 0.02),
            ScannedLine(text: "benefit", x: 0.55, y: 0.101, width: 0.15, height: 0.02),
            ScannedLine(text: "好處", x: 0.75, y: 0.1, width: 0.13, height: 0.02),
        ]
        let found = ScanParser.parse(ScanParser.readingRows(lines))
        XCTAssertEqual(found.map(\.word), ["abandon", "benefit"])
        XCTAssertEqual(found.map(\.meaningZh), ["放棄", "好處"])
    }

    func testAIRejectsWordsAndMeaningsBorrowedFromOtherRows() {
        let page = "abandon 放棄\nbenefit 好處\neducation 教育\nlook forward to\n期待"
        XCTAssertFalse(ScanGrounding.isGrounded(word: "abandon", meaning: "好處", in: page))
        XCTAssertFalse(ScanGrounding.isGrounded(word: "cat", meaning: "教育", in: page))
        XCTAssertTrue(ScanGrounding.isGrounded(word: "look forward to", meaning: "期待", in: page))
    }

    func testEnglishAlternativeDoesNotChangeChineseMeaning() {
        let dictionary = WordSuggester(words: ["abandon", "benefit"])
        XCTAssertEqual(dictionary.best(of: ["abandan v. 放棄", "abandon v. 房棄"]), "abandon v. 放棄")
        XCTAssertEqual(dictionary.best(of: ["2. benfit n. 好處", "2. benefit n. 好虎"]), "2. benefit n. 好處")
    }
}
