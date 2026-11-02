import SwiftUI
import UIKit
import UserNotifications
import Word7000Core

/// Push notifications for the developer's messages to everyone (sent by the
/// broadcast-push function). The iPhone's token is registered with the
/// account (a guest's too), with who the learner is (guest, signed in,
/// Premium) and the interface language, so a message can go to some of them
/// and arrive in their language.
@MainActor
final class PushRegistration {
    static let shared = PushRegistration()
    weak var account: AccountModel?
    weak var plus: PlusModel?
    private var token: String?
    private var lastUploaded: String?

    func received(token: String) {
        self.token = token
        Task { await upload() }
    }

    /// Sends the token with who the learner is now; only when that changed.
    func upload() async {
        guard let token, let account, account.configured else { return }
        let audience = plus?.subscribed == true ? "plus" : (account.isPermanent ? "free" : "guest")
        let language = L.zh ? "zh" : "en"
        let key = "\(token)|\(audience)|\(language)|\(account.session?.user.id ?? "")"
        guard key != lastUploaded else { return }
        if await account.registerPushDevice(token: token, audience: audience, language: language) { lastUploaded = key }
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
        if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            UIApplication.shared.registerForRemoteNotifications()
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

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {}

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
