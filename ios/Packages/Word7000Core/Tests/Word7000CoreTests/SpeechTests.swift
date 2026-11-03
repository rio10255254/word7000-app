import XCTest
@testable import Word7000Core

final class SpeechTests: XCTestCase {
    private let voices = [
        SpeechVoiceOption(id: "us-basic", name: "Basic", language: "en-US", quality: 1),
        SpeechVoiceOption(id: "us-enhanced", name: "Enhanced", language: "en-US", quality: 2),
        SpeechVoiceOption(id: "us-premium", name: "Premium", language: "en-US", quality: 3),
        SpeechVoiceOption(id: "uk-premium", name: "UK", language: "en-GB", quality: 3),
        SpeechVoiceOption(id: "tw-basic", name: "Taiwan", language: "zh-TW", quality: 1),
        SpeechVoiceOption(id: "cn-premium", name: "Mandarin", language: "zh-CN", quality: 3),
        SpeechVoiceOption(id: "hk-premium", name: "Cantonese", language: "zh-HK", quality: 3),
    ]

    func testAutomaticUsesBestQualityForTheRequestedAccent() {
        XCTAssertEqual(SpeechVoiceSelection.preferred(voices, language: "en-US", selectedID: nil, systemDefaultID: "us-basic")?.id, "us-premium")
        XCTAssertEqual(SpeechVoiceSelection.preferred(voices, language: "zh-TW", selectedID: nil, systemDefaultID: "tw-basic")?.id, "tw-basic")
    }

    func testHonorsTheLearnersVoiceAndFallsBackWhenItIsRemoved() {
        XCTAssertEqual(SpeechVoiceSelection.preferred(voices, language: "en-US", selectedID: "uk-premium", systemDefaultID: nil)?.id, "uk-premium")
        XCTAssertEqual(SpeechVoiceSelection.preferred(voices, language: "en-US", selectedID: "deleted-voice", systemDefaultID: nil)?.id, "us-premium")
        XCTAssertEqual(SpeechVoiceSelection.preferred(voices, language: "en-US", selectedID: "cn-premium", systemDefaultID: nil)?.id, "us-premium")
        XCTAssertNil(SpeechVoiceSelection.preferred([], language: "en-US", selectedID: "us-basic", systemDefaultID: nil))
    }

    func testPrefersANaturalVoiceAndNeverPicksARoboticOneByItself() {
        let compact = [
            SpeechVoiceOption(id: "com.apple.eloquence.en-US.Eddy", name: "Eddy", language: "en-US", quality: 1),
            SpeechVoiceOption(id: "com.apple.voice.compact.en-US.Fred", name: "Fred", language: "en-US", quality: 1),
            SpeechVoiceOption(id: "com.apple.voice.compact.en-US.Samantha", name: "Samantha", language: "en-US", quality: 1),
        ]
        XCTAssertEqual(SpeechVoiceSelection.preferred(compact, language: "en-US", selectedID: nil, systemDefaultID: nil)?.name, "Samantha")
        XCTAssertEqual(SpeechVoiceSelection.preferred(compact, language: "en-US", selectedID: "com.apple.eloquence.en-US.Eddy", systemDefaultID: nil)?.name, "Eddy")
        XCTAssertTrue(SpeechVoiceSelection.canSoundBetter(compact, language: "en-US", enhancedQuality: 2))
        let withAva = compact + [SpeechVoiceOption(id: "com.apple.voice.premium.en-US.Ava", name: "Ava (Premium)", language: "en-US", quality: 3)]
        XCTAssertEqual(SpeechVoiceSelection.preferred(withAva, language: "en-US", selectedID: nil, systemDefaultID: nil)?.name, "Ava (Premium)")
        XCTAssertFalse(SpeechVoiceSelection.canSoundBetter(withAva, language: "en-US", enhancedQuality: 2))
    }

    func testDoesNotSubstituteCantoneseForMandarin() {
        let unavailableTaiwan = voices.filter { $0.id != "tw-basic" }
        XCTAssertEqual(SpeechVoiceSelection.preferred(unavailableTaiwan, language: "zh-TW", selectedID: "hk-premium", systemDefaultID: nil)?.id, "cn-premium")
    }

    func testVoiceAndSpeedSettingsRoundTripIndependently() throws {
        let saved = SpeechPreferences(englishVoiceID: "uk-premium", chineseVoiceID: "tw-basic", speed: .slow)
        let restored = try JSONDecoder().decode(SpeechPreferences.self, from: JSONEncoder().encode(saved))
        XCTAssertEqual(restored, saved)
        XCTAssertEqual(restored.voiceID(for: "en-US"), "uk-premium")
        XCTAssertEqual(restored.voiceID(for: "zh-TW"), "tw-basic")
    }
}
