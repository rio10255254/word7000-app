import Foundation
import Word7000Core

/// Settings that are not part of learning progress.
struct AppSettings: Codable, Equatable {
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
}

struct FilterSelection: Codable, Equatable, Hashable {
    var status: LibraryFilter = .all
    var level = "all"
    var initial = "all"
    var sort: LibrarySort = .default

    var isActive: Bool { status != .all || level != "all" || initial != "all" }

    var options: LibraryFilterOptions {
        LibraryFilterOptions(initial: initial, level: level, sort: sort)
    }
}

/// Small JSON documents in Application Support. Each is written atomically,
/// so a crash mid-write can never leave a half-written file behind.
struct Persistence {
    let directory: URL

    static let live: Persistence = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return Persistence(directory: base.appendingPathComponent("Word7000", isDirectory: true))
    }()

    func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        let url = directory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func save<T: Encodable>(_ value: T, to name: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(value)
            try data.write(to: directory.appendingPathComponent(name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            // Saving is best effort; the next change tries again.
        }
    }
}
