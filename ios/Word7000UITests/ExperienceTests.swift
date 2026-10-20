import XCTest

final class ExperienceTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    override func tearDown() {
        let app = XCUIApplication()
        if app.state == .runningForeground { snapshot(app, "experience-" + name.components(separatedBy: " ").last!.replacingOccurrences(of: "]", with: "")) }
        super.tearDown()
    }

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
        app.scrollViews["study-card"].swipeLeft()
        waitForReadyCard(app)
        XCTAssertTrue(app.staticTexts["study-position"].label.hasPrefix("3 /"))
        app.scrollViews["study-card"].swipeRight()
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

    func testExamUsesConciseOptionsAndCanBeSubmittedOnSmallScreens() {
        let app = launch()
        let exam = app.buttons["today-exam"]
        for _ in 0..<4 where !exam.isHittable { app.swipeUp() }
        exam.tap()
        let first = app.buttons["exam-option-0"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        for index in 0..<4 {
            XCTAssertFalse(app.buttons["exam-option-\(index)"].label.contains("；"))
        }
        first.tap()
        XCTAssertTrue(app.staticTexts["exam-position"].label.hasPrefix("2 /"))
        app.buttons["exam-submit"].tap()
        XCTAssertTrue(app.staticTexts["exam-summary"].waitForExistence(timeout: 5))
        snapshot(app, "exam-results-small-screen")
    }

    func testFirstPracticeHasFiveWordsAndWelcomeIsNotRepeated() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingOnboarding", "-uiTestingLight", "-uiTestingFakePlans"]
        app.launch()
        XCTAssertTrue(app.buttons["welcome-start"].waitForExistence(timeout: 10))
        snapshot(app, "welcome-first-practice")
        app.buttons["welcome-start"].tap()
        waitForReadyCard(app)
        XCTAssertEqual(app.staticTexts["study-position"].label, "1 / 5")
        XCUIDevice.shared.press(.home)
        sleep(1)
        app.terminate()
        app.launchArguments = ["-uiTestingLight", "-uiTestingFakePlans"]
        app.launch()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["welcome-start"].exists)
    }

    func testLibrarySearchKeepsKeyboardAndExactMatch() {
        let app = launch()
        app.tabBars.buttons.element(boundBy: 1).tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("c")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        search.typeText("apture")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        XCTAssertEqual(search.value as? String, "capture")
        XCTAssertTrue(app.staticTexts["capture"].firstMatch.waitForExistence(timeout: 5))
        snapshot(app, "library-exact-search-keyboard")
    }

    func testSpeechVoiceAndSpeedPersist() {
        let app = launch()
        openSpeechSettings(app)
        app.segmentedControls["speech-speed"].buttons.element(boundBy: 0).tap()
        app.buttons["speech-voice-en-US"].tap()
        let voice = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'speech-pick-' ")).firstMatch
        XCTAssertTrue(voice.waitForExistence(timeout: 10), app.debugDescription)
        voice.tap()
        let selectedName = app.buttons["speech-voice-en-US"].value as? String ?? ""
        XCTAssertFalse(selectedName.isEmpty)
        snapshot(app, "speech-preferences")
        app.buttons["speech-preview-en-US"].tap()
        app.buttons["speech-preview-zh-TW"].tap()
        XCUIDevice.shared.press(.home)
        sleep(1)
        app.terminate()
        app.launchArguments = ["-uiTestingLight", "-uiTestingFakePlans"]
        app.launch()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        openSpeechSettings(app)
        XCTAssertTrue(app.segmentedControls["speech-speed"].buttons.element(boundBy: 0).isSelected)
        XCTAssertEqual(app.buttons["speech-voice-en-US"].value as? String, selectedName)
    }

    private func openSpeechSettings(_ app: XCUIApplication) {
        app.tabBars.buttons.element(boundBy: 2).tap()
        let settings = app.buttons["me-settings"]
        for _ in 0..<5 where !settings.isHittable { app.swipeUp() }
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        let speech = app.buttons["settings-speech"]
        for _ in 0..<5 where !speech.isHittable { app.swipeUp() }
        XCTAssertTrue(speech.waitForExistence(timeout: 5))
        speech.tap()
        XCTAssertTrue(app.segmentedControls["speech-speed"].waitForExistence(timeout: 10))
        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != nil AND value != '' AND value != 'Loading' AND value != '載入中'"), object: app.buttons["speech-voice-en-US"])
        XCTAssertEqual(XCTWaiter.wait(for: [loaded], timeout: 10), .completed)
    }

    private func snapshot(_ app: XCUIApplication, _ name: String) {
        guard let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] else { return }
        let directory = URL(fileURLWithPath: home).appendingPathComponent("word7000-screenshots")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation.write(to: directory.appendingPathComponent(name + ".png"))
        try? app.debugDescription.write(to: directory.appendingPathComponent(name + "-hierarchy.txt"), atomically: true, encoding: .utf8)
    }
}
