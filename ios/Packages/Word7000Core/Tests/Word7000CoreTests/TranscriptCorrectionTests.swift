import XCTest
@testable import Word7000Core

final class TranscriptCorrectionTests: XCTestCase {
    func testCharactersThatSoundLikeTheKeyPhraseBecomeIt() {
        // 外代 and 外帶 are both wài dài.
        let result = TranscriptCorrection.correct("我要外代，謝謝", keyPhrase: "外帶", chinese: true)
        XCTAssertEqual(result.text, "我要外帶，謝謝")
        XCTAssertEqual(result.fixes, [.init(heard: "外代", corrected: "外帶")])
        XCTAssertEqual(TranscriptCorrection.undo(result.fixes, in: result.text), "我要外代，謝謝")
    }

    func testOtherSoundsAndRightTextAreLeftAlone() {
        // 內用 (nèi yòng) is a different answer, not a misheard 外帶.
        XCTAssertEqual(TranscriptCorrection.correct("我要內用", keyPhrase: "外帶", chinese: true).fixes, [])
        XCTAssertEqual(TranscriptCorrection.correct("我要外帶", keyPhrase: "外帶", chinese: true).fixes, [])
        // Another tone is another word, and the learner's to fix.
        XCTAssertEqual(TranscriptCorrection.correct("我要歪帶", keyPhrase: "外帶", chinese: true).fixes, [])
        XCTAssertEqual(TranscriptCorrection.correct("Just two, thanks", keyPhrase: "two", chinese: false).fixes, [])
    }
}
