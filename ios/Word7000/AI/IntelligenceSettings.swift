import Foundation
import Observation
import Word7000Core

@MainActor @Observable
final class IntelligenceSettings {
    static let shared = IntelligenceSettings()
    var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: "intelligence.enabled") }
    }
    private(set) var policy: IntelligencePolicy?
    private var checking = false
    private var lastCheck: Date?
    var coachAllowed: Bool { enabled && policy?.speakingCoachEnabled != false }
    var scanAllowed: Bool { enabled && policy?.scanAssistantEnabled != false }

    private init() {
        enabled = UserDefaults.standard.object(forKey: "intelligence.enabled") as? Bool ?? true
        policy = UserDefaults.standard.data(forKey: "intelligence.policy").flatMap(IntelligencePolicy.decode)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestingReset") { enabled = true; policy = nil }
        #endif
    }

    func refreshPolicy() async {
        // UI tests never read live configuration or alter production state.
        guard !ProcessInfo.processInfo.arguments.contains("-uiTestingReset"), !checking,
              lastCheck.map({ Date().timeIntervalSince($0) > 21_600 }) ?? true else { return }
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
