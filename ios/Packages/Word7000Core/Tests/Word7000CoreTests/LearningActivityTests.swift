import XCTest
@testable import Word7000Core

final class LearningActivityTests: XCTestCase {
    func testSpeakingCountsAsPracticeWithoutChangingTheWordGoal() {
        var counters = DailyLearningCounters()
        counters.speakingCompleted = 3
        counters.speakingSkipped = 5
        XCTAssertEqual(counters.practiceActions, 3)
        XCTAssertEqual(counters.goalActions, 0)
        counters.studyKnown = 2
        counters.quizWrong = 1
        XCTAssertEqual(counters.practiceActions, 6)
        XCTAssertEqual(counters.goalActions, 3)
    }
}
