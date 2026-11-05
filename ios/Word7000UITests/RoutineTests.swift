import XCTest

/// WordCat Next: today's words end with spot checks. Every card is marked
/// known, so the young words come back as spelling and the older ones (the
/// sample progress makes six of them due) as exam questions; then the
/// summary, and Today again. Screenshots of each step for review.
final class RoutineTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testCardsThenSpellingThenQuizThenSummary() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingLight", "-uiTestingSampleProgress", "-uiTestingFakePlans", "-uiTestingRoutine"]
        app.launch()
        let start = app.buttons["today-start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        snap(app, "routine-0-today")
        start.tap()

        // The cards: every one marked known.
        let handOff = app.descendants(matching: .any)["routine-hand-off"]
        let summary = app.descendants(matching: .any)["routine-summary"]
        var flipped = 0
        while !handOff.exists, !summary.exists, flipped < 40 {
            let show = app.buttons["study-show-answer"]
            guard show.waitForExistence(timeout: 5) else { break }
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: show)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
            if flipped == 0 {
                XCTAssertTrue(app.descendants(matching: .any)["routine-steps"].exists)
                snap(app, "routine-1-cards")
            }
            show.tap()
            let known = app.buttons["study-grade-known"]
            XCTAssertTrue(known.waitForExistence(timeout: 5))
            known.tap()
            flipped += 1
            _ = handOff.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(handOff.waitForExistence(timeout: 10), app.debugDescription)
        snap(app, "routine-2-hand-off")
        app.buttons["routine-begin"].tap()

        // Spelling: the first word is answered with another real word, to see
        // the cat name it; then each answer is typed from the sentence's value.
        let input = app.textFields["routine-input"]
        var spelled = 0
        while input.waitForExistence(timeout: 5) {
            let answer = app.staticTexts["cloze-sentence"].value as? String ?? ""
            XCTAssertFalse(answer.isEmpty, "the sentence carries its answer under UI tests")
            if spelled == 0 {
                snap(app, "routine-3-spell")
                input.tap()
                input.typeText("apple\n")
                XCTAssertTrue(app.staticTexts["routine-message"].waitForExistence(timeout: 5))
                snap(app, "routine-4-spell-another-word")
                // The keyboard stays up after a try, the cursor after the text.
                let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: input)
                XCTAssertEqual(XCTWaiter.wait(for: [focused], timeout: 3), .completed, "the keyboard stays up after a try")
                input.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8))
            }
            input.tap()
            input.typeText(answer + "\n")
            let next = app.buttons["routine-next"]
            XCTAssertTrue(next.waitForExistence(timeout: 5), app.debugDescription)
            if spelled == 0 { snap(app, "routine-5-spell-solved") }
            next.tap()
            spelled += 1
            if handOff.waitForExistence(timeout: 2) || summary.exists { break }
        }
        XCTAssertGreaterThan(spelled, 0)

        // The quiz: the first option each time, right or wrong.
        if app.buttons["routine-begin"].waitForExistence(timeout: 3) {
            snap(app, "routine-6-quiz-hand-off")
            app.buttons["routine-begin"].tap()
        }
        var asked = 0
        while app.buttons["routine-option-0"].waitForExistence(timeout: 8) {
            if asked == 0 { snap(app, "routine-7-quiz") }
            app.buttons["routine-option-0"].tap()
            let next = app.buttons["routine-next"]
            XCTAssertTrue(next.waitForExistence(timeout: 5))
            if asked == 0 {
                XCTAssertTrue(app.descendants(matching: .any)["routine-explanation"].exists)
                snap(app, "routine-8-quiz-answered")
            }
            next.tap()
            asked += 1
            if summary.waitForExistence(timeout: 2) { break }
        }
        XCTAssertGreaterThan(asked, 0, "the sample progress has older words due")

        XCTAssertTrue(summary.waitForExistence(timeout: 10), app.debugDescription)
        sleep(1)
        snap(app, "routine-9-summary")
        app.buttons["routine-done"].tap()
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        snap(app, "routine-10-today-after")
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
