import Foundation
import XCTest
@testable import Word7000Core

final class LearningFileStoreTests: XCTestCase {
    func testBackgroundWritesKeepTheMostRecentSnapshot() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LearningFileStore(directory: directory)
        for count in 1...150 {
            store.enqueue(ProgressState(studiedToday: count), to: "progress.json")
        }
        store.finishPendingWrites()
        let reopened = LearningFileStore(directory: directory)
        XCTAssertEqual(try reopened.load(ProgressState.self, from: "progress.json")?.studiedToday, 150)
    }

    func testAccountBackupsSurviveGuestResetAndReopening() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LearningFileStore(directory: directory)
        let a = AccountBackup(progress: ProgressState(studiedToday: 17), customSets: .empty)
        let b = AccountBackup(progress: ProgressState(studiedToday: 3), customSets: .empty)
        try store.save(a, to: AccountBackup.fileName(userId: "learner-a"))
        try store.save(b, to: AccountBackup.fileName(userId: "learner-b"))
        try store.save(ProgressState.empty, to: "progress.json")
        let reopened = LearningFileStore(directory: directory)
        XCTAssertEqual(try reopened.load(AccountBackup.self, from: AccountBackup.fileName(userId: "learner-a"))?.progress?.studiedToday, 17)
        XCTAssertEqual(try reopened.load(AccountBackup.self, from: AccountBackup.fileName(userId: "learner-b"))?.progress?.studiedToday, 3)
    }

    func testWriteFailureIsReportedAndPathsCannotEscapeDirectory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LearningFileStore(directory: directory)
        XCTAssertThrowsError(try store.save(1, to: "../outside.json"))
        XCTAssertFalse(AccountBackup.fileName(userId: "../../user").contains("/"))
        let complete = expectation(description: "failure reported")
        store.enqueue(1, to: "bad/name.json") { saved in
            XCTAssertFalse(saved)
            complete.fulfill()
        }
        wait(for: [complete], timeout: 3)
    }
}
