import Foundation

public enum SpeechSpeed: String, Codable, CaseIterable, Identifiable, Sendable {
    case slow, natural, brisk
    public var id: String { rawValue }
    public var multiplier: Double {
        switch self {
        case .slow: 0.82
        case .natural: 1
        case .brisk: 1.12
        }
    }
}

public struct SpeechPreferences: Codable, Equatable, Sendable {
    public var englishVoiceID: String?
    public var chineseVoiceID: String?
    public var speed: SpeechSpeed
    /// Reads each new study card aloud. Optional so settings saved before it
    /// existed still decode; nil means off.
    public var autoSpeak: Bool?
    /// Reads each speaking question aloud as it appears; nil means on.
    public var autoReadQuestions: Bool?

    public init(englishVoiceID: String? = nil, chineseVoiceID: String? = nil, speed: SpeechSpeed = .natural, autoSpeak: Bool? = nil,
                autoReadQuestions: Bool? = nil) {
        self.englishVoiceID = englishVoiceID
        self.chineseVoiceID = chineseVoiceID
        self.speed = speed
        self.autoSpeak = autoSpeak
        self.autoReadQuestions = autoReadQuestions
    }

    public func voiceID(for language: String) -> String? {
        language.lowercased().hasPrefix("en") ? englishVoiceID : chineseVoiceID
    }
}

public struct SpeechVoiceOption: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let language: String
    public let quality: Int

    public init(id: String, name: String, language: String, quality: Int) {
        self.id = id
        self.name = name
        self.language = language
        self.quality = quality
    }
}

public enum SpeechVoiceSelection {
    public static func matching(_ voices: [SpeechVoiceOption], language: String) -> [SpeechVoiceOption] {
        let requested = language.lowercased().replacingOccurrences(of: "_", with: "-")
        return voices.filter { voice in
            let locale = voice.language.lowercased().replacingOccurrences(of: "_", with: "-")
            if requested.hasPrefix("en") { return locale.hasPrefix("en-") || locale == "en" }
            if requested.hasPrefix("zh") {
                return ["zh-tw", "zh-cn", "cmn-tw", "cmn-cn"].contains(locale)
            }
            return locale == requested
        }
    }

    /// The warmest-sounding voices iOS lets apps use, best first. Among voices
    /// of the same quality one of these wins over the rest.
    static let natural = ["Ava", "Zoe", "Evan", "Nathan", "Noelle", "Joelle", "Allison", "Tom", "Susan", "Samantha", "Meijia"]

    /// Robotic voices (the Eloquence set, for screen readers) are never the
    /// automatic choice; a learner can still pick one by hand.
    static func isRobotic(_ voice: SpeechVoiceOption) -> Bool {
        voice.id.lowercased().contains("eloquence")
    }

    public static func preferred(_ voices: [SpeechVoiceOption], language: String, selectedID: String?, systemDefaultID: String?) -> SpeechVoiceOption? {
        let candidates = matching(voices, language: language)
        if let selectedID, let explicit = candidates.first(where: { $0.id == selectedID }) { return explicit }
        let requested = language.lowercased().replacingOccurrences(of: "_", with: "-")
        let human = candidates.filter { !isRobotic($0) }
        let pool = human.isEmpty ? candidates : human
        let exact = pool.filter { $0.language.lowercased().replacingOccurrences(of: "_", with: "-") == requested }
        func rank(_ voice: SpeechVoiceOption) -> Int {
            natural.firstIndex { voice.name.hasPrefix($0) } ?? natural.count
        }
        return (exact.isEmpty ? pool : exact).sorted { a, b in
            if a.quality != b.quality { return a.quality > b.quality }
            if rank(a) != rank(b) { return rank(a) < rank(b) }
            if (a.id == systemDefaultID) != (b.id == systemDefaultID) { return a.id == systemDefaultID }
            return a.id < b.id
        }.first
    }

    /// True when only standard (compact) voices are installed for a language,
    /// so a far more natural one is a free download away.
    public static func canSoundBetter(_ voices: [SpeechVoiceOption], language: String, enhancedQuality: Int) -> Bool {
        !matching(voices, language: language).contains { $0.quality >= enhancedQuality && !isRobotic($0) }
    }
}
