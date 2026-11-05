import XCTest

/// WordCat Next: the first launch. Learn English; who you are (high school
/// year 2); the exam (學測, already suggested); what to get better at
/// (spelling and speaking); the daily goal; the level test answered to the
/// end; three words to spell; the cat working it out; and the result with
/// the plan. Starting from it opens the first cards. Screenshots of each scene.
final class OnboardingLabTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testProfileLevelTestSpellingAndPlan() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingOnboarding", "-uiTestingLight", "-uiTestingFakePlans", "-uiTestingLabOnboarding"]
        app.launch()

        let english = app.buttons["welcome-learn-english"]
        XCTAssertTrue(english.waitForExistence(timeout: 10), app.debugDescription)
        snap(app, "welcome-01-language")
        english.tap()

        let stage = app.buttons["welcome-stage-senior2"]
        XCTAssertTrue(stage.waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "welcome-02-stage")
        stage.tap()

        // The exam most in year 2 prepare for is already picked.
        let gsat = app.buttons["welcome-exam-gsat"]
        XCTAssertTrue(gsat.waitForExistence(timeout: 5))
        XCTAssertTrue(gsat.isSelected, "high school suggests the 學測")
        sleep(1)
        snap(app, "welcome-03-exam")
        gsat.tap()

        let spelling = app.buttons["welcome-focus-spelling"]
        XCTAssertTrue(spelling.waitForExistence(timeout: 5))
        spelling.tap()
        app.buttons["welcome-focus-speaking"].tap()
        sleep(1)
        snap(app, "welcome-04-focus")
        app.buttons["welcome-focus-next"].tap()

        let next = app.buttons["welcome-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        snap(app, "welcome-05-goal")
        next.tap()

        let begin = app.buttons["welcome-test-start"]
        XCTAssertTrue(begin.waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "welcome-06-test-intro")
        begin.tap()

        // The level test: the first option, or "don't know", in turn.
        let unknown = app.buttons["welcome-test-unknown"]
        XCTAssertTrue(unknown.waitForExistence(timeout: 10), app.debugDescription)
        sleep(1)
        snap(app, "welcome-07-test")
        let spellPosition = app.descendants(matching: .any)["welcome-spell-position"]
        let result = app.descendants(matching: .any)["welcome-result"]
        var asked = 0
        while !spellPosition.exists, !result.exists, asked < 16 {
            if asked % 3 == 2 {
                unknown.tap()
            } else {
                let option = app.buttons["welcome-test-option-0"]
                XCTAssertTrue(option.waitForExistence(timeout: 5))
                option.tap()
                if asked == 1 { snap(app, "welcome-08-test-answered") }
            }
            asked += 1
            _ = spellPosition.waitForExistence(timeout: 1.5)
        }
        XCTAssertLessThanOrEqual(asked, 15)

        // Three words to spell: a wrong try twice, then "don't know".
        XCTAssertTrue(spellPosition.waitForExistence(timeout: 5), app.debugDescription)
        let input = app.textFields["welcome-spell-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "welcome-09-spell")
        input.typeText("qqq")
        app.buttons["welcome-spell-check"].tap()
        sleep(1)
        snap(app, "welcome-10-spell-miss")
        input.typeText("qqq")
        app.buttons["welcome-spell-check"].tap()
        sleep(2)
        for _ in 0..<2 {
            let giveUp = app.buttons["welcome-spell-unknown"]
            XCTAssertTrue(giveUp.waitForExistence(timeout: 5))
            sleep(1)
            if !giveUp.isEnabled { sleep(1) }
            giveUp.tap()
            sleep(2)
        }

        // The cat works it out, then the result and the plan.
        XCTAssertTrue(result.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.descendants(matching: .any)["welcome-result-estimate"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["welcome-result-spelling"].exists, "the spelling was measured")
        XCTAssertTrue(app.descendants(matching: .any)["welcome-plan"].exists)
        sleep(2)
        snap(app, "welcome-11-result")
        app.swipeUp()
        sleep(1)
        snap(app, "welcome-12-plan")

        let start = app.buttons["welcome-start"]
        for _ in 0..<3 where !start.isHittable { app.swipeUp() }
        start.tap()
        XCTAssertTrue(app.buttons["study-show-answer"].waitForExistence(timeout: 10))
        snap(app, "welcome-13-first-cards")
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
