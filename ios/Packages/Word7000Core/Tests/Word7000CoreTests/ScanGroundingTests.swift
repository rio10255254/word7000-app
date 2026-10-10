import XCTest
@testable import Word7000Core

final class ScanGroundingTests: XCTestCase {
    func testTableRowsPairWordsWithMeanings() {
        let rows = [["No.", "Word", "Meaning"], ["1", "abandon", "v.", "放棄"], ["2", "benefit (n.)", "好處；利益"], ["3", "look forward to", "期待"]]
        let found = ScanGrounding.candidates(fromTableRows: rows)
        XCTAssertEqual(found.map(\.word), ["abandon", "benefit", "look forward to"])
        XCTAssertEqual(found.map(\.meaningZh), ["放棄", "好處；利益", "期待"])
        XCTAssertEqual(found.first?.partOfSpeech, "v")
    }

    func testOnlyTextOnThePageIsAccepted() {
        let page = "abandon 放棄\nbenefit 好 處\nLook  Forward to: 期待"
        XCTAssertTrue(ScanGrounding.isGrounded(word: "abandon", meaning: "放棄", in: page))
        XCTAssertTrue(ScanGrounding.isGrounded(word: "benefit", meaning: "好處", in: page))
        XCTAssertTrue(ScanGrounding.isGrounded(word: "look forward to", meaning: "期待", in: page))
        // A meaning the model made up, or a word that is not there.
        XCTAssertFalse(ScanGrounding.isGrounded(word: "abandon", meaning: "拋棄", in: page))
        XCTAssertFalse(ScanGrounding.isGrounded(word: "capture", meaning: "放棄", in: page))
        XCTAssertFalse(ScanGrounding.isGrounded(word: "放棄", meaning: "放棄", in: page))
    }
}
