import XCTest
@testable import Word7000Core

final class SpeakingReflectionTests: XCTestCase {
    func testEditorialPackHasUniqueWordsPairedContrastsAndActualExamples() {
        XCTAssertEqual(WordNotes.all.count, 24)
        XCTAssertEqual(Set(WordNotes.all.map(\.word)).count, 24)
        for note in WordNotes.all {
            XCTAssertNotNil(WordNotes.note(for: note.contrast))
            XCTAssertTrue(SpeakingReflection(answer: note.example, target: note.word, chinese: false).containsTarget, note.word)
            XCTAssertFalse(note.explanationZh.isEmpty)
            XCTAssertFalse(note.explanationEn.isEmpty)
            XCTAssertFalse(note.translation.isEmpty)
        }
    }
    func testCorrectionQuotesMustExistAndCannotRepeat() throws {
        let correction = SpeakingCoach.Correction(original: "go", replacement: "went", reason: "Past tense.")
        let feedback = SpeakingCoach.Feedback(rewrite: "I went.", tip: "Past tense.", followUp: "Where?", corrections: [correction])
        XCTAssertNoThrow(try feedback.validated(answer: "Yesterday I go."))
        XCTAssertThrowsError(try feedback.validated(answer: "I stayed home."))
        XCTAssertThrowsError(try SpeakingCoach.Feedback(rewrite: "r", tip: "t", followUp: "q", corrections: [correction, correction]).validated(answer: "go"))
        XCTAssertNoThrow(try SpeakingCoach.Feedback(rewrite: "I went.", tip: "Clear.", followUp: "Where?").validated(answer: "I went."))
    }
    func testTargetRequiresWholeWordOrPhrase() {
        XCTAssertFalse(SpeakingReflection(answer: "The adaptation worked.", target: "adapt", chinese: false).containsTarget)
        XCTAssertTrue(SpeakingReflection(answer: "We ADAPT quickly!", target: "adapt", chinese: false).containsTarget)
        XCTAssertTrue(SpeakingReflection(answer: "I look forward to tomorrow.", target: "look forward to", chinese: false).containsTarget)
        XCTAssertFalse(SpeakingReflection(answer: "Look at it before moving forward.", target: "look forward to", chinese: false).containsTarget)
    }
    func testLemmaIsExplicitAndNotAGrammarScore() {
        let result = SpeakingReflection(answer: "We adapted.", target: "adapt", chinese: false, matchedLemma: true)
        XCTAssertTrue(result.containsTarget)
        XCTAssertEqual(result.unitCount, 2)
        XCTAssertEqual(result.sentenceCount, 1)
    }
    func testChineseAndEmptyAnswers() {
        let result = SpeakingReflection(answer: "我想試試看。你呢？", target: "試試看", chinese: true)
        XCTAssertTrue(result.containsTarget)
        XCTAssertEqual(result.sentenceCount, 2)
        XCTAssertEqual(result.unitCount, "我想試試看。你呢？".count)
        XCTAssertTrue(SpeakingReflection(answer: "我很確信。", target: "確信；必然的", chinese: true).containsTarget)
        XCTAssertFalse(SpeakingReflection(answer: "", target: "", chinese: true).containsTarget)
        XCTAssertEqual(SpeakingReflection(answer: " ...! ", target: "a", chinese: false).sentenceCount, 0)
    }
    func testPolicyRejectsIncompleteFutureAndOversizedDocuments() {
        XCTAssertNotNil(IntelligencePolicy.decode(Data(#"{"version":1,"speakingCoachEnabled":false,"scanAssistantEnabled":true}"#.utf8)))
        XCTAssertNil(IntelligencePolicy.decode(Data(#"{"version":2,"speakingCoachEnabled":true,"scanAssistantEnabled":true}"#.utf8)))
        XCTAssertNil(IntelligencePolicy.decode(Data(#"{"version":1}"#.utf8)))
        XCTAssertNil(IntelligencePolicy.decode(Data(repeating: 32, count: 4097)))
    }
    func testWeeklySummaryDoesNotInventAccuracy() {
        XCTAssertNil(LearningWeekSummary(days: []).accuracy)
        var counters = DailyLearningCounters()
        counters.studyKnown = 2; counters.studyReview = 3
        counters.quizCorrect = 3; counters.quizWrong = 1; counters.speakingCompleted = 2
        let summary = LearningWeekSummary(days: [.init(date: "2026-10-22", counters: counters)])
        XCTAssertEqual(summary.activeDays, 1)
        XCTAssertEqual(summary.words, 5)
        XCTAssertEqual(summary.speaking, 2)
        XCTAssertEqual(summary.accuracy, 75)
    }
}
