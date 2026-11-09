import XCTest

/// WordCat Next: today's stamp once words and speaking are done (opened
/// straight away here), then Me with the last weeks as squares and the days
/// this year. Screenshots of both.
final class DayCompleteTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testTheStampThenMe() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingLight", "-uiTestingSampleProgress", "-uiTestingFakePlans",
                               "-uiTestingDayComplete", "-uiTestingDayCompleteNow"]
        app.launch()
        let keep = app.buttons["day-complete-keep"]
        XCTAssertTrue(keep.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.descendants(matching: .any)["day-complete-stamp"].exists)
        // The stamp, then its streak rolling on, then today's square.
        sleep(3)
        snap(app, "day-1-stamp")
        keep.tap()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))

        app.tabBars.buttons.matching(NSPredicate(format: "label IN %@", ["我", "Me"])).firstMatch.tap()
        let calendar = app.descendants(matching: .any)["me-calendar"].firstMatch
        for _ in 0..<3 where !calendar.exists { app.swipeUp() }
        XCTAssertTrue(calendar.waitForExistence(timeout: 5), app.debugDescription)
        // The days this year sit under the calendar; on a small phone the
        // list only builds them once they are nearly in view, so drag a little.
        let yearDays = app.staticTexts["me-year-days"]
        for _ in 0..<4 where !yearDays.exists {
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            from.press(forDuration: 0.05, thenDragTo: from.withOffset(CGVector(dx: 0, dy: -160)))
        }
        XCTAssertTrue(yearDays.waitForExistence(timeout: 3), app.debugDescription)
        sleep(1)
        snap(app, "day-2-me")
        // A tap on a square names its day above it, as GitHub's calendar does.
        calendar.tap()
        XCTAssertTrue(app.descendants(matching: .any)["me-calendar-detail"].firstMatch.waitForExistence(timeout: 3), app.debugDescription)
        snap(app, "day-3-me-calendar-detail")
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] {
            let directory = URL(fileURLWithPath: home).appendingPathComponent("word7000-screenshots")
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"))
        }
    }
}
