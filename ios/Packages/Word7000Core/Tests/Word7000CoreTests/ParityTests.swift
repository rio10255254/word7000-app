import Foundation
import XCTest
@testable import Word7000Core

/// Replays golden results computed by the React Native app's TypeScript
/// engine (src/nativeParity.test.ts), so both apps make the same decisions.
final class ParityTests: XCTestCase {
    struct Step: Decodable { let op: String; let wordId: String; let today: String; let at: String }
    struct Option: Decodable, Equatable { let meaning: String; let correct: Bool }
    struct QuizCase: Decodable { let wordId: String; let meaning: [Option]; let word: [Option] }
    struct LibraryCase: Decodable {
        let query: String
        let filter: LibraryFilter
        let level: String?
        let initial: String?
        let sort: LibrarySort?
        let ids: [String]
    }
    struct Line: Decodable { let height: Double; let text: String; let width: Double; let x: Double; let y: Double }
    struct Candidate: Decodable, Equatable { let key: String; let meaningZh: String; let partOfSpeech: String; let word: String }
    struct ScanCase: Decodable { let lines: [Line]; let result: [Candidate] }
    struct Stats: Decodable { let due, mastered, review, favorites, remaining, studiedToday: Int }
    struct StreakCase: Decodable {
        let name: String
        let source, incoming, merged, normalized, studied: ProgressState
        let today: String
    }
    struct Session: Decodable { let cardIds: [String]; let index: Int; let initialCount: Int; let knownIds: [String]; let reviewIds: [String]; let requeued: [String: Int] }

    struct Fixtures: Decodable {
        let steps: [Step]
        let history: [ProgressState]
        let otherDevice: ProgressState
        let merged: ProgressState
        let streakCases: [StreakCase]
        let normalized: ProgressState
        let stats: Stats
        let statsLater: Stats
        let studySession: [String]
        let quizSessionSmall: [String]
        let quizSessionLarge: [String]
        let quizOptions: [QuizCase]
        let studyQueue: [String]
        let libraryState: ProgressState
        let library: [LibraryCase]
        let scans: [ScanCase]
        let sessionGrades: [[String]]
        let session: Session
        let idCount: Int
    }

    static let repoRoot: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { url.deleteLastPathComponent() }
        return url
    }()

    static let fixtures: Fixtures = {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("parity.json")
        return try! JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url))
    }()

    static let words: [WordEntry] = {
        let url = repoRoot.appendingPathComponent("ios/Word7000/Resources/words.json")
        return try! WordData.decode(Data(contentsOf: url))
    }()

    var f: Fixtures { Self.fixtures }
    var words: [WordEntry] { Self.words }

    func testWordListMatches() {
        XCTAssertEqual(words.count, f.idCount)
    }

    func testGradingHistory() {
        var state = ProgressState(dailyTarget: 20, streak: 0, studiedToday: 0, words: [:])
        for (index, step) in f.steps.enumerated() {
            switch step.op {
            case "known": state = LearningEngine.markKnown(state, wordId: step.wordId, today: step.today, changedAt: step.at)
            case "review": state = LearningEngine.markReview(state, wordId: step.wordId, today: step.today, changedAt: step.at)
            case "quiz": state = LearningEngine.markQuizCorrect(state, wordId: step.wordId, today: step.today, changedAt: step.at)
            default: state = LearningEngine.toggleFavorite(state, wordId: step.wordId, changedAt: step.at)
            }
            XCTAssertEqual(state, f.history[index], "step \(index) \(step.op) \(step.wordId)")
        }
        XCTAssertEqual(LearningEngine.normalizeForDate(state, today: "2026-06-09"), f.normalized)
        XCTAssertEqual(LearningEngine.merge([state, f.otherDevice]), f.merged)
    }

    func testStats() {
        let stats = LearningEngine.stats(words: words, state: f.libraryState, today: "2026-06-06")
        XCTAssertEqual([stats.due, stats.mastered, stats.review, stats.favorites, stats.remaining, stats.studiedToday],
                       [f.stats.due, f.stats.mastered, f.stats.review, f.stats.favorites, f.stats.remaining, f.stats.studiedToday])
        let later = LearningEngine.stats(words: words, state: f.libraryState, today: "2026-06-20")
        XCTAssertEqual(later.due, f.statsLater.due)
    }

    func testStreakProtectionMatchesSharedClient() {
        for item in f.streakCases {
            XCTAssertEqual(LearningEngine.merge([item.source, item.incoming]), item.merged, item.name)
            XCTAssertEqual(LearningEngine.merge([item.incoming, item.source]), item.merged, item.name)
            XCTAssertEqual(LearningEngine.normalizeForDate(item.source, today: item.today), item.normalized, item.name)
            XCTAssertEqual(LearningEngine.markKnown(item.source, wordId: "streak-word", today: item.today,
                                                   changedAt: "\(item.today)T08:00:00.000Z"), item.studied, item.name)
        }
    }

    func testPreparedStatsAndQueueCountsMatchTheFullQueue() {
        let vocabulary = PreparedVocabulary(words)
        for today in ["2026-06-06", "2026-06-20"] {
            XCTAssertEqual(LearningEngine.stats(vocabulary: vocabulary, state: f.libraryState, today: today),
                           LearningEngine.stats(words: words, state: f.libraryState, today: today))
        }
        let states = [f.libraryState, f.history.last!, ProgressState.empty]
        for state in states {
            for today in ["2026-06-06", "2026-06-20"] {
                for limit in [0, 1, 5, 12, 40, 200] {
                    for list in [Array(words.prefix(40)), words] {
                        let queue = LearningEngine.buildStudyQueue(words: list, state: state, today: today, limit: limit, seed: "counts")
                        let fresh = queue.filter { state.progress(for: $0.id).status == .new }.count
                        let counts = LearningEngine.studyQueueCounts(words: list, state: state, today: today, limit: limit)
                        XCTAssertEqual([counts.fresh, counts.review, counts.total], [fresh, queue.count - fresh, queue.count],
                                       "\(today) limit \(limit)")
                    }
                }
            }
        }
    }

    func testSeededOrders() {
        XCTAssertEqual(SeededRandom.shuffle(Array(words.prefix(30)), seed: "seed-1").map(\.id), f.studySession)
        XCTAssertEqual(QuizBuilder.session(words: Array(words.prefix(30)), count: 20, seed: "seed-2").map(\.id), f.quizSessionSmall)
        XCTAssertEqual(QuizBuilder.session(words: words, count: 20, seed: "seed-3").map(\.id), f.quizSessionLarge)
        let queue = LearningEngine.buildStudyQueue(words: Array(words.prefix(40)), state: f.history.last!, today: "2026-06-06", limit: 12, seed: "seed-5")
        XCTAssertEqual(queue.map(\.id), f.studyQueue)
    }

    func testQuizOptions() {
        let vocabulary = PreparedVocabulary(words)
        for quiz in f.quizOptions {
            let meaning = QuizBuilder.options(vocabulary: vocabulary, wordId: quiz.wordId, seed: "seed-4", mode: .meaning)
            XCTAssertEqual(meaning.map { Option(meaning: $0.text, correct: $0.correct) }, quiz.meaning, quiz.wordId)
            let word = QuizBuilder.options(vocabulary: vocabulary, wordId: quiz.wordId, seed: "seed-4", mode: .word)
            XCTAssertEqual(word.map { Option(meaning: $0.text, correct: $0.correct) }, quiz.word, quiz.wordId)
        }
    }

    func testLibraryFiltering() {
        let vocabulary = PreparedVocabulary(words)
        for query in f.library {
            let ids = vocabulary.filter(
                state: f.libraryState,
                query: query.query,
                filter: query.filter,
                options: LibraryFilterOptions(initial: query.initial, level: query.level, sort: query.sort ?? .default)
            ).prefix(25).map(\.id)
            XCTAssertEqual(Array(ids), query.ids, "\(query.query) \(query.filter) \(query.sort?.rawValue ?? "")")
        }
    }

    func testScanParser() {
        for scan in f.scans {
            let lines = scan.lines.map { ScannedLine(text: $0.text, x: $0.x, y: $0.y, width: $0.width, height: $0.height) }
            let result = ScanParser.parse(lines).map { Candidate(key: $0.key, meaningZh: $0.meaningZh, partOfSpeech: $0.partOfSpeech, word: $0.word) }
            XCTAssertEqual(result, scan.result, scan.lines.map(\.text).joined(separator: " | "))
        }
    }

    func testStudySession() {
        var session = StudySession(cardIds: ["a", "b", "c", "d", "e", "f", "g"], sourceKey: "k")
        for grade in f.sessionGrades {
            session = session.grading(grade[0], as: StudyGrade(rawValue: grade[1])!)
        }
        XCTAssertEqual(session.cardIds, f.session.cardIds)
        XCTAssertEqual(session.index, f.session.index)
        XCTAssertEqual(session.knownIds, f.session.knownIds)
        XCTAssertEqual(session.reviewIds, f.session.reviewIds)
        XCTAssertEqual(session.requeued, f.session.requeued)
    }

    func testPlainTextLines() {
        let lines = ScanParser.lines(fromPlainText: "abandon v. 放棄\n\nbenefit\n好處\nThe benefit is clear.\n")
        XCTAssertEqual(ScanParser.parse(lines).map(\.word), ["abandon", "benefit"])
    }
}
