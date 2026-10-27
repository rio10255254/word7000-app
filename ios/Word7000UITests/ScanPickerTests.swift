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
            let deadline = Date().addingTimeInterval(80)
            while !save.exists, !loadFailed.exists, Date() < deadline { _ = save.waitForExistence(timeout: 2) }
            if !save.exists, loadFailed.exists {
                snapshot(app, name: "scan-photo-\(index)-load-failed")
                pickPhoto()
            }
            XCTAssertTrue(save.waitForExistence(timeout: 80), app.debugDescription)
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

    func testRepeatedScanKeepsDifferentMeaningsAndSkipsExactDuplicates() {
        var app = openScanner(pastedText: "bank n. 銀行")
        let bankName = savePastedBank(app)
        XCUIDevice.shared.press(.home)
        sleep(1)
        app.terminate()

        app = openScanner(pastedText: "BANK n. 銀行\nbank n. 河岸\nobjectively adv. 客觀地\nobjective n. 目標", reset: false)
        readPasted(app)
        let destination = app.buttons["scan-destination"]
        destination.scrollIntoView(in: app, swipes: 6)
        XCTAssertTrue(destination.isHittable)
        destination.tap()
        app.buttons[bankName].tap()
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

    func testSpeakingChoicesRemainVisibleAfterScanningAnUnsupportedWord() {
        let app = openScanner(pastedText: "objectively adv. 客觀地")
        _ = savePastedBank(app)
        app.buttons["scan-close"].tap()
        app.tabBars.buttons.element(boundBy: 0).tap()
        app.buttons["today-speaking"].tap()
        let modes = app.segmentedControls["speaking-activity"]
        XCTAssertTrue(modes.waitForExistence(timeout: 10))
        XCTAssertTrue(modes.buttons.element(boundBy: 0).isSelected)
        XCTAssertTrue(app.buttons["speaking-use-core"].waitForExistence(timeout: 5), app.debugDescription)
        snapshot(app, name: "speaking-empty-bank-choices")
        modes.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.staticTexts["speaking-question"].waitForExistence(timeout: 5))
        modes.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["speaking-use-core"].waitForExistence(timeout: 5))
        app.buttons["speaking-use-core"].tap()
        XCTAssertTrue(app.staticTexts["speaking-question"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["speaking-available-count"].label, "600 題")
        app.buttons["speaking-show-reference"].tap()
        XCTAssertTrue(app.staticTexts["speaking-reference-answer"].waitForExistence(timeout: 5))
        app.buttons["speaking-complete-after-reference"].tap()
        XCTAssertTrue(app.staticTexts["speaking-position"].label.hasPrefix("2 /"))
        modes.buttons.element(boundBy: 1).tap()
        app.buttons["speaking-close"].tap()
        app.buttons["today-speaking"].tap()
        XCTAssertTrue(app.segmentedControls["speaking-activity"].buttons.element(boundBy: 1).isSelected)
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
        app.tabBars.buttons.element(boundBy: 1).tap()
        app.buttons["words-add"].tap()
        app.buttons["words-new-bank"].tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), app.debugDescription)
        let name = alert.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5), app.debugDescription)
        name.tap()
        name.typeText("Lesson")
        XCTAssertEqual(name.value as? String, "Lesson")
        app.alerts.buttons["儲存"].tap()
        let created = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bank-set-' AND label CONTAINS 'Lesson'")).firstMatch
        XCTAssertTrue(created.waitForExistence(timeout: 5), app.debugDescription)
        snapshot(app, name: "empty-manual-bank-created")
        XCUIDevice.shared.press(.home)
        sleep(1)
        app.terminate()
        app = openScanner(pastedText: "objectively adv. 客觀地", reset: false)
        readPasted(app)
        let destination = app.buttons["scan-destination"]
        destination.scrollIntoView(in: app, swipes: 5)
        destination.tap()
        XCTAssertTrue(app.buttons["Lesson"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["Lesson"].tap()
        let save = app.buttons["scan-save"]
        save.scrollIntoView(in: app, swipes: 5)
        saveScan(save, in: app)
    }

    private func readPasted(_ app: XCUIApplication) {
        let read = app.buttons["scan-read-pasted"]
        read.scrollIntoView(in: app, swipes: 5)
        read.tap()
        XCTAssertTrue(app.buttons["scan-save"].waitForExistence(timeout: 5))
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
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.buttons["words-scan"].waitForExistence(timeout: 5))
        app.buttons["words-scan"].tap()
        XCTAssertTrue(app.buttons["scan-choose-photo"].waitForExistence(timeout: 5))
        return app
    }

    /// The system photo picker animates away on its own schedule, and on a slow
    /// simulator the scanner underneath is not tappable until it has gone.
    /// A Cancel tap made while the picker is still loading can be dropped too,
    /// so tap it again while it is still there. Mid-animation, reading Cancel's
    /// `isHittable` can fail the test outright ("activation point invalid",
    /// iOS 26 and 27), and a `hittable` predicate never came true for the
    /// picker's out-of-process Cancel on iOS 18. So Cancel is tapped at the
    /// middle of its frame once that frame is on screen and has stopped moving,
    /// that is once the picker has finished sliding in over the scanner.
    private func dismissPhotoPicker(in app: XCUIApplication) {
        let choose = app.buttons["scan-choose-photo"]
        for _ in 0..<3 {
            let cancel = cancelButton(in: app)
            if cancel.exists {
                var frame = cancel.frame
                for _ in 0..<10 {
                    usleep(300_000)
                    guard cancel.exists else { break }
                    let next = cancel.frame
                    if next == frame { break }
                    frame = next
                }
                if cancel.exists, frame.width > 0, frame.height > 0, app.frame.contains(CGPoint(x: frame.midX, y: frame.midY)) {
                    app.coordinate(withNormalizedOffset: .zero)
                        .withOffset(CGVector(dx: frame.midX - app.frame.minX, dy: frame.midY - app.frame.minY))
                        .tap()
                }
            }
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: choose)
            if XCTWaiter.wait(for: [ready], timeout: 8) == .completed { return }
        }
        XCTFail("The photo picker did not close\n\(app.debugDescription)")
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
