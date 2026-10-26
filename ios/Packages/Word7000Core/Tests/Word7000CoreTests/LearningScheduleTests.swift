import XCTest
@testable import Word7000Core

final class LearningScheduleTests: XCTestCase {
    // MARK: Last study day after today

    func testALastStudyDayAfterTodayIsNotAMissedDay() {
        // Synced from a device a time zone ahead, or after flying west.
        let synced = ProgressState(streak: 30, dailyProgressDate: "2026-10-27", lastStudyDate: "2026-10-27")
        let opened = LearningEngine.normalizeForDate(synced, today: "2026-10-26")
        XCTAssertEqual(opened.streak, 30)
        XCTAssertNil(opened.streakFreezeDate)

        let studied = LearningEngine.markKnown(opened, wordId: "a", today: "2026-10-26", changedAt: "2026-10-26T08:00:00.000Z")
        XCTAssertEqual(studied.streak, 30)
        XCTAssertEqual(studied.lastStudyDate, "2026-10-27", "the last study day never moves back")
        XCTAssertEqual(studied.studiedToday, 1)

        // The next day continues from the later date as usual.
        let nextDay = LearningEngine.markKnown(studied, wordId: "b", today: "2026-10-28", changedAt: "2026-10-28T08:00:00.000Z")
        XCTAssertEqual(nextDay.streak, 31)
        XCTAssertEqual(nextDay.lastStudyDate, "2026-10-28")
    }

    func testMergingWithADeviceAheadKeepsTheStreak() {
        let here = ProgressState(streak: 12, dailyProgressDate: "2026-10-26", lastStudyDate: "2026-10-26")
        let ahead = ProgressState(streak: 13, dailyProgressDate: "2026-10-27", lastStudyDate: "2026-10-27")
        let merged = LearningEngine.normalizeForDate(LearningEngine.merge([here, ahead]), today: "2026-10-26")
        XCTAssertEqual(merged.streak, 13)
        // The streak is safe until the end of the 28th, so tonight needs no reminder.
        let plan = StreakReminderPlan.make(progress: merged, now: date("2026-10-26T23:30:00Z"), enabled: true, calendar: utcCalendar)
        XCTAssertFalse(plan.activeNow)
    }

    func testWidgetCountsALaterStudyDayAsStudied() {
        let snapshot = HomeWidgetSnapshot(date: "2026-10-26", studiedToday: 3, dailyTarget: 20, streak: 9, lastStudyDate: "2026-10-27",
                                          streakFreezeDate: nil, chineseInterface: false, words: [:])
        let display = snapshot.display(on: "2026-10-26")
        XCTAssertEqual(display.streak, 9)
        XCTAssertTrue(display.studiedToday)
    }

    // MARK: Studying ahead of schedule

    func testAWordRecalledBeforeItIsDueKeepsItsBox() {
        var state = LearningEngine.markKnown(.empty, wordId: "a", today: "2026-10-01", changedAt: "2026-10-01T08:00:00.000Z")
        XCTAssertEqual(state.words["a"]?.stage, 3)
        XCTAssertEqual(state.words["a"]?.dueDate, "2026-10-08")

        // Seen again on each of the next days, long before it is due.
        for day in ["2026-10-02", "2026-10-03", "2026-10-04", "2026-10-05"] {
            state = LearningEngine.markKnown(state, wordId: "a", today: day, changedAt: "\(day)T08:00:00.000Z")
            XCTAssertEqual(state.words["a"]?.stage, 3, day)
        }
        XCTAssertEqual(state.words["a"]?.dueDate, "2026-10-12", "the wait restarts from the last recall")

        // Once due, a recall moves it on.
        state = LearningEngine.markKnown(state, wordId: "a", today: "2026-10-12", changedAt: "2026-10-12T08:00:00.000Z")
        XCTAssertEqual(state.words["a"]?.stage, 4)
        XCTAssertEqual(state.words["a"]?.dueDate, "2026-10-26")
    }

    func testAnOverdueWordStillMovesOnAndAQuizAnswerAheadDoesNot() {
        let base = ProgressState(words: ["a": WordProgress(status: .mastered, dueDate: "2026-10-05", lastStudied: "2026-09-28", stage: 3)])
        let late = LearningEngine.markQuizCorrect(base, wordId: "a", today: "2026-10-09", changedAt: "2026-10-09T08:00:00.000Z")
        XCTAssertEqual(late.words["a"]?.stage, 4)
        let early = LearningEngine.markQuizCorrect(base, wordId: "a", today: "2026-10-01", changedAt: "2026-10-01T08:00:00.000Z")
        XCTAssertEqual(early.words["a"]?.stage, 3)
        XCTAssertEqual(early.words["a"]?.dueDate, "2026-10-08")
    }

    func testASmallBankStudiedDailyDoesNotJumpToLongWaits() {
        let words = (0..<5).map { word("w\($0)") }
        var state = ProgressState.empty
        for offset in 0..<5 {
            let day = DayMath.addDays("2026-10-01", offset)!
            for entry in LearningEngine.buildStudyQueue(words: words, state: state, today: day, limit: 20, seed: "s\(offset)") {
                state = LearningEngine.markKnown(state, wordId: entry.id, today: day, changedAt: "\(day)T08:00:00.000Z")
            }
        }
        for entry in words {
            XCTAssertEqual(state.words[entry.id]?.stage, 3, entry.id)
            XCTAssertEqual(state.words[entry.id]?.dueDate, "2026-10-12", entry.id)
        }
    }

    // MARK: Merging the daily count

    func testMergingTheSameDayCountsEveryWordStudiedOnEitherDevice() {
        var phone = ProgressState.empty
        for index in 0..<10 {
            phone = LearningEngine.markKnown(phone, wordId: "p\(index)", today: "2026-10-26", changedAt: "2026-10-26T08:00:00.000Z")
        }
        var pad = ProgressState.empty
        for index in 0..<5 {
            pad = LearningEngine.markKnown(pad, wordId: "t\(index)", today: "2026-10-26", changedAt: "2026-10-26T09:00:00.000Z")
        }
        XCTAssertEqual(LearningEngine.merge([phone, pad]).studiedToday, 15)
        XCTAssertEqual(LearningEngine.merge([pad, phone]).studiedToday, 15)
        // The same words on both devices still count once.
        XCTAssertEqual(LearningEngine.merge([phone, phone]).studiedToday, 10)
        // Words studied on an earlier day do not count towards today.
        var older = ProgressState.empty
        older = LearningEngine.markKnown(older, wordId: "o", today: "2026-10-25", changedAt: "2026-10-25T08:00:00.000Z")
        XCTAssertEqual(LearningEngine.merge([phone, older]).studiedToday, 10)
    }

    // MARK: Quiz and spelling word choice

    func testQuizAsksSeenWordsAndTopsUpWithNewOnes() {
        let words = (0..<200).map { word("w\($0)") }
        var state = ProgressState.empty
        let seenIds = ["w3", "w50", "w77", "w101", "w120", "w150", "w160", "w170", "w199"]
        for id in seenIds {
            state = LearningEngine.markKnown(state, wordId: id, today: "2026-10-01", changedAt: "2026-10-01T08:00:00.000Z")
        }
        for run in 0..<20 {
            let session = QuizBuilder.seenFirstSession(words: words, state: state, count: 10, seed: "run-\(run)")
            XCTAssertEqual(session.count, 10)
            XCTAssertEqual(Set(session.map(\.id)).count, 10)
            XCTAssertTrue(Set(seenIds).isSubset(of: Set(session.map(\.id))), "every seen word is asked")
        }
        // Seen words shuffle in with the new ones rather than always leading.
        let firsts = Set((0..<20).map { QuizBuilder.seenFirstSession(words: words, state: state, count: 10, seed: "run-\($0)")[0].id })
        XCTAssertGreaterThan(firsts.count, 1)
    }

    func testQuizWithEnoughSeenWordsAsksOnlySeenWords() {
        let words = (0..<200).map { word("w\($0)") }
        var state = ProgressState.empty
        for index in stride(from: 0, to: 200, by: 10) {
            state = LearningEngine.markReview(state, wordId: "w\(index)", today: "2026-10-01", changedAt: "2026-10-01T08:00:00.000Z")
        }
        let session = QuizBuilder.seenFirstSession(words: words, state: state, count: 10, seed: "only-seen")
        XCTAssertEqual(session.count, 10)
        XCTAssertTrue(session.allSatisfy { state.words[$0.id] != nil })
        // Fewer words than asked: everything there is.
        XCTAssertEqual(QuizBuilder.seenFirstSession(words: Array(words.prefix(4)), state: state, count: 10, seed: "tiny").count, 4)
        XCTAssertEqual(QuizBuilder.seenFirstSession(words: [], state: state, count: 10, seed: "none").count, 0)
    }

    // MARK: Helpers

    private func word(_ id: String) -> WordEntry {
        WordEntry(id: id, word: id, partOfSpeech: "n", pronunciation: "", meaningZh: id, example: "", exampleZh: "", group: "Core 1")
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }
}
