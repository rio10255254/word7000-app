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

    func testLegacyReconciliationInEitherOrderAndOnRepeatedSync() throws {
        struct Scenario {
            var name: String
            var old: ProgressState = ProgressState(streak: 5, dailyProgressDate: "2026-10-01", lastStudyDate: "2026-10-01")
            var incoming: ProgressState
            var streak: Int
            var freeze: String? = nil
            var last: String = "2026-10-01"
        }
        let protected = ProgressState(streak: 5, dailyProgressDate: "2026-10-03", lastStudyDate: "2026-10-01", streakFreezeDate: "2026-10-02")
        let scenarios = [
            Scenario(name: "continuous study does not spend protection",
                     incoming: ProgressState(streak: 7, dailyProgressDate: "2026-10-03", lastStudyDate: "2026-10-03"),
                     streak: 7, last: "2026-10-03"),
            Scenario(name: "equal candidate does not spend protection",
                     incoming: ProgressState(streak: 6, dailyProgressDate: "2026-10-03", lastStudyDate: "2026-10-03"),
                     streak: 6, last: "2026-10-03"),
            Scenario(name: "legacy open keeps protection", old: protected,
                     incoming: ProgressState(streak: 0, dailyProgressDate: "2026-10-03", lastStudyDate: "2026-10-01"),
                     streak: 5, freeze: "2026-10-02"),
            Scenario(name: "legacy open allocates protection",
                     incoming: ProgressState(streak: 0, dailyProgressDate: "2026-10-03", lastStudyDate: "2026-10-01"),
                     streak: 5, freeze: "2026-10-02"),
            Scenario(name: "legacy study extends protection", old: protected,
                     incoming: ProgressState(streak: 1, studiedToday: 3, dailyProgressDate: "2026-10-03", lastStudyDate: "2026-10-03"),
                     streak: 6, freeze: "2026-10-02", last: "2026-10-03"),
            Scenario(name: "legacy study allocates protection",
                     incoming: ProgressState(streak: 1, dailyProgressDate: "2026-10-03", lastStudyDate: "2026-10-03"),
                     streak: 6, freeze: "2026-10-02", last: "2026-10-03"),
            Scenario(name: "next-day study",
                     incoming: ProgressState(streak: 1, dailyProgressDate: "2026-10-02", lastStudyDate: "2026-10-02"),
                     streak: 6, last: "2026-10-02"),
            Scenario(name: "same-day reset",
                     incoming: ProgressState(streak: 0, studiedToday: 10, dailyProgressDate: "2026-10-01", lastStudyDate: "2026-10-01"),
                     streak: 5),
            Scenario(name: "cooldown blocks second gap",
                     old: ProgressState(streak: 5, lastStudyDate: "2026-10-01", streakFreezeDate: "2026-09-28"),
                     incoming: ProgressState(streak: 1, dailyProgressDate: "2026-10-03", lastStudyDate: "2026-10-03"),
                     streak: 1, freeze: "2026-09-28", last: "2026-10-03"),
            Scenario(name: "expired open stays expired", old: protected,
                     incoming: ProgressState(streak: 0, dailyProgressDate: "2026-10-04", lastStudyDate: "2026-10-01"),
                     streak: 0, freeze: "2026-10-02"),
            Scenario(name: "distant study starts over",
                     old: ProgressState(streak: 100, lastStudyDate: "2026-10-01", streakFreezeDate: "2026-10-02"),
                     incoming: ProgressState(streak: 1, dailyProgressDate: "2026-10-04", lastStudyDate: "2026-10-04"),
                     streak: 1, freeze: "2026-10-02", last: "2026-10-04"),
            Scenario(name: "older freeze cannot overwrite", old: protected,
                     incoming: ProgressState(streak: 0, dailyProgressDate: "2026-10-03", lastStudyDate: "2026-10-01", streakFreezeDate: "2026-09-20"),
                     streak: 5, freeze: "2026-10-02"),
            Scenario(name: "newer freeze blocks another use",
                     old: ProgressState(streak: 5, lastStudyDate: "2026-10-01", streakFreezeDate: "2026-09-20"),
                     incoming: ProgressState(streak: 0, dailyProgressDate: "2026-10-03", lastStudyDate: "2026-10-01", streakFreezeDate: "2026-09-28"),
                     streak: 0, freeze: "2026-09-28"),
            Scenario(name: "opening cannot roll study date backward",
                     old: ProgressState(streak: 6, dailyProgressDate: "2026-10-03", lastStudyDate: "2026-10-03", streakFreezeDate: "2026-10-02"),
                     incoming: ProgressState(streak: 0, dailyProgressDate: "2026-10-04", lastStudyDate: "2026-10-01"),
                     streak: 6, freeze: "2026-10-02", last: "2026-10-03"),
            Scenario(name: "invalid freeze ignored", old: protected,
                     incoming: ProgressState(streak: 0, dailyProgressDate: "2026-10-03", lastStudyDate: "2026-10-01", streakFreezeDate: "9999-99-99"),
                     streak: 5, freeze: "2026-10-02"),
        ]
        for scenario in scenarios {
            for inputs in [[scenario.old, scenario.incoming], [scenario.incoming, scenario.old],
                           [scenario.old, scenario.incoming, scenario.old, scenario.incoming]] {
                let merged = LearningEngine.merge(inputs)
                XCTAssertEqual(merged.streak, scenario.streak, scenario.name)
                XCTAssertEqual(merged.lastStudyDate, scenario.last, scenario.name)
                XCTAssertEqual(merged.streakFreezeDate, scenario.freeze, scenario.name)
                let repeated = LearningEngine.merge([merged, scenario.old, scenario.incoming])
                XCTAssertEqual(repeated.streak, scenario.streak, scenario.name)
                XCTAssertEqual(repeated.streakFreezeDate, scenario.freeze, scenario.name)
                let roundTrip = try JSONDecoder().decode(ProgressState.self, from: JSONEncoder().encode(merged))
                XCTAssertEqual(LearningEngine.merge([roundTrip]), merged, scenario.name)
            }
        }
    }

    func testCooldownBoundaryAndCalendarBoundaries() {
        let notReady = LearningEngine.normalizeForDate(
            ProgressState(streak: 5, lastStudyDate: "2026-10-07", streakFreezeDate: "2026-10-02"), today: "2026-10-09")
        XCTAssertEqual(notReady.streak, 0)
        XCTAssertEqual(notReady.streakFreezeDate, "2026-10-02")
        let ready = LearningEngine.normalizeForDate(
            ProgressState(streak: 5, lastStudyDate: "2026-10-08", streakFreezeDate: "2026-10-02"), today: "2026-10-10")
        XCTAssertEqual(ready.streak, 5)
        XCTAssertEqual(ready.streakFreezeDate, "2026-10-09")
        for (last, today, freeze) in [("2026-12-31", "2027-01-02", "2027-01-01"),
                                     ("2028-02-28", "2028-03-01", "2028-02-29"),
                                     ("2026-03-07", "2026-03-09", "2026-03-08")] {
            let studied = LearningEngine.recordPracticeDay(ProgressState(streak: 5, lastStudyDate: last), today: today)
            XCTAssertEqual(studied.streak, 6)
            XCTAssertEqual(studied.streakFreezeDate, freeze)
            XCTAssertEqual(studied.studiedToday, 0)
        }
    }

    func testReconciliationDoesNotReplaceDailySettingsOrWordChanges() {
        let local = LearningEngine.toggleFavorite(ProgressState(streak: 5, lastStudyDate: "2026-10-01"), wordId: "local")
        let incoming = LearningEngine.markKnown(ProgressState(dailyTarget: 40, lastStudyDate: "2026-10-01"), wordId: "remote", today: "2026-10-03")
        let merged = LearningEngine.merge([local, incoming])
        XCTAssertEqual(merged.streak, 6)
        XCTAssertEqual(merged.dailyTarget, 40)
        XCTAssertEqual(merged.studiedToday, 1)
        XCTAssertEqual(merged.dailyProgressDate, "2026-10-03")
        XCTAssertEqual(merged.words["remote"]?.status, .mastered)
        XCTAssertEqual(merged.words["local"]?.favorite, true)
    }
}
