import XCTest
import UIKit

final class ScanPickerTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    override func tearDown() {
        let app = XCUIApplication()
        if app.state == .runningForeground {
            snapshot(app, name: "scan-" + name.components(separatedBy: " ").last!.replacingOccurrences(of: "]", with: ""))
        }
        super.tearDown()
    }

    func testPhotoPickerCancellationAndReopening() {
        let app = openScanner()
        app.buttons["scan-choose-photo"].tap()
        XCTAssertTrue(cancelButton(in: app).waitForExistence(timeout: 10))
        snapshot(app, name: "scan-photo-picker")
        dismissPhotoPicker(in: app)
        app.buttons["scan-choose-photo"].tap()
        XCTAssertTrue(cancelButton(in: app).waitForExistence(timeout: 10))
        dismissPhotoPicker(in: app)
        XCTAssertFalse(app.staticTexts["辨識失敗"].exists)
    }

    func testPhotosAreReadAndSavedAcrossInputFormats() {
        for index in 0..<5 {
            let app = openScanner()
            func pickPhoto() {
                app.buttons["scan-choose-photo"].tap()
                XCTAssertTrue(cancelButton(in: app).waitForExistence(timeout: 10))
                snapshot(app, name: "scan-photo-library-\(index)")
                let photos = app.images.matching(identifier: "PXGGridLayout-Info")
                // Resolve the last required photo instead of repeatedly enumerating
                // the remote Photos accessibility tree inside a predicate callback.
                XCTAssertTrue(photos.element(boundBy: 4).waitForExistence(timeout: 60), app.debugDescription)
                snapshot(app, name: "scan-photo-library-\(index)-ready")
                photos.element(boundBy: index).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                let add = app.buttons.matching(NSPredicate(format: "label IN %@", ["Add", "加入", "Done", "完成"])).firstMatch
                if add.waitForExistence(timeout: 2) { add.tap() }
            }
            pickPhoto()
            let save = app.buttons["scan-save"]
            // The iOS 18 simulator's Photos service sometimes never delivers the
            // photo; after ScanPhotoLoader.transferTimeout the app says so and
            // offers the photo picker again. Pick it once more, as a learner would.
            let loadFailed = app.descendants(matching: .any)["scan-message"]
            // The review is open once its first word row is there (the save
            // key, far down the list, may not be built yet on a small phone).
            let reviewed = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH 'scan-word-'")).firstMatch
            let deadline = Date().addingTimeInterval(80)
            while !reviewed.exists, !loadFailed.exists, Date() < deadline { _ = reviewed.waitForExistence(timeout: 2) }
            if !reviewed.exists, loadFailed.exists {
                snapshot(app, name: "scan-photo-\(index)-load-failed")
                pickPhoto()
            }
            XCTAssertTrue(reviewed.waitForExistence(timeout: 80), app.debugDescription)
            let words = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH 'scan-word-'"))
                .allElementsBoundByIndex.compactMap { ($0.value as? String)?.lowercased() }
            let meanings = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH 'scan-meaning-'"))
                .allElementsBoundByIndex.compactMap { $0.value as? String }
            XCTAssertEqual(Set(words), Set(["objectively", "objective", "carefully"]))
            XCTAssertEqual(Set(meanings), Set(["客觀地", "目標", "小心地"]))
            let expected = ["objectively": "客觀地", "objective": "目標", "carefully": "小心地"]
            for field in app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH 'scan-word-'")).allElementsBoundByIndex {
                let id = String(field.identifier.dropFirst("scan-word-".count))
                XCTAssertEqual(app.textFields["scan-meaning-" + id].value as? String, expected[(field.value as? String ?? "").lowercased()])
            }
            snapshot(app, name: "scan-photo-\(index)-review")
            save.scrollIntoView(in: app, swipes: 4)
            XCTAssertTrue(save.isEnabled)
            XCTAssertTrue(save.isHittable)
            saveScan(save, in: app)
            snapshot(app, name: "scan-photo-\(index)-saved")
            app.buttons["scan-start-study"].tap()
            XCTAssertTrue(app.buttons["study-show-answer"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.staticTexts["study-position"].label.hasSuffix("/ 3"))
            var savedWords = Set<String>()
            for position in 0..<3 {
                let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: app.buttons["study-show-answer"])
                XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
                savedWords.insert(app.staticTexts["study-prompt"].label.lowercased())
                if position < 2 {
                    app.buttons["study-show-answer"].tap()
                    app.buttons["study-grade-known"].tap()
                    XCTAssertTrue(app.buttons["study-show-answer"].waitForExistence(timeout: 5))
                }
            }
            XCTAssertEqual(savedWords, Set(expected.keys))
            snapshot(app, name: "scan-photo-\(index)-study")
            app.terminate()
        }
    }

    func testSpellingSuggestionNeedsExplicitAcceptance() {
        let app = openScanner(pastedText: "abandan v. 放棄\nobjectively adv. 客觀地\nobjective n. 目標")
        let read = app.buttons["scan-read-pasted"]
        read.scrollIntoView(in: app, swipes: 4)
        read.tap()
        let word = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH 'scan-word-' AND value == 'abandan'")).firstMatch
        XCTAssertTrue(word.waitForExistence(timeout: 5))
        let wordIdentifier = word.identifier
        XCTAssertTrue(app.textFields.matching(NSPredicate(format: "value == 'objectively'")).firstMatch.exists)
        let suggestion = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'scan-suggestion-' ")).firstMatch
        XCTAssertTrue(suggestion.exists)
        suggestion.tap()
        XCTAssertEqual(app.textFields[wordIdentifier].value as? String, "abandon")
        snapshot(app, name: "scan-explicit-spelling-choice")
    }

    /// A line with only the English word, or only the Chinese meaning, gets
    /// the rest from the word list, offered under the notepad; Fill all writes
    /// them out, and the list reads like a full one.
    func testNotepadFillsInHalfWrittenLines() {
        let app = openScanner(pastedText: "abandon\n好處")
        let suggestions = app.buttons.matching(identifier: "scan-note-suggestion")
        XCTAssertTrue(suggestions.firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(suggestions.count, 2)
        snapshot(app, name: "scan-notepad-suggestions")
        let fillAll = app.buttons["scan-note-fill-all"]
        fillAll.scrollIntoView(in: app, swipes: 4)
        fillAll.tap()
        let pad = app.descendants(matching: .any)["scan-pasted-text"]
        let filled = NSPredicate(format: "value CONTAINS 'abandon vt./n. 遺棄'")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: filled, object: pad)], timeout: 5), .completed,
                       String(describing: pad.value))
        XCTAssertFalse(app.buttons["scan-note-suggestion"].exists)
        readPasted(app)
        XCTAssertTrue(app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH 'scan-word-' AND value == 'abandon'")).firstMatch.exists)
        XCTAssertTrue(app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH 'scan-word-' AND value == 'benefit'")).firstMatch.exists
                      || app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH 'scan-word-'")).count == 2)
    }

    func testRepeatedScanKeepsDifferentMeaningsAndSkipsExactDuplicates() {
        var app = openScanner(pastedText: "bank n. 銀行")
        let bankName = savePastedBank(app)
        XCUIDevice.shared.press(.home)
        sleep(1)
        app.terminate()

        app = openScanner(pastedText: "BANK n. 銀行\nbank n. 河岸\nobjectively adv. 客觀地\nobjective n. 目標", reset: false)
        readPasted(app)
        // The banks are chips under "Save to".
        let destination = app.buttons[bankName]
        destination.scrollIntoView(in: app, swipes: 6)
        XCTAssertTrue(destination.isHittable)
        destination.tap()
        let save = app.buttons["scan-save"]
        save.scrollIntoView(in: app, swipes: 5)
        XCTAssertEqual(save.label, "存入字庫（3 個）")
        XCTAssertTrue(app.staticTexts["scan-duplicates-summary"].exists)
        snapshot(app, name: "scan-precise-duplicate-review")
        saveScan(save, in: app)
        app.buttons["scan-start-study"].tap()
        XCTAssertTrue(app.buttons["study-show-answer"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["study-position"].label.hasSuffix("/ 4"))
    }

    /// A scanned word with no reviewed conversation question is still
    /// practised, by building on its example: speaking is one mixed practice.
    func testSpeakingChoicesRemainVisibleAfterScanningAnUnsupportedWord() {
        let app = openScanner(pastedText: "objectively adv. 客觀地")
        _ = savePastedBank(app)
        app.buttons["scan-close"].tap()
        app.tabBars.buttons.element(boundBy: 0).tap()
        app.buttons["today-speaking"].tap()
        // Speaking opens on the scenario path; the word list is a tab beside it.
        let track = app.buttons["speaking-track-0"]
        XCTAssertTrue(track.waitForExistence(timeout: 10))
        app.buttons["speaking-track-1"].tap()
        // A word with an example opens on saying it; one without goes straight to the question.
        if app.buttons["shadow-skip"].waitForExistence(timeout: 5) { app.buttons["shadow-skip"].tap() }
        XCTAssertTrue(app.staticTexts["speaking-question"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertFalse(app.segmentedControls["speaking-activity"].exists)
        XCTAssertFalse(app.buttons["speaking-use-core"].exists)
        snapshot(app, name: "speaking-scanned-word-example")
        // The word list and its size live under the scope button, not above the question.
        app.buttons["speaking-filters"].tap()
        let count = app.staticTexts["speaking-available-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        XCTAssertEqual(count.label, "可練習 1 個單字")
        app.buttons["speaking-filters-done"].tap()
        XCTAssertTrue(app.staticTexts["speaking-question"].waitForExistence(timeout: 5))
        // A scanned word may have no example sentence; it can still be practised.
        XCTAssertTrue(app.buttons["coach-record"].exists)
        XCTAssertTrue(app.buttons["speaking-next"].waitForExistence(timeout: 5))
        snapshot(app, name: "speaking-visible-practice-types")
    }

    func testLongPressBankDeletionCanBeUndoneWithoutLosingWords() {
        let app = openScanner(pastedText: "objectively adv. 客觀地")
        _ = savePastedBank(app)
        app.buttons["scan-close"].tap()
        let bank = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bank-set-' ")).firstMatch
        XCTAssertTrue(bank.waitForExistence(timeout: 5))
        let bankID = bank.identifier
        bank.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.7)).press(forDuration: 1)
        let delete = app.buttons["刪除字庫"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        snapshot(app, name: "bank-long-press-actions")
        delete.tap()
        let confirm = app.buttons["bank-delete-confirm"].firstMatch
        if confirm.waitForExistence(timeout: 2) { confirm.tap() }
        else { app.buttons["刪除字庫"].firstMatch.tap() }
        XCTAssertTrue(app.buttons["bank-undo-delete"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons[bankID].exists)
        app.buttons["bank-undo-delete"].tap()
        XCTAssertTrue(app.buttons[bankID].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["objectively"].firstMatch.waitForExistence(timeout: 5))
        snapshot(app, name: "bank-deletion-restored")
    }

    func testScanCanBeAddedToAnEmptyManuallyCreatedBank() {
        var app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingLight", "-uiTestingFakePlans"]
        app.launch()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        app.tabBars.buttons.matching(NSPredicate(format: "label IN %@", ["單字", "Words"])).firstMatch.tap()
        app.buttons["words-add"].tap()
        app.buttons["words-new-bank"].tap()
        let name = app.textFields["bank-name-input"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), app.debugDescription)
        name.tap()
        name.typeText("Lesson")
        XCTAssertEqual(name.value as? String, "Lesson")
        app.buttons["bank-name-save"].tap()
        let created = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bank-set-' AND label CONTAINS 'Lesson'")).firstMatch
        XCTAssertTrue(created.waitForExistence(timeout: 5), app.debugDescription)
        snapshot(app, name: "empty-manual-bank-created")
        XCUIDevice.shared.press(.home)
        sleep(1)
        app.terminate()
        app = openScanner(pastedText: "objectively adv. 客觀地", reset: false)
        readPasted(app)
        // The banks are chips under "Save to".
        let lesson = app.buttons["Lesson"]
        lesson.scrollIntoView(in: app, swipes: 5)
        XCTAssertTrue(lesson.waitForExistence(timeout: 5), app.debugDescription)
        lesson.tap()
        let save = app.buttons["scan-save"]
        save.scrollIntoView(in: app, swipes: 5)
        saveScan(save, in: app)
    }

    private func readPasted(_ app: XCUIApplication) {
        let read = app.buttons["scan-read-pasted"]
        read.scrollIntoView(in: app, swipes: 5)
        read.tap()
        // The review is a list: on a small phone the save key, far down, is
        // only built once it is near; the first word row shows it is open.
        let firstWord = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH 'scan-word-'")).firstMatch
        XCTAssertTrue(firstWord.waitForExistence(timeout: 5), app.debugDescription)
    }

    private func savePastedBank(_ app: XCUIApplication) -> String {
        readPasted(app)
        let name = app.textFields["scan-bank-name"]
        name.scrollIntoView(in: app, swipes: 5)
        let bankName = name.value as? String ?? ""
        XCTAssertFalse(bankName.isEmpty)
        let save = app.buttons["scan-save"]
        save.scrollIntoView(in: app, swipes: 5)
        saveScan(save, in: app)
        return bankName
    }

    private func openScanner(pastedText: String? = nil, reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingLight", "-uiTestingFakePlans", "-uiTestingScanText"]
        if reset { app.launchArguments.append("-uiTestingReset") }
        app.launchEnvironment["WORD7000_SCAN_TEST_TEXT"] = pastedText
        app.launch()
        XCTAssertTrue(app.buttons["today-start"].waitForExistence(timeout: 10))
        app.tabBars.buttons.matching(NSPredicate(format: "label IN %@", ["單字", "Words"])).firstMatch.tap()
        XCTAssertTrue(app.buttons["words-scan"].waitForExistence(timeout: 5))
        app.buttons["words-scan"].tap()
        XCTAssertTrue(app.buttons["scan-choose-photo"].waitForExistence(timeout: 5))
        return app
    }

    /// The system photo picker animates away on its own schedule, and on a slow
    /// simulator the scanner underneath is not tappable until it has gone.
    /// A Cancel tap made while the picker is still loading can be dropped too,
    /// so tap it again while it is still there. Mid-animation, reading
    /// `isHittable` on the picker's out-of-process Cancel can fail the test
    /// outright ("Activation point invalid", iOS 27), even with a frame, and a
    /// `hittable` predicate never came true for it on iOS 18. Tapping through
    /// the element's own coordinate re-reads its frame at tap time, which is
    /// infinite once the picker is leaving. So Cancel's centre is read once and
    /// tapped as a point on the screen.
    private func dismissPhotoPicker(in app: XCUIApplication) {
        let choose = app.buttons["scan-choose-photo"]
        for _ in 0..<3 {
            let cancel = cancelButton(in: app)
            if cancel.exists {
                let frame = cancel.frame
                let centre = CGPoint(x: frame.midX, y: frame.midY)
                if !frame.isEmpty, centre.x.isFinite, centre.y.isFinite, app.frame.contains(centre) {
                    app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: centre.x, dy: centre.y)).tap()
                }
            }
            if waitUntilBack(choose, in: app, timeout: 8) { return }
        }
        XCTFail("The photo picker did not close\n\(app.debugDescription)")
    }

    /// Reading `hittable` while the picker is still sliding away can fail the
    /// test outright ("Activation point invalid"). So the picker's Cancel must be
    /// gone and the button must have a settled on-screen frame first.
    private func waitUntilBack(_ button: XCUIElement, in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let frame = button.exists ? button.frame : .null
            if !cancelButton(in: app).exists, !frame.isEmpty, frame.midX.isFinite, frame.midY.isFinite,
               app.frame.contains(CGPoint(x: frame.midX, y: frame.midY)), button.isHittable {
                return true
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return false
    }

    /// Right after the picker closes, a tap on Save can land while the sheet is
    /// still settling and be dropped. Saving moves straight to the saved screen,
    /// so a Save button still on screen means the tap never arrived; try once more.
    private func saveScan(_ save: XCUIElement, in app: XCUIApplication) {
        let saved = app.staticTexts["scan-saved"]
        save.tap()
        if !saved.waitForExistence(timeout: 10), save.exists, save.isHittable {
            save.tap()
        }
        XCTAssertTrue(saved.waitForExistence(timeout: 10), app.debugDescription)
    }

    private func cancelButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "取消"])).firstMatch
    }

    private func snapshot(_ app: XCUIApplication, name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] {
            let directory = URL(fileURLWithPath: home).appendingPathComponent("word7000-screenshots", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent(name + ".png"))
            try? app.debugDescription.write(to: directory.appendingPathComponent(name + "-hierarchy.txt"), atomically: true, encoding: .utf8)
        }
    }
}
