import AuthenticationServices
import CryptoKit
import SwiftUI
import Word7000Core

/// Sign in with Apple: the only kind of account. Without one the learner is
/// a guest, with everything for studying on this iPhone but no online AI.
struct SignInSheet: View {
    enum Reason {
        case general, scan, plus, ai

        var title: String {
            switch self {
            case .general: L.t("用 Apple 登入", "Sign in with Apple")
            case .scan: L.t("登入後就能掃描單字表", "Sign in to scan word lists")
            case .plus: L.t("先用 Apple 登入", "Sign in with Apple first")
            case .ai: L.t("登入後就能用 AI", "Sign in to use the AI")
            }
        }

        var body: String {
            switch self {
            case .general: L.t("訪客的進度不會保存。登入後會保存，並同步到你的每一台裝置。", "A guest's progress isn't kept. Signed in, it is kept and synced to every device.")
            case .scan: L.t("掃描是 Premium 功能，掃描的字庫會跟著你的帳號走。先用 Apple 登入。", "Scanning is part of Premium, and scanned banks go with your account. Sign in with Apple first.")
            case .plus: L.t("Premium 綁定你的 Apple ID，換手機登入就會回來，進度也會同步。", "Premium belongs to your Apple ID: sign in on a new iPhone and it is there, with your progress.")
            case .ai: L.t("傻貓的 AI 是 Premium 功能，每天 \(PlusAI.plusDaily) 次。先用 Apple 登入。", "Silly Cat's AI is part of Premium, \(PlusAI.plusDaily) answers a day. Sign in with Apple first.")
            }
        }

        var icon: String {
            switch self {
            case .general: "icloud.fill"
            case .scan: "doc.text.viewfinder"
            case .plus: "sparkles"
            case .ai: "bubble.left.and.text.bubble.right.fill"
            }
        }
    }

    @Environment(AppModel.self) private var model
    @Environment(AccountModel.self) private var account
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var reason: Reason = .general
    var onSignedIn: () -> Void = {}

    @State private var rawNonce = ""
    /// Counts failed sign-ins so the message shakes on each one.
    @State private var failures = 0
    @State private var waved = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: reason.icon)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                        .symbolEffect(.bounce, value: waved)
                        .frame(width: 76, height: 76)
                        .background(Palette.accent.opacity(0.14), in: Circle())
                        // The companion peeking round the badge.
                        .overlay(alignment: .bottomTrailing) {
                            Mascot(mood: .happy, size: 40)
                                .offset(x: 26, y: 6)
                        }
                        .popIn()
                        .padding(.top, 12)
                    VStack(spacing: 8) {
                        Text(reason.title).font(.display(.title2, weight: .bold))
                        Text(reason.body).foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .entrance(1)

                    VStack(spacing: 12) {
                        SignInWithAppleButton(.continue) { request in
                            rawNonce = Self.makeNonce()
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = Self.sha256(rawNonce)
                        } onCompletion: { result in
                            handleApple(result)
                        }
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        .frame(height: 52)
                        .clipShape(Capsule())

                    }
                    .disabled(account.busy || !account.configured)
                    .entrance(2)

                    Group {
                        if account.busy {
                            ProgressView()
                                .transition(.opacity)
                        } else if case .error = account.status {
                            Label {
                                Text(account.message)
                            } icon: {
                                Image(systemName: "exclamationmark.circle.fill")
                            }
                            .font(.footnote)
                            .foregroundStyle(Palette.miss)
                            .shake(trigger: failures, enabled: !reduceMotion)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        } else if account.message == A.cancelled {
                            Text(account.message).font(.footnote).foregroundStyle(.secondary)
                                .transition(.opacity)
                        }
                    }
                    .animation(reduceMotion ? nil : Motion.reveal, value: account.busy)
                    .animation(reduceMotion ? nil : Motion.reveal, value: account.status)

                    Text(L.t("登入後，目前的進度會一起保留。", "Your current progress is kept when you sign in."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
            }
            // On the app's paper, not a blank system sheet.
            .background { AmbientBackground() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("稍後", "Not now")) { dismiss() }
                        .disabled(account.busy)
                }
            }
        }
        .compactSheet()
        .presentationBackground(Palette.background)
        .interactiveDismissDisabled(account.busy)
        .onChange(of: account.status) { _, status in
            if case .error = status { failures += 1 }
        }
        .sensoryFeedback(.error, trigger: failures) { _, _ in model.settings.hapticsEnabled ?? true }
        .sensoryFeedback(.success, trigger: account.isPermanent) { _, new in new && (model.settings.hapticsEnabled ?? true) }
        .task {
            try? await Task.sleep(for: .milliseconds(450))
            if !reduceMotion { waved = true }
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case let .success(authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken, let idToken = String(data: tokenData, encoding: .utf8)
            else {
                Usage.log("sign_in_failed", "no_token")
                account.noteAppleFailure()
                return
            }
            let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
            Task {
                await account.signInWithApple(idToken: idToken, rawNonce: rawNonce, authorizationCode: code, fullName: credential.fullName, email: credential.email)
                finishIfSignedIn()
            }
        case let .failure(error):
            // Apple can fail before WordCat's server is reached (seen on iOS 18:
            // several tries before one works). Say so instead of doing nothing.
            let code = (error as? ASAuthorizationError)?.code
            if code == .canceled {
                account.noteCancelled()
            } else {
                Usage.log("sign_in_failed", "apple_\((error as NSError).code)")
                account.noteAppleFailure()
            }
        }
    }

    private func finishIfSignedIn() {
        guard account.isPermanent else { return }
        dismiss()
        onSignedIn()
    }

    static func makeNonce(length: Int = 32) -> String {
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return String(bytes.map { characters[Int($0) % characters.count] })
    }

    static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// The account rows in "我".
struct AccountSection: View {
    var includeDeletion = false
    @Environment(AccountModel.self) private var account
    @Environment(PlusModel.self) private var plus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var signInOpen = false
    @State private var confirmSignOut = false
    @State private var confirmDelete = false

    var body: some View {
        Section {
            if !account.configured {
                Label(A.localOnly, systemImage: "iphone")
                    .foregroundStyle(.secondary)
            } else if account.isPermanent {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Palette.accent)
                        .popIn()
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.displayName ?? L.t("已登入", "Signed in")).font(.headline).lineLimit(2)
                        statusLine
                    }
                }
                .padding(.vertical, 4)
                Button(L.t("登出", "Sign out")) { confirmSignOut = true }
                    .disabled(account.busy)
            } else {
                Button { signInOpen = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 30))
                            .foregroundStyle(Palette.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L.t("用 Apple 登入", "Sign in with Apple")).font(.headline).foregroundStyle(.primary)
                            Text(L.t("訪客的進度不會保存，登入就能保存並同步", "A guest's progress isn't kept; sign in to keep and sync it")).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .accessibilityIdentifier("me-sign-in")
                statusLine
            }
        } header: {
            Text(L.account)
        }
        .animation(reduceMotion ? nil : Motion.reveal, value: account.isPermanent)
        // Signing out, or deleting the account, lands with a success tap.
        .sensoryFeedback(.success, trigger: account.isPermanent) { old, new in old && !new && Feel.enabled }
        .sheet(isPresented: $signInOpen) { SignInSheet() }
        .warmConfirm(isPresented: $confirmSignOut, title: L.t("要登出嗎？", "Sign out?"),
                     message: L.t("會先保留這個帳號在本機的紀錄，再切換到訪客。跨裝置備份請確認同步狀態。", "Your account's records will be kept on this iPhone before switching to a guest. Check sync status for backup on other devices."),
                     confirmTitle: L.t("登出", "Sign out"), destructive: true, confirmIdentifier: "account-sign-out-confirm") {
            Task { await account.signOut() }
        }
        .warmConfirm(isPresented: $confirmDelete, title: L.t("刪除帳號與所有資料？", "Delete your account and all data?"),
                     message: deleteMessage,
                     confirmTitle: L.t("刪除", "Delete"), destructive: true, confirmIdentifier: "account-delete-confirm",
                     mood: .thinking) {
            Task { await account.deleteAccount() }
        }

        if includeDeletion, account.configured, account.session != nil {
            Section {
                Button(L.t("刪除帳號與資料", "Delete account and data"), role: .destructive) { confirmDelete = true }
                    .disabled(account.busy)
            } footer: {
                Text(L.t("會永久刪除這個帳號的學習進度和字庫，無法復原。", "Permanently deletes this account's progress and banks. This cannot be undone."))
            }
        }
    }

    private var deleteMessage: String {
        (plus.storeSubscribed
         ? L.t("學習進度、字庫和每日紀錄都會永久刪除，無法復原。刪除帳號不會取消 App Store 的 Premium 訂閱，請到「管理訂閱」取消。",
               "Progress, banks and daily records are deleted for good. This cannot be undone. Deleting the account doesn't cancel your App Store Premium subscription; cancel it in Manage subscription.")
         : L.t("學習進度、字庫和每日紀錄都會永久刪除，無法復原。", "Progress, banks and daily records are deleted for good. This cannot be undone."))
            + (account.isPermanent ? L.t("\n接著會請你用 Apple 確認一次，單字貓也會從 Apple 帳號的登入清單移除。", "\nYou'll confirm with Apple once, and WordCat is removed from your Apple Account's sign-in list too.") : "")
    }

    private var statusLine: some View {
        HStack(spacing: 6) {
            switch account.status {
            case .syncing, .loading:
                ProgressView().controlSize(.mini)
            case .error:
                Image(systemName: "exclamationmark.icloud").foregroundStyle(Palette.review)
                    .popIn()
            default:
                // A finished sync lands with a small bounce of the cloud.
                Image(systemName: account.cloudSyncEnabled ? "checkmark.icloud" : "iphone")
                    .foregroundStyle(account.cloudSyncEnabled ? Palette.known : .secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .popIn()
            }
            Text(account.message)
                .contentTransition(.opacity)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .animation(reduceMotion ? nil : Motion.reveal, value: account.status)
    }
}

