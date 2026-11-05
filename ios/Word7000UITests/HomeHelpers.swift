import XCTest

extension XCUIApplication {
    /// WordCat Next: every way to practise words is in the word card's menu,
    /// opened by pressing and holding the card. `labels` are the item's title
    /// in either interface language.
    func openWordsMenu(_ labels: String..., file: StaticString = #filePath, line: UInt = #line) {
        let cards = buttons["today-step-cards"]
        XCTAssertTrue(cards.waitForExistence(timeout: 10), file: file, line: line)
        cards.press(forDuration: 1.2)
        let item = buttons.matching(NSPredicate(format: "label IN %@", labels)).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), debugDescription, file: file, line: line)
        item.tap()
    }
}
