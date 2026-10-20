import XCTest
@testable import Word7000Core

final class StreakProtectionTests: XCTestCase {
    func testOneMissedDayKeepsTheStreakOncePerWeek() {
        var state = ProgressState(streak: 5, lastStudyDate: "2026-10-01")
        // The 2nd is missed: protection covers it, and studying on the 3rd continues.
        state = LearningEngine.normalizeForDate(state, today: "2026-10-03")
        XCTAssertEqual(state.streak, 5)
        XCTAssertEqual(state.streakFreezeDate, "2026-10-02")
        XCTAssertTrue(StreakProtection.justUsed(in: state, today: "2026-10-03"))
        state = LearningEngine.markKnown(state, wordId: "a", today: "2026-10-03", changedAt: "2026-10-03T08:00:00.000Z")
        XCTAssertEqual(state.streak, 6)
        XCTAssertFalse(StreakProtection.justUsed(in: state, today: "2026-10-03"))
        // Normalising again the same day changes nothing.
        XCTAssertEqual(LearningEngine.normalizeForDate(state, today: "2026-10-03"), state)

        // Another missed day within the week breaks it.
        state = LearningEngine.markKnown(state, wordId: "a", today: "2026-10-04", changedAt: "2026-10-04T08:00:00.000Z")
        XCTAssertEqual(state.streak, 7)
        XCTAssertFalse(StreakProtection.isAvailable(on: "2026-10-05", in: state))
        state = LearningEngine.normalizeForDate(state, today: "2026-10-06")
        XCTAssertEqual(state.streak, 0)
        state = LearningEngine.markKnown(state, wordId: "a", today: "2026-10-06", changedAt: "2026-10-06T08:00:00.000Z")
        XCTAssertEqual(state.streak, 1)

        // A week after the last use it is ready again.
        XCTAssertTrue(StreakProtection.isAvailable(on: "2026-10-09", in: state))
    }

    func testTwoMissedDaysAreNeverCovered() {
        let state = LearningEngine.normalizeForDate(ProgressState(streak: 5, lastStudyDate: "2026-10-01"), today: "2026-10-04")
        XCTAssertEqual(state.streak, 0)
        XCTAssertNil(state.streakFreezeDate)
        let studied = LearningEngine.markKnown(ProgressState(streak: 5, lastStudyDate: "2026-10-01"), wordId: "a", today: "2026-10-04")
        XCTAssertEqual(studied.streak, 1)
    }

    func testMergeKeepsTheLatestUse() {
        let a = ProgressState(streak: 3, lastStudyDate: "2026-10-03", streakFreezeDate: "2026-10-02")
        let b = ProgressState(streak: 1, lastStudyDate: "2026-09-20", streakFreezeDate: "2026-09-10")
        XCTAssertEqual(LearningEngine.merge([b, a]).streakFreezeDate, "2026-10-02")
        XCTAssertNil(LearningEngine.merge([ProgressState(), ProgressState()]).streakFreezeDate)
    }

    func testProgressSavedBeforeProtectionStillDecodes() throws {
        let json = #"{"dailyTarget":20,"streak":2,"studiedToday":0,"words":{}}"#
        let state = try JSONDecoder().decode(ProgressState.self, from: Data(json.utf8))
        XCTAssertNil(state.streakFreezeDate)
        XCTAssertEqual(state.streak, 2)
    }
}
