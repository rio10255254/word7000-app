import Foundation
import Observation
import Word7000Core
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor @Observable
final class AppleSpeakingCoach {
    static let shared = AppleSpeakingCoach()

    enum Availability: Equatable {
        case unsupported, disabled, preparing, unsupportedLanguage, unavailable, paused, ready

        var showsEntry: Bool { self != .unsupported }
    }

    private(set) var availability: Availability = .unsupported
    private(set) var isBusy = false

    private init() { refreshAvailability() }

    func refreshAvailability() {
        guard IntelligenceSettings.shared.coachAllowed else { availability = .paused; return }
        #if DEBUG
        if let fixture {
            availability = fixture == .unavailable ? .disabled : .ready
            return
        }
        #endif
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                availability = model.supportsLocale(Locale(identifier: "en-US"))
                    && model.supportsLocale(Locale(identifier: "zh-Hant-TW")) ? .ready : .unsupportedLanguage
            case .unavailable(.deviceNotEligible): availability = .unsupported
            case .unavailable(.appleIntelligenceNotEnabled): availability = .disabled
            case .unavailable(.modelNotReady): availability = .preparing
            case .unavailable: availability = .unavailable
            @unknown default: availability = .unavailable
            }
            return
        }
        #endif
        availability = .unsupported
    }

    func generate(_ request: SpeakingCoach.Request) async throws -> SpeakingCoach.Feedback {
        try Task.checkCancellation()
        guard !isBusy else { throw SpeakingCoach.Failure.busy }
        refreshAvailability()
        guard availability == .ready else { throw SpeakingCoach.Failure.unavailable }
        let request = try request.validated()
        // Keep the shared lease until the underlying call actually returns, even after cancellation.
        isBusy = true
        defer { isBusy = false }
        #if DEBUG
        if let fixture { return try await generateFixture(request, fixture: fixture) }
        #endif
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            do {
                let session = LanguageModelSession(model: SystemLanguageModel.default, instructions: request.instructions)
                let response = try await session.respond(
                    to: request.prompt(), generating: CoachResponse.self,
                    options: GenerationOptions(temperature: 0.3, maximumResponseTokens: SpeakingCoach.maximumResponseTokens)
                )
                try Task.checkCancellation()
                refreshAvailability()
                guard availability == .ready else { throw SpeakingCoach.Failure.unavailable }
                return try SpeakingCoach.Feedback(
                    rewrite: response.content.rewrite, tip: response.content.tip, followUp: response.content.followUp,
                    corrections: response.content.corrections.map {
                        .init(original: $0.original, replacement: $0.replacement, reason: $0.reason)
                    }
                ).validated(answer: request.answer)
            } catch {
                try Task.checkCancellation()
                if error is CancellationError { throw CancellationError() }
                refreshAvailability()
                guard availability == .ready else { throw SpeakingCoach.Failure.unavailable }
                if let failure = error as? SpeakingCoach.Failure { throw failure }
                if let failure = error as? LanguageModelSession.GenerationError {
                    switch failure {
                    case .assetsUnavailable, .unsupportedLanguageOrLocale: throw SpeakingCoach.Failure.unavailable
                    case .exceededContextWindowSize: throw SpeakingCoach.Failure.tooLong
                    case .concurrentRequests, .rateLimited: throw SpeakingCoach.Failure.busy
                    default: break
                    }
                }
                throw SpeakingCoach.Failure.generationFailed
            }
        }
        #endif
        throw SpeakingCoach.Failure.unavailable
    }

    #if DEBUG
    enum Fixture: String { case success, commitCorrection, errorOnce, slow, timeout, unavailable }

    private var fixture: Fixture? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-uiTestingCoach"), arguments.indices.contains(index + 1) else { return nil }
        return Fixture(rawValue: arguments[index + 1])
    }

    var testingTimeout: Duration? { fixture == .timeout ? .milliseconds(250) : nil }
    var testingCommittedAnswer: String? {
        fixture == .commitCorrection ? "I practice with my friend every day." : nil
    }
    @ObservationIgnored private var didFailFixture = false

    private func generateFixture(_ request: SpeakingCoach.Request, fixture: Fixture) async throws -> SpeakingCoach.Feedback {
        if fixture == .unavailable { throw SpeakingCoach.Failure.unavailable }
        if fixture == .errorOnce, !didFailFixture {
            didFailFixture = true
            throw SpeakingCoach.Failure.generationFailed
        }
        let delay: Duration = fixture == .slow ? .seconds(4) : (fixture == .timeout ? .seconds(2) : .milliseconds(150))
        try await Task.sleep(for: delay)
        try Task.checkCancellation()
        return try SpeakingCoach.Feedback(
            rewrite: request.mode == .english ? "I enjoy learning something new with my friends." : "我喜歡和朋友一起學習新事物。",
            tip: request.mode == .english ? "已收到：\(request.answer.prefix(200))" : "Received: \(request.answer.prefix(200))",
            followUp: request.mode == .english ? "What would you like to try next?" : "你接下來想嘗試什麼？"
        ).validated()
    }
    #endif
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
private struct CoachResponse {
    @Guide(description: "One natural rewrite of the learner's answer, preserving their meaning, in the language being learned.")
    var rewrite: String
    @Guide(description: "One short, constructive language tip in the interface language, without a score.")
    var tip: String
    @Guide(description: "One brief related follow-up question in the language being learned.")
    var followUp: String
    @Guide(description: "Zero to two clear errors, not stylistic preferences. Empty if the answer is correct or you are uncertain.")
    var corrections: [CoachCorrection]
}

@available(iOS 26.0, *)
@Generable
private struct CoachCorrection {
    @Guide(description: "Exact quote from the student's answer, at most 120 characters. Never invent a quote.")
    var original: String
    @Guide(description: "Correction preserving the learner's meaning, at most 160 characters.")
    var replacement: String
    @Guide(description: "Brief reason in the interface language, at most 180 characters.")
    var reason: String
}
#endif
