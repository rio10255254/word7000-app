import XCTest
@testable import Word7000Core

final class HomeWidgetTests: XCTestCase {
    let words = Array(ParityTests.words.prefix(50))

    func testSnapshotCarriesTodayAndTurnsOverAtMidnight() {
        let progress = ProgressState(dailyTarget: 20, streak: 3, studiedToday: 8, dailyProgressDate: "2026-10-20", lastStudyDate: "2026-10-20")
        let snapshot = HomeWidgetSnapshot.make(progress: progress, today: "2026-10-20", chineseInterface: true, words: words)
        XCTAssertEqual(snapshot.words.count, HomeWidgetSnapshot.daysAhead)

        let today = snapshot.display(on: "2026-10-20")
        XCTAssertEqual([today.studied, today.target, today.streak], [8, 20, 3])
        XCTAssertTrue(today.studiedToday)
        XCTAssertEqual(today.fraction, 0.4, accuracy: 0.001)
        XCTAssertNotNil(today.word)

        let tomorrow = snapshot.display(on: "2026-10-21")
        XCTAssertEqual([tomorrow.studied, tomorrow.streak], [0, 3])
        XCTAssertFalse(tomorrow.studiedToday)
        XCTAssertNotNil(tomorrow.word)
        // Protection covers the 21st, so the streak survives the 22nd too.
        XCTAssertEqual(snapshot.display(on: "2026-10-22").streak, 3)
        XCTAssertEqual(snapshot.display(on: "2026-10-23").streak, 0)
        XCTAssertNotNil(snapshot.display(on: "2026-10-23").word)
    }

    func testWordOfTheDayStaysPutAndSkipsMasteredWords() {
        var progress = ProgressState()
        for word in words.dropLast() {
            progress.words[word.id] = WordProgress(status: .mastered)
        }
        let first = HomeWidgetSnapshot.make(progress: .empty, today: "2026-10-20", chineseInterface: false, words: words)
        let again = HomeWidgetSnapshot.make(progress: progress, today: "2026-10-20", chineseInterface: false, words: words, previous: first)
        XCTAssertEqual(again.words["2026-10-20"], first.words["2026-10-20"])
        let fresh = HomeWidgetSnapshot.make(progress: progress, today: "2026-10-20", chineseInterface: false, words: words)
        XCTAssertEqual(fresh.words["2026-10-20"]?.word, words.last?.word)
    }

    func testOfflineRotationSurvivesYearsAndSerialization() throws {
        let snapshot = HomeWidgetSnapshot.make(progress: .empty, today: "2026-10-20", chineseInterface: true,
                                               words: fixtureWords(200))
        let restored = try JSONDecoder().decode(HomeWidgetSnapshot.self, from: JSONEncoder().encode(snapshot))
        XCTAssertEqual(restored, snapshot)
        let pool = try XCTUnwrap(snapshot.fallbackWords)
        var seen = Set<String>()
        // Includes day four, year boundaries and leap day, with no app refresh.
        for offset in 3..<3_660 {
            let day = try XCTUnwrap(DayMath.addDays(snapshot.date, offset))
            let display = snapshot.display(on: day)
            let word = try XCTUnwrap(display.word, day)
            XCTAssertTrue(pool.contains(word), day)
            XCTAssertEqual(restored.display(on: day), display, day)
            XCTAssertEqual(snapshot.display(on: day), display, day)
            XCTAssertEqual(display.studied, 0)
            seen.insert(word.word)
        }
        XCTAssertGreaterThan(seen.count, HomeWidgetSnapshot.daysAhead)
        XCTAssertNotNil(restored.display(on: "2100-01-01").word)
        XCTAssertEqual(snapshot.words.count, HomeWidgetSnapshot.daysAhead)
        XCTAssertEqual(snapshot.fallbackWords?.count, HomeWidgetSnapshot.fallbackWordLimit)
    }

    func testFallbackSelectionUsesStableDateHash() {
        let snapshot = HomeWidgetSnapshot.make(progress: .empty, today: "2026-10-20", chineseInterface: true,
                                               words: fixtureWords(4))
        // Known results also catch accidental use of Swift's randomized Hasher.
        XCTAssertEqual(snapshot.display(on: "2026-10-23").word?.word, "word-2")
        XCTAssertEqual(snapshot.display(on: "2026-10-24").word?.word, "word-3")
        XCTAssertEqual(snapshot.display(on: "2028-02-29").word?.word, "word-3")
        XCTAssertEqual(snapshot.display(on: "2100-01-01").word?.word, "word-3")
    }

    func testFallbackPoolIsBoundedAndUsesLibraryOrder() throws {
        let library = fixtureWords(7_000)
        let snapshot = HomeWidgetSnapshot.make(progress: .empty, today: "2026-10-20", chineseInterface: true, words: library)
        let pool = try XCTUnwrap(snapshot.fallbackWords)
        XCTAssertEqual(pool.count, HomeWidgetSnapshot.fallbackWordLimit)
        XCTAssertEqual(pool.map(\.word), Array(library.prefix(HomeWidgetSnapshot.fallbackWordLimit)).map(\.word))
        let repeated = HomeWidgetSnapshot.make(progress: .empty, today: snapshot.date, chineseInterface: true, words: library)
        XCTAssertEqual(repeated, snapshot)

        let manual = HomeWidgetSnapshot(date: snapshot.date, studiedToday: 0, dailyTarget: 20, streak: 0,
                                        lastStudyDate: nil, streakFreezeDate: nil, chineseInterface: true, words: [:],
                                        fallbackWords: Array(repeating: pool[0], count: 1_000))
        XCTAssertEqual(manual.fallbackWords?.count, HomeWidgetSnapshot.fallbackWordLimit)
    }

    func testFallbackSkipsMasteredWordsAndUsesAllWhenEverythingIsMastered() {
        let library = fixtureWords(200)
        var progress = ProgressState()
        for entry in library.dropLast() { progress.words[entry.id] = WordProgress(status: .mastered) }
        let snapshot = HomeWidgetSnapshot.make(progress: progress, today: "2026-10-20", chineseInterface: true, words: library)
        XCTAssertEqual(snapshot.fallbackWords?.map(\.word), [library.last!.word])
        XCTAssertEqual(snapshot.display(on: "2036-10-20").word?.word, library.last?.word)

        progress.words[library.last!.id] = WordProgress(status: .mastered)
        let allMastered = HomeWidgetSnapshot.make(progress: progress, today: "2026-10-20", chineseInterface: true, words: library)
        XCTAssertEqual(allMastered.fallbackWords?.count, HomeWidgetSnapshot.fallbackWordLimit)
        XCTAssertNotNil(allMastered.display(on: "2036-10-20").word)
    }

    func testProgressAndModeChangesReusePoolUntilNextDay() {
        let library = fixtureWords(200)
        let first = HomeWidgetSnapshot.make(progress: .empty, today: "2026-10-20", chineseInterface: true, words: library)
        var progress = ProgressState(dailyTarget: 30, streak: 1, studiedToday: 15,
                                     dailyProgressDate: first.date, lastStudyDate: first.date)
        for entry in library.dropLast() { progress.words[entry.id] = WordProgress(status: .mastered) }
        let sameDay = HomeWidgetSnapshot.make(progress: progress, today: first.date, chineseInterface: false,
                                              words: library, previous: first)
        XCTAssertEqual(sameDay.fallbackWords, first.fallbackWords)
        XCTAssertEqual(sameDay.words, first.words)
        XCTAssertFalse(sameDay.chineseInterface)
        XCTAssertEqual(sameDay.display(on: first.date).studied, 15)
        XCTAssertEqual(sameDay.display(on: first.date).target, 30)

        let nextDay = HomeWidgetSnapshot.make(progress: progress, today: "2026-10-21", chineseInterface: false,
                                              words: library, previous: sameDay)
        XCTAssertEqual(nextDay.fallbackWords?.map(\.word), [library.last!.word])
        // Already scheduled days stay pinned; newly scheduled days use progress.
        XCTAssertEqual(nextDay.words["2026-10-21"], first.words["2026-10-21"])
        XCTAssertEqual(nextDay.words["2026-10-22"], first.words["2026-10-22"])
        XCTAssertEqual(nextDay.words["2026-10-23"]?.word, library.last?.word)
        XCTAssertEqual(nextDay.display(on: "2036-10-20").word?.word, library.last?.word)
    }

    func testReopeningAfterLongAbsencePinsTodaysOfflineWord() throws {
        let library = fixtureWords(200)
        let old = HomeWidgetSnapshot.make(progress: .empty, today: "2026-10-20", chineseInterface: true, words: library)
        let today = "2028-02-29"
        let displayed = try XCTUnwrap(old.display(on: today).word)
        var progress = ProgressState()
        let survivor = try XCTUnwrap(library.last)
        XCTAssertNotEqual(displayed.word, survivor.word)
        for entry in library.dropLast() { progress.words[entry.id] = WordProgress(status: .mastered) }
        let refreshed = HomeWidgetSnapshot.make(progress: progress, today: today, chineseInterface: false,
                                                words: library, previous: old)
        XCTAssertEqual(refreshed.words[today], displayed)
        XCTAssertEqual(refreshed.display(on: today).word, displayed)
        XCTAssertEqual(refreshed.fallbackWords?.map(\.word), [survivor.word])
        XCTAssertEqual(refreshed.display(on: "2028-03-01").word?.word, survivor.word)
        XCTAssertEqual(refreshed.display(on: "2036-10-20").word?.word, survivor.word)
        let again = HomeWidgetSnapshot.make(progress: .empty, today: today, chineseInterface: true,
                                            words: library, previous: refreshed)
        XCTAssertEqual(again.display(on: today).word, displayed)
        XCTAssertEqual(again.fallbackWords, refreshed.fallbackWords)
    }

    func testEmptyAndSingleWordLibraries() {
        let empty = HomeWidgetSnapshot.make(progress: .empty, today: "2026-10-20", chineseInterface: false, words: [])
        XCTAssertTrue(empty.words.isEmpty)
        XCTAssertEqual(empty.fallbackWords, [])
        XCTAssertNil(empty.display(on: empty.date).word)
        XCTAssertNil(empty.display(on: "2100-01-01").word)

        let single = HomeWidgetSnapshot.make(progress: .empty, today: empty.date, chineseInterface: false,
                                             words: fixtureWords(1), previous: empty)
        XCTAssertEqual(single.fallbackWords?.count, 1)
        XCTAssertEqual(single.display(on: "2100-01-01").word, single.words[single.date])
    }

    func testEmptyLibraryDoesNotDiscardPreviousOfflinePool() {
        let old = HomeWidgetSnapshot.make(progress: .empty, today: "2026-10-20", chineseInterface: true, words: fixtureWords(10))
        let refreshed = HomeWidgetSnapshot.make(progress: .empty, today: "2028-02-29", chineseInterface: true,
                                                words: [], previous: old)
        XCTAssertEqual(refreshed.fallbackWords, old.fallbackWords)
        for day in [refreshed.date, "2028-03-01", "2100-01-01"] {
            XCTAssertNotNil(refreshed.display(on: day).word)
            XCTAssertEqual(refreshed.display(on: day).word, old.display(on: day).word)
        }
    }

    func testChineseModeKeepsBothSidesOfOfflineWord() throws {
        var entry = fixtureWords(1)[0]
        entry.word = "learn"
        entry.pronunciation = "/learn/"
        entry.meaningZh = "\u{5B78}\u{7FD2}; \u{5B78}\u{6703}; extra sense"
        let expected = HomeWidgetSnapshot.Word(word: "learn", pronunciation: "/learn/",
                                               meaning: "\u{5B78}\u{7FD2}\u{FF1B}\u{5B78}\u{6703}", partOfSpeech: entry.partOfSpeech)
        for chineseInterface in [true, false] {
            let snapshot = HomeWidgetSnapshot.make(progress: .empty, today: "2026-10-20",
                                                   chineseInterface: chineseInterface, words: [entry])
            let restored = try JSONDecoder().decode(HomeWidgetSnapshot.self, from: JSONEncoder().encode(snapshot))
            XCTAssertEqual(restored.chineseInterface, chineseInterface)
            var shown = expected
            // Learners of Chinese also see the meaning's pinyin.
            if !chineseInterface { shown.pinyin = "xué xí；xué huì" }
            XCTAssertEqual(restored.display(on: "2036-10-20").word, shown)
        }
    }

    func testLegacySnapshotDecodesAndRotatesWithoutNewField() throws {
        let old = try JSONDecoder().decode(HomeWidgetSnapshot.self, from: legacyJSON)
        XCTAssertNil(old.fallbackWords)
        XCTAssertFalse(old.chineseInterface)
        XCTAssertNil(old.lastStudyDate)
        XCTAssertNil(old.streakFreezeDate)
        XCTAssertEqual(old.display(on: "2026-10-20").word?.word, "alpha")
        XCTAssertEqual(old.display(on: "2026-10-21").word?.word, "beta")
        // Sorted date keys give [alpha, beta] regardless of JSON key order.
        XCTAssertEqual(old.display(on: "2026-10-23").word?.word, "alpha")
        XCTAssertEqual(old.display(on: "2026-10-24").word?.word, "beta")
        let restored = try JSONDecoder().decode(HomeWidgetSnapshot.self, from: JSONEncoder().encode(old))
        XCTAssertEqual(restored, old)
        XCTAssertEqual(restored.display(on: "2100-01-01").word, old.display(on: "2100-01-01").word)

        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: legacyJSON) as? [String: Any])
        let missingPools: [Any] = [NSNull(), [Any]()]
        for missingPool in missingPools {
            object["fallbackWords"] = missingPool
            let snapshot = try JSONDecoder().decode(HomeWidgetSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
            XCTAssertEqual(snapshot.display(on: "2026-10-24").word, old.display(on: "2026-10-24").word)
        }
    }

    func testLegacyRefreshPinsOfflineWordAndBoundsSchedule() throws {
        let old = try JSONDecoder().decode(HomeWidgetSnapshot.self, from: legacyJSON)
        let today = "2028-02-29"
        let refreshed = HomeWidgetSnapshot.make(progress: .empty, today: today, chineseInterface: false,
                                                words: fixtureWords(200), previous: old)
        XCTAssertEqual(refreshed.display(on: today).word, old.display(on: today).word)
        XCTAssertEqual(refreshed.words.count, HomeWidgetSnapshot.daysAhead)
        XCTAssertEqual(refreshed.fallbackWords?.count, HomeWidgetSnapshot.fallbackWordLimit)

        let withoutLibrary = HomeWidgetSnapshot.make(progress: .empty, today: today, chineseInterface: false,
                                                     words: [], previous: old)
        XCTAssertEqual(withoutLibrary.fallbackWords?.map(\.word), ["alpha", "beta"])
        XCTAssertEqual(withoutLibrary.display(on: "2100-01-01").word, old.display(on: "2100-01-01").word)
    }

    func testScheduledWordOverridesFallbackAndRepeatedRefreshesStayBounded() throws {
        var snapshot = HomeWidgetSnapshot.make(progress: .empty, today: "2026-10-20", chineseInterface: true, words: fixtureWords(200))
        let pinned = HomeWidgetSnapshot.Word(word: "pinned", pronunciation: "", meaning: "pinned meaning", partOfSpeech: "n")
        snapshot.words["2026-10-23"] = pinned
        XCTAssertEqual(snapshot.display(on: "2026-10-23").word, pinned)
        for offset in 1...100 {
            let day = try XCTUnwrap(DayMath.addDays("2026-10-20", offset))
            snapshot = HomeWidgetSnapshot.make(progress: .empty, today: day, chineseInterface: true,
                                                words: fixtureWords(200), previous: snapshot)
            XCTAssertEqual(snapshot.words.count, HomeWidgetSnapshot.daysAhead)
            XCTAssertEqual(snapshot.fallbackWords?.count, HomeWidgetSnapshot.fallbackWordLimit)
        }
    }

    func testSameDayRefreshPerformance() {
        let library = fixtureWords(7_000)
        let snapshot = HomeWidgetSnapshot.make(progress: .empty, today: "2026-10-20", chineseInterface: true, words: library)
        measure {
            for _ in 0..<100 {
                let refreshed = HomeWidgetSnapshot.make(progress: .empty, today: snapshot.date, chineseInterface: true,
                                                        words: library, previous: snapshot)
                XCTAssertEqual(refreshed.fallbackWords?.count, HomeWidgetSnapshot.fallbackWordLimit)
            }
        }
    }

    private func fixtureWords(_ count: Int) -> [WordEntry] {
        (0..<count).map { index in
            WordEntry(id: "id-\(index)", word: "word-\(index)", partOfSpeech: "n", pronunciation: "/word-\(index)/",
                      meaningZh: "meaning-\(index)", example: "", exampleZh: "", group: "Core 1")
        }
    }

    private var legacyJSON: Data {
        Data(#"""
        {"date":"2026-10-20","studiedToday":0,"dailyTarget":20,"streak":0,"chineseInterface":false,
         "words":{"2026-10-21":{"word":"beta","pronunciation":"/b/","meaning":"second","partOfSpeech":"n"},
                  "2026-10-20":{"word":"alpha","pronunciation":"/a/","meaning":"first","partOfSpeech":"n"}}}
        """#.utf8)
    }

    func testStoreOnlyWritesChanges() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HomeWidgetStore(directory: directory)
        let snapshot = HomeWidgetSnapshot.make(progress: .empty, today: "2026-10-20", chineseInterface: true, words: words)
        XCTAssertNil(store.load())
        XCTAssertTrue(store.save(snapshot))
        XCTAssertFalse(store.save(snapshot))
        XCTAssertEqual(store.load(), snapshot)
        XCTAssertEqual(store.load()?.display(on: "2100-01-01"), snapshot.display(on: "2100-01-01"))
        XCTAssertNil(HomeWidgetStore(directory: nil).load())
    }

    func testStoreLoadsLegacySnapshotAndOnlyWritesUpgradeOnce() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try legacyJSON.write(to: directory.appendingPathComponent(HomeWidgetStore.fileName))
        let store = HomeWidgetStore(directory: directory)
        let old = try XCTUnwrap(store.load())
        XCTAssertNotNil(old.display(on: "2100-01-01").word)
        let upgraded = HomeWidgetSnapshot.make(progress: .empty, today: "2028-02-29", chineseInterface: false,
                                               words: fixtureWords(200), previous: old)
        XCTAssertTrue(store.save(upgraded))
        XCTAssertEqual(store.load(), upgraded)
        XCTAssertFalse(store.save(upgraded))
    }
}
