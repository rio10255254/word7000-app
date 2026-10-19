import XCTest

final class ExperienceTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingLight", "-uiTestingSampleProgress", "-uiTestingFakePlans"]
        app.launch()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        return app
    }

    private func waitForReadyCard(_ app: XCUIApplication) {
        let button = app.buttons["study-show-answer"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
    }

    func testRapidGradeAndBothSwipeDirections() {
        let app = launch()
        app.buttons["today-start"].tap()
        waitForReadyCard(app)
        app.buttons["study-show-answer"].tap()
        app.buttons["study-grade-known"].doubleTap()
        waitForReadyCard(app)
        XCTAssertTrue(app.staticTexts["study-position"].label.hasPrefix("2 /"))
        app.otherElements["study-card"].swipeLeft()
        waitForReadyCard(app)
        XCTAssertTrue(app.staticTexts["study-position"].label.hasPrefix("3 /"))
        app.otherElements["study-card"].swipeRight()
        waitForReadyCard(app)
        XCTAssertTrue(app.staticTexts["study-position"].label.hasPrefix("4 /"))
    }

    func testStudyResumesAfterRelaunch() {
        let app = launch()
        app.buttons["today-start"].tap()
        waitForReadyCard(app)
        app.buttons["study-show-answer"].tap()
        app.buttons["study-grade-known"].tap()
        waitForReadyCard(app)
        let prompt = app.staticTexts["study-prompt"].label
        let position = app.staticTexts["study-position"].label
        XCUIDevice.shared.press(.home)
        sleep(1)
        app.terminate()
        app.launchArguments = ["-uiTestingLight", "-uiTestingFakePlans"]
        app.launch()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        app.buttons["today-start"].tap()
        waitForReadyCard(app)
        XCTAssertEqual(app.staticTexts["study-prompt"].label, prompt)
        XCTAssertEqual(app.staticTexts["study-position"].label, position)
    }

    func testQuizLengthAndPersistentTopNextAction() {
        let app = launch()
        app.buttons["today-quiz"].tap()
        XCTAssertTrue(app.buttons["quiz-start"].waitForExistence(timeout: 5))
        app.segmentedControls["quiz-question-count"].buttons["20"].tap()
        app.buttons["quiz-start"].tap()
        XCTAssertTrue(app.buttons["quiz-option-0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 / 20"].exists)
        app.buttons["quiz-option-0"].tap()
        XCTAssertTrue(app.buttons["quiz-next-toolbar"].waitForExistence(timeout: 5))
        app.buttons["quiz-next-toolbar"].tap()
        XCTAssertTrue(app.staticTexts["2 / 20"].waitForExistence(timeout: 5))
        app.buttons["quiz-close"].tap()
        app.buttons["today-quiz"].tap()
        XCTAssertTrue(app.segmentedControls["quiz-question-count"].buttons["20"].isSelected)
    }
}
