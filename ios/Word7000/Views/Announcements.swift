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
        return message.link == "plus" ? L.t("看看 Plus", "See Plus") : L.t("看更多", "Read more")
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
