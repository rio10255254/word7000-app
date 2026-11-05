import XCTest
@testable import Word7000Core

final class ToneAnalysisTests: XCTestCase {
    /// A voice-like tone (a few harmonics) gliding through `pitches`.
    private func syllable(_ pitches: [Double], seconds: Double = 0.32, rate: Double = 16_000) -> [Float] {
        let count = Int(seconds * rate)
        var phase = 0.0
        return (0..<count).map { index in
            let t = Double(index) / Double(count - 1)
            let position = t * Double(pitches.count - 1)
            let lower = Int(position), upper = min(lower + 1, pitches.count - 1)
            let hz = pitches[lower] + (pitches[upper] - pitches[lower]) * (position - Double(lower))
            phase += 2 * .pi * hz / rate
            let value = sin(phase) + 0.5 * sin(2 * phase) + 0.25 * sin(3 * phase)
            return Float(0.3 * value)
        }
    }

    private func silence(_ seconds: Double = 0.08, rate: Double = 16_000) -> [Float] {
        Array(repeating: 0, count: Int(seconds * rate))
    }

    func testPitchIsTrackedAcrossAGlide() {
        let track = PitchTracker.track(samples: syllable([200, 200]), rate: 16_000)
        let voiced = track.compactMap(\.hz)
        XCTAssertGreaterThan(voiced.count, 15)
        for hz in voiced { XCTAssertEqual(hz, 200, accuracy: 6) }
        let falling = PitchTracker.track(samples: syllable([260, 150]), rate: 16_000).compactMap(\.hz)
        XCTAssertGreaterThan(falling.first ?? 0, falling.last ?? 0)
    }

    func testFourTonesInOnePhraseAreTellApart() {
        // 媽麻馬罵: high level, rising, low, falling, said by one voice.
        let parts: [[Double]] = [[235, 235], [175, 200, 240], [160, 145, 140, 148], [250, 215, 160]]
        var samples: [Float] = []
        var spans: [ClosedRange<Double>?] = []
        for part in parts {
            samples += silence()
            let start = Double(samples.count) / 16_000
            samples += syllable(part)
            spans.append(start...(Double(samples.count) / 16_000))
        }
        samples += silence()
        let result = ToneAnalysis.analyze(samples: samples, rate: 16_000, spans: spans, expected: [1, 2, 3, 4])
        XCTAssertEqual(result.map { $0?.heard }, [1, 2, 3, 4])
        XCTAssertTrue(result.allSatisfy { $0?.mismatched == false })
        // The same phrase with the last syllable said level is heard as another tone.
        let wrong = ToneAnalysis.analyze(samples: samples, rate: 16_000, spans: spans, expected: [1, 2, 3, 2])
        XCTAssertEqual(wrong[3]?.mismatched, true)
    }

    func testHigherVoicesAreJudgedAgainstTheirOwnRange() {
        let parts: [[Double]] = [[330, 330], [250, 290, 340], [230, 210, 205, 215], [350, 300, 225]]
        var samples: [Float] = []
        var spans: [ClosedRange<Double>?] = []
        for part in parts {
            samples += silence()
            let start = Double(samples.count) / 16_000
            samples += syllable(part)
            spans.append(start...(Double(samples.count) / 16_000))
        }
        let result = ToneAnalysis.analyze(samples: samples, rate: 16_000, spans: spans, expected: [1, 2, 3, 4])
        XCTAssertEqual(result.map { $0?.heard }, [1, 2, 3, 4])
    }

    func testSilenceIsNotJudged() {
        let result = ToneAnalysis.analyze(samples: silence(1), rate: 16_000, spans: [0...0.5], expected: [1])
        XCTAssertNil(result[0] ?? nil)
    }

    func testTonesAsSaidInAPhrase() {
        XCTAssertEqual(ToneAnalysis.tone(of: "mǎ"), 3)
        XCTAssertEqual(ToneAnalysis.tone(of: "ma"), 5)
        XCTAssertEqual(ToneAnalysis.tone(of: "lǜ"), 4)
        // 你好: two third tones, the first said as a second tone.
        XCTAssertEqual(ToneAnalysis.spokenTones(characters: ["你", "好"], syllables: ["nǐ", "hǎo"]), [2, 3])
        // 不要, 一定, 一天.
        XCTAssertEqual(ToneAnalysis.spokenTones(characters: ["不", "要"], syllables: ["bù", "yào"]), [2, 4])
        XCTAssertEqual(ToneAnalysis.spokenTones(characters: ["一", "定"], syllables: ["yī", "dìng"]), [2, 4])
        XCTAssertEqual(ToneAnalysis.spokenTones(characters: ["一", "天"], syllables: ["yī", "tiān"]), [4, 1])
    }
}

final class ToneSlipTests: XCTestCase {
    func testSyllablesTakeAnotherTone() {
        XCTAssertEqual(ToneAnalysis.syllable("mǎ", withTone: 1), "mā")
        XCTAssertEqual(ToneAnalysis.syllable("hǎo", withTone: 4), "hào")
        XCTAssertEqual(ToneAnalysis.syllable("zǒu", withTone: 2), "zóu")
        XCTAssertEqual(ToneAnalysis.syllable("guì", withTone: 3), "guǐ")
        XCTAssertEqual(ToneAnalysis.syllable("lǜ", withTone: 2), "lǘ")
    }

    func testCharactersAreFoundInTheTimedText() {
        let spans = ToneAnalysis.spans(of: ["我", "騎", "馬"], in: [("我騎", 0.2, 0.4), ("碼", 0.7, 0.3)])
        XCTAssertEqual(spans[0], 0.2...0.4)
        XCTAssertEqual(spans[1]?.lowerBound ?? 0, 0.4, accuracy: 0.001)
        XCTAssertEqual(spans[2], 0.7...1.0, "A homophone stands in for the character")
        XCTAssertEqual(ToneAnalysis.spans(of: ["你"], in: []), [nil])
    }

    func testToneSlipsCountHalf() throws {
        let check = ShadowingCheck(target: "我騎馬。", heard: "我騎馬", chinese: true)
        XCTAssertEqual(check.score, 1)
        let horse = try XCTUnwrap(check.units.first { $0.text == "馬" })
        let slipped = check.withToneSlips([horse.id: "mā"])
        XCTAssertEqual(slipped.units.first { $0.text == "馬" }?.mark, .tone(heard: "mā"))
        XCTAssertEqual(slipped.score, 2.5 / 3, accuracy: 0.001)
        XCTAssertTrue(slipped.passed)
        XCTAssertEqual(check.withToneSlips([:]), check)
    }

    func testSentencePinyinReadsWithLatinPunctuation() {
        XCTAssertEqual(ChineseDisplay.readablePinyin("zhè biān qǐng， zhè shì cài dān. yào xiān diǎn yǐn liào ma？"),
                       "zhè biān qǐng, zhè shì cài dān. yào xiān diǎn yǐn liào ma?")
        XCTAssertEqual(ChineseDisplay.readablePinyin("nǐ hǎo，wǒ jiào「xiǎo māo」。"), "nǐ hǎo, wǒ jiào \u{201C}xiǎo māo\u{201D}.")
        XCTAssertEqual(ChineseDisplay.readablePinyin("qī diǎn 7:30 jiàn"), "qī diǎn 7:30 jiàn")
        XCTAssertEqual(ChineseDisplay.readablePinyin(""), "")
    }

    func testEveryCharacterHasItsToneAsSaid() {
        let check = ShadowingCheck(target: "我要一杯冰紅茶。", chinese: true)
        let scored = check.units.filter(\.scored)
        let tones = ToneAnalysis.spokenTones(characters: scored.map(\.text), syllables: scored.map(\.pinyin))
        // 一 before a first tone is said in the fourth.
        XCTAssertEqual(tones, [3, 4, 4, 1, 1, 2, 2])
    }
}
