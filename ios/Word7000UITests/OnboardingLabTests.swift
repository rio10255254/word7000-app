import XCTest

/// WordCat Next: the first launch. Learn English, the exam (學測), the daily
/// goal, words first, then the level test answered to the end and the
/// result's shelf; starting from it opens the first cards. Screenshots of
/// each scene.
final class OnboardingLabTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testExamGoalLeadLevelTestAndResult() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingOnboarding", "-uiTestingLight", "-uiTestingFakePlans", "-uiTestingLabOnboarding"]
        app.launch()

        let english = app.buttons["welcome-learn-english"]
        XCTAssertTrue(english.waitForExistence(timeout: 10), app.debugDescription)
        snap(app, "welcome-1-language")
        english.tap()

        let gsat = app.buttons["welcome-exam-gsat"]
        XCTAssertTrue(gsat.waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "welcome-2-exam")
        gsat.tap()

        let next = app.buttons["welcome-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        snap(app, "welcome-3-goal")
        next.tap()

        let words = app.buttons["welcome-lead-words"]
        XCTAssertTrue(words.waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "welcome-4-lead")
        words.tap()

        // The level test: the first option, or "don't know", in turn.
        let unknown = app.buttons["welcome-test-unknown"]
        XCTAssertTrue(unknown.waitForExistence(timeout: 10), app.debugDescription)
        sleep(1)
        snap(app, "welcome-5-test")
        let result = app.descendants(matching: .any)["welcome-result"]
        var asked = 0
        while !result.exists, asked < 16 {
            if asked % 3 == 2 {
                unknown.tap()
            } else {
                let option = app.buttons["welcome-test-option-0"]
                XCTAssertTrue(option.waitForExistence(timeout: 5))
                option.tap()
                if asked == 0 { snap(app, "welcome-6-test-answered") }
            }
            asked += 1
            _ = result.waitForExistence(timeout: 1.5)
        }
        XCTAssertTrue(result.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertLessThanOrEqual(asked, 15)
        XCTAssertTrue(app.descendants(matching: .any)["welcome-result-estimate"].exists)
        sleep(2)
        snap(app, "welcome-7-result")

        app.buttons["welcome-start"].tap()
        XCTAssertTrue(app.buttons["study-show-answer"].waitForExistence(timeout: 10))
        snap(app, "welcome-8-first-cards")
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
