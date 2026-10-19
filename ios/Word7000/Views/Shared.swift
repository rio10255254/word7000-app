import AVFoundation
import Observation
import SwiftUI

/// Reads a word aloud with the system voice; works offline.
@MainActor
@Observable
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = Speaker()
    private(set) var activeText: String?
    private(set) var activeLanguage: String?
    @ObservationIgnored private var activeUtterance: AVSpeechUtterance?
    @ObservationIgnored private var speechID: UUID?
    @ObservationIgnored private let audioQueue = DispatchQueue(label: "word7000.speech-audio", qos: .userInitiated)
    @ObservationIgnored
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, language: String = "en-US") {
        if activeText == text, activeLanguage == language { stop(); return }
        stop()
        let id = UUID()
        speechID = id
        activeText = text
        activeLanguage = language
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
                utterance.voice = AVSpeechSynthesisVoice(language: language)
                utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
                self.activeUtterance = utterance
                self.synthesizer.speak(utterance)
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

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if activeUtterance === utterance { stop() }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        if activeUtterance === utterance { stop() }
    }
}

struct SpeakButton: View {
    var text: String
    var language: String = "en-US"

    var body: some View {
        let playing = Speaker.shared.activeText == text && Speaker.shared.activeLanguage == language
        Button { Speaker.shared.speak(text, language: language) } label: {
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
