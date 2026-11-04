import XCTest
@testable import Word7000Core

final class UsageCounterTests: XCTestCase {
    func testCountsPerDayEventAndDetail() {
        var counter = UsageCounter()
        let day = Date(timeIntervalSince1970: 1_793_750_400) // 2026-11-04 UTC
        counter.add("speaking", detail: "completed", at: day)
        counter.add("speaking", detail: "completed", at: day)
        counter.add("speaking", detail: "skipped", at: day)
        counter.add("speaking", detail: "completed", at: day.addingTimeInterval(86_400))
        XCTAssertEqual(counter.counts[.init(day: "2026-11-04", event: "speaking", detail: "completed")], 2)
        XCTAssertEqual(counter.counts.count, 3)
        XCTAssertEqual(counter.rows.first, .object(["day": .string("2026-11-04"), "event": .string("speaking"), "detail": .string("completed"), "count": .number(2)]))
    }

    func testOnlySafeNamesAndDetailsAreKept() {
        var counter = UsageCounter()
        counter.add("x")
        counter.add("ai", count: 0)
        counter.add("Paywall_View", detail: "locked-smart AI 中文!")
        XCTAssertEqual(counter.counts.keys.map(\.event), ["paywall_view"])
        XCTAssertEqual(counter.counts.keys.map(\.detail), ["locked-smartAI"])
    }

    func testDrainAndMergeKeepUnsentCounts() throws {
        var counter = UsageCounter()
        counter.add("quiz_answer", detail: "english")
        let batch = counter.drain()
        XCTAssertTrue(counter.isEmpty)
        counter.add("quiz_answer", detail: "english")
        counter.merge(batch)
        XCTAssertEqual(counter.counts.values.first, 2)
        let decoded = try JSONDecoder().decode(UsageCounter.self, from: JSONEncoder().encode(counter))
        XCTAssertEqual(decoded, counter)
    }

    func testStopsGrowingPastTheCap() {
        var counter = UsageCounter()
        for index in 0..<(UsageCounter.maxRows + 20) { counter.add("study_session", detail: "d\(index)") }
        XCTAssertEqual(counter.counts.count, UsageCounter.maxRows)
        counter.add("study_session", detail: "d0")
        XCTAssertEqual(counter.counts[.init(day: UsageCounter.day(Date()), event: "study_session", detail: "d0")], 2)
    }
}
