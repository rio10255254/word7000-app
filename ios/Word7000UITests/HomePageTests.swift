import XCTest

/// WordCat Next: the home page's two pillars. Words lead; speaking can be
/// made the first and back. The word card's quiz step runs a short
/// exam-style quiz to its score, Sunday's quiz note opens the weekly quiz,
/// and holding the card shows every way to practise. Screenshots of each.
final class HomePageTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testPillarsSwapAndTheQuizzesRun() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingLight", "-uiTestingSampleProgress", "-uiTestingFakePlans", "-uiTestingWeeklyQuiz"]
        app.launch()
        let start = app.buttons["today-start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        sleep(2)
        snap(app, "home-1-words-first")
        XCTAssertTrue(app.buttons["today-shelf"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["today-week"].exists)
        XCTAssertTrue(app.buttons["today-review"].exists)

        // Speaking first: the cards swap, and back.
        app.buttons["today-lead-speaking"].tap()
        XCTAssertTrue(app.buttons["today-lead-words"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["today-speaking"].exists)
        sleep(1)
        snap(app, "home-2-speaking-first")
        app.buttons["today-lead-words"].tap()
        XCTAssertTrue(app.buttons["today-lead-speaking"].waitForExistence(timeout: 5))

        // The ring changes the daily goal.
        app.buttons["today-goal"].tap()
        let thirty = app.buttons.matching(NSPredicate(format: "label IN %@", ["每天 30 個", "30 a day"])).firstMatch
        XCTAssertTrue(thirty.waitForExistence(timeout: 5), app.debugDescription)
        snap(app, "home-3-goal-menu")
        thirty.tap()
        XCTAssertTrue(app.buttons["today-goal"].waitForExistence(timeout: 5))

        // The quiz step: exam-style questions on learned words, then the score.
        app.buttons["today-quiz"].tap()
        var asked = 0
        let summary = app.descendants(matching: .any)["exam-round-summary"]
        while app.buttons["routine-option-0"].waitForExistence(timeout: 8) {
            if asked == 0 { snap(app, "home-4-quiz") }
            app.buttons["routine-option-\(asked % 4)"].tap()
            let next = app.buttons["routine-next"]
            XCTAssertTrue(next.waitForExistence(timeout: 5))
            if asked == 0 { snap(app, "home-5-quiz-answered") }
            next.tap()
            asked += 1
            if summary.waitForExistence(timeout: 1) { break }
        }
        XCTAssertGreaterThanOrEqual(asked, 4, "the sample progress has learned words to ask")
        XCTAssertTrue(summary.waitForExistence(timeout: 5), app.debugDescription)
        sleep(1)
        snap(app, "home-6-quiz-score")
        app.buttons["exam-round-done"].tap()

        // Sunday's quiz, from its note.
        let weekly = app.buttons["today-weekly-quiz"]
        XCTAssertTrue(weekly.waitForExistence(timeout: 10))
        weekly.tap()
        let question = app.buttons["routine-option-0"]
        let empty = app.descendants(matching: .any)["exam-round-empty"]
        XCTAssertTrue(question.waitForExistence(timeout: 10) || empty.exists, app.debugDescription)
        sleep(1)
        snap(app, "home-7-weekly")
        app.buttons["exam-round-close"].tap()

        // Holding the word card: every way to practise words.
        let cards = app.buttons["today-step-cards"]
        XCTAssertTrue(cards.waitForExistence(timeout: 10))
        cards.press(forDuration: 1.2)
        let meaning = app.buttons.matching(NSPredicate(format: "label IN %@", ["看字選意思", "Pick the meaning"])).firstMatch
        XCTAssertTrue(meaning.waitForExistence(timeout: 5), app.debugDescription)
        snap(app, "home-8-words-menu")
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
