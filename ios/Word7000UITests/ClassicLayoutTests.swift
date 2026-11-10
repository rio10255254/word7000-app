import XCTest

/// The classic layout: 2.0.2's Today with its practice tiles, today's path as
/// chapters in the Language learning tab, and writing that can be turned off.
final class ClassicLayoutTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingLight", "-uiTestingSampleProgress", "-uiTestingClassic"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        return app
    }

    private func tab(_ app: XCUIApplication, _ labels: [String]) -> XCUIElement {
        app.tabBars.buttons.matching(NSPredicate(format: "label IN %@", labels)).firstMatch
    }

    /// The chapter being read, on the Language learning tab.
    private func readingChapter(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "正在讀", "Reading now")).firstMatch
    }

    func testClassicTodayHasTheTilesAndTheChaptersOpenTodaysSteps() {
        let app = launch()
        for id in ["today-quiz", "today-speaking", "today-spelling", "today-exam"] {
            XCTAssertTrue(app.buttons[id].waitForExistence(timeout: 5), "\(id) on the classic Today")
        }
        XCTAssertFalse(tab(app, ["練習", "Practice"]).exists, "the classic layout has no Practice tab")
        snapshot(app, "classic-today")

        let learning = tab(app, ["語言學習", "Language learning"])
        XCTAssertTrue(learning.exists)
        learning.tap()
        let chapter = readingChapter(app)
        XCTAssertTrue(chapter.waitForExistence(timeout: 5), app.debugDescription)
        snapshot(app, "classic-path")
        chapter.tap()
        XCTAssertTrue(app.buttons["chapter-step-cards"].waitForExistence(timeout: 5), app.debugDescription)
        for step in ["spell", "quiz", "speaking"] {
            XCTAssertTrue(app.buttons["chapter-step-\(step)"].exists, "\(step) is one of the chapter's tiles")
        }
        snapshot(app, "classic-chapter")
        // The first tile opens today's cards.
        app.buttons["chapter-step-cards"].tap()
        XCTAssertTrue(app.buttons["study-show-answer"].waitForExistence(timeout: 10), app.debugDescription)
    }

    func testWritingCanBeTurnedOffAndTheLayoutSwitchedBack() {
        let app = launch()
        tab(app, ["我", "Me"]).tap()
        let settings = app.buttons["me-settings"]
        settings.scrollIntoView(in: app, swipes: 5)
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()

        // A swipe can carry a row right past a small screen; drag a short way
        // at a time until it is there.
        func reach(_ element: XCUIElement) {
            for _ in 0..<16 where !(element.exists && element.isHittable) {
                let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -160)))
            }
        }
        let classic = app.buttons["settings-layout-1"]
        reach(classic)
        XCTAssertTrue(classic.isSelected, app.debugDescription)
        let writing = app.switches["settings-writing"]
        reach(writing)
        XCTAssertEqual(writing.value as? String, "1", "writing is on until turned off")
        // WordCat's own switch is the whole row; the system switch inside it has no size.
        let inner = writing.switches.firstMatch
        let control = inner.exists && inner.isHittable ? inner : writing
        control.tap()
        func switchedOff(within seconds: TimeInterval) -> Bool {
            let off = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '0'"), object: writing)
            return XCTWaiter.wait(for: [off], timeout: seconds) == .completed
        }
        // A tap the system drops leaves it on: retry once, only while it still reads on.
        if !switchedOff(within: 3), writing.value as? String == "1" { control.tap() }
        XCTAssertTrue(switchedOff(within: 5), app.debugDescription)
        snapshot(app, "classic-settings")

        // No writing tile on Today, and no writing step in the chapter.
        tab(app, ["今天", "Today"]).tap()
        XCTAssertTrue(app.buttons["today-quiz"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["today-spelling"].exists, "the writing tile is gone")
        tab(app, ["語言學習", "Language learning"]).tap()
        let chapter = readingChapter(app)
        XCTAssertTrue(chapter.waitForExistence(timeout: 5), app.debugDescription)
        chapter.tap()
        XCTAssertTrue(app.buttons["chapter-step-cards"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["chapter-step-quiz"].exists)
        XCTAssertFalse(app.buttons["chapter-step-spell"].exists, "no writing tile either")
        snapshot(app, "classic-chapter-no-writing")

        // Back to the new layout: Practice returns, Language learning goes.
        tab(app, ["我", "Me"]).tap()
        let newLayout = app.buttons["settings-layout-0"]
        reach(newLayout)
        newLayout.tap()
        XCTAssertTrue(tab(app, ["練習", "Practice"]).waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(tab(app, ["語言學習", "Language learning"]).exists)
        XCTAssertFalse(app.switches["settings-writing"].exists, "the writing switch is only for the classic layout")
    }

    private func snapshot(_ app: XCUIApplication, _ name: String) {
        guard let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] else { return }
        let directory = URL(fileURLWithPath: home).appendingPathComponent("word7000-screenshots")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation.write(to: directory.appendingPathComponent(name + ".png"))
        try? app.debugDescription.write(to: directory.appendingPathComponent(name + "-hierarchy.txt"), atomically: true, encoding: .utf8)
    }
}
