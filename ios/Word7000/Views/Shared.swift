import AVFoundation
import Observation
import SwiftUI
import Word7000Core

enum WordAudioSession {
    static let queue = DispatchQueue(label: "word7000.speech-audio", qos: .userInitiated)

    static func activate(recording: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(recording ? .playAndRecord : .playback,
                                            mode: recording ? .default : .spokenAudio,
                                            options: recording ? [.defaultToSpeaker] : [])
                    try session.setActive(true)
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    static func release() {
        queue.async { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    }
}

/// Reads a word aloud with the system voice; works offline.
@MainActor
@Observable
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = Speaker()
    private(set) var activeText: String?
    private(set) var activeLanguage: String?
    private(set) var voices: [SpeechVoiceOption] = []
    /// The system's default voice for each app language, looked up once when
    /// the voice list arrives. Asking on every redraw kept the main thread busy
    /// for many seconds on a cold start; asking off the main thread never
    /// returned on iOS 27.
    @ObservationIgnored private var systemDefaultIDs: [String: String] = [:]
    @ObservationIgnored private var voicesTask: Task<[SpeechVoiceOption], Never>?
    @ObservationIgnored private var activeUtterance: AVSpeechUtterance?
    @ObservationIgnored private var speechID: UUID?
    @ObservationIgnored private let audioQueue = WordAudioSession.queue
    @ObservationIgnored
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func refreshVoices() async {
        if let task = voicesTask { apply(await task.value); return }
        let task = Task.detached(priority: .utility) { () -> [SpeechVoiceOption] in
            var options: [SpeechVoiceOption] = []
            for voice in AVSpeechSynthesisVoice.speechVoices() {
                guard !voice.voiceTraits.contains(.isNoveltyVoice),
                      !voice.voiceTraits.contains(.isPersonalVoice) else { continue }
                options.append(SpeechVoiceOption(id: voice.identifier, name: voice.name,
                                                language: voice.language, quality: Int(voice.quality.rawValue)))
            }
            options.sort { a, b in
                if a.name == b.name { return a.id < b.id }
                return a.name < b.name
            }
            return options
        }
        voicesTask = task
        apply(await task.value)
        voicesTask = nil
    }

    private func apply(_ options: [SpeechVoiceOption]) {
        if systemDefaultIDs.isEmpty {
            for language in ["en-US", "zh-TW"] {
                systemDefaultIDs[language] = AVSpeechSynthesisVoice(language: language)?.identifier
            }
        }
        voices = options
    }

    func selectedVoice(language: String, preferences: SpeechPreferences) -> SpeechVoiceOption? {
        SpeechVoiceSelection.preferred(voices, language: language, selectedID: preferences.voiceID(for: language),
                                       systemDefaultID: systemDefaultIDs[language])
    }

    func speak(_ text: String, language: String = "en-US", preferences: SpeechPreferences = SpeechPreferences()) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if activeText == text, activeLanguage == language { stop(); return }
        stop()
        let id = UUID()
        speechID = id
        activeText = text
        activeLanguage = language
        Task { [weak self] in
          guard let self else { return }
          if voices.isEmpty { await refreshVoices() }
          guard speechID == id else { return }
          let voiceID = selectedVoice(language: language, preferences: preferences)?.id
          audioQueue.async { [weak self] in
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                Task { @MainActor in if self?.speechID == id { self?.stop() } }
                return
            }
            Task { @MainActor in
                guard let self, self.speechID == id else { return }
                let utterance = AVSpeechUtterance(string: text)
                utterance.voice = voiceID.flatMap { AVSpeechSynthesisVoice(identifier: $0) } ?? AVSpeechSynthesisVoice(language: language)
                let isolatedWord = language.hasPrefix("en")
                    ? text.split(whereSeparator: { $0.isWhitespace }).count == 1 && text.count < 30 : text.count <= 4
                let rate = AVSpeechUtteranceDefaultSpeechRate * Float(preferences.speed.multiplier) * (isolatedWord ? 0.94 : 1)
                utterance.rate = min(AVSpeechUtteranceMaximumSpeechRate, max(AVSpeechUtteranceMinimumSpeechRate, rate))
                utterance.pitchMultiplier = 1
                utterance.prefersAssistiveTechnologySettings = true
                self.activeUtterance = utterance
                self.synthesizer.speak(utterance)
            }
          }
        }
    }

    func stop() {
        guard activeText != nil else { return }
        speechID = nil
        activeUtterance = nil
        activeText = nil
        activeLanguage = nil
        synthesizer.stopSpeaking(at: .immediate)
        audioQueue.async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    func stopAndRelease() async {
        stop()
        await withCheckedContinuation { continuation in
            audioQueue.async { continuation.resume() }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in if activeUtterance === utterance { stop() } }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in if activeUtterance === utterance { stop() } }
    }
}

struct SpeakButton: View {
    @Environment(AppModel.self) private var model
    var text: String
    var language: String = "en-US"

    var body: some View {
        let playing = Speaker.shared.activeText == text && Speaker.shared.activeLanguage == language
        Button { Speaker.shared.speak(text, language: language, preferences: model.settings.speech ?? SpeechPreferences()) } label: {
            Image(systemName: playing ? "stop.fill" : "speaker.wave.2.fill")
                .font(.title3)
                .foregroundStyle(Palette.accent)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel(playing ? L.t("停止播放", "Stop audio") : L.pronounce)
    }
}

extension Color {
    init?(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let number = UInt32(value, radix: 16) else { return nil }
        self.init(
            red: Double((number >> 16) & 0xFF) / 255,
            green: Double((number >> 8) & 0xFF) / 255,
            blue: Double(number & 0xFF) / 255
        )
    }
}
