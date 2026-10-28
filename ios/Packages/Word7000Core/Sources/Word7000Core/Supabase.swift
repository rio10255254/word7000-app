import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Where the account backend lives. The publishable key is public by design;
/// row level security keeps every learner to their own rows.
public struct SupabaseConfig: Equatable, Sendable {
    public var url: URL
    public var key: String

    public init?(url: String?, key: String?) {
        let trimmed = (url ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var normalized = trimmed
        while normalized.hasSuffix("/") { normalized.removeLast() }
        if normalized.lowercased().hasSuffix("/rest/v1") { normalized.removeLast(8) }
        let key = (key ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, !key.isEmpty, !normalized.contains("$("), let parsed = URL(string: normalized), parsed.scheme != nil else {
            return nil
        }
        self.url = parsed
        self.key = key
    }

    /// supabase-js stores its session under `sb-<first host label>-auth-token`.
    public var legacySessionStorageKey: String {
        "sb-\(url.host?.split(separator: ".").first.map(String.init) ?? "")-auth-token"
    }
}

public struct AuthUser: Codable, Equatable, Sendable {
    public var id: String
    public var email: String?
    public var isAnonymous: Bool?
    public var userMetadata: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case id, email
        case isAnonymous = "is_anonymous"
        case userMetadata = "user_metadata"
    }

    public init(id: String, email: String? = nil, isAnonymous: Bool? = nil, userMetadata: [String: JSONValue]? = nil) {
        self.id = id
        self.email = email
        self.isAnonymous = isAnonymous
        self.userMetadata = userMetadata
    }

    public var anonymous: Bool { isAnonymous ?? false }

    public var displayName: String? {
        for key in ["full_name", "name", "given_name"] {
            if case let .string(value)? = userMetadata?[key], !value.isEmpty { return value }
        }
        return nil
    }
}

public struct AuthSession: Codable, Equatable, Sendable {
    public var accessToken: String
    public var refreshToken: String
    /// Seconds since 1970.
    public var expiresAt: Double?
    public var user: AuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case expiresIn = "expires_in"
        case user
    }

    public init(accessToken: String, refreshToken: String, expiresAt: Double?, user: AuthUser) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.user = user
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        refreshToken = try container.decode(String.self, forKey: .refreshToken)
        user = try container.decode(AuthUser.self, forKey: .user)
        if let expiresAt = try container.decodeIfPresent(Double.self, forKey: .expiresAt) {
            self.expiresAt = expiresAt
        } else if let expiresIn = try container.decodeIfPresent(Double.self, forKey: .expiresIn) {
            self.expiresAt = Date().timeIntervalSince1970 + expiresIn
        } else {
            self.expiresAt = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encode(refreshToken, forKey: .refreshToken)
        try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
        try container.encode(user, forKey: .user)
    }

    /// Refresh a minute early so a request never goes out with a token that
    /// expires on the way.
    public func needsRefresh(now: Date = Date()) -> Bool {
        guard let expiresAt else { return true }
        return expiresAt - 60 <= now.timeIntervalSince1970
    }
}

/// Untyped JSON for metadata and error bodies.
public enum JSONValue: Codable, Equatable, Sendable {
    case string(String), number(Double), bool(Bool), object([String: JSONValue]), array([JSONValue]), null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else { self = .array(try container.decode([JSONValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

public struct SupabaseError: Error, Equatable, Sendable {
    public var status: Int
    public var code: String?
    public var message: String

    public init(status: Int, code: String?, message: String) {
        self.status = status
        self.code = code
        self.message = message
    }

    /// "This Google or Apple account already belongs to someone else."
    public var isIdentityAlreadyLinked: Bool {
        if code == "identity_already_exists" { return true }
        let lower = message.lowercased()
        return lower.range(of: #"already (linked|registered)|identity.*another user"#, options: .regularExpression) != nil
    }

    static func from(status: Int, data: Data) -> SupabaseError {
        let object = (try? JSONDecoder().decode([String: JSONValue].self, from: data)) ?? [:]
        func text(_ key: String) -> String? {
            if case let .string(value)? = object[key], !value.isEmpty { return value }
            return nil
        }
        let message = text("error_description") ?? text("msg") ?? text("message") ?? text("error") ?? "HTTP \(status)"
        return SupabaseError(status: status, code: text("error_code") ?? text("code"), message: message)
    }
}

/// Sends one HTTP request. Swapped out in tests.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, Int)
}

public struct URLSessionTransport: HTTPTransport {
    public init() {}

    public func send(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
}

/// The few Supabase endpoints the app uses: Auth (GoTrue), the `profiles`
/// and `daily_active_users` tables (PostgREST) and the `delete-account`
/// function. Written against the HTTP API so the app has no third-party
/// dependency.
public struct SupabaseClient: Sendable {
    public let config: SupabaseConfig
    let transport: HTTPTransport
    let timeout: TimeInterval

    public init(config: SupabaseConfig, transport: HTTPTransport = URLSessionTransport(), timeout: TimeInterval = 15) {
        self.config = config
        self.transport = transport
        self.timeout = timeout
    }

    // MARK: Auth

    public func signInAnonymously() async throws -> AuthSession {
        try await decode(AuthSession.self, request("POST", "auth/v1/signup", body: .object(["data": .object([:])])))
    }

    public func refresh(refreshToken: String) async throws -> AuthSession {
        try await decode(AuthSession.self, request("POST", "auth/v1/token", query: ["grant_type": "refresh_token"], body: .object(["refresh_token": .string(refreshToken)])))
    }

    public func signIn(email: String, password: String) async throws -> AuthSession {
        try await decode(AuthSession.self, request("POST", "auth/v1/token", query: ["grant_type": "password"],
                                                    body: .object(["email": .string(email), "password": .string(password)])))
    }

    /// Returns a session, or nil when the address still has to be confirmed.
    public func signUp(email: String, password: String) async throws -> AuthSession? {
        let data = try await request("POST", "auth/v1/signup", body: .object(["email": .string(email), "password": .string(password)]))
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    /// Sign in with an identity token (Sign in with Apple). With `linkTo`, the
    /// identity is added to that (guest) user instead, keeping its data.
    public func signInWithIdToken(provider: String, idToken: String, nonce: String?, accessToken: String?, linkTo: AuthSession? = nil) async throws -> AuthSession {
        var body: [String: JSONValue] = ["provider": .string(provider), "id_token": .string(idToken)]
        if let nonce { body["nonce"] = .string(nonce) }
        if let accessToken { body["access_token"] = .string(accessToken) }
        if linkTo != nil { body["link_identity"] = .bool(true) }
        return try await decode(AuthSession.self, request("POST", "auth/v1/token", query: ["grant_type": "id_token"], body: .object(body), session: linkTo))
    }

    /// The page to open for an OAuth sign-in (implicit flow: tokens come back
    /// in the redirect's fragment).
    public func oauthURL(provider: String, redirectTo: String) -> URL {
        var components = URLComponents(url: config.url.appendingPathComponent("auth/v1/authorize"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "provider", value: provider),
            URLQueryItem(name: "redirect_to", value: redirectTo),
            URLQueryItem(name: "prompt", value: "select_account"),
        ]
        return components.url!
    }

    /// The page to open to add an OAuth identity to the signed-in user.
    public func linkIdentityURL(provider: String, redirectTo: String, session: AuthSession) async throws -> URL {
        struct Response: Decodable { var url: String }
        let response = try await decode(Response.self, request("GET", "auth/v1/user/identities/authorize", query: [
            "provider": provider, "skip_http_redirect": "true", "redirect_to": redirectTo, "prompt": "select_account",
        ], session: session))
        guard let url = URL(string: response.url) else { throw SupabaseError(status: 0, code: nil, message: "Invalid link URL") }
        return url
    }

    public func user(session: AuthSession) async throws -> AuthUser {
        try await decode(AuthUser.self, request("GET", "auth/v1/user", session: session))
    }

    public func updateUserMetadata(_ data: [String: JSONValue], session: AuthSession) async throws {
        _ = try await request("PUT", "auth/v1/user", body: .object(["data": .object(data)]), session: session)
    }

    /// Emails a link that brings the learner back to the app to choose a new
    /// password. Supabase answers the same whether or not the address exists.
    public func requestPasswordReset(email: String, redirectTo: String) async throws {
        _ = try await request("POST", "auth/v1/recover", query: ["redirect_to": redirectTo], body: .object(["email": .string(email)]))
    }

    /// Sets a new password with the session from a reset link; returns that user.
    public func updatePassword(_ password: String, session: AuthSession) async throws -> AuthUser {
        try await decode(AuthUser.self, request("PUT", "auth/v1/user", body: .object(["password": .string(password)]), session: session))
    }

    public func signOut(session: AuthSession) async throws {
        _ = try await request("POST", "auth/v1/logout", query: ["scope": "local"], session: session)
    }

    // MARK: Data

    public struct Profile: Equatable, Sendable {
        public var found: Bool
        public var progress: ProgressState?
        public var customSets: CustomSetState?
        /// The row's `updated_at` as the server reports it. Every save changes
        /// it, so an unchanged value means no other device has saved since.
        public var version: String?

        public init(found: Bool, progress: ProgressState? = nil, customSets: CustomSetState? = nil, version: String? = nil) {
            self.found = found
            self.progress = progress
            self.customSets = customSets
            self.version = version
        }
    }

    public func loadProfile(session: AuthSession) async throws -> Profile {
        let data = try await request("GET", "rest/v1/profiles", query: ["id": "eq.\(session.user.id)", "select": "progress,custom_sets,updated_at"], session: session)
        let rows = (try? JSONDecoder().decode([[String: JSONValue]].self, from: data)) ?? []
        guard let row = rows.first else { return Profile(found: false) }
        return Profile(found: true, progress: Self.decode(ProgressState.self, row["progress"]),
                       customSets: Self.decode(CustomSetState.self, row["custom_sets"]), version: Self.version(row))
    }

    /// Just the profile's `version`, without downloading the documents; nil
    /// when there is no profile yet.
    public func profileVersion(session: AuthSession) async throws -> String? {
        let data = try await request("GET", "rest/v1/profiles", query: ["id": "eq.\(session.user.id)", "select": "updated_at"], session: session)
        let rows = try decode([[String: JSONValue]].self, data)
        return rows.first.flatMap(Self.version)
    }

    /// Overwrites the learner's documents; either may be left out. Returns the
    /// profile's new `version`, or nil if the server did not report it.
    @discardableResult
    public func saveProfile(progress: ProgressState?, customSets: CustomSetState?, session: AuthSession, now: Date = Date()) async throws -> String? {
        var row: [String: JSONValue] = ["id": .string(session.user.id), "updated_at": .string(DayMath.timestamp(now))]
        if let progress { row["progress"] = try Self.json(progress) }
        if let customSets { row["custom_sets"] = try Self.json(customSets) }
        let data = try await request("POST", "rest/v1/profiles", query: ["on_conflict": "id", "select": "updated_at"], body: .array([.object(row)]),
                                     session: session, headers: ["Prefer": "resolution=merge-duplicates,return=representation"])
        let rows = (try? JSONDecoder().decode([[String: JSONValue]].self, from: data)) ?? []
        return rows.first.flatMap(Self.version)
    }

    private static func version(_ row: [String: JSONValue]) -> String? {
        if case let .string(value)? = row["updated_at"] { return value }
        return nil
    }

    public func recordDailyActivity(date: String, session: AuthSession, now: Date = Date()) async throws {
        let row: [String: JSONValue] = ["user_id": .string(session.user.id), "activity_date": .string(date), "last_seen_at": .string(DayMath.timestamp(now))]
        _ = try await request("POST", "rest/v1/daily_active_users", query: ["on_conflict": "user_id,activity_date"], body: .array([.object(row)]), session: session,
                              headers: ["Prefer": "resolution=merge-duplicates,return=minimal"])
    }

    public func deleteAccount(session: AuthSession) async throws {
        let data = try await request("POST", "functions/v1/delete-account", body: .object([:]), session: session)
        if let object = try? JSONDecoder().decode([String: JSONValue].self, from: data), case let .string(message)? = object["error"] {
            throw SupabaseError(status: 200, code: nil, message: message)
        }
    }

    // MARK: Plumbing

    func request(_ method: String, _ path: String, query: [String: String] = [:], body: JSONValue? = nil, session: AuthSession? = nil, headers: [String: String] = [:]) async throws -> Data {
        var components = URLComponents(url: config.url.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var request = URLRequest(url: components.url!, timeoutInterval: timeout)
        request.httpMethod = method
        request.setValue(config.key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session?.accessToken ?? config.key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        let (data, status) = try await transport.send(request)
        guard (200..<300).contains(status) else { throw SupabaseError.from(status: status, data: data) }
        return data
    }

    func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw SupabaseError(status: 0, code: nil, message: "Unexpected response") }
    }

    static func decode<T: Decodable>(_ type: T.Type, _ value: JSONValue?) -> T? {
        guard let value, let data = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func json<T: Encodable>(_ value: T) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value))
    }
}

/// What an OAuth redirect (`word7000://auth/callback?…#…`) carries. Values may
/// arrive in the query, the fragment or both.
public struct AuthCallback: Equatable, Sendable {
    public var accessToken: String?
    public var refreshToken: String?
    public var code: String?
    public var error: String?
    public var errorCode: String?
    /// "recovery" when the link came from a password reset email.
    public var type: String?

    public init(url: URL) {
        var values: [String: String] = [:]
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        for item in components?.queryItems ?? [] { values[item.name] = item.value }
        if let fragment = components?.fragment {
            var parts = URLComponents()
            parts.query = fragment
            for item in parts.queryItems ?? [] { values[item.name] = item.value }
        }
        accessToken = values["access_token"]
        refreshToken = values["refresh_token"]
        code = values["code"]
        error = values["error_description"] ?? values["error"]
        errorCode = values["error_code"]
        type = values["type"]
    }

    /// A password reset link, carrying a session to set the new password with.
    public var isPasswordRecovery: Bool { type == "recovery" && accessToken != nil && refreshToken != nil }

    public var isIdentityAlreadyLinked: Bool {
        errorCode == "identity_already_exists"
            || (error?.lowercased().range(of: #"already.*(linked|registered)"#, options: .regularExpression) != nil)
    }
}

extension SupabaseClient {
    public func supportsCustomReminderTime(session: AuthSession) async -> Bool {
        do {
            _ = try await request("GET", "rest/v1/live_activity_devices", query: ["select": "reminder_minute", "limit": "0"], session: session)
            return true
        } catch { return false }
    }

    /// Registers (or updates) this device for server-started lock screen
    /// cards; one row per user and device.
    public func saveLiveActivityDevice(_ row: [String: JSONValue], session: AuthSession) async throws {
        var row = row
        if let owner = row["user_id"], owner != .string(session.user.id) { throw CancellationError() }
        row["user_id"] = .string(session.user.id)
        let data = try await request("POST", "rest/v1/live_activity_devices", query: ["on_conflict": "user_id,device_id"], body: .array([.object(row)]), session: session,
                                     headers: ["Prefer": "resolution=merge-duplicates,return=representation"])
        // The server silently ignores stale registrations. HTTP success alone
        // is not an acknowledgment of this snapshot.
        let saved = try decode([[String: JSONValue]].self, data)
        guard saved.count == 1, Self.matchesRegistration(saved[0], snapshot: row) else {
            throw SupabaseError(status: 409, code: "registration_not_saved", message: "Reminder registration was not saved")
        }
    }

    /// Only this account's device is changed; no token or reminder preferences
    /// are needed, and unrelated devices are never disabled.
    public func disableLiveActivityDevice(_ snapshot: [String: JSONValue], session: AuthSession) async throws {
        guard snapshot["user_id"] == .string(session.user.id),
              case let .string(deviceId)? = snapshot["device_id"],
              let timestamp = snapshot["updated_at"], Self.registrationDate(timestamp) != nil,
              snapshot["enabled"] == .bool(false), !Task.isCancelled else { throw CancellationError() }
        let data = try await request("PATCH", "rest/v1/live_activity_devices",
                                     query: ["user_id": "eq.\(session.user.id)", "device_id": "eq.\(deviceId)"],
                                     body: .object(["enabled": .bool(false), "updated_at": timestamp]), session: session,
                                     headers: ["Prefer": "return=representation"])
        let saved = try decode([[String: JSONValue]].self, data)
        guard saved.count == 1, Self.matchesRegistration(saved[0], snapshot: snapshot) else {
            if saved.isEmpty {
                // Empty PATCH means either no registration or a rejected stale
                // write. Only confirmed absence is a successful no-op logout.
                try Task.checkCancellation()
                let existing = try await request("GET", "rest/v1/live_activity_devices",
                                                 query: ["user_id": "eq.\(session.user.id)", "device_id": "eq.\(deviceId)",
                                                         "select": "user_id", "limit": "1"], session: session)
                if try decode([[String: JSONValue]].self, existing).isEmpty { return }
            }
            throw SupabaseError(status: 409, code: "registration_not_saved", message: "Reminder disable was not confirmed")
        }
    }

    private static func matchesRegistration(_ saved: [String: JSONValue], snapshot: [String: JSONValue]) -> Bool {
        guard case .string(_)? = snapshot["device_id"],
              let expectedTime = registrationDate(snapshot["updated_at"]),
              let savedTime = registrationDate(saved["registration_updated_at"] ?? saved["updated_at"]),
              expectedTime == savedTime else { return false }
        // An equal-timestamp retry may return OLD. Verify the entire submitted
        // registration, not just its IDs; cron-only fields are not submitted.
        return snapshot.allSatisfy { key, value in
            if key == "updated_at" || key == "registration_updated_at" { return true }
            if key == "streak_expires_at", value != .null {
                guard let expected = registrationDate(value), let actual = registrationDate(saved[key]) else { return false }
                return expected == actual
            }
            return saved[key] == value
        }
    }

    private static func registrationDate(_ value: JSONValue?) -> Date? {
        guard case let .string(text)? = value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }
}
