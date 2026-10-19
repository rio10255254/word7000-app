import Foundation
import Word7000Core

/// Settings that are not part of learning progress.
struct AppSettings: Codable, Equatable, Sendable {
    var theme: AppearancePreference = .system
    var activeBankId: String = WordBanks.coreBankId
    var studyFilter = FilterSelection()
    var quizFilter = FilterSelection()
    var libraryFilter = FilterSelection()
    var quizQuestionCount = 10
    /// Identifies this device in per-device activity counters.
    var deviceSourceId = "ios-\(UUID().uuidString.prefix(8).lowercased())"
    /// Set once data from the previous (React Native) app has been imported.
    var migratedLegacyData = false
    // Added after 2.0.0 (27). New fields must be optional so settings saved
    // by an older build still decode.
    /// Whose data the local files hold (nil: not yet tied to an account).
    var localOwnerId: String?
    var localOwnerIsAnonymous: Bool?
    /// Once a permanent account was used here, Google sign-in no longer tries
    /// to link the guest identity.
    var permanentAccountUsed: Bool?
    /// nil means `.english`, the default.
    var studyMode: StudyMode?
    /// Lock screen study reminders; nil means on.
    var streakReminder: Bool?
    var reminderMinute: Int?
    var onboardingComplete: Bool?
    var hapticsEnabled: Bool?
    var speakingFilter: FilterSelection?
    var savedBankFilters: [String: BankFilterSettings]?
}

struct BankFilterSettings: Codable, Equatable, Sendable {
    var study = FilterSelection()
    var quiz = FilterSelection()
    var library = FilterSelection()
    var speaking = FilterSelection()
}

struct FilterSelection: Codable, Equatable, Hashable, Sendable {
    var status: LibraryFilter = .all
    var level = "all"
    var initial = "all"
    var sort: LibrarySort = .alphabetical

    var isActive: Bool { status != .all || level != "all" || initial != "all" }

    var options: LibraryFilterOptions {
        LibraryFilterOptions(initial: initial, level: level, sort: sort)
    }
}

/// Small JSON documents in Application Support. Each is written atomically,
/// so a crash mid-write can never leave a half-written file behind.
struct AppSnapshot: Codable, Sendable {
    var progress: ProgressState
    var customSets: CustomSetState
    var settings: AppSettings
    var studySession: StudySession?
    var sessionDay: String?
}

struct Persistence: Sendable {
    let directory: URL
    let store: LearningFileStore

    init(directory: URL) {
        self.directory = directory
        self.store = LearningFileStore(directory: directory)
    }

    static let live: Persistence = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return Persistence(directory: base.appendingPathComponent("Word7000", isDirectory: true))
    }()

    func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        try? store.load(type, from: name)
    }

    @discardableResult
    func save<T: Encodable>(_ value: T, to name: String) -> Bool {
        do {
            try store.save(value, to: name)
            return true
        } catch {
            return false
        }
    }
}
