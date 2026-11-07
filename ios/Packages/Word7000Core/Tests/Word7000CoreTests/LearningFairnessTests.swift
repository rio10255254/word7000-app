import XCTest
@testable import Word7000Core

/// WordCat Next: the learning system as each learner meets it: questions in
/// the shape of their own exam, checks in the language they learn, a pace
/// that follows the scheduler, speaking that counts, no check waved through.
final class LearningFairnessTests: XCTestCase {
    private func entry(_ word: String, pos: String, meaning: String, example: String = "", zh: String = "",
                       group: String = "Core 3") -> WordEntry {
        WordEntry(id: "w-\(word)", word: word, partOfSpeech: pos, pronunciation: "", meaningZh: meaning,
                  example: example, exampleZh: zh, group: group)
    }

    // MARK: Exam styles

    func testExamStyleFollowsTheExam() {
        XCTAssertEqual(ExamStyle(exam: "gsat"), .gsat)
        XCTAssertEqual(ExamStyle(exam: "tvee"), .tvee)
        XCTAssertEqual(ExamStyle(exam: "cap"), .cap)
        XCTAssertEqual(ExamStyle(exam: "proficiency"), .proficiency)
        XCTAssertEqual(ExamStyle(exam: "none"), .open)
        XCTAssertEqual(ExamStyle(exam: nil), .gsat)
    }

    private var nouns: [WordEntry] {
        [
            entry("decision", pos: "n.", meaning: "決定", example: "She made a quick decision about the trip."),
            entry("decide", pos: "v.", meaning: "決定；下決心"),
            entry("decisive", pos: "adj.", meaning: "果斷的"),
            entry("division", pos: "n.", meaning: "分割"),
            entry("decoration", pos: "n.", meaning: "裝飾"),
            entry("precision", pos: "n.", meaning: "精確"),
            entry("garden", pos: "n.", meaning: "花園"),
            entry("journey", pos: "n.", meaning: "旅程"),
            entry("kitchen", pos: "n.", meaning: "廚房"),
            entry("market", pos: "n.", meaning: "市場"),
            entry("pencil", pos: "n.", meaning: "鉛筆"),
        ]
    }

    func testGsatOffersLookAlikes() throws {
        let pool = ExamPool(nouns)
        let question = try XCTUnwrap(ExamQuestions.make(for: nouns[0], pool: pool, seed: "s", style: .gsat))
        let wrong = question.options.filter { $0 != question.answer }
        // Mostly look-alikes of "decision": division, decoration, precision.
        XCTAssertGreaterThanOrEqual(Set(wrong).intersection(["division", "decoration", "precision"]).count, 2, "\(wrong)")
        XCTAssertFalse(question.wordForm)
    }

    func testCapAsksTheMeaningWithoutSpellingTraps() throws {
        let pool = ExamPool(nouns)
        for seed in ["a", "b", "c", "d"] {
            let question = try XCTUnwrap(ExamQuestions.make(for: nouns[0], pool: pool, seed: seed, style: .cap))
            let wrong = question.options.filter { $0 != question.answer }
            XCTAssertEqual(wrong.count, 3)
            for option in wrong {
                XCTAssertLessThan(ExamQuestions.similarity(option, "decision"), 6, "\(option) looks like the answer")
                XCTAssertTrue(["garden", "journey", "kitchen", "market", "pencil"].contains(option), option)
            }
        }
    }

    func testProficiencyAsksTheWordFormWhenTheFamilyIsThere() throws {
        let answer = entry("consideration", pos: "n.", meaning: "考慮", example: "Thank you for your consideration of my request.")
        let words = [answer, entry("consider", pos: "v.", meaning: "考慮；認為"), entry("considerable", pos: "adj.", meaning: "相當大的")]
            + nouns.dropFirst(6)
        let question = try XCTUnwrap(ExamQuestions.make(for: answer, pool: ExamPool(words), seed: "s", style: .proficiency))
        XCTAssertTrue(question.wordForm)
        XCTAssertTrue(question.options.contains("consider"))
        XCTAssertTrue(question.options.contains("considerable"))
        XCTAssertEqual(question.answer, "consideration")
    }

    func testWordsThatOnlyStartAlikeAreNoFamily() {
        let pool = ExamPool([entry("consider", pos: "v.", meaning: "考慮"), entry("constant", pos: "adj.", meaning: "不變的"),
                             entry("production", pos: "n.", meaning: "生產"), entry("produce", pos: "v.", meaning: "生產")])
        XCTAssertEqual(ExamQuestions.familyForms(of: "consider", pos: "v", pool: pool), [])
        // Starting alike is not enough.
        let alike = ExamPool([entry("think", pos: "v.", meaning: "想"), entry("thing", pos: "n.", meaning: "東西"),
                              entry("thin", pos: "adj.", meaning: "瘦的"), entry("within", pos: "prep.", meaning: "在…之內"),
                              entry("withdraw", pos: "v.", meaning: "撤回"), entry("consistent", pos: "adj.", meaning: "一致的"),
                              entry("consideration", pos: "n.", meaning: "考慮"), entry("disapproval", pos: "n.", meaning: "不贊成"),
                              entry("disappointment", pos: "n.", meaning: "失望")])
        XCTAssertEqual(ExamQuestions.familyForms(of: "thing", pos: "n", pool: alike), [])
        XCTAssertEqual(ExamQuestions.familyForms(of: "without", pos: "prep", pool: alike), [])
        XCTAssertEqual(ExamQuestions.familyForms(of: "consider", pos: "v", pool: alike), ["consideration"])
        XCTAssertEqual(ExamQuestions.familyForms(of: "disapprove", pos: "v", pool: alike), ["disapproval"])
        XCTAssertEqual(ExamQuestions.familyForms(of: "produce", pos: QuizBuilder.primaryPartOfSpeech("v."), pool: pool), ["production"])
    }

    func testProficiencyWithoutAFamilyAsksTheMeaning() throws {
        let words = [entry("journey", pos: "n.", meaning: "旅程", example: "The journey took three days.")] + nouns.dropFirst(3)
        let question = try XCTUnwrap(ExamQuestions.make(for: words[0], pool: ExamPool(Array(words)), seed: "s", style: .proficiency))
        XCTAssertFalse(question.wordForm)
        XCTAssertEqual(question.options.count, 4)
    }

    private func bundled(_ name: String) throws -> [WordEntry] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Word7000/Resources/\(name).json")
        return try WordData.decode(Data(contentsOf: url))
    }

    /// Every exam style can ask most of the real list, with four different options.
    func testEveryStyleAsksMostBundledWords() throws {
        let words = try bundled("words")
        let pool = ExamPool(words)
        let sample = stride(from: 0, to: words.count, by: 70).map { words[$0] }
        var families = 0
        for style in [ExamStyle.gsat, .cap, .proficiency] {
            let asked = sample.compactMap { ExamQuestions.make(for: $0, pool: pool, seed: "s", style: style) }
            XCTAssertGreaterThanOrEqual(Double(asked.count) / Double(sample.count), 0.8, "\(style)")
            for question in asked {
                XCTAssertEqual(Set(question.options.map { $0.lowercased() }).count, 4, "\(style) \(question.wordId)")
                if question.wordForm { families += 1 }
            }
        }
        XCTAssertGreaterThan(families, 0, "some words come with their family")
    }

    /// Learners of Chinese: most of the Chinese list has a Chinese question.
    func testMostOfTheChineseListHasAChineseQuestion() throws {
        let words = try bundled("words-zh")
        let pool = ExamPool(words, chinese: true)
        let sample = stride(from: 0, to: words.count, by: 25).map { words[$0] }
        let sentences = sample.filter { Cloze.chineseSentence(for: $0) != nil }
        XCTAssertGreaterThanOrEqual(Double(sentences.count) / Double(sample.count), 0.7)
        let asked = sentences.compactMap { ExamQuestions.make(for: $0, pool: pool, seed: "s") }
        XCTAssertGreaterThanOrEqual(Double(asked.count) / Double(sentences.count), 0.8)
        for question in asked { XCTAssertEqual(Set(question.options).count, 4, question.wordId) }
    }

    // MARK: Learners of Chinese

    private var chineseWords: [WordEntry] {
        [
            entry("difficult; hard", pos: "adj.", meaning: "難；困難", example: "Is Chinese difficult?", zh: "中文難不難？"),
            entry("easy", pos: "adj.", meaning: "容易", example: "This character is easy to write.", zh: "這個字很容易寫。"),
            entry("busy", pos: "adj.", meaning: "忙", zh: "我今天很忙。"),
            entry("happy", pos: "adj.", meaning: "高興；快樂", zh: "我很高興。"),
            entry("tired", pos: "adj.", meaning: "累", zh: "我好累。"),
            entry("simple", pos: "adj.", meaning: "簡單", zh: "這題很簡單。"),
        ]
    }

    func testChineseLearnersFillInTheChineseWord() throws {
        let easy = try XCTUnwrap(Cloze.chineseSentence(for: chineseWords[1]))
        XCTAssertEqual(easy.answer, "容易")
        XCTAssertEqual(easy.pieces, [.text("這個字很"), .blank, .text("寫。")])
        // Every place the word stands is blanked, or the sentence gives it away.
        let hard = try XCTUnwrap(Cloze.chineseSentence(for: chineseWords[0]))
        XCTAssertEqual(hard.answer, "難")
        XCTAssertEqual(hard.pieces, [.text("中文"), .blank, .text("不"), .blank, .text("？")])
        XCTAssertNotNil(Cloze.sentence(for: chineseWords[1], chinese: true))
        // Not in its sentence: no question.
        XCTAssertNil(Cloze.chineseSentence(for: entry("rain", pos: "n.", meaning: "雨", zh: "今天很冷。")))
    }

    func testChineseExamQuestionsOfferChineseWords() throws {
        let pool = ExamPool(chineseWords, chinese: true)
        XCTAssertTrue(pool.chinese)
        let question = try XCTUnwrap(ExamQuestions.make(for: chineseWords[1], pool: pool, seed: "s"))
        XCTAssertEqual(question.answer, "容易")
        XCTAssertEqual(question.options.count, 4)
        for option in question.options {
            XCTAssertTrue(option.unicodeScalars.allSatisfy { Cloze.isHan($0) }, option)
        }
    }

    // MARK: A check that cannot be asked

    func testAnUnaskableCheckIsReplacedFromTheReserve() {
        var routine = WordRoutine(cardIds: ["a", "b", "c", "d"], stagesBefore: [:], sourceKey: "k", day: "2026-11-07")
        routine.planChecks(knownIds: ["a", "b", "c", "d"], unsureIds: [], maxSpell: 2, maxExam: 0,
                           canSpell: { _ in true }, canExam: { _ in false })
        XCTAssertEqual(routine.spellIds, ["a", "b"])
        routine.replaceUnaskable("a")
        XCTAssertEqual(routine.spellIds, ["c", "b"], "the next word takes its place")
        XCTAssertEqual(routine.spellLeft.first, "c")
        routine.replaceUnaskable("c")
        routine.replaceUnaskable("d")
        routine.replaceUnaskable("b")
        XCTAssertTrue(routine.spellIds.isEmpty, "with the reserve used up the step is one shorter, not waved through")
        XCTAssertEqual(routine.summary.checked, 0)
    }

    func testAnsweredChecksAreNotReplaced() {
        var routine = WordRoutine(cardIds: ["a", "b", "c"], stagesBefore: [:], sourceKey: "k", day: "2026-11-07")
        routine.planChecks(knownIds: ["a", "b", "c"], unsureIds: [], maxSpell: 1, maxExam: 0,
                           canSpell: { _ in true }, canExam: { _ in false })
        routine.recordSpell("a", outcome: .knew)
        routine.replaceUnaskable("a")
        XCTAssertEqual(routine.spellIds, ["a"])
    }

    func testRoutinesSavedBeforeTheReserveStillLoad() throws {
        let json = #"{"cardIds":["a"],"stagesBefore":{},"sourceKey":"k","day":"2026-11-07","step":"flip","knownIds":[],"unsureIds":[],"spellIds":[],"examIds":[],"spellResults":{},"examResults":{}}"#
        let routine = try JSONDecoder().decode(WordRoutine.self, from: Data(json.utf8))
        XCTAssertNil(routine.spellReserve)
        XCTAssertEqual(routine.cardIds, ["a"])
    }

    func testACheckThatCatchesANewWordIsNoLapse() {
        let today = "2026-11-07"
        var state = LearningEngine.markKnown(ProgressState(), wordId: "new", today: today)
        state = LearningEngine.applyCheck(state, wordId: "new", today: today, wasNew: true, outcome: .missed)
        XCTAssertEqual(state.words["new"]?.status, .review)
        XCTAssertEqual(state.words["new"]?.lapses ?? 0, 0, "never known, so not forgotten")
        var old = LearningEngine.markKnown(ProgressState(), wordId: "old", today: "2026-10-01")
        old = LearningEngine.markKnown(old, wordId: "old", today: today)
        old = LearningEngine.applyCheck(old, wordId: "old", today: today, wasNew: false, outcome: .missed)
        XCTAssertEqual(old.words["old"]?.lapses, 1)
    }

    func testLevelCheckWordsAreNotTodaysStudy() {
        let today = "2026-11-07"
        let placed = Placement.apply(knownIds: ["a", "b"], learningIds: ["b"], to: ProgressState(dailyProgressDate: today), today: today)
        XCTAssertNil(placed.words["a"]?.lastStudied)
        XCTAssertNil(placed.words["b"]?.lastStudied)
        XCTAssertEqual(LearningEngine.merge([placed, ProgressState(dailyProgressDate: today)]).studiedToday, 0)
        // The ones recognised but not spelled open the first cards.
        let words = ["a", "b", "c", "d", "e", "f"].map { WordEntry(id: $0, word: $0, partOfSpeech: "n.", pronunciation: "", meaningZh: "", example: "", exampleZh: "", group: "Core 1") }
        let queue = LearningEngine.buildStudyQueue(words: words, state: placed, today: today, limit: 2, seed: "s")
        XCTAssertTrue(queue.map(\.id).contains("b"))
    }

    // MARK: Speaking counts

    func testUsingAWordInSpeakingCountsWhereAnAnswerWould() {
        let today = "2026-11-07"
        var state = ProgressState()
        // Never studied: left alone.
        XCTAssertEqual(LearningEngine.creditUse(state, wordId: "new", today: today), state)
        // Marked "not yet" today: said in a sentence, it moves on to tomorrow.
        state = LearningEngine.markReview(state, wordId: "shaky", today: today)
        let afterShaky = LearningEngine.creditUse(state, wordId: "shaky", today: today, changedAt: "t")
        XCTAssertEqual(afterShaky.words["shaky"]?.status, .mastered)
        XCTAssertEqual(afterShaky.words["shaky"]?.dueDate, "2026-11-08")
        // Due for review: climbs a box.
        state = LearningEngine.markKnown(state, wordId: "due", today: "2026-10-31")
        XCTAssertEqual(state.words["due"]?.stage, 3)
        let afterDue = LearningEngine.creditUse(state, wordId: "due", today: today, changedAt: "t")
        XCTAssertEqual(afterDue.words["due"]?.stage, 4)
        // Not due yet: its review is not put off.
        state = LearningEngine.markKnown(state, wordId: "fresh", today: "2026-11-05")
        XCTAssertEqual(LearningEngine.creditUse(state, wordId: "fresh", today: today), state)
    }

    // MARK: The pace

    func testThePaceFollowsTheScheduler() {
        let day = "2026-11-07"
        // The first day holds only new words.
        XCTAssertEqual(LearningEngine.projectedNewWords(state: ProgressState(), today: day, dailyTarget: 20, days: 1,
                                                        freshAvailable: 1000), 20)
        // Over a long stretch reviews take their share, but new words never
        // drop under two in five (8 of 20).
        let year = LearningEngine.projectedNewWords(state: ProgressState(), today: day, dailyTarget: 20, days: 200,
                                                    freshAvailable: 100_000)
        XCTAssertGreaterThanOrEqual(year, 8 * 200)
        XCTAssertLessThan(year, 12 * 200, "slower than the flat three in five the plan used to assume")
        // Reviews already piled up: the first day gives new words only their share.
        var backlog = ProgressState()
        for n in 0..<40 { backlog = LearningEngine.markReview(backlog, wordId: "w\(n)", today: "2026-11-01") }
        XCTAssertEqual(LearningEngine.projectedNewWords(state: backlog, today: day, dailyTarget: 20, days: 1,
                                                        freshAvailable: 1000), 8)
        // No more new words than there are.
        XCTAssertEqual(LearningEngine.projectedNewWords(state: ProgressState(), today: day, dailyTarget: 20, days: 30,
                                                        freshAvailable: 25), 25)
        XCTAssertEqual(PlacementTest.chaptersReached(from: 3, newWords: 1200), 5)
        XCTAssertEqual(PlacementTest.chaptersReached(from: 13, newWords: 5000), PlacementTest.topLevel)
        // An exam date far off is counted up to ten years, not forever.
        XCTAssertGreaterThan(LearningEngine.projectedNewWords(state: ProgressState(), today: day, dailyTarget: 20, days: 1_000_000,
                                                              freshAvailable: 100_000), 0)
    }
}
