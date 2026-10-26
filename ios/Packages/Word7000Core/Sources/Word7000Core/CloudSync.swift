import Foundation

/// Folding another device's saved documents into this device's before an
/// upload. A save replaces the whole cloud document, so uploading without
/// merging first would drop everything other devices saved since this one
/// last read the cloud.
public enum CloudSync {
    public struct Merge: Equatable, Sendable {
        public var progress: ProgressState
        public var customSets: CustomSetState
        /// The merge took something from the cloud this device did not have.
        public var changedLocal: Bool
        /// The cloud copy lacks something this device has.
        public var uploadProgress: Bool
        public var uploadCustomSets: Bool
    }

    public static func merge(localProgress: ProgressState, localSets: CustomSetState, cloud: SupabaseClient.Profile, today: String) -> Merge {
        func progressMerge(_ states: [ProgressState?]) -> ProgressState {
            LearningEngine.normalizeForDate(LearningEngine.merge(states), today: today)
        }
        let progress = progressMerge([localProgress, cloud.progress])
        let sets = CustomSetState.merge([localSets, cloud.customSets])
        // Each side is compared after the same merge on its own, so a merge
        // that only tidies the encoding (a nil list becoming empty) is not a change.
        let localAlone = (progressMerge([localProgress]), CustomSetState.merge([localSets]))
        return Merge(
            progress: progress,
            customSets: sets,
            changedLocal: progress != localAlone.0 || sets != localAlone.1,
            uploadProgress: cloud.progress.map { progress != progressMerge([$0]) } ?? true,
            uploadCustomSets: cloud.customSets.map { sets != CustomSetState.merge([$0]) } ?? true
        )
    }
}
