import XCTest
@testable import Word7000Core

final class HomeTests: XCTestCase {
    // MARK: Which card leads

    func testThePreferredPillarLeadsUntilItIsDone() {
        XCTAssertEqual(HomeLayout.lead(preferred: .words, wordsDone: false, speakingDone: false, speakingShown: true), .words)
        XCTAssertEqual(HomeLayout.lead(preferred: .words, wordsDone: true, speakingDone: false, speakingShown: true), .speaking)
        XCTAssertEqual(HomeLayout.lead(preferred: .speaking, wordsDone: false, speakingDone: false, speakingShown: true), .speaking)
        XCTAssertEqual(HomeLayout.lead(preferred: .speaking, wordsDone: false, speakingDone: true, speakingShown: true), .words)
    }

    func testWithBothDoneOrNoSpeakingCardWordsLead() {
        XCTAssertEqual(HomeLayout.lead(preferred: .speaking, wordsDone: true, speakingDone: true, speakingShown: true), .words)
        XCTAssertEqual(HomeLayout.lead(preferred: .words, wordsDone: true, speakingDone: true, speakingShown: true), .words)
        XCTAssertEqual(HomeLayout.lead(preferred: .speaking, wordsDone: false, speakingDone: false, speakingShown: false), .words)
    }

    // MARK: The week's stamps

    func testWeekdaysStartOnMonday() {
        XCTAssertEqual(WeekStamps.weekdayIndex("2026-11-02"), 0, "a Monday")
        XCTAssertEqual(WeekStamps.weekdayIndex("2026-11-05"), 3, "a Thursday")
        XCTAssertEqual(WeekStamps.weekdayIndex("2026-11-08"), 6, "a Sunday")
        XCTAssertEqual(WeekStamps.weekdayIndex("1969-12-29"), 0, "before day 0 too")
    }

    private func analytics(studied days: [String]) -> LearningAnalyticsState {
        var counters = DailyLearningCounters()
        counters.studyKnown = 3
        return LearningAnalyticsState(days: Dictionary(uniqueKeysWithValues: days.map { ($0, ["ios": counters]) }))
    }

    func testTheWeekMarksStudiedMissedCoveredTodayAndAhead() {
        let week = WeekStamps.week(today: "2026-11-05", analytics: analytics(studied: ["2026-11-02", "2026-11-04"]),
                                   coveredDay: "2026-11-03")
        XCTAssertEqual(week.map(\.date), ["2026-11-02", "2026-11-03", "2026-11-04", "2026-11-05", "2026-11-06", "2026-11-07", "2026-11-08"])
        XCTAssertEqual(week.map(\.mark), [.studied, .covered, .studied, .today, .ahead, .ahead, .ahead])
    }

    func testTodayIsStampedOnceStudiedAndSundayEndsTheWeek() {
        let week = WeekStamps.week(today: "2026-11-08", analytics: analytics(studied: ["2026-11-08"]), coveredDay: nil)
        XCTAssertEqual(week.first?.date, "2026-11-02")
        XCTAssertEqual(week.last?.mark, .studied)
        XCTAssertEqual(week.filter { $0.mark == .missed }.count, 6)
    }

    // MARK: The shelf

    private func word(_ id: String, group: String, example: String? = nil) -> WordEntry {
        WordEntry(id: id, word: id, partOfSpeech: "n", pronunciation: "", meaningZh: "意思",
                  example: example ?? "I like the \(id) a lot.", exampleZh: "", group: group)
    }

    func testChaptersCountMasteredWordsInListOrder() {
        let words = [word("a", group: "Core 1"), word("b", group: "Core 1"), word("c", group: "Core 2"),
                     word("d", group: "Core 1"), word("e", group: "Core 2")]
        let state = ProgressState(words: ["a": WordProgress(status: .mastered), "b": WordProgress(status: .review),
                                          "d": WordProgress(status: .mastered), "e": WordProgress(status: .mastered)])
        let chapters = MasteryShelf.chapters(words: words, state: state)
        XCTAssertEqual(chapters, [ShelfChapter(group: "Core 1", total: 3, mastered: 2), ShelfChapter(group: "Core 2", total: 2, mastered: 1)])
        XCTAssertEqual(MasteryShelf.current(chapters), 0, "two thirds is not read through yet")
    }

    func testTheCurrentChapterIsTheFirstNotReadThrough() {
        let chapters = [ShelfChapter(group: "Core 1", total: 10, mastered: 9), ShelfChapter(group: "Core 2", total: 10, mastered: 8),
                        ShelfChapter(group: "Core 3", total: 10, mastered: 1)]
        XCTAssertEqual(MasteryShelf.current(chapters), 2)
        XCTAssertNil(MasteryShelf.current([ShelfChapter(group: "Core 1", total: 5, mastered: 5)]))
    }

    // MARK: Quizzes outside the routine

    func testTheQuickQuizAsksLearnedWordsDueSoonestAndNeverNewOnes() {
        let words = (1...30).map { word("w\($0)", group: "Core 1") } + [word("fresh", group: "Core 1")]
        var saved: [String: WordProgress] = [:]
        for n in 1...30 {
            // w1 is due first, w30 last.
            saved["w\(n)"] = WordProgress(status: .mastered, dueDate: String(format: "2026-11-%02d", n), stage: 3)
        }
        let picked = ExamRound.pick(.quick, words: words, state: ProgressState(words: saved), today: "2026-11-05", seed: "s")
        XCTAssertEqual(picked.count, ExamRound.quickCount)
        XCTAssertFalse(picked.contains("fresh"))
        let soonest = Set((1...20).map { "w\($0)" })
        XCTAssertTrue(picked.allSatisfy(soonest.contains), "from the twenty due soonest: \(picked)")
        XCTAssertEqual(picked, ExamRound.pick(.quick, words: words, state: ProgressState(words: saved), today: "2026-11-05", seed: "s"))
        XCTAssertNotEqual(picked, ExamRound.pick(.quick, words: words, state: ProgressState(words: saved), today: "2026-11-05", seed: "other"))
    }

    func testOnlyWordsWithASentenceToBlankAreAsked() {
        let words = [word("kept", group: "Core 1"), word("nosentence", group: "Core 1", example: "Something else entirely.")]
        let state = ProgressState(words: ["kept": WordProgress(status: .mastered, stage: 3),
                                          "nosentence": WordProgress(status: .mastered, stage: 3)])
        XCTAssertEqual(ExamRound.pick(.quick, words: words, state: state, today: "2026-11-05", seed: "s"), ["kept"])
        XCTAssertEqual(ExamRound.available(.quick, words: words, state: state, today: "2026-11-05"), 1)
    }

    func testTheWeeklyQuizAsksThisWeeksWordsOnSundays() {
        let words = (1...6).map { word("w\($0)", group: "Core 1") }
        let state = ProgressState(words: [
            "w1": WordProgress(status: .mastered, lastStudied: "2026-11-02", stage: 3),
            "w2": WordProgress(status: .review, lastStudied: "2026-11-08", stage: 0),
            "w3": WordProgress(status: .mastered, lastStudied: "2026-11-05", stage: 1),
            "w4": WordProgress(status: .mastered, lastStudied: "2026-11-07", stage: 2),
            "w5": WordProgress(status: .mastered, lastStudied: "2026-11-01", stage: 3),
        ])
        let picked = ExamRound.pick(.weekly, words: words, state: state, today: "2026-11-08", seed: "s")
        XCTAssertEqual(Set(picked), ["w1", "w2", "w3", "w4"], "the last seven days only")
        XCTAssertTrue(ExamRound.weeklyDue(words: words, state: state, today: "2026-11-08"))
        XCTAssertFalse(ExamRound.weeklyDue(words: words, state: state, today: "2026-11-07"), "Sundays only")
        let quiet = ProgressState(words: ["w1": WordProgress(status: .mastered, lastStudied: "2026-11-08", stage: 3)])
        XCTAssertFalse(ExamRound.weeklyDue(words: words, state: quiet, today: "2026-11-08"), "too few words for a quiz")
    }

    // MARK: The calendar in Me

    func testTheCalendarEndsWithThisWeekAndLeavesTheRestOfItEmpty() {
        let weeks = ActivityCalendar.weeks(3, today: "2026-11-05", analytics: analytics(studied: ["2026-11-05", "2026-10-20"]))
        XCTAssertEqual(weeks.count, 3)
        XCTAssertTrue(weeks.allSatisfy { $0.count == 7 })
        XCTAssertEqual(weeks[2][3], 3, "Thursday is today, with three answers")
        XCTAssertNil(weeks[2][4], "Friday has not come yet")
        XCTAssertEqual(weeks[0][1], 3, "two weeks ago Tuesday")
        XCTAssertEqual(weeks[1].compactMap { $0 }.reduce(0, +), 0)
    }

    func testDaysThisYearAndShades() {
        XCTAssertEqual(ActivityCalendar.activeDays(inYearOf: "2026-11-05", analytics: analytics(studied: ["2026-01-01", "2026-11-05", "2025-12-31"])), 2)
        XCTAssertEqual(ActivityCalendar.activeDays(inYearOf: "2026-11-05", analytics: nil), 0)
        XCTAssertEqual([0, 1, 12, 30, 80].map(ActivityCalendar.shade), [0, 1, 2, 3, 4])
    }
}
