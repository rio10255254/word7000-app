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
