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
        let transport = FakeTransport([(#"[{"user_id":"u1","device_id":"iphone"}]"#, 201)])
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
}
