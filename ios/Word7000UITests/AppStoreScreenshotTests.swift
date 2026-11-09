import XCTest

/// The real screens behind the App Store screenshots (scripts/generate-app-store-screenshots.mjs).
/// `store-zh-*`: the Chinese interface, learning English (Taiwan's App Store).
/// `store-en-*`: the English interface, learning Chinese (other App Stores).
/// Run with ios-native.yml's `store` checks; they land on the native-store-screenshots branch.
final class AppStoreScreenshotTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testStoreChinese() { walk(prefix: "store-zh", chineseMode: false) }

    func testStoreEnglish() { walk(prefix: "store-en", chineseMode: true) }

    /// WordCat Next's own screens: the daily path (cards, then writing, then
    /// exam-style questions, then the summary), the plan, a speaking stage
    /// (listen, repeat, answer, the map) and the day's stamp. `store-*-n*`.
    func testStoreNextChinese() { walkNext(prefix: "store-zh", chineseMode: false) }

    func testStoreNextEnglish() { walkNext(prefix: "store-en", chineseMode: true) }

    private static let nextFlags = ["-uiTestingRoutine", "-uiTestingSpeakingRoutine", "-uiTestingDayComplete"]

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
        app.openPractice("practice-meaning")
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
                // A take with a tone slip stays and listens again until it is
                // right; Next moves on (it waits while a take is under way).
                let next = app.buttons["shadow-next"]
                for _ in 0..<8 where !app.staticTexts["speaking-question"].exists {
                    // Next can go between asking and tapping, as the question
                    // comes up by itself: read it once and tap where it was.
                    if let shown = try? next.snapshot(), shown.isEnabled, !shown.frame.isEmpty {
                        let origin = app.coordinate(withNormalizedOffset: .zero)
                        origin.withOffset(CGVector(dx: shown.frame.midX, dy: shown.frame.midY)).tap()
                    }
                    sleep(1)
                }
            } else {
                skip.tap()
            }
        }
        // The question follows by itself after a short countdown once all of
        // the sentence was right; a take with a tone off waits for Next.
        if !app.staticTexts["speaking-question"].waitForExistence(timeout: 8),
           let shown = try? app.buttons["shadow-next"].snapshot(), !shown.frame.isEmpty {
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: shown.frame.midX, dy: shown.frame.midY)).tap()
        }
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
        let track = app.buttons["speaking-track-0"]
        if track.waitForExistence(timeout: 3) {
            app.buttons["speaking-track-1"].tap()
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
        // Check sits under the answer while typing; on a shorter screen the
        // chat may need a nudge to bring it up.
        let check = app.buttons["coach-submit"]
        // A Zhuyin keyboard (the Chinese interface on some simulators) holds
        // the letter as input still being composed; Return puts it in the answer.
        if !check.waitForExistence(timeout: 3) { answer.typeText("\n") }
        if !check.waitForExistence(timeout: 5) { check.scrollIntoView(in: app, swipes: 3) }
        XCTAssertTrue(check.waitForExistence(timeout: 5), app.debugDescription)
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
        app.tabBars.buttons.matching(NSPredicate(format: "label IN %@", ["單字", "Words"])).firstMatch.tap()
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

    private func walkNext(prefix: String, chineseMode: Bool) {
        // Today, on the path.
        var app = launch(chineseMode: chineseMode, Self.nextFlags)
        snap(app, "\(prefix)-n1-today")

        // The cards, then the checks that follow them.
        app.buttons["today-start"].tap()
        let handOff = app.descendants(matching: .any)["routine-hand-off"]
        let summary = app.descendants(matching: .any)["routine-summary"]
        var flipped = 0
        while !handOff.exists, !summary.exists, flipped < 40 {
            let show = app.buttons["study-show-answer"]
            guard show.waitForExistence(timeout: 5) else { break }
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: show)
            _ = XCTWaiter.wait(for: [ready], timeout: 10)
            show.tap()
            let known = app.buttons["study-grade-known"]
            guard known.waitForExistence(timeout: 5) else { break }
            if flipped == 0 {
                sleep(1)
                snap(app, "\(prefix)-n2-card")
            }
            known.tap()
            flipped += 1
            _ = handOff.waitForExistence(timeout: 1)
        }
        if handOff.waitForExistence(timeout: 10) { app.buttons["routine-begin"].tap() }
        // Writing: the word from its sentence.
        let input = app.textFields["routine-input"]
        var wrote = 0
        while input.waitForExistence(timeout: 6), wrote < 12 {
            let answer = app.staticTexts["cloze-sentence"].value as? String ?? ""
            if wrote == 0 {
                sleep(1)
                snap(app, "\(prefix)-n3-write")
            }
            input.tap()
            input.typeText(answer + "\n")
            let next = app.buttons["routine-next"]
            guard next.waitForExistence(timeout: 5) else { break }
            if wrote == 0 {
                sleep(1)
                snap(app, "\(prefix)-n3-write-solved")
            }
            next.tap()
            wrote += 1
            if handOff.waitForExistence(timeout: 2) || summary.exists { break }
        }
        // Questions in the style of the learner's exam.
        if app.buttons["routine-begin"].waitForExistence(timeout: 3) { app.buttons["routine-begin"].tap() }
        var asked = 0
        while app.buttons["routine-option-0"].waitForExistence(timeout: 8), asked < 12 {
            if asked == 0 {
                sleep(1)
                snap(app, "\(prefix)-n4-exam")
            }
            app.buttons["routine-option-0"].tap()
            let next = app.buttons["routine-next"]
            guard next.waitForExistence(timeout: 5) else { break }
            if asked == 0 {
                sleep(1)
                snap(app, "\(prefix)-n4-exam-answered")
            }
            next.tap()
            asked += 1
            if summary.waitForExistence(timeout: 2) { break }
        }
        if summary.waitForExistence(timeout: 10) {
            sleep(2)
            snap(app, "\(prefix)-n5-summary")
        }
        app.terminate()

        // The plan: the pace to the exam (會考 for learners of English).
        app = launch(chineseMode: chineseMode, Self.nextFlags)
        app.tabBars.buttons.matching(NSPredicate(format: "label IN %@", ["我", "Me"])).firstMatch.tap()
        let settings = app.buttons["me-settings"]
        settings.scrollIntoView(in: app, swipes: 5)
        if settings.waitForExistence(timeout: 5) {
            settings.tap()
            let plan = app.buttons["settings-plan"]
            if plan.waitForExistence(timeout: 5) {
                plan.tap()
                let exam = app.buttons["plan-exam-2"]
                if !chineseMode, exam.waitForExistence(timeout: 3) {
                    exam.scrollIntoView(in: app, swipes: 3)
                    exam.tap()
                    for _ in 0..<4 { app.swipeDown() }
                }
                if app.descendants(matching: .any)["plan-card"].firstMatch.waitForExistence(timeout: 5) {
                    sleep(2)
                    snap(app, "\(prefix)-n6-plan")
                }
            }
        }
        app.terminate()

        // A speaking stage: listen, say the reply, answer; then the map.
        app = launch(chineseMode: chineseMode, Self.nextFlags + ["-uiTestingRecording", "-uiTestingToneShowcase"])
        let speaking = app.buttons["today-speaking"]
        speaking.scrollIntoView(in: app, swipes: 4)
        if speaking.waitForExistence(timeout: 5) {
            speaking.tap()
            let done = app.buttons["speaking-listen-done"]
            if done.waitForExistence(timeout: 10) {
                sleep(2)
                snap(app, "\(prefix)-n7-listen")
                done.tap()
            }
            let record = app.buttons["shadow-record"]
            if record.waitForExistence(timeout: 10) {
                record.tap()
                if app.descendants(matching: .any)["shadow-result"].firstMatch.waitForExistence(timeout: 10) {
                    sleep(1)
                    snap(app, "\(prefix)-n8-shadow")
                }
            }
            if app.staticTexts["speaking-question"].waitForExistence(timeout: 12) {
                sleep(1)
                snap(app, "\(prefix)-n9-answer")
            }
            let map = app.buttons["speaking-scenarios"]
            if map.waitForExistence(timeout: 5) {
                map.tap()
                sleep(2)
                snap(app, "\(prefix)-n10-map")
            }
        }
        app.terminate()

        // The day's stamp, then the weeks on Me.
        app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingSampleProgress", "-uiTestingLight", "-uiTestingFakePlans", "-uiTestingPlus",
                               "-uiTestingDayCompleteNow"] + (chineseMode ? ["-uiTestingChineseMode"] : []) + Self.nextFlags
        app.launch()
        let keep = app.buttons["day-complete-keep"]
        if keep.waitForExistence(timeout: 10) {
            sleep(3)
            snap(app, "\(prefix)-n11-stamp")
            keep.tap()
            if app.buttons["today-start"].waitForExistence(timeout: 10) {
                app.tabBars.buttons.matching(NSPredicate(format: "label IN %@", ["我", "Me"])).firstMatch.tap()
                if app.descendants(matching: .any)["me-calendar"].firstMatch.waitForExistence(timeout: 5) {
                    sleep(1)
                    snap(app, "\(prefix)-n12-me")
                }
            }
        }
    }

    /// The cat alone in each mood, on black and on white, still: the store
    /// art cuts it out from the pair (scripts/generate-app-store-screenshots.mjs).
    func testStoreMascots() {
        for mood in ["happy", "cheer", "smug", "cheeky", "encourage"] {
            for background in ["black", "white"] {
                let app = XCUIApplication()
                app.launchArguments = ["-uiTestingMascotPoster", "\(mood):\(background)"]
                app.launch()
                XCTAssertTrue(app.descendants(matching: .any)["mascot-poster"].firstMatch.waitForExistence(timeout: 10))
                sleep(2)
                snap(app, "store-cat-\(mood)-\(background)")
                app.terminate()
            }
        }
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
