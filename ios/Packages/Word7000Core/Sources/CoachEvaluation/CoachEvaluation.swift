import Foundation
import Word7000Core
#if canImport(FoundationModels)
import FoundationModels
#endif

struct EvaluationCase: Decodable {
    let id: String
    let request: SpeakingCoach.Request
}
struct EvaluationResult: Encodable {
    let id: String
    let feedback: SpeakingCoach.Feedback?
    let error: String?
    let seconds: Double
    let needsHumanReview = true
}

@main
struct CoachEvaluation {
    static func main() async throws {
        let arguments = CommandLine.arguments
        if arguments.count == 2, arguments[1] == "--probe" {
            #if canImport(FoundationModels)
            if #available(macOS 26.0, *) {
                let model = SystemLanguageModel.default
                let status: [String: String] = [
                    "availability": String(describing: model.availability),
                    "english": String(model.supportsLocale(Locale(identifier: "en-US"))),
                    "traditionalChinese": String(model.supportsLocale(Locale(identifier: "zh-Hant-TW"))),
                    "modelCalled": "false"
                ]
                print(String(decoding: try JSONEncoder().encode(status), as: UTF8.self))
                return
            }
            #endif
            print("{\"availability\":\"unsupportedHost\",\"modelCalled\":\"false\"}")
            return
        }
        guard arguments.count == 4, arguments[1] == "--run-on-device" else {
            print("Usage: CoachEvaluation --run-on-device cases.generated.json new-results.jsonl")
            print("Uses Apple Intelligence on this Mac. Artificial test cases only; no cloud model. Results still require human review.")
            return
        }
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            try await run(input: arguments[2], output: arguments[3])
            return
        }
        #endif
        throw EvaluationError.unsupported
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    static func run(input: String, output: String) async throws {
        let model = SystemLanguageModel.default
        guard model.isAvailable, model.supportsLocale(Locale(identifier: "en-US")),
              model.supportsLocale(Locale(identifier: "zh-Hant-TW")) else { throw EvaluationError.unsupported }
        let cases = try JSONDecoder().decode([EvaluationCase].self, from: Data(contentsOf: URL(fileURLWithPath: input)))
        guard cases.count == 200, Set(cases.map(\.id)).count == 200 else { throw EvaluationError.invalidCases }
        let destination = URL(fileURLWithPath: output)
        guard !FileManager.default.fileExists(atPath: destination.path) else { throw EvaluationError.outputExists }
        try Data().write(to: destination, options: .withoutOverwriting)
        let handle = try FileHandle(forWritingTo: destination)
        defer { try? handle.close() }
        for item in cases {
            let start = Date()
            let result: EvaluationResult
            do {
                let request = try item.request.validated()
                // Expected labels/rubrics are never sent to the model.
                let session = LanguageModelSession(model: model, instructions: request.instructions)
                let value = try await session.respond(to: request.prompt(), generating: EvaluationResponse.self,
                    options: GenerationOptions(temperature: 0.3, maximumResponseTokens: SpeakingCoach.maximumResponseTokens)).content
                let feedback = try SpeakingCoach.Feedback(rewrite: value.rewrite, tip: value.tip, followUp: value.followUp,
                    corrections: value.corrections.map { .init(original: $0.original, replacement: $0.replacement, reason: $0.reason) })
                    .validated(answer: request.answer)
                result = .init(id: item.id, feedback: feedback, error: nil, seconds: Date().timeIntervalSince(start))
            } catch {
                result = .init(id: item.id, feedback: nil, error: String(describing: error), seconds: Date().timeIntervalSince(start))
            }
            try handle.write(contentsOf: JSONEncoder().encode(result) + Data([10]))
            try handle.synchronize()
            print("\(item.id): \(result.feedback == nil ? "no valid response" : "awaiting human review")")
            try await Task.sleep(for: .milliseconds(500))
        }
    }
    #endif
}

enum EvaluationError: Error { case unsupported, invalidCases, outputExists }

#if canImport(FoundationModels)
@available(macOS 26.0, *)
@Generable
struct EvaluationResponse {
    @Guide(description: "One natural rewrite of the learner's answer, preserving their meaning, in the language being learned.")
    var rewrite: String
    @Guide(description: "One short, constructive language tip in the interface language, without a score.")
    var tip: String
    @Guide(description: "One brief related follow-up question in the language being learned.")
    var followUp: String
    @Guide(description: "Zero to two clear errors, not stylistic preferences. Empty if the answer is correct or you are uncertain.")
    var corrections: [EvaluationCorrection]
}
@available(macOS 26.0, *)
@Generable
struct EvaluationCorrection {
    @Guide(description: "Exact quote from the student's answer, at most 120 characters. Never invent a quote.")
    var original: String
    @Guide(description: "Correction preserving the learner's meaning, at most 160 characters.")
    var replacement: String
    @Guide(description: "Brief reason in the interface language, at most 180 characters.")
    var reason: String
}
#endif
