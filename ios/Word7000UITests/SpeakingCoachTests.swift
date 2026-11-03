import XCTest
import UIKit

/// Mock responses exercise the interface, not the quality of an on-device model.
final class SpeakingCoachTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    override func tearDown() {
        if (testRun?.failureCount ?? 0) > 0 {
            let app = XCUIApplication()
            if app.state == .runningForeground {
                let identifier = name.components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { !$0.isEmpty }.joined(separator: "-")
                snapshot(app, "studio-failure-" + identifier)
            }
        }
        super.tearDown()
    }

    func testSkipAndSampleWithoutAnswering() {
        let app = launch()
        XCTAssertFalse(app.launchArguments.contains("-uiTestingCoach"))
        openSpeaking(app)
        let question = app.staticTexts["speaking-question"].label
        XCTAssertFalse(question.isEmpty)
        let completed = completionValue(app)
        XCTAssertTrue(app.buttons["coach-record"].exists, "Recording is right under the question")
        XCTAssertTrue(app.buttons["speaking-show-reference"].isEnabled)

        app.buttons["speaking-show-reference"].tap()
        let reference = app.staticTexts["speaking-reference-answer"]
        reveal(reference, in: app)
        XCTAssertFalse(reference.label.isEmpty)
        XCTAssertEqual(app.staticTexts["speaking-question"].label, question)
        snapshot(app, "coach-real-no-override-reference")
        // Nothing said or written: Next is a skip and does not count.
        tap(app.buttons["speaking-next"], in: app)
        wait(app.staticTexts["speaking-position"], matching: "label BEGINSWITH '2 /'")
        XCTAssertEqual(completionValue(app), completed)
    }

    func testMockSuccessTypingCheckAndProgressInLightEnglishUI() {
        let app = launch(coach: "commitCorrection", englishUI: true)
        let completedBefore = weeklySpeakingCount(app)
        app.tabBars.buttons.element(boundBy: 0).tap()
        openSpeaking(app)
        let question = app.staticTexts["speaking-question"].label
        XCTAssertFalse(app.buttons["coach-submit"].exists, "Nothing to check before an answer")

        tap(app.buttons["coach-type-instead"], in: app)
        let answer = app.textViews["coach-answer"]
        XCTAssertTrue(answer.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Type instead puts the cursor on the notepad")
        answer.typeText("I practice with my x")
        answer.typeText(XCUIKeyboardKey.delete.rawValue)
        answer.typeText("freind")
        XCTAssertTrue(app.keyboards.firstMatch.exists, "Editing must not recreate the editor or dismiss its keyboard")
        assertNoFeedback(app)
        snapshot(app, "coach-mock-light-en-keyboard")
        // Leave the final word pending: the Check key must commit keyboard edits itself.
        let check = app.buttons["coach-submit"]
        XCTAssertTrue(check.waitForExistence(timeout: 5))
        XCTAssertTrue(check.isEnabled)
        XCTAssertTrue(check.isHittable, "Check stays reachable above the keyboard")
        let pendingAnswer = answer.value as? String ?? ""
        check.tap()
        wait(app.keyboards.firstMatch, matching: "exists == false")
        XCTAssertTrue(app.staticTexts["coach-rewrite"].waitForExistence(timeout: 5))
        reveal(answer, in: app)
        let finalAnswer = answer.value as? String ?? ""
        XCTAssertEqual(finalAnswer, "I practice with my friend every day.")
        XCTAssertNotEqual(finalAnswer, pendingAnswer, "Ending native editing must really change the submitted text")
        assertFeedback(app, snapshotPrefix: "coach-mock-light-en")
        let tip = app.staticTexts["coach-tip"]
        reveal(tip, in: app, scrollingUp: false)
        XCTAssertEqual(tip.label, "Received: " + finalAnswer.trimmingCharacters(in: .whitespacesAndNewlines))
        XCTAssertFalse(app.descendants(matching: .any)["coach-error"].firstMatch.exists)
        XCTAssertEqual(app.staticTexts["speaking-question"].label, question)

        // Something was written: Next counts the question.
        tap(app.buttons["speaking-next"], in: app)
        wait(app.staticTexts["speaking-position"], matching: "label BEGINSWITH '2 /'")
        XCTAssertNotEqual(app.staticTexts["speaking-question"].label, question)
        XCTAssertFalse(app.textViews["coach-answer"].exists, "A new question starts without an answer")
        assertNoFeedback(app)
        app.buttons["speaking-close"].tap()
        XCTAssertNotEqual(weeklySpeakingCount(app), completedBefore, "An answered question counts as practice")
    }

    func testMockRetryDarkEnglishAndCancellationRecovery() {
        let app = launch(coach: "errorOnce", dark: true, englishUI: true)
        openSpeaking(app)
        enterAnswer("I practice daily.", in: app)
        submit(app)
        let error = app.descendants(matching: .any)["coach-error"].firstMatch
        reveal(error, in: app)
        XCTAssertEqual(error.label, "No suitable suggestions were produced. Edit your answer or try again.")
        assertNoFeedback(app)
        XCTAssertEqual(app.textViews["coach-answer"].value as? String, "I practice daily.")
        submit(app)
        assertFeedback(app, snapshotPrefix: "coach-mock-dark-en-retry")
        XCTAssertFalse(error.exists)
        app.terminate()

        // Core tests cover uncooperative late replies and overlapping requests.
        // Here only check the short UI cancellation and timeout recovery paths.
        for mode in ["slow", "timeout"] {
            let recovery = launch(coach: mode)
            openSpeaking(recovery)
            enterAnswer("I practice daily.", in: recovery)
            submit(recovery)
            if mode == "slow" {
                let cancel = recovery.buttons["coach-cancel"]
                XCTAssertTrue(cancel.waitForExistence(timeout: 3))
                cancel.tap()
            } else {
                let timeout = recovery.descendants(matching: .any)["coach-error"].firstMatch
                reveal(timeout, in: recovery)
                // Check the timeout, not just any failure (default Chinese interface).
                XCTAssertTrue(timeout.label.contains("\u{7B49}\u{5019}\u{592A}\u{4E45}"))
            }
            wait(recovery.buttons["coach-submit"], matching: "exists == true AND enabled == true")
            XCTAssertFalse(recovery.buttons["coach-cancel"].exists)
            assertNoFeedback(recovery)
            if mode == "slow" {
                XCTAssertFalse(recovery.descendants(matching: .any)["coach-error"].firstMatch.exists)
            }
            XCTAssertEqual(recovery.textViews["coach-answer"].value as? String, "I practice daily.")
            recovery.terminate()
        }
    }

    func testWithoutDeviceAICheckingLeadsToPremiumAndPracticeContinues() {
        let app = launch(coach: "unavailable")
        openSpeaking(app)
        let completed = completionValue(app)
        enterAnswer("I practice daily.", in: app)
        dismissKeyboard(app)
        // Without the on-device AI, checking leads straight to Premium,
        // and still says the free way is to turn Apple Intelligence on.
        let premium = app.buttons["coach-premium-check"]
        reveal(premium, in: app)
        XCTAssertTrue(app.staticTexts["coach-premium-note"].label.contains("Apple Intelligence"))
        XCTAssertFalse(app.buttons["coach-submit"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["coach-unavailable"].firstMatch.exists)
        assertNoFeedback(app)
        snapshot(app, "coach-mock-light-zh-premium")
        tap(premium, in: app)
        let close = app.buttons["paywall-close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "Check leads to the paywall")
        close.tap()
        XCTAssertTrue(premium.waitForExistence(timeout: 5))
        assertNoFeedback(app)
        tap(app.buttons["speaking-next"], in: app)
        wait(app.staticTexts["speaking-position"], matching: "label BEGINSWITH '2 /'")
        XCTAssertNotEqual(completionValue(app), completed, "A written answer counts without AI")
    }

    private func launch(coach: String? = nil, dark: Bool = false, englishUI: Bool = false, recording: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", dark ? "-uiTestingDark" : "-uiTestingLight",
                               "-uiTestingSampleProgress", "-uiTestingFakePlans"]
        if let coach { app.launchArguments += ["-uiTestingCoach", coach] }
        if recording { app.launchArguments.append("-uiTestingRecording") }
        if englishUI { app.launchArguments.append("-uiTestingChineseMode") }
        app.launch()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        return app
    }

    func testFollowUpCanBeAnsweredThenLeftForTheOriginalQuestion() {
        let app = launch(coach: "success", englishUI: true)
        openSpeaking(app)
        let question = app.staticTexts["speaking-question"].label
        enterAnswer("I practice daily.", in: app)
        submit(app)
        let followUp = app.staticTexts["coach-follow-up"]
        reveal(followUp, in: app, scrollingUp: false)
        let followUpText = followUp.label
        XCTAssertFalse(followUpText.isEmpty)
        XCTAssertTrue(app.staticTexts["coach-follow-up-translation"].exists, "The follow-up comes translated")
        tap(app.buttons["coach-answer-follow-up"], in: app)
        let shown = app.staticTexts["coach-question"]
        reveal(shown, in: app)
        XCTAssertEqual(shown.label, followUpText)
        XCTAssertFalse(app.textViews["coach-answer"].exists, "A follow-up starts a new answer")
        assertNoFeedback(app)
        XCTAssertFalse(app.buttons["coach-submit"].exists)
        snapshot(app, "coach-follow-up-question")
        tap(app.buttons["coach-original-question"], in: app)
        XCTAssertFalse(app.staticTexts["coach-question"].exists)
        XCTAssertEqual(app.staticTexts["speaking-question"].label, question)
    }

    func testRecordingTurnsIntoTextThenChecksWithExplicitFixture() {
        let app = launch(coach: "success", englishUI: true, recording: true)
        openSpeaking(app)
        tap(app.buttons["coach-record"], in: app)
        app.buttons["coach-record"].tap()
        let playback = app.buttons["coach-play-recording"]
        tap(playback, in: app)
        XCTAssertTrue(playback.label.contains("Stop"))
        playback.tap()
        let answer = app.textViews["coach-answer"]
        reveal(answer, in: app)
        XCTAssertEqual(answer.value as? String, "I practice with my friend every day.",
                       "Stopping a take turns it into text without another tap")
        XCTAssertFalse(app.buttons["coach-transcribe"].exists, "A transcribed take needs no second transcription")
        XCTAssertFalse(app.staticTexts["coach-rewrite"].exists, "Checking waits for the learner")
        // Checking is one tap, and confirms the transcript.
        tap(app.buttons["coach-submit"], in: app)
        XCTAssertTrue(app.staticTexts["coach-rewrite"].waitForExistence(timeout: 5))
        snapshot(app, "studio-confirmed-transcript")
        tap(app.buttons["speaking-next"], in: app)
        wait(app.staticTexts["speaking-position"], matching: "label BEGINSWITH '2 /'")
        XCTAssertFalse(app.buttons["coach-play-recording"].exists, "A new question starts without the old take")
    }

    func testNativeRecorderPermissionTimerPlaybackAndCleanup() {
        let app = launch(englishUI: true)
        openSpeaking(app)
        tap(app.buttons["coach-record"], in: app)
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = system.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) {
            // A system sheet can still be animating when its button appears in
            // accessibility. Only retry that permission tap, never the recording.
            for _ in 0..<2 where allow.exists {
                wait(allow, matching: "exists == true AND hittable == true")
                allow.tap()
                let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: allow)
                if XCTWaiter.wait(for: [dismissed], timeout: 5) == .completed { break }
            }
            XCTAssertFalse(allow.exists)
        } else if system.buttons["OK"].exists { system.buttons["OK"].tap() }
        let duration = app.staticTexts["coach-recording-duration"]
        let ticking = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let number = Int(duration.label.split(separator: " ").first ?? "0") ?? 0
            return number >= 1
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ticking], timeout: 10), .completed)
        app.buttons["coach-record"].tap()
        XCTAssertTrue(app.buttons["coach-play-recording"].waitForExistence(timeout: 5))
        snapshot(app, "studio-native-recording")
        tap(app.buttons["speaking-show-reference"], in: app)
        tap(app.buttons["coach-play-recording"], in: app)
        tap(app.buttons["speaking-next"], in: app)
        wait(app.staticTexts["speaking-position"], matching: "label BEGINSWITH '2 /'")
        XCTAssertFalse(app.buttons["coach-play-recording"].exists)
    }

    func testAISettingsDisableSuggestionsButKeepRecordingAndText() {
        let app = launch(coach: "success", englishUI: true)
        app.tabBars.buttons.element(boundBy: 2).tap()
        tap(app.buttons["me-settings"], in: app)
        tap(app.buttons["settings-intelligence"], in: app)
        let toggle = app.switches["settings-ai-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let control = toggle.switches.firstMatch
        if control.exists { control.tap() } else { toggle.tap() }
        wait(toggle, matching: "value == '0'")
        snapshot(app, "studio-ai-disabled-settings")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons.element(boundBy: 0).tap()
        openSpeaking(app)
        XCTAssertTrue(app.buttons["coach-record"].isEnabled)
        enterAnswer("I practice daily.", in: app)
        dismissKeyboard(app)
        XCTAssertFalse(app.buttons["coach-submit"].exists)
        reveal(app.buttons["coach-retake"], in: app)
        XCTAssertTrue(app.buttons["coach-retake"].isEnabled)
    }

    func testEditorialNotesAreReachableInBothLanguages() {
        for englishUI in [false, true] {
            let app = launch(dark: englishUI, englishUI: englishUI)
            app.tabBars.buttons.element(boundBy: 1).tap()
            let search = app.searchFields.firstMatch
            XCTAssertTrue(search.waitForExistence(timeout: 5))
            search.tap()
            // Learners of Chinese study the Taiwan Mandarin bank and can search
            // it by pinyin; learners of English get the editorial note.
            search.typeText(englishUI ? "jianyi" : "advice")
            let word = app.staticTexts[englishUI ? "建議" : "advice"].firstMatch
            XCTAssertTrue(word.waitForExistence(timeout: 5))
            word.tap()
            if englishUI {
                let example = app.staticTexts["我建議你早點出門。"].firstMatch
                reveal(example, in: app)
                XCTAssertTrue(example.exists)
            } else {
                reveal(app.staticTexts["advice / advise"], in: app)
                let explanation = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "advice 是不可數名詞")).firstMatch
                reveal(explanation, in: app)
            }
            snapshot(app, englishUI ? "editorial-dark-en" : "editorial-light-zh")
            app.terminate()
        }
    }

    private func openSpeaking(_ app: XCUIApplication) {
        tap(app.buttons["today-speaking"], in: app)
        XCTAssertTrue(app.staticTexts["speaking-question"].waitForExistence(timeout: 5))
    }

    private func enterAnswer(_ text: String, in app: XCUIApplication) {
        let answer = app.textViews["coach-answer"]
        if !answer.exists { tap(app.buttons["coach-type-instead"], in: app) }
        XCTAssertTrue(answer.waitForExistence(timeout: 5))
        if !app.keyboards.firstMatch.waitForExistence(timeout: 2) { answer.tap() }
        answer.typeText(text)
        // The accessibility value can lag the final keyboard event on older
        // simulators. Keep the exact-text assertion; never retry the keystroke.
        let committed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", text), object: answer)
        XCTAssertEqual(XCTWaiter.wait(for: [committed], timeout: 5), .completed)
        XCTAssertEqual(answer.value as? String, text)
    }

    private func dismissKeyboard(_ app: XCUIApplication) {
        guard app.keyboards.firstMatch.exists else { return }
        app.buttons["coach-keyboard-done"].tap()
        wait(app.keyboards.firstMatch, matching: "exists == false")
    }

    private func submit(_ app: XCUIApplication) {
        let submit = app.buttons["coach-submit"]
        wait(submit, matching: "exists == true AND enabled == true")
        tap(submit, in: app)
    }

    private func assertFeedback(_ app: XCUIApplication, snapshotPrefix: String) {
        for (index, identifier) in ["coach-rewrite", "coach-tip", "coach-follow-up"].enumerated() {
            let field = app.staticTexts[identifier]
            reveal(field, in: app, scrollingUp: true)
            XCTAssertFalse(field.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if index == 0 { snapshot(app, snapshotPrefix + "-rewrite") }
        }
        snapshot(app, snapshotPrefix + "-tip-follow-up")
        XCTAssertTrue(app.buttons["speaking-next"].isHittable)
    }

    private func assertNoFeedback(_ app: XCUIApplication) {
        for identifier in ["coach-rewrite", "coach-tip", "coach-follow-up"] {
            XCTAssertFalse(app.staticTexts[identifier].exists, identifier)
        }
    }

    private func completionValue(_ app: XCUIApplication) -> String {
        let value = app.staticTexts["speaking-position"].value as? String ?? ""
        XCTAssertFalse(value.isEmpty, "The speaking progress must expose its completed count")
        return value
    }

    private func weeklySpeakingCount(_ app: XCUIApplication) -> String {
        app.tabBars.buttons.element(boundBy: 2).tap()
        let count = app.descendants(matching: .any)["me-week-speaking"].firstMatch
        reveal(count, in: app)
        XCTAssertFalse(count.label.isEmpty)
        return count.label
    }

    private func wait(_ element: XCUIElement, matching predicate: String,
                      file: StaticString = #filePath, line: UInt = #line) {
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 5), .completed, predicate, file: file, line: line)
    }

    /// Scrolls the page until the element can be tapped and is clear of the
    /// keys pinned at the bottom.
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, scrollingUp: Bool = true,
                        file: StaticString = #filePath, line: UInt = #line) {
        _ = element.waitForExistence(timeout: 1)
        for _ in 0..<5 where !element.isHittable || underBottomKeys(element, in: app) {
            scroll(app, up: scrollingUp)
        }
        for _ in 0..<6 where !element.isHittable || underBottomKeys(element, in: app) {
            scroll(app, up: !scrollingUp)
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(element.isHittable, "Control must remain reachable on small screens", file: file, line: line)
    }

    private func underBottomKeys(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        let keys = ["speaking-next", "speaking-show-reference"]
        guard element.exists, !keys.contains(element.identifier) else { return false }
        let next = app.buttons["speaking-next"]
        guard next.exists else { return false }
        return element.frame.maxY > next.frame.minY - 8
    }

    /// Swipes just inside the page's left edge: within the scroll view (the
    /// window's margin outside it does not scroll), clear of the notepad,
    /// which scrolls itself.
    private func scroll(_ app: XCUIApplication, up: Bool) {
        let window = app.windows.firstMatch
        let page = app.scrollViews.firstMatch
        let frame = page.exists ? page.frame : window.frame
        let origin = window.coordinate(withNormalizedOffset: .zero)
        let x = frame.minX + 6
        let upper = origin.withOffset(CGVector(dx: x, dy: frame.minY + frame.height * 0.2))
        let lower = origin.withOffset(CGVector(dx: x, dy: frame.minY + frame.height * 0.8))
        (up ? lower : upper).press(forDuration: 0.01, thenDragTo: up ? upper : lower)
    }

    private func tap(_ element: XCUIElement, in app: XCUIApplication,
                     file: StaticString = #filePath, line: UInt = #line) {
        reveal(element, in: app, file: file, line: line)
        element.tap()
    }

    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let screenshot = app.screenshot()
        let size = "\(Int(app.frame.width))x\(Int(app.frame.height))"
        let filename = name + "-" + size
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = filename
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] else { return }
        let directory = URL(fileURLWithPath: home).appendingPathComponent("word7000-screenshots")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try screenshot.pngRepresentation.write(to: directory.appendingPathComponent(filename + ".png"))
            try app.debugDescription.write(to: directory.appendingPathComponent(filename + "-hierarchy.txt"),
                                           atomically: true, encoding: .utf8)
        } catch {
            XCTFail("Could not save coach screenshot: \(error)")
        }
    }
}
