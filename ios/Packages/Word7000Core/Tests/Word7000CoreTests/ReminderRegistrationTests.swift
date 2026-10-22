import Foundation
import XCTest
@testable import Word7000Core

@MainActor
final class ReminderRegistrationTests: XCTestCase {
    private typealias Row = ReminderRegistrationCoordinator.Row

    @MainActor
    private final class Transport {
        var rows: [Row] = []
        var completions: [Int: CheckedContinuation<Bool, Never>] = [:]
        var active = 0
        var peak = 0

        func send(_ row: Row) async -> Bool {
            let index = rows.count
            rows.append(row)
            active += 1
            peak = max(peak, active)
            let result = await withCheckedContinuation { completions[index] = $0 }
            active -= 1
            return result
        }

        func finish(_ index: Int, saved: Bool = true) {
            completions.removeValue(forKey: index)?.resume(returning: saved)
        }

        func waitForCount(_ count: Int, file: StaticString = #filePath, line: UInt = #line) async {
            for _ in 0..<2000 {
                if rows.count >= count { return }
                try? await Task.sleep(for: .milliseconds(1))
            }
            XCTFail("Expected \(count) requests, got \(rows.count)", file: file, line: line)
        }
    }

    private func values(_ count: Int) -> Row {
        ["device_id": .string("iphone"), "studied_today": .number(Double(count))]
    }

    private func waitForLogout(_ finished: () -> Bool) async {
        // Await the observable completion while the transport stays held.
        // A fixed 150ms sleep races task scheduling on shared CI machines.
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !finished(), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func testDebounceCoalescesBeforeDispatch() async {
        let queue = ReminderRegistrationCoordinator()
        var sent: [Row] = []
        for count in 1...20 {
            queue.submit(owner: "a", values: values(count), delay: .seconds(3600)) { sent.append($0); return true }
        }
        await queue.flush()
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent.first?["studied_today"], .number(20))
        queue.submit(owner: "a", values: values(20), delay: .zero) { sent.append($0); return true }
        await queue.flush()
        XCTAssertEqual(sent.count, 1)
    }

    func testInflightUploadsAreSerializedAndOnlyLatestPendingSurvives() async {
        let queue = ReminderRegistrationCoordinator(), transport = Transport()
        queue.submit(owner: "a", values: values(1), delay: .zero, upload: transport.send)
        await transport.waitForCount(1)
        queue.submit(owner: "a", values: values(2), delay: .zero, upload: transport.send)
        queue.submit(owner: "a", values: values(3), delay: .zero, upload: transport.send)
        XCTAssertEqual(transport.rows.count, 1)
        transport.finish(0)
        await transport.waitForCount(2)
        XCTAssertEqual(transport.rows.last?["studied_today"], .number(3))
        transport.finish(1)
        await queue.flush()
        XCTAssertEqual(transport.rows.count, 2)
        XCTAssertEqual(transport.peak, 1)
    }

    func testDisableSupersedesPendingUpdateAndBackgroundFlushWaitsForIt() async {
        let queue = ReminderRegistrationCoordinator(), transport = Transport()
        var enabled = values(1)
        enabled["enabled"] = .bool(true)
        queue.submit(owner: "a", values: enabled, delay: .zero, upload: transport.send)
        await transport.waitForCount(1)
        var newer = values(2)
        newer["enabled"] = .bool(true)
        queue.submit(owner: "a", values: newer, delay: .zero, upload: transport.send)
        var disabled = newer
        disabled["enabled"] = .bool(false)
        queue.submit(owner: "a", values: disabled, delay: .zero, upload: transport.send)
        var completed = false
        let background = Task { await queue.flush(); completed = true }
        await Task.yield()
        XCTAssertFalse(completed)
        XCTAssertEqual(transport.rows.count, 1)
        transport.finish(0)
        await transport.waitForCount(2)
        XCTAssertEqual(transport.rows.last?["enabled"], .bool(false))
        XCTAssertFalse(completed, "Background lease must cover the replacement write too")
        transport.finish(1)
        await background.value
        XCTAssertTrue(completed)
        XCTAssertEqual(transport.rows.count, 2)
        XCTAssertEqual(transport.peak, 1)
    }

    func testAccountChangeWhileAuthenticationWaitsCannotAcknowledgeOldSnapshot() async {
        let queue = ReminderRegistrationCoordinator(), authentication = Transport()
        var currentOwner = "a"
        var uploaded: [Row] = []
        queue.submit(owner: "a", values: values(1), delay: .zero) { row in
            // Models AccountModel's awaited session refresh and owner guard.
            _ = await authentication.send(row)
            guard row["user_id"] == .string(currentOwner) else { return false }
            uploaded.append(row)
            return true
        }
        await authentication.waitForCount(1)
        currentOwner = "b"
        queue.submit(owner: "b", values: values(2), delay: .zero) { uploaded.append($0); return true }
        authentication.finish(0)
        await queue.flush()
        XCTAssertEqual(uploaded.count, 1)
        XCTAssertEqual(uploaded.first?["user_id"], .string("b"))
        // Returning to A must send again, even if its content is unchanged.
        currentOwner = "a"
        queue.submit(owner: "a", values: values(1), delay: .zero) { uploaded.append($0); return true }
        await queue.flush()
        XCTAssertEqual(uploaded.count, 2)
        XCTAssertEqual(uploaded.last?["user_id"], .string("a"))
    }

    func testRevertingToPreviouslyAcknowledgedValuesStillReplacesInflightWrite() async {
        let queue = ReminderRegistrationCoordinator(), transport = Transport()
        queue.submit(owner: "a", values: values(1), delay: .zero) { _ in true }
        await queue.flush()
        queue.submit(owner: "a", values: values(2), delay: .zero, upload: transport.send)
        await transport.waitForCount(1)
        queue.submit(owner: "a", values: values(1), delay: .zero, upload: transport.send)
        transport.finish(0)
        await transport.waitForCount(2)
        XCTAssertEqual(transport.rows.last?["studied_today"], .number(1))
        transport.finish(1)
        await queue.flush()
    }

    func testAccountSwitchDropsQueuedOldRowsAndNeverAcknowledgesOldCompletion() async {
        let queue = ReminderRegistrationCoordinator(), transport = Transport()
        queue.submit(owner: "a", values: values(1), delay: .zero, upload: transport.send)
        await transport.waitForCount(1)
        queue.submit(owner: "a", values: values(2), delay: .zero, upload: transport.send)
        queue.setOwner(nil)
        queue.submit(owner: "b", values: values(3), delay: .zero, upload: transport.send)
        transport.finish(0)
        await transport.waitForCount(2)
        XCTAssertEqual(transport.rows.last?["user_id"], .string("b"))
        transport.finish(1)
        await queue.flush()
        queue.submit(owner: "a", values: values(1), delay: .zero, upload: transport.send)
        await transport.waitForCount(3)
        transport.finish(2)
        await queue.flush()
        XCTAssertEqual(transport.peak, 1)
    }

    func testSwitchAwayAndBackWhileInflightCannotAcknowledgePreviousAccountEpoch() async {
        let queue = ReminderRegistrationCoordinator(), transport = Transport()
        queue.submit(owner: "a", values: values(1), delay: .zero, upload: transport.send)
        await transport.waitForCount(1)
        queue.setOwner("b")
        queue.submit(owner: "a", values: values(1), delay: .zero, upload: transport.send)
        transport.finish(0)
        await transport.waitForCount(2)
        transport.finish(1)
        await queue.flush()
        XCTAssertEqual(transport.rows.count, 2)
    }

    func testFailedUploadRetainsTimestampAndIsNotAcknowledged() async {
        let queue = ReminderRegistrationCoordinator()
        var rows: [Row] = []
        var succeeds = false
        let send: ReminderRegistrationCoordinator.Upload = { rows.append($0); return succeeds }
        queue.submit(owner: "a", values: values(1), delay: .zero, upload: send)
        await queue.flush()
        XCTAssertEqual(rows.count, 1)
        succeeds = true
        queue.submit(owner: "a", values: values(1), delay: .zero, now: Date().addingTimeInterval(100), upload: send)
        await queue.flush()
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0]["updated_at"], rows[1]["updated_at"])
        queue.submit(owner: "a", values: values(1), delay: .zero, upload: send)
        await queue.flush()
        XCTAssertEqual(rows.count, 2)
    }

    func testFailureDoesNotDiscardNewerPendingSnapshot() async {
        let queue = ReminderRegistrationCoordinator(), transport = Transport()
        queue.submit(owner: "a", values: values(1), delay: .zero, upload: transport.send)
        await transport.waitForCount(1)
        queue.submit(owner: "a", values: values(2), delay: .zero, upload: transport.send)
        transport.finish(0, saved: false)
        await transport.waitForCount(2)
        XCTAssertEqual(transport.rows.last?["studied_today"], .number(2))
        transport.finish(1)
        await queue.flush()
    }

    func testLostResponseCannotUseOldAcknowledgmentToSuppressRevert() async {
        let queue = ReminderRegistrationCoordinator(), transport = Transport()
        queue.submit(owner: "a", values: values(1), delay: .zero) { _ in true }
        await queue.flush()
        queue.submit(owner: "a", values: values(2), delay: .zero, upload: transport.send)
        await transport.waitForCount(1)
        queue.submit(owner: "a", values: values(1), delay: .zero, upload: transport.send)
        transport.finish(0, saved: false)
        await transport.waitForCount(2)
        XCTAssertEqual(transport.rows.last?["studied_today"], .number(1))
        transport.finish(1)
        await queue.flush()
    }

    func testExpirationRetainsLatestAndDoesNotReleaseInflightWriterEarly() async {
        let queue = ReminderRegistrationCoordinator(), transport = Transport()
        queue.submit(owner: "a", values: values(1), delay: .zero, upload: transport.send)
        await transport.waitForCount(1)
        queue.submit(owner: "a", values: values(2), delay: .zero, upload: transport.send)
        queue.suspend()
        queue.resume()
        queue.submit(owner: "a", values: values(3), delay: .zero, upload: transport.send)
        XCTAssertEqual(transport.rows.count, 1)
        // This transport deliberately ignores cancellation and even reports
        // success after expiration. Neither permits a stale acknowledgment.
        transport.finish(0)
        await transport.waitForCount(2)
        XCTAssertEqual(transport.rows.last?["studied_today"], .number(3))
        transport.finish(1)
        await queue.flush()
        XCTAssertEqual(transport.peak, 1)
    }

    func testExpirationWithoutPendingChangeRetriesExactSnapshot() async {
        let queue = ReminderRegistrationCoordinator(), transport = Transport()
        queue.submit(owner: "a", values: values(1), delay: .zero, upload: transport.send)
        await transport.waitForCount(1)
        queue.suspend()
        transport.finish(0)
        await queue.flush()
        XCTAssertEqual(transport.rows.count, 1)
        queue.resume()
        queue.submit(owner: "a", values: values(1), delay: .zero, upload: transport.send)
        await transport.waitForCount(2)
        XCTAssertEqual(transport.rows.first?["updated_at"], transport.rows.last?["updated_at"])
        transport.finish(1)
        await queue.flush()
    }

    func testSnapshotTimestampsIncreaseEvenWithinOneMillisecondAndClockReversal() async throws {
        let queue = ReminderRegistrationCoordinator()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var stamps: [String] = []
        for index in 0..<4 {
            queue.submit(owner: index == 3 ? "b" : "a", values: values(index), delay: .zero,
                         now: index < 2 ? now : now.addingTimeInterval(-1000)) { row in
                if case let .string(stamp)? = row["updated_at"] { stamps.append(stamp) }
                return true
            }
            await queue.flush()
        }
        XCTAssertEqual(stamps.count, 4)
        for index in 1..<stamps.count { XCTAssertLessThan(stamps[index - 1], stamps[index]) }
    }

    func testLogoutReplacesPendingWorkAndBlocksRefreshUntilOwnerChanges() async {
        let queue = ReminderRegistrationCoordinator(), transport = Transport()
        queue.submit(owner: "a", values: values(1), delay: .zero, upload: transport.send)
        await transport.waitForCount(1)
        queue.submit(owner: "a", values: values(2), delay: .zero, upload: transport.send)
        let logout = Task { await queue.revoke(owner: "a", deviceId: "iphone", upload: transport.send) }
        // Yield until revoke has replaced the pending registration.
        for _ in 0..<20 { await Task.yield() }
        queue.submit(owner: "a", values: values(3), delay: .zero, upload: transport.send)
        transport.finish(0)
        await transport.waitForCount(2)
        XCTAssertEqual(transport.rows.last?["enabled"], .bool(false))
        XCTAssertNil(transport.rows.last?["studied_today"])
        if case let .string(first)? = transport.rows.first?["updated_at"],
           case let .string(last)? = transport.rows.last?["updated_at"] { XCTAssertLessThan(first, last) }
        transport.finish(1)
        let disabled = await logout.value
        XCTAssertTrue(disabled)
        queue.submit(owner: "a", values: values(4), delay: .zero, upload: transport.send)
        await queue.flush()
        XCTAssertEqual(transport.rows.count, 2)
        // A failed guest bootstrap leaves no new owner and must not reopen A.
        queue.setOwner(nil)
        await queue.flush()
        XCTAssertEqual(transport.rows.count, 2)
        queue.submit(owner: "guest", values: values(0), delay: .zero, upload: transport.send)
        await transport.waitForCount(3)
        XCTAssertEqual(transport.rows.last?["user_id"], .string("guest"))
        transport.finish(2)
        await queue.flush()
        XCTAssertEqual(transport.peak, 1)
    }

    func testLogoutDeadlineDoesNotWaitForOldTransportOrDispatchAfterTimeout() async {
        let queue = ReminderRegistrationCoordinator(), transport = Transport()
        queue.submit(owner: "a", values: values(1), delay: .zero, upload: transport.send)
        await transport.waitForCount(1)
        var result: Bool?
        var disableAttempts = 0
        let logout = Task {
            result = await queue.revoke(owner: "a", deviceId: "iphone", timeout: .milliseconds(20)) { _ in
                disableAttempts += 1
                return true
            }
        }
        await waitForLogout { result != nil }
        XCTAssertEqual(result, false, "Logout must return while the old request is still held")
        queue.submit(owner: "a", values: values(9), delay: .zero, upload: transport.send)
        transport.finish(0)
        await logout.value
        await queue.flush()
        XCTAssertEqual(disableAttempts, 0)
        XCTAssertEqual(transport.rows.count, 1)
    }

    func testLogoutTimeoutKeepsWriterOccupiedUntilDisableTransportFinishes() async {
        let queue = ReminderRegistrationCoordinator(), transport = Transport()
        var result: Bool?
        let logout = Task {
            result = await queue.revoke(owner: "a", deviceId: "iphone", timeout: .milliseconds(20), upload: transport.send)
        }
        await transport.waitForCount(1)
        await waitForLogout { result != nil }
        XCTAssertEqual(result, false)
        queue.submit(owner: "guest", values: values(0), delay: .zero, upload: transport.send)
        XCTAssertEqual(transport.rows.count, 1)
        transport.finish(0)
        await transport.waitForCount(2)
        XCTAssertEqual(transport.rows.last?["user_id"], .string("guest"))
        transport.finish(1)
        await logout.value
        await queue.flush()
        XCTAssertEqual(transport.peak, 1)
    }

    func testFailedLogoutDisableDoesNotRetryOrAllowOldAccountRefresh() async {
        let queue = ReminderRegistrationCoordinator()
        var sent: [Row] = []
        let disabled = await queue.revoke(owner: "a", deviceId: "iphone") { sent.append($0); return false }
        XCTAssertFalse(disabled)
        queue.submit(owner: "a", values: values(1), delay: .zero) { sent.append($0); return true }
        await queue.flush()
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent.first?["enabled"], .bool(false))
    }

    func testBackgroundExpirationCompletesLogoutWithoutWaitingForTransport() async {
        let queue = ReminderRegistrationCoordinator(), transport = Transport()
        let logout = Task { await queue.revoke(owner: "a", deviceId: "iphone", upload: transport.send) }
        await transport.waitForCount(1)
        queue.suspend()
        let disabled = await logout.value
        XCTAssertFalse(disabled)
        transport.finish(0)
        await queue.flush()
        queue.resume()
        queue.submit(owner: "a", values: values(2), delay: .zero, upload: transport.send)
        await queue.flush()
        XCTAssertEqual(transport.rows.count, 1)
    }
}
