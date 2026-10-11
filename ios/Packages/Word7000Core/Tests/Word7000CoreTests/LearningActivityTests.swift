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

    func testStackedCategoriesCountEachCompletedActionOnce() {
        var state = LearningAnalyticsState()
        state.record(date: "2026-10-11", source: "phone") { counters in
            counters.studyKnown = 8
            counters.studyReview = 2
            counters.speakingCompleted = 3
            counters.speakingSkipped = 9
            counters.quizCorrect = 4
            counters.quizWrong = 1
            counters.otherActions = 2
            counters.englishActions = 12
            counters.chineseActions = 8
            counters.activeSeconds = 300
            counters.sessions = 2
        }
        let day = state.activity(endingOn: "2026-10-11", dayCount: 1)[0]
        XCTAssertEqual(day.words, 10)
        XCTAssertEqual(day.speaking, 3)
        XCTAssertEqual(day.other, 7)
        XCTAssertEqual(day.total, 20)
        XCTAssertEqual(day.total, day.counters.practiceActions)
    }

    func testSevenThirtyAndNinetyDaysIncludeEmptyDaysAndEndToday() {
        var state = LearningAnalyticsState()
        state.record(date: "2026-03-01", source: "phone") { $0.speakingCompleted = 2 }
        state.record(date: "2026-03-07", source: "phone") { $0.studyKnown = 4 }
        for count in [7, 30, 90] {
            let days = state.activity(endingOn: "2026-03-07", dayCount: count)
            XCTAssertEqual(days.count, count)
            XCTAssertEqual(days.first?.date, DayMath.addDays("2026-03-07", 1 - count))
            XCTAssertEqual(days.last?.date, "2026-03-07")
            XCTAssertEqual(Set(days.map(\.id)).count, count)
            XCTAssertEqual(days.reduce(0) { $0 + $1.total }, 6)
            XCTAssertEqual(days.first(where: { $0.date == "2026-03-02" })?.total, 0)
        }
        XCTAssertTrue(state.activity(endingOn: "2026-03-07", dayCount: 0).isEmpty)
        XCTAssertTrue(state.activity(endingOn: "2026-03-07", dayCount: -1).isEmpty)
    }
}
