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
        XCTAssertEqual(ChineseSpelling.maxHints(syllables), 1)
        XCTAssertEqual(ChineseSpelling.maxHints(["chī"]), 0)
    }
}
