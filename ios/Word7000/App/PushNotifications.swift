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
    /// This iPhone receives messages meant only for test phones.
    private(set) var isTester = UserDefaults.standard.bool(forKey: "push.tester")
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

    /// Long press on the Settings row: this iPhone becomes (or stops being)
    /// a test phone, which alone receives messages sent to test phones.
    func toggleTester() async -> Bool {
        guard let token, let account else { return false }
        let next = !isTester
        guard await account.setPushTester(token: token, on: next) else { return false }
        isTester = next
        UserDefaults.standard.set(next, forKey: "push.tester")
        return true
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

    /// Asks once, right after the app first opens, whether the cat may send
    /// notifications, so announcements reach a learner from the start.
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
    @State private var testerNote: String?
    private var push: PushRegistration { .shared }

    var body: some View {
        // Not a Button: inside a Form a Button takes the touch, and a long
        // press added to it never fired. A plain row takes both gestures.
        HStack {
            SettingsLabel(L.t("公告推播", "Announcement pushes"), icon: icon, tint: tint)
            Spacer(minLength: 8)
            Text(summary + (push.isTester ? L.t("・測試機", " · test phone") : ""))
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.trailing).lineLimit(3)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: tap)
        // For the developer: a long press makes this iPhone a test phone.
        .onLongPressGesture(minimumDuration: 1, perform: toggleTester)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { tap() }
        .alert(testerNote ?? "", isPresented: Binding(get: { testerNote != nil }, set: { if !$0 { testerNote = nil } })) {
            Button(L.t("好", "OK")) { testerNote = nil }
        }
        .accessibilityIdentifier("settings-push-status")
        .task { await push.refreshIfAllowed() }
    }

    private func tap() {
        if push.status == .denied, let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        else { Task { await push.retry() } }
    }

    private func toggleTester() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task {
            let done = await push.toggleTester()
            testerNote = done
                ? (push.isTester ? L.t("這支手機已設為測試機：「只給測試手機」的公告與推播只會送到這裡。", "This iPhone is now a test phone: messages for test phones come only here.")
                                 : L.t("已取消測試機。", "No longer a test phone."))
                : L.t("要先登記成功（顯示「已登記」）才能設為測試機。", "Register first (it must say Registered).")
        }
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
