import XCTest
@testable import Word7000Core

final class PlacementTestTests: XCTestCase {
    /// A learner who knows every word up to `level` and none above it.
    private func run(knowsUpTo level: Int) -> PlacementTest {
        var test = PlacementTest()
        var n = 0
        while !test.isFinished {
            let asked = test.level
            test.record(wordId: "w\(n)", level: asked, knew: asked <= level)
            n += 1
        }
        return test
    }

    func testItStartsEasyAndJumpsUpAfterARightAnswer() {
        var test = PlacementTest()
        XCTAssertEqual(test.level, 1, "the first word is from Core 1")
        test.record(wordId: "a", level: 1, knew: true)
        XCTAssertEqual(test.level, 5)
        test.record(wordId: "b", level: 5, knew: true)
        XCTAssertEqual(test.level, 9)
        test.record(wordId: "c", level: 9, knew: false)
        XCTAssertEqual(test.level, 7, "a miss turns it back with half the jump")
        XCTAssertEqual(test.turns, 1)
    }

    func testItNeverLeavesTheList() {
        var test = PlacementTest()
        test.record(wordId: "a", level: 1, knew: false)
        XCTAssertEqual(test.level, 1)
        var top = PlacementTest()
        for n in 0..<5 { top.record(wordId: "t\(n)", level: top.level, knew: true) }
        XCTAssertEqual(top.level, PlacementTest.topLevel)
    }

    func testItSettlesNearTheLearnersLevelWithinFifteen() {
        for level in [2, 5, 8, 11] {
            let test = run(knowsUpTo: level)
            XCTAssertLessThanOrEqual(test.asked, PlacementTest.maxQuestions)
            XCTAssertGreaterThanOrEqual(test.asked, PlacementTest.minQuestions)
            let chapter = test.startChapter
            // A chapter below the edge at most: a little review is better than a wall.
            XCTAssertTrue((level - 1...level + 1).contains(chapter), "knows up to Core \(level): starts at \(chapter)")
        }
    }

    func testTheEstimateGrowsWithTheLevel() {
        let low = run(knowsUpTo: 3).estimatedKnownWords
        let high = run(knowsUpTo: 9).estimatedKnownWords
        XCTAssertLessThan(low, high)
        XCTAssertEqual(high % 50, 0, "rounded to fifty")
        XCTAssertTrue((3500...5500).contains(high), "knows about nine chapters: \(high)")
    }

    func testOnlyRightAnswersCountAsKnown() {
        var test = PlacementTest()
        test.record(wordId: "a", level: 1, knew: true)
        test.record(wordId: "b", level: 5, knew: false)
        test.record(wordId: "c", level: 3, knew: true)
        XCTAssertEqual(test.knownIds, ["a", "c"])
    }

    func testWordsComeFromTheAskedLevelAndAreNotRepeated() {
        let words = (1...3).flatMap { level in
            (0..<4).map { WordEntry(id: "L\(level)-\($0)", word: "word\(String(repeating: "x", count: $0))", partOfSpeech: "n",
                                    pronunciation: "", meaningZh: "字", example: "", exampleZh: "", group: "Core \(level)") }
        } + [WordEntry(id: "phrase", word: "look after", partOfSpeech: "v", pronunciation: "", meaningZh: "照顧",
                       example: "", exampleZh: "", group: "Core 2")]
        let first = PlacementTest.word(at: 2, from: words, asked: [], seed: "s")
        XCTAssertEqual(first.map { LearningEngine.coreLevel($0.group) }, 2)
        XCTAssertNotEqual(first?.id, "phrase")
        let second = PlacementTest.word(at: 2, from: words, asked: [first!.id], seed: "s")
        XCTAssertNotEqual(second?.id, first?.id)
        XCTAssertNil(PlacementTest.word(at: 9, from: words, asked: [], seed: "s"))
    }

    func testChaptersReachedBeforeTheExam() {
        XCTAssertEqual(PlacementTest.chaptersReached(from: 5, wordsPerDay: 20, days: 75), 8)
        XCTAssertEqual(PlacementTest.chaptersReached(from: 12, wordsPerDay: 50, days: 300), 14)
    }
}
