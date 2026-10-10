import XCTest
@testable import Word7000Core

final class WordSuggesterTests: XCTestCase {
    let suggester = WordSuggester(words: ["abandon", "ability", "benefit", "capture", "decline", "look", "forward", "to", "environment", "cat", "car"])

    func testSnapsSmallHandwritingSlipsToTheDictionary() {
        XCTAssertEqual(suggester.correction(for: "abandan"), "abandon")
        XCTAssertEqual(suggester.correction(for: "benfit"), "benefit")
        XCTAssertEqual(suggester.correction(for: "captrue"), "capture")
        XCTAssertEqual(suggester.correction(for: "enviromnent"), "environment")
    }

    func testLeavesKnownShortAndFarWordsAlone() {
        XCTAssertNil(suggester.correction(for: "abandon"))
        XCTAssertNil(suggester.correction(for: "cot"))
        XCTAssertNil(suggester.correction(for: "photosynthesis"))
    }

    func testCorrectsPhrasesWordByWord() {
        XCTAssertEqual(suggester.correction(for: "look forwrd to"), "look forward to")
    }

    func testPrefersTheCandidateThatIsAWord() {
        XCTAssertEqual(suggester.best(of: ["abandan v. 放棄", "abandon v. 放棄"]), "abandon v. 放棄")
        XCTAssertEqual(suggester.best(of: ["xyz", "qrs"]), "xyz")
    }

    func testDistance() {
        XCTAssertEqual(WordSuggester.distance("abc", "acb", limit: 2), 1)
        XCTAssertEqual(WordSuggester.distance("kitten", "sitting", limit: 3), 3)
        XCTAssertEqual(WordSuggester.distance("same", "same", limit: 1), 0)
    }
}
