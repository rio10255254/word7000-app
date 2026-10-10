import Foundation
import Word7000Core

/// Reads what the previous React Native version of the app saved on this
/// iPhone, so updating to the native app keeps every learner's progress.
enum LegacyImport {
    struct Snapshot {
        var progress: ProgressState?
        var customSets: CustomSetState?
        var activeBankId: String?
    }

    static func load() -> Snapshot? {
        nil
    }
}
