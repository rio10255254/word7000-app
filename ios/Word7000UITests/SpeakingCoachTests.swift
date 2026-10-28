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

    func testOriginalPracticeWithoutCoachOverride() {
        let app = launch()
        XCTAssertFalse(app.launchArguments.contains("-uiTestingCoach"))
        openSpeaking(app)
        let question = app.staticTexts["speaking-question"].label
        XCTAssertFalse(question.isEmpty)
        XCTAssertTrue(app.buttons["speaking-show-reference"].isEnabled)
        XCTAssertTrue(app.buttons["speaking-complete"].isEnabled)
        XCTAssertTrue(app.buttons["speaking-coach-open"].exists, "Recording and reflection remain available without AI")

        app.buttons["speaking-show-reference"].tap()
        let reference = app.staticTexts["speaking-reference-answer"]
        reveal(reference, in: app)
        XCTAssertFalse(reference.label.isEmpty)
        XCTAssertEqual(app.staticTexts["speaking-question"].label, question)
        snapshot(app, "coach-real-no-override-reference")
        tap(app.buttons["speaking-complete-after-reference"], in: app)
        wait(app.staticTexts["speaking-position"], matching: "label BEGINSWITH '2 /'")

        // Exercise the original direct completion path as well as reference-first.
        tap(app.buttons["speaking-complete"], in: app)
        XCTAssertTrue(app.buttons["speaking-next"].waitForExistence(timeout: 5))
        app.buttons["speaking-next"].tap()
        wait(app.staticTexts["speaking-position"], matching: "label BEGINSWITH '3 /'")
    }

    func testMockSuccessEditingDraftAndProgressInLightEnglishUI() {
        let app = launch(coach: "commitCorrection", englishUI: true)
        let completedBefore = weeklySpeakingCount(app)
        app.tabBars.buttons.element(boundBy: 0).tap()
        openSpeaking(app)
        XCTAssertTrue(app.segmentedControls["speaking-activity"].buttons["Questions"].isSelected)
        let question = app.staticTexts["speaking-question"].label
        let position = app.staticTexts["speaking-position"].label
        let completed = completionValue(app)
        XCTAssertEqual(openCoach(app), question)
        XCTAssertTrue(app.navigationBars["Speaking coach"].exists)
        XCTAssertFalse(app.buttons["coach-submit"].isEnabled)

        let answer = app.textViews["coach-answer"]
        answer.tap()
        answer.typeText("I practice with my x")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        answer.typeText(XCUIKeyboardKey.delete.rawValue)
        answer.typeText("freind")
        XCTAssertTrue(app.keyboards.firstMatch.exists, "Editing must not recreate the editor or dismiss its keyboard")
        assertNoFeedback(app)
        snapshot(app, "coach-mock-light-en-keyboard")
        // Leave the final word pending: the CTA must commit keyboard edits itself.
        let submitButton = app.buttons["coach-submit"]
        XCTAssertTrue(submitButton.isEnabled)
        XCTAssertTrue(submitButton.isHittable)
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        let pendingAnswer = answer.value as? String ?? ""
        submitButton.tap()
        wait(app.keyboards.firstMatch, matching: "exists == false")
        // The form scrolls to the suggestions when they arrive; come back to the answer.
        XCTAssertTrue(app.staticTexts["coach-rewrite"].waitForExistence(timeout: 5))
        reveal(answer, in: app)
        let finalAnswer = answer.value as? String ?? ""
        XCTAssertEqual(finalAnswer, "I practice with my friend every day.")
        XCTAssertNotEqual(finalAnswer, pendingAnswer, "Ending native editing must really change the submitted text")
        XCTAssertFalse(finalAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        assertFeedback(app, snapshotPrefix: "coach-mock-light-en")
        let tip = app.staticTexts["coach-tip"]
        reveal(tip, in: app, scrollingUp: false)
        XCTAssertEqual(tip.label, "Received: " + finalAnswer.trimmingCharacters(in: .whitespacesAndNewlines))
        XCTAssertFalse(app.descendants(matching: .any)["coach-error"].firstMatch.exists)
        wait(submitButton, matching: "exists == true AND enabled == true")

        closeCoach(app)
        XCTAssertEqual(app.staticTexts["speaking-question"].label, question)
        XCTAssertEqual(app.staticTexts["speaking-position"].label, position)
        XCTAssertEqual(completionValue(app), completed)
        XCTAssertTrue(app.buttons["speaking-complete"].isEnabled)
        XCTAssertEqual(openCoach(app), question)
        XCTAssertEqual(app.textViews["coach-answer"].value as? String, finalAnswer)
        closeCoach(app)

        app.buttons["speaking-show-reference"].tap()
        tap(app.buttons["speaking-next"], in: app)
        wait(app.staticTexts["speaking-position"], matching: "label BEGINSWITH '2 /'")
        let nextQuestion = app.staticTexts["speaking-question"].label
        XCTAssertNotEqual(nextQuestion, question)
        XCTAssertEqual(completionValue(app), completed)
        XCTAssertEqual(openCoach(app), nextQuestion)
        XCTAssertEqual(app.textViews["coach-answer"].value as? String, "")
        XCTAssertFalse(app.buttons["coach-submit"].isEnabled)
        assertNoFeedback(app)
        closeCoach(app)
        app.buttons["speaking-close"].tap()
        XCTAssertEqual(weeklySpeakingCount(app), completedBefore,
                       "Coach suggestions and skipping a question must not count as completed practice")
    }

    func testMockRetryDarkEnglishAndCancellationRecovery() {
        let app = launch(coach: "errorOnce", dark: true, englishUI: true)
        openSpeaking(app)
        openCoach(app)
        XCTAssertTrue(app.navigationBars["Speaking coach"].exists)
        enterAnswer("I practice daily.", in: app)
        submit(app)
        let error = app.descendants(matching: .any)["coach-error"].firstMatch
        reveal(error, in: app)
        XCTAssertEqual(error.label, "No suitable suggestions were produced. Edit your answer or try again.")
        assertNoFeedback(app)
        reveal(app.textViews["coach-answer"], in: app, scrollingUp: false)
        XCTAssertEqual(app.textViews["coach-answer"].value as? String, "I practice daily.")
        submit(app)
        assertFeedback(app, snapshotPrefix: "coach-mock-dark-en-retry")
        reveal(app.textViews["coach-answer"], in: app, scrollingUp: false)
        XCTAssertFalse(error.exists)
        app.terminate()

        // Core tests cover uncooperative late replies and overlapping requests.
        // Here only check the short UI cancellation and timeout recovery paths.
        for mode in ["slow", "timeout"] {
            let recovery = launch(coach: mode)
            openSpeaking(recovery)
            openCoach(recovery)
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
            reveal(recovery.textViews["coach-answer"], in: recovery, scrollingUp: false)
            XCTAssertEqual(recovery.textViews["coach-answer"].value as? String, "I practice daily.")
            closeCoach(recovery)
            XCTAssertTrue(recovery.buttons["speaking-complete"].isEnabled)
            recovery.terminate()
        }
    }

    func testMockAIDisabledStillExplainsStatusAndAllowsPractice() {
        let app = launch(coach: "unavailable")
        openSpeaking(app)
        let question = app.staticTexts["speaking-question"].label
        let completed = completionValue(app)
        openCoach(app, expectsAnswer: false)
        let unavailable = app.descendants(matching: .any)["coach-unavailable"].firstMatch
        reveal(unavailable, in: app)
        // The fixture means AI is turned off, not an unsupported device.
        XCTAssertTrue(unavailable.label.contains("\u{958B}\u{555F} Apple Intelligence"))
        XCTAssertTrue(app.navigationBars["\u{53E3}\u{8AAA}\u{6559}\u{7DF4}"].exists)
        reveal(app.textViews["coach-answer"], in: app, scrollingUp: false)
        XCTAssertFalse(app.buttons["coach-submit"].exists)
        XCTAssertFalse(app.buttons["coach-cancel"].exists)
        assertNoFeedback(app)
        tap(app.buttons["coach-check-again"], in: app)
        XCTAssertTrue(unavailable.exists)
        reveal(app.textViews["coach-answer"], in: app, scrollingUp: false)
        XCTAssertFalse(app.buttons["coach-submit"].exists)
        snapshot(app, "coach-mock-light-zh-ai-off")
        closeCoach(app)
        XCTAssertEqual(app.staticTexts["speaking-question"].label, question)
        XCTAssertEqual(completionValue(app), completed)
        XCTAssertTrue(app.buttons["speaking-show-reference"].isEnabled)
        XCTAssertTrue(app.buttons["speaking-complete"].isEnabled)
        app.buttons["speaking-show-reference"].tap()
        reveal(app.staticTexts["speaking-reference-answer"], in: app)
        tap(app.buttons["speaking-complete-after-reference"], in: app)
        wait(app.staticTexts["speaking-position"], matching: "label BEGINSWITH '2 /'")
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
        let question = openCoach(app)
        enterAnswer("I practice daily.", in: app)
        submit(app)
        let followUp = app.staticTexts["coach-follow-up"]
        reveal(followUp, in: app, scrollingUp: false)
        let followUpText = followUp.label
        XCTAssertFalse(followUpText.isEmpty)
        tap(app.buttons["coach-answer-follow-up"], in: app)
        let shown = app.staticTexts["coach-question"]
        reveal(shown, in: app)
        XCTAssertEqual(shown.label, followUpText)
        reveal(app.textViews["coach-answer"], in: app, scrollingUp: false)
        XCTAssertEqual(app.textViews["coach-answer"].value as? String, "", "A new question starts a new answer")
        assertNoFeedback(app)
        XCTAssertFalse(app.buttons["coach-submit"].isEnabled)
        snapshot(app, "coach-follow-up-question")
        // iOS 26 can drop a tap that lands right after the sheet re-renders
        // (run 183): the follow-up stays shown. The button exists only while a
        // follow-up does, so tapping it again can only go back.
        let original = app.buttons["coach-original-question"]
        tap(original, in: app)
        func backToOriginal(within seconds: TimeInterval) -> Bool {
            let back = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", question),
                                                 object: app.staticTexts["coach-question"])
            return XCTWaiter.wait(for: [back], timeout: seconds) == .completed
        }
        if !backToOriginal(within: 5), original.exists, original.isHittable { original.tap() }
        reveal(app.staticTexts["coach-question"], in: app)
        XCTAssertTrue(backToOriginal(within: 10), "Still showing: \(app.staticTexts["coach-question"].label)")
        closeCoach(app)
    }

    func testRecordingReviewPlaybackAndDeletionWithExplicitFixture() {
        let app = launch(coach: "success", englishUI: true, recording: true)
        openSpeaking(app)
        openCoach(app)
        reveal(app.buttons["coach-record"], in: app, scrollingUp: false)
        tap(app.buttons["coach-record"], in: app)
        app.buttons["coach-record"].tap()
        let playback = app.buttons["coach-play-recording"]
        tap(playback, in: app)
        XCTAssertTrue(playback.label.contains("Stop"))
        playback.tap()
        XCTAssertEqual(app.textViews["coach-answer"].value as? String, "I practice with my friend every day.",
                       "Stopping a take transcribes it without another tap")
        XCTAssertFalse(app.buttons["coach-transcribe"].exists, "A transcribed take needs no second transcription")
        XCTAssertFalse(app.buttons["coach-submit"].exists, "Never coach an unconfirmed transcript")
        XCTAssertTrue(app.buttons["coach-confirm-transcript"].exists)
        closeCoach(app)
        openCoach(app)
        XCTAssertFalse(app.buttons["coach-submit"].exists, "Reopening must not silently confirm the transcript")
        // Confirming the transcript is the request itself.
        tap(app.buttons["coach-confirm-transcript"], in: app)
        XCTAssertTrue(app.staticTexts["coach-rewrite"].waitForExistence(timeout: 5))
        wait(app.buttons["coach-submit"], matching: "exists == true AND enabled == true")
        snapshot(app, "studio-confirmed-transcript")
        closeCoach(app)
        openCoach(app)
        XCTAssertFalse(app.buttons["coach-play-recording"].exists, "Leaving deletes the recording")
        XCTAssertEqual(app.textViews["coach-answer"].value as? String, "I practice with my friend every day.")
        closeCoach(app)
    }

    func testNativeRecorderPermissionTimerPlaybackAndCleanup() {
        let app = launch(englishUI: true)
        openSpeaking(app)
        openCoach(app)
        reveal(app.buttons["coach-record"], in: app, scrollingUp: false)
        app.buttons["coach-record"].tap()
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
        tap(app.buttons["coach-reference"], in: app)
        reveal(app.buttons["coach-play-recording"], in: app, scrollingUp: false)
        app.buttons["coach-play-recording"].tap()
        closeCoach(app)
        openCoach(app)
        XCTAssertFalse(app.buttons["coach-play-recording"].exists)
        closeCoach(app)
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
        openCoach(app)
        XCTAssertFalse(app.buttons["coach-submit"].exists)
        reveal(app.buttons["coach-record"], in: app, scrollingUp: false)
        XCTAssertTrue(app.buttons["coach-record"].isEnabled)
        closeCoach(app)
    }

    func testEditorialNotesAreReachableInBothLanguages() {
        // Learning English: the editorial note on an English word.
        var app = launch()
        app.tabBars.buttons.element(boundBy: 1).tap()
        search("advice", in: app)
        let word = app.staticTexts["advice"].firstMatch
        XCTAssertTrue(word.waitForExistence(timeout: 5))
        word.tap()
        reveal(app.staticTexts["advice / advise"], in: app)
        let explanation = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "advice 是不可數名詞")).firstMatch
        reveal(explanation, in: app)
        snapshot(app, "editorial-light-zh")
        app.terminate()

        // Learning Chinese, in English: the course word, found by its pinyin,
        // with its own example.
        app = launch(dark: true, englishUI: true)
        app.tabBars.buttons.element(boundBy: 1).tap()
        search("jianyi", in: app)
        let course = app.staticTexts["建議"].firstMatch
        XCTAssertTrue(course.waitForExistence(timeout: 5))
        course.tap()
        reveal(app.staticTexts["醫生建議我多喝水。"], in: app)
        snapshot(app, "editorial-dark-en")
        app.terminate()
    }

    private func search(_ text: String, in app: XCUIApplication) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(text)
    }

    private func openSpeaking(_ app: XCUIApplication) {
        tap(app.buttons["today-speaking"], in: app)
        XCTAssertTrue(app.staticTexts["speaking-question"].waitForExistence(timeout: 5))
    }

    @discardableResult
    private func openCoach(_ app: XCUIApplication, expectsAnswer: Bool = true) -> String {
        tap(app.buttons["speaking-coach-open"], in: app)
        XCTAssertTrue(app.buttons["coach-close"].waitForExistence(timeout: 5))
        let question = app.staticTexts["coach-question"]
        XCTAssertTrue(question.waitForExistence(timeout: 5))
        let text = question.label
        XCTAssertFalse(text.isEmpty)
        if expectsAnswer { reveal(app.textViews["coach-answer"], in: app) }
        return text
    }

    /// On iOS 26 a tap on Close right after the sheet re-renders (such as after
    /// "Check again") can be dropped, leaving the sheet exactly as it was.
    /// A Close button still on screen means the tap never arrived; try once more.
    private func closeCoach(_ app: XCUIApplication) {
        let close = app.buttons["coach-close"]
        tap(close, in: app)
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: close)
        if XCTWaiter.wait(for: [gone], timeout: 5) != .completed, close.exists, close.isHittable {
            close.tap()
        }
        wait(close, matching: "exists == false")
        XCTAssertTrue(app.staticTexts["speaking-question"].waitForExistence(timeout: 5))
    }

    private func enterAnswer(_ text: String, in app: XCUIApplication) {
        let answer = app.textViews["coach-answer"]
        answer.tap()
        answer.typeText(text)
        // The accessibility value can lag the final keyboard event on older
        // simulators, past five seconds on a busy iOS 18 runner (run 181).
        // Keep the exact-text assertion; never retry the keystroke.
        let committed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", text), object: answer)
        XCTAssertEqual(XCTWaiter.wait(for: [committed], timeout: 15), .completed)
        XCTAssertEqual(answer.value as? String, text)
    }

    private func submit(_ app: XCUIApplication) {
        if app.keyboards.firstMatch.exists {
            tap(app.buttons["coach-keyboard-done"], in: app)
            wait(app.keyboards.firstMatch, matching: "exists == false")
        }
        let submit = app.buttons["coach-submit"]
        wait(submit, matching: "exists == true AND enabled == true")
        tap(submit, in: app)
    }

    private func assertFeedback(_ app: XCUIApplication, snapshotPrefix: String) {
        for (index, identifier) in ["coach-rewrite", "coach-tip", "coach-follow-up"].enumerated() {
            let field = app.staticTexts[identifier]
            reveal(field, in: app)
            XCTAssertFalse(field.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if index == 0 { snapshot(app, snapshotPrefix + "-rewrite") }
        }
        snapshot(app, snapshotPrefix + "-tip-follow-up")
        XCTAssertTrue(app.buttons["coach-close"].isHittable)
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
        // Fifteen seconds: on a busy runner the keyboard alone took over five
        // to go away (iOS 27, run 182).
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 15), .completed, predicate, file: file, line: line)
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication, scrollingUp: Bool = true,
                        file: StaticString = #filePath, line: UInt = #line) {
        // Forms can omit offscreen rows from the accessibility tree on small phones.
        _ = element.waitForExistence(timeout: 1)
        for _ in 0..<5 where !element.isHittable {
            scrollForm(in: app, up: scrollingUp)
        }
        // Reopened forms can restore an offset beyond the target row.
        for _ in 0..<6 where !element.isHittable {
            scrollForm(in: app, up: !scrollingUp)
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(element.isHittable, "Control must remain reachable on small screens", file: file, line: line)
    }

    private func scrollForm(in app: XCUIApplication, up: Bool) {
        let form = app.collectionViews["coach-form"]
        if form.exists {
            // Use the form margin so the gesture doesn't scroll the editor itself.
            let upper = form.coordinate(withNormalizedOffset: CGVector(dx: 0.025, dy: 0.3))
            let lower = form.coordinate(withNormalizedOffset: CGVector(dx: 0.025, dy: 0.75))
            (up ? lower : upper).press(forDuration: 0.01, thenDragTo: up ? upper : lower)
        } else if up { app.swipeUp() } else { app.swipeDown() }
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
