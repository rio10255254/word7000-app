import XCTest
@testable import Word7000Core

final class HomeWidgetTests: XCTestCase {
    let words = Array(ParityTests.words.prefix(50))

    func testSnapshotCarriesTodayAndTurnsOverAtMidnight() {
        let progress = ProgressState(dailyTarget: 20, streak: 3, studiedToday: 8, dailyProgressDate: "2026-10-20", lastStudyDate: "2026-10-20")
        let snapshot = HomeWidgetSnapshot.make(progress: progress, today: "2026-10-20", chineseInterface: true, words: words)
        XCTAssertEqual(snapshot.words.count, HomeWidgetSnapshot.daysAhead)

        let today = snapshot.display(on: "2026-10-20")
        XCTAssertEqual([today.studied, today.target, today.streak], [8, 20, 3])
        XCTAssertTrue(today.studiedToday)
        XCTAssertEqual(today.fraction, 0.4, accuracy: 0.001)
        XCTAssertNotNil(today.word)

        let tomorrow = snapshot.display(on: "2026-10-21")
        XCTAssertEqual([tomorrow.studied, tomorrow.streak], [0, 3])
        XCTAssertFalse(tomorrow.studiedToday)
        XCTAssertNotNil(tomorrow.word)
        // Protection covers the 21st, so the streak survives the 22nd too.
        XCTAssertEqual(snapshot.display(on: "2026-10-22").streak, 3)
        XCTAssertEqual(snapshot.display(on: "2026-10-23").streak, 0)
    }

    func testWordOfTheDayStaysPutAndSkipsMasteredWords() {
        var progress = ProgressState()
        for word in words.dropLast() {
            progress.words[word.id] = WordProgress(status: .mastered)
        }
        let first = HomeWidgetSnapshot.make(progress: .empty, today: "2026-10-20", chineseInterface: false, words: words)
        let again = HomeWidgetSnapshot.make(progress: progress, today: "2026-10-20", chineseInterface: false, words: words, previous: first)
        XCTAssertEqual(again.words["2026-10-20"], first.words["2026-10-20"])
        let fresh = HomeWidgetSnapshot.make(progress: progress, today: "2026-10-20", chineseInterface: false, words: words)
        XCTAssertEqual(fresh.words["2026-10-20"]?.word, words.last?.word)
    }

    func testStoreOnlyWritesChanges() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HomeWidgetStore(directory: directory)
        let snapshot = HomeWidgetSnapshot.make(progress: .empty, today: "2026-10-20", chineseInterface: true, words: words)
        XCTAssertNil(store.load())
        XCTAssertTrue(store.save(snapshot))
        XCTAssertFalse(store.save(snapshot))
        XCTAssertEqual(store.load(), snapshot)
        XCTAssertNil(HomeWidgetStore(directory: nil).load())
    }
}
