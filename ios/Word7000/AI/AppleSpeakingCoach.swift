import Foundation
import Observation
import Word7000Core

/// Speaking suggestions: Premium's online AI (Claude) only. The free app has
/// no AI at all; recording, transcription, shadowing and tones work without it.
@MainActor @Observable
final class AppleSpeakingCoach {
    static let shared = AppleSpeakingCoach()

    enum Availability: Equatable {
        case unsupported, disabled, preparing, unsupportedLanguage, unavailable, paused, ready

        var showsEntry: Bool { self != .unsupported }
    }

    private(set) var availability: Availability = .unsupported
    /// Suggestions come from the online AI.
    private(set) var usesOnline = false
    private(set) var isBusy = false

    private init() { refreshAvailability() }

    func refreshAvailability() {
        guard IntelligenceSettings.shared.coachAllowed else {
            usesOnline = false
            availability = .paused
            return
        }
        #if DEBUG
        if let fixture {
            usesOnline = false
            availability = fixture == .unavailable ? .unsupported : .ready
            return
        }
        #endif
        usesOnline = CloudAssistant.shared.offered
        availability = usesOnline ? .ready : .unsupported
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
        guard CloudAssistant.shared.ready else { throw SpeakingCoach.Failure.unavailable }
        do {
            let feedback = try await CloudAssistant.shared.run(.coach, request.cloudInput, as: SpeakingCoach.Feedback.self)
            try Task.checkCancellation()
            return try feedback.validated(for: request)
        } catch {
            try Task.checkCancellation()
            if error is CancellationError { throw CancellationError() }
            if let failure = error as? SpeakingCoach.Failure { throw failure }
            throw (error as? CloudAI.Failure) == .busy ? SpeakingCoach.Failure.busy : SpeakingCoach.Failure.unavailable
        }
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
        let delay: Duration = fixture == .slow ? .seconds(10) : (fixture == .timeout ? .seconds(2) : .milliseconds(150))
        try await Task.sleep(for: delay)
        try Task.checkCancellation()
        return try SpeakingCoach.Feedback(
            rewrite: request.mode == .english ? "I enjoy learning something new with my friends." : "我喜歡和朋友一起學習新事物。",
            tip: request.mode == .english ? "已收到：\(request.answer.prefix(200))" : "Received: \(request.answer.prefix(200))",
            followUp: request.mode == .english ? "What would you like to try next?" : "你接下來想嘗試什麼？",
            followUpTranslation: request.mode == .english ? "你接下來想嘗試什麼？" : "What would you like to try next?"
        ).validated()
    }
    #endif
}

extension SpeakingCoach.Request {
    /// The fields the online coach needs; the server writes the instructions.
    var cloudInput: [String: JSONValue] {
        ["keyword": .string(keyword), "meaning": .string(meaning), "question": .string(question),
         "context": .string(context), "answer": .string(answer), "mode": .string(mode.rawValue)]
    }
}
