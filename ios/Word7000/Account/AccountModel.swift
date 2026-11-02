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
    /// Progress syncs for anyone signed in with Apple; a guest's stays on
    /// this iPhone.
    var cloudSyncEnabled: Bool { isPermanent }

    /// Told who is signed in, for the trial and for tying purchases to the account.
    @ObservationIgnored weak var plus: PlusModel?
    @ObservationIgnored var beforeSignOut: (@MainActor (String, String) async -> Bool)?
    private let client: SupabaseClient?
    private unowned let app: AppModel
    @ObservationIgnored private var dirty = SyncDirty()
    @ObservationIgnored private var flushTask: Task<Void, Never>?
    @ObservationIgnored private var flushing = false
    @ObservationIgnored private var retryAttempt = 0
    @ObservationIgnored private var lastHeartbeat: Date?
    @ObservationIgnored private var identityGeneration = 0
    /// The cloud profile's version this device last read or wrote. Another
    /// version there means another device saved since.
    @ObservationIgnored private var cloudVersion: String?

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
            // Plus and the trial follow the saved account straight away, not
            // only once the network has answered.
            if let restored { syncTrialStart(session: restored) }
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
        if self.session?.user.id != session?.user.id {
            identityGeneration += 1
            cloudVersion = nil
        }
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
        cloudVersion = cloud?.version
        app.setLocalOwner(activeSession.user.id, anonymous: activeSession.user.anonymous)
        if !activeSession.user.anonymous { app.settings.permanentAccountUsed = true }

        status = .ready
        message = activeSession.user.anonymous ? A.guestSaved : A.signedIn
        syncTrialStart(session: activeSession)
        dirty = SyncDirty(progress: true, customSets: true)
        await flush()
        heartbeat()
    }

    /// Tells Plus and the app who is signed in: Plus is tied to the account,
    /// and a guest's progress is not saved.
    private func syncTrialStart(session: AuthSession) {
        let permanent = !session.user.anonymous
        app.keepsLearningRecords = permanent
        plus?.setAccount(id: permanent ? session.user.id : nil)
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

    /// Uploads whatever changed, after first merging in anything another
    /// device saved since this one last synced: a save replaces the whole
    /// cloud document. `pullingCloud` also checks for such changes when
    /// nothing local is waiting (coming back to the foreground). On failure
    /// the snapshot waits in an outbox file and is retried with growing
    /// delays (3 s … 5 min).
    func flush(pullingCloud: Bool = false) async {
        guard let client, let current = session, !flushing, dirty.any || pullingCloud else { return }
        if dirty.any, isPermanent {
            // Written in the background: this runs after every few graded cards,
            // and encoding the whole history on the main thread stalls the cards.
            Outbox(progress: app.progress, customSets: app.customSets).saveInBackground(userId: current.user.id) { [weak self] saved in
                guard !saved else { return }
                Task { @MainActor in
                    self?.status = .error(A.saveFailed)
                    self?.message = A.saveFailed
                }
            }
        }
        if !isPermanent {
            guard dirty.any else { return }
            // A guest's progress is not kept anywhere; signing in keeps it.
            status = .ready
            message = P.syncLocked
            return
        }
        flushing = true
        let generation = identityGeneration
        var failed = false
        defer {
            flushing = false
            // Changes made while this upload was running wait for the next one;
            // after a failure the scheduled retry carries them.
            if generation != identityGeneration || !failed, dirty.any { enqueue(SyncDirty()) }
        }
        var sending = dirty
        dirty = SyncDirty()
        status = .syncing
        do {
            let valid = try await validSession(client: client, current)
            if try await client.profileVersion(session: valid) != cloudVersion {
                let cloud = try await client.loadProfile(session: valid)
                guard generation == identityGeneration else { return }
                let merged = CloudSync.merge(localProgress: app.progress, localSets: app.customSets, cloud: cloud, today: app.today)
                if merged.changedLocal {
                    app.replaceData(progress: merged.progress, customSets: merged.customSets, preserveSession: true)
                }
                cloudVersion = cloud.version
                if merged.uploadProgress { sending.progress = true }
                if merged.uploadCustomSets { sending.customSets = true }
            }
            if sending.any {
                let version = try await client.saveProfile(progress: sending.progress ? app.progress : nil,
                                                           customSets: sending.customSets ? app.customSets : nil, session: valid)
                guard generation == identityGeneration else { return }
                cloudVersion = version
            }
            retryAttempt = 0
            // Keep the local account copy after upload, including after the trial.
            status = .ready
            message = valid.user.anonymous ? A.guestSaved : A.synced
        } catch {
            guard generation == identityGeneration else { return }
            failed = true
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

    /// The online AI is for learners signed in with Apple; guests have none
    /// (the server refuses them too).
    var canUseCloudAI: Bool { client != nil && isPermanent }

    /// Runs one online AI task with this learner's session; guests count too.
    func runAI<Value: Decodable>(_ kind: CloudAI.Kind, input: [String: JSONValue], entitlement: String?,
                                 as type: Value.Type = Value.self) async throws -> (value: Value, usage: CloudAI.Usage?) {
        guard let client, let current = session else { throw CloudAI.Failure.unavailable }
        let valid: AuthSession
        do { valid = try await validSession(client: client, current) }
        catch is CancellationError { throw CancellationError() }
        catch { throw CloudAI.Failure.unavailable }
        return try await client.runAI(kind, input: input, session: valid, entitlement: entitlement, as: type)
    }

    func saveLiveActivityDevice(_ row: [String: JSONValue]) async -> Bool {
        guard let client, let current = session, !Task.isCancelled else { return false }
        let generation = identityGeneration
        do {
            let valid = try await validSession(client: client, current)
            guard generation == identityGeneration, !Task.isCancelled else { return false }
            try await client.saveLiveActivityDevice(row, session: valid)
            return generation == identityGeneration
        } catch { return false }
    }

    func disableLiveActivityDevice(_ row: [String: JSONValue]) async -> Bool {
        guard let client, let current = session, row["user_id"] == .string(current.user.id), !Task.isCancelled else { return false }
        let generation = identityGeneration
        do {
            let valid = try await validSession(client: client, current)
            guard generation == identityGeneration, !Task.isCancelled else { return false }
            try await client.disableLiveActivityDevice(row, session: valid)
            return generation == identityGeneration && !Task.isCancelled
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
        guard let client, let current = session, !busy else { return }
        busy = true
        defer { busy = false }
        guard Outbox(progress: app.progress, customSets: app.customSets).save(userId: current.user.id) else {
            status = .error(A.saveFailed)
            message = A.saveFailed
            return
        }
        let generation = identityGeneration
        let remindersDisabled = await beforeSignOut?(current.user.id, app.settings.deviceSourceId) ?? false
        guard generation == identityGeneration else { return }
        dirty = SyncDirty(progress: true, customSets: true)
        await flush()
        guard generation == identityGeneration else { return }
        try? await client.signOut(session: current)
        guard generation == identityGeneration else { return }
        flushTask?.cancel()
        store(nil)
        dirty = SyncDirty()
        // This iPhone goes back to a fresh guest; the account's data stays in the cloud.
        app.replaceData(progress: ProgressState(dailyTarget: app.progress.dailyTarget), customSets: .empty)
        app.setLocalOwner(nil, anonymous: true)
        message = A.signedOut
        await bootstrap()
        if !remindersDisabled { message = A.signedOutReminderUnconfirmed }
    }

    func deleteAccount() async {
        guard let client, let current = session else { return }
        busy = true
        defer { busy = false }
        message = A.deleting
        do {
            try await client.deleteAccount(session: try await validSession(client: client, current))
            Outbox.clear(userId: current.user.id)
            app.forgetSpeakingHistory(ownerId: current.user.id, anonymous: current.user.anonymous)
            store(nil)
            app.replaceData(progress: ProgressState(dailyTarget: app.progress.dailyTarget), customSets: .empty)
            app.setLocalOwner(nil, anonymous: true)
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

    /// Writes without waiting. The store writes in order, so a later `load`,
    /// `save` or `clear` still sees this copy.
    func saveInBackground(userId: String, completion: @escaping @Sendable (Bool) -> Void) {
        Persistence.live.store.enqueue(self, to: Self.fileName(userId: userId), completion: completion)
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
    static var guestSaved: String { L.t("訪客：進度不會保存，登入就能保存", "Guest: progress isn't kept; sign in to keep it") }
    static var signedIn: String { L.t("已登入，正在確認備份", "Signed in; checking backup") }
    static var saveFailed: String { L.t("目前無法儲存，請確認手機空間後重試。", "Unable to save. Check your iPhone storage and try again.") }
    static var synced: String { L.t("已同步", "Synced") }
    static var savedLocally: String { L.t("進度已存在手機，稍後自動同步", "Saved on this iPhone; will sync shortly") }
    static var offline: String { L.t("目前離線，進度先存在手機", "Offline; progress is saved on this iPhone") }
    static var signingIn: String { L.t("登入中…", "Signing in…") }
    static var signInFailed: String { L.t("登入失敗，請再試一次", "Sign-in failed. Please try again.") }
    static var appleFailed: String { L.t("Apple 登入失敗，請再試一次", "Sign in with Apple failed. Please try again.") }
    static var cancelled: String { L.t("已取消登入", "Sign-in cancelled") }
    static var signedOut: String { L.t("已登出", "Signed out") }
    static var signedOutReminderUnconfirmed: String { L.t("已登出，但尚未確認停用這支手機的舊帳號提醒。", "Signed out, but reminders for the previous account on this iPhone could not be confirmed off.") }
    static var deleting: String { L.t("正在刪除帳號與資料…", "Deleting account and data…") }
    static var deleted: String { L.t("帳號已刪除", "Account deleted") }
    static var deleteFailed: String { L.t("刪除失敗，請稍後再試", "Could not delete. Please try again later.") }
}
