import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The online AI service (the `ai` Supabase function, backed by Anthropic's
/// Claude). The app sends data for one named task; prompts, the model and the
/// Anthropic key stay on the server, which sets how much Claude reasons per tier.
public enum CloudAI {
    /// Who the learner agreed to send text to. The server refuses requests
    /// that name no provider or another one, so a consent given for an earlier
    /// provider never covers this one.
    public static let provider = "anthropic"

    public enum Kind: String, Codable, Sendable {
        case coach, scan, explain, quizWhy, fillWord, insights, ask
    }

    public enum Failure: Error, Equatable, Sendable {
        /// Not set up, offline, or the service is down: use the on-device model.
        case unavailable
        /// Claude is rate limited or overloaded right now.
        case busy
        /// This learner used today's allowance.
        case quota
        case invalidInput
        case signInRequired
    }

    /// Decided by the server: Plus from an Apple-signed subscription, the trial
    /// for 7 days after a learner's first AI request, otherwise free.
    public enum Tier: String, Codable, Sendable {
        case free, trial, plus

        /// Plus and the trial get more reasoning on coaching, explanations and insights.
        public var usesDeeperReasoning: Bool { self != .free }
    }

    /// Where the learner stands today, as the server reported with its last answer.
    public struct Usage: Equatable, Sendable {
        public let tier: Tier
        public let limit: Int
        public let remaining: Int
        public init(tier: Tier, limit: Int, remaining: Int) {
            self.tier = tier; self.limit = limit; self.remaining = remaining
        }
    }

    /// Long enough for the server to try twice.
    public static let timeout: TimeInterval = 30

    /// A word page explanation.
    public struct Explanation: Codable, Equatable, Sendable {
        public struct Example: Codable, Equatable, Sendable {
            public let sentence: String
            public let translation: String
            public init(sentence: String, translation: String) { self.sentence = sentence; self.translation = translation }
        }
        public let summary: String
        public let usage: String
        public let collocations: [String]
        public let examples: [Example]
        public let pitfall: String
        public let memoryTip: String

        public init(summary: String, usage: String, collocations: [String], examples: [Example], pitfall: String, memoryTip: String) {
            self.summary = summary; self.usage = usage; self.collocations = collocations
            self.examples = examples; self.pitfall = pitfall; self.memoryTip = memoryTip
        }

        /// Drops empty pieces and caps lengths so a long reply cannot break the layout.
        public func cleaned() throws -> Explanation {
            let result = Explanation(
                summary: CloudAI.clip(summary, 220), usage: CloudAI.clip(usage, 360),
                collocations: collocations.map { CloudAI.clip($0, 80) }.filter { !$0.isEmpty }.prefix(5).map { $0 },
                examples: examples.map { Example(sentence: CloudAI.clip($0.sentence, 220), translation: CloudAI.clip($0.translation, 220)) }
                    .filter { !$0.sentence.isEmpty }.prefix(3).map { $0 },
                pitfall: CloudAI.clip(pitfall, 300), memoryTip: CloudAI.clip(memoryTip, 200))
            guard !result.summary.isEmpty else { throw Failure.unavailable }
            return result
        }
    }

    /// The tutor's reply to a learner's own question about a word.
    public struct Answer: Codable, Equatable, Sendable {
        /// False when the question was not about the word; the answer then
        /// says what the learner can ask instead.
        public let onTopic: Bool
        public let answer: String
        public let examples: [Explanation.Example]

        public init(onTopic: Bool, answer: String, examples: [Explanation.Example]) {
            self.onTopic = onTopic; self.answer = answer; self.examples = examples
        }

        public func cleaned() throws -> Answer {
            let result = Answer(
                onTopic: onTopic, answer: CloudAI.clip(answer, 420),
                examples: onTopic ? examples.map { Explanation.Example(sentence: CloudAI.clip($0.sentence, 220), translation: CloudAI.clip($0.translation, 220)) }
                    .filter { !$0.sentence.isEmpty }.prefix(2).map { $0 } : [])
            guard !result.answer.isEmpty else { throw Failure.unavailable }
            return result
        }
    }

    /// Why a quiz answer was wrong.
    public struct QuizExplanation: Codable, Equatable, Sendable {
        public let explanation: String
        public let memoryTip: String
        public init(explanation: String, memoryTip: String) { self.explanation = explanation; self.memoryTip = memoryTip }

        public func cleaned() throws -> QuizExplanation {
            let result = QuizExplanation(explanation: CloudAI.clip(explanation, 280), memoryTip: CloudAI.clip(memoryTip, 180))
            guard !result.explanation.isEmpty else { throw Failure.unavailable }
            return result
        }
    }

    /// What the AI read in the learner's recent numbers, for the Me tab.
    public struct Insights: Codable, Equatable, Sendable {
        public struct FocusWord: Codable, Equatable, Sendable {
            public let word: String
            public let tip: String
            public init(word: String, tip: String) { self.word = word; self.tip = tip }
        }

        public let headline: String
        public let summary: String
        public let strengths: [String]
        public let focusWords: [FocusWord]
        public let plan: [String]

        public init(headline: String, summary: String, strengths: [String], focusWords: [FocusWord], plan: [String]) {
            self.headline = headline; self.summary = summary; self.strengths = strengths
            self.focusWords = focusWords; self.plan = plan
        }

        public func cleaned() throws -> Insights {
            let lines = { (items: [String], limit: Int) in
                items.map { CloudAI.clip($0, 160) }.filter { !$0.isEmpty }.prefix(limit).map { $0 }
            }
            let result = Insights(
                headline: CloudAI.clip(headline, 80),
                summary: CloudAI.clip(summary, 360),
                strengths: lines(strengths, 3),
                focusWords: focusWords.map { FocusWord(word: CloudAI.clip($0.word, 60), tip: CloudAI.clip($0.tip, 120)) }
                    .filter { !$0.word.isEmpty }.prefix(5).map { $0 },
                plan: lines(plan, 4)
            )
            guard !result.headline.isEmpty, !result.summary.isEmpty else { throw Failure.unavailable }
            return result
        }
    }

    /// Suggested fields for a word the learner is adding.
    public struct WordSuggestion: Codable, Equatable, Sendable {
        public let meaning: String
        public let partOfSpeech: String
        public let otherMeanings: String
        public let example: String
        public let exampleTranslation: String
        public init(meaning: String, partOfSpeech: String, otherMeanings: String, example: String, exampleTranslation: String) {
            self.meaning = meaning; self.partOfSpeech = partOfSpeech; self.otherMeanings = otherMeanings
            self.example = example; self.exampleTranslation = exampleTranslation
        }

        public func cleaned() -> WordSuggestion {
            WordSuggestion(meaning: CloudAI.clip(meaning, 60), partOfSpeech: CloudAI.clip(partOfSpeech, 20),
                           otherMeanings: CloudAI.clip(otherMeanings, 120), example: CloudAI.clip(example, 240),
                           exampleTranslation: CloudAI.clip(exampleTranslation, 240))
        }
    }

    /// Word / meaning pairs copied from a scanned page; still checked against the page.
    public struct ScanEntries: Codable, Equatable, Sendable {
        public struct Entry: Codable, Equatable, Sendable {
            public let word: String
            public let meaning: String
            public let partOfSpeech: String
            public init(word: String, meaning: String, partOfSpeech: String) { self.word = word; self.meaning = meaning; self.partOfSpeech = partOfSpeech }
        }
        public let entries: [Entry]
        public init(entries: [Entry]) { self.entries = entries }
    }

    static func clip(_ text: String, _ limit: Int) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
    }

    /// Maps the function's error replies (`{"error": "quota"}` and so on).
    static func failure(from error: Error) -> Failure {
        if let failure = error as? Failure { return failure }
        guard let error = error as? SupabaseError else { return .unavailable }
        switch (error.status, error.message) {
        case (_, "quota"): return .quota
        case (_, "busy"): return .busy
        case (400, _): return .invalidInput
        case (401, _): return .signInRequired
        default: return .unavailable
        }
    }
}

/// Generic types cannot be nested in a generic function.
private struct CloudAIReply<Body: Decodable>: Decodable {
    let result: Body
    let tier: CloudAI.Tier?
    let limit: Int?
    let remaining: Int?
}

extension SupabaseClient {
    /// Runs one AI task with the learner's session (a guest session is enough).
    public func runAI<Value: Decodable>(_ task: CloudAI.Kind, input: [String: JSONValue], session: AuthSession,
                                         as type: Value.Type = Value.self) async throws -> Value {
        try await runAI(task, input: input, session: session, entitlement: nil, as: type).value
    }

    /// Runs one AI task and reports today's usage. `entitlement` is the signed
    /// StoreKit transaction of an active Plus subscription, if there is one.
    public func runAI<Value: Decodable>(_ task: CloudAI.Kind, input: [String: JSONValue], session: AuthSession,
                                         entitlement: String?, as type: Value.Type = Value.self) async throws -> (value: Value, usage: CloudAI.Usage?) {
        let client = SupabaseClient(config: config, transport: transport, timeout: CloudAI.timeout)
        var body: [String: JSONValue] = ["task": .string(task.rawValue), "input": .object(input), "consent": .string(CloudAI.provider)]
        if let entitlement { body["entitlement"] = .string(entitlement) }
        do {
            let data = try await client.request("POST", "functions/v1/ai", body: .object(body), session: session)
            let reply = try JSONDecoder().decode(CloudAIReply<Value>.self, from: data)
            let usage = reply.tier.flatMap { tier in
                reply.limit.flatMap { limit in reply.remaining.map { CloudAI.Usage(tier: tier, limit: limit, remaining: $0) } }
            }
            return (reply.result, usage)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if (error as? URLError)?.code == .cancelled { throw CancellationError() }
            throw CloudAI.failure(from: error)
        }
    }
}
