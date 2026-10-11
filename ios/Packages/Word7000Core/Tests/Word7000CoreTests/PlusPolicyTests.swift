import XCTest
@testable import Word7000Core

final class PlusPolicyTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    func day(_ n: Double) -> Date { start.addingTimeInterval(n * 86_400) }

    func testTrialLastsSevenDaysThenLocks() {
        let policy = PlusPolicy(trialStartedAt: start, subscribed: false, trialScansUsed: 0)
        XCTAssertEqual(policy.access(now: day(0)), .trial(daysLeft: 7))
        XCTAssertEqual(policy.access(now: day(6.5)), .trial(daysLeft: 1))
        XCTAssertEqual(policy.access(now: day(7)), .expired)
        for feature in PlusFeature.allCases {
            XCTAssertEqual(policy.decide(feature, now: day(2)), .allowed)
            XCTAssertEqual(policy.decide(feature, now: day(8)), .needsPlus)
        }
    }

    func testScansAreCappedDuringTheTrial() {
        let policy = PlusPolicy(trialStartedAt: start, subscribed: false, trialScansUsed: PlusPolicy.trialScanLimit)
        XCTAssertEqual(policy.decide(.scan, now: day(1)), .trialLimitReached)
        XCTAssertEqual(policy.decide(.sync, now: day(1)), .allowed)
        XCTAssertEqual(policy.trialScansLeft, 0)
    }

    func testSubscribersHaveEverything() {
        let policy = PlusPolicy(trialStartedAt: start, subscribed: true, trialScansUsed: 99)
        XCTAssertEqual(policy.access(now: day(100)), .subscribed)
        XCTAssertEqual(policy.decide(.scan, now: day(100)), .allowed)
    }

    func testTheEarliestRecordedStartWins() {
        XCTAssertEqual(PlusPolicy.trialStart([day(3), nil, day(1)]), day(1))
        XCTAssertEqual(PlusPolicy.trialStart([nil], fallback: day(5)), day(5))
    }
}
