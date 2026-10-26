import Foundation
import Observation
import SwiftUI
import Word7000Core

/// First choice for every AI feature: Anthropic's Claude through the `ai` service.
/// Callers fall back to the on-device model (or to no AI) whenever this throws.
@MainActor @Observable
final class CloudAssistant {
    static let shared = CloudAssistant()

    /// Set at launch; the session it holds signs each request.
    @ObservationIgnored weak var account: AccountModel?
    /// Set at launch; its signed subscription unlocks the Plus model on the server.
    @ObservationIgnored weak var plus: PlusModel?
    private(set) var lastFailure: CloudAI.Failure?
    /// The plan and today's allowance, as the server last reported them.
    private(set) var usage: CloudAI.Usage?
    /// After Claude was rate limited or overloaded, wait a moment before asking again
    /// so learners get the on-device answer quickly instead of another wait.
    @ObservationIgnored private var pausedUntil: Date?

    private init() {}

    private var reachable: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestingReset") { return false }
        #endif
        return account?.canUseCloudAI == true
    }

    /// The online AI could be used once the learner agrees.
    var offered: Bool { reachable && IntelligenceSettings.shared.cloudOffered }
    var needsConsent: Bool { offered && IntelligenceSettings.shared.cloudConsent == nil }
    /// The online AI will be tried for the next request.
    var ready: Bool {
        guard reachable, IntelligenceSettings.shared.cloudAllowed, lastFailure != .quota || !sameDay else { return false }
        return pausedUntil.map { Date() >= $0 } ?? true
    }

    @ObservationIgnored private var quotaDay = DayMath.today()
    private var sameDay: Bool { quotaDay == DayMath.today() }

    func run<Value: Decodable>(_ kind: CloudAI.Kind, _ input: [String: JSONValue], as type: Value.Type = Value.self) async throws -> Value {
        guard ready, let account else { throw CloudAI.Failure.unavailable }
        do {
            let reply = try await account.runAI(kind, input: input, entitlement: plus?.entitlementJWS, as: type)
            lastFailure = nil
            if let usage = reply.usage { self.usage = usage; usageDay = DayMath.today() }
            return reply.value
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            let failure = (error as? CloudAI.Failure) ?? .unavailable
            lastFailure = failure
            switch failure {
            case .busy: pausedUntil = Date().addingTimeInterval(45)
            case .quota:
                quotaDay = DayMath.today()
                if let usage { self.usage = CloudAI.Usage(tier: usage.tier, limit: usage.limit, remaining: 0) }
            case .unavailable: pausedUntil = Date().addingTimeInterval(20)
            case .invalidInput, .signInRequired: break
            }
            throw failure
        }
    }

    /// For the settings screen.
    var statusText: String {
        if !IntelligenceSettings.shared.enabled || !IntelligenceSettings.shared.cloudEnabled { return L.t("已關閉", "Off") }
        if IntelligenceSettings.shared.policy?.cloudEnabled == false { return L.t("暫停中", "Paused") }
        if !reachable { return L.t("連線後可使用", "Available when online") }
        switch IntelligenceSettings.shared.cloudConsent {
        case nil: return L.t("第一次使用時詢問", "Asks before first use")
        case false?: return L.t("只用裝置內 AI", "On-device only")
        case true?:
            if lastFailure == .quota, sameDay { return L.t("今日額度已用完", "Today's allowance used") }
            if lastFailure == .busy { return L.t("使用人數多，暫用裝置內 AI", "Busy, using on-device AI") }
            return planLabel
        }
    }

    @ObservationIgnored private var usageDay = DayMath.today()

    /// False until the server first answers, unless the learner subscribes.
    var tierKnown: Bool { plus?.subscribed == true || usage != nil }

    /// What the learner gets, for settings rows and answer footers.
    var tier: CloudAI.Tier {
        if plus?.subscribed == true { return .plus }
        return usage?.tier ?? .free
    }

    var planLabel: String {
        switch tier {
        case .plus: L.t("Plus・深度思考", "Plus · Deeper reasoning")
        case .trial: L.t("試用・深度思考", "Trial · Deeper reasoning")
        case .free: L.t("免費版・快速回答", "Free · Quick answers")
        }
    }

    /// "12 left today", once the server has said.
    var remainingText: String? {
        guard let usage, usageDay == DayMath.today() else { return nil }
        return L.t("今天還剩 \(usage.remaining) / \(usage.limit) 次", "\(usage.remaining) of \(usage.limit) left today")
    }

    /// Free learners see a gentle nudge toward the Plus model.
    var showsUpgrade: Bool { offered && tierKnown && tier == .free }
}

/// Must match AI_FREE_LIMIT / AI_PLUS_LIMIT on the server (supabase/functions/ai).
enum PlusAI {
    static let freeDaily = 20
    static let plusDaily = 100
}

extension L {
    static var cloudConsentTitle: String { t("使用線上 AI？", "Use online AI?") }
    static var cloudConsentMessage: String {
        t("口說教練、單字解說、測驗講解、掃描整理、單字建議與學習分析可以改用更聰明的線上 AI（Anthropic 的 Claude）。使用時，你輸入或說出的文字與相關單字會傳送到 Anthropic（美國）處理，不包含錄音、帳號名稱或 Email。你隨時可以在「AI 與錄音」關閉。",
          "The speaking coach, word explanations, quiz explanations, scan tidy-up, word suggestions and learning insights can use smarter online AI (Anthropic's Claude). When used, the text you type or say and the related words are sent to Anthropic (USA) for processing, without recordings, your account name or email. You can turn this off anytime in AI and recording.")
    }
    static var cloudConsentAllow: String { t("使用線上 AI", "Use online AI") }
    static var cloudConsentDecline: String { t("只用裝置內", "On-device only") }
}

/// The one-time question before any text is sent to the online AI. Apple asks
/// apps to get this agreement before sharing personal data with a third-party AI.
private struct CloudConsentAlert: ViewModifier {
    @Binding var isPresented: Bool
    var then: () -> Void

    func body(content: Content) -> some View {
        content.alert(L.cloudConsentTitle, isPresented: $isPresented) {
            Button(L.cloudConsentAllow) { IntelligenceSettings.shared.cloudConsent = true; then() }
                .accessibilityIdentifier("cloud-consent-allow")
            Button(L.cloudConsentDecline, role: .cancel) { IntelligenceSettings.shared.cloudConsent = false; then() }
        } message: {
            Text(L.cloudConsentMessage)
        }
    }
}

extension View {
    /// Shows the online AI question; `then` runs after either answer.
    func cloudConsentAlert(isPresented: Binding<Bool>, then: @escaping () -> Void) -> some View {
        modifier(CloudConsentAlert(isPresented: isPresented, then: then))
    }
}
