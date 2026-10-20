import XCTest
@testable import Word7000Core

final class SpellingTests: XCTestCase {
    func testAnswersIgnoreCaseAndSpacing() {
        XCTAssertEqual(Spelling.check("  Abandon ", word: "abandon"), .correct)
        XCTAssertEqual(Spelling.check("TV", word: "TV"), .correct)
        XCTAssertEqual(Spelling.check("", word: "abandon"), .wrong)
    }

    func testOneLetterOffIsAlmost() {
        XCTAssertEqual(Spelling.check("abandn", word: "abandon"), .almost)      // missing
        XCTAssertEqual(Spelling.check("abandoon", word: "abandon"), .almost)    // extra
        XCTAssertEqual(Spelling.check("abendon", word: "abandon"), .almost)     // wrong letter
        XCTAssertEqual(Spelling.check("recieve", word: "receive"), .almost)     // swapped
        XCTAssertEqual(Spelling.check("abnadon", word: "abandon"), .almost)
        XCTAssertEqual(Spelling.check("abendan", word: "abandon"), .wrong)
        XCTAssertEqual(Spelling.check("abandonment", word: "abandon"), .wrong)
        // Short words leave no room for a near miss.
        XCTAssertEqual(Spelling.check("cat", word: "car"), .wrong)
    }

    func testPatternRevealsLettersFromTheStart() {
        XCTAssertEqual(Spelling.pattern("abandon", revealed: 0), "_ _ _ _ _ _ _")
        XCTAssertEqual(Spelling.pattern("abandon", revealed: 2), "a b _ _ _ _ _")
        XCTAssertEqual(Spelling.maxHints("abandon"), 6)
        XCTAssertEqual(Spelling.maxHints("a"), 0)
    }

    func testEveryWordCanBeTyped() {
        for word in ParityTests.words {
            XCTAssertEqual(Spelling.check(word.word.uppercased(), word: word.word), .correct, word.word)
            XCTAssertFalse(word.word.contains("/"), word.word)
        }
    }
}
