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
        app.tabBars.buttons.element(boundBy: 1).tap()

        // The built-in "adapt" carries the published correction.
        XCTAssertTrue(app.staticTexts["適應（已校正）"].waitForExistence(timeout: 10), app.debugDescription)

        let bank = app.buttons["bank-official:medical"]
        XCTAssertTrue(bank.waitForExistence(timeout: 5))
        bank.tap()
        XCTAssertTrue(app.staticTexts["diagnosis"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["symptom"].exists)
        snapshot(app, name: "official-bank")

        // Studying it uses only its words.
        app.tabBars.buttons.element(boundBy: 0).tap()
        app.buttons["today-start"].tap()
        XCTAssertTrue(app.buttons["study-show-answer"].waitForExistence(timeout: 5))
        let words = ["diagnosis", "symptom", "prescription"]
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label IN %@", words)).firstMatch.waitForExistence(timeout: 5),
                      app.debugDescription)
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
