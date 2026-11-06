import XCTest

/// WordCat Next: a screenshot of every page, in order, for review. Today
/// and its two sheets, each round in the Practice tab, Words with a word,
/// and Me with Settings. Nothing is asserted beyond reaching each page.
final class TourTests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    private var n = 0
    private var prefix = "tour"

    func testEveryPage() { tour(["-uiTestingLight"]) }

    /// The way the testers see it at night: dark, in the collage.
    func testEveryPageDarkCollage() {
        prefix = "tour-dark"
        tour(["-uiTestingDark", "-uiTestingCollage"])
    }

    /// The cat's chat in the dark: its cream bubbles keep dark text.
    func testCatChatDarkCollage() {
        prefix = "tour-dark"
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingSampleProgress", "-uiTestingDark", "-uiTestingCollage", "-uiTestingCatShowcase"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["mascot-chat-input"].waitForExistence(timeout: 10))
        sleep(2)
        snap(app, "cat-chat")
    }

    private func tour(_ look: [String]) {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingSampleProgress", "-uiTestingFakePlans",
                               "-uiTestingRoutine", "-uiTestingSpeakingRoutine", "-uiTestingDayComplete"] + look
        app.launch()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        sleep(2)
        snap(app, "today")

        // The two sheets are only as tall as what they hold: pull each down by the sheet itself.
        tapIfThere(app.buttons["today-streak"]); sleep(1); snap(app, "today-streak-sheet")
        app.descendants(matching: .any)["today-week"].firstMatch.swipeDown(velocity: .fast); sleep(1)
        tapIfThere(app.buttons["today-shelf"]); sleep(1); snap(app, "today-shelf-sheet")
        app.buttons["today-goal"].swipeDown(velocity: .fast); sleep(1)

        // Practice: each round's first screen.
        let rows = ["practice-missed", "practice-spell", "practice-exam-style", "practice-meaning", "practice-mock",
                    "practice-scenarios", "practice-word-speaking"]
        tab(app, ["練習", "Practice"])
        sleep(1)
        snap(app, "practice")
        for row in rows {
            tab(app, ["練習", "Practice"])
            let button = app.buttons[row]
            guard button.waitForExistence(timeout: 5) else { continue }
            for _ in 0..<3 where !button.isHittable { app.swipeUp() }
            button.tap()
            sleep(3)
            snap(app, row)
            close(app)
        }

        // Words, and one word.
        tab(app, ["單字", "Words"])
        sleep(1)
        snap(app, "words")
        let cell = app.cells.element(boundBy: 2)
        if cell.waitForExistence(timeout: 5) {
            cell.tap()
            sleep(1)
            snap(app, "word-detail")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        // Me, scrolled, and Settings.
        tab(app, ["我", "Me"])
        sleep(1)
        snap(app, "me")
        app.swipeUp(); sleep(1); snap(app, "me-more")
        app.swipeUp(); sleep(1); snap(app, "me-end")
        let settings = app.buttons["me-settings"]
        for _ in 0..<3 where !settings.isHittable { app.swipeUp() }
        if settings.exists {
            settings.tap()
            sleep(1)
            snap(app, "settings")
        }
    }

    private func tab(_ app: XCUIApplication, _ labels: [String]) {
        let button = app.tabBars.buttons.matching(NSPredicate(format: "label IN %@", labels)).firstMatch
        if button.waitForExistence(timeout: 5) { button.tap() }
    }

    private func tapIfThere(_ element: XCUIElement) {
        if element.waitForExistence(timeout: 5) { element.tap() }
    }

    /// Closes whatever round or sheet is open.
    private func close(_ app: XCUIApplication) {
        for id in ["study-close", "cloze-close", "exam-round-close", "quiz-close", "exam-close", "speaking-close"] {
            let button = app.buttons[id]
            if button.exists, button.isHittable { button.tap(); sleep(1); return }
        }
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["關閉", "Close", "取消", "Cancel"])).firstMatch
        if cancel.exists { cancel.tap(); sleep(1); return }
        app.swipeDown(velocity: .fast)
        sleep(1)
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        n += 1
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] {
            let directory = URL(fileURLWithPath: home).appendingPathComponent("word7000-screenshots")
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent(String(format: "%@-%02d-%@.png", prefix, n, name)))
        }
    }
}
