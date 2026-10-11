import XCTest

/// Walks through the main screens and saves a screenshot of each, in light
/// and dark mode. CI uploads them so every change can be checked by eye.
enum L10n {
    static let close = "關閉"
}

final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    func testLightScreens() { walkThrough(theme: "Light") }
    func testDarkScreens() { walkThrough(theme: "Dark") }

    /// The English interface for learning Chinese.
    func testChineseModeScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingSampleProgress", "-uiTestingLight", "-uiTestingChineseMode"]
        app.launch()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        snap(app, "zh-1-today")
        app.buttons["today-start"].tap()
        XCTAssertTrue(app.buttons["study-show-answer"].waitForExistence(timeout: 5))
        snap(app, "zh-2-study")
        app.buttons["study-show-answer"].tap()
        XCTAssertTrue(app.buttons["study-grade-known"].waitForExistence(timeout: 5))
        snap(app, "zh-3-study-answer")
        app.buttons["study-close"].tap()
        XCTAssertTrue(app.buttons["today-speaking"].waitForExistence(timeout: 5))
        app.buttons["today-speaking"].tap()
        sleep(1)
        snap(app, "zh-4-speaking")
    }

    func testTrialExpiresWhileAppRemainsOpen() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingLight", "-uiTestingTrialEndsSoon", "-uiTestingFakePlans"]
        app.launch()
        XCTAssertTrue(app.buttons["plus-recap-later"].waitForExistence(timeout: 20))
        snap(app, "plus-7-trial-expired-while-open")
        app.buttons["plus-recap-later"].tap()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 5))
    }

    func testHistoryChartSelectionAndRange() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingLight", "-uiTestingPlus", "-uiTestingHistoryData", "-uiTestingFakePlans"]
        app.launch()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        app.tabBars.buttons.element(boundBy: 2).tap()
        app.buttons["me-history"].tap()
        let chart = app.descendants(matching: .any)["history-chart"].firstMatch
        XCTAssertTrue(chart.waitForExistence(timeout: 5))
        let date = app.staticTexts["history-selected-date"]
        XCTAssertTrue(date.waitForExistence(timeout: 5))
        let initial = date.label
        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.4))
            .press(forDuration: 0.3, thenDragTo: chart.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.4)))
        XCTAssertNotEqual(date.label, initial)
        snap(app, "plus-8-history-selected-day")
        app.buttons["90 天"].tap()
        XCTAssertEqual(date.label, initial)
        snap(app, "plus-9-history-ninety-days")
    }

    func testHistoryEmptyState() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingLight", "-uiTestingPlus", "-uiTestingFakePlans"]
        app.launch()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        app.tabBars.buttons.element(boundBy: 2).tap()
        app.buttons["me-history"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["history-chart-empty"].firstMatch.waitForExistence(timeout: 5))
        snap(app, "plus-10-history-empty")
    }

    /// After the trial: the one-time recap, the reminder on Today, the
    /// paywall with plans, and a locked screen's preview.
    func testPlusScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingSampleProgress", "-uiTestingLight", "-uiTestingTrialExpired", "-uiTestingFakePlans"]
        app.launch()
        if app.buttons["plus-recap-later"].waitForExistence(timeout: 10) {
            sleep(1)
            snap(app, "plus-1-trial-recap")
            app.buttons["plus-recap-later"].tap()
        }
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        sleep(1)
        snap(app, "plus-2-today-nudge")
        if app.buttons["plus-nudge"].waitForExistence(timeout: 3) {
            app.buttons["plus-nudge"].tap()
            sleep(2)
            snap(app, "plus-3-paywall")
            XCTAssertTrue(app.buttons["paywall-close"].isHittable)
            if app.buttons["plan-monthly"].exists {
                app.buttons["plan-monthly"].tap()
                sleep(1)
                app.swipeUp()
                sleep(1)
                snap(app, "plus-4-paywall-monthly")
                XCTAssertTrue(app.buttons["paywall-close"].isHittable)
            }
            app.buttons[L10n.close].firstMatch.tap()
            sleep(1)
        }
        app.tabBars.buttons.element(boundBy: 2).tap()
        sleep(1)
        snap(app, "plus-5-me")
        if app.buttons["me-history"].waitForExistence(timeout: 3) {
            app.buttons["me-history"].tap()
            sleep(1)
            snap(app, "plus-6-history-locked")
        }
    }

    private func walkThrough(theme: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingSampleProgress", "-uiTesting\(theme)", "-uiTestingFakePlans"]
        app.launch()
        let prefix = theme.lowercased()

        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        snap(app, "\(prefix)-1-today")

        app.buttons["today-start"].tap()
        XCTAssertTrue(app.buttons["study-show-answer"].waitForExistence(timeout: 5))
        snap(app, "\(prefix)-2-study")
        app.buttons["study-show-answer"].tap()
        XCTAssertTrue(app.buttons["study-grade-known"].waitForExistence(timeout: 5))
        snap(app, "\(prefix)-3-study-answer")
        app.buttons["study-grade-known"].tap()
        XCTAssertTrue(app.buttons["study-show-answer"].waitForExistence(timeout: 5))
        app.buttons["study-close"].tap()

        XCTAssertTrue(app.buttons["today-quiz"].waitForExistence(timeout: 5))
        app.buttons["today-quiz"].tap()
        XCTAssertTrue(app.buttons["quiz-option-0"].waitForExistence(timeout: 5))
        snap(app, "\(prefix)-4-quiz")
        app.buttons["quiz-option-0"].tap()
        XCTAssertTrue(app.buttons["quiz-next"].waitForExistence(timeout: 5))
        snap(app, "\(prefix)-5-quiz-answered")
        app.buttons["quiz-close"].tap()

        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.buttons["words-scan"].waitForExistence(timeout: 5))
        snap(app, "\(prefix)-6-words")
        app.cells.element(boundBy: 2).tap()
        sleep(1)
        snap(app, "\(prefix)-7-word-detail")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["words-scan"].tap()
        sleep(1)
        snap(app, "\(prefix)-8-scan")
        app.buttons["關閉"].firstMatch.tap()

        app.tabBars.buttons.element(boundBy: 2).tap()
        sleep(1)
        snap(app, "\(prefix)-9-me")

        if prefix == "light", app.buttons["me-plus"].waitForExistence(timeout: 3) {
            app.buttons["me-plus"].tap()
            sleep(3)
            snap(app, "\(prefix)-11-paywall")
            app.buttons[L10n.close].firstMatch.tap()
        }

        app.tabBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["today-speaking"].waitForExistence(timeout: 5))
        app.buttons["today-speaking"].tap()
        sleep(1)
        snap(app, "\(prefix)-10-speaking")
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        // Also write straight to the Mac running the simulator, like fastlane
        // snapshot does, so CI can upload the PNGs as they are.
        if let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] {
            let directory = URL(fileURLWithPath: home).appendingPathComponent("word7000-screenshots")
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"))
        }
    }
}
