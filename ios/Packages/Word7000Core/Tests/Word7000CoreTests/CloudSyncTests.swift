import XCTest
@testable import Word7000Core

final class CloudSyncTests: XCTestCase {
    private let today = "2026-10-26"

    func testAnotherDevicesWordsSurviveThisDevicesUpload() {
        // The iPad saved 30 words; this iPhone, last synced this morning, grades one card.
        var pad = ProgressState.empty
        for index in 0..<30 {
            pad = LearningEngine.markKnown(pad, wordId: "pad\(index)", today: today, changedAt: "2026-10-26T12:00:00.000Z")
        }
        let phone = LearningEngine.markKnown(.empty, wordId: "phone", today: today, changedAt: "2026-10-26T20:00:00.000Z")
        let cloud = SupabaseClient.Profile(found: true, progress: pad, customSets: CustomSetState(), version: "v-pad")

        let merged = CloudSync.merge(localProgress: phone, localSets: CustomSetState(), cloud: cloud, today: today)
        XCTAssertEqual(merged.progress.words.count, 31)
        XCTAssertTrue(merged.changedLocal, "the iPhone shows the iPad's words")
        XCTAssertTrue(merged.uploadProgress, "the cloud gets the iPhone's word too")
        XCTAssertFalse(merged.uploadCustomSets)
    }

    func testNewerStatusWinsWhicheverDeviceHasIt() {
        let older = LearningEngine.markKnown(.empty, wordId: "a", today: "2026-10-20", changedAt: "2026-10-20T08:00:00.000Z")
        let newer = LearningEngine.markReview(older, wordId: "a", today: today, changedAt: "2026-10-26T08:00:00.000Z")
        let cloudNewer = CloudSync.merge(localProgress: older, localSets: CustomSetState(),
                                         cloud: .init(found: true, progress: newer, customSets: CustomSetState()), today: today)
        XCTAssertEqual(cloudNewer.progress.words["a"]?.status, .review)
        let localNewer = CloudSync.merge(localProgress: newer, localSets: CustomSetState(),
                                         cloud: .init(found: true, progress: older, customSets: CustomSetState()), today: today)
        XCTAssertEqual(localNewer.progress.words["a"]?.status, .review)
        XCTAssertTrue(localNewer.uploadProgress)
    }

    func testCustomSetsFromBothDevicesAreKept() {
        var phoneSets = CustomSetState()
        phoneSets.sets = [CustomVocabSet(color: "blue", createdAt: "2026-10-01T00:00:00.000Z", id: "s1", name: "Phone", sortOrder: 0, updatedAt: "2026-10-01T00:00:00.000Z", wordIds: ["a"])]
        var padSets = CustomSetState()
        padSets.sets = [CustomVocabSet(color: "green", createdAt: "2026-10-02T00:00:00.000Z", id: "s2", name: "Pad", sortOrder: 1, updatedAt: "2026-10-02T00:00:00.000Z", wordIds: ["b"])]
        let merged = CloudSync.merge(localProgress: .empty, localSets: phoneSets,
                                     cloud: .init(found: true, progress: .empty, customSets: padSets), today: today)
        XCTAssertEqual(Set(merged.customSets.sets.map(\.id)), ["s1", "s2"])
        XCTAssertTrue(merged.changedLocal)
        XCTAssertTrue(merged.uploadCustomSets)
    }

    func testNothingNewOnEitherSideChangesNothing() {
        let phone = LearningEngine.normalizeForDate(
            LearningEngine.markKnown(.empty, wordId: "a", today: today, changedAt: "2026-10-26T08:00:00.000Z"), today: today)
        let merged = CloudSync.merge(localProgress: phone, localSets: CustomSetState(),
                                     cloud: .init(found: true, progress: phone, customSets: CustomSetState()), today: today)
        XCTAssertFalse(merged.changedLocal)
        XCTAssertFalse(merged.uploadProgress)
        XCTAssertFalse(merged.uploadCustomSets)
    }

    func testAnEmptyCloudTakesEverythingFromThisDevice() {
        let phone = LearningEngine.markKnown(.empty, wordId: "a", today: today, changedAt: "2026-10-26T08:00:00.000Z")
        let merged = CloudSync.merge(localProgress: phone, localSets: CustomSetState(), cloud: .init(found: false), today: today)
        XCTAssertEqual(merged.progress.words.keys.sorted(), ["a"])
        XCTAssertTrue(merged.uploadProgress)
        XCTAssertTrue(merged.uploadCustomSets)
    }
}
