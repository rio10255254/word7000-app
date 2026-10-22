import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import Word7000Core

final class SupabaseTests: XCTestCase {
    final class FakeTransport: HTTPTransport, @unchecked Sendable {
        var responses: [(String, Int)]
        var requests: [URLRequest] = []

        init(_ responses: [(String, Int)]) { self.responses = responses }

        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            let (body, status) = responses.removeFirst()
            return (Data(body.utf8), status)
        }
    }

    let config = SupabaseConfig(url: "https://abcdefgh.supabase.co/rest/v1/", key: "sb_publishable_x")!
    let sessionJSON = #"{"access_token":"a1","refresh_token":"r1","expires_in":3600,"user":{"id":"u1","is_anonymous":true}}"#

    func testConfigNormalisesAndRejectsUnsetBuildVariables() {
        XCTAssertEqual(config.url.absoluteString, "https://abcdefgh.supabase.co")
        XCTAssertEqual(config.legacySessionStorageKey, "sb-abcdefgh-auth-token")
        XCTAssertNil(SupabaseConfig(url: "$(EXPO_PUBLIC_SUPABASE_URL)", key: "k"))
        XCTAssertNil(SupabaseConfig(url: "https://x.supabase.co", key: ""))
    }

    func testAnonymousSignInSendsKeyAndDecodesSession() async throws {
        let transport = FakeTransport([(sessionJSON, 200)])
        let session = try await SupabaseClient(config: config, transport: transport).signInAnonymously()
        XCTAssertEqual(session.user.id, "u1")
        XCTAssertTrue(session.user.anonymous)
        XCTAssertFalse(session.needsRefresh())
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://abcdefgh.supabase.co/auth/v1/signup")
        XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "sb_publishable_x")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sb_publishable_x")
    }

    func testLinkingAppleSendsTheGuestTokenAndFlag() async throws {
        let transport = FakeTransport([(sessionJSON, 200)])
        let guest = try JSONDecoder().decode(AuthSession.self, from: Data(sessionJSON.utf8))
        _ = try await SupabaseClient(config: config, transport: transport)
            .signInWithIdToken(provider: "apple", idToken: "jwt", nonce: "n", accessToken: "code", linkTo: guest)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.query, "grant_type=id_token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer a1")
        let body = try JSONDecoder().decode([String: JSONValue].self, from: XCTUnwrap(request.httpBody))
        XCTAssertEqual(body["link_identity"], .bool(true))
        XCTAssertEqual(body["nonce"], .string("n"))
    }

    func testProfileWithEmptyDocumentsLoadsAsFoundButEmpty() async throws {
        let transport = FakeTransport([(#"[{"progress":{},"custom_sets":{"sets":[],"customWords":[]}}]"#, 200)])
        let session = try JSONDecoder().decode(AuthSession.self, from: Data(sessionJSON.utf8))
        let profile = try await SupabaseClient(config: config, transport: transport).loadProfile(session: session)
        XCTAssertTrue(profile.found)
        XCTAssertNil(profile.progress)
        XCTAssertEqual(profile.customSets, CustomSetState())
        XCTAssertEqual(transport.requests.first?.url?.query, "id=eq.u1&select=progress,custom_sets")
    }

    func testSaveProfileUpsertsOneRow() async throws {
        let transport = FakeTransport([("", 201)])
        let session = try JSONDecoder().decode(AuthSession.self, from: Data(sessionJSON.utf8))
        try await SupabaseClient(config: config, transport: transport).saveProfile(progress: ProgressState(), customSets: nil, session: session)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Prefer"), "resolution=merge-duplicates,return=minimal")
        let rows = try JSONDecoder().decode([[String: JSONValue]].self, from: XCTUnwrap(request.httpBody))
        XCTAssertEqual(rows.first?["id"], .string("u1"))
        XCTAssertNotNil(rows.first?["progress"])
        XCTAssertNil(rows.first?["custom_sets"])
    }

    func testErrorsCarryCodeAndRecogniseLinkedIdentities() async {
        let transport = FakeTransport([(#"{"code":422,"error_code":"identity_already_exists","msg":"Identity is already linked to another user"}"#, 422)])
        let session = try! JSONDecoder().decode(AuthSession.self, from: Data(sessionJSON.utf8))
        do {
            _ = try await SupabaseClient(config: config, transport: transport).signInWithIdToken(provider: "apple", idToken: "t", nonce: nil, accessToken: nil, linkTo: session)
            XCTFail("expected an error")
        } catch let error as SupabaseError {
            XCTAssertEqual(error.status, 422)
            XCTAssertTrue(error.isIdentityAlreadyLinked)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testOAuthCallbackParsing() {
        let url = URL(string: "word7000://auth/callback?code=c1#access_token=a&refresh_token=r&error_description=Nope%20here")!
        let parsed = AuthCallback(url: url)
        XCTAssertEqual(parsed.code, "c1")
        XCTAssertEqual(parsed.accessToken, "a")
        XCTAssertEqual(parsed.refreshToken, "r")
        XCTAssertEqual(parsed.error, "Nope here")
    }

    func testReminderRegistrationRequiresReturnedRowAndKeepsSnapshotTimestamp() async throws {
        let transport = FakeTransport([(#"[{"user_id":"u1","device_id":"iphone","updated_at":"2026-10-22T01:00:00.001+00:00"}]"#, 201)])
        let session = try JSONDecoder().decode(AuthSession.self, from: Data(sessionJSON.utf8))
        let row: [String: JSONValue] = ["user_id": .string("u1"), "device_id": .string("iphone"),
                                       "updated_at": .string("2026-10-22T01:00:00.001Z")]
        try await SupabaseClient(config: config, transport: transport).saveLiveActivityDevice(row, session: session)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Prefer"), "resolution=merge-duplicates,return=representation")
        let rows = try JSONDecoder().decode([[String: JSONValue]].self, from: XCTUnwrap(request.httpBody))
        XCTAssertEqual(rows.first?["updated_at"], row["updated_at"])
        XCTAssertNil(rows.first?["registration_updated_at"])
    }

    func testIgnoredStaleRegistrationIsNotReportedAsSaved() async throws {
        let transport = FakeTransport([("[]", 201)])
        let session = try JSONDecoder().decode(AuthSession.self, from: Data(sessionJSON.utf8))
        do {
            try await SupabaseClient(config: config, transport: transport)
                .saveLiveActivityDevice(["device_id": .string("iphone")], session: session)
            XCTFail("A silently rejected write must not be acknowledged")
        } catch let error as SupabaseError {
            XCTAssertEqual(error.code, "registration_not_saved")
        }
    }

    func testReminderSnapshotCannotBeRelabelledAsAnotherUser() async throws {
        let transport = FakeTransport([])
        let session = try JSONDecoder().decode(AuthSession.self, from: Data(sessionJSON.utf8))
        do {
            try await SupabaseClient(config: config, transport: transport)
                .saveLiveActivityDevice(["user_id": .string("old-user"), "device_id": .string("iphone")], session: session)
            XCTFail("Mismatched owner must not be sent")
        } catch is CancellationError {}
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testRefreshedSessionForDifferentOwnerCannotUploadCapturedRegistration() async throws {
        let response = #"{"access_token":"new","refresh_token":"r2","expires_in":3600,"user":{"id":"u2"}}"#
        let transport = FakeTransport([(response, 200)])
        let client = SupabaseClient(config: config, transport: transport)
        let snapshot: [String: JSONValue] = ["user_id": .string("u1"), "device_id": .string("iphone"),
                                            "updated_at": .string("2026-10-22T01:00:00.001Z")]
        let refreshed = try await client.refresh(refreshToken: "r1")
        do {
            try await client.saveLiveActivityDevice(snapshot, session: refreshed)
            XCTFail("A stale owner's snapshot must not use the refreshed owner's credentials")
        } catch is CancellationError {}
        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertEqual(transport.requests.first?.url?.path, "/auth/v1/token")
    }

    func testIdenticalRetryAcceptsRegistrationTimeDespiteLaterCronTime() async throws {
        let response = #"[{"user_id":"u1","device_id":"iphone","enabled":false,"streak_expires_at":"2026-10-23T00:00:00+00:00","registration_updated_at":"2026-10-22T01:00:00.001+00:00","updated_at":"2026-10-22T02:00:00+00:00","last_push_error":"preserved"}]"#
        let transport = FakeTransport([(response, 200)])
        let session = try JSONDecoder().decode(AuthSession.self, from: Data(sessionJSON.utf8))
        let row: [String: JSONValue] = ["device_id": .string("iphone"), "enabled": .bool(false),
                                       "streak_expires_at": .string("2026-10-23T00:00:00.000Z"),
                                       "updated_at": .string("2026-10-22T01:00:00.001Z")]
        try await SupabaseClient(config: config, transport: transport).saveLiveActivityDevice(row, session: session)
        XCTAssertEqual(transport.requests.count, 1)
    }

    func testReturnedOldRowWithAnyConflictingRegistrationFieldIsNotAcknowledged() async throws {
        let session = try JSONDecoder().decode(AuthSession.self, from: Data(sessionJSON.utf8))
        let row: [String: JSONValue] = [
            "user_id": .string("u1"), "device_id": .string("iphone"), "enabled": .bool(false),
            "push_to_start_token": .string("token"), "app_locale": .string("en"), "time_zone": .string("UTC"),
            "streak": .number(3), "streak_expires_at": .string("2026-10-23T00:00:00Z"),
            "daily_target": .number(20), "studied_today": .number(5), "progress_date": .string("2026-10-22"),
            "reminder_minute": .number(720), "updated_at": .string("2026-10-22T01:00:00.001Z"),
        ]
        for key in row.keys {
            var saved = row
            saved[key] = .null
            let response = String(decoding: try JSONEncoder().encode([saved]), as: UTF8.self)
            let transport = FakeTransport([(response, 200)])
            do {
                try await SupabaseClient(config: config, transport: transport).saveLiveActivityDevice(row, session: session)
                XCTFail("Conflicting or missing \(key) must not be acknowledged")
            } catch let error as SupabaseError {
                XCTAssertEqual(error.code, "registration_not_saved")
            }
        }
    }

    func testNewerRegistrationTimeCannotBeHiddenByMatchingCronTime() async throws {
        let response = #"[{"user_id":"u1","device_id":"iphone","registration_updated_at":"2026-10-22T01:00:00.002Z","updated_at":"2026-10-22T01:00:00.001Z"}]"#
        let session = try JSONDecoder().decode(AuthSession.self, from: Data(sessionJSON.utf8))
        do {
            try await SupabaseClient(config: config, transport: FakeTransport([(response, 200)]))
                .saveLiveActivityDevice(["device_id": .string("iphone"), "updated_at": .string("2026-10-22T01:00:00.001Z")], session: session)
            XCTFail("Registration time, not cron time, must match")
        } catch let error as SupabaseError {
            XCTAssertEqual(error.code, "registration_not_saved")
        }
    }

    @MainActor
    func testLostResponseRetryAcknowledgesExactSnapshotAndStopsRetrying() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let saved: [String: JSONValue] = ["user_id": .string("u1"), "device_id": .string("iphone"), "enabled": .bool(false),
                                         "registration_updated_at": .string(DayMath.timestamp(now)),
                                         "updated_at": .string(DayMath.timestamp(now.addingTimeInterval(60)))]
        let response = String(decoding: try JSONEncoder().encode([saved]), as: UTF8.self)
        // First write reached the database, but its response was lost. The retry
        // returns the same registration with cron's newer bookkeeping time.
        let transport = FakeTransport([("", 503), (response, 200), (response, 200)])
        let client = SupabaseClient(config: config, transport: transport)
        let session = try JSONDecoder().decode(AuthSession.self, from: Data(sessionJSON.utf8))
        let queue = ReminderRegistrationCoordinator()
        let row: [String: JSONValue] = ["device_id": .string("iphone"), "enabled": .bool(false)]
        let send: ReminderRegistrationCoordinator.Upload = { row in
            do { try await client.saveLiveActivityDevice(row, session: session); return true }
            catch { return false }
        }
        for attempt in 0..<3 {
            queue.submit(owner: "u1", values: row, delay: .zero, now: now.addingTimeInterval(Double(attempt)), upload: send)
            await queue.flush()
        }
        XCTAssertEqual(transport.requests.count, 2)
        let first = try JSONDecoder().decode(JSONValue.self, from: XCTUnwrap(transport.requests.first?.httpBody))
        let second = try JSONDecoder().decode(JSONValue.self, from: XCTUnwrap(transport.requests.last?.httpBody))
        XCTAssertEqual(first, second)
    }

    func testLogoutDisableOnlyPatchesCurrentAccountDeviceWithCapturedTimestamp() async throws {
        let row: [String: JSONValue] = ["user_id": .string("u1"), "device_id": .string("iphone"),
                                       "enabled": .bool(false), "updated_at": .string("2026-10-22T01:00:00.001Z")]
        let response = String(decoding: try JSONEncoder().encode([row]), as: UTF8.self)
        let transport = FakeTransport([(response, 200)])
        let session = try JSONDecoder().decode(AuthSession.self, from: Data(sessionJSON.utf8))
        try await SupabaseClient(config: config, transport: transport).disableLiveActivityDevice(row, session: session)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(request.url?.query, "device_id=eq.iphone&user_id=eq.u1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Prefer"), "return=representation")
        let body = try JSONDecoder().decode([String: JSONValue].self, from: XCTUnwrap(request.httpBody))
        XCTAssertEqual(body, ["enabled": .bool(false), "updated_at": row["updated_at"]!])
    }

    func testLogoutDisableCannotUseAnotherAccountsCredentials() async throws {
        let transport = FakeTransport([])
        let session = try JSONDecoder().decode(AuthSession.self, from: Data(sessionJSON.utf8))
        do {
            try await SupabaseClient(config: config, transport: transport).disableLiveActivityDevice([
                "user_id": .string("old"), "device_id": .string("iphone"), "enabled": .bool(false),
                "updated_at": .string("2026-10-22T01:00:00.001Z"),
            ], session: session)
            XCTFail("Wrong owner must not dispatch a disable")
        } catch is CancellationError {}
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testLogoutRejectedDisableWithExistingRowIsExplicitlyUnconfirmed() async throws {
        let transport = FakeTransport([("[]", 200), (#"[{"user_id":"u1"}]"#, 200)])
        let session = try JSONDecoder().decode(AuthSession.self, from: Data(sessionJSON.utf8))
        do {
            try await SupabaseClient(config: config, transport: transport).disableLiveActivityDevice([
                "user_id": .string("u1"), "device_id": .string("iphone"), "enabled": .bool(false),
                "updated_at": .string("2026-10-22T01:00:00.001Z"),
            ], session: session)
            XCTFail("Missing or rejected row must not report a confirmed disable")
        } catch let error as SupabaseError {
            XCTAssertEqual(error.code, "registration_not_saved")
        }
        XCTAssertEqual(transport.requests.count, 2)
    }

    func testLogoutNeverRegisteredDeviceIsConfirmedByScopedLookup() async throws {
        let transport = FakeTransport([("[]", 200), ("[]", 200)])
        let session = try JSONDecoder().decode(AuthSession.self, from: Data(sessionJSON.utf8))
        try await SupabaseClient(config: config, transport: transport).disableLiveActivityDevice([
            "user_id": .string("u1"), "device_id": .string("iphone"), "enabled": .bool(false),
            "updated_at": .string("2026-10-22T01:00:00.001Z"),
        ], session: session)
        XCTAssertEqual(transport.requests.count, 2)
        XCTAssertEqual(transport.requests.last?.httpMethod, "GET")
        XCTAssertEqual(transport.requests.last?.url?.query, "device_id=eq.iphone&limit=1&select=user_id&user_id=eq.u1")
    }

    func testLogoutLookupFailureDoesNotClaimNeverRegistered() async throws {
        let transport = FakeTransport([("[]", 200), ("", 503)])
        let session = try JSONDecoder().decode(AuthSession.self, from: Data(sessionJSON.utf8))
        do {
            try await SupabaseClient(config: config, transport: transport).disableLiveActivityDevice([
                "user_id": .string("u1"), "device_id": .string("iphone"), "enabled": .bool(false),
                "updated_at": .string("2026-10-22T01:00:00.001Z"),
            ], session: session)
            XCTFail("A failed lookup cannot confirm absence")
        } catch let error as SupabaseError {
            XCTAssertEqual(error.status, 503)
        }
    }
}
