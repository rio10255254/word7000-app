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
        // The card's own identifier covers its children, so find the chip by its text.
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label IN %@", ["新字", "還不熟", "複習"])).firstMatch.exists)
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

    func testAutoRevealShowsAnswersWithoutATap() {
        let app = launch()
        app.buttons["today-start"].tap()
        waitForReadyCard(app)
        let toggle = app.descendants(matching: .any)["study-auto-reveal"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        XCTAssertTrue(app.buttons["study-grade-known"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["study-show-answer"].exists)
        app.buttons["study-grade-known"].tap()
        // The next card arrives already answered, and the choice outlives the card.
        let known = app.buttons["study-grade-known"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: known)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        XCTAssertTrue(app.staticTexts["study-position"].label.hasPrefix("2 /"))
        XCTAssertFalse(app.buttons["study-show-answer"].exists)
        toggle.tap()
        waitForReadyCard(app)
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

    func testSpellingChecksEachAnswerAndReachesResults() {
        let app = launch()
        let spelling = app.buttons["today-spelling"]
        for _ in 0..<4 where !spelling.isHittable { app.swipeUp() }
        spelling.tap()
        let input = app.textFields["spelling-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["spelling-hint"].isEnabled)
        let total = Int(app.staticTexts["spelling-position"].label.split(separator: "/").last?.trimmingCharacters(in: .whitespaces) ?? "") ?? 0
        XCTAssertGreaterThan(total, 0)
        for round in 0..<total {
            input.tap()
            input.typeText("qqqq\n")
            XCTAssertTrue(app.staticTexts["spelling-answer"].waitForExistence(timeout: 5), "round \(round)")
            if round == 0 { snapshot(app, "spelling-answer") }
            app.buttons["spelling-next"].tap()
        }
        XCTAssertTrue(app.buttons["spelling-again"].waitForExistence(timeout: 5), app.debugDescription)
        snapshot(app, "spelling-results")
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
        let autoSpeak = app.switches["speech-auto-speak"]
        for _ in 0..<3 where !autoSpeak.isHittable { app.swipeUp() }
        XCTAssertEqual(autoSpeak.value as? String, "0")
        autoSpeak.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertEqual(autoSpeak.value as? String, "1")
        XCUIDevice.shared.press(.home)
        sleep(1)
        app.terminate()
        app.launchArguments = ["-uiTestingLight", "-uiTestingFakePlans"]
        app.launch()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        openSpeechSettings(app)
        XCTAssertTrue(app.segmentedControls["speech-speed"].buttons.element(boundBy: 0).isSelected)
        XCTAssertEqual(app.buttons["speech-voice-en-US"].value as? String, selectedName)
        let savedAutoSpeak = app.switches["speech-auto-speak"]
        for _ in 0..<3 where !savedAutoSpeak.isHittable { app.swipeUp() }
        XCTAssertEqual(savedAutoSpeak.value as? String, "1")
    }

    func testSettingsAreGroupedAndReachable() {
        let app = launch()
        app.tabBars.buttons.element(boundBy: 2).tap()
        let settings = app.buttons["me-settings"]
        for _ in 0..<5 where !settings.isHittable { app.swipeUp() }
        settings.tap()
        XCTAssertTrue(app.switches["settings-auto-reveal"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["settings-reminder"].exists)
        XCTAssertTrue(app.buttons["settings-intelligence"].exists)
        snapshot(app, "settings-top")
        let speech = app.buttons["settings-speech"]
        for _ in 0..<3 where !speech.isHittable { app.swipeUp() }
        XCTAssertTrue(speech.isHittable)
        app.swipeUp()
        app.swipeUp()
        snapshot(app, "settings-bottom")
        app.swipeDown()
        app.swipeDown()
        let intelligence = app.buttons["settings-intelligence"]
        for _ in 0..<3 where !intelligence.isHittable { app.swipeDown() }
        intelligence.tap()
        XCTAssertTrue(app.switches["settings-ai-toggle"].waitForExistence(timeout: 5))
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
