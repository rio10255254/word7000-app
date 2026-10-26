import Foundation
import Observation
import Word7000Core

@MainActor @Observable
final class IntelligenceSettings {
    static let shared = IntelligenceSettings()
    var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: "intelligence.enabled") }
    }
    /// The learner's switch for the online AI (Claude). On by default, but
    /// nothing is sent until they agree once (`cloudConsent`).
    var cloudEnabled: Bool {
        didSet { UserDefaults.standard.set(cloudEnabled, forKey: "intelligence.cloud") }
    }
    /// nil until the learner answers the one-time question about sending text
    /// to Anthropic. Agreement given for an earlier provider does not count.
    var cloudConsent: Bool? {
        didSet { UserDefaults.standard.set(cloudConsent, forKey: Self.consentKey) }
    }
    private static let consentKey = "intelligence.cloudConsent.anthropic"
    /// The answer about Groq, the earlier provider: only a "no" carries over.
    private static let groqConsentKey = "intelligence.cloudConsent"
    private(set) var policy: IntelligencePolicy?
    private(set) var checking = false
    private var lastCheck: Date?
    var coachAllowed: Bool { enabled && policy?.speakingCoachEnabled != false }
    var scanAllowed: Bool { enabled && policy?.scanAssistantEnabled != false }
    /// Online AI may be offered (consent may still be pending).
    var cloudOffered: Bool { enabled && cloudEnabled && cloudConsent != false && policy?.cloudEnabled != false }
    /// Online AI may be used right now.
    var cloudAllowed: Bool { cloudOffered && cloudConsent == true }

    private init() {
        enabled = UserDefaults.standard.object(forKey: "intelligence.enabled") as? Bool ?? true
        cloudEnabled = UserDefaults.standard.object(forKey: "intelligence.cloud") as? Bool ?? true
        let groqDeclined = UserDefaults.standard.object(forKey: Self.groqConsentKey) as? Bool == false
        cloudConsent = UserDefaults.standard.object(forKey: Self.consentKey) as? Bool ?? (groqDeclined ? false : nil)
        policy = UserDefaults.standard.data(forKey: "intelligence.policy").flatMap(IntelligencePolicy.decode)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestingReset") { enabled = true; cloudEnabled = true; cloudConsent = nil; policy = nil }
        #endif
    }

    func refreshPolicy(force: Bool = false) async {
        // UI tests never read live configuration or alter production state.
        guard !ProcessInfo.processInfo.arguments.contains("-uiTestingReset"), !checking,
              force || (lastCheck.map({ Date().timeIntervalSince($0) > 21_600 }) ?? true) else { return }
        checking = true
        defer { checking = false; lastCheck = Date() }
        let url = URL(string: "https://word7000-app.rio10255254.workers.dev/ai-features.json")!
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        let client = URLSession(configuration: configuration)
        defer { client.invalidateAndCancel() }
        do {
            let (bytes, response) = try await client.bytes(for: URLRequest(url: url, timeoutInterval: 8))
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            var data = Data()
            for try await byte in bytes {
                guard data.count < 4096 else { return }
                data.append(byte)
            }
            guard let value = IntelligencePolicy.decode(data) else { return }
            policy = value
            UserDefaults.standard.set(data, forKey: "intelligence.policy")
        } catch { /* Retain the last valid policy, including a previous disable. */ }
    }
}
