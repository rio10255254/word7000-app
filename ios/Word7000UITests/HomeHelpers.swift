import XCTest

extension XCUIApplication {
    /// WordCat Next: the other ways to practise words are in the shelf sheet
    /// (the book on Today), under More practice. `labels` are the item's
    /// title in either interface language.
    func openWordsMenu(_ labels: String..., file: StaticString = #filePath, line: UInt = #line) {
        let shelf = buttons["today-shelf"]
        XCTAssertTrue(shelf.waitForExistence(timeout: 10), file: file, line: line)
        shelf.tap()
        let more = buttons["today-more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5), debugDescription, file: file, line: line)
        more.tap()
        let item = buttons.matching(NSPredicate(format: "label IN %@", labels)).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), debugDescription, file: file, line: line)
        item.tap()
    }
}
