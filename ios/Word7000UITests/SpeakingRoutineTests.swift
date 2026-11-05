import XCTest

/// WordCat Next: a speaking stage in four steps. Listen to the whole
/// conversation, say the first reply after hearing it and see the question,
/// skip the other turns, then say a sentence with one of today's words (the
/// simulated take says the word's example) and see the stage cleared.
/// Screenshots of each step.
final class SpeakingRoutineTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testListenRepeatAnswerThenTodaysWord() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingLight", "-uiTestingSampleProgress", "-uiTestingFakePlans",
                               "-uiTestingRecording", "-uiTestingSpeakingRoutine"]
        app.launch()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        let speaking = app.buttons["today-speaking"]
        XCTAssertTrue(speaking.waitForExistence(timeout: 5))
        speaking.tap()

        // Listen first.
        let done = app.buttons["speaking-listen-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.buttons["speaking-listen-play"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["speaking-steps"].exists)
        sleep(1)
        snap(app, "speak-1-listen")
        done.tap()

        // The first turn: say the reply after hearing it, then the question.
        let record = app.buttons["shadow-record"]
        XCTAssertTrue(record.waitForExistence(timeout: 10))
        sleep(1)
        snap(app, "speak-2-repeat")
        record.tap()
        XCTAssertTrue(app.descendants(matching: .any)["shadow-result"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["speaking-question"].waitForExistence(timeout: 10), "moves on by itself")
        sleep(1)
        snap(app, "speak-3-answer")
        for _ in 2...5 {
            tapReachable(app.buttons["speaking-next"], in: app)
            let skip = app.buttons["shadow-skip"]
            if skip.waitForExistence(timeout: 5) { tapReachable(skip, in: app) }
        }
        tapReachable(app.buttons["speaking-next"], in: app)

        // Last: one of today's words in a sentence.
        let wordRecord = app.buttons["speaking-word-record"]
        XCTAssertTrue(wordRecord.waitForExistence(timeout: 10), app.debugDescription)
        sleep(1)
        snap(app, "speak-4-todays-word")
        tapReachable(wordRecord, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["speaking-word-result"].firstMatch.waitForExistence(timeout: 15), app.debugDescription)
        let finish = app.buttons["speaking-word-done"]
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: finish)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 10), .completed, app.debugDescription)
        sleep(1)
        snap(app, "speak-5-word-used")
        finish.tap()
        XCTAssertTrue(app.staticTexts["speaking-stage-result"].waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "speak-6-cleared")
    }

    /// Scrolls until the control can be tapped (small phones), then taps it.
    private func tapReachable(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), app.debugDescription)
        for _ in 0..<4 where !element.isHittable { app.swipeUp() }
        element.tap()
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
