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
            case .general: "登入 Word7000"
            case .scan: "登入後就能掃描單字表"
            }
        }

        var body: String {
            switch self {
            case .general: "換手機或重裝 App 時，學習進度、收藏和字庫都會跟著你。"
            case .scan: "掃描的字庫會存在你的帳號，換手機也不會不見。"
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
                            Label("使用 Google 繼續", systemImage: "globe")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .secondaryAction()

                        Button(showEmail ? "收起 Email 登入" : "使用 Email") {
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
                                SecureField("密碼", text: $password)
                                    .textContentType(.password)
                                HStack(spacing: 10) {
                                    Button("註冊") { Task { await account.signUp(email: email.trimmed, password: password); finishIfSignedIn() } }
                                        .secondaryAction()
                                    Button("登入") { Task { await account.signIn(email: email.trimmed, password: password); finishIfSignedIn() } }
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

                    Text("登入後，目前的進度會一起保留。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("稍後") { dismiss() }
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
                        Text(account.displayName ?? "已登入").font(.headline)
                        statusLine
                    }
                }
                .padding(.vertical, 4)
                Button("登出") { confirmSignOut = true }
                    .disabled(account.busy)
            } else {
                Button { signInOpen = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 30))
                            .foregroundStyle(Palette.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("登入或建立帳號").font(.headline).foregroundStyle(.primary)
                            Text("換手機也能保留進度").font(.subheadline).foregroundStyle(.secondary)
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
        .confirmationDialog("要登出嗎？", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("登出", role: .destructive) { Task { await account.signOut() } }
        } message: {
            Text("進度已存在帳號裡，之後登入就會回來。這支 iPhone 會改用新的訪客進度。")
        }
        .alert("刪除帳號與所有資料？", isPresented: $confirmDelete) {
            Button("取消", role: .cancel) {}
            Button("刪除", role: .destructive) { Task { await account.deleteAccount() } }
        } message: {
            Text("學習進度、字庫和每日紀錄都會永久刪除，無法復原。")
        }

        if account.configured, account.session != nil {
            Section {
                Button("刪除帳號與資料", role: .destructive) { confirmDelete = true }
                    .disabled(account.busy)
            } footer: {
                Text("會永久刪除這個帳號的學習進度和字庫，無法復原。")
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
                Image(systemName: "checkmark.icloud").foregroundStyle(Palette.known)
            }
            Text(account.message)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}
