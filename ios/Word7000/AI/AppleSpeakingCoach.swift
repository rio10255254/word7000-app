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
    /// Answers go to Apple's server model rather than staying on this iPhone.
    private(set) var usesCloud = false

    /// Apple's server model (iOS 27) is far stronger than the on-device one
    /// but needs the Private Cloud Compute entitlement. Turn this on only once
    /// Apple has assigned it and it is in Word7000.entitlements.
    private static let privateCloudComputeEntitled = false

    private init() { refreshAvailability() }

    func refreshAvailability() {
        usesCloud = false
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
                usesCloud = availability == .ready && cloudReady
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
                let feedback = try await coach(request)
                try Task.checkCancellation()
                refreshAvailability()
                guard availability == .ready else { throw SpeakingCoach.Failure.unavailable }
                return feedback
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

    #if canImport(FoundationModels)
    /// The on-device model sometimes answers in the wrong language. A fresh
    /// session usually does not, so one more try before giving up.
    @available(iOS 26.0, *)
    private func coach(_ request: SpeakingCoach.Request) async throws -> SpeakingCoach.Feedback {
        for attempt in 1...2 {
            let reply = request.mode == .english
                ? try await respond(request, as: EnglishPracticeReply.self)
                : try await respond(request, as: ChinesePracticeReply.self)
            try Task.checkCancellation()
            do { return try reply.validated(for: request) }
            catch SpeakingCoach.Failure.wrongLanguage where attempt == 1 { continue }
        }
        throw SpeakingCoach.Failure.wrongLanguage
    }

    @available(iOS 26.0, *)
    private func respond<Reply: CoachReply>(_ request: SpeakingCoach.Request, as reply: Reply.Type) async throws -> SpeakingCoach.Feedback {
        let options = GenerationOptions(temperature: 0.3, maximumResponseTokens: SpeakingCoach.maximumResponseTokens)
        #if compiler(>=6.4)
        if #available(iOS 27.0, *), cloudReady {
            do {
                let session = LanguageModelSession(model: PrivateCloudComputeLanguageModel(), instructions: request.instructions)
                return try await session.respond(to: request.prompt(), generating: Reply.self, options: options,
                                                 contextOptions: ContextOptions(includeSchemaInPrompt: true, reasoningLevel: .light)).content.feedback
            } catch {
                // Offline, over the daily limit or a service problem: this
                // iPhone's own model still answers.
                if error is CancellationError || Task.isCancelled { throw error }
            }
        }
        #endif
        let session = LanguageModelSession(model: SystemLanguageModel.default, instructions: request.instructions)
        return try await session.respond(to: request.prompt(), generating: Reply.self, options: options).content.feedback
    }
    #endif

    private var cloudReady: Bool {
        #if compiler(>=6.4) && canImport(FoundationModels)
        if #available(iOS 27.0, *), Self.privateCloudComputeEntitled {
            let model = PrivateCloudComputeLanguageModel()
            return model.isAvailable && !model.quotaUsage.isLimitReached
        }
        #endif
        return false
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
/// One schema per practice language: "the language being learned" was too
/// vague for the on-device model, which then replied in Chinese.
@available(iOS 26.0, *)
private protocol CoachReply: Generable {
    var feedback: SpeakingCoach.Feedback { get }
}

@available(iOS 26.0, *)
@Generable
private struct EnglishPracticeReply {
    @Guide(description: "The student's answer rewritten in natural English, keeping their meaning. A statement that answers the question, never the question itself. English only.")
    var rewrite: String
    @Guide(description: "One short, constructive tip about the student's English, written in Traditional Chinese as used in Taiwan. No score.")
    var tip: String
    @Guide(description: "One brief related follow-up question, in English.")
    var followUp: String
    @Guide(description: "Zero to two clear errors, not stylistic preferences. Empty if the answer is correct or you are uncertain.")
    var corrections: [EnglishCorrection]
}

@available(iOS 26.0, *)
@Generable
private struct EnglishCorrection {
    @Guide(description: "Exact quote from the student's answer, at most 120 characters. Never invent a quote.")
    var original: String
    @Guide(description: "The corrected English, preserving the learner's meaning, at most 160 characters.")
    var replacement: String
    @Guide(description: "Brief reason in Traditional Chinese as used in Taiwan, at most 180 characters.")
    var reason: String
}

@available(iOS 26.0, *)
@Generable
private struct ChinesePracticeReply {
    @Guide(description: "The student's answer rewritten in natural Traditional Chinese as used in Taiwan, keeping their meaning. A statement that answers the question, never the question itself.")
    var rewrite: String
    @Guide(description: "One short, constructive tip about the student's Chinese, written in English. No score.")
    var tip: String
    @Guide(description: "One brief related follow-up question, in Traditional Chinese as used in Taiwan.")
    var followUp: String
    @Guide(description: "Zero to two clear errors, not stylistic preferences. Empty if the answer is correct or you are uncertain.")
    var corrections: [ChineseCorrection]
}

@available(iOS 26.0, *)
@Generable
private struct ChineseCorrection {
    @Guide(description: "Exact quote from the student's answer, at most 120 characters. Never invent a quote.")
    var original: String
    @Guide(description: "The corrected Traditional Chinese, preserving the learner's meaning, at most 160 characters.")
    var replacement: String
    @Guide(description: "Brief reason in English, at most 180 characters.")
    var reason: String
}

@available(iOS 26.0, *)
extension EnglishPracticeReply: CoachReply {
    var feedback: SpeakingCoach.Feedback {
        SpeakingCoach.Feedback(rewrite: rewrite, tip: tip, followUp: followUp, corrections: corrections.map {
            .init(original: $0.original, replacement: $0.replacement, reason: $0.reason)
        })
    }
}

@available(iOS 26.0, *)
extension ChinesePracticeReply: CoachReply {
    var feedback: SpeakingCoach.Feedback {
        SpeakingCoach.Feedback(rewrite: rewrite, tip: tip, followUp: followUp, corrections: corrections.map {
            .init(original: $0.original, replacement: $0.replacement, reason: $0.reason)
        })
    }
}
#endif
