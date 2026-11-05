import XCTest
@testable import Word7000Core

final class TodaysWordUseTests: XCTestCase {
    private func word(_ id: String, _ text: String? = nil) -> WordEntry {
        WordEntry(id: id, word: text ?? id, partOfSpeech: "v", pronunciation: "", meaningZh: "意思",
                  example: "", exampleZh: "", group: "Core 1")
    }

    // MARK: Hearing the word

    func testTheWordInASentenceCounts() {
        XCTAssertEqual(TodaysWordUse.check(heard: "I need to adapt to the new menu.", word: "adapt"), .used)
        XCTAssertEqual(TodaysWordUse.check(heard: "Can I ADAPT this recipe?", word: "adapt"), .used)
    }

    func testAnotherFormCountsToo() {
        XCTAssertEqual(TodaysWordUse.check(heard: "She adapted quickly to the job", word: "adapt"), .usedOtherForm)
        XCTAssertEqual(TodaysWordUse.check(heard: "He is studying at the cafe", word: "study"), .usedOtherForm)
        XCTAssertTrue(TodaysWordUse.Verdict.usedOtherForm.counts)
    }

    func testTheWordAloneIsNotASentence() {
        XCTAssertEqual(TodaysWordUse.check(heard: "adapt", word: "adapt"), .tooShort)
        XCTAssertEqual(TodaysWordUse.check(heard: "adapt it", word: "adapt"), .tooShort)
        XCTAssertFalse(TodaysWordUse.Verdict.tooShort.counts)
    }

    func testALookAlikeOrAPartIsNotTheWord() {
        XCTAssertEqual(TodaysWordUse.check(heard: "I want to adopt a cat today", word: "adapt"), .missing)
        XCTAssertEqual(TodaysWordUse.check(heard: "The adaptation was great fun", word: "adapt"), .missing)
        XCTAssertEqual(TodaysWordUse.check(heard: "", word: "adapt"), .missing)
    }

    func testPunctuationAndApostrophesDoNotGetInTheWay() {
        XCTAssertEqual(TodaysWordUse.check(heard: "Well, I can't, adapt! Not today.", word: "adapt"), .used)
        XCTAssertEqual(TodaysWordUse.check(heard: "It's a well-known fact, right", word: "well-known"), .used)
    }

    // MARK: Which words to offer

    func testTodaysKnownWordsComeFirstInTheRoutinesOrder() {
        let words = ["a", "b", "c", "d", "e"].map { word($0) }
        let state = ProgressState(words: [
            "a": WordProgress(status: .review, lastStudied: "2026-11-05", stage: 0),
            "b": WordProgress(status: .mastered, lastStudied: "2026-11-05", stage: 3),
            "c": WordProgress(status: .mastered, lastStudied: "2026-11-05", stage: 3),
            "d": WordProgress(status: .mastered, lastStudied: "2026-11-04", stage: 3),
        ])
        XCTAssertEqual(TodaysWordUse.pick(words: words, state: state, today: "2026-11-05", preferred: ["c", "a", "b"]), ["c", "b", "a"])
    }

    func testWithoutTodaysWordsTheMostRecentAreOffered() {
        let words = ["a", "b", "c", "d"].map { word($0) }
        let state = ProgressState(words: [
            "a": WordProgress(status: .mastered, lastStudied: "2026-10-01", stage: 3),
            "b": WordProgress(status: .mastered, lastStudied: "2026-11-03", stage: 3),
            "c": WordProgress(status: .review, lastStudied: "2026-11-04", stage: 0),
            "d": WordProgress(status: .mastered, lastStudied: "2026-11-02", stage: 3),
        ])
        XCTAssertEqual(TodaysWordUse.pick(words: words, state: state, today: "2026-11-05"), ["c", "b", "d"])
    }

    func testPhrasesAndNewWordsAreNotOffered() {
        let words = [word("p", "look after"), word("n", "novel"), word("k", "keep")]
        let state = ProgressState(words: [
            "p": WordProgress(status: .mastered, lastStudied: "2026-11-05", stage: 3),
            "k": WordProgress(status: .mastered, lastStudied: "2026-11-05", stage: 3),
        ])
        XCTAssertEqual(TodaysWordUse.pick(words: words, state: state, today: "2026-11-05"), ["k"])
        XCTAssertEqual(TodaysWordUse.pick(words: words, state: ProgressState(), today: "2026-11-05"), [])
    }
}
