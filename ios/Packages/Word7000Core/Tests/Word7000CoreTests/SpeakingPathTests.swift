import XCTest
@testable import Word7000Core

final class ShadowingCheckTests: XCTestCase {
    func testEnglishMarksWhatWasHeardAndMissed() {
        let check = ShadowingCheck(target: "I had to adapt when I entered a new school.",
                                   heard: "I had to adapt when I enter a new school", chinese: false)
        XCTAssertEqual(check.units.map(\.text).last, "school.")
        XCTAssertEqual(check.units.first { $0.text == "entered" }?.mark, .missed)
        XCTAssertEqual(check.units.first { $0.text == "adapt" }?.mark, .heard)
        XCTAssertEqual(check.heardCount, 9)
        XCTAssertEqual(check.score, 0.9, accuracy: 0.001)
        XCTAssertTrue(check.passed)
    }

    func testEnglishIgnoresCaseAndPunctuationAndExtraWords() {
        let check = ShadowingCheck(target: "Don't worry, it's fine!", heard: "um don't worry it's fine okay", chinese: false)
        XCTAssertEqual(check.score, 1)
        XCTAssertTrue(check.units.allSatisfy { $0.mark == .heard })
    }

    func testNothingHeardFailsWithEveryWordMissed() {
        let check = ShadowingCheck(target: "I like tea.", heard: "", chinese: false)
        XCTAssertEqual(check.score, 0)
        XCTAssertFalse(check.passed)
        XCTAssertTrue(check.units.allSatisfy { $0.mark == .missed })
    }

    func testBeforeSpeakingThereAreNoMarks() {
        let check = ShadowingCheck(target: "我喜歡喝茶。", chinese: true)
        XCTAssertEqual(check.units.map(\.text), ["我", "喜", "歡", "喝", "茶", "。"])
        XCTAssertTrue(check.units.allSatisfy { $0.mark == nil })
        XCTAssertEqual(check.units.filter(\.scored).count, 5)
        XCTAssertEqual(check.units[4].pinyin, "chá")
        XCTAssertTrue(check.units[5].pinyin.isEmpty)
    }

    func testChineseCountsHomophonesAsHeardAndToneSlipsAsHalf() throws {
        // 媽 (mā) for 馬 (mǎ) is the right syllable with another tone; 碼 (mǎ) sounds the same.
        let target = "我騎馬。"
        let tone = ShadowingCheck(target: target, heard: "我騎媽", chinese: true)
        let slip = try XCTUnwrap(tone.units.first { $0.text == "馬" })
        guard case .tone(let heard) = slip.mark else { return XCTFail("\(String(describing: slip.mark))") }
        XCTAssertEqual(ChineseDisplay.stripTones(heard), "ma")
        XCTAssertEqual(tone.toneCount, 1)
        XCTAssertEqual(tone.score, 2.5 / 3, accuracy: 0.001)

        let homophone = ShadowingCheck(target: target, heard: "我騎碼", chinese: true)
        XCTAssertEqual(homophone.score, 1)

        let missed = ShadowingCheck(target: target, heard: "我騎", chinese: true)
        XCTAssertEqual(missed.units.first { $0.text == "馬" }?.mark, .missed)
    }

    func testTheSentenceToSayIsTheFirstOfTheModelAnswer() {
        XCTAssertEqual(ShadowingCheck.sentence(from: "I agree. It was hard.", chinese: false), "I agree. It was hard.")
        XCTAssertEqual(ShadowingCheck.sentence(from: "I had to adapt when I moved. It was hard.", chinese: false),
                       "I had to adapt when I moved.")
        XCTAssertEqual(ShadowingCheck.sentence(from: "我進入新學校時必須適應。一開始很混亂。", chinese: true), "我進入新學校時必須適應。")
        XCTAssertEqual(ShadowingCheck.sentence(from: "好啊。我們走吧。", chinese: true), "好啊。我們走吧。")
        XCTAssertEqual(ShadowingCheck.sentence(from: "", chinese: true), "")
    }

    func testEveryReviewedAnswerGivesASentenceToSay() {
        for entry in SpeakingPractice.entries {
            XCTAssertFalse(ShadowingCheck.sentence(from: entry.answerEn, chinese: false).isEmpty, entry.word)
            let chinese = ShadowingCheck.sentence(from: entry.answerZh, chinese: true)
            XCTAssertFalse(chinese.isEmpty, entry.word)
            XCTAssertEqual(ShadowingCheck(target: chinese, heard: chinese, chinese: true).score, 1, entry.word)
        }
    }
}

final class SpeakingPathTests: XCTestCase {
    func testStarsForClearingSayingEveryModelAndAnsweringEveryQuestion() {
        XCTAssertEqual(SpeakingPath.Result(words: 5).stars, 0)
        XCTAssertFalse(SpeakingPath.Result(words: 5).cleared)
        XCTAssertEqual(SpeakingPath.Result(words: 5, shadowed: 1).stars, 1)
        XCTAssertEqual(SpeakingPath.Result(words: 5, shadowed: 5, answered: 2).stars, 2)
        XCTAssertEqual(SpeakingPath.Result(words: 5, shadowed: 3, answered: 5).stars, 2)
        XCTAssertEqual(SpeakingPath.Result(words: 5, shadowed: 5, answered: 5).stars, 3)
    }

    func testOneStageADayBuildsAStreak() {
        var path = SpeakingPath.Progress()
        XCTAssertEqual(path.nextStage, 1)
        path = path.clearing(stars: 2, today: "2026-11-04")
        XCTAssertEqual(path.nextStage, 2)
        XCTAssertTrue(path.clearedToday("2026-11-04"))
        XCTAssertEqual(path.currentStreak(today: "2026-11-04"), 1)
        // A second stage the same day moves along the path but not the streak.
        path = path.clearing(stars: 3, today: "2026-11-04")
        XCTAssertEqual(path.stars, [2, 3])
        XCTAssertEqual(path.currentStreak(today: "2026-11-04"), 1)
        XCTAssertEqual(path.currentStreak(today: "2026-11-05"), 1, "Kept until the day is over")
        path = path.clearing(stars: 1, today: "2026-11-05")
        XCTAssertEqual(path.currentStreak(today: "2026-11-05"), 2)
        XCTAssertEqual(path.currentStreak(today: "2026-11-07"), 0, "A missed day ends it")
        path = path.clearing(stars: 9, today: "2026-11-08")
        XCTAssertEqual(path.streak, 1)
        XCTAssertEqual(path.stars.last, 3)
    }

    func testProgressDecodesAndEncodes() throws {
        let path = SpeakingPath.Progress(stars: [1, 3], lastDay: "2026-11-04", streak: 4)
        let decoded = try JSONDecoder().decode(SpeakingPath.Progress.self, from: JSONEncoder().encode(path))
        XCTAssertEqual(decoded, path)
    }
}
