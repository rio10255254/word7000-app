import XCTest

/// Word list content published without an app update: an official bank on
/// the Words shelf and a corrected built-in word.
final class OfficialBankTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testOfficialBankAppearsAndCorrectionsApply() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingLight", "-uiTestingOfficialBank"]
        app.launch()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        app.tabBars.buttons.matching(NSPredicate(format: "label IN %@", ["單字", "Words"])).firstMatch.tap()

        let bank = app.buttons["bank-official:medical"]
        XCTAssertTrue(bank.waitForExistence(timeout: 5))
        bank.tap()
        XCTAssertTrue(containing("diagnosis", in: app).waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(containing("symptom", in: app).exists)
        snapshot(app, name: "official-bank")

        // Studying it uses only its words.
        app.tabBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["today-start"].tap()
        XCTAssertTrue(app.buttons["study-show-answer"].waitForExistence(timeout: 5))
        let words = ["diagnosis", "symptom", "prescription"]
        let shown = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@ OR label CONTAINS %@", words[0], words[1], words[2]))
        XCTAssertTrue(shown.firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["study-close"].tap()

        // The built-in "adapt" carries the published correction (checked last:
        // search keeps the keyboard over the tab bar).
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        app.tabBars.buttons.matching(NSPredicate(format: "label IN %@", ["單字", "Words"])).firstMatch.tap()
        app.buttons["bank-core"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("adapt")
        XCTAssertTrue(containing("已校正", in: app).waitForExistence(timeout: 10), app.debugDescription)
    }

    private func containing(_ text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func snapshot(_ app: XCUIApplication, name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] {
            let directory = URL(fileURLWithPath: home).appendingPathComponent("word7000-screenshots", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent(name + ".png"))
        }
    }
}
