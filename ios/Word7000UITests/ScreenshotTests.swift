import XCTest
import UIKit

/// Walks through the main screens and saves a screenshot of each, in light
/// and dark mode. CI uploads them so every change can be checked by eye.
enum L10n {
    static let close = "關閉"
}

final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    func testLightScreens() { walkThrough(theme: "Light") }
    func testDarkScreens() { walkThrough(theme: "Dark") }
    /// The paper collage style, through the same screens.
    func testCollageScreens() { walkThrough(theme: "Light", style: "collage") }
    func testCollageDarkScreens() { walkThrough(theme: "Dark", style: "collage") }

    /// After some practice the cat asks once which style to use; choosing
    /// the collage closes the sheet and Today redraws in it.
    func testStyleChooserAppearsOnceAndApplies() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingSampleProgress", "-uiTestingLight", "-uiTestingStyleChooser"]
        app.launch()
        XCTAssertTrue(app.buttons["style-choose"].waitForExistence(timeout: 10), "The style chooser did not appear")
        snap(app, "style-chooser")
        app.buttons["style-collage"].tap()
        app.buttons["style-choose"].tap()
        XCTAssertTrue(app.buttons["style-choose"].waitForNonExistence(timeout: 5), "The style chooser did not close")
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "style-chosen-collage-today")
        app.tabBars.buttons.element(boundBy: 2).tap()
        // Settings is the last row of Me: it only exists once scrolled to.
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        for _ in 0..<6 where !app.buttons["me-settings"].exists { app.swipeUp() }
        XCTAssertTrue(app.buttons["me-settings"].waitForExistence(timeout: 5))
        scrollClearOfTabBar(app, app.buttons["me-settings"])
        app.buttons["me-settings"].tap()
        XCTAssertTrue(app.buttons["settings-style"].waitForExistence(timeout: 5))
        // On a small screen the row can sit behind the tab bar while still
        // counting as hittable, and the tap would land on the tab bar.
        scrollClearOfTabBar(app, app.buttons["settings-style"])
        app.buttons["settings-style"].tap()
        XCTAssertTrue(app.buttons["style-leather"].waitForExistence(timeout: 5))
        snap(app, "style-settings")
    }

    /// The English interface for learning Chinese.
    func testChineseModeScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingSampleProgress", "-uiTestingLight", "-uiTestingChineseMode"]
        app.launch()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        snap(app, "zh-1-today")
        app.buttons["today-start"].tap()
        XCTAssertTrue(app.buttons["study-show-answer"].waitForExistence(timeout: 5))
        snap(app, "zh-2-study")
        app.buttons["study-show-answer"].tap()
        XCTAssertTrue(app.buttons["study-grade-known"].waitForExistence(timeout: 5))
        snap(app, "zh-3-study-answer")
        app.buttons["study-close"].tap()
        XCTAssertTrue(app.buttons["today-speaking"].waitForExistence(timeout: 5))
        app.buttons["today-speaking"].tap()
        XCTAssertTrue(app.segmentedControls["speaking-activity"].buttons["Questions"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls["speaking-activity"].buttons["Examples"].exists)
        sleep(1)
        snap(app, "zh-4-speaking")
    }

    func testTrialExpiresWhileAppRemainsOpen() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingLight", "-uiTestingTrialEndsSoon", "-uiTestingFakePlans"]
        app.launch()
        XCTAssertTrue(app.buttons["plus-recap-later"].waitForExistence(timeout: 20))
        snap(app, "plus-7-trial-expired-while-open")
        app.buttons["plus-recap-later"].tap()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 5))
    }

    func testHistoryChartSelectionAndRange() {
        historyChart(theme: "Light", chineseMode: false)
    }

    func testHistoryChartDarkEnglishInterface() {
        historyChart(theme: "Dark", chineseMode: true)
    }

    private func historyChart(theme: String, chineseMode: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTesting\(theme)", "-uiTestingPlus", "-uiTestingHistoryData", "-uiTestingFakePlans"]
        if chineseMode { app.launchArguments.append("-uiTestingChineseMode") }
        app.launch()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        app.tabBars.buttons.element(boundBy: 2).tap()
        for _ in 0..<4 where !app.buttons["me-history"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["me-history"].waitForExistence(timeout: 5))
        app.buttons["me-history"].tap()
        let chart = app.descendants(matching: .any)["history-chart"].firstMatch
        XCTAssertTrue(chart.waitForExistence(timeout: 5))
        let date = app.staticTexts["history-selected-date"]
        XCTAssertTrue(date.waitForExistence(timeout: 5))
        let initial = date.label
        XCTAssertEqual(app.staticTexts["history-selected-count"].label, chineseMode ? "11 actions" : "11 次")
        let speaking = app.descendants(matching: .any)["history-selected-speaking"].firstMatch
        XCTAssertTrue(speaking.exists)
        XCTAssertEqual(speaking.label, chineseMode ? "Speaking, 2" : "口說, 2")
        assertChartHasBars(chart)
        let prefix = chineseMode ? "dark-en" : "light"
        snap(app, "\(prefix)-history-seven-days")
        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.4))
            .press(forDuration: 0.3, thenDragTo: chart.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.4)))
        XCTAssertNotEqual(date.label, initial)
        snap(app, "\(prefix)-history-selected-day")
        app.buttons[chineseMode ? "30 days" : "30 天"].tap()
        XCTAssertEqual(date.label, initial)
        assertChartHasBars(chart)
        snap(app, "\(prefix)-history-thirty-days")
        app.buttons[chineseMode ? "90 days" : "90 天"].tap()
        XCTAssertEqual(date.label, chineseMode ? "Last 7 days" : "最近 7 天")
        assertChartHasBars(chart)
        snap(app, "\(prefix)-history-ninety-days")
        app.buttons[chineseMode ? "7 days" : "7 天"].tap()
        XCTAssertEqual(date.label, initial)
    }

    func testHistoryEmptyState() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingLight", "-uiTestingPlus", "-uiTestingFakePlans"]
        app.launch()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        app.tabBars.buttons.element(boundBy: 2).tap()
        for _ in 0..<4 where !app.buttons["me-history"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["me-history"].waitForExistence(timeout: 5))
        app.buttons["me-history"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["history-chart-empty"].firstMatch.waitForExistence(timeout: 5))
        snap(app, "plus-10-history-empty")
    }

    /// After the trial: the one-time recap, the reminder on Today, the
    /// paywall with plans, and a locked screen's preview.
    func testPlusScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingSampleProgress", "-uiTestingHistoryData", "-uiTestingLight", "-uiTestingTrialExpired", "-uiTestingFakePlans"]
        app.launch()
        let recap = app.buttons["plus-recap-later"]
        XCTAssertTrue(recap.waitForExistence(timeout: 10))
        if recap.exists {
            sleep(1)
            snap(app, "plus-1-trial-recap")
            recap.tap()
        }
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        sleep(1)
        snap(app, "plus-2-today-nudge")
        if app.buttons["plus-nudge"].waitForExistence(timeout: 3) {
            app.buttons["plus-nudge"].tap()
            sleep(2)
            snap(app, "plus-3-paywall")
            XCTAssertTrue(app.buttons["paywall-close"].isHittable)
            if app.buttons["plan-monthly"].exists {
                app.buttons["plan-monthly"].tap()
                sleep(1)
                app.swipeUp()
                sleep(1)
                snap(app, "plus-4-paywall-monthly")
                XCTAssertTrue(app.buttons["paywall-close"].isHittable)
            }
            app.buttons[L10n.close].firstMatch.tap()
            sleep(1)
        }
        app.tabBars.buttons.element(boundBy: 2).tap()
        sleep(1)
        snap(app, "plus-5-me")
        for _ in 0..<4 where !app.buttons["me-history"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["me-history"].waitForExistence(timeout: 5))
        if app.buttons["me-history"].exists {
            app.buttons["me-history"].tap()
            XCTAssertTrue(app.descendants(matching: .any)["history-chart"].firstMatch.waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["locked-unlock"].exists)
            snap(app, "plus-11-history-seven-free")
            app.buttons["30 天"].tap()
            XCTAssertTrue(app.buttons["locked-unlock"].waitForExistence(timeout: 5))
            sleep(1)
            snap(app, "plus-6-history-locked")
            app.buttons["7 天"].tap()
            XCTAssertTrue(app.descendants(matching: .any)["history-chart"].firstMatch.waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["locked-unlock"].exists)
        }
    }

    private func walkThrough(theme: String, style: String? = nil) {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingSampleProgress", "-uiTesting\(theme)", "-uiTestingFakePlans"]
        if style == "collage" { app.launchArguments.append("-uiTestingCollage") }
        app.launch()
        let prefix = [style, theme.lowercased()].compactMap { $0 }.joined(separator: "-")

        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        snap(app, "\(prefix)-1-today")

        app.buttons["today-start"].tap()
        XCTAssertTrue(app.buttons["study-show-answer"].waitForExistence(timeout: 5))
        snap(app, "\(prefix)-2-study")
        app.buttons["study-show-answer"].tap()
        XCTAssertTrue(app.buttons["study-grade-known"].waitForExistence(timeout: 5))
        snap(app, "\(prefix)-3-study-answer")
        app.buttons["study-grade-known"].tap()
        XCTAssertTrue(app.buttons["study-show-answer"].waitForExistence(timeout: 5))
        app.buttons["study-close"].tap()

        XCTAssertTrue(app.buttons["today-quiz"].waitForExistence(timeout: 5))
        app.buttons["today-quiz"].tap()
        XCTAssertTrue(app.buttons["quiz-start"].waitForExistence(timeout: 5))
        app.buttons["quiz-start"].tap()
        XCTAssertTrue(app.buttons["quiz-option-0"].waitForExistence(timeout: 5))
        snap(app, "\(prefix)-4-quiz")
        app.buttons["quiz-option-0"].tap()
        XCTAssertTrue(app.buttons["quiz-next"].waitForExistence(timeout: 5))
        snap(app, "\(prefix)-5-quiz-answered")
        let closeQuiz = app.buttons["quiz-close"]
        let closeReady = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            closeQuiz.exists && closeQuiz.isHittable && closeQuiz.frame.maxX < app.frame.midX
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [closeReady], timeout: 5), .completed)
        closeQuiz.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let quizGone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: closeQuiz)
        XCTAssertEqual(XCTWaiter.wait(for: [quizGone], timeout: 5), .completed)

        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.buttons["words-scan"].waitForExistence(timeout: 5))
        snap(app, "\(prefix)-6-words")
        app.cells.element(boundBy: 2).tap()
        sleep(1)
        snap(app, "\(prefix)-7-word-detail")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["words-scan"].tap()
        sleep(1)
        snap(app, "\(prefix)-8-scan")
        app.buttons["關閉"].firstMatch.tap()

        app.tabBars.buttons.element(boundBy: 2).tap()
        sleep(1)
        snap(app, "\(prefix)-9-me")

        if prefix == "light", app.buttons["me-plus"].waitForExistence(timeout: 3) {
            app.buttons["me-plus"].tap()
            sleep(3)
            snap(app, "\(prefix)-11-paywall")
            app.buttons[L10n.close].firstMatch.tap()
        }

        app.tabBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["today-speaking"].waitForExistence(timeout: 5))
        app.buttons["today-speaking"].tap()
        sleep(1)
        snap(app, "\(prefix)-10-speaking")
    }

    /// Swipes up until the element is fully above the tab bar.
    private func scrollClearOfTabBar(_ app: XCUIApplication, _ element: XCUIElement) {
        let tabBarTop = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY : app.frame.maxY
        for _ in 0..<6 where !(element.isHittable && element.frame.maxY <= tabBarTop - 4) {
            app.swipeUp()
        }
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

    private func assertChartHasBars(_ chart: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        guard let image = chart.screenshot().image.cgImage else {
            XCTFail("The chart screenshot is unavailable", file: file, line: line)
            return
        }
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        // The bars use the warm palette: terracotta words, sage speaking, slate quizzes.
        let colors = pixels.withUnsafeMutableBytes { bytes -> (terracotta: Int, sage: Int, slate: Int) in
            guard let context = CGContext(data: bytes.baseAddress, width: image.width, height: image.height,
                                          bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
                return (0, 0, 0)
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            let data = bytes.bindMemory(to: UInt8.self)
            var terracotta = 0, sage = 0, slate = 0
            for offset in stride(from: 0, to: data.count, by: 4) {
                let r = Int(data[offset]), g = Int(data[offset + 1]), b = Int(data[offset + 2])
                if r > 150, r > g + 60, g > b + 10 { terracotta += 1 }
                if g > 100, g > r + 20, g > b + 30 { sage += 1 }
                if b > 110, b > r + 35, b > g + 20 { slate += 1 }
            }
            return (terracotta, sage, slate)
        }
        XCTAssertGreaterThan(colors.terracotta, 500, "Vocabulary bars are missing", file: file, line: line)
        XCTAssertGreaterThan(colors.sage, 500, "Speaking bars are missing", file: file, line: line)
        XCTAssertGreaterThan(colors.slate, 300, "Quiz bars are missing", file: file, line: line)
    }
}
