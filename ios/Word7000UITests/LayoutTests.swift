import XCTest

/// Today has to fit whatever iPhone it runs on: every part reachable without
/// scrolling, nothing under the tab bar, the companion clear of every button,
/// the header's buttons answering taps, and no wide empty band left at the
/// bottom. The tests read the simulator they are given; CI's layout check runs
/// them on an SE, a standard phone, a Pro and a Pro Max.
final class LayoutTests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingLight", "-uiTestingSampleProgress", "-uiTestingFakePlans"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        // Let the entrance animations settle before measuring.
        sleep(2)
        return app
    }

    func testTodayFitsInEnglishMode() {
        let app = launch()
        checkToday(app, name: "layout-english", tiles: ["today-quiz", "today-speaking", "today-spelling", "today-exam"])
    }

    func testTodayFitsInChineseMode() {
        let app = launch(["-uiTestingChineseMode"])
        checkToday(app, name: "layout-chinese", tiles: ["today-quiz", "today-speaking", "today-exam"])
    }

    func testTodayFitsInDarkMode() {
        let app = launch(["-uiTestingDark"])
        checkToday(app, name: "layout-dark", tiles: ["today-quiz", "today-speaking", "today-spelling", "today-exam"])
    }

    /// The header's buttons work, even right after the companion is tapped
    /// and is showing its speech bubble.
    func testHeaderButtonsAnswerTaps() {
        let app = launch()
        let mascot = app.buttons["today-mascot"]
        XCTAssertTrue(mascot.exists)
        mascot.tap()

        let chip = app.buttons["today-study-filter"]
        XCTAssertTrue(chip.isHittable)
        chip.tap()
        let sheet = app.navigationBars["學習範圍"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "The study scope did not open from the header chip")
        snap(app, "layout-scope-sheet")
        sheet.swipeDown(velocity: .fast)
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        sleep(1)

        mascot.tap()
        let chinese = app.buttons["today-language-zh"]
        XCTAssertTrue(chinese.isHittable)
        chinese.tap()
        // Learning Chinese: the interface turns English and spelling goes away.
        let selected = NSPredicate(format: "isSelected == true")
        expectation(for: selected, evaluatedWith: app.buttons["today-language-zh"])
        waitForExpectations(timeout: 5)
        XCTAssertFalse(app.buttons["today-spelling"].exists, "Spelling should go away when learning Chinese")
        snap(app, "layout-switched-to-chinese")

        app.buttons["today-language-en"].tap()
        expectation(for: selected, evaluatedWith: app.buttons["today-language-en"])
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["today-spelling"].waitForExistence(timeout: 5))
    }

    /// Plays with the companion: a tap, a drag, and a press and hold. None of
    /// it may leave Today in a state where its buttons stop working.
    func testCompanionCanBePlayedWith() {
        let app = launch()
        let mascot = app.buttons["today-mascot"]
        XCTAssertTrue(mascot.exists)
        mascot.tap()
        mascot.press(forDuration: 0.8)
        let from = mascot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        from.press(forDuration: 0.05, thenDragTo: from.withOffset(CGVector(dx: -60, dy: 30)))
        sleep(1)
        snap(app, "layout-companion")
        XCTAssertTrue(app.buttons["today-start"].isHittable)
        app.buttons["today-start"].tap()
        XCTAssertTrue(app.buttons["study-show-answer"].waitForExistence(timeout: 5), "Study did not open after playing with the companion")
    }

    // MARK: Checks

    private func checkToday(_ app: XCUIApplication, name: String, tiles: [String], file: StaticString = #filePath, line: UInt = #line) {
        snap(app, name)
        let window = app.windows.firstMatch.frame
        let tabBar = app.tabBars.firstMatch
        let bottom = tabBar.exists ? tabBar.frame.minY : window.maxY
        var ids = ["today-language-en", "today-language-zh", "today-study-filter", "today-start"] + tiles
        if app.buttons["today-review"].exists { ids.insert("today-review", at: 4) }

        var frames: [String: CGRect] = [:]
        for id in ids {
            let button = app.buttons[id]
            guard button.exists else {
                XCTFail("\(name): \(id) is missing", file: file, line: line)
                continue
            }
            let frame = button.frame
            frames[id] = frame
            XCTAssertTrue(button.isHittable, "\(name): \(id) can't be tapped without scrolling", file: file, line: line)
            XCTAssertTrue(window.contains(frame), "\(name): \(id) \(frame) runs off the screen \(window)", file: file, line: line)
            XCTAssertLessThanOrEqual(frame.maxY, bottom + 1, "\(name): \(id) \(frame) is under the tab bar (top \(bottom))", file: file, line: line)
        }

        let mascot = app.buttons["today-mascot"]
        if mascot.exists {
            // A little slack for the soft shadow at its edges.
            let body = mascot.frame.insetBy(dx: 4, dy: 4)
            for (id, frame) in frames where body.intersects(frame) {
                XCTFail("\(name): the companion \(body) covers \(id) \(frame)", file: file, line: line)
            }
        } else {
            XCTFail("\(name): the companion is missing", file: file, line: line)
        }

        // The page should use the phone's height: not much left under the last tile.
        let last = frames.values.map(\.maxY).max() ?? bottom
        let gap = bottom - last
        let note = "\(name): window \(window), tab bar top \(bottom), last tile ends \(last), gap \(gap)"
        print("LAYOUT \(note)")
        XCTAssertLessThan(gap, 150, "\(note): too much empty room at the bottom", file: file, line: line)
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] {
            let directory = URL(fileURLWithPath: home).appendingPathComponent("word7000-screenshots")
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"))
            try? app.debugDescription.write(to: directory.appendingPathComponent("\(name)-hierarchy.txt"), atomically: true, encoding: .utf8)
        }
    }
}
