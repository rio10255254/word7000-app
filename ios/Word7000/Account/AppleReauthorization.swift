import AuthenticationServices
import UIKit

/// Asks Sign in with Apple to confirm once more, for a fresh authorization
/// code (used when deleting the account, so its Apple access is revoked).
@MainActor
final class AppleReauthorization: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    enum Result: Equatable { case code(String), cancelled, unavailable }

    private var continuation: CheckedContinuation<Result, Never>?
    private static var current: AppleReauthorization?

    static func code() async -> Result {
        if AppRuntime.uiTesting { return .unavailable }
        let request = ASAuthorizationAppleIDProvider().createRequest()
        let reauthorization = AppleReauthorization()
        current = reauthorization
        defer { current = nil }
        return await withCheckedContinuation { continuation in
            reauthorization.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = reauthorization
            controller.presentationContextProvider = reauthorization
            controller.performRequests()
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        let code = (authorization.credential as? ASAuthorizationAppleIDCredential)?.authorizationCode
            .flatMap { String(data: $0, encoding: .utf8) }
        MainActor.assumeIsolated { finish(code.map(Result.code) ?? .unavailable) }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let cancelled = (error as? ASAuthorizationError)?.code == .canceled
        MainActor.assumeIsolated { finish(cancelled ? .cancelled : .unavailable) }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first.map { UIWindow(windowScene: $0) } ?? UIWindow()
        }
    }

    private func finish(_ result: Result) {
        continuation?.resume(returning: result)
        continuation = nil
    }
}
