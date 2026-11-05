import XCTest
@testable import Word7000Core

final class LearnerProfileTests: XCTestCase {
    // MARK: What the answers change

    func testSchoolSetsWhereTheTestStartsAndWhichExamIsSuggested() {
        XCTAssertEqual(LearnerProfile.Stage.juniorHigh.testStart, 1)
        XCTAssertEqual(LearnerProfile.Stage.senior3.testStart, 3)
        XCTAssertEqual(LearnerProfile.Stage.juniorHigh.suggestedExam, "cap")
        XCTAssertEqual(LearnerProfile.Stage.senior2.suggestedExam, "gsat")
        XCTAssertEqual(LearnerProfile.Stage.working.suggestedExam, "proficiency")
        XCTAssertEqual(PlacementTest(start: 3).level, 3)
        XCTAssertEqual(PlacementTest(start: 40).level, PlacementTest.topLevel)
    }

    func testAtMostTwoFocusesAndAThirdReplacesTheOldest() {
        var profile = LearnerProfile()
        profile.toggle(.spelling)
        profile.toggle(.speaking)
        profile.toggle(.exam)
        XCTAssertEqual(profile.focus, [.speaking, .exam])
        profile.toggle(.speaking)
        XCTAssertEqual(profile.focus, [.exam])
    }

    func testSpeakingLeadsOnlyWhenPickedWithoutMoreWords() {
        XCTAssertEqual(LearnerProfile(focus: [.speaking]).lead, .speaking)
        XCTAssertEqual(LearnerProfile(focus: [.speaking, .spelling]).lead, .speaking)
        XCTAssertEqual(LearnerProfile(focus: [.speaking, .vocabulary]).lead, .words)
        XCTAssertEqual(LearnerProfile().lead, .words)
        XCTAssertEqual(LearnerProfile(focus: [.vocabulary]).suggestedTarget, 30)
        XCTAssertEqual(LearnerProfile().suggestedTarget, 20)
    }

    func testChecksFollowTheFocusAndTheSpelling() {
        XCTAssertEqual(LearnerProfile().spellChecks, WordRoutine.maxSpell)
        XCTAssertEqual(LearnerProfile(focus: [.spelling]).spellChecks, WordRoutine.maxSpell + 2)
        XCTAssertEqual(LearnerProfile(focus: [.spelling], spelling: 0.2).spellChecks, WordRoutine.maxSpell + 4)
        XCTAssertEqual(LearnerProfile(spelling: 0.95).spellChecks, WordRoutine.maxSpell - 2, "solid spelling: fewer checks")
        XCTAssertEqual(LearnerProfile(focus: [.spelling], spelling: 0.95).spellChecks, WordRoutine.maxSpell + 2, "unless asked for")
        XCTAssertEqual(LearnerProfile(focus: [.exam]).examChecks, WordRoutine.maxExam + 3)
    }

    func testTheSpellingScoreStartsAtTheFirstMeasureThenMovesAThird() {
        var profile = LearnerProfile()
        profile.recordSpelling([.knew, .gotIt, .missed])
        XCTAssertEqual(profile.spelling ?? -1, 0.5, accuracy: 0.001)
        profile.recordSpelling([.knew, .knew])
        XCTAssertEqual(profile.spelling ?? -1, 0.5 * 2 / 3 + 1.0 / 3, accuracy: 0.001)
        profile.recordSpelling([])
        XCTAssertEqual(profile.spelling ?? -1, 0.5 * 2 / 3 + 1.0 / 3, accuracy: 0.001, "nothing spelled changes nothing")
    }

    func testTheProfileSurvivesAnOlderBuildWithoutIt() throws {
        let profile = LearnerProfile(stage: .senior2, focus: [.exam], spelling: 0.4)
        let data = try JSONEncoder().encode(profile)
        XCTAssertEqual(try JSONDecoder().decode(LearnerProfile.self, from: data), profile)
        XCTAssertEqual(try JSONDecoder().decode(LearnerProfile.self, from: Data(#"{"focus":[]}"#.utf8)), LearnerProfile())
    }

    // MARK: The routine takes the profile's numbers

    func testTheRoutineAsksAsManyChecksAsTheProfileSays() {
        let ids = (1...12).map { "n\($0)" }
        var routine = WordRoutine(cardIds: ids, stagesBefore: [:], sourceKey: "k", day: "2026-11-05")
        routine.planChecks(knownIds: ids, unsureIds: [], maxSpell: 9, maxExam: 2, canSpell: { _ in true }, canExam: { _ in true })
        XCTAssertEqual(routine.spellIds.count, 9)
        var plain = WordRoutine(cardIds: ids, stagesBefore: [:], sourceKey: "k", day: "2026-11-05")
        plain.planChecks(knownIds: ids, unsureIds: [], canSpell: { _ in true }, canExam: { _ in true })
        XCTAssertEqual(plain.spellIds.count, WordRoutine.maxSpell)
    }

    // MARK: The spelling on the first launch, and the plan

    private func word(_ id: String, level: Int, cue: String? = "蘋果") -> WordEntry {
        WordEntry(id: id, word: id, partOfSpeech: "n", pronunciation: "", meaningZh: "蘋果",
                  example: "I ate an \(id) today.", exampleZh: "我今天吃了一顆蘋果。", exampleZhCue: cue, group: "Core \(level)")
    }

    func testTheSpellingWordsComeFromTheSettledChapterAndCanBeBlanked() {
        let words = (0..<5).map { word("apple\(String(repeating: "x", count: $0))", level: 2) }
            + (0..<5).map { word("pear\(String(repeating: "y", count: $0))", level: 1) }
            + [word("nocue", level: 2, cue: nil), word("ice cream", level: 2)]
        var test = PlacementTest()
        test.record(wordId: "applex", level: 2, knew: true)
        test.record(wordId: "other", level: 5, knew: false)
        let picked = test.spellingWords(from: words, count: 3, seed: "s")
        XCTAssertEqual(picked.count, 3)
        XCTAssertFalse(picked.contains { $0.id == "applex" }, "not one already asked")
        XCTAssertFalse(picked.contains { $0.id == "nocue" || $0.id == "ice cream" })
        // The settled chapter, or the nearest one with enough words to spell.
        let levels = Set(picked.compactMap { LearningEngine.coreLevel($0.group) })
        XCTAssertEqual(levels.count, 1)
        XCTAssertLessThanOrEqual(abs(levels.first! - test.startChapter), 1, "\(levels) for chapter \(test.startChapter)")
        XCTAssertEqual(picked, test.spellingWords(from: words, count: 3, seed: "s"))
    }

    func testWordsKnownButNotSpelledStartAChapterLower() {
        var test = PlacementTest()
        for (n, level) in [1, 5, 9, 7, 8, 7, 8, 7].enumerated() { test.record(wordId: "w\(n)", level: level, knew: level <= 7) }
        let strong = PersonalPlan(test: test, profile: LearnerProfile(spelling: 1), target: 20, daysToExam: 50)
        let weak = PersonalPlan(test: test, profile: LearnerProfile(spelling: 0), target: 20, daysToExam: 50)
        XCTAssertGreaterThan(strong.startChapter, 1)
        XCTAssertEqual(weak.startChapter, strong.startChapter - 1)
        XCTAssertEqual(strong.reachChapter, PlacementTest.chaptersReached(from: strong.startChapter, wordsPerDay: 20, days: 50))
        XCTAssertNil(PersonalPlan(test: test, profile: LearnerProfile(), target: 20, daysToExam: nil).reachChapter)
        XCTAssertEqual(PersonalPlan(test: PlacementTest(), profile: LearnerProfile(spelling: 0), target: 20, daysToExam: nil).startChapter, 1)
    }

    func testWordsRecognisedButNotSpelledStartAsWordsBeingLearned() {
        let state = Placement.apply(knownIds: ["a", "b"], learningIds: ["b", "c"], to: ProgressState(), today: "2026-11-05")
        XCTAssertEqual(state.words["a"]?.status, .mastered)
        XCTAssertEqual(state.words["b"]?.status, .review, "missed in spelling: not known after all")
        XCTAssertEqual(state.words["c"]?.status, .review)
        XCTAssertEqual(state.words["c"]?.dueDate, "2026-11-05")
        XCTAssertEqual(state.streak, 0, "not study: the day is left as it was")
        XCTAssertNil(state.dailyProgressDate)
    }
}
