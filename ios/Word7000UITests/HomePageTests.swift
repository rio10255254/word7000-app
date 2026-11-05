import XCTest

/// WordCat Next: Today as one path and one button. The button starts the
/// cards; the streak opens the week, the shelf opens the chapters with the
/// goal, the bank and more practice; the quiz stop runs a short exam-style
/// quiz to its score, and Sunday's stop opens the weekly quiz. Screenshots
/// of each.
final class HomePageTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testPathSheetsAndQuizzes() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingLight", "-uiTestingSampleProgress", "-uiTestingFakePlans", "-uiTestingWeeklyQuiz"]
        app.launch()
        let start = app.buttons["today-start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["today-node-cards"].exists)
        sleep(2)
        snap(app, "home-1-path")

        // The streak: this week's stamps.
        app.buttons["today-streak"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["today-week"].firstMatch.waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "home-2-week")
        app.swipeDown(velocity: .fast)

        // The shelf: chapters, goal, bank and more practice.
        let shelf = app.buttons["today-shelf"]
        XCTAssertTrue(shelf.waitForExistence(timeout: 5))
        shelf.tap()
        XCTAssertTrue(app.buttons["today-more"].waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "home-3-shelf")
        app.swipeDown(velocity: .fast)

        // The quiz stop: exam-style questions on learned words, then the score.
        let quiz = app.buttons["today-quiz"]
        XCTAssertTrue(quiz.waitForExistence(timeout: 5))
        quiz.tap()
        var asked = 0
        let summary = app.descendants(matching: .any)["exam-round-summary"]
        while app.buttons["routine-option-0"].waitForExistence(timeout: 8) {
            app.buttons["routine-option-\(asked % 4)"].tap()
            let next = app.buttons["routine-next"]
            XCTAssertTrue(next.waitForExistence(timeout: 5))
            next.tap()
            asked += 1
            if summary.waitForExistence(timeout: 1) { break }
        }
        XCTAssertGreaterThanOrEqual(asked, 4, "the sample progress has learned words to ask")
        XCTAssertTrue(summary.waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["exam-round-done"].tap()

        // Sunday's stop on the path.
        let weekly = app.buttons["today-weekly-quiz"]
        XCTAssertTrue(weekly.waitForExistence(timeout: 10))
        weekly.tap()
        let question = app.buttons["routine-option-0"]
        let empty = app.descendants(matching: .any)["exam-round-empty"]
        XCTAssertTrue(question.waitForExistence(timeout: 10) || empty.exists, app.debugDescription)
        app.buttons["exam-round-close"].tap()

        // The button starts the cards.
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        XCTAssertTrue(app.buttons["study-show-answer"].waitForExistence(timeout: 10))
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
