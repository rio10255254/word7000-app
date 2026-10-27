import XCTest

/// Walks the main screens on whatever iPhone runs it, in both study modes,
/// and checks what a learner needs is on screen without scrolling: the day's
/// practice on Today, all quiz answers, the grade buttons, and a typing
/// answer above the keyboard. Every screen is saved as
/// `<device>-<mode>-<screen>.png`, with how long the main steps took, so the
/// devices check can compare every iPhone shape side by side.
final class DeviceLayoutTests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    func testEnglishModeFitsThisIPhone() { walk(chinese: false) }

    func testChineseModeFitsThisIPhone() { walk(chinese: true) }

    // MARK: Walk

    private func walk(chinese: Bool) {
        let mode = chinese ? "zh" : "en"
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingLight", "-uiTestingSampleProgress", "-uiTestingFakePlans"]
        if chinese { app.launchArguments.append("-uiTestingChineseMode") }
        var timings: [String: Double] = [:]

        let launched = Date()
        app.launch()
        let start = app.buttons["today-start"]
        XCTAssertTrue(start.waitForExistence(timeout: 20))
        timings["launchToToday"] = Date().timeIntervalSince(launched)
        settle()
        snapshot(app, mode, "today")
        // The whole day fits on one screen: no scrolling to reach practice.
        for id in ["today-start", "today-quiz", "today-speaking", chinese ? "today-pinyin" : "today-spelling", "today-exam"] {
            assertOnScreen(app, app.buttons[id], "\(mode) Today: \(id)")
        }

        // Study card, front and back.
        var began = Date()
        start.tap()
        let show = app.buttons["study-show-answer"]
        XCTAssertTrue(show.waitForExistence(timeout: 10))
        timings["openStudy"] = Date().timeIntervalSince(began)
        settle()
        snapshot(app, mode, "study-front")
        show.tap()
        let known = app.buttons["study-grade-known"]
        XCTAssertTrue(known.waitForExistence(timeout: 5))
        settle()
        snapshot(app, mode, "study-back")
        assertOnScreen(app, known, "\(mode) study: know it")
        assertOnScreen(app, app.buttons["study-grade-review"], "\(mode) study: not yet")
        close(app, "study-close")

        // Quiz: every answer reachable without scrolling.
        began = Date()
        app.buttons["today-quiz"].tap()
        let firstOption = app.buttons["quiz-option-0"]
        XCTAssertTrue(firstOption.waitForExistence(timeout: 10))
        timings["openQuiz"] = Date().timeIntervalSince(began)
        settle()
        snapshot(app, mode, "quiz")
        for index in 0..<4 { assertOnScreen(app, app.buttons["quiz-option-\(index)"], "\(mode) quiz: option \(index)") }
        firstOption.tap()
        settle()
        snapshot(app, mode, "quiz-answered")
        close(app, "quiz-close")

        // Typing practice: after checking, the right answer is not under the keyboard.
        app.buttons[chinese ? "today-pinyin" : "today-spelling"].tap()
        let input = app.textFields["spelling-input"]
        if input.waitForExistence(timeout: 10) {
            settle()
            snapshot(app, mode, "typing")
            input.tap()
            input.typeText("zz")
            app.buttons["spelling-check"].tap()
            let answer = app.staticTexts["spelling-answer"]
            XCTAssertTrue(answer.waitForExistence(timeout: 5))
            settle()
            snapshot(app, mode, "typing-answer")
            let keyboard = app.keyboards.firstMatch
            let limit = keyboard.exists ? keyboard.frame.minY : app.frame.maxY
            XCTAssertLessThanOrEqual(answer.frame.maxY, limit, "\(mode) typing: the answer is hidden under the keyboard on \(device)")
            assertOnScreen(app, app.buttons["spelling-next"], "\(mode) typing: next")
            close(app, "spelling-close")
        } else {
            XCTFail("\(mode): typing practice did not open on \(device)")
        }

        // Speaking.
        app.buttons["today-speaking"].tap()
        if app.staticTexts["speaking-question"].waitForExistence(timeout: 10) || app.buttons["speaking-close"].waitForExistence(timeout: 2) {
            settle()
            snapshot(app, mode, "speaking")
        }
        close(app, "speaking-close")

        // Words and a word's page.
        began = Date()
        openTab(app, index: 1)
        let firstWord = app.cells.element(boundBy: 2)
        XCTAssertTrue(firstWord.waitForExistence(timeout: 10))
        timings["openWords"] = Date().timeIntervalSince(began)
        settle()
        snapshot(app, mode, "words")
        firstWord.tap()
        settle()
        snapshot(app, mode, "word-detail")

        // Me.
        openTab(app, index: 2)
        settle()
        snapshot(app, mode, "me")

        saveTimings(timings, mode: mode)
    }

    // MARK: Helpers

    /// The simulator's model name, e.g. "iPhone SE (3rd generation)".
    private var device: String {
        ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "iPhone"
    }

    private var fileStem: String {
        device.replacingOccurrences(of: "[^A-Za-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// Lets springs and the tab change settle before a screenshot.
    private func settle() { usleep(600_000) }

    /// On screen now, inside the window and clear of the tab bar.
    private func assertOnScreen(_ app: XCUIApplication, _ element: XCUIElement, _ what: String) {
        guard element.waitForExistence(timeout: 3) else {
            XCTFail("\(what) is not on screen on \(device) (it may need scrolling)")
            return
        }
        let frame = element.frame
        var visible = app.frame
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists, tabBar.frame.minY > app.frame.midY { visible.size.height = tabBar.frame.minY - visible.minY }
        XCTAssertTrue(element.isHittable && visible.contains(CGPoint(x: frame.midX, y: frame.maxY - 1)),
                      "\(what) needs scrolling on \(device): \(frame) outside \(visible)")
    }

    private func close(_ app: XCUIApplication, _ id: String) {
        let button = app.buttons[id]
        guard button.waitForExistence(timeout: 3) else { return }
        button.tap()
        _ = app.buttons["today-start"].waitForExistence(timeout: 5)
    }

    /// The tab bar, or the side rail it becomes on a wide iPhone.
    private func openTab(_ app: XCUIApplication, index: Int) {
        let labels = [["今天", "Today"], ["單字", "Words"], ["我", "Me"]][index]
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists, tabBar.buttons.count > index {
            tabBar.buttons.element(boundBy: index).tap()
            return
        }
        let item = app.buttons.matching(NSPredicate(format: "label IN %@", labels)).firstMatch
        if item.waitForExistence(timeout: 3) { item.tap() } else { XCTFail("No \(labels[1]) tab on \(device)") }
    }

    private var outputDirectory: URL? {
        guard let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] else { return nil }
        let directory = URL(fileURLWithPath: home).appendingPathComponent("word7000-device-screenshots")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func snapshot(_ app: XCUIApplication, _ mode: String, _ name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(fileStem)-\(mode)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let directory = outputDirectory else { return }
        try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(fileStem)-\(mode)-\(name).png"))
    }

    private func saveTimings(_ timings: [String: Double], mode: String) {
        guard let directory = outputDirectory else { return }
        let rounded = timings.mapValues { ($0 * 100).rounded() / 100 }
        let record: [String: Any] = ["device": device, "mode": mode, "seconds": rounded]
        if let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]) {
            try? data.write(to: directory.appendingPathComponent("\(fileStem)-\(mode)-timings.json"))
        }
    }
}
