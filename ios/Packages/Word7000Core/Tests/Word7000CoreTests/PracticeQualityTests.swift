import XCTest
@testable import Word7000Core

final class PracticeQualityTests: XCTestCase {
    func testScannedDifferentSenseDoesNotBorrowAnUnrelatedExample() {
        var source = word("bright", "bright", "明亮的")
        source.example = "The room was bright in the morning."
        source.exampleZh = "這個房間早上很明亮。"
        let rows = [ReviewedScanWord(meaningZh: "聰明的", partOfSpeech: "a", word: "bright")]
        let scanned = WordBanks.buildScannedWords(rows, coreWords: [source], requireMatchingExample: true)
        XCTAssertEqual(scanned.first?.meaningZh, "聰明的")
        XCTAssertEqual(scanned.first?.example, "")
        XCTAssertEqual(scanned.first?.exampleZh, "")
        let matching = WordBanks.buildScannedWords([.init(meaningZh: "明亮的", partOfSpeech: "a", word: "bright")], coreWords: [source], requireMatchingExample: true)
        XCTAssertEqual(matching.first?.example, source.example)
    }

    func testScannedExamplesAllowFormattingDifferencesButNotDifferentWordClasses() {
        var source = word("own", "record", "紀錄；記載")
        source.partOfSpeech = "n"
        source.example = "This record shows every delivery."
        source.exampleZh = "這份紀錄列出了每次配送。"
        let matching = WordBanks.buildScannedWords([.init(meaningZh: "記載, 紀錄", partOfSpeech: "noun", word: "RECORD")],
                                                  coreWords: [source], requireMatchingExample: true)
        XCTAssertEqual(matching.first?.example, source.example)
        let different = WordBanks.buildScannedWords([.init(meaningZh: "紀錄；記載", partOfSpeech: "v", word: "record")],
                                                   coreWords: [source], requireMatchingExample: true)
        XCTAssertTrue(different.first?.example.isEmpty == true)
    }

    func testExactSearchComesFirstWhenBrowsingAlphabetically() {
        let words = [word("1", "catalog", "目錄"), word("2", "cat", "貓"), word("3", "aardvark", "cat")]
        let found = PreparedVocabulary(words).filter(state: .empty, query: "cat", filter: .all,
                                                     options: .init(sort: .alphabetical), rankedSearch: true)
        XCTAssertEqual(found.map(\.word), ["cat", "catalog", "aardvark"])
    }

    func testPracticeAfterMidnightStartsANewDailyCountAndKeepsTheStreak() {
        let yesterday = LearningEngine.markKnown(.empty, wordId: "first", today: "2026-10-19")
        let today = LearningEngine.normalizeForDate(yesterday, today: "2026-10-20")
        XCTAssertEqual(today.studiedToday, 0)
        let practiced = LearningEngine.markKnown(today, wordId: "second", today: "2026-10-20")
        XCTAssertEqual(practiced.studiedToday, 1)
        XCTAssertEqual(practiced.streak, 2)
        XCTAssertEqual(practiced.lastStudyDate, "2026-10-20")
    }

    func testScannedCopyKeepsItsOwnMeaningInItsBank() {
        let core = [word("core-1", "bright", "明亮的")]
        let scanned = WordBanks.buildScannedWords([.init(meaningZh: "聰明的", partOfSpeech: "a", word: "bright")], coreWords: core, stamp: "scan")
        let created = CustomSetState.empty.creatingSet(named: "Lesson", now: "2026-10-19T00:00:00Z")
        let state = created.state.addingCustomWords(scanned, toSet: created.id)
        let all = WordBanks.mergeCustomWords(base: core, custom: state.customWords, includeBankCopies: true)
        XCTAssertEqual(WordBanks.words(of: state.sets.first, in: all).first?.meaningZh, "聰明的")
        XCTAssertEqual(WordBanks.mergeCustomWords(base: core, custom: state.customWords).count, 1)
    }

    func testNewerCustomEditWinsRegardlessOfMergeOrder() {
        let created = CustomSetState.empty.creatingSet(named: "Lesson", now: "2026-10-19T00:00:00Z")
        let original = created.state.addingCustomWords([word("own", "quiet", "安靜的")], toSet: created.id, now: "2026-10-19T00:01:00Z")
        var changed = original.customWords[0]
        changed.word = "silent"
        changed.meaningZh = "無聲的"
        let edited = original.editingWord(changed, now: "2026-10-19T00:02:00Z")
        for states in [[original, edited], [edited, original]] {
            let merged = CustomSetState.merge(states)
            XCTAssertEqual(merged.customWords.count, 1)
            XCTAssertEqual(merged.customWords[0].word, "silent")
            XCTAssertEqual(merged.customWords[0].meaningZh, "無聲的")
        }
    }

    func testDeleteCanBeRestoredAfterCloudMerge() {
        let created = CustomSetState.empty.creatingSet(named: "Lesson", now: "2026-10-19T00:00:00Z")
        let original = created.state.sets[0]
        let deleted = created.state.deletingSet(created.id, now: "2026-10-19T00:01:00Z")
        let restored = deleted.restoringSet(original, now: "2026-10-19T00:02:00Z")
        XCTAssertEqual(CustomSetState.merge([deleted, restored]).sets.map(\.id), [created.id])
    }

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
