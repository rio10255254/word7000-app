import XCTest
@testable import Word7000Core

final class ModeProgressTests: XCTestCase {
    private func stored() -> ProgressState {
        var state = ProgressState(dailyTarget: 15, streak: 4)
        state = LearningEngine.markKnown(state, wordId: "w0001", today: "2026-11-01")
        state = LearningEngine.markReview(state, wordId: "w0002", today: "2026-11-01")
        var chinese = WordProgress.fresh
        chinese.status = .review
        state.words["zh:w0003"] = chinese
        return state
    }

    func testEachModeSeesOnlyItsOwnWords() {
        let state = stored()
        XCTAssertEqual(Set(ModeProgress.view(state, chinese: false).words.keys), ["w0001", "w0002"])
        XCTAssertEqual(Set(ModeProgress.view(state, chinese: true).words.keys), ["w0003"])
        XCTAssertEqual(ModeProgress.view(state, chinese: true).streak, 4)
        XCTAssertEqual(ModeProgress.view(state, chinese: true).dailyTarget, 15)
    }

    func testStoringAViewKeepsTheOtherMode() {
        let state = stored()
        var chinese = ModeProgress.view(state, chinese: true)
        chinese = LearningEngine.markKnown(chinese, wordId: "w0001", today: "2026-11-02")
        let back = ModeProgress.store(chinese, chinese: true, otherWords: ModeProgress.storedWords(of: state, excluding: true))
        XCTAssertEqual(Set(back.words.keys), ["w0001", "w0002", "zh:w0001", "zh:w0003"])
        XCTAssertEqual(back.words["w0002"], state.words["w0002"])
        XCTAssertEqual(ModeProgress.view(back, chinese: false).words, ModeProgress.view(state, chinese: false).words)
    }

    func testRoundTripIsLossless() {
        let state = stored()
        for chinese in [false, true] {
            let view = ModeProgress.view(state, chinese: chinese)
            XCTAssertEqual(ModeProgress.store(view, chinese: chinese, otherWords: ModeProgress.storedWords(of: state, excluding: chinese)), state)
        }
    }

    func testSeedingCopiesSharedProgressOnce() {
        var state = stored()
        state.words.removeValue(forKey: "zh:w0003")
        let seeded = ModeProgress.seedChinese(state)
        XCTAssertEqual(Set(ModeProgress.view(seeded, chinese: true).words.keys), ["w0001", "w0002"])
        XCTAssertEqual(ModeProgress.view(seeded, chinese: false).words, state.words)
        XCTAssertEqual(ModeProgress.seedChinese(stored()), stored())
    }
}
