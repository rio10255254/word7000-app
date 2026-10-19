import XCTest
@testable import Word7000Core

final class PracticeQualityTests: XCTestCase {
    func testQuizShowsOneMeaningAndExcludesOverlappingAlternatives() {
        let words = [
            word("1", "bright", "明亮的；聰明的"),
            word("2", "clever", "聰明的"),
            word("3", "quiet", "安靜的；平靜的"),
            word("4", "warm", "溫暖的；熱情的"),
            word("5", "gentle", "溫柔的"),
        ]
        let options = QuizBuilder.options(vocabulary: PreparedVocabulary(words), wordId: "1", seed: "single", concise: true)
        XCTAssertEqual(options.count, 4)
        XCTAssertEqual(options.filter(\.correct).map(\.text), ["明亮的"])
        XCTAssertFalse(options.contains { $0.text.contains("；") || $0.text == "聰明的" })
        let reverse = QuizBuilder.options(vocabulary: PreparedVocabulary(words), wordId: "1", seed: "single", mode: .word, concise: true)
        XCTAssertFalse(reverse.contains { $0.text == "clever" })
    }

    private func word(_ id: String, _ english: String, _ chinese: String) -> WordEntry {
        WordEntry(id: id, word: english, partOfSpeech: "a", pronunciation: "", meaningZh: chinese,
                  example: "", exampleZh: "", group: "Core 1")
    }
}
