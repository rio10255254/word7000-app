import Foundation

/// The launch arguments the UI tests pass (`-uiTestingReset` and so on). Only
/// Debug builds read them: a Release app cannot be started with Plus unlocked,
/// a moved trial or its data wiped, and carries none of the argument names.
enum UITesting {
    enum Flag: String {
        case reset = "Reset", plus = "Plus", fakePlans = "FakePlans", onboarding = "Onboarding"
        case trialExpired = "TrialExpired", trialEndsSoon = "TrialEndsSoon", scanText = "ScanText"
        case sampleProgress = "SampleProgress", historyData = "HistoryData", chineseMode = "ChineseMode"
        case light = "Light", dark = "Dark"
    }

    #if DEBUG
    static func on(_ flag: Flag) -> Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTesting" + flag.rawValue)
    }

    /// Text the scan tests paste in, from the test runner's environment.
    static var scanText: String {
        on(.reset) || on(.scanText) ? ProcessInfo.processInfo.environment["WORD7000_SCAN_TEST_TEXT"] ?? "" : ""
    }
    #else
    static func on(_ flag: Flag) -> Bool { false }
    static var scanText: String { "" }
    #endif
}
