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

    public init(englishVoiceID: String? = nil, chineseVoiceID: String? = nil, speed: SpeechSpeed = .natural) {
        self.englishVoiceID = englishVoiceID
        self.chineseVoiceID = chineseVoiceID
        self.speed = speed
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

    public static func preferred(_ voices: [SpeechVoiceOption], language: String, selectedID: String?, systemDefaultID: String?) -> SpeechVoiceOption? {
        let candidates = matching(voices, language: language)
        if let selectedID, let explicit = candidates.first(where: { $0.id == selectedID }) { return explicit }
        let requested = language.lowercased().replacingOccurrences(of: "_", with: "-")
        let exact = candidates.filter { $0.language.lowercased().replacingOccurrences(of: "_", with: "-") == requested }
        return (exact.isEmpty ? candidates : exact).sorted { a, b in
            if a.quality != b.quality { return a.quality > b.quality }
            if (a.id == systemDefaultID) != (b.id == systemDefaultID) { return a.id == systemDefaultID }
            return a.id < b.id
        }.first
    }
}
