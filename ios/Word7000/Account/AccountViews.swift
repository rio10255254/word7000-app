import AuthenticationServices
import CryptoKit
import SwiftUI
import Word7000Core

/// Sign in with Apple first, Google second, email tucked away.
struct SignInSheet: View {
    enum Reason {
        case general, scan

        var title: String {
            switch self {
            case .general: L.t("登入 Word7000", "Sign in to Word7000")
            case .scan: L.t("登入後就能掃描單字表", "Sign in to scan word lists")
            }
        }

        var body: String {
            switch self {
            case .general: L.t("保留這支手機上的學習紀錄。Plus 與試用期間可同步到其他裝置。", "Keep your learning records on this iPhone. Plus and the trial include sync across devices.")
            case .scan: L.t("將掃描字庫與你的帳號連結。Plus 與試用期間會提供雲端同步。", "Link scanned banks to your account. Cloud sync is included with Plus and during the trial.")
            }
        }

        var icon: String {
            switch self {
            case .general: "icloud.fill"
            case .scan: "doc.text.viewfinder"
            }
        }
    }

    @Environment(AccountModel.self) private var account
    @Environment(\.dismiss) private var dismiss
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @Environment(\.colorScheme) private var colorScheme
    var reason: Reason = .general
    var onSignedIn: () -> Void = {}

    @State private var rawNonce = ""
    @State private var showEmail = false
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: reason.icon)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                        .frame(width: 76, height: 76)
                        .background(Palette.accent.opacity(0.14), in: Circle())
                        .padding(.top, 12)
                    VStack(spacing: 8) {
                        Text(reason.title).font(.rounded(.title2, weight: .bold))
                        Text(reason.body).foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)

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

                        Button {
                            Task { await google() }
                        } label: {
                            Label(L.t("使用 Google 繼續", "Continue with Google"), systemImage: "globe")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .secondaryAction()

                        Button(showEmail ? L.t("收起 Email 登入", "Hide email sign-in") : L.t("使用 Email", "Use email")) {
                            withAnimation(.snappy) { showEmail.toggle() }
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.top, 4)

                        if showEmail {
                            VStack(spacing: 10) {
                                TextField("Email", text: $email)
                                    .textContentType(.username)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                SecureField(L.t("密碼", "Password"), text: $password)
                                    .textContentType(.password)
                                HStack(spacing: 10) {
                                    Button(L.t("註冊", "Sign up")) { Task { await account.signUp(email: email.trimmed, password: password); finishIfSignedIn() } }
                                        .secondaryAction()
                                    Button(L.t("登入", "Sign in")) { Task { await account.signIn(email: email.trimmed, password: password); finishIfSignedIn() } }
                                        .prominentAction()
                                }
                            }
                            .textFieldStyle(.roundedBorder)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .disabled(account.busy || !account.configured)

                    if account.busy {
                        ProgressView()
                    } else if case .error = account.status {
                        Text(account.message).font(.footnote).foregroundStyle(Palette.miss)
                    } else if account.message == A.confirmEmail || account.message == A.cancelled {
                        Text(account.message).font(.footnote).foregroundStyle(.secondary)
                    }

                    Text(L.t("登入後，目前的進度會一起保留。", "Your current progress is kept when you sign in."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("稍後", "Not now")) { dismiss() }
                        .disabled(account.busy)
                }
            }
        }
        .interactiveDismissDisabled(account.busy)
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case let .success(authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken, let idToken = String(data: tokenData, encoding: .utf8)
            else { return }
            let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
            Task {
                await account.signInWithApple(idToken: idToken, rawNonce: rawNonce, authorizationCode: code, fullName: credential.fullName, email: credential.email)
                finishIfSignedIn()
            }
        case let .failure(error):
            if (error as? ASAuthorizationError)?.code == .canceled { account.noteCancelled() }
        }
    }

    private func google() async {
        await account.signInWithGoogle { url in
            do {
                return try await webAuthenticationSession.authenticate(using: url, callbackURLScheme: "word7000", preferredBrowserSession: .ephemeral)
            } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
                await MainActor.run { account.noteCancelled() }
                throw error
            }
        }
        finishIfSignedIn()
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
                            Text(L.t("登入或建立帳號", "Sign in or create an account")).font(.headline).foregroundStyle(.primary)
                            Text(L.t("保留紀錄與管理備份", "Keep records and manage backup")).font(.subheadline).foregroundStyle(.secondary)
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
        .sheet(isPresented: $signInOpen) { SignInSheet() }
        .confirmationDialog(L.t("要登出嗎？", "Sign out?"), isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button(L.t("登出", "Sign out"), role: .destructive) { Task { await account.signOut() } }
        } message: {
            Text(L.t("會先保留這個帳號在本機的紀錄，再切換到訪客。跨裝置備份請確認同步狀態。", "Your account's records will be kept on this iPhone before switching to a guest. Check sync status for backup on other devices."))
        }
        .alert(L.t("刪除帳號與所有資料？", "Delete your account and all data?"), isPresented: $confirmDelete) {
            Button(L.cancel, role: .cancel) {}
            Button(L.t("刪除", "Delete"), role: .destructive) { Task { await account.deleteAccount() } }
        } message: {
            Text(L.t("學習進度、字庫和每日紀錄都會永久刪除，無法復原。", "Progress, banks and daily records are deleted for good. This cannot be undone."))
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

    private var statusLine: some View {
        HStack(spacing: 6) {
            switch account.status {
            case .syncing, .loading:
                ProgressView().controlSize(.mini)
            case .error:
                Image(systemName: "exclamationmark.icloud").foregroundStyle(Palette.review)
            default:
                Image(systemName: account.cloudSyncEnabled ? "checkmark.icloud" : "iphone")
                    .foregroundStyle(account.cloudSyncEnabled ? Palette.known : .secondary)
            }
            Text(account.message)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}
