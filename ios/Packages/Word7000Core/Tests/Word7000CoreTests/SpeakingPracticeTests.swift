import XCTest
@testable import Word7000Core

final class SpeakingPracticeTests: XCTestCase {
    func testEveryReviewedQuestionHasARealPairedAnswer() {
        XCTAssertEqual(SpeakingPractice.entries.count, 120)
        XCTAssertEqual(Set(SpeakingPractice.entries.map(\.id)).count, 120)
        for entry in SpeakingPractice.entries {
            XCTAssertFalse(entry.question.isEmpty, entry.word)
            XCTAssertNil(entry.question.range(of: "\\p{Han}", options: .regularExpression), entry.word)
            XCTAssertTrue(entry.answerEn.lowercased().components(separatedBy: CharacterSet.letters.inverted).contains(entry.word.lowercased()), entry.word)
            for part in entry.keywordZh.components(separatedBy: "…") {
                XCTAssertTrue(entry.answerZh.contains(part), entry.word)
            }
            XCTAssertFalse(entry.answerEn.contains("I would add one personal reason"))
            XCTAssertFalse(entry.answerZh.contains("我會再補上一個"))
        }
    }

    func testAboutQuestionAndBothLanguagesUseReviewedAnswers() throws {
        let word = try XCTUnwrap(ParityTests.words.first { $0.word == "about" })
        let english = try XCTUnwrap(SpeakingPractice.card(for: word, mode: .english))
        let chinese = try XCTUnwrap(SpeakingPractice.card(for: word, mode: .chinese))
        XCTAssertEqual(english.question, "What is a topic you can talk about for a long time?")
        XCTAssertEqual(chinese.referenceAnswer, english.referenceTranslation)
        XCTAssertEqual(chinese.referenceTranslation, english.referenceAnswer)
        XCTAssertEqual(chinese.keyword, "關於")
        XCTAssertNotEqual(english.referenceAnswer, word.example)
    }

    func testCustomMeaningDoesNotBorrowAnUnrelatedQuestion() throws {
        var word = try XCTUnwrap(ParityTests.words.first { $0.word == "about" })
        word.id = "scan-about-local"
        word.meaningZh = "大約"
        XCTAssertNil(SpeakingPractice.card(for: word, mode: .chinese))
    }

    func testSpeakingProtectsStreakWithoutInflatingWordGoal() {
        let first = LearningEngine.recordPracticeDay(.empty, today: "2026-10-18")
        let next = LearningEngine.recordPracticeDay(first, today: "2026-10-19")
        XCTAssertEqual(next.streak, 2)
        XCTAssertEqual(next.studiedToday, 0)
        XCTAssertEqual(LearningEngine.recordPracticeDay(next, today: "2026-10-19").streak, 2)
    }

    func testChinesePronunciationKeepsTonesAndSeparators() {
        #if canImport(Darwin) || os(Linux)
        XCTAssertEqual(ChineseDisplay.pronunciationWithTones("我的；你好"), "wǒ de；nǐ hǎo")
        XCTAssertEqual(ChineseDisplay.pronunciationWithTones("調整"), "tiáo zhěng")
        XCTAssertEqual(ChineseDisplay.pronunciationWithTones("為了；因為；為什麼"), "wèi le；yīn wèi；wèi shén me")
        #endif
    }
}
