import XCTest
@testable import Word7000Core

/// A handwritten list photographed by a learner of Chinese: English on the
/// left, Chinese on the right, a column of check boxes between them that
/// Vision (reading for Chinese) took for 工, a title, a note beside one
/// headword, and "during" misread as "daring" on one line. The old parser
/// gave the reported screen's eight rows (when Starts Since / 工,
/// during / 工, walk / 工, daring / 在..期間, "Since" three times) and
/// Unit / 時間介系詞 from the title.
final class ScanQualityTests: XCTestCase {
    private func box(_ text: String, _ x: Double, _ y: Double, _ width: Double) -> ScannedLine {
        ScannedLine(text: text, x: x, y: y, width: width, height: 0.028)
    }

    /// The first reading, Chinese first (`TextRecognizer.languages`).
    private var sheet: [ScannedLine] {
        [
            box("Unit 5 時間介系詞", 0.30, 0.03, 0.40),
            box("for", 0.10, 0.10, 0.07), box("多", 0.45, 0.10, 0.04),
            box("when Starts", 0.08, 0.17, 0.17), box("Since", 0.26, 0.17, 0.08), box("工", 0.36, 0.17, 0.03),
            box("Since", 0.10, 0.24, 0.09), box("從什麼時候開始", 0.45, 0.24, 0.22), box("從我小时候", 0.72, 0.24, 0.16),
            box("daring", 0.10, 0.31, 0.11), box("在..期間", 0.45, 0.31, 0.12),
            box("during", 0.10, 0.38, 0.11), box("工", 0.36, 0.38, 0.03),
            box("walk", 0.10, 0.45, 0.08), box("工", 0.36, 0.45, 0.03),
        ]
    }

    /// The second reading of the sharpened photo, English first: the boxes
    /// come out as 口 and the misread line as "during".
    private var secondReading: [ScannedLine] {
        sheet.map { line in
            var copy = line
            if copy.text == "工" { copy.text = "口" }
            if copy.text == "daring" { copy.text = "during" }
            return copy
        }
    }

    private static let words = ScanDictionary(words: BundledWords.words)
    private var dictionary: ScanDictionary { Self.words }

    /// The steps `TextRecognizer.candidates` takes for one page.
    private func read(_ lines: [ScannedLine], second: [ScannedLine]? = nil, dictionary: ScanDictionary?) -> [ScannedWordCandidate] {
        var found = ScanGrounding.merging(primary: ScanParser.parsePage(lines), supplemental: [], dictionary: dictionary)
        var pageWords = ScanParser.latinWords(in: lines)
        if let second {
            found = ScanGrounding.merging(primary: found, supplemental: ScanParser.parsePage(second), dictionary: dictionary)
            pageWords.formUnion(ScanParser.latinWords(in: second))
        }
        guard let dictionary else { return found }
        return ScanGrounding.respelled(found, pageWords: pageWords, dictionary: dictionary)
    }

    // MARK: The reported sheet

    func testReportedSheetReadsAsThreeEntries() {
        let found = read(sheet, dictionary: dictionary)
        XCTAssertEqual(found.map(\.word), ["for", "Since", "during"])
        XCTAssertEqual(found.map(\.meaningZh), ["多", "從什麼時候開始 從我小时候", "在..期間"])
        XCTAssertFalse(found.contains { $0.meaningZh.contains("工") })
        XCTAssertTrue(found.allSatisfy { $0.partOfSpeech.isEmpty })
        // "during" is written on the page too, so the misreading is replaced
        // and can be restored.
        XCTAssertEqual(found[2].originalWord, "daring")
        XCTAssertFalse(found.contains(where: \.needsReview))
        // Nothing is shown as "kept separately".
        XCTAssertEqual(ScanImportPlan(rows: found.map(\.reviewedWord)).dispositions, [.newWord, .newWord, .newWord])
        // Saved the usual way: the English is `word`, the Chinese (what a
        // learner of Chinese studies) `meaningZh`, as in words-zh.json.
        let saved = WordBanks.buildScannedWords(found.map(\.reviewedWord), coreWords: [], stamp: "sheet")
        XCTAssertEqual(saved.map(\.word), ["for", "Since", "during"])
        XCTAssertEqual(saved.map(\.meaningZh), ["多", "從什麼時候開始 從我小时候", "在..期間"])
    }

    func testSecondReadingSettlesTheMisreadWordWithoutADuplicate() {
        let found = read(sheet, second: secondReading, dictionary: dictionary)
        XCTAssertEqual(found.map(\.word), ["for", "Since", "during"])
        XCTAssertEqual(found.map(\.meaningZh), ["多", "從什麼時候開始 從我小时候", "在..期間"])
        XCTAssertEqual(found[2].originalWord, "daring")
        XCTAssertFalse(found.contains(where: \.needsReview))
    }

    func testWithoutTheWordListBothReadingsWaitForTheLearner() {
        let found = read(sheet, second: secondReading, dictionary: nil)
        XCTAssertEqual(found.map(\.word), ["for", "Since", "daring", "during"])
        XCTAssertEqual(found.filter(\.needsReview).map(\.word), ["daring", "during"])
    }

    // MARK: Marks read as Chinese

    func testBulletsAndCheckBoxesAreNotMeanings() {
        // Bullets read as 口 in front of every entry, dashes read as 一.
        let pasted = ScanParser.parsePage(ScanParser.lines(fromPlainText: "口 abandon v. 一 放棄\n口 benefit n. 一 好處\n口 bank 銀行\n口 bank 河岸"))
        XCTAssertEqual(pasted.map(\.word), ["abandon", "benefit", "bank", "bank"])
        XCTAssertEqual(pasted.map(\.meaningZh), ["放棄", "好處", "銀行", "河岸"])
        XCTAssertEqual(pasted.map(\.partOfSpeech), ["v", "n", "", ""])
        // The same with each bullet read as a box of its own.
        let boxes = [
            box("口", 0.03, 0.10, 0.03), box("abandon", 0.08, 0.10, 0.15), box("放棄", 0.45, 0.10, 0.08),
            box("口", 0.03, 0.16, 0.03), box("benefit", 0.08, 0.16, 0.14), box("好處", 0.45, 0.16, 0.08),
        ]
        let found = ScanParser.parsePage(boxes)
        XCTAssertEqual(found.map(\.word), ["abandon", "benefit"])
        XCTAssertEqual(found.map(\.meaningZh), ["放棄", "好處"])
    }

    func testACheckBoxColumnBetweenWordAndMeaningIsNotPartOfTheMeaning() {
        let boxes = [
            box("Since", 0.10, 0.10, 0.09), box("工", 0.36, 0.10, 0.03), box("從什麼時候開始", 0.45, 0.10, 0.22),
            box("during", 0.10, 0.17, 0.11), box("工", 0.36, 0.17, 0.03), box("在..期間", 0.45, 0.17, 0.12),
        ]
        let found = ScanParser.parsePage(boxes)
        XCTAssertEqual(found.map(\.word), ["Since", "during"])
        XCTAssertEqual(found.map(\.meaningZh), ["從什麼時候開始", "在..期間"])
        let table = ScanGrounding.candidates(fromTableRows: [["Since", "工", "從什麼時候開始"], ["during", "工", "在..期間"]])
        XCTAssertEqual(table.map(\.meaningZh), ["從什麼時候開始", "在..期間"])
    }

    func testOneBulletBeforeAnEnglishWordIsLeftOut() {
        let found = ScanParser.parse(ScanParser.lines(fromPlainText: "一 walk 散步\nrun 跑步\nswim 游泳"))
        XCTAssertEqual(found.map(\.word), ["walk", "run", "swim"])
        XCTAssertEqual(found.map(\.meaningZh), ["散步", "跑步", "游泳"])
        // Tightly written rows: the bullet of the next row sits right under
        // "walk", which has no meaning written yet.
        let tight = [box("walk", 0.08, 0.10, 0.08),
                     box("工", 0.03, 0.135, 0.03), box("run", 0.08, 0.135, 0.06), box("跑步", 0.45, 0.135, 0.08)]
        let tightRows = ScanParser.parsePage(tight)
        XCTAssertEqual(tightRows.map(\.word), ["run"])
        XCTAssertEqual(tightRows.map(\.meaningZh), ["跑步"])
    }

    func testCharactersThatLookLikeMarksStayMeaningsWhereTheyAreWords() {
        // Lists for learners of Chinese, Chinese first.
        let chineseFirst = ScanParser.parse(ScanParser.lines(fromPlainText: "口 kǒu mouth\n手 shǒu hand\n工作 gōngzuò work"))
        XCTAssertEqual(chineseFirst.map(\.word), ["mouth", "hand", "work"])
        XCTAssertEqual(chineseFirst.map(\.meaningZh), ["口", "手", "工作"])
        let numbers = ScanParser.parse(ScanParser.lines(fromPlainText: "一 yī one\n二 èr two\n十 shí ten"))
        XCTAssertEqual(numbers.map(\.meaningZh), ["一", "二", "十"])
        // English first, each look-alike once, and two pairs on one line.
        let englishFirst = ScanParser.parse(ScanParser.lines(fromPlainText: "one 一 two 二\nten 十\nwork 工 作"))
        XCTAssertEqual(englishFirst.map(\.word), ["one", "two", "ten", "work"])
        XCTAssertEqual(englishFirst.map(\.meaningZh), ["一", "二", "十", "工 作"])
    }

    func testPinyinStartingWithAToneMarkStaysOutOfTheMeaning() {
        let found = ScanParser.parse(ScanParser.lines(fromPlainText: "愛 ài love\n二 èr two\n餓 è hungry"))
        XCTAssertEqual(found.map(\.word), ["love", "two", "hungry"])
        XCTAssertEqual(found.map(\.meaningZh), ["愛", "二", "餓"])
    }

    func testCapitalIMisreadInsideASentenceIsNotAMeaning() {
        let found = ScanParser.parse(ScanParser.lines(fromPlainText: "Since 工 was little\nsince 自從"))
        XCTAssertEqual(found.map(\.word), ["since"])
        XCTAssertEqual(found.map(\.meaningZh), ["自從"])
    }

    func testMeaningCountLeavesOutMarks() {
        XCTAssertEqual(ScanParser.meaningLineCount(sheet), 5)
    }

    // MARK: Headings and notes

    func testHeadingsAndNotesBesideHeadwordsAreNotWords() {
        let found = ScanParser.parse(ScanParser.lines(fromPlainText: """
        Unit 5 時間介系詞
        第三課 Lesson 3
        when Starts Since 從什麼時候開始
        learn English 學英文
        look forward to 期待
        traditional Chinese medicine 中醫
        """))
        XCTAssertEqual(found.map(\.word), ["learn English", "look forward to", "traditional Chinese medicine"])
    }

    // MARK: Two pairings and two readings of one entry

    func testTheSameEntryPairedTwiceIsOneRow() {
        let rows = ScanParser.parse(ScanParser.lines(fromPlainText: "Since 從什麼時候開始 從我小时候\nfor 多"))
        let boxes = ScanParser.parse(ScanParser.lines(fromPlainText: "Since 從什麼時候開始\nfor 多久"))
        let merged = ScanGrounding.merging(primary: rows, supplemental: boxes)
        XCTAssertEqual(merged.map(\.word), ["Since", "for"])
        XCTAssertEqual(merged.map(\.meaningZh), ["從什麼時候開始 從我小时候", "多久"])
        // Different senses actually on the page, or a different stated word
        // class, stay separate.
        let senses = ScanGrounding.merging(primary: ScanParser.parse(ScanParser.lines(fromPlainText: "bank n. 銀行\nrecord n. 紀錄")),
                                           supplemental: ScanParser.parse(ScanParser.lines(fromPlainText: "bank n. 河岸\nrecord v. 紀錄")))
        XCTAssertEqual(senses.map(\.meaningZh), ["銀行", "紀錄", "河岸", "紀錄"])
    }

    func testTwoNumberedColumnsReadAsOneRowKeepTheNextNumberOutOfTheMeaning() {
        let lines = [box("1. abandon", 0.05, 0.10, 0.15), box("放棄", 0.22, 0.10, 0.08),
                     box("2. benefit", 0.55, 0.10, 0.15), box("好處", 0.72, 0.10, 0.08)]
        let found = ScanParser.parsePage(lines)
        XCTAssertEqual(found.map(\.word), ["abandon", "benefit"])
        XCTAssertEqual(found.map(\.meaningZh), ["放棄", "好處"])
    }

    func testAReaderWithRowsOutOfStepDoesNotGiveAWordAnotherWordsMeaning() {
        let primary = ScanParser.parse(ScanParser.lines(fromPlainText: "during 在..期間\nwalk 散步"))
        let shifted = [ScannedWordCandidate(key: "s0", meaningZh: "散步", partOfSpeech: "", word: "during"),
                       ScannedWordCandidate(key: "s1", meaningZh: "走路", partOfSpeech: "", word: "stroll")]
        let merged = ScanGrounding.merging(primary: primary, supplemental: shifted)
        XCTAssertEqual(merged.map(\.word), ["during", "walk", "stroll"])
        XCTAssertEqual(merged.map(\.meaningZh), ["在..期間", "散步", "走路"])
    }

    func testWordEndingsAreNeverSettledByTheWordList() {
        let primary = ScanParser.parse(ScanParser.lines(fromPlainText: "objectively adv. 客觀的"))
        let table = ScanParser.parse(ScanParser.lines(fromPlainText: "objective adv. 客觀的"))
        let merged = ScanGrounding.merging(primary: primary, supplemental: table, dictionary: dictionary)
        XCTAssertEqual(merged.map(\.word), ["objectively", "objective"])
        XCTAssertTrue(merged.allSatisfy(\.needsReview))
        XCTAssertNil(dictionary.respelling(of: "objectively", meaning: "客觀的"))
    }

    // MARK: Spelling from the word list

    func testAMisreadWordIsOnlySuggestedUnlessTheRightOneIsOnThePage() {
        XCTAssertEqual(dictionary.respelling(of: "daring", meaning: "在..期間"), "during")
        XCTAssertEqual(dictionary.respelling(of: "Daring", meaning: "在…期間"), "During")
        // A word that means what is printed is left alone.
        XCTAssertNil(dictionary.respelling(of: "daring", meaning: "大膽的"))
        XCTAssertNil(dictionary.respelling(of: "during", meaning: "在..期間"))
        // A meaning of the learner's own matches no near word either.
        XCTAssertNil(dictionary.respelling(of: "daring", meaning: "勇敢"))

        let read = [ScannedWordCandidate(key: "0", meaningZh: "在..期間", partOfSpeech: "", word: "daring")]
        let suggested = ScanGrounding.respelled(read, pageWords: ["daring"], dictionary: dictionary)
        XCTAssertEqual(suggested.map(\.word), ["daring"])
        XCTAssertEqual(suggested.first?.suggestedWord, "during")
        XCTAssertNil(suggested.first?.originalWord)

        let replaced = ScanGrounding.respelled(read, pageWords: ["daring", "during"], dictionary: dictionary)
        XCTAssertEqual(replaced.map(\.word), ["during"])
        XCTAssertEqual(replaced.first?.originalWord, "daring")
        XCTAssertNil(replaced.first?.suggestedWord)
    }
}

/// A handwritten notes page read by Vision: each word with its Chinese on
/// the left, examples in a second column on the right ("since 從什麼時候
/// 開始 … Since I was little 從我小時候開始").
final class ScanNotesPageTests: XCTestCase {
    static let page: [ScannedLine] = [
        ScannedLine(text: "for", x: 0.1063, y: 0.1076, width: 0.0833, height: 0.0347),
        ScannedLine(text: "how_ong", x: 0.2038, y: 0.0836, width: 0.1383, height: 0.0312),
        ScannedLine(text: "多", x: 0.2356, y: 0.1099, width: 0.0632, height: 0.0366),
        ScannedLine(text: "Since", x: 0.1115, y: 0.2640, width: 0.0988, height: 0.0302),
        ScannedLine(text: "when Starts", x: 0.2471, y: 0.2454, width: 0.1840, height: 0.0264),
        ScannedLine(text: "從什麼時候開始", x: 0.2557, y: 0.2756, width: 0.2415, height: 0.0329),
        ScannedLine(text: "during", x: 0.1178, y: 0.3728, width: 0.1034, height: 0.0496),
        ScannedLine(text: "在…期間", x: 0.2701, y: 0.3985, width: 0.1580, height: 0.0347),
        ScannedLine(text: "Sor thvee hours", x: 0.3962, y: 0.0978, width: 0.2679, height: 0.0393),
        ScannedLine(text: "ten years", x: 0.4815, y: 0.1481, width: 0.1845, height: 0.0395),
        ScannedLine(text: "30", x: 0.5029, y: 0.2023, width: 0.0517, height: 0.0176),
        ScannedLine(text: "minuite", x: 0.5632, y: 0.1940, width: 0.1293, height: 0.0239),
        ScannedLine(text: "Since 工 was", x: 0.5567, y: 0.2475, width: 0.2256, height: 0.0288),
        ScannedLine(text: "little", x: 0.7759, y: 0.2435, width: 0.0891, height: 0.0259),
        ScannedLine(text: "從我小時候", x: 0.7213, y: 0.2713, width: 0.1437, height: 0.0326),
        ScannedLine(text: "開始", x: 0.8218, y: 0.3058, width: 0.0690, height: 0.0304),
        ScannedLine(text: "during工walk工Saw", x: 0.5178, y: 0.3761, width: 0.3341, height: 0.0534),
        ScannedLine(text: "a bird.", x: 0.7701, y: 0.4202, width: 0.1178, height: 0.0325),
    ]

    /// The example's Chinese on the same baseline is not part of the
    /// meaning, and the example's words are not entries.
    func testExampleColumnStaysOutOfTheEntries() {
        let found = ScanParser.parsePage(Self.page)
        XCTAssertEqual(found.map { "\($0.word.lowercased()) \($0.meaningZh)" }, ["for 多", "since 從什麼時候開始", "during 在…期間"])
    }

    func testAMeaningEndsItsRow() {
        let rows = ScanParser.readingRows(Self.page).map(\.text)
        XCTAssertTrue(rows.contains("Since 從什麼時候開始"), "\(rows)")
        XCTAssertTrue(rows.contains("從我小時候"), "\(rows)")
        XCTAssertTrue(rows.contains("during 在…期間"), "\(rows)")
    }
}
