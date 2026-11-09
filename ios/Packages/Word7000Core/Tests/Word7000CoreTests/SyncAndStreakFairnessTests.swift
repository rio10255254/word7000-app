import XCTest
@testable import Word7000Core

/// Things a learner should never lose: the words they said they knew do not
/// pretend to be today's study, and the newest change to the daily goal wins
/// a sync.
final class SyncAndStreakFairnessTests: XCTestCase {
    func testPlacementWordsAreNotTodaysStudyAfterASync() {
        let today = "2026-11-07"
        var state = ProgressState(dailyProgressDate: today)
        state = Placement.apply(knownIds: ["a", "b", "c"], to: state, today: today)
        XCTAssertEqual(state.words["a"]?.status, .mastered)
        XCTAssertNil(state.words["a"]?.lastStudied, "known on sight is not studied today")
        XCTAssertNotNil(state.words["a"]?.dueDate)
        // A sign-in merges the local and cloud copies: the goal stays at zero.
        let merged = LearningEngine.merge([state, ProgressState(dailyProgressDate: today)])
        XCTAssertEqual(merged.studiedToday, 0)
    }

    func testTheNewestGoalChangeWinsASync() {
        let today = "2026-11-07"
        // This phone changed the goal to 30; the other studied more today but kept 20.
        let phone = ProgressState(dailyTarget: 30, studiedToday: 5, dailyProgressDate: today,
                                  dailyTargetUpdatedAt: "2026-11-07T08:00:00Z")
        let tablet = ProgressState(dailyTarget: 20, studiedToday: 15, dailyProgressDate: today)
        XCTAssertEqual(LearningEngine.merge([phone, tablet]).dailyTarget, 30)
        XCTAssertEqual(LearningEngine.merge([tablet, phone]).dailyTarget, 30)
        // Neither changed it since the stamp came in: the day's source, as before.
        XCTAssertEqual(LearningEngine.merge([ProgressState(dailyTarget: 30, studiedToday: 5, dailyProgressDate: today), tablet]).dailyTarget, 20)
        // A later change on the tablet wins in turn.
        var later = tablet
        later.dailyTarget = 10
        later.dailyTargetUpdatedAt = "2026-11-07T09:00:00Z"
        XCTAssertEqual(LearningEngine.merge([phone, later]).dailyTarget, 10)
    }
}
