import XCTest
@testable import Word7000Core

final class WordRoutineTests: XCTestCase {
    private func routine(stages: [String: Int], cards: [String]) -> WordRoutine {
        WordRoutine(cardIds: cards, stagesBefore: stages, sourceKey: "core", day: "2026-11-05")
    }

    // MARK: Picking the checks

    func testKnownYoungWordsAreSpelledAndOlderOnesGetExamQuestions() {
        var r = routine(stages: ["r1": 1, "r4": 4, "r6": 6], cards: ["n1", "r1", "r4", "n2", "r6", "n3"])
        r.planChecks(knownIds: ["n1", "r1", "r4", "n2", "r6"], unsureIds: ["n3"],
                     canSpell: { _ in true }, canExam: { _ in true })
        XCTAssertEqual(r.spellIds, ["n1", "n2", "r1"], "new words first, then the young reviews")
        XCTAssertEqual(r.examIds, ["r4", "r6"])
        XCTAssertEqual(r.step, .spell)
    }

    func testWordsMarkedNotYetAreNotChecked() {
        var r = routine(stages: [:], cards: ["n1", "n2"])
        r.planChecks(knownIds: [], unsureIds: ["n1", "n2"], canSpell: { _ in true }, canExam: { _ in true })
        XCTAssertEqual(r.step, .done)
        XCTAssertTrue(r.spellIds.isEmpty && r.examIds.isEmpty)
    }

    func testChecksAreCappedAndSkipWordsThatCannotBeAsked() {
        let cards = (1...10).map { "n\($0)" } + (1...8).map { "r\($0)" }
        let stages = Dictionary(uniqueKeysWithValues: (1...8).map { ("r\($0)", 5) })
        var r = routine(stages: stages, cards: cards)
        r.planChecks(knownIds: cards, unsureIds: [], canSpell: { $0 != "n1" }, canExam: { $0 != "r2" })
        XCTAssertEqual(r.spellIds, ["n2", "n3", "n4", "n5", "n6", "n7"])
        XCTAssertEqual(r.examIds, ["r1", "r3", "r4", "r5", "r6"])
    }

    func testOnlyExamQuestionsGoStraightToTheExamStep() {
        var r = routine(stages: ["r1": 3], cards: ["r1"])
        r.planChecks(knownIds: ["r1"], unsureIds: [], canSpell: { _ in true }, canExam: { _ in true })
        XCTAssertEqual(r.step, .exam)
    }

    // MARK: Going through the steps

    func testStepsAndTheSummary() {
        var r = routine(stages: ["r1": 1, "r4": 4], cards: ["n1", "n2", "n3", "r1", "r4"])
        r.planChecks(knownIds: ["n1", "n2", "r1", "r4"], unsureIds: ["n3"], canSpell: { _ in true }, canExam: { _ in true })
        XCTAssertEqual(r.spellLeft, ["n1", "n2", "r1"])
        r.recordSpell("n1", outcome: .knew)
        r.recordSpell("n2", outcome: .missed)
        r.recordSpell("n2", outcome: .knew)  // the first answer counts
        r.recordSpell("r1", outcome: .gotIt)
        r.recordExam("r4", correct: true)    // not the exam step yet
        XCTAssertTrue(r.examResults.isEmpty)
        r.finishSpell()
        XCTAssertEqual(r.step, .exam)
        r.recordExam("r4", correct: false)
        r.finishExam()
        XCTAssertEqual(r.step, .done)
        XCTAssertEqual(r.caughtIds, ["n2", "r4"])
        XCTAssertEqual(r.summary, WordRoutine.Summary(alreadyKnew: 1, learned: 2, reviewed: 2, caught: 2, checked: 4))
    }

    func testChecksCanBeLeftForAnotherDay() {
        var r = routine(stages: [:], cards: ["n1"])
        r.planChecks(knownIds: ["n1"], unsureIds: [], canSpell: { _ in true }, canExam: { _ in true })
        r.skipChecks()
        XCTAssertEqual(r.step, .done)
        XCTAssertEqual(r.summary.alreadyKnew, 1)
    }

    func testTheRoutineSurvivesBeingSaved() throws {
        var r = routine(stages: ["r4": 4], cards: ["n1", "r4"])
        r.planChecks(knownIds: ["n1", "r4"], unsureIds: [], canSpell: { _ in true }, canExam: { _ in true })
        r.recordSpell("n1", outcome: .gotIt)
        let decoded = try JSONDecoder().decode(WordRoutine.self, from: JSONEncoder().encode(r))
        XCTAssertEqual(decoded, r)
    }

    // MARK: The schedule after a check

    func testACheckAdjustsTheSchedule() {
        let today = "2026-11-05"
        var state = ProgressState(dailyTarget: 20)
        state = LearningEngine.markKnown(state, wordId: "n1", today: today)
        XCTAssertEqual(state.words["n1"]?.stage, 3)

        XCTAssertEqual(LearningEngine.applyCheck(state, wordId: "n1", today: today, wasNew: true, outcome: .knew), state)

        let helped = LearningEngine.applyCheck(state, wordId: "n1", today: today, wasNew: true, outcome: .gotIt, changedAt: "t")
        XCTAssertEqual(helped.words["n1"]?.stage, 1)
        XCTAssertEqual(helped.words["n1"]?.dueDate, "2026-11-06")
        XCTAssertEqual(helped.words["n1"]?.status, .mastered)

        XCTAssertEqual(LearningEngine.applyCheck(state, wordId: "n1", today: today, wasNew: false, outcome: .gotIt), state)

        let caught = LearningEngine.applyCheck(state, wordId: "n1", today: today, wasNew: true, outcome: .missed)
        XCTAssertEqual(caught.words["n1"]?.status, .review)
        XCTAssertEqual(caught.words["n1"]?.stage, 0)
        XCTAssertEqual(caught.words["n1"]?.dueDate, today)
    }

    // MARK: Exam questions

    private func entry(_ word: String, pos: String, meaning: String, extra: String? = nil, example: String = "",
                       zh: String = "", cue: String? = nil, group: String = "Core 3") -> WordEntry {
        WordEntry(id: "w-\(word)", word: word, partOfSpeech: pos, pronunciation: "", meaningZh: meaning,
                  supplementalMeaningZh: extra, example: example, exampleZh: zh, exampleZhCue: cue, group: group)
    }

    private lazy var pool: [WordEntry] = [
        entry("adapt", pos: "vt / vi", meaning: "適應", extra: "調整；改編"),
        entry("adopt", pos: "vt", meaning: "收養", extra: "採用"),
        entry("admit", pos: "vt", meaning: "承認"),
        entry("adjust", pos: "vt", meaning: "調整"),
        entry("adore", pos: "vt", meaning: "非常喜愛"),
        entry("advise", pos: "vt", meaning: "勸告"),
        entry("adapted", pos: "a", meaning: "適合的"),
        entry("banana", pos: "n", meaning: "香蕉"),
        entry("look after", pos: "v", meaning: "照顧"),
    ]

    func testExamOptionsLookAlikeButMeanSomethingElse() throws {
        let word = entry("adapt", pos: "vt / vi", meaning: "適應", extra: "調整；改編",
                         example: "Children adapt to new bus routes after a few rainy mornings.",
                         zh: "連續幾個下雨的早晨後，孩子們逐漸習慣了新的公車路線。", cue: "習慣")
        let question = try XCTUnwrap(ExamQuestions.make(for: word, pool: pool, seed: "s"))
        XCTAssertEqual(question.options.count, 4)
        XCTAssertEqual(Set(question.options).count, 4)
        XCTAssertEqual(question.answer, "adapt")
        XCTAssertTrue(question.options.contains("adopt"), "the reviewed look-alike is always offered")
        XCTAssertFalse(question.options.contains("adjust"), "a word sharing a sense would also be right")
        XCTAssertFalse(question.options.contains("banana"), "another part of speech gives itself away")
        XCTAssertFalse(question.options.contains("adapted"))
        XCTAssertEqual(question.sentence.pieces.first, .text("Children "))
    }

    func testExamOptionsFollowACapitalisedBlank() throws {
        let word = entry("admit", pos: "vt", meaning: "承認", example: "Admit it, you ate the last dumpling.")
        let question = try XCTUnwrap(ExamQuestions.make(for: word, pool: pool, seed: "s"))
        XCTAssertEqual(question.answer, "Admit")
        XCTAssertTrue(question.options.allSatisfy { $0.first?.isUppercase == true })
    }

    func testPhrasesAndThinPoolsHaveNoExamQuestion() {
        XCTAssertNil(ExamQuestions.make(for: entry("look after", pos: "v", meaning: "照顧", example: "Please look after the dog."),
                                        pool: pool, seed: "s"))
        let word = entry("banana", pos: "n", meaning: "香蕉", example: "A banana a day.")
        XCTAssertNil(ExamQuestions.make(for: word, pool: pool, seed: "s"), "no other nouns to choose from")
    }

    func testSensesOverlap() {
        XCTAssertTrue(ExamQuestions.sharesSense(["調整"], ["調整", "改編"]))
        XCTAssertTrue(ExamQuestions.sharesSense(["辛辣的"], ["辛辣"]))
        XCTAssertFalse(ExamQuestions.sharesSense(["有"], ["有些"]))
        XCTAssertFalse(ExamQuestions.sharesSense(["收養"], ["承認"]))
    }

    func testLookAlikesScoreHigher() {
        XCTAssertGreaterThan(ExamQuestions.similarity("adapt", "adopt"), ExamQuestions.similarity("adapt", "advise"))
        XCTAssertGreaterThan(ExamQuestions.similarity("adapt", "advise"), ExamQuestions.similarity("adapt", "banana"))
        XCTAssertEqual(ExamQuestions.editDistance(Array("adapt"), Array("adopt")), 1)
    }

    func testMostBundledWordsHaveAnExamQuestion() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Word7000/Resources/words.json")
        let words = try WordData.decode(Data(contentsOf: url))
        let pool = ExamPool(words)
        let sample = stride(from: 0, to: words.count, by: 70).map { words[$0] }
        let asked = sample.compactMap { ExamQuestions.make(for: $0, pool: pool, seed: "s") }
        XCTAssertGreaterThanOrEqual(Double(asked.count) / Double(sample.count), 0.8)
        for question in asked {
            XCTAssertEqual(Set(question.options.map { $0.lowercased() }).count, 4, question.wordId)
        }
    }
}
