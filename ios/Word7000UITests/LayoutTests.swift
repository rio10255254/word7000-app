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
        let theme = extra.contains("-uiTestingDark") ? [] : ["-uiTestingLight"]
        app.launchArguments = ["-uiTestingReset", "-uiTestingSampleProgress", "-uiTestingFakePlans"] + theme + extra
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
        checkToday(app, name: "layout-chinese", tiles: ["today-quiz", "today-speaking", "today-spelling", "today-exam"])
    }

    /// The other look, leather (the others run in the default, the collage).
    func testTodayFitsInLeather() {
        let app = launch(["-uiTestingLeather"])
        checkToday(app, name: "layout-leather", tiles: ["today-quiz", "today-speaking", "today-spelling", "today-exam"])
    }

    func testTodayFitsInDarkMode() {
        let app = launch(["-uiTestingDark"])
        checkToday(app, name: "layout-dark", tiles: ["today-quiz", "today-speaking", "today-spelling", "today-exam"])
    }

    /// The Me page's capsule buttons keep their labels on one line in the
    /// English interface at the largest standard text size: side by side
    /// when they fit, else one above the other, never "subscriptio / n".
    func testMeButtonsKeepLabelsWhole() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingSampleProgress", "-uiTestingFakePlans", "-uiTestingLight",
                               "-uiTestingChineseMode", "-uiTestingPlus",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        app.tabBars.buttons.element(boundBy: 2).tap()
        let plus = app.buttons["me-plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "layout-me-large-text")
        let window = app.windows.firstMatch.frame
        var frames = [plus.frame]
        let signIn = app.buttons["me-sign-in"]
        if signIn.exists { frames.append(signIn.frame) }
        for frame in frames {
            // One line of text in a large capsule is well under 72 points tall.
            XCTAssertLessThan(frame.height, 72, "a button label wrapped: \(frame)")
            XCTAssertTrue(window.contains(frame), "\(frame) runs off the screen \(window)")
        }
        if frames.count == 2 {
            XCTAssertFalse(frames[0].intersects(frames[1]), "the buttons overlap: \(frames)")
        }
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
        sheet.buttons["完成"].tap()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5), "The study scope did not close")

        mascot.tap()
        let chinese = app.buttons["today-language-zh"]
        XCTAssertTrue(chinese.isHittable)
        chinese.tap()
        // Learning Chinese: the interface turns English, and spelling becomes
        // writing the Chinese (characters or pinyin), so the tile stays.
        let selected = NSPredicate(format: "isSelected == true")
        expectation(for: selected, evaluatedWith: app.buttons["today-language-zh"])
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["today-spelling"].waitForExistence(timeout: 5), "Writing practice should stay when learning Chinese")
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

    /// The main screens on this phone: each one's key buttons fully on the
    /// screen, and a screenshot of each to look over at every size.
    func testMainScreensFitThisPhone() {
        let app = launch()
        let window = app.windows.firstMatch.frame

        app.buttons["today-start"].tap()
        let showAnswer = app.buttons["study-show-answer"]
        XCTAssertTrue(showAnswer.waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "tour-1-card")
        onScreen(showAnswer, in: window, "study-show-answer")
        showAnswer.tap()
        let known = app.buttons["study-grade-known"]
        XCTAssertTrue(known.waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "tour-2-answer")
        onScreen(known, in: window, "study-grade-known")
        onScreen(app.buttons["study-grade-review"], in: window, "study-grade-review")
        app.buttons["study-close"].tap()

        let quiz = app.buttons["today-quiz"]
        XCTAssertTrue(quiz.waitForExistence(timeout: 5))
        quiz.tap()
        let start = app.buttons["quiz-start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "tour-3-quiz-setup")
        onScreen(start, in: window, "quiz-start")
        start.tap()
        XCTAssertTrue(app.buttons["quiz-option-0"].waitForExistence(timeout: 5))
        app.buttons["quiz-option-0"].tap()
        let next = app.buttons["quiz-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "tour-4-quiz-answered")
        onScreen(next, in: window, "quiz-next")
        app.buttons["quiz-close"].tap()

        let speaking = app.buttons["today-speaking"]
        XCTAssertTrue(speaking.waitForExistence(timeout: 5))
        speaking.tap()
        let record = app.buttons["shadow-record"]
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        sleep(2)
        snap(app, "tour-5-speaking")
        onScreen(record, in: window, "shadow-record")
        let skip = app.buttons["shadow-skip"]
        onScreen(skip, in: window, "shadow-skip")
        skip.tap()
        let moveOn = app.buttons["speaking-next"]
        XCTAssertTrue(moveOn.waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "tour-6-speaking-question")
        onScreen(moveOn, in: window, "speaking-next")
        moveOn.tap()
        // The next turn keeps the line said before, faded, above the new ones.
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        sleep(2)
        snap(app, "tour-7-speaking-turn2")
        XCTAssertTrue(app.descendants(matching: .any)["speaking-earlier-line"].firstMatch.exists, "The line said before stays above")
        onScreen(app.buttons["shadow-record"], in: window, "shadow-record (turn 2)")
    }

    /// Fully on the screen, so it can be seen and tapped.
    private func onScreen(_ element: XCUIElement, in window: CGRect, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        guard element.exists else { return XCTFail("\(name) is missing", file: file, line: line) }
        let frame = element.frame
        XCTAssertTrue(window.insetBy(dx: -1, dy: -1).contains(frame), "\(name) runs off the screen: \(frame) in \(window)", file: file, line: line)
        XCTAssertTrue(element.isHittable, "\(name) can't be tapped", file: file, line: line)
    }

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
