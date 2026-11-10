import XCTest

/// Today has to fit whatever iPhone it runs on: every part reachable without
/// scrolling, nothing under the tab bar, the companion clear of every button,
/// the header's buttons answering taps, and no wide empty band left at the
/// bottom. The tests read the simulator they are given; CI's layout check runs
/// them on an SE, a standard phone, a Pro and a Pro Max.
final class LayoutTests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    /// WordCat Next: the controls on Today besides the header and today-start.
    private static let home = ["today-streak", "today-shelf", "today-node-cards", "today-spelling", "today-quiz", "today-speaking"]

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

    /// The classic Today fills the phone: its practice tiles grow (up to a
    /// tile's size) down to the tab bar, leaving no strip under them.
    func testClassicTodayFillsThisPhone() {
        let app = launch(["-uiTestingClassic"])
        checkToday(app, name: "layout-classic", tiles: ["today-quiz", "today-speaking", "today-spelling", "today-exam"], maxGap: 40)
    }

    /// A chapter's route fills the phone too: its steps grow to a strip's
    /// size and the dashed route between them takes the rest.
    func testChapterRouteFillsThisPhone() {
        let app = launch(["-uiTestingClassic"])
        let tab = app.tabBars.buttons.matching(NSPredicate(format: "label IN %@", ["語言學習", "Language learning"])).firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()
        let chapter = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "正在讀", "Reading now")).firstMatch
        XCTAssertTrue(chapter.waitForExistence(timeout: 5), app.debugDescription)
        chapter.tap()
        XCTAssertTrue(app.buttons["chapter-step-cards"].waitForExistence(timeout: 5), app.debugDescription)
        sleep(2)
        checkToday(app, name: "layout-chapter", tiles: ["chapter-step-cards", "chapter-step-spell", "chapter-step-quiz", "chapter-step-speaking"],
                   start: nil, mascot: nil, maxGap: 40)
    }

    func testTodayFitsInEnglishMode() {
        let app = launch()
        checkToday(app, name: "layout-english", tiles: Self.home)
    }

    func testTodayFitsInChineseMode() {
        let app = launch(["-uiTestingChineseMode"])
        checkToday(app, name: "layout-chinese", tiles: Self.home)
    }

    /// The other look, leather (the others run in the default, the collage).
    func testTodayFitsInLeather() {
        let app = launch(["-uiTestingLeather"])
        checkToday(app, name: "layout-leather", tiles: Self.home)
    }

    func testTodayFitsInDarkMode() {
        let app = launch(["-uiTestingDark"])
        checkToday(app, name: "layout-dark", tiles: Self.home)
    }

    /// The Practice tab fits one screen: every way to practise above the
    /// tab bar, with nothing to scroll for.
    func testPracticeFitsWithoutScrolling() {
        let app = launch()
        let tab = app.tabBars.buttons.matching(NSPredicate(format: "label IN %@", ["練習", "Practice"])).firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()
        let last = app.buttons["practice-word-speaking"]
        XCTAssertTrue(last.waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "layout-practice")
        let window = app.windows.firstMatch.frame
        let tabBar = app.tabBars.firstMatch
        let bottom = tabBar.exists ? tabBar.frame.minY : window.maxY
        for id in ["practice-missed", "practice-spell", "practice-exam-style", "practice-meaning", "practice-mock",
                   "practice-cards", "practice-scenarios", "practice-word-speaking"] {
            let row = app.buttons[id]
            guard row.exists else { continue }
            onScreen(row, in: window, id)
            XCTAssertLessThanOrEqual(row.frame.maxY, bottom + 1, "\(id) sits under the tab bar")
        }
    }

    /// The Me page's capsule buttons keep their labels on one line in the
    /// English interface at the largest standard text size: side by side
    /// when they fit, else one above the other, never "subscriptio / n".
    /// Not subscribed: a subscriber manages Premium in Settings instead.
    func testMeButtonsKeepLabelsWhole() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingSampleProgress", "-uiTestingFakePlans", "-uiTestingLight",
                               "-uiTestingChineseMode",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        app.tabBars.buttons.matching(NSPredicate(format: "label IN %@", ["我", "Me"])).firstMatch.tap()
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
        // WordCat Next: a tap opens the chat with the cat; closing it leaves Today working.
        mascot.tap()
        closeCatChat(app)

        // The word bank is in the shelf sheet, opened from the top.
        let shelf = app.buttons["today-shelf"]
        XCTAssertTrue(shelf.isHittable)
        shelf.tap()
        let chip = app.buttons["today-study-filter"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        chip.tap()
        let sheet = app.navigationBars["學習範圍"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "The study scope did not open from the shelf sheet")
        snap(app, "layout-scope-sheet")
        sheet.buttons["完成"].tap()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5), "The study scope did not close")

        // WordCat Next: the language is chosen in Settings, not on Today.
        // Learning Chinese: the interface turns English, and spelling becomes
        // writing the Chinese (characters or pinyin), so the step stays.
        app.terminate()
        let chinese = launch(["-uiTestingChineseMode"])
        XCTAssertFalse(chinese.buttons["today-language-zh"].exists)
        XCTAssertTrue(chinese.buttons["today-spelling"].waitForExistence(timeout: 5), "Writing practice should stay when learning Chinese")
        snap(chinese, "layout-switched-to-chinese")
    }

    /// Plays with the companion: a tap, a drag, and a press and hold. None of
    /// it may leave Today in a state where its buttons stop working.
    func testCompanionCanBePlayedWith() {
        let app = launch()
        let mascot = app.buttons["today-mascot"]
        XCTAssertTrue(mascot.exists)
        mascot.tap()
        closeCatChat(app)
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

        // The word card's quiz step: exam-style questions on learned words.
        let quiz = app.buttons["today-quiz"]
        XCTAssertTrue(quiz.waitForExistence(timeout: 5))
        quiz.tap()
        let lastOption = app.buttons["routine-option-3"]
        XCTAssertTrue(lastOption.waitForExistence(timeout: 10))
        sleep(1)
        snap(app, "tour-3-quiz")
        onScreen(lastOption, in: window, "routine-option-3")
        app.buttons["routine-option-0"].tap()
        let next = app.buttons["routine-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "tour-4-quiz-answered")
        onScreen(next, in: window, "routine-next")
        app.buttons["exam-round-close"].tap()

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
        // WordCat Next: in a role-play the key sits in the bottom bar, beside Skip.
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

    /// The chat a tap on the cat opens, closed again.
    private func closeCatChat(_ app: XCUIApplication) {
        // The chat opens on the cat working out its note, so its input may not
        // be there yet: the sheet's Done key says it is open.
        let done = app.buttons.matching(NSPredicate(format: "label IN %@", ["完成", "Done"])).firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5), "A tap on the cat opens its chat\n\(app.debugDescription)")
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5))
    }

    /// Wholly above the row of buttons at the bottom, not tucked under it.
    private func above(_ element: XCUIElement, _ bar: XCUIElement, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertLessThanOrEqual(element.frame.maxY, bar.frame.minY + 1,
                                 "\(name) \(element.frame) is partly under the buttons below (top \(bar.frame.minY))", file: file, line: line)
    }

    /// Fully on the screen, so it can be seen and tapped.
    private func onScreen(_ element: XCUIElement, in window: CGRect, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        guard element.exists else { return XCTFail("\(name) is missing", file: file, line: line) }
        let frame = element.frame
        XCTAssertTrue(window.insetBy(dx: -1, dy: -1).contains(frame), "\(name) runs off the screen: \(frame) in \(window)", file: file, line: line)
        XCTAssertTrue(element.isHittable, "\(name) can't be tapped", file: file, line: line)
    }

    private func checkToday(_ app: XCUIApplication, name: String, tiles: [String], start: String? = "today-start",
                            mascot mascotId: String? = "today-mascot", maxGap: CGFloat = 150,
                            file: StaticString = #filePath, line: UInt = #line) {
        snap(app, name)
        let window = app.windows.firstMatch.frame
        let tabBar = app.tabBars.firstMatch
        let bottom = tabBar.exists ? tabBar.frame.minY : window.maxY
        let ids = (start.map { [$0] } ?? []) + tiles

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

        let mascot = app.buttons[mascotId ?? "-"]
        if mascotId == nil {
            // A page without the strolling companion.
        } else if mascot.exists {
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
        XCTAssertLessThan(gap, maxGap, "\(note): too much empty room at the bottom", file: file, line: line)
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
