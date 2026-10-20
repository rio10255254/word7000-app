import XCTest
@testable import Word7000Core

final class SpeakingPracticeTests: XCTestCase {
    func testEveryReviewedQuestionHasARealPairedAnswer() {
        XCTAssertEqual(SpeakingPractice.entries.count, 600)
        XCTAssertEqual(Set(SpeakingPractice.entries.map(\.id)).count, 600)
        XCTAssertEqual(Set(SpeakingPractice.entries.map(\.question)).count, 600)
        for entry in SpeakingPractice.entries {
            XCTAssertFalse(entry.question.isEmpty, entry.word)
            XCTAssertNil(entry.question.range(of: "\\p{Han}", options: .regularExpression), entry.word)
            XCTAssertTrue(entry.answerEn.lowercased().components(separatedBy: CharacterSet.letters.inverted).contains(entry.word.lowercased()), entry.word)
            for part in entry.keywordZh.components(separatedBy: "…") {
                XCTAssertTrue(entry.answerZh.contains(part), entry.word)
            }
            XCTAssertFalse(entry.answerEn.contains("I would add one personal reason"))
            XCTAssertFalse(entry.answerZh.contains("我會再補上一個"))
        }
    }

    func testEveryExpandedWordHasPairedCardsInBothLanguages() throws {
        let byWord = Dictionary(uniqueKeysWithValues: ParityTests.words.map { ($0.word, $0) })
        for entry in SpeakingPractice.entries {
            let word = try XCTUnwrap(byWord[entry.word], entry.word)
            let english = try XCTUnwrap(SpeakingPractice.card(for: word, mode: .english), entry.word)
            let chinese = try XCTUnwrap(SpeakingPractice.card(for: word, mode: .chinese), entry.word)
            XCTAssertEqual(english.question, entry.question)
            XCTAssertEqual(chinese.question, entry.question)
            XCTAssertEqual(english.referenceAnswer, entry.answerEn)
            XCTAssertEqual(chinese.referenceAnswer, entry.answerZh)
            XCTAssertEqual(chinese.referenceTranslation, english.referenceAnswer)
            XCTAssertEqual(english.referenceTranslation, chinese.referenceAnswer)
            XCTAssertEqual(chinese.keyword, entry.keywordZh)
            XCTAssertNotEqual(english.referenceAnswer, word.example, entry.word)
        }
    }

    func testExpandedQuestionsSurviveLevelFiltersAndRandomSessions() {
        let candidates = SpeakingPractice.candidates(from: ParityTests.words, activity: .questions)
        XCTAssertEqual(candidates.count, 600)
        XCTAssertEqual(Set(candidates.map(\.group)).count, 14)
        for group in Set(ParityTests.words.map(\.group)) {
            let scoped = candidates.filter { $0.group == group }
            XCTAssertFalse(scoped.isEmpty, group)
            let session = QuizBuilder.session(words: scoped, count: 10, seed: "speaking-expanded-" + group)
            XCTAssertEqual(session.count, min(10, scoped.count))
            XCTAssertEqual(Set(session.map(\.id)).count, session.count)
            XCTAssertTrue(session.allSatisfy { SpeakingPractice.entry(for: $0) != nil })
        }
        let first = QuizBuilder.session(words: candidates, count: 10, seed: "speaking-expanded-first")
        let second = QuizBuilder.session(words: candidates, count: 10, seed: "speaking-expanded-second")
        XCTAssertNotEqual(first.map(\.id), second.map(\.id))
        XCTAssertTrue((first + second).contains { (Int($0.id.dropFirst()) ?? 0) > 100 })
    }

    func testAboutQuestionAndBothLanguagesUseReviewedAnswers() throws {
        let word = try XCTUnwrap(ParityTests.words.first { $0.word == "about" })
        let english = try XCTUnwrap(SpeakingPractice.card(for: word, mode: .english))
        let chinese = try XCTUnwrap(SpeakingPractice.card(for: word, mode: .chinese))
        XCTAssertEqual(english.question, "What is a topic you can talk about for a long time?")
        XCTAssertEqual(chinese.referenceAnswer, english.referenceTranslation)
        XCTAssertEqual(chinese.referenceTranslation, english.referenceAnswer)
        XCTAssertEqual(chinese.keyword, "關於")
        XCTAssertNotEqual(english.referenceAnswer, word.example)
    }

    func testCustomMeaningDoesNotBorrowAnUnrelatedQuestion() throws {
        var word = try XCTUnwrap(ParityTests.words.first { $0.word == "about" })
        word.id = "scan-about-local"
        word.meaningZh = "大約"
        XCTAssertNil(SpeakingPractice.card(for: word, mode: .chinese))
    }

    func testQuestionsNeverSilentlyTurnIntoAnExampleExercise() throws {
        var custom = try XCTUnwrap(ParityTests.words.first { $0.word == "about" })
        custom.id = "scan-about-local"
        custom.meaningZh = "大約"
        XCTAssertTrue(SpeakingPractice.candidates(from: [custom], activity: .questions).isEmpty)
        XCTAssertEqual(SpeakingPractice.candidates(from: [custom], activity: .examples), [custom])
        XCTAssertFalse(SpeakingPractice.candidates(from: ParityTests.words, activity: .questions).isEmpty)
    }

    func testBothPracticeChoicesSurviveSaving() throws {
        for activity in SpeakingPractice.Activity.allCases {
            let data = try JSONEncoder().encode(activity)
            XCTAssertEqual(try JSONDecoder().decode(SpeakingPractice.Activity.self, from: data), activity)
        }
    }

    func testSpeakingProtectsStreakWithoutInflatingWordGoal() {
        let first = LearningEngine.recordPracticeDay(.empty, today: "2026-10-18")
        let next = LearningEngine.recordPracticeDay(first, today: "2026-10-19")
        XCTAssertEqual(next.streak, 2)
        XCTAssertEqual(next.studiedToday, 0)
        XCTAssertEqual(LearningEngine.recordPracticeDay(next, today: "2026-10-19").streak, 2)
    }

    func testChinesePronunciationKeepsTonesAndSeparators() {
        #if canImport(Darwin) || os(Linux)
        XCTAssertEqual(ChineseDisplay.pronunciationWithTones("我的；你好"), "wǒ de；nǐ hǎo")
        XCTAssertEqual(ChineseDisplay.pronunciationWithTones("調整"), "tiáo zhěng")
        XCTAssertEqual(ChineseDisplay.pronunciationWithTones("為了；因為；為什麼"), "wèi le；yīn wèi；wèi shén me")
        #endif
    }

    func testSessionsPreferQuestionsNotPractisedRecently() {
        let candidates = SpeakingPractice.candidates(from: ParityTests.words, activity: .questions)
        var recent: [String] = []
        var asked = Set<String>()
        for round in 0..<60 {
            let session = SpeakingPractice.session(from: candidates, recent: recent, count: 10, seed: "round-\(round)")
            XCTAssertEqual(session.count, 10)
            XCTAssertEqual(Set(session.map(\.id)).count, 10)
            XCTAssertTrue(asked.isDisjoint(with: session.map(\.id)), "round \(round) repeated a question")
            for word in session {
                asked.insert(word.id)
                recent = SpeakingPractice.remembering(word.id, in: recent)
            }
            // Nothing within the remembered window comes back.
            if asked.count >= SpeakingPractice.recentLimit { asked = Set(recent) }
        }
        XCTAssertEqual(recent.count, SpeakingPractice.recentLimit)
    }

    func testSmallScopesRefillWithTheLongestAgoPractisedWords() {
        let words = Array(ParityTests.words.prefix(12))
        let recent = words.prefix(10).map(\.id)
        let session = SpeakingPractice.session(from: words, recent: recent, count: 5, seed: "small")
        XCTAssertEqual(Set(session.map(\.id)), Set([words[10].id, words[11].id, words[0].id, words[1].id, words[2].id]))
        XCTAssertEqual(SpeakingPractice.session(from: Array(words.prefix(3)), recent: recent, count: 10, seed: "tiny").count, 3)
        XCTAssertEqual(SpeakingPractice.remembering(words[0].id, in: recent).last, words[0].id)
        XCTAssertEqual(SpeakingPractice.remembering(words[0].id, in: recent).count, 10)
    }

    func testSpeechPreferencesSavedBeforeAutoSpeakStillDecode() throws {
        let old = #"{"speed":"slow","englishVoiceID":"voice"}"#
        let decoded = try JSONDecoder().decode(SpeechPreferences.self, from: Data(old.utf8))
        XCTAssertEqual(decoded, SpeechPreferences(englishVoiceID: "voice", speed: .slow))
        XCTAssertNil(decoded.autoSpeak)
    }
}
