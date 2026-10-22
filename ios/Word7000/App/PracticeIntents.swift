import AppIntents
import Observation

@MainActor @Observable
final class PracticeLaunch {
    static let shared = PracticeLaunch()
    var requested: Activity?
}

struct StartWordPractice: AppIntent {
    static var title: LocalizedStringResource = "Start word practice"
    static var openAppWhenRun: Bool = true
    @MainActor func perform() async throws -> some IntentResult {
        PracticeLaunch.shared.requested = .study
        return .result()
    }
}

struct StartSpeakingPractice: AppIntent {
    static var title: LocalizedStringResource = "Start speaking practice"
    static var openAppWhenRun: Bool = true
    @MainActor func perform() async throws -> some IntentResult {
        PracticeLaunch.shared.requested = .speaking
        return .result()
    }
}

struct StartWordQuiz: AppIntent {
    static var title: LocalizedStringResource = "Start a vocabulary quiz"
    static var openAppWhenRun: Bool = true
    @MainActor func perform() async throws -> some IntentResult {
        PracticeLaunch.shared.requested = .quiz
        return .result()
    }
}

struct Word7000Shortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartWordPractice(), phrases: ["Study words with \(.applicationName)"],
                    shortTitle: "Word practice", systemImageName: "character.book.closed")
        AppShortcut(intent: StartSpeakingPractice(), phrases: ["Practice speaking with \(.applicationName)"],
                    shortTitle: "Speaking practice", systemImageName: "bubble.left.and.text.bubble.right")
        AppShortcut(intent: StartWordQuiz(), phrases: ["Start a quiz with \(.applicationName)"],
                    shortTitle: "Vocabulary quiz", systemImageName: "checklist")
    }
}
