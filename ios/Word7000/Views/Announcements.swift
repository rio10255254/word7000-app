import SwiftUI
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
        guard !AppRuntime.uiTesting, current == nil else { return }
        if let lastCheck, Date().timeIntervalSince(lastCheck) < 600 { return }
        lastCheck = Date()
        let seen = Set(seen)
        let messages = await account.fetchAnnouncements()
        current = messages.first { !seen.contains($0.id) && $0.reaches(signedIn: account.isPermanent, plus: plus.subscribed) }
    }

    func markSeen(_ message: Announcement) {
        if !seen.contains(message.id) { seen.append(message.id) }
        if current?.id == message.id { current = nil }
    }
}

/// One message: the cat with a pinned note, a link if it has one, and a
/// button to close it.
struct AnnouncementSheet: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appStyle) private var appStyle
    var message: Announcement
    /// Called when its link asks for the Plus offer.
    var openPlus: () -> Void

    private var title: String { L.zh || message.titleEn.isEmpty ? message.titleZh : message.titleEn }
    private var bodyText: String { L.zh || message.bodyEn.isEmpty ? message.bodyZh : message.bodyEn }
    private var linkLabel: String {
        let label = L.zh || message.linkLabelEn.isEmpty ? message.linkLabelZh : message.linkLabelEn
        if !label.isEmpty { return label }
        return message.link == "plus" ? L.t("看看 Premium", "See Premium") : L.t("看更多", "Read more")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Mascot(mood: .happy, size: 86)
                    .popIn()
                    .padding(.top, 20)
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.display(.title3, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text(bodyText)
                        .font(.body)
                        .foregroundStyle(Palette.ink.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background { note }
                .entrance(1)
                VStack(spacing: 10) {
                    if let link = message.link {
                        Button {
                            dismiss()
                            if link == "plus" {
                                openPlus()
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
                    .secondaryAction()
                    .accessibilityIdentifier("announcement-close")
                }
                .entrance(2)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 24)
        }
        .background { AmbientBackground() }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var note: some View {
        if appStyle == .collage {
            PaperSurface(kind: .ruled)
                .clipShape(TornEdgeShape(edges: [.bottom], depth: 4, seed: 11))
                .overlay(alignment: .top) { TapeStrip(width: 70, angle: -3).offset(y: -10) }
                .rotationEffect(.degrees(-0.6))
        } else {
            PremiumSurface(radius: 22)
        }
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

    /// At most every ten minutes; a failed check never blocks anyone.
    func refresh(account: AccountModel) async {
        guard !AppRuntime.uiTesting else { return }
        if let lastCheck, Date().timeIntervalSince(lastCheck) < 600, required == nil { return }
        lastCheck = Date()
        guard let requirement = await account.fetchUpdateRequirement() else { return }
        required = requirement.blocks(version: Self.version, build: Self.build) ? requirement : nil
    }
}

/// Full screen, with no way past it but updating: TestFlight for testers,
/// the App Store for everyone else.
struct UpdateRequiredView: View {
    @Environment(\.openURL) private var openURL
    var requirement: UpdateRequirement

    private static var fromTestFlight: Bool { Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" }
    private var message: String {
        let custom = L.zh || requirement.messageEn.isEmpty ? requirement.messageZh : requirement.messageEn
        return custom.isEmpty
            ? L.t("這個版本已經不能使用了，更新到最新版就能繼續學習，你的進度都還在。",
                  "This version can no longer be used. Update to the latest one to keep learning; your progress is safe.")
            : custom
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Mascot(mood: .encourage, size: 110).popIn()
            VStack(spacing: 10) {
                Text(L.t("請更新單字貓", "Please update WordCat"))
                    .font(.display(.title2, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("update-required-message")
            }
            Spacer()
            Button {
                let link = Self.fromTestFlight ? "itms-beta://" : "itms-apps://apps.apple.com/app/id6786934889"
                if let url = URL(string: link) { openURL(url) }
            } label: {
                Text(Self.fromTestFlight ? L.t("到 TestFlight 更新", "Update in TestFlight") : L.t("到 App Store 更新", "Update in the App Store"))
                    .font(.headline).frame(maxWidth: .infinity)
            }
            .prominentAction()
            .accessibilityIdentifier("update-required-open")
            Text(L.t("目前版本 \(UpdateGate.version) (\(UpdateGate.build.map(String.init) ?? "?"))",
                     "This version: \(UpdateGate.version) (\(UpdateGate.build.map(String.init) ?? "?"))"))
                .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { AmbientBackground() }
        .interactiveDismissDisabled()
    }
}
