import Foundation
import Word7000Core

/// WordCat Next: the scenario conversations, recorded. Every line of every
/// stage, in both languages, was voiced ahead of time (ElevenLabs v4, a voice
/// for each role and one for the learner's side) and ships in the app, so the
/// listening step and the model replies sound like people talking rather than
/// the iPhone's reader. Speaker plays a recording whenever the text it is
/// asked to read is one of these lines, and reads anything else as before.
enum ScenarioVoice {
    /// "en|Just two, thanks." → "restaurant-0-0-reply-en".
    private static let index: [String: String] = {
        var index: [String: String] = [:]
        for scenario in SpeakingScenarios.all {
            for (stageIndex, stage) in scenario.stages.enumerated() {
                for (turnIndex, turn) in stage.turns.enumerated() {
                    for language in ["zh", "en"] {
                        for (kind, line) in [("partner", turn.partner), ("reply", turn.reply)] {
                            let text = language == "zh" ? line.zh : line.en
                            index[key(text, language: language)] = "\(scenario.id)-\(stageIndex)-\(turnIndex)-\(kind)-\(language)"
                        }
                    }
                }
            }
        }
        return index
    }()

    private static func key(_ text: String, language: String) -> String {
        "\(language.prefix(2))|\(text.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    /// The recording of `text` in `language` ("en-US", "zh-TW"), if there is one.
    static func url(for text: String, language: String) -> URL? {
        guard let name = index[key(text, language: language)] else { return nil }
        return Bundle.main.url(forResource: name, withExtension: "mp3")
            ?? Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: "ScenarioAudio")
    }
}
