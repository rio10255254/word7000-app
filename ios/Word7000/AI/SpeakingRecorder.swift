import AVFoundation
import NaturalLanguage
import Observation
import Speech
import Word7000Core

/// A single temporary take. No upload, persistent transcript, or background audio.
@MainActor @Observable
final class SpeakingRecorder: NSObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    enum State { case idle, requesting, recording, ready, playing, transcribing, downloading }
    enum TranscriptionSupport { case checking, modern, download, legacy, unavailable }
    private(set) var state: State = .idle
    private(set) var support: TranscriptionSupport = .checking
    private(set) var seconds: TimeInterval = 0
    private(set) var level: Float = 0
    private(set) var message: String?
    private(set) var transcript: String?
    private(set) var hasRecording = false
    var ownsAudio: Bool { state == .recording || state == .playing || state == .requesting }
    var busy: Bool { ownsAudio || state == .transcribing || state == .downloading }
    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var file: URL?
    @ObservationIgnored private var operation: Task<Void, Never>?
    @ObservationIgnored private var meter: Task<Void, Never>?
    @ObservationIgnored private var deadline: Task<Void, Never>?
    @ObservationIgnored private var cancelRecognition: (() -> Void)?
    @ObservationIgnored private var legacyTask: SFSpeechRecognitionTask?
    @ObservationIgnored private var legacyContinuation: CheckedContinuation<String, Error>?
    private var generation = UUID()
    private var language = "en-US"
    #if DEBUG
    private var simulated: Bool { ProcessInfo.processInfo.arguments.contains("-uiTestingRecording") }
    #endif

    func refresh(language: String) async {
        self.language = language
        #if DEBUG
        if simulated { support = .modern; return }
        #endif
        let expected = language
        var result: TranscriptionSupport = .unavailable
        if #available(iOS 26.0, *), SpeechTranscriber.isAvailable,
           let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: language)) {
            let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
            result = await AssetInventory.status(forModules: [transcriber]) == .installed ? .modern : .download
        } else if SFSpeechRecognizer(locale: Locale(identifier: language))?.supportsOnDeviceRecognition == true {
            result = .legacy
        }
        guard self.language == expected else { return }
        support = result
    }

    func start() {
        guard !busy else { return }
        clear()
        #if DEBUG
        if simulated { state = .recording; seconds = 3; level = 0.4; return }
        #endif
        state = .requesting
        let id = generation
        operation = Task { [weak self] in
            let allowed = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
            }
            guard let self, generation == id, !Task.isCancelled else { return }
            guard allowed else {
                state = .idle
                message = L.t("未開啟麥克風權限。你仍可輸入回答，或到系統設定開啟。", "Microphone access is off. You can still type, or enable it in Settings.")
                return
            }
            await Speaker.shared.stopAndRelease()
            guard generation == id, !Task.isCancelled else { return }
            do {
                let audio = AVAudioSession.sharedInstance()
                try audio.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                try audio.setActive(true)
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("word7000-take-\(UUID().uuidString).m4a")
                file = url
                let recorder = try AVAudioRecorder(url: url, settings: [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44_100,
                    AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ])
                self.recorder = recorder
                recorder.delegate = self
                recorder.isMeteringEnabled = true
                guard recorder.prepareToRecord() else { throw RecordingError.failed }
                try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
                guard recorder.record(forDuration: 60) else { throw RecordingError.failed }
                state = .recording
                meter = Task { [weak self] in
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .milliseconds(100))
                        guard let self, self.generation == id, self.state == .recording else { return }
                        self.recorder?.updateMeters()
                        self.seconds = self.recorder?.currentTime ?? 0
                        self.level = max(0, min(1, ((self.recorder?.averagePower(forChannel: 0) ?? -50) + 50) / 50))
                    }
                }
            } catch {
                clear()
                message = L.t("無法開始錄音，請確認麥克風沒有被其他 App 使用。", "Recording could not start. Check whether another app is using the microphone.")
            }
        }
    }

    func stop() {
        guard state == .recording else { return }
        seconds = max(seconds, recorder?.currentTime ?? 0)
        recorder?.stop()
        recorder = nil
        meter?.cancel(); meter = nil; level = 0
        hasRecording = seconds > 0.2
        state = hasRecording ? .ready : .idle
        releaseAudio()
    }

    func togglePlayback() {
        if state == .playing { stopPlayback(); return }
        #if DEBUG
        if simulated, hasRecording, !busy { state = .playing; return }
        #endif
        guard !busy, hasRecording, let file else { return }
        let id = generation
        state = .requesting
        operation = Task { [weak self] in
            await Speaker.shared.stopAndRelease()
            guard let self, generation == id, !Task.isCancelled else { return }
            do {
                let audio = AVAudioSession.sharedInstance()
                try audio.setCategory(.playback, mode: .spokenAudio)
                try audio.setActive(true)
                player = try AVAudioPlayer(contentsOf: file)
                player?.delegate = self
                guard player?.play() == true else { throw RecordingError.failed }
                state = .playing
            } catch {
                stopPlayback()
                message = L.t("無法播放這段錄音，請重新錄製。", "This recording could not play. Please record another take.")
            }
        }
    }

    func stopPlayback() {
        guard state == .playing || state == .requesting else { return }
        player?.stop(); player = nil
        state = hasRecording ? .ready : .idle
        releaseAudio()
    }

    func transcribe() {
        #if DEBUG
        if simulated, hasRecording, !busy {
            transcript = "I practice with my friend every day."
            state = .ready
            return
        }
        #endif
        guard !busy, hasRecording, let file, support == .modern || support == .legacy else { return }
        message = nil; transcript = nil; state = .transcribing
        let id = generation
        let language = language
        operation = Task { [weak self] in
            guard let self else { return }
            do {
                let text: String
                if #available(iOS 26.0, *), support == .modern {
                    text = try await modernTranscript(file: file, language: language)
                } else {
                    let permission = await withCheckedContinuation { continuation in
                        SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
                    }
                    guard generation == id, !Task.isCancelled else { return }
                    guard permission == .authorized else { throw RecordingError.permission }
                    text = try await legacyTranscript(file: file, language: language)
                }
                guard generation == id, !Task.isCancelled else { return }
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RecordingError.empty }
                transcript = text
                state = .ready
            } catch {
                guard generation == id, !Task.isCancelled else { return }
                state = .ready
                if case RecordingError.empty = error {
                    message = L.t("沒有辨識到清楚的語音。可以先回放，再重新錄製或自行輸入。", "No clear speech was recognized. Replay the recording, then try another take or type your answer.")
                } else if case RecordingError.permission = error {
                    message = L.t("尚未允許語音辨識。可以到系統設定開啟，或繼續回放與自行輸入。", "Speech recognition is not allowed. Enable it in Settings, or keep using playback and typed answers.")
                } else {
                    message = L.t("這次無法在手機內辨識。錄音仍可回放，也可以自行輸入回答。", "On-device transcription was unavailable. Your recording can still be replayed, or you can type your answer.")
                }
            }
            deadline?.cancel(); deadline = nil; cancelRecognition = nil
        }
        deadline = Task { [weak self] in
            try? await Task.sleep(for: .seconds(45))
            guard !Task.isCancelled, let self, self.generation == id, self.state == .transcribing else { return }
            self.cancelProcessing()
            self.message = L.t("辨識等候太久。錄音仍在，請稍後重試或自行輸入。", "Transcription took too long. Your recording is still here; retry or type your answer.")
        }
    }

    @available(iOS 26.0, *)
    private func modernTranscript(file: URL, language: String) async throws -> String {
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: language)) else { throw RecordingError.failed }
        try Task.checkCancellation()
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        guard await AssetInventory.status(forModules: [transcriber]) == .installed else { throw RecordingError.failed }
        try Task.checkCancellation()
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        cancelRecognition = { Task { await analyzer.cancelAndFinishNow() } }
        do {
            try await analyzer.start(inputAudioFile: AVAudioFile(forReading: file), finishAfterFile: true)
            var parts: [String] = []
            for try await result in transcriber.results {
                try Task.checkCancellation()
                if result.isFinal { parts.append(String(result.text.characters)) }
            }
            await analyzer.cancelAndFinishNow()
            return parts.joined(separator: language.hasPrefix("zh") ? "" : " ")
        } catch {
            await analyzer.cancelAndFinishNow()
            throw error
        }
    }

    private func legacyTranscript(file: URL, language: String) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)),
              recognizer.supportsOnDeviceRecognition else { throw RecordingError.failed }
        let request = SFSpeechURLRecognitionRequest(url: file)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        let id = generation
        cancelRecognition = { [weak self] in self?.finishLegacy(.failure(CancellationError())) }
        return try await withCheckedThrowingContinuation { continuation in
            legacyContinuation = continuation
            legacyTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let text = result?.isFinal == true ? result?.bestTranscription.formattedString : nil
                Task { @MainActor in
                    guard let self, self.generation == id else { return }
                    if let text { self.finishLegacy(.success(text)) }
                    else if let error { self.finishLegacy(.failure(error)) }
                }
            }
        }
    }

    private func finishLegacy(_ result: Result<String, Error>) {
        let continuation = legacyContinuation
        legacyContinuation = nil
        legacyTask?.cancel(); legacyTask = nil
        continuation?.resume(with: result)
    }

    func downloadLanguage() {
        guard !busy, support == .download else { return }
        state = .downloading; message = nil
        let id = generation
        let language = language
        operation = Task { [weak self] in
            guard let self else { return }
            do {
                if #available(iOS 26.0, *), let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: language)) {
                    let module = SpeechTranscriber(locale: locale, preset: .transcription)
                    if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                        try await request.downloadAndInstall()
                    }
                }
                guard generation == id, !Task.isCancelled else { return }
                state = hasRecording ? .ready : .idle
                await refresh(language: language)
            } catch {
                guard generation == id, !Task.isCancelled else { return }
                state = hasRecording ? .ready : .idle
                message = L.t("語言下載尚未完成，請稍後再試。", "The language download did not finish. Try again later.")
            }
        }
    }

    func cancelProcessing() {
        generation = UUID()
        operation?.cancel(); operation = nil
        deadline?.cancel(); deadline = nil
        cancelRecognition?(); cancelRecognition = nil
        state = hasRecording ? .ready : .idle
    }

    func interrupt() {
        if state == .recording { stop() }
        if state == .playing { stopPlayback() }
        if state == .transcribing || state == .downloading || state == .requesting { cancelProcessing() }
    }

    func clear() {
        let hadAudio = ownsAudio
        cancelProcessing()
        meter?.cancel(); meter = nil
        recorder?.stop(); recorder = nil
        player?.stop(); player = nil
        if let file { try? FileManager.default.removeItem(at: file) }
        file = nil; hasRecording = false; transcript = nil; message = nil
        seconds = 0; level = 0; state = .idle
        if hadAudio { releaseAudio() }
    }

    static func removeAbandonedTakes() {
        let directory = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for file in files where file.lastPathComponent.hasPrefix("word7000-take-") && file.pathExtension == "m4a" {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func releaseAudio() { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    private enum RecordingError: Error { case failed, permission, empty }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            guard self.recorder === recorder, state == .recording else { return }
            seconds = max(seconds, min(60, recorder.currentTime)); stop()
        }
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in if self.player === player { stopPlayback() } }
    }
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            guard self.recorder === recorder else { return }
            clear()
            message = L.t("錄音中斷，請重新錄製或輸入回答。", "Recording was interrupted. Record again or type your answer.")
        }
    }
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            guard self.player === player else { return }
            stopPlayback()
            message = L.t("無法播放這段錄音，請重新錄製。", "This recording could not play. Please record another take.")
        }
    }

    static func reflection(answer: String, target: String, chinese: Bool) -> SpeakingReflection {
        var matched = false
        if !chinese, SpeakingReflection.tokens(target).count == 1, !answer.isEmpty {
            let tagger = NLTagger(tagSchemes: [.lemma])
            tagger.string = answer
            tagger.setLanguage(.english, range: answer.startIndex..<answer.endIndex)
            tagger.enumerateTags(in: answer.startIndex..<answer.endIndex, unit: .word, scheme: .lemma,
                                 options: [.omitWhitespace, .omitPunctuation]) { tag, _ in
                if tag?.rawValue.lowercased() == target.lowercased() { matched = true; return false }
                return true
            }
        }
        return SpeakingReflection(answer: answer, target: target, chinese: chinese, matchedLemma: matched)
    }
}
