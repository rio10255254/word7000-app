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
        cancelButton(in: app).tap()
        XCTAssertTrue(app.buttons["scan-choose-photo"].waitForExistence(timeout: 5))
        app.buttons["scan-choose-photo"].tap()
        XCTAssertTrue(cancelButton(in: app).waitForExistence(timeout: 10))
        cancelButton(in: app).tap()
        XCTAssertTrue(app.buttons["scan-choose-photo"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["辨識失敗"].exists)
    }

    func testPhotosAreReadAndSavedAcrossInputFormats() {
        for index in 0..<5 {
            let app = openScanner()
            app.buttons["scan-choose-photo"].tap()
            XCTAssertTrue(cancelButton(in: app).waitForExistence(timeout: 10))
            snapshot(app, name: "scan-photo-library-\(index)")
            let photos = app.images.matching(identifier: "PXGGridLayout-Info")
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in photos.count >= 5 }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 60), .completed, app.debugDescription)
            snapshot(app, name: "scan-photo-library-\(index)-ready")
            photos.element(boundBy: index).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let add = app.buttons.matching(NSPredicate(format: "label IN %@", ["Add", "加入", "Done", "完成"])).firstMatch
            if add.waitForExistence(timeout: 2) { add.tap() }
            let save = app.buttons["scan-save"]
            XCTAssertTrue(save.waitForExistence(timeout: 45), app.debugDescription)
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
            for _ in 0..<4 where !save.isHittable { app.swipeUp() }
            XCTAssertTrue(save.isEnabled)
            XCTAssertTrue(save.isHittable)
            save.tap()
            XCTAssertTrue(app.staticTexts["scan-saved"].waitForExistence(timeout: 10))
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
        for _ in 0..<4 where !read.isHittable { app.swipeUp() }
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
        for _ in 0..<6 where !destination.isHittable { app.swipeUp() }
        XCTAssertTrue(destination.isHittable)
        destination.tap()
        app.buttons[bankName].tap()
        let save = app.buttons["scan-save"]
        for _ in 0..<5 where !save.isHittable { app.swipeUp() }
        XCTAssertEqual(save.label, "存入字庫（3 個）")
        XCTAssertTrue(app.staticTexts["scan-duplicates-summary"].exists)
        snapshot(app, name: "scan-precise-duplicate-review")
        save.tap()
        XCTAssertTrue(app.staticTexts["scan-saved"].waitForExistence(timeout: 10))
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
        for _ in 0..<5 where !destination.isHittable { app.swipeUp() }
        destination.tap()
        XCTAssertTrue(app.buttons["Lesson"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["Lesson"].tap()
        let save = app.buttons["scan-save"]
        for _ in 0..<5 where !save.isHittable { app.swipeUp() }
        save.tap()
        XCTAssertTrue(app.staticTexts["scan-saved"].waitForExistence(timeout: 10))
    }

    private func readPasted(_ app: XCUIApplication) {
        let read = app.buttons["scan-read-pasted"]
        for _ in 0..<5 where !read.isHittable { app.swipeUp() }
        read.tap()
        XCTAssertTrue(app.buttons["scan-save"].waitForExistence(timeout: 5))
    }

    private func savePastedBank(_ app: XCUIApplication) -> String {
        readPasted(app)
        let name = app.textFields["scan-bank-name"]
        for _ in 0..<5 where !name.isHittable { app.swipeUp() }
        let bankName = name.value as? String ?? ""
        XCTAssertFalse(bankName.isEmpty)
        let save = app.buttons["scan-save"]
        for _ in 0..<5 where !save.isHittable { app.swipeUp() }
        save.tap()
        XCTAssertTrue(app.staticTexts["scan-saved"].waitForExistence(timeout: 10))
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
