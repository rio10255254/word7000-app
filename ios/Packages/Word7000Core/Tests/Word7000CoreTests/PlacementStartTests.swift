import XCTest
@testable import Word7000Core

/// WordCat Next: the level test's start chapter is where new words come from.
final class PlacementStartTests: XCTestCase {
    private func words(levels: ClosedRange<Int>, each: Int = 20) -> [WordEntry] {
        levels.flatMap { level in
            (0..<each).map { index in
                WordEntry(id: "c\(level)-\(index)", word: "w\(level)x\(index)", partOfSpeech: "n", pronunciation: "",
                          meaningZh: "字", example: "", exampleZh: "", group: "Core \(level)")
            }
        }
    }

    func testNewWordsSkipTheChaptersBelowTheStart() {
        let all = words(levels: 1...14)
        let queue = LearningEngine.buildStudyQueue(words: all, state: ProgressState(), today: "2026-11-06", limit: 30,
                                                   seed: "s", startLevel: 13)
        XCTAssertEqual(queue.count, 30)
        XCTAssertTrue(queue.allSatisfy { (LearningEngine.coreLevel($0.group) ?? 0) >= 13 }, queue.map(\.group).description)
        // Counted the same way the home page shows them.
        let counts = LearningEngine.studyQueueCounts(words: all, state: ProgressState(), today: "2026-11-06", limit: 30, startLevel: 13)
        XCTAssertEqual(counts.fresh, 30)
    }

    func testOnceTheStartChaptersAreDoneTheEasierOnesComeBack() {
        let all = words(levels: 1...3, each: 5)
        let queue = LearningEngine.buildStudyQueue(words: all, state: ProgressState(), today: "2026-11-06", limit: 5,
                                                   seed: "s", startLevel: 9)
        XCTAssertEqual(queue.count, 5, "nothing from chapter 9 on: the easier words are still offered")
    }

    func testWithoutATestNothingIsSkipped() {
        let all = words(levels: 1...14)
        let queue = LearningEngine.buildStudyQueue(words: all, state: ProgressState(), today: "2026-11-06", limit: 60, seed: "s")
        XCTAssertTrue(queue.contains { (LearningEngine.coreLevel($0.group) ?? 0) < 5 })
    }

    func testTheLevelEstimateStartsFromTheTest() {
        let estimate = LearningEngine.abilityEstimate(words: words(levels: 1...14), state: ProgressState(), startLevel: 13)
        XCTAssertEqual(LearningEngine.favouredLevels(ability: estimate.ability).lowerBound, 13)
        XCTAssertEqual(LearningEngine.abilityEstimate(words: words(levels: 1...14), state: ProgressState()).ability,
                       LearningEngine.abilityPrior)
    }
}
