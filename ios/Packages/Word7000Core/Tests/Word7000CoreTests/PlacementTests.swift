import XCTest
@testable import Word7000Core

final class PlacementTests: XCTestCase {
    private func word(_ id: String, _ text: String, level: Int) -> WordEntry {
        WordEntry(id: id, word: text, partOfSpeech: "n", pronunciation: "", meaningZh: "字", example: "", exampleZh: "", group: "Core \(level)")
    }

    func testOneShortSingleWordPerLevelFromEasyToHard() {
        var words: [WordEntry] = []
        for level in 1...14 {
            words.append(word("a\(level)", "word\(level)", level: level))
            words.append(word("b\(level)", "two words", level: level))
            words.append(word("c\(level)", "extraordinarily", level: level))
        }
        let picked = Placement.words(from: words, seed: "s")
        XCTAssertEqual(picked.map(\.group), Placement.levels.map { "Core \($0)" })
        XCTAssertTrue(picked.allSatisfy { $0.id.hasPrefix("a") })
        XCTAssertEqual(Placement.words(from: words, seed: "s").map(\.id), picked.map(\.id))
    }

    func testKnownWordsCountAsKnownWithoutTouchingTheDayOrAMetWord() {
        var state = ProgressState()
        state.dailyTarget = 20
        state = LearningEngine.markReview(state, wordId: "met", today: "2026-11-02")
        let before = state
        let placed = Placement.apply(knownIds: ["w1", "w2", "met"], to: state, today: "2026-11-02")
        XCTAssertEqual(placed.words["w1"]?.status, .mastered)
        XCTAssertEqual(placed.words["w2"]?.status, .mastered)
        XCTAssertEqual(placed.words["met"], before.words["met"])
        XCTAssertEqual(placed.studiedToday, before.studiedToday)
        XCTAssertEqual(placed.streak, before.streak)
        // Known on sight lifts the estimate when the words are hard.
        let words = (1...14).map { word("w\($0)", "w\($0)", level: $0) }
        let hard = Placement.apply(knownIds: ["w12", "w13", "w14"], to: ProgressState(), today: "2026-11-02")
        XCTAssertGreaterThan(LearningEngine.abilityEstimate(words: words, state: hard).ability, LearningEngine.abilityPrior)
    }
}
