import XCTest
@testable import Word7000Core

final class StreakReminderTests: XCTestCase {
    var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return calendar
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    func testCoversTheLastHourOfTheDayAfterStudying() {
        let progress = ProgressState(streak: 4, lastStudyDate: "2026-10-09")
        let early = StreakReminderPlan.make(progress: progress, now: date(10, 20), enabled: true, calendar: calendar)
        XCTAssertFalse(early.activeNow)
        XCTAssertEqual(early.expiresAt, date(11, 0))
        XCTAssertEqual(early.startsAt, date(10, 23))
        XCTAssertTrue(StreakReminderPlan.make(progress: progress, now: date(10, 23, 30), enabled: true, calendar: calendar).activeNow)
    }

    func testNothingWhenDisabledBrokenOrNoStreak() {
        XCTAssertNil(StreakReminderPlan.make(progress: ProgressState(streak: 4, lastStudyDate: "2026-10-09"), now: date(10, 23, 30), enabled: false, calendar: calendar).expiresAt)
        XCTAssertNil(StreakReminderPlan.make(progress: ProgressState(streak: 4, lastStudyDate: "2026-10-07"), now: date(10, 23, 30), enabled: true, calendar: calendar).expiresAt)
        XCTAssertNil(StreakReminderPlan.make(progress: ProgressState(streak: 0, lastStudyDate: "2026-10-09"), now: date(10, 23, 30), enabled: true, calendar: calendar).expiresAt)
    }

    func testPropsRoundTripTheServerShape() {
        let json = #"{"activityKind":"noon","countdownLabel":"今日進度","expiresAt":1760140800000,"keepStreakLabel":"再學 5 個單字，完成今天目標","progressCurrent":15,"progressTarget":20,"startedAt":1760083200000,"streak":3,"streakLabel":"連勝 3 天","title":"中午學習時間"}"#
        let props = StreakActivityProps.decode(json)
        XCTAssertEqual(props?.isNoon, true)
        XCTAssertEqual(props?.progressTarget, 20)
        XCTAssertEqual(StreakActivityProps.decode(props!.json), props)
    }
}
