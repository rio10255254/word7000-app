import SwiftUI
import UIKit
import UserNotifications
import Word7000Core

/// Push notifications for the developer's messages to everyone (sent by the
/// broadcast-push function). The iPhone's token is registered with the
/// account (a guest's too), with who the learner is (guest, signed in,
/// Premium) and the interface language, so a message can go to some of them
/// and arrive in their language.
@MainActor @Observable
final class PushRegistration {
    static let shared = PushRegistration()

    /// Where registration stands, shown in Settings so a missing push can be
    /// traced to its step: permission, Apple's token, or our server.
    enum Status: Equatable {
        case checking, notAsked, denied, waitingForToken, tokenFailed(String), uploading, failed(String), registered
    }
    private(set) var status: Status = .checking
    @ObservationIgnored weak var account: AccountModel?
    @ObservationIgnored weak var plus: PlusModel?
    @ObservationIgnored private var token: String?
    @ObservationIgnored private var lastUploaded: String?

    func received(token: String) {
        self.token = token
        Task { await upload() }
    }

    func failed(_ error: Error) {
        status = .tokenFailed(String(describing: error).prefix(160).description)
    }

    /// Sends the token with who the learner is now; only when that changed.
    func upload() async {
        guard let token, let account, account.configured else { return }
        let audience = plus?.subscribed == true ? "plus" : (account.isPermanent ? "free" : "guest")
        let language = L.zh ? "zh" : "en"
        let key = "\(token)|\(audience)|\(language)|\(account.session?.user.id ?? "")"
        guard key != lastUploaded else { status = .registered; return }
        status = .uploading
        if let problem = await account.registerPushDevice(token: token, audience: audience, language: language) {
            status = .failed(problem)
        } else {
            lastUploaded = key
            status = .registered
        }
    }

    /// From the Settings row: ask for permission if never asked, then fetch a
    /// fresh token and register it again.
    func retry() async {
        lastUploaded = nil
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            guard granted else { status = .denied; return }
        }
        await refreshIfAllowed()
        if token != nil { await upload() }
    }

    /// Asks once, at a good moment (after a learner's first round), whether
    /// the cat may send notifications.
    func askOnce(_ model: AppModel) async {
        guard !AppRuntime.uiTesting, model.settings.pushAsked != true else { return }
        model.settings.pushAsked = true
        model.scheduleSave()
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if granted { UIApplication.shared.registerForRemoteNotifications() }
    }

    /// On every launch: a learner who allowed notifications keeps a fresh token.
    func refreshIfAllowed() async {
        guard !AppRuntime.uiTesting else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            if token == nil { status = .waitingForToken }
            UIApplication.shared.registerForRemoteNotifications()
        case .denied: status = .denied
        default: status = .notAsked
        }
    }
}

/// Receives the push token, and lets a message show while the app is open.
final class PushAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in PushRegistration.shared.received(token: token) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in PushRegistration.shared.failed(error) }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

/// A Settings row saying whether announcements can reach this iPhone, and
/// what is in the way when they cannot; tapping it tries again.
struct PushStatusRow: View {
    @Environment(\.openURL) private var openURL
    private var push: PushRegistration { .shared }

    var body: some View {
        Button {
            if push.status == .denied, let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            else { Task { await push.retry() } }
        } label: {
            HStack {
                SettingsLabel(L.t("公告推播", "Announcement pushes"), icon: icon, tint: tint)
                Spacer(minLength: 8)
                Text(summary).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.trailing).lineLimit(3)
            }
        }
        .accessibilityIdentifier("settings-push-status")
        .task { await push.refreshIfAllowed() }
    }

    private var summary: String {
        switch push.status {
        case .checking: L.t("檢查中…", "Checking…")
        case .notAsked: L.t("尚未允許，點一下開啟", "Not allowed yet; tap to allow")
        case .denied: L.t("通知已關閉，點一下到設定開啟", "Off; tap to open Settings")
        case .waitingForToken: L.t("等待 Apple 回應…", "Waiting for Apple…")
        case let .tokenFailed(reason): L.t("Apple 未給推播代碼：", "Apple gave no push token: ") + reason
        case .uploading: L.t("登記中…", "Registering…")
        case let .failed(reason): L.t("登記失敗，點一下重試：", "Not registered, tap to retry: ") + reason
        case .registered: L.t("已登記，收得到公告", "Registered")
        }
    }
    private var icon: String { push.status == .registered ? "checkmark.seal.fill" : "exclamationmark.triangle.fill" }
    private var tint: Color { push.status == .registered ? .green : .orange }
}
