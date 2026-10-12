import XCTest
import UIKit

final class ScanPickerTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

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
            func photos() -> [XCUIElement] {
                app.images.allElementsBoundByIndex.filter {
                    $0.isHittable && $0.frame.width > 80 && $0.frame.height > 80 && $0.frame.height < 500
                }
            }
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in photos().count >= 5 }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 15), .completed, app.debugDescription)
            photos()[index].tap()
            let add = app.buttons.matching(NSPredicate(format: "label IN %@", ["Add", "加入", "Done", "完成"])).firstMatch
            if add.waitForExistence(timeout: 2) { add.tap() }
            let save = app.buttons["scan-save"]
            XCTAssertTrue(save.waitForExistence(timeout: 45), app.debugDescription)
            let words = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH 'scan-word-'"))
                .allElementsBoundByIndex.compactMap { $0.value as? String }
            let meanings = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH 'scan-meaning-'"))
                .allElementsBoundByIndex.compactMap { $0.value as? String }
            XCTAssertEqual(Set(words), Set(["abandon", "benefit", "capture"]))
            XCTAssertEqual(Set(meanings), Set(["放棄", "好處", "捕獲"]))
            snapshot(app, name: "scan-photo-\(index)-review")
            for _ in 0..<4 where !save.isHittable { app.swipeUp() }
            XCTAssertTrue(save.isEnabled)
            XCTAssertTrue(save.isHittable)
            save.tap()
            XCTAssertTrue(app.staticTexts["scan-saved"].waitForExistence(timeout: 10))
            snapshot(app, name: "scan-photo-\(index)-saved")
            app.terminate()
        }
    }

    private func openScanner() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset", "-uiTestingLight", "-uiTestingFakePlans"]
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
        let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("word7000-screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent(name + ".png"))
    }
}
