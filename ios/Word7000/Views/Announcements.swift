import SwiftUI
import UIKit
import Word7000Core

/// Messages from the developer to everyone (the `announcements` table,
/// posted with the "Broadcast a message" workflow). Each is shown once, as a
/// note the cat holds up, the next time the app is opened or comes back.
@MainActor @Observable
final class AnnouncementStore {
    static let shared = AnnouncementStore()
    /// The next message to show, if any.
    var current: Announcement?
    @ObservationIgnored private var lastCheck: Date?
    private static let seenKey = "word7000.seenAnnouncements"

    private var seen: [String] {
        get { UserDefaults.standard.stringArray(forKey: Self.seenKey) ?? [] }
        set { UserDefaults.standard.set(Array(newValue.suffix(200)), forKey: Self.seenKey) }
    }

    /// At most every ten minutes, so coming back to the app is cheap.
    func refresh(account: AccountModel, plus: PlusModel) async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestingAnnouncement") {
            current = Announcement(id: "ui-test", titleZh: "新版口說練習上線了", bodyZh: "每題一頁，按一下就能錄音，錄完自動變成文字，再請小笨貓幫你批改。有任何問題，歡迎在 TestFlight 回報給我們！",
                                   titleEn: "Speaking practice, rebuilt", bodyEn: "One page per question: tap once to record, see it as text, then let Silly Cat check it. Tell us what you think in TestFlight!",
                                   link: "update", linkLabelZh: "更新到最新版", linkLabelEn: "Get the latest version")
            return
        }
        #endif
        guard !AppRuntime.uiTesting, current == nil else { return }
        if let lastCheck, Date().timeIntervalSince(lastCheck) < 600 { return }
        lastCheck = Date()
        let seen = Set(seen)
        let messages = await account.fetchAnnouncements()
        current = messages.first {
            !seen.contains($0.id) && $0.reaches(signedIn: account.isPermanent, plus: plus.subscribed,
                                                tester: PushRegistration.shared.isTester)
                && $0.shows(toVersion: UpdateGate.version, build: UpdateGate.build)
        }
    }

    func markSeen(_ message: Announcement) {
        if !seen.contains(message.id) { seen.append(message.id) }
        if current?.id == message.id { current = nil }
    }
}

/// The oldest version still allowed to run (posted with the "Broadcast a
/// message" workflow's require_version). An older app shows only a way to
/// update, so everyone moves off a broken or retired build.
@MainActor @Observable
final class UpdateGate {
    static let shared = UpdateGate()
    private(set) var required: UpdateRequirement?
    @ObservationIgnored private var lastCheck: Date?

    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0" }
    static var build: Int? { (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String).flatMap(Int.init) }
    static var fromTestFlight: Bool { Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" }
    /// TestFlight for testers, the app's App Store page for everyone else.
    static var storeURL: URL {
        URL(string: fromTestFlight ? "itms-beta://" : "itms-apps://apps.apple.com/app/id6786934889")!
    }

    /// On launch and on coming back: at most every ten minutes while the app
    /// is allowed, every time while it is blocked (so lifting the rule frees
    /// it at once). A check that fails changes nothing, and never blocks.
    func refresh(account: AccountModel) async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestingUpdateRequired") {
            required = UpdateRequirement(minVersion: "99.0")
            return
        }
        #endif
        guard !AppRuntime.uiTesting else { return }
        if required == nil, let lastCheck, Date().timeIntervalSince(lastCheck) < 600 { return }
        lastCheck = Date()
        guard let answer = await account.fetchUpdateRequirement() else { return }
        required = answer.flatMap { $0.blocks(version: Self.version, build: Self.build) ? $0 : nil }
    }
}

/// The shared stage for messages that must be seen: the whole screen, a tag
/// saying what this is, the cat up front, the message on a pinned note (taped
/// paper in the collage, a raised card in leather), and its keys at the
/// bottom. Nothing behind it can be reached until a key is pressed.
struct NoticeStage<Keys: View>: View {
    @Environment(\.appStyle) private var appStyle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var tag: String
    var tagIcon: String
    var tint: Color
    var mood: Mascot.Mood
    var title: String
    var message: String
    @ViewBuilder var keys: Keys
    @State private var bob = false

    private var ink: Color { appStyle == .collage ? Collage.ink : Palette.ink }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 18) {
                    Label(tag, systemImage: tagIcon)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(tint, in: Capsule())
                        .overlay { if appStyle == .collage { Capsule().strokeBorder(Collage.ink.opacity(0.8), lineWidth: 1.5) } }
                        .rotationEffect(.degrees(appStyle == .collage ? -2 : 0))
                        .popIn()
                        .padding(.top, 16)
                        .accessibilityIdentifier("notice-tag")
                    Mascot(mood: mood, size: 128)
                        .offset(y: bob ? -6 : 0)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: bob)
                        .onAppear { bob = true }
                        .popIn(delay: 0.05)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 12) {
                        Text(title)
                            .font(.display(.title2, weight: .bold))
                            .foregroundStyle(ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("notice-title")
                        Text(message)
                            .font(.body)
                            .lineSpacing(3)
                            .foregroundStyle(ink.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("notice-message")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22).padding(.vertical, 24)
                    .background { note }
                    .entrance(1)
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 16)
                // A short message sits in the middle of the screen, not at its top.
                .frame(minHeight: proxy.size.height, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
            }
            VStack(spacing: 10) { keys }
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 10)
                .padding(.bottom, 16)
                .entrance(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { AmbientBackground(tint: tint) }
        .interactiveDismissDisabled()
    }

    @ViewBuilder
    private var note: some View {
        if appStyle == .collage {
            PaperSurface(kind: .ruled)
                .clipShape(TornEdgeShape(edges: [.bottom], depth: 5, seed: 11))
                .overlay { TornEdgeShape(edges: [.bottom], depth: 5, seed: 11).stroke(Collage.ink.opacity(0.35), lineWidth: 0.8) }
                .overlay(alignment: .top) { TapeStrip(width: 84, angle: -3).offset(y: -11) }
                .rotationEffect(.degrees(-0.8))
        } else {
            PremiumSurface(radius: 24)
        }
    }
}

/// One message from the developer over the whole screen: it stays until the
/// learner presses Got it or its link.
struct AnnouncementSheet: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    var message: Announcement
    /// Called when its link asks for the Plus offer.
    var openPlus: () -> Void

    private var title: String { L.zh || message.titleEn.isEmpty ? message.titleZh : message.titleEn }
    private var bodyText: String { L.zh || message.bodyEn.isEmpty ? message.bodyZh : message.bodyEn }
    private var linkLabel: String {
        let label = L.zh || message.linkLabelEn.isEmpty ? message.linkLabelZh : message.linkLabelEn
        if !label.isEmpty { return label }
        switch message.link {
        case "plus": return L.t("看看 Premium", "See Premium")
        case "update": return UpdateGate.fromTestFlight ? L.t("到 TestFlight 更新", "Update in TestFlight") : L.t("到 App Store 更新", "Update in the App Store")
        default: return L.t("看更多", "Read more")
        }
    }

    var body: some View {
        NoticeStage(tag: L.t("小笨貓公告", "From Silly Cat"), tagIcon: "megaphone.fill", tint: Palette.accent,
                    mood: .happy, title: title, message: bodyText) {
            if let link = message.link {
                Button {
                    dismiss()
                    if link == "plus" {
                        openPlus()
                    } else if link == "update" {
                        openURL(UpdateGate.storeURL)
                    } else if let url = URL(string: link), url.scheme == "https" {
                        openURL(url)
                    }
                } label: {
                    Text(linkLabel).font(.headline).frame(maxWidth: .infinity)
                }
                .prominentAction()
                .accessibilityIdentifier("announcement-link")
            }
            Button { dismiss() } label: {
                Text(L.t("知道了", "Got it")).font(.headline).frame(maxWidth: .infinity)
            }
            .modifier(AnnouncementCloseKey(primary: message.link == nil))
            .accessibilityIdentifier("announcement-close")
        }
    }
}

/// Got it is the main key when the message has no link of its own.
private struct AnnouncementCloseKey: ViewModifier {
    var primary: Bool
    func body(content: Content) -> some View {
        if primary { content.prominentAction() } else { content.secondaryAction() }
    }
}

/// Full screen, with no way past it but updating: TestFlight for testers,
/// the App Store for everyone else.
struct UpdateRequiredView: View {
    @Environment(\.openURL) private var openURL
    var requirement: UpdateRequirement

    private var message: String {
        let custom = L.zh || requirement.messageEn.isEmpty ? requirement.messageZh : requirement.messageEn
        return custom.isEmpty
            ? L.t("這個版本已經停止使用。更新到最新版就能繼續學習，你的進度都還在。",
                  "This version is no longer supported. Update to the latest one to keep learning; your progress is safe.")
            : custom
    }

    var body: some View {
        NoticeStage(tag: L.t("需要更新", "Update required"), tagIcon: "arrow.down.app.fill", tint: Palette.miss,
                    mood: .encourage, title: L.t("請更新單字貓", "Please update WordCat"), message: message) {
            Button { openURL(UpdateGate.storeURL) } label: {
                Label(UpdateGate.fromTestFlight ? L.t("到 TestFlight 更新", "Update in TestFlight") : L.t("到 App Store 更新", "Update in the App Store"),
                      systemImage: "arrow.down.circle.fill")
                    .font(.headline).frame(maxWidth: .infinity)
            }
            .prominentAction()
            .accessibilityIdentifier("update-required-open")
            Text(L.t("目前版本 \(UpdateGate.version) (\(UpdateGate.build.map(String.init) ?? "?"))",
                     "This version: \(UpdateGate.version) (\(UpdateGate.build.map(String.init) ?? "?"))"))
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// A window above the app's own, so the update screen covers every sheet,
/// alert and full-screen practice, and nothing can be opened over it.
@MainActor
final class UpdateWindow {
    static let shared = UpdateWindow()
    private var window: UIWindow?

    func show(_ requirement: UpdateRequirement, style: AppStyle, scheme: ColorScheme?) {
        let root = AnyView(UpdateRequiredView(requirement: requirement)
            .environment(\.appStyle, style)
            .environment(\.locale, Locale(identifier: L.zh ? "zh_Hant_TW" : "en_US"))
            .tint(Palette.accent))
        if let host = window?.rootViewController as? UIHostingController<AnyView> {
            host.rootView = root
            return
        }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else { return }
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.rootViewController = UIHostingController(rootView: root)
        if let scheme { window.overrideUserInterfaceStyle = scheme == .dark ? .dark : .light }
        window.makeKeyAndVisible()
        self.window = window
    }

    func hide() {
        window?.isHidden = true
        window = nil
    }
}
