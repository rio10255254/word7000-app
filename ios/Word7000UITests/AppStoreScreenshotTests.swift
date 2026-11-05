import XCTest

/// The real screens behind the App Store screenshots (scripts/generate-app-store-screenshots.mjs).
/// `store-zh-*`: the Chinese interface, learning English (Taiwan's App Store).
/// `store-en-*`: the English interface, learning Chinese (other App Stores).
/// Run with ios-native.yml's `store` checks; they land on the native-store-screenshots branch.
final class AppStoreScreenshotTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testStoreChinese() { walk(prefix: "store-zh", chineseMode: false) }

    func testStoreEnglish() { walk(prefix: "store-en", chineseMode: true) }

    private func launch(chineseMode: Bool, _ extra: [String] = [], environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingSampleProgress", "-uiTestingLight", "-uiTestingFakePlans", "-uiTestingPlus"]
            + (chineseMode ? ["-uiTestingChineseMode"] : []) + extra
        app.launchEnvironment = environment
        app.launch()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        sleep(1)
        return app
    }

    private func walk(prefix: String, chineseMode: Bool) {
        // Today, then a card with its answer showing.
        var app = launch(chineseMode: chineseMode)
        snap(app, "\(prefix)-1-today")
        app.buttons["today-start"].tap()
        XCTAssertTrue(app.buttons["study-show-answer"].waitForExistence(timeout: 5))
        app.buttons["study-show-answer"].tap()
        XCTAssertTrue(app.buttons["study-grade-known"].waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "\(prefix)-2-card")
        app.terminate()

        // A quiz answered wrong, with the cat explaining the mix-up.
        app = launch(chineseMode: chineseMode)
        app.openWordsMenu("看字選意思", "Pick the meaning")
        XCTAssertTrue(app.buttons["quiz-start"].waitForExistence(timeout: 5))
        app.buttons["quiz-start"].tap()
        // The page is about getting one wrong: answer until a miss shows the contrast.
        for attempt in 0..<8 {
            XCTAssertTrue(app.buttons["quiz-option-0"].waitForExistence(timeout: 5))
            app.buttons["quiz-option-\(attempt % 2)"].tap()
            XCTAssertTrue(app.buttons["quiz-next"].waitForExistence(timeout: 5))
            if app.descendants(matching: .any)["quiz-contrast"].waitForExistence(timeout: 1) { break }
            app.buttons["quiz-next"].tap()
        }
        sleep(1)
        snap(app, "\(prefix)-3-quiz")
        app.terminate()

        // Speaking, checked by the coach.
        app = launch(chineseMode: chineseMode, ["-uiTestingCoach", chineseMode ? "showcase" : "showcaseEnglish",
                                                "-uiTestingSpeakingWord", chineseMode ? "貼上" : "改善",
                                                "-uiTestingRecording", "-uiTestingToneShowcase"])
        let speaking = app.buttons["today-speaking"]
        speaking.scrollIntoView(in: app, swipes: 4)
        speaking.tap()
        // Each word opens on saying its model sentence first.
        let skip = app.buttons["shadow-skip"]
        if skip.waitForExistence(timeout: 5) {
            sleep(1)
            snap(app, "\(prefix)-4-speaking-shadow")
            // Say it: each word lights up as it is heard (a simulated take),
            // and for Chinese the pitch of each character is drawn under it.
            let record = app.buttons["shadow-record"]
            if record.waitForExistence(timeout: 3) {
                record.tap()
                if app.descendants(matching: .any)["shadow-result"].firstMatch.waitForExistence(timeout: 10) {
                    sleep(1)
                    snap(app, "\(prefix)-4-speaking-shadow-result")
                }
            } else {
                skip.tap()
            }
        }
        // The question follows by itself after a short countdown.
        XCTAssertTrue(app.staticTexts["speaking-question"].waitForExistence(timeout: 12), app.debugDescription)
        sleep(1)
        snap(app, "\(prefix)-4-speaking-question")
        // On to the next turn: the line said before stays above, faded.
        let next = app.buttons["speaking-next"]
        if next.waitForExistence(timeout: 3) {
            next.tap()
            if skip.waitForExistence(timeout: 5) {
                sleep(2)
                snap(app, "\(prefix)-4-speaking-turn2")
            }
        }
        // The coach's sample answer fits a word question, so check it under Words.
        let track = app.segmentedControls["speaking-track"]
        if track.waitForExistence(timeout: 3) {
            track.buttons.element(boundBy: 1).tap()
            if skip.waitForExistence(timeout: 5) { skip.tap() }
            XCTAssertTrue(app.staticTexts["speaking-question"].waitForExistence(timeout: 5), app.debugDescription)
            sleep(1)
        }
        let typeInstead = app.buttons["coach-type-instead"]
        typeInstead.scrollIntoView(in: app, swipes: 4)
        typeInstead.tap()
        let answer = app.textViews["coach-answer"]
        XCTAssertTrue(answer.waitForExistence(timeout: 5))
        if !app.keyboards.firstMatch.waitForExistence(timeout: 2) { answer.tap() }
        sleep(1)
        answer.typeText("x")
        let check = app.buttons["coach-submit"]
        XCTAssertTrue(check.waitForExistence(timeout: 5))
        check.tap()
        XCTAssertTrue(app.staticTexts["coach-rewrite"].waitForExistence(timeout: 10), app.debugDescription)
        sleep(2)
        snap(app, "\(prefix)-5-coach")
        app.swipeUp()
        sleep(1)
        snap(app, "\(prefix)-5-coach-more")
        app.terminate()

        // The scenario map: ten everyday scenes, two stages each.
        app = launch(chineseMode: chineseMode)
        let practice = app.buttons["today-speaking"]
        practice.scrollIntoView(in: app, swipes: 4)
        practice.tap()
        let map = app.buttons["speaking-scenarios"]
        if map.waitForExistence(timeout: 5) {
            map.tap()
            sleep(2)
            snap(app, "\(prefix)-4-speaking-map")
        }
        app.terminate()

        // The cat's chat.
        app = launch(chineseMode: chineseMode, ["-uiTestingCatShowcase"])
        XCTAssertTrue(app.descendants(matching: .any)["mascot-chat-input"].waitForExistence(timeout: 10))
        sleep(1)
        snap(app, "\(prefix)-7-cat")
        app.terminate()

        // Scanning a printed list into a word bank.
        let sheet = chineseMode
            ? "hospital n. 醫院\npharmacy n. 藥局\nfever n. 發燒\nregister v. 掛號"
            : "objectively adv. 客觀地\nobjective n. 目標\ncarefully adv. 小心地\nconsiderable adj. 相當大的"
        app = launch(chineseMode: chineseMode, ["-uiTestingScanText"], environment: ["WORD7000_SCAN_TEST_TEXT": sheet])
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.buttons["words-scan"].waitForExistence(timeout: 5))
        app.buttons["words-scan"].tap()
        let read = app.buttons["scan-read-pasted"]
        XCTAssertTrue(read.waitForExistence(timeout: 5))
        read.scrollIntoView(in: app, swipes: 5)
        read.tap()
        XCTAssertTrue(app.buttons["scan-save"].waitForExistence(timeout: 10))
        sleep(1)
        snap(app, "\(prefix)-6-scan")
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
        }
    }
}
