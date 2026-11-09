import XCTest
@testable import Word7000Core

final class ClozeTests: XCTestCase {
    private func word(_ text: String, example: String = "", exampleZh: String = "", cue: String? = nil, meaning: String = "意思") -> WordEntry {
        WordEntry(id: "w-\(text)", word: text, partOfSpeech: "n", pronunciation: "", meaningZh: meaning,
                  example: example, exampleZh: exampleZh, exampleZhCue: cue, group: "Core 1")
    }

    // MARK: The English sentence

    func testBlanksTheWordAndKeepsTheRest() {
        let sentence = Cloze.blanked("Children adapt to new bus routes.", word: "adapt")
        XCTAssertEqual(sentence?.pieces, [.text("Children "), .blank, .text(" to new bus routes.")])
        XCTAssertEqual(sentence?.answer, "adapt")
    }

    func testTheAnswerIsSpelledAsInTheSentence() {
        let sentence = Cloze.blanked("Adapt quickly, or the bus leaves.", word: "adapt")
        XCTAssertEqual(sentence?.pieces.first, .blank)
        XCTAssertEqual(sentence?.answer, "Adapt")
    }

    func testOnlyWholeWordsAreBlanked() {
        let sentence = Cloze.blanked("Start the art class at noon.", word: "art")
        XCTAssertEqual(sentence?.pieces, [.text("Start the "), .blank, .text(" class at noon.")])
        XCTAssertNil(Cloze.blanked("We start at noon.", word: "art"))
    }

    func testEveryPlaceTheWordAppearsIsBlanked() {
        let sentence = Cloze.blanked("Take one dose now and one dose later.", word: "dose")
        XCTAssertEqual(sentence?.pieces, [.text("Take one "), .blank, .text(" now and one "), .blank, .text(" later.")])
    }

    func testPhrasesAndPossessives() {
        XCTAssertEqual(Cloze.blanked("Please look after the dog.", word: "look after")?.pieces,
                       [.text("Please "), .blank, .text(" the dog.")])
        XCTAssertEqual(Cloze.blanked("The children's bus is late.", word: "children")?.pieces,
                       [.text("The "), .blank, .text("'s bus is late.")])
    }

    func testAWordMissingFromItsSentenceHasNoQuestion() {
        // A custom word whose example uses another form.
        XCTAssertNil(Cloze.sentence(for: word("adapt", example: "The children adapted quickly.")))
        XCTAssertNil(Cloze.sentence(for: word("adapt", example: "")))
        // A suffix after a hyphen is still a whole word to fill in.
        XCTAssertEqual(Cloze.sentence(for: word("tion", example: "Add -tion to the verb act."))?.answer, "tion")
    }

    // MARK: The Chinese cue

    func testTheCueSplitsTheTranslation() {
        let entry = word("adapt", exampleZh: "孩子們逐漸習慣了新的公車路線。", cue: "習慣")
        XCTAssertEqual(Cloze.cue(for: entry), Cloze.Cue(before: "孩子們逐漸", cue: "習慣", after: "了新的公車路線。"))
    }

    func testAContextPinsACueThatAppearsTwice() {
        let entry = word("car", exampleZh: "長途開車前，我的車需要換新輪胎。", cue: "我的|車")
        XCTAssertEqual(Cloze.cue(for: entry), Cloze.Cue(before: "長途開車前，我的", cue: "車", after: "需要換新輪胎。"))
    }

    func testAStaleOrMissingCueIsNoCue() {
        XCTAssertNil(Cloze.cue(for: word("adapt", exampleZh: "孩子們很快就適應了。", cue: "習慣")))
        XCTAssertNil(Cloze.cue(for: word("of", exampleZh: "烤玉米的香氣。", cue: "")))
        XCTAssertNil(Cloze.cue(for: word("of", exampleZh: "烤玉米的香氣。", cue: nil)))
    }

    // MARK: Judging

    func testCaseSpacesAndCurlyApostrophesDoNotCount() {
        XCTAssertEqual(Cloze.judge("  ADAPT ", answer: "Adapt"), .correct)
        XCTAssertEqual(Cloze.judge("don\u{2019}t", answer: "don't"), .correct)
        XCTAssertEqual(Cloze.judge("", answer: "adapt"), .wrong)
    }

    func testAnotherFormOfTheWordIsNamedAsSuch() {
        XCTAssertEqual(Cloze.judge("adapted", answer: "adapt"), .otherForm)
        XCTAssertEqual(Cloze.judge("study", answer: "studies"), .otherForm)
        XCTAssertEqual(Cloze.judge("making", answer: "make"), .otherForm)
        XCTAssertEqual(Cloze.judge("stopped", answer: "stop"), .otherForm)
        XCTAssertEqual(Cloze.judge("tries", answer: "try"), .otherForm)
        XCTAssertEqual(Cloze.judge("watches", answer: "watch"), .otherForm)
        // Words of their own are not forms.
        XCTAssertEqual(Cloze.judge("owner", answer: "own"), .wrong)
        XCTAssertEqual(Cloze.judge("bed", answer: "be"), .wrong)
    }

    func testAnotherRealWordSaysWhatItMeans() {
        let list = ["ass": word("ass", meaning: "屁股"), "affect": word("affect", meaning: "影響")]
        XCTAssertEqual(Cloze.judge("ass", answer: "ego", lookup: { list[$0] }), .otherWord(word: "ass", meaning: "屁股"))
        // A real word one letter away is still named, not "almost".
        XCTAssertEqual(Cloze.judge("affect", answer: "effect", lookup: { list[$0] }), .otherWord(word: "affect", meaning: "影響"))
    }

    func testOneLetterOffIsAlmost() {
        XCTAssertEqual(Cloze.judge("recieve", answer: "receive"), .almost)
        XCTAssertEqual(Cloze.judge("honst", answer: "honest"), .almost)
        XCTAssertEqual(Cloze.judge("eg", answer: "ego"), .wrong)
        XCTAssertEqual(Cloze.judge("banana", answer: "honest"), .wrong)
    }

    func testDaysUntilTheWordComesBack() {
        XCTAssertEqual(Cloze.daysUntil("2026-11-12", today: "2026-11-05"), 7)
        XCTAssertEqual(Cloze.daysUntil("2026-11-01", today: "2026-11-05"), 0)
        XCTAssertNil(Cloze.daysUntil(nil, today: "2026-11-05"))
    }

    // MARK: One question

    func testRightStraightAwayIsKnown() {
        var attempt = ClozeAttempt(answer: "ego")
        XCTAssertEqual(attempt.submit("ego"), .correct)
        XCTAssertEqual(attempt.outcome, .knew)
    }

    func testTheFirstLetterOrOneSlipIsALittleHelp() {
        var hinted = ClozeAttempt(answer: "ego")
        XCTAssertEqual(hinted.nextHelp, .firstLetter)
        hinted.takeHelp()
        XCTAssertEqual(hinted.lettersShown, 1)
        hinted.submit("ego")
        XCTAssertEqual(hinted.outcome, .gotIt)

        var slipped = ClozeAttempt(answer: "honest")
        XCTAssertEqual(slipped.submit("honst"), .almost)
        XCTAssertNil(slipped.outcome)
        slipped.submit("honest")
        XCTAssertEqual(slipped.outcome, .gotIt)
    }

    func testShowingTheAnswerStillNeedsItTypedAndCountsAsMissed() {
        var attempt = ClozeAttempt(answer: "ego")
        attempt.takeHelp()
        XCTAssertEqual(attempt.nextHelp, .answer)
        attempt.takeHelp()
        XCTAssertTrue(attempt.answerShown)
        XCTAssertNil(attempt.nextHelp)
        XCTAssertFalse(attempt.solved)
        attempt.submit("ego")
        XCTAssertEqual(attempt.outcome, .missed)
    }

    func testThreeMissesShowTheAnswer() {
        var attempt = ClozeAttempt(answer: "ego")
        attempt.submit("ass")
        attempt.submit("asshole")
        XCTAssertFalse(attempt.answerShown)
        attempt.submit("e")
        XCTAssertTrue(attempt.answerShown)
        attempt.submit("ego")
        XCTAssertEqual(attempt.outcome, .missed)
    }

    func testAOneLetterWordOffersTheAnswerStraightAway() {
        XCTAssertEqual(ClozeAttempt(answer: "a").nextHelp, .answer)
    }

    // MARK: A round

    private func entries(_ spec: [(String, Bool, Int)]) -> [ClozeRound.Entry] {
        spec.map { ClozeRound.Entry(wordId: $0.0, isNew: $0.1, stage: $0.2) }
    }

    func testWellKnownReviewsOpenAndCloseTheRound() {
        let round = ClozeRound(entries: entries([("n1", true, 0), ("r1", false, 1), ("n2", true, 0),
                                                 ("r5", false, 5), ("r3", false, 3), ("n3", true, 0)]))
        XCTAssertEqual(round.order, ["r5", "r3", "n1", "n2", "n3", "r1"])
    }

    func testANewLearnerKeepsTheOrderGiven() {
        let round = ClozeRound(entries: entries([("n1", true, 0), ("n2", true, 0), ("n2", true, 0)]))
        XCTAssertEqual(round.order, ["n1", "n2"])
        XCTAssertEqual(round.initialCount, 2)
    }

    func testAMissedWordComesBackThreeQuestionsLater() {
        var round = ClozeRound(entries: entries((1...6).map { ("n\($0)", true, 0) }))
        round.record(.missed)
        XCTAssertEqual(round.order, ["n1", "n2", "n3", "n4", "n1", "n5", "n6"])
        XCTAssertTrue(round.comesBack("n1"))
        round.record(.knew); round.record(.knew); round.record(.knew)
        XCTAssertEqual(round.currentWordId, "n1")
        XCTAssertTrue(round.isSecondLook)
        round.record(.missed)
        XCTAssertFalse(round.comesBack("n1"), "a word comes back once")
    }

    func testTheLastWordIsNotRepeatedStraightAway() {
        var round = ClozeRound(entries: entries([("n1", true, 0)]))
        round.record(.missed)
        XCTAssertTrue(round.isComplete)
    }

    func testAtMostHalfTheRoundComesBack() {
        var round = ClozeRound(entries: entries((1...4).map { ("n\($0)", true, 0) }))
        XCTAssertEqual(round.maxRequeues, 2)
        round.record(.missed)
        round.record(.missed)
        round.record(.missed)
        XCTAssertEqual(round.requeued.count, 2)
    }

    func testARunOfMissesBringsTheEasiestWordForward() {
        var round = ClozeRound(entries: entries([("n1", true, 0), ("n2", true, 0), ("n3", true, 0),
                                                 ("n4", true, 0), ("n5", true, 0), ("n6", true, 0),
                                                 ("n7", true, 0), ("r2", false, 2)]))
        // r2 is the only review, so it closes nothing (needs three) and opens the round.
        XCTAssertEqual(round.order.first, "r2")
        round.record(.knew)
        round.record(.missed); round.record(.missed); round.record(.missed)
        // No review word is left to bring forward, so the order stays.
        XCTAssertEqual(round.currentWordId, "n4")

        var harder = ClozeRound(entries: entries([("n1", true, 0), ("n2", true, 0), ("n3", true, 0),
                                                  ("n4", true, 0), ("n5", true, 0), ("r1", false, 1),
                                                  ("r4", false, 4), ("r6", false, 6)]))
        XCTAssertEqual(harder.order, ["r6", "r4", "n1", "n2", "n3", "n4", "n5", "r1"])
        harder.record(.knew); harder.record(.knew)
        harder.record(.missed); harder.record(.missed); harder.record(.missed)
        XCTAssertEqual(harder.currentWordId, "r1", "the easiest word left comes next")
    }

    func testTheSummaryCountsEachWordByItsFirstAnswer() {
        var round = ClozeRound(entries: entries([("n1", true, 0), ("n2", true, 0), ("n3", true, 0), ("r1", false, 2)]))
        // Order: r1, n1, n2, n3.
        round.record(.knew)    // r1
        round.record(.knew)    // n1: already known
        round.record(.missed)  // n2: comes back at the end
        round.record(.gotIt)   // n3
        XCTAssertEqual(round.currentWordId, "n2")
        round.record(.knew)    // n2 again
        XCTAssertTrue(round.isComplete)
        XCTAssertEqual(round.summary, ClozeRound.Summary(alreadyKnew: 1, learned: 2, reviewed: 1, missed: 1))
    }

    // MARK: The bundled list

    func testEveryBundledWordHasAQuestionAndMostHaveACue() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Word7000/Resources/words.json")
        let words = try WordData.decode(Data(contentsOf: url))
        let questions = words.filter { Cloze.sentence(for: $0) != nil }
        let cues = words.filter { Cloze.cue(for: $0) != nil }
        XCTAssertGreaterThanOrEqual(questions.count, 6990)
        XCTAssertGreaterThanOrEqual(cues.count, 6980)
    }
}
