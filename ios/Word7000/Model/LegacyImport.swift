import CryptoKit
import Foundation
import Word7000Core

/// Reads what the previous React Native version of the app saved on this
/// iPhone, so updating to the native app keeps every learner's progress.
///
/// That app used AsyncStorage: `Library/Application Support/<bundle id>/
/// RCTAsyncLocalStorage_V1/manifest.json` holds small values inline; a value
/// longer than 1024 UTF-16 units lives in a file named after the MD5 of its
/// key, and its manifest entry is `null`. The directory is left untouched, so
/// the account session in it can still be picked up when sign-in arrives.
enum LegacyImport {
    struct Snapshot {
        var progress: ProgressState?
        var customSets: CustomSetState?
        var activeBankId: String?
        var theme: AppearancePreference?
        var deviceId: String?
        var streakReminder: Bool?
        var studyMode: StudyMode?
        var filters: (study: FilterSelection, quiz: FilterSelection, library: FilterSelection, questionCount: Int?)?
    }

    static func load() -> Snapshot? {
        let values = readAsyncStorage()
        guard !values.isEmpty else { return nil }
        return snapshot(from: values)
    }

    static func snapshot(from values: [String: String]) -> Snapshot {
        let decoder = JSONDecoder()
        func decode<T: Decodable>(_ type: T.Type, _ raw: String?) -> T? {
            raw.flatMap { try? decoder.decode(T.self, from: Data($0.utf8)) }
        }

        // Every copy of the learner's progress: the local guest copy, each
        // account cache, unsynced cloud writes and a pending account upgrade.
        var progressCopies: [ProgressState] = []
        var setCopies: [CustomSetState] = []
        struct Outbox: Decodable { var progress: ProgressState?; var customSets: CustomSetState? }
        for (key, raw) in values {
            if key == "word7000-progress-v1" || key.hasPrefix("word7000-progress-v1:user:") {
                decode(ProgressState.self, raw).map { progressCopies.append($0) }
            } else if key == "word7000-custom-sets-v1" || key.hasPrefix("word7000-custom-sets-v1:user:") {
                decode(CustomSetState.self, raw).map { setCopies.append($0) }
            } else if key.hasPrefix("word7000-sync-outbox-v1:user:") || key == "word7000-pending-account-upgrade-v1" {
                if let outbox = decode(Outbox.self, raw) {
                    outbox.progress.map { progressCopies.append($0) }
                    outbox.customSets.map { setCopies.append($0) }
                }
            }
        }

        var snapshot = Snapshot()
        if !progressCopies.isEmpty { snapshot.progress = LearningEngine.merge(progressCopies) }
        if !setCopies.isEmpty { snapshot.customSets = CustomSetState.merge(setCopies) }
        snapshot.activeBankId = values["word7000-active-bank-v1"].flatMap { $0.isEmpty ? nil : $0 }
        snapshot.theme = values["word7000-theme-v1"].flatMap(AppearancePreference.init(rawValue:))
        snapshot.deviceId = values["word7000-streak-device-id-v1"].flatMap { $0.isEmpty ? nil : $0 }
        snapshot.streakReminder = values["word7000-streak-reminder-v1"].map { $0 != "false" }
        snapshot.studyMode = values["word7000-study-mode-v1"].flatMap(StudyMode.init(rawValue:))
        if let prefs = decode(LegacyFilterPreferences.self, values["word7000-filter-preferences-v1"]) {
            snapshot.filters = (prefs.study.selection, prefs.quiz.selection, prefs.library.selection, prefs.quiz.questionCount)
        }
        return snapshot
    }

    struct LegacyFilterPreferences: Decodable {
        struct Entry: Decodable {
            var filter: LibraryFilter?
            var initial: String?
            var level: String?
            var sort: LibrarySort?
            var questionCount: Int?

            var selection: FilterSelection {
                FilterSelection(status: filter ?? .all, level: level ?? "all", initial: initial ?? "all", sort: sort ?? .default)
            }
        }
        var library: Entry
        var quiz: Entry
        var study: Entry
    }

    static func readAsyncStorage() -> [String: String] {
        let fileManager = FileManager.default
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let bundleId = Bundle.main.bundleIdentifier ?? "com.rio.word7000"
        let candidates = [
            support.appendingPathComponent(bundleId).appendingPathComponent("RCTAsyncLocalStorage_V1"),
            documents.appendingPathComponent("RCTAsyncLocalStorage_V1"),
            documents.appendingPathComponent("RNCAsyncLocalStorage_V1"),
            documents.appendingPathComponent("RCTAsyncLocalStorage"),
        ]
        for directory in candidates {
            let values = read(directory: directory)
            if !values.isEmpty { return values }
        }
        return [:]
    }

    static func read(directory: URL) -> [String: String] {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("manifest.json")),
              let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        var values: [String: String] = [:]
        for (key, value) in manifest {
            if let inline = value as? String {
                values[key] = inline
                continue
            }
            let name = Insecure.MD5.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
            if let stored = try? String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8) {
                values[key] = stored
            }
        }
        return values
    }
}
