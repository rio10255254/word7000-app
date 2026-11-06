import XCTest

extension XCUIApplication {
    /// WordCat Next: the other ways to practise words are in the Practice
    /// tab. `id` is the row's identifier.
    func openPractice(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let tab = tabBars.buttons.matching(NSPredicate(format: "label IN %@", ["練習", "Practice"])).firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 10), file: file, line: line)
        tab.tap()
        let row = buttons[id]
        XCTAssertTrue(row.waitForExistence(timeout: 5), debugDescription, file: file, line: line)
        row.tap()
    }
}

extension XCUIElement {
    /// Pulls the sheet this element sits on down and away, as a thumb does:
    /// a press inside the sheet dragged well below it. A swipe on the element
    /// is only as long as the element, too short on a line of text, and a
    /// swipe from the screen's middle misses a sheet only as tall as its note.
    func pullSheetDown(file: StaticString = #filePath, line: UInt = #line) {
        let app = XCUIApplication()
        let start = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let bottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
        start.press(forDuration: 0.05, thenDragTo: bottom, withVelocity: .fast, thenHoldForDuration: 0)
        // Still up: a tap on the dimmed screen above it, as a learner might.
        if !waitForNonExistence(timeout: 2) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.06)).tap()
        }
        XCTAssertTrue(waitForNonExistence(timeout: 5), "The sheet did not close", file: file, line: line)
    }
}
