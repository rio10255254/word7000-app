import MessageUI
import PhotosUI
import SwiftUI
import Word7000Core

/// Report a problem, for everyone: what kind it is, what happened, a
/// screenshot or two, and the app's own details (version, iPhone, iOS) added
/// so the learner need not look them up. It goes out as an email to the
/// support address from the phone's Mail; without Mail, from whatever mail
/// app the phone opens, and failing that it can be copied. Nothing is sent
/// anywhere else.
struct ReportProblemView: View {
    @Environment(AppModel.self) private var model
    @Environment(AccountModel.self) private var account
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var kind: Kind = .bug
    @State private var text = ""
    @State private var picked: [PhotosPickerItem] = []
    @State private var images: [Data] = []
    @State private var mailOpen = false
    @State private var copied = false
    @State private var sent = false
    @FocusState private var typing: Bool

    static let address = "rio10255254@gmail.com"

    enum Kind: String, CaseIterable, Hashable {
        case bug, content, idea, other

        var title: String {
            switch self {
            case .bug: L.t("壞掉了", "Something broke")
            case .content: L.t("內容有錯", "Wrong content")
            case .idea: L.t("建議", "An idea")
            case .other: L.t("其他", "Other")
            }
        }

        var icon: String {
            switch self {
            case .bug: "ladybug.fill"
            case .content: "text.badge.xmark"
            case .idea: "lightbulb.fill"
            case .other: "ellipsis.bubble.fill"
            }
        }
    }

    private var ready: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .center, spacing: 10) {
                        Mascot(mood: sent ? .cheer : .thinking, size: 52)
                        MascotBubble(text: sent
                                     ? L.t("收到！我會盯著工程師修好。", "Got it! I'll make sure it gets fixed.")
                                     : L.t("哪裡怪怪的？跟我說，我去催工程師。", "Something off? Tell me, I'll nag the developer."),
                                     pointing: .leading)
                    }
                    .listRowBackground(Color.clear)
                    .accessibilityElement(children: .combine)
                }

                Section {
                    ChoiceChips(options: Kind.allCases.map { ChoiceOption(value: $0, title: $0.title, icon: $0.icon) },
                                selection: kind, equalWidths: false, identifier: "report-kind") { kind = $0 }
                } header: {
                    Text(L.t("是哪一種？", "What kind?"))
                }

                Section {
                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text(L.t("發生了什麼事？在哪個畫面、做了什麼？", "What happened? On which screen, doing what?"))
                                .foregroundStyle(Palette.tertiaryLabel)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $text)
                            .frame(minHeight: 120)
                            .focused($typing)
                            .scrollContentBackground(.hidden)
                            .accessibilityIdentifier("report-text")
                    }
                    PhotosPicker(selection: $picked, maxSelectionCount: 3, matching: .images) {
                        Label(images.isEmpty ? L.t("附上截圖（選填）", "Add screenshots (optional)")
                                             : L.t("已附 \(images.count) 張截圖", "\(images.count) screenshots added"),
                              systemImage: "photo.on.rectangle.angled")
                    }
                    .accessibilityIdentifier("report-screenshots")
                } header: {
                    Text(L.t("說說看", "Tell us"))
                }

                Section {
                    Text(Self.details(model: model, account: account))
                        .font(.footnote.monospaced())
                        .foregroundStyle(Palette.secondaryLabel)
                        .textSelection(.enabled)
                } header: {
                    Text(L.t("會一起附上", "Added for you"))
                } footer: {
                    Text(L.t("只有這些和你寫的內容，用 Email 寄給開發者，不會傳到其他地方。",
                             "Only these and what you write, sent by email to the developer. Nothing goes anywhere else."))
                }

                Section {
                    Button(action: send) {
                        Label(sent ? L.t("再寄一封", "Send another") : L.t("寄出回報", "Send report"), systemImage: "paperplane.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!ready)
                    .accessibilityIdentifier("report-send")
                    Button {
                        UIPasteboard.general.string = message
                        copied = true
                    } label: {
                        Label(copied ? L.t("已複製，貼到信裡寄給 \(Self.address)", "Copied. Paste it into an email to \(Self.address)")
                                     : L.t("複製內容（不用信箱 App 時）", "Copy instead (no mail app)"),
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.subheadline)
                    }
                    .disabled(!ready)
                    .accessibilityIdentifier("report-copy")
                }
            }
            .navigationTitle(L.t("回報問題", "Report a problem"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.close) { dismiss() }
                        .accessibilityIdentifier("report-close")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L.t("完成", "Done")) { typing = false }
                }
            }
            .task(id: picked) { await loadImages() }
            .sheet(isPresented: $mailOpen) {
                MailComposer(to: Self.address, subject: subject, body: message, images: images) { didSend in
                    mailOpen = false
                    if didSend { sent = true; text = ""; picked = []; images = [] }
                }
                .ignoresSafeArea()
            }
        }
    }

    private var subject: String {
        L.t("單字貓問題回報：\(kind.title)", "WordCat report: \(kind.title)") + " (\(Self.appVersion))"
    }

    private var message: String {
        "\(text.trimmingCharacters(in: .whitespacesAndNewlines))\n\n— — —\n\(L.t("類型", "Kind")): \(kind.title)\n\(Self.details(model: model, account: account))"
    }

    private func send() {
        typing = false
        Usage.log("report_problem", kind.rawValue)
        if MFMailComposeViewController.canSendMail() {
            mailOpen = true
            return
        }
        // No Mail account: whatever mail app the phone uses (screenshots
        // cannot ride along this way, so say so in the message).
        var body = message
        if !images.isEmpty { body += "\n\n" + L.t("（我有截圖，會另外附上）", "(I have screenshots and will attach them)") }
        var parts = URLComponents()
        parts.scheme = "mailto"
        parts.path = Self.address
        parts.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
        guard let url = parts.url else {
            UIPasteboard.general.string = message
            copied = true
            return
        }
        openURL(url) { opened in
            // No mail app at all: the report is copied to paste anywhere.
            if !opened {
                UIPasteboard.general.string = message
                copied = true
            }
        }
    }

    private func loadImages() async {
        var loaded: [Data] = []
        for item in picked {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.7) else { continue }
            loaded.append(jpeg)
        }
        images = loaded
    }

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    /// The app's own details: what a report needs to be reproduced, and
    /// nothing that says who the learner is.
    @MainActor static func details(model: AppModel, account: AccountModel) -> String {
        var machine = utsname()
        uname(&machine)
        let model_ = withUnsafeBytes(of: &machine.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
        let accountKind = !account.configured ? "-" : account.isPermanent ? L.t("Apple 帳號", "Apple account") : L.t("訪客", "Guest")
        return [
            "App: \(appVersion)",
            "iOS: \(UIDevice.current.systemVersion)",
            "\(L.t("機型", "Device")): \(model_)",
            "\(L.t("學習", "Learning")): \(model.studyMode == .english ? "English" : "中文") · \(model.bankName)",
            "\(L.t("版面", "Layout")): \(model.classicLayout ? L.t("經典", "Classic") : L.t("新版", "New"))",
            "\(L.t("帳號", "Account")): \(accountKind)",
        ].joined(separator: "\n")
    }
}

/// The system's mail sheet, with the report filled in.
private struct MailComposer: UIViewControllerRepresentable {
    var to: String
    var subject: String
    var body: String
    var images: [Data]
    var done: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(done: done) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mail = MFMailComposeViewController()
        mail.mailComposeDelegate = context.coordinator
        mail.setToRecipients([to])
        mail.setSubject(subject)
        mail.setMessageBody(body, isHTML: false)
        for (index, image) in images.enumerated() {
            mail.addAttachmentData(image, mimeType: "image/jpeg", fileName: "screenshot-\(index + 1).jpg")
        }
        return mail
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let done: (Bool) -> Void
        init(done: @escaping (Bool) -> Void) { self.done = done }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            done(result == .sent)
        }
    }
}
