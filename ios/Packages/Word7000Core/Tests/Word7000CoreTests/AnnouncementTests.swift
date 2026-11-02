import XCTest
@testable import Word7000Core

final class AnnouncementTests: XCTestCase {
    func testDecodesTheTableRowAndPicksItsAudience() throws {
        let json = #"[{"id":"a1","audience":"free","title_zh":"新功能","body_zh":"內容","title_en":"New","body_en":"Body","link":"plus","link_label_zh":"看看","link_label_en":"See","starts_at":"2026-11-02T00:00:00Z","active":true}]"#
        let rows = try JSONDecoder().decode([Announcement].self, from: Data(json.utf8))
        XCTAssertEqual(rows.first?.titleZh, "新功能")
        XCTAssertEqual(rows.first?.link, "plus")
        let free = try XCTUnwrap(rows.first)
        XCTAssertTrue(free.reaches(signedIn: true, plus: false))
        XCTAssertFalse(free.reaches(signedIn: false, plus: false))
        XCTAssertFalse(free.reaches(signedIn: true, plus: true))
        XCTAssertTrue(Announcement(id: "b").reaches(signedIn: false, plus: false))
        XCTAssertTrue(Announcement(id: "c", audience: "plus").reaches(signedIn: true, plus: true))
        XCTAssertFalse(Announcement(id: "d", audience: "guest").reaches(signedIn: true, plus: false))
    }
}
