import Foundation

/// Everyday situations to rehearse out loud (a restaurant, a shop, the
/// clinic…), as short role-plays: someone says a line, the learner says a
/// model reply after it, then answers in their own words. The same lines
/// serve both directions: learners of English say the English, learners of
/// Chinese the Chinese, each with the other as the translation.
/// Source: content/speaking/scenarios.json.
public enum SpeakingScenarios {
    public struct Text: Codable, Equatable, Hashable, Sendable {
        public let zh: String
        public let en: String

        public init(zh: String, en: String) {
            self.zh = zh
            self.en = en
        }

        /// In the language being practised.
        public func practised(_ mode: ConversationPromptMode) -> String { mode == .chinese ? zh : en }
        /// In the learner's own language.
        public func own(_ mode: ConversationPromptMode) -> String { mode == .chinese ? en : zh }
    }

    public struct Turn: Codable, Equatable, Hashable, Sendable {
        /// Who speaks to the learner.
        public let role: Text
        public let partner: Text
        /// The model reply, said after hearing it.
        public let reply: Text
        /// The useful chunk the turn teaches; part of the reply.
        public let key: Text
        /// What to say in one's own words.
        public let task: Text
    }

    public struct Stage: Codable, Equatable, Sendable {
        public let title: Text
        public let turns: [Turn]
    }

    public struct Scenario: Codable, Equatable, Sendable, Identifiable {
        public let id: String
        public let title: Text
        /// An SF Symbol name.
        public let icon: String
        public let stages: [Stage]
    }

    /// One stop on the path: a scenario's stage.
    public struct StageRef: Equatable, Hashable, Sendable {
        public let scenario: Int
        public let stage: Int
        public init(scenario: Int, stage: Int) {
            self.scenario = scenario
            self.stage = stage
        }
    }

    private struct Document: Decodable {
        let schemaVersion: Int
        let scenarios: [Scenario]
    }

    public static let all: [Scenario] = {
        guard let url = Bundle.module.url(forResource: "speaking-scenarios", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let document = try? JSONDecoder().decode(Document.self, from: data), document.schemaVersion == 1 else { return [] }
        return document.scenarios
    }()

    /// Every stage, in path order: each scenario's stages, scenario by scenario.
    public static let path: [StageRef] = all.enumerated().flatMap { scenario, item in
        item.stages.indices.map { StageRef(scenario: scenario, stage: $0) }
    }

    /// How a stage's stars are stored.
    public static func key(_ ref: StageRef) -> String {
        guard all.indices.contains(ref.scenario) else { return "" }
        return "\(all[ref.scenario].id)-\(ref.stage + 1)"
    }

    public static func scenario(_ ref: StageRef) -> Scenario? {
        all.indices.contains(ref.scenario) ? all[ref.scenario] : nil
    }

    public static func stage(_ ref: StageRef) -> Stage? {
        guard let scenario = scenario(ref), scenario.stages.indices.contains(ref.stage) else { return nil }
        return scenario.stages[ref.stage]
    }

    /// The stage's number along the whole path, from 1.
    public static func number(_ ref: StageRef) -> Int { (path.firstIndex(of: ref) ?? 0) + 1 }

    /// The stage to play next: the first not yet cleared; once all are, the
    /// first without three stars; once all have three, the first.
    public static func next(after progress: SpeakingPath.Progress) -> StageRef? {
        path.first { progress.stars(key($0)) == 0 }
            ?? path.first { progress.stars(key($0)) < 3 }
            ?? path.first
    }

    /// A turn as a speaking card: the partner's line is the question.
    public static func card(_ turn: Turn, mode: ConversationPromptMode) -> ConversationPromptCard {
        let key = turn.key.practised(mode)
        return ConversationPromptCard(
            keyword: key,
            keywordPronunciation: mode == .chinese ? ChineseDisplay.sentencePinyin(key) : "",
            question: turn.partner.practised(mode),
            questionSupport: turn.task.own(mode),
            referenceAnswer: turn.reply.practised(mode),
            referenceTranslation: turn.reply.own(mode),
            questionGloss: turn.partner.own(mode)
        )
    }
}
