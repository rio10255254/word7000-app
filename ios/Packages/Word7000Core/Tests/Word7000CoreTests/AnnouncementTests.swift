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

    func testUpdateRequirementBlocksOnlyOlderVersionsAndBuilds() throws {
        let json = #"[{"id":"u1","min_version":"2.0.2","min_build":4,"message_zh":"請更新","message_en":"Please update","active":true}]"#
        let row = try XCTUnwrap(JSONDecoder().decode([UpdateRequirement].self, from: Data(json.utf8)).first)
        XCTAssertEqual(row.messageZh, "請更新")
        XCTAssertTrue(row.blocks(version: "2.0.1", build: 9))
        XCTAssertTrue(row.blocks(version: "2.0.2", build: 3))
        XCTAssertFalse(row.blocks(version: "2.0.2", build: 4))
        XCTAssertFalse(row.blocks(version: "2.0.3", build: 1))
        XCTAssertFalse(row.blocks(version: "2.1", build: 1))
        XCTAssertTrue(row.blocks(version: "1.9.9", build: nil))
        let anyBuild = UpdateRequirement(minVersion: "2.0.2")
        XCTAssertFalse(anyBuild.blocks(version: "2.0.2", build: 1))
        XCTAssertTrue(anyBuild.blocks(version: "2.0", build: 1))
        XCTAssertFalse(UpdateRequirement(minVersion: "2.0.2", minBuild: 4).blocks(version: "2.0.2", build: nil))
    }

    func testAnnouncementCanBeLimitedToOlderVersions() throws {
        let json = #"[{"id":"a2","audience":"all","title_zh":"請更新","body_zh":"","title_en":"","body_en":"","link":"update","link_label_zh":"","link_label_en":"","below_version":"2.0.3","below_build":null}]"#
        let old = try XCTUnwrap(JSONDecoder().decode([Announcement].self, from: Data(json.utf8)).first)
        XCTAssertTrue(old.shows(toVersion: "2.0.2", build: 9))
        XCTAssertFalse(old.shows(toVersion: "2.0.3", build: 1))
        XCTAssertTrue(Announcement(id: "everyone").shows(toVersion: "9.9", build: 1))
        let legacy = #"[{"id":"a3","audience":"all","title_zh":"","body_zh":"","title_en":"","body_en":"","link":null,"link_label_zh":"","link_label_en":""}]"#
        XCTAssertNil(try JSONDecoder().decode([Announcement].self, from: Data(legacy.utf8)).first?.belowVersion)
    }
}
