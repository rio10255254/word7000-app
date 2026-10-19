import Foundation
import Observation
import UIKit
import Word7000Core

/// Who the learner is and keeping their progress in the cloud.
///
/// Everyone gets an account: a guest (anonymous) one is created silently on
/// first launch, so progress is backed up from day one. Signing in with
/// Apple, Google or email turns it into a permanent account that works on
/// every device. Local data is always written first; the cloud copy follows
/// in the background and catches up after being offline.
@MainActor
@Observable
final class AccountModel {
    enum Status: Equatable {
        /// No backend configured: everything stays on this iPhone.
        case local
        case loading
        case ready
        case syncing
        case error(String)
    }

    private(set) var status: Status
    private(set) var session: AuthSession?
    private(set) var supportsCustomReminderTime = false
    private(set) var busy = false
    /// A short line for the account section.
    private(set) var message: String

    var configured: Bool { client != nil }
    var isPermanent: Bool { session.map { !$0.user.anonymous } ?? false }
    var email: String? { isPermanent ? session?.user.email : nil }
    var displayName: String? {
        guard isPermanent else { return nil }
        if let name = session?.user.displayName, !name.isEmpty, !name.contains("@") { return name }
        return L.t("我的學習帳號", "My learning account")
    }
    var cloudSyncEnabled: Bool { plus?.decide(.sync) == .allowed }

    /// Uploading to the cloud is a Plus feature after the trial.
    @ObservationIgnored weak var plus: PlusModel?
    private let client: SupabaseClient?
    private unowned let app: AppModel
    @ObservationIgnored private var dirty = SyncDirty()
    @ObservationIgnored private var flushTask: Task<Void, Never>?
    @ObservationIgnored private var flushing = false
    @ObservationIgnored private var retryAttempt = 0
    @ObservationIgnored private var lastHeartbeat: Date?
    @ObservationIgnored private var identityGeneration = 0

    static let redirectURL = "https://word7000-app.rio10255254.workers.dev/auth-native.html"
    private static let sessionKey = "session"

    init(app: AppModel, config: SupabaseConfig? = AccountModel.bundledConfig()) {
        self.app = app
        self.client = config.map { SupabaseClient(config: $0) }
        self.status = config == nil ? .local : .loading
        self.message = config == nil ? A.localOnly : A.preparing
        app.onDataChange = { [weak self] change in self?.enqueue(change) }
    }

    /// Filled in at build time from the EAS "production" environment.
    nonisolated static func bundledConfig() -> SupabaseConfig? {
        let info = Bundle.main.infoDictionary ?? [:]
        let url = info["Word7000SupabaseURL"] as? String
        let publishable = info["Word7000SupabasePublishableKey"] as? String
        let anon = info["Word7000SupabaseAnonKey"] as? String
        return SupabaseConfig(url: url, key: publishable) ?? SupabaseConfig(url: url, key: anon)
    }

    // MARK: Launch

    func bootstrap() async {
        guard let client else { return }
        if ProcessInfo.processInfo.arguments.contains("-uiTestingReset") {
            Keychain.delete(Self.sessionKey)
        }
        status = .loading
        do {
            var restored = storedSession() ?? legacySession()
            if let current = restored, current.needsRefresh() {
                do {
                    restored = try await client.refresh(refreshToken: current.refreshToken)
                } catch let error as SupabaseError where (400..<500).contains(error.status) {
                    restored = nil // revoked or expired: start over as a guest
                } catch {
                    // Offline: keep the old session; requests retry later.
                }
            }
            let session: AuthSession
            if let restored {
                session = restored
            } else {
                session = try await client.signInAnonymously()
            }
            await activate(session)
        } catch {
            status = .error(A.offline)
            message = A.offline
        }
    }

    private func storedSession() -> AuthSession? {
        Keychain.read(Self.sessionKey).flatMap { try? JSONDecoder().decode(AuthSession.self, from: $0) }
    }

    /// The previous React Native app kept its session in AsyncStorage; using
    /// its refresh token keeps guests attached to their cloud data.
    private func legacySession() -> AuthSession? {
        guard let client, app.settings.localOwnerId == nil else { return nil }
        let values = LegacyImport.readAsyncStorage()
        let raw = values[client.config.legacySessionStorageKey]
            ?? values.first(where: { $0.key.hasPrefix("sb-") && $0.key.hasSuffix("-auth-token") })?.value
        guard let raw, var session = try? JSONDecoder().decode(AuthSession.self, from: Data(raw.utf8)) else { return nil }
        session.expiresAt = 0 // always refresh before use
        return session
    }

    private func store(_ session: AuthSession?) {
        if self.session?.user.id != session?.user.id { identityGeneration += 1 }
        self.session = session
        if let session, let data = try? JSONEncoder().encode(session) {
            Keychain.write(data, for: Self.sessionKey)
        } else {
            Keychain.delete(Self.sessionKey)
        }
    }

    // MARK: Activation

    /// Brings local and cloud data together for this user and saves the result
    /// on both sides. Local data from a guest is always carried over; data
    /// left behind by a different permanent account never is.
    private func activate(_ newSession: AuthSession, fallbackEmail: String? = nil) async {
        guard let client else { return }
        if let owner = app.settings.localOwnerId, owner != newSession.user.id {
            guard Outbox(progress: app.progress, customSets: app.customSets).save(userId: owner) else {
                status = .error(A.saveFailed)
                message = A.saveFailed
                return
            }
        }
        flushTask?.cancel()
        var activeSession = newSession
        if activeSession.user.email == nil, let fallbackEmail { activeSession.user.email = fallbackEmail }
        store(activeSession)
        let generation = identityGeneration

        let ownerId = app.settings.localOwnerId
        let carryLocal = ownerId == nil || ownerId == activeSession.user.id || (app.settings.localOwnerIsAnonymous ?? true)
        let outbox = Outbox.load(userId: activeSession.user.id)
        let cloud = try? await client.loadProfile(session: activeSession)
        guard generation == identityGeneration else { return }

        let progress = LearningEngine.merge([cloud?.progress, carryLocal ? app.progress : nil, outbox?.progress])
        let sets = CustomSetState.merge([cloud?.customSets, carryLocal ? app.customSets : nil, outbox?.customSets])
        app.replaceData(progress: progress, customSets: sets, preserveSession: carryLocal)
        app.settings.localOwnerId = activeSession.user.id
        app.settings.localOwnerIsAnonymous = activeSession.user.anonymous
        if !activeSession.user.anonymous { app.settings.permanentAccountUsed = true }

        status = .ready
        message = activeSession.user.anonymous ? A.guestSaved : A.signedIn
        syncTrialStart(session: activeSession)
        dirty = SyncDirty(progress: true, customSets: true)
        await flush()
        heartbeat()
    }

    /// The trial start is kept in the account as well, so a new iPhone or a
    /// reinstall continues the same trial instead of starting a new one.
    private func syncTrialStart(session: AuthSession) {
        guard let client, let plus else { return }
        if case let .number(seconds)? = session.user.userMetadata?["plus_trial_started_at"] {
            plus.mergeAccountTrialStart(Date(timeIntervalSince1970: seconds))
        }
        let start = plus.trialStartedAt.timeIntervalSince1970
        if case let .number(stored)? = session.user.userMetadata?["plus_trial_started_at"], stored <= start { return }
        Task {
            try? await client.updateUserMetadata(["plus_trial_started_at": .number(start)], session: session)
        }
    }

    // MARK: Background sync

    private func enqueue(_ change: SyncDirty) {
        guard client != nil else { return }
        dirty.formUnion(change)
        flushTask?.cancel()
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            await self?.flush()
        }
    }

    /// Uploads whatever changed. On failure the snapshot waits in an outbox
    /// file and is retried with growing delays (3 s … 5 min).
    func flush() async {
        guard let client, let current = session, !flushing, dirty.any else { return }
        guard Outbox(progress: app.progress, customSets: app.customSets).save(userId: current.user.id) else {
            status = .error(A.saveFailed)
            message = A.saveFailed
            return
        }
        if let plus, plus.decide(.sync) != .allowed {
            // Local data is untouched; the changes wait and go up after subscribing.
            status = .ready
            message = P.syncLocked
            return
        }
        flushing = true
        let generation = identityGeneration
        defer {
            flushing = false
            if generation != identityGeneration, dirty.any { enqueue(SyncDirty()) }
        }
        let sending = dirty
        dirty = SyncDirty()
        let progress = app.progress, sets = app.customSets
        status = .syncing
        do {
            let valid = try await validSession(client: client, current)
            try await client.saveProfile(progress: sending.progress ? progress : nil, customSets: sending.customSets ? sets : nil, session: valid)
            guard generation == identityGeneration else { return }
            retryAttempt = 0
            // Keep the local account copy after upload, including after the trial.
            status = .ready
            message = valid.user.anonymous ? A.guestSaved : A.synced
        } catch {
            guard generation == identityGeneration else { return }
            dirty.formUnion(sending)
            status = .error(A.savedLocally)
            message = A.savedLocally
            let delay = min(3.0 * pow(2.0, Double(retryAttempt)), 300)
            retryAttempt += 1
            flushTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                await self?.flush()
            }
        }
    }

    private func validSession(client: SupabaseClient, _ current: AuthSession) async throws -> AuthSession {
        guard session?.user.id == current.user.id else { throw CancellationError() }
        guard current.needsRefresh() else { return current }
        let refreshed = try await client.refresh(refreshToken: current.refreshToken)
        guard session?.user.id == current.user.id else { throw CancellationError() }
        store(refreshed)
        return refreshed
    }

    /// Called when the app goes to the background: finish the upload even if
    /// iOS suspends us right after.
    func flushBeforeBackground() {
        guard dirty.any || flushing else { return }
        let identifier = UIApplication.shared.beginBackgroundTask(withName: "word7000-sync")
        Task {
            await flush()
            UIApplication.shared.endBackgroundTask(identifier)
        }
    }

    /// Counts the learner as active today (guest or signed in).
    func heartbeat() {
        guard let client, let current = session else { return }
        if let last = lastHeartbeat, Date().timeIntervalSince(last) < 60 { return }
        lastHeartbeat = Date()
        let today = DayMath.today()
        Task {
            guard let valid = try? await validSession(client: client, current) else { return }
            try? await client.recordDailyActivity(date: today, session: valid)
        }
    }

    /// Registers this iPhone for server-started lock screen cards.
    func checkReminderSupport() async {
        guard let client, let current = session else { supportsCustomReminderTime = false; return }
        let generation = identityGeneration
        guard let valid = try? await validSession(client: client, current) else { return }
        let supported = await client.supportsCustomReminderTime(session: valid)
        guard generation == identityGeneration else { return }
        supportsCustomReminderTime = supported
    }

    func saveLiveActivityDevice(_ row: [String: JSONValue]) async -> Bool {
        guard let client, let current = session else { return false }
        let generation = identityGeneration
        do {
            let valid = try await validSession(client: client, current)
            guard generation == identityGeneration else { return false }
            try await client.saveLiveActivityDevice(row, session: valid)
            return generation == identityGeneration
        } catch { return false }
    }

    // MARK: Sign in

    /// Sign in with Apple. A guest is linked, so their account (and data)
    /// simply becomes permanent; if that Apple ID already has an account, we
    /// sign into it and carry the guest's progress over.
    func signInWithApple(idToken: String, rawNonce: String, authorizationCode: String?, fullName: PersonNameComponents?, email: String?) async {
        guard let client else { return }
        busy = true
        defer { busy = false }
        message = A.signingIn
        do {
            var newSession: AuthSession
            if let current = session, current.user.anonymous {
                do {
                    newSession = try await client.signInWithIdToken(provider: "apple", idToken: idToken, nonce: rawNonce, accessToken: authorizationCode, linkTo: try await validSession(client: client, current))
                } catch let error as SupabaseError where error.isIdentityAlreadyLinked {
                    newSession = try await client.signInWithIdToken(provider: "apple", idToken: idToken, nonce: rawNonce, accessToken: authorizationCode)
                }
            } else {
                newSession = try await client.signInWithIdToken(provider: "apple", idToken: idToken, nonce: rawNonce, accessToken: authorizationCode)
            }
            if let user = try? await client.user(session: newSession) { newSession.user = user }
            var metadata: [String: JSONValue] = [:]
            if let given = fullName?.givenName, !given.isEmpty { metadata["given_name"] = .string(given) }
            if let family = fullName?.familyName, !family.isEmpty { metadata["family_name"] = .string(family) }
            let full = [fullName?.givenName, fullName?.familyName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
            if !full.isEmpty { metadata["full_name"] = .string(full) }
            if let email, !email.isEmpty { metadata["email"] = .string(email) }
            if !metadata.isEmpty { try? await client.updateUserMetadata(metadata, session: newSession) }
            await activate(newSession, fallbackEmail: email)
        } catch {
            fail(error, fallback: A.appleFailed)
        }
    }

    /// Google sign-in through the web. `authenticate` opens the page and
    /// returns the redirect back into the app.
    func signInWithGoogle(authenticate: (URL) async throws -> URL) async {
        guard let client else { return }
        busy = true
        defer { busy = false }
        message = A.signingIn
        do {
            var linking = false
            var url = client.oauthURL(provider: "google", redirectTo: Self.redirectURL)
            if let current = session, current.user.anonymous, !(app.settings.permanentAccountUsed ?? false) {
                if let linkURL = try? await client.linkIdentityURL(provider: "google", redirectTo: Self.redirectURL, session: try await validSession(client: client, current)) {
                    url = linkURL
                    linking = true
                }
            }
            var callback = AuthCallback(url: try await authenticate(url))
            if linking, callback.isIdentityAlreadyLinked {
                linking = false
                callback = AuthCallback(url: try await authenticate(client.oauthURL(provider: "google", redirectTo: Self.redirectURL)))
            }
            if let error = callback.error { throw SupabaseError(status: 0, code: callback.errorCode, message: error) }
            var newSession: AuthSession
            if let access = callback.accessToken, let refresh = callback.refreshToken {
                let user = try await client.user(session: AuthSession(accessToken: access, refreshToken: refresh, expiresAt: nil, user: AuthUser(id: "")))
                newSession = AuthSession(accessToken: access, refreshToken: refresh, expiresAt: Date().timeIntervalSince1970 + 3000, user: user)
            } else if linking, let current = session {
                newSession = try await client.refresh(refreshToken: current.refreshToken)
            } else {
                throw SupabaseError(status: 0, code: nil, message: A.googleFailed)
            }
            if newSession.user.anonymous { throw SupabaseError(status: 0, code: nil, message: A.googleFailed) }
            await activate(newSession)
        } catch {
            fail(error, fallback: A.googleFailed)
        }
    }

    func signIn(email: String, password: String) async {
        guard let client else { return }
        guard !email.isEmpty, !password.isEmpty else { message = A.enterEmailPassword; return }
        busy = true
        defer { busy = false }
        message = A.signingIn
        do {
            await activate(try await client.signIn(email: email, password: password))
        } catch {
            fail(error, fallback: A.signInFailed)
        }
    }

    func signUp(email: String, password: String) async {
        guard let client else { return }
        guard !email.isEmpty, password.count >= 6 else { message = A.passwordTooShort; return }
        busy = true
        defer { busy = false }
        message = A.creatingAccount
        do {
            if let newSession = try await client.signUp(email: email, password: password) {
                await activate(newSession)
            } else {
                message = A.confirmEmail
            }
        } catch {
            fail(error, fallback: A.signInFailed)
        }
    }

    private func fail(_ error: Error, fallback: String) {
        let text = (error as? SupabaseError)?.message ?? fallback
        status = .error(text)
        message = text
    }

    func noteCancelled() {
        message = A.cancelled
    }

    // MARK: Sign out and delete

    func signOut() async {
        guard let client, let current = session else { return }
        busy = true
        defer { busy = false }
        guard Outbox(progress: app.progress, customSets: app.customSets).save(userId: current.user.id) else {
            status = .error(A.saveFailed)
            message = A.saveFailed
            return
        }
        dirty = SyncDirty(progress: true, customSets: true)
        await flush()
        try? await client.signOut(session: current)
        flushTask?.cancel()
        store(nil)
        dirty = SyncDirty()
        // This iPhone goes back to a fresh guest; the account's data stays in the cloud.
        app.replaceData(progress: ProgressState(dailyTarget: app.progress.dailyTarget), customSets: .empty)
        app.settings.localOwnerId = nil
        app.settings.localOwnerIsAnonymous = true
        message = A.signedOut
        await bootstrap()
    }

    func deleteAccount() async {
        guard let client, let current = session else { return }
        busy = true
        defer { busy = false }
        message = A.deleting
        do {
            try await client.deleteAccount(session: try await validSession(client: client, current))
            Outbox.clear(userId: current.user.id)
            store(nil)
            app.replaceData(progress: ProgressState(dailyTarget: app.progress.dailyTarget), customSets: .empty)
            app.settings.localOwnerId = nil
            app.settings.localOwnerIsAnonymous = true
            message = A.deleted
            await bootstrap()
        } catch {
            fail(error, fallback: A.deleteFailed)
        }
    }
}

/// Changes that have not reached the cloud yet, kept per user on disk.
typealias Outbox = AccountBackup

extension AccountBackup {

    static func load(userId: String) -> Outbox? {
        Persistence.live.load(Self.self, from: fileName(userId: userId))
            ?? Persistence.live.load(Self.self, from: "outbox-\(userId).json")
    }

    @discardableResult
    func save(userId: String) -> Bool {
        Persistence.live.save(self, to: Self.fileName(userId: userId))
    }

    static func clear(userId: String) {
        try? Persistence.live.store.remove(fileName(userId: userId))
        try? Persistence.live.store.remove("outbox-\(userId).json")
    }
}

struct SyncDirty: Equatable {
    var progress = false
    var customSets = false

    var any: Bool { progress || customSets }

    mutating func formUnion(_ other: SyncDirty) {
        progress = progress || other.progress
        customSets = customSets || other.customSets
    }
}

/// Account copy (Chinese interface).
enum A {
    static var localOnly: String { L.t("進度保存在這支 iPhone", "Progress is saved on this iPhone") }
    static var preparing: String { L.t("正在準備…", "Getting ready…") }
    static var guestSaved: String { L.t("進度已自動備份", "Progress backed up automatically") }
    static var signedIn: String { L.t("已登入，正在確認備份", "Signed in; checking backup") }
    static var saveFailed: String { L.t("目前無法儲存，請確認手機空間後重試。", "Unable to save. Check your iPhone storage and try again.") }
    static var synced: String { L.t("已同步", "Synced") }
    static var savedLocally: String { L.t("進度已存在手機，稍後自動同步", "Saved on this iPhone; will sync shortly") }
    static var offline: String { L.t("目前離線，進度先存在手機", "Offline; progress is saved on this iPhone") }
    static var signingIn: String { L.t("登入中…", "Signing in…") }
    static var creatingAccount: String { L.t("建立帳號中…", "Creating account…") }
    static var confirmEmail: String { L.t("請到信箱確認後再登入", "Check your email to confirm, then sign in") }
    static var enterEmailPassword: String { L.t("請輸入 Email 和密碼", "Enter your email and password") }
    static var passwordTooShort: String { L.t("密碼至少 6 個字元", "Password must be at least 6 characters") }
    static var signInFailed: String { L.t("登入失敗，請再試一次", "Sign-in failed. Please try again.") }
    static var appleFailed: String { L.t("Apple 登入失敗，請再試一次", "Sign in with Apple failed. Please try again.") }
    static var googleFailed: String { L.t("Google 登入沒有完成", "Google sign-in did not finish") }
    static var cancelled: String { L.t("已取消登入", "Sign-in cancelled") }
    static var signedOut: String { L.t("已登出", "Signed out") }
    static var deleting: String { L.t("正在刪除帳號與資料…", "Deleting account and data…") }
    static var deleted: String { L.t("帳號已刪除", "Account deleted") }
    static var deleteFailed: String { L.t("刪除失敗，請稍後再試", "Could not delete. Please try again later.") }
}
