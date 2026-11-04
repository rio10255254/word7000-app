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
    enum Fixture: String { case success, commitCorrection, errorOnce, slow, timeout, unavailable, showcase, showcaseEnglish }

    private var fixture: Fixture? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-uiTestingCoach"), arguments.indices.contains(index + 1) else { return nil }
        return Fixture(rawValue: arguments[index + 1])
    }

    var testingTimeout: Duration? { fixture == .timeout ? .milliseconds(250) : nil }
    var testingCommittedAnswer: String? {
        switch fixture {
        case .commitCorrection: "I practice with my friend every day."
        // A learner of Chinese answering the 貼上 question, with one slip.
        case .showcase: "會，我常常從網路上找資料，然後貼上到我的報告。"
        // A Taiwanese student answering the "improve" question, with two slips.
        case .showcaseEnglish: "I think wake up early can improve my morning, because I am always hurry."
        default: nil
        }
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
        if fixture == .showcaseEnglish {
            return try SpeakingCoach.Feedback(
                rewrite: "Waking up a little earlier would improve my mornings, because I'm always in a rush.",
                tip: "很接近了！動作當主詞時記得加 -ing：Waking up early helps.",
                followUp: "What do you usually do first after you wake up?",
                followUpTranslation: "你起床後通常第一件事做什麼？",
                corrections: [
                    SpeakingCoach.Correction(original: "wake up early", replacement: "Waking up a little earlier",
                                             reason: "當主詞要用動名詞 waking up。"),
                    SpeakingCoach.Correction(original: "I am always hurry", replacement: "I'm always in a rush",
                                             reason: "hurry 是動詞；「很趕」說 in a rush 或 in a hurry。"),
                ]
            ).validated(answer: request.answer)
        }
        if fixture == .showcase {
            // Promotional screenshots: a reply in the shape the coach gives a
            // learner of Chinese (rewrite and follow-up in Chinese, tip in English).
            return try SpeakingCoach.Feedback(
                rewrite: "會啊，我常常上網找資料，再貼到報告裡。",
                tip: "So close. When you say where it goes, drop the 上: 貼到報告裡, not 貼上到.",
                followUp: "你怎麼確定網路上的資料是對的？",
                followUpTranslation: "How do you make sure what you find online is right?",
                corrections: [SpeakingCoach.Correction(original: "貼上到我的報告", replacement: "貼到報告裡",
                                                       reason: "貼上 already means \u{201C}paste\u{201D}; use 貼到 + the place.")]
            ).validated(answer: request.answer)
        }
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
