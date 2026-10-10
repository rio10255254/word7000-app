import XCTest

/// Walks through the main screens and saves a screenshot of each, in light
/// and dark mode. CI uploads them so every change can be checked by eye.
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    func testLightScreens() { walkThrough(theme: "Light") }
    func testDarkScreens() { walkThrough(theme: "Dark") }

    private func walkThrough(theme: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingSampleProgress", "-uiTesting\(theme)"]
        app.launch()
        let prefix = theme.lowercased()

        XCTAssertTrue(app.buttons["home-start-study"].waitForExistence(timeout: 10))
        snap(app, "\(prefix)-1-home")

        app.buttons["home-start-study"].tap()
        XCTAssertTrue(app.buttons["study-show-answer"].waitForExistence(timeout: 5))
        snap(app, "\(prefix)-2-study")
        app.buttons["study-show-answer"].tap()
        XCTAssertTrue(app.buttons["study-grade-known"].waitForExistence(timeout: 5))
        snap(app, "\(prefix)-3-study-revealed")
        app.buttons["study-grade-known"].tap()
        XCTAssertTrue(app.buttons["study-show-answer"].waitForExistence(timeout: 5))

        app.tabBars.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(app.buttons["quiz-start"].waitForExistence(timeout: 5))
        snap(app, "\(prefix)-4-quiz-setup")
        app.buttons["quiz-start"].tap()
        XCTAssertTrue(app.buttons["quiz-option-0"].waitForExistence(timeout: 5))
        snap(app, "\(prefix)-5-quiz-question")
        app.buttons["quiz-option-0"].tap()
        XCTAssertTrue(app.buttons["quiz-next"].waitForExistence(timeout: 5))
        snap(app, "\(prefix)-6-quiz-answered")

        app.tabBars.buttons.element(boundBy: 3).tap()
        sleep(1)
        snap(app, "\(prefix)-7-library")
        app.cells.element(boundBy: 1).tap()
        sleep(1)
        snap(app, "\(prefix)-8-word-detail")

        app.tabBars.buttons.element(boundBy: 4).tap()
        sleep(1)
        snap(app, "\(prefix)-9-profile")

        app.tabBars.buttons.element(boundBy: 0).tap()
        app.buttons["bank-button"].firstMatch.tap()
        sleep(1)
        snap(app, "\(prefix)-10-bank-picker")
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        // Also write straight to the Mac running the simulator, like fastlane
        // snapshot does, so CI can upload the PNGs as they are.
        if let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] {
            let directory = URL(fileURLWithPath: home).appendingPathComponent("word7000-screenshots")
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"))
        }
    }
}
