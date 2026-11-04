import Foundation
import Word7000Core
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Small, unseen helps from Apple's on-device model, where an iPhone has
/// one. None of them is a feature: each answers a narrow question quickly or
/// not at all, and every caller already works without it. Nothing it says
/// is shown as AI, and it never changes what the learner said.
@MainActor
enum DeviceAssist {
    /// Whether this iPhone's model can be asked right now.
    static var available: Bool {
        guard !AppRuntime.uiTesting, IntelligenceSettings.shared.enabled else { return false }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) { return SystemLanguageModel.default.isAvailable }
        #endif
        return false
    }

    /// Whether a spoken answer, paused on, already reads as a complete
    /// answer to the question, so listening can end without a long wait.
    /// Nil when there is no answer in time.
    static func seemsFinished(_ text: String, question: String, chinese: Bool) async -> Bool? {
        guard available, !text.isEmpty else { return nil }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return await within(.milliseconds(800)) {
                let session = LanguageModelSession(instructions: """
                You decide whether a language learner has finished saying their answer out loud. \
                Reply complete when the answer is a finished thought that answers the question, \
                even if short or imperfect. Reply incomplete when it stops mid-sentence or \
                plainly trails off (for example ending on "and", "because", "我覺得", "然後").
                """)
                let prompt = "Question: \(question)\nAnswer so far (\(chinese ? "Chinese" : "English")): \(text)"
                let reply = try await session.respond(to: prompt, generating: Completeness.self,
                                                      options: GenerationOptions(temperature: 0))
                return reply.content.complete
            }
        }
        #endif
        return nil
    }

    /// The same words with punctuation, for a transcript that came back
    /// without any. Nil unless the words came back exactly as they were.
    static func punctuate(_ text: String, chinese: Bool) async -> String? {
        guard available, !text.isEmpty, !hasPunctuation(text) else { return nil }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let result = await within(.milliseconds(1500)) { () -> String in
                let session = LanguageModelSession(instructions: """
                Add punctuation to a speech transcript. Do not add, remove, change or reorder \
                any word or character; only insert punctuation\(chinese ? " (full-width Chinese punctuation)" : "") \
                and, in English, capital letters at the start of sentences.
                """)
                return try await session.respond(to: text, options: GenerationOptions(temperature: 0)).content
            }
            guard let result, sameWords(result, text) else { return nil }
            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif
        return nil
    }

    static func hasPunctuation(_ text: String) -> Bool {
        text.contains { ".,!?;:。，！？；：、".contains($0) }
    }

    /// The same letters and characters, ignoring punctuation, spaces and case.
    static func sameWords(_ a: String, _ b: String) -> Bool {
        func bare(_ text: String) -> String {
            String(text.lowercased().filter { $0.isLetter || $0.isNumber || ChineseDisplay.isHan($0) })
        }
        return !bare(a).isEmpty && bare(a) == bare(b)
    }

    /// The answer, or nil when it takes longer than `limit` or fails.
    private static func within<Value: Sendable>(_ limit: Duration, _ work: @escaping @Sendable () async throws -> Value) async -> Value? {
        await withTaskGroup(of: Value?.self) { group in
            group.addTask { try? await work() }
            group.addTask { try? await Task.sleep(for: limit); return nil }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct Completeness {
    @Guide(description: "True when the answer is a finished thought; false when it stops mid-sentence")
    var complete: Bool
}
#endif
