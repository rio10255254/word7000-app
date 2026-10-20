import XCTest
@testable import Word7000Core

final class ScanImportTests: XCTestCase {
    func testNormalisesWidthSpacingCaseAndTypographicApostrophes() {
        let existing = [entry("look forward to", "期待", "phr"), entry("don't", "不要", "")]
        let rows = [row(" LOOK\u{00A0} forward\tto ", "期待", "phr."),
                    row("ｌｏｏｋ　ｆｏｒｗａｒｄ　ｔｏ", "期待", "phr"), row("don’t", "不要", "")]
        let plan = ScanImportPlan(rows: rows, existing: existing)
        XCTAssertEqual(plan.dispositions, [.duplicateInBank, .duplicateInBank, .duplicateInBank])
        XCTAssertEqual(plan.duplicateCount, 3)
        XCTAssertTrue(plan.additions.isEmpty)
    }

    func testDifferentMeaningsAndWordEndingsAreNeverDiscarded() {
        let rows = [row("bank", "河岸"), row("BANK", "銀行"), row("bank", "河岸"),
                    row("objective", "目標"), row("objectively", "客觀地", "adv")]
        let plan = ScanImportPlan(rows: rows, existing: [entry("bank", "銀行")])
        XCTAssertEqual(plan.dispositions, [.additionalMeaning, .duplicateInBank, .duplicateInScan, .newWord, .newWord])
        XCTAssertEqual(plan.additions.map(\.word), ["bank", "objective", "objectively"])
    }

    func testMeaningSeparatorsAndOrderDoNotCreateCopies() {
        let plan = ScanImportPlan(rows: [row("abandon", "遺棄, 放棄", "v")],
                                  existing: [entry("abandon", "放棄；遺棄", "verb")])
        XCTAssertEqual(plan.dispositions, [.duplicateInBank])
        XCTAssertTrue(ScanImportPlan.sameEntry(row("carefully", "小 心 地", "adv"), row("carefully", "小心地", "adverb")))
    }

    func testDifferentExplicitWordClassesAreKeptAndAliasesAreEquivalent() {
        let rows = [row("record", "紀錄", "v"), row("bright", "明亮的", "adj."), row("clean", "乾淨", "v / n")]
        let existing = [entry("record", "紀錄", "n"), entry("bright", "明亮的", "a"), entry("clean", "乾淨", "n./v.")]
        XCTAssertEqual(ScanImportPlan(rows: rows, existing: existing).dispositions,
                       [.additionalMeaning, .duplicateInBank, .duplicateInBank])
        XCTAssertTrue(ScanImportPlan.sameEntry(row("bank", "銀行", ""), row("bank", "銀行", "n")))
    }

    func testHyphensAndAccentsKeepTheirMeaningfulDifferences() {
        let plan = ScanImportPlan(rows: [row("co–op", "合作社"), row("coop", "合作社"), row("résumé", "履歷"), row("resume", "履歷")])
        XCTAssertEqual(plan.additions.count, 4)
        XCTAssertEqual(ScanImportPlan.wordKey("co–op"), "co-op")
    }

    func testIncompleteRowsNeverBecomeWords() {
        let plan = ScanImportPlan(rows: [row("\u{200B}", "銀行"), row("bank", "； ;"), row("", ""), row("bank", "銀行")])
        XCTAssertEqual(plan.dispositions, [.incomplete, .incomplete, .incomplete, .newWord])
        XCTAssertEqual(plan.additions.count, 1)
    }

    func testParserMultipleReadersAndSavedBankKeepSeparateSenses() {
        let parsed = ScanParser.parse(ScanParser.lines(fromPlainText: "bank n. 銀行\nbank n. 河岸\nBANK n. 銀行"))
        XCTAssertEqual(parsed.map(\.meaningZh), ["銀行", "河岸"])
        let merged = ScanGrounding.merging(primary: parsed, supplemental: parsed)
        XCTAssertEqual(merged.count, 2)
        XCTAssertFalse(merged.contains(where: \.needsReview))
        let words = WordBanks.buildScannedWords(merged.map(\.reviewedWord), coreWords: [], stamp: "two-senses")
        XCTAssertEqual(words.map(\.meaningZh), ["銀行", "河岸"])
        XCTAssertEqual(Set(words.map(\.id)).count, 2)
        let repeated = ScanImportPlan(rows: merged.map(\.reviewedWord), existing: words)
        XCTAssertEqual(repeated.duplicateCount, 2)
        XCTAssertTrue(repeated.additions.isEmpty)
    }

    func testChangingDestinationRechecksOnlyThatBank() {
        let rows = [row("bank", "銀行"), row("bank", "河岸")]
        let first = ScanImportPlan(rows: rows, existing: [entry("bank", "銀行")])
        let second = ScanImportPlan(rows: rows, existing: [entry("bank", "河岸")])
        XCTAssertEqual(first.additions.map(\.meaningZh), ["河岸"])
        XCTAssertEqual(second.additions.map(\.meaningZh), ["銀行"])
        XCTAssertEqual(ScanImportPlan(rows: rows).additions.count, 2)
    }

    private func row(_ word: String, _ meaning: String, _ part: String = "n") -> ReviewedScanWord {
        ReviewedScanWord(meaningZh: meaning, partOfSpeech: part, word: word)
    }

    private func entry(_ word: String, _ meaning: String, _ part: String = "n") -> WordEntry {
        WordEntry(id: "test-\(word)", word: word, partOfSpeech: part, pronunciation: "", meaningZh: meaning,
                  example: "", exampleZh: "", group: "Scan")
    }
}
