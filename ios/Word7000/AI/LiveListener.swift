import AVFoundation
import Observation
import Speech
import Word7000Core

/// Listens while the learner speaks and turns it into text as it goes, on
/// this iPhone only: with Apple's newer recognizer (iOS 26) where its model
/// for the language is on the phone, otherwise with the older one. The take
/// is kept (temporarily) to play back and to measure its pitch; nothing is
/// uploaded. Where this iPhone cannot recognize the language on the device,
/// it still records. Its loudness tells when the learner has stopped
/// speaking, with or without text.
@MainActor @Observable
final class LiveListener: NSObject, AVAudioPlayerDelegate {
    enum State { case idle, requesting, listening, finishing, ready, playing }
    /// `live`: text while speaking. `afterwards`: this iPhone recognizes the
    /// language only with Apple's newer recognizer, so the take becomes text
    /// once it ends, as before live listening. `recordOnly`: no recognition.
    enum Support { case checking, live, afterwards, recordOnly }

    private(set) var state: State = .idle
    private(set) var support: Support = .checking
    /// 0...1, for the ring around the key.
    private(set) var level: Float = 0
    /// What was heard so far, updated while speaking.
    private(set) var text = ""
    /// The recognizer has finished with this take.
    private(set) var isFinal = false
    /// Recognized pieces with where they fall in the take, for pitch.
    private(set) var segments: [Segment] = []
    private(set) var hasRecording = false
    /// Seconds recorded so far.
    private(set) var seconds: TimeInterval = 0
    private(set) var message: String? {
        didSet { messageNeedsSettings = false }
    }
    /// Only permission problems are fixed in Settings.
    private(set) var messageNeedsSettings = false
    /// Seconds since the last change to the text (or since listening began).
    var quietFor: TimeInterval { Date().timeIntervalSince(lastChange) }
    /// A voice was heard in this take, by its loudness against the room's.
    private(set) var heardVoice = false
    /// Seconds since the voice was last heard; 0 until it was.
    var silentFor: TimeInterval { heardVoice ? Date().timeIntervalSince(lastVoice) : 0 }

    struct Segment: Equatable, Sendable {
        let text: String
        let start: TimeInterval
        let duration: TimeInterval
    }

    var listening: Bool { state == .listening }
    var busy: Bool { state == .requesting || state == .listening || state == .finishing }

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var file: URL?
    @ObservationIgnored private var player: AVAudioPlayer?
    /// When the live audio engine cannot start (an unusual audio route, or
    /// a simulator), a plain recorder takes the take instead, as before.
    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var meter: Task<Void, Never>?
    @ObservationIgnored private var finishing: Task<Void, Never>?
    @ObservationIgnored private let store = SampleStore()
    @ObservationIgnored private var lastChange = Date()
    @ObservationIgnored private var lastVoice = Date()
    @ObservationIgnored private var loudSince: Date?
    /// The room's own level, learned from the quietest moments; -1 until measured.
    @ObservationIgnored private var noiseFloor: Float = -1
    /// Apple's newer recognizer has this language on the phone: it listens live.
    @ObservationIgnored private var useAnalyzer = false
    /// The older recognizer can listen live on the device.
    @ObservationIgnored private var legacyLive = false
    /// A finished take can still become text with the newer recognizer.
    @ObservationIgnored private var canTranscribeFile = false
    /// The newer recognizer's live session: no more audio, then the last words settle.
    @ObservationIgnored private var streamingFinish: (() async -> Void)?
    @ObservationIgnored private var streamingCancel: (() -> Void)?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var language = "en-US"
    #if DEBUG
    @ObservationIgnored private var simulation: Task<Void, Never>?
    /// UI tests: what a simulated take says, a word (or character) at a time.
    @ObservationIgnored var simulatedText: String?
    private var simulated: Bool { ProcessInfo.processInfo.arguments.contains("-uiTestingRecording") }
    #endif

    /// The recorded take as mono samples, for pitch.
    var samples: (values: [Float], rate: Double) { store.snapshot() }

    func refresh(language: String) async {
        self.language = language
        #if DEBUG
        if simulated { support = .live; return }
        #endif
        let expected = language
        // The newer recognizer first: it hears Taiwan Mandarin much better,
        // and gives text while the learner is still speaking.
        var analyzer = false
        if #available(iOS 26.0, *), SpeechTranscriber.isAvailable,
           let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: language)),
           await AssetInventory.status(forModules: [SpeechTranscriber(locale: locale, preset: .transcription)]) == .installed {
            analyzer = true
        }
        let legacy = SFSpeechRecognizer(locale: Locale(identifier: language))?.supportsOnDeviceRecognition == true
        guard self.language == expected else { return }
        useAnalyzer = analyzer
        legacyLive = legacy
        canTranscribeFile = analyzer
        support = analyzer || legacy ? .live : .recordOnly
    }

    /// Starts a take. `hints` only bias recognition (none when the exact
    /// words matter, as when saying a sentence after the model).
    func start(hints: [String] = []) {
        guard !busy else { return }
        clear()
        let id = generation
        lastChange = Date()
        #if DEBUG
        if simulated { simulate(id); return }
        #endif
        state = .requesting
        Task { [weak self] in
            let allowed = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
            }
            guard let self, self.generation == id else { return }
            guard allowed else {
                self.state = .idle
                self.message = L.t("未開啟麥克風權限。你仍可輸入回答，或到系統設定開啟。", "Microphone access is off. You can still type, or turn it on in Settings.")
                self.messageNeedsSettings = true
                return
            }
            if self.support == .live, !self.useAnalyzer {
                let status = await withCheckedContinuation { continuation in
                    SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
                }
                guard self.generation == id else { return }
                if status != .authorized { self.support = .recordOnly }
            }
            await Speaker.shared.stopAndRelease()
            guard self.generation == id else { return }
            do {
                try await WordAudioSession.activate(recording: true)
                guard self.generation == id else { return }
                var feed: ((AVAudioPCMBuffer) -> Void)?
                if self.useAnalyzer, #available(iOS 26.0, *) {
                    feed = await self.startStreaming(id: id)
                    guard self.generation == id else { return }
                }
                do {
                    try self.begin(hints: hints, id: id, feed: feed)
                } catch {
                    // No live audio here: record plainly and turn it into text afterwards.
                    self.abandonLive()
                    try self.beginRecorder(id: id)
                }
            } catch {
                self.abandonLive()
                self.state = .idle
                self.message = L.t("無法開始錄音，請確認麥克風沒有被其他 App 使用。", "Recording could not start. Check whether another app is using the microphone.")
                WordAudioSession.release()
            }
        }
    }

    private func abandonLive() {
        stopEngine()
        task?.cancel(); task = nil
        request = nil
        streamingCancel?(); streamingCancel = nil; streamingFinish = nil
        if let file { try? FileManager.default.removeItem(at: file) }
        file = nil
    }

    private func beginRecorder(id: UUID) throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("word7000-take-\(UUID().uuidString).m4a")
        let recorder = try AVAudioRecorder(url: url, settings: [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ])
        recorder.isMeteringEnabled = true
        guard recorder.prepareToRecord(), recorder.record(forDuration: 60) else { throw ListenError.noInput }
        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        file = url
        self.recorder = recorder
        state = .listening
        meter = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, self.generation == id, self.state == .listening, let recorder = self.recorder else { return }
                recorder.updateMeters()
                self.seconds = recorder.currentTime
                self.hear(max(0, min(1, (recorder.averagePower(forChannel: 0) + 50) / 50)))
            }
        }
    }

    /// Ends a plain recording and turns it into text with whichever
    /// recognizer this iPhone has on the device.
    private func stopRecorder(_ recorder: AVAudioRecorder) {
        seconds = max(seconds, recorder.currentTime)
        recorder.stop()
        self.recorder = nil
        meter?.cancel(); meter = nil
        hasRecording = seconds > 0.2 && file != nil
        guard hasRecording, let file, support != .recordOnly else { complete(); return }
        state = .finishing
        let id = generation
        let language = language
        let newer = canTranscribeFile
        finishing = Task { [weak self] in
            var text = ""
            if #available(iOS 26.0, *), newer {
                text = (try? await LiveListener.transcribe(file: file, language: language)) ?? ""
            } else {
                text = await LiveListener.transcribeOnDevice(file: file, language: language)
            }
            guard let self, self.generation == id, self.state == .finishing else { return }
            if !text.isEmpty { self.text = text }
            self.complete()
        }
    }

    /// A finished take as text with the older recognizer, on the device only.
    private static func transcribeOnDevice(file: URL, language: String) async -> String {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)),
              recognizer.supportsOnDeviceRecognition else { return "" }
        let request = SFSpeechURLRecognitionRequest(url: file)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        request.addsPunctuation = true
        return await withCheckedContinuation { continuation in
            var resumed = false
            let lock = NSLock()
            func finish(_ text: String) {
                lock.lock(); defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: text)
            }
            _ = recognizer.recognitionTask(with: request) { result, error in
                if let result, result.isFinal { finish(result.bestTranscription.formattedString) }
                else if error != nil { finish("") }
            }
        }
    }

    /// `feed`, when set, takes the audio for the newer recognizer; otherwise
    /// the older one listens, where it can on the device.
    private func begin(hints: [String], id: UUID, feed: ((AVAudioPCMBuffer) -> Void)?) throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw ListenError.noInput }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("word7000-take-\(UUID().uuidString).caf")
        let output = try AVAudioFile(forWriting: url, settings: format.settings)
        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        file = url
        store.reset(rate: format.sampleRate)

        let recognizer = feed == nil && legacyLive && support == .live ? SFSpeechRecognizer(locale: Locale(identifier: language)) : nil
        let recognitionRequest: SFSpeechAudioBufferRecognitionRequest? =
            recognizer?.supportsOnDeviceRecognition == true ? SFSpeechAudioBufferRecognitionRequest() : nil
        if let recognizer, let request = recognitionRequest {
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = true
            // The recognizer's own punctuation, so answers read as sentences.
            request.addsPunctuation = true
            request.contextualStrings = hints
            self.request = request
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let segments = result?.bestTranscription.segments.map {
                    Segment(text: $0.substring, start: $0.timestamp, duration: $0.duration)
                }
                let final = result?.isFinal == true || (error != nil)
                Task { @MainActor in
                    guard let self, self.generation == id else { return }
                    self.receive(text: text, segments: segments, final: final)
                }
            }
        }

        let store = self.store
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            recognitionRequest?.append(buffer)
            feed?(buffer)
            try? output.write(from: buffer)
            let level = store.append(buffer)
            let seconds = store.seconds
            Task { @MainActor in
                guard let self, self.generation == id, self.state == .listening else { return }
                self.hear(level)
                self.seconds = seconds
            }
        }
        engine.prepare()
        try engine.start()
        hasRecording = false
        state = .listening
    }

    private func receive(text: String?, segments: [Segment]?, final: Bool) {
        if let text, text != self.text {
            self.text = text
            lastChange = Date()
        }
        if let segments { self.segments = segments }
        if final { settle() }
    }

    /// The live recognizer is done. When the older one heard nothing although
    /// someone spoke, the newer one still gets a go at the recording.
    private func settle() {
        if text.isEmpty, heardVoice, canTranscribeFile, streamingFinish == nil,
           state == .listening || state == .finishing, let file, store.count > 0 {
            stopEngine()
            finishing?.cancel(); finishing = nil
            task?.cancel(); task = nil
            request = nil
            hasRecording = true
            transcribeAfterwards(file)
            return
        }
        complete()
    }

    /// Learns the room's level and notes when a voice rises above it. A
    /// sound counts as a voice once it lasts a moment, so a tap or a click
    /// does not.
    private func hear(_ level: Float) {
        self.level = level
        if noiseFloor < 0 { noiseFloor = level }
        // Down quickly to a quieter room, up only slowly while someone speaks.
        noiseFloor += (level - noiseFloor) * (level < noiseFloor ? 0.5 : 0.003)
        let threshold = min(0.8, max(0.28, noiseFloor + 0.16))
        let now = Date()
        guard level > threshold else { loudSince = nil; return }
        if loudSince == nil { loudSince = now }
        if heardVoice || now.timeIntervalSince(loudSince ?? now) >= 0.06 {
            heardVoice = true
            lastVoice = now
        }
    }

    /// Starts the newer recognizer on this take and returns where its audio
    /// goes; nil when it cannot start, and the older recognizer listens.
    @available(iOS 26.0, *)
    private func startStreaming(id: UUID) async -> ((AVAudioPCMBuffer) -> Void)? {
        let language = language
        guard let streaming = try? await StreamingTranscription.start(language: language) else { return nil }
        guard generation == id else { streaming.cancel(); return nil }
        streamingFinish = { await streaming.finish() }
        streamingCancel = { streaming.cancel() }
        let chinese = language.hasPrefix("zh")
        Task { @MainActor [weak self] in
            // Settled text, then what is still being heard after it.
            var settled = "", settledSegments: [Segment] = []
            var latest = "", latestSegments: [Segment] = []
            do {
                for try await result in streaming.transcriber.results {
                    let piece = String(result.text.characters)
                    var pieceSegments: [Segment] = []
                    for run in result.text.runs {
                        guard let range = run.audioTimeRange else { continue }
                        let text = String(result.text[run.range].characters)
                        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
                        pieceSegments.append(Segment(text: text, start: range.start.seconds, duration: range.duration.seconds))
                    }
                    latest = Self.join(settled, piece, chinese: chinese)
                    latestSegments = settledSegments + pieceSegments
                    if result.isFinal { settled = latest; settledSegments = latestSegments }
                    guard let self, self.generation == id else { return }
                    self.receive(text: latest, segments: latestSegments, final: false)
                }
            } catch {}
            guard let self, self.generation == id else { return }
            self.receive(text: latest, segments: latestSegments, final: true)
        }
        return { streaming.append($0) }
    }

    private static func join(_ before: String, _ piece: String, chinese: Bool) -> String {
        if before.isEmpty { return piece.trimmingCharacters(in: .whitespaces) }
        if chinese || before.hasSuffix(" ") || piece.hasPrefix(" ") { return before + piece }
        return before + " " + piece
    }

    /// Ends the take; the text becomes final shortly after.
    func stop() {
        guard state == .listening || state == .requesting else { return }
        #if DEBUG
        if simulated {
            // Recognition settles on the whole take once it ends.
            simulation?.cancel()
            let full = simulatedText ?? "I practice with my friend every day."
            receive(text: full, segments: nil, final: false)
            complete(); hasRecording = true; return
        }
        #endif
        if let recorder { stopRecorder(recorder); return }
        stopEngine()
        hasRecording = file != nil && store.count > 0
        if let finish = streamingFinish {
            // The last words settle once the recognizer knows the take is over.
            state = .finishing
            let id = generation
            finishing = Task { [weak self] in
                await finish()
                try? await Task.sleep(for: .seconds(2))
                guard let self, self.generation == id, self.state == .finishing else { return }
                self.complete()
            }
            return
        }
        if request == nil, support == .afterwards || canTranscribeFile, hasRecording, let file {
            transcribeAfterwards(file)
            return
        }
        guard request != nil else { complete(); return }
        state = .finishing
        request?.endAudio()
        let id = generation
        // The recognizer usually answers within a moment; never wait on it for long.
        finishing = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard let self, self.generation == id, self.state == .finishing else { return }
            self.settle()
        }
    }

    /// The take as text once it has ended, with Apple's newer recognizer.
    private func transcribeAfterwards(_ file: URL) {
        state = .finishing
        let id = generation
        let language = language
        finishing = Task { [weak self] in
            var text = ""
            if #available(iOS 26.0, *) { text = (try? await Self.transcribe(file: file, language: language)) ?? "" }
            guard let self, self.generation == id, self.state == .finishing else { return }
            if !text.isEmpty { self.text = text }
            self.complete()
        }
    }

    @available(iOS 26.0, *)
    private static func transcribe(file: URL, language: String) async throws -> String {
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: language)) else { return "" }
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        do {
            try await analyzer.start(inputAudioFile: AVAudioFile(forReading: file), finishAfterFile: true)
            var parts: [String] = []
            for try await result in transcriber.results where result.isFinal {
                parts.append(String(result.text.characters))
            }
            await analyzer.cancelAndFinishNow()
            return parts.joined(separator: language.hasPrefix("zh") ? "" : " ")
        } catch {
            await analyzer.cancelAndFinishNow()
            throw error
        }
    }

    private func complete() {
        guard state == .listening || state == .finishing || state == .requesting else { return }
        if state == .listening { stopEngine(); if store.count > 0 { hasRecording = file != nil } }
        finishing?.cancel(); finishing = nil
        task?.cancel(); task = nil
        request = nil
        streamingCancel?(); streamingCancel = nil; streamingFinish = nil
        isFinal = true
        level = 0
        state = .ready
        WordAudioSession.release()
    }

    private func stopEngine() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
    }

    func togglePlayback() {
        if state == .playing { stopPlayback(); return }
        guard state == .ready, hasRecording else { return }
        #if DEBUG
        if simulated { state = .playing; return }
        #endif
        guard let file else { return }
        Task { [weak self] in
            do {
                try await WordAudioSession.activate(recording: false)
                guard let self, self.state == .ready else { return }
                let player = try AVAudioPlayer(contentsOf: file)
                player.delegate = self
                self.player = player
                if player.play() { self.state = .playing }
            } catch {
                self?.message = L.t("無法播放這段錄音。", "This recording could not play.")
            }
        }
    }

    func stopPlayback() {
        player?.stop(); player = nil
        if state == .playing { state = .ready }
    }

    func interrupt() {
        if state == .listening { stop() }
        if state == .playing { stopPlayback() }
    }

    /// Forgets the take and deletes its file.
    func clear() {
        generation = UUID()
        #if DEBUG
        simulation?.cancel(); simulation = nil
        #endif
        let hadAudio = busy || state == .playing
        recorder?.stop(); recorder = nil
        meter?.cancel(); meter = nil
        stopEngine()
        finishing?.cancel(); finishing = nil
        task?.cancel(); task = nil
        request = nil
        streamingCancel?(); streamingCancel = nil; streamingFinish = nil
        player?.stop(); player = nil
        if let file { try? FileManager.default.removeItem(at: file) }
        file = nil
        store.reset(rate: 0)
        text = ""; segments = []; isFinal = false; hasRecording = false; seconds = 0
        heardVoice = false; loudSince = nil; noiseFloor = -1
        message = nil; level = 0; state = .idle
        if hadAudio { WordAudioSession.release() }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in if self.player === player { self.stopPlayback() } }
    }

    private enum ListenError: Error { case noInput }

    #if DEBUG
    /// A pretend take for UI tests: the text arrives a piece at a time.
    private func simulate(_ id: UUID) {
        state = .listening
        level = 0.4
        seconds = 3
        let full = simulatedText ?? "I practice with my friend every day."
        let pieces: [String] = full.contains(where: { $0.unicodeScalars.contains { $0.value >= 0x4E00 } })
            ? full.map(String.init)
            : full.split(separator: " ").map(String.init)
        simulation = Task { [weak self] in
            var heard = ""
            for piece in pieces {
                try? await Task.sleep(for: .milliseconds(180))
                guard let self, !Task.isCancelled, self.generation == id else { return }
                heard += heard.isEmpty || pieces.count == full.count ? piece : " " + piece
                self.receive(text: heard, segments: nil, final: false)
            }
        }
    }
    #endif
}

/// Apple's newer on-device recognizer, fed while the learner speaks. Text
/// comes back as it is heard (volatile results) and settles as it goes;
/// each piece knows where it falls in the take, for pitch.
@available(iOS 26.0, *)
private final class StreamingTranscription: @unchecked Sendable {
    let transcriber: SpeechTranscriber
    private let analyzer: SpeechAnalyzer
    private let input: AsyncStream<AnalyzerInput>.Continuation
    /// What the recognizer takes; the microphone's audio is converted to it.
    private let format: AVAudioFormat?
    private let lock = NSLock()
    private var converter: AVAudioConverter?

    private init(transcriber: SpeechTranscriber, analyzer: SpeechAnalyzer,
                 input: AsyncStream<AnalyzerInput>.Continuation, format: AVAudioFormat?) {
        self.transcriber = transcriber
        self.analyzer = analyzer
        self.input = input
        self.format = format
    }

    /// Nil when this language's model is not on the phone.
    static func start(language: String) async throws -> StreamingTranscription? {
        guard SpeechTranscriber.isAvailable,
              let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: language)) else { return nil }
        let transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [],
                                            reportingOptions: [.volatileResults], attributeOptions: [.audioTimeRange])
        guard await AssetInventory.status(forModules: [transcriber]) == .installed else { return nil }
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        let (stream, input) = AsyncStream<AnalyzerInput>.makeStream()
        try await analyzer.start(inputSequence: stream)
        return StreamingTranscription(transcriber: transcriber, analyzer: analyzer, input: input, format: format)
    }

    /// From the audio thread: one buffer of the take.
    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock(); defer { lock.unlock() }
        // Always a copy: the engine reuses its buffers, the recognizer reads later.
        guard let converted = convert(buffer) else { return }
        input.yield(AnalyzerInput(buffer: converted))
    }

    func finish() async {
        input.finish()
        try? await analyzer.finalizeAndFinishThroughEndOfInput()
    }

    func cancel() {
        input.finish()
        let analyzer = analyzer
        Task { await analyzer.cancelAndFinishNow() }
    }

    private func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let target = format ?? buffer.format
        if converter == nil || converter?.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: target)
            converter?.primeMethod = .none
        }
        guard let converter, buffer.format.sampleRate > 0 else { return nil }
        let ratio = target.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return nil }
        var given = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if given { inputStatus.pointee = .noDataNow; return nil }
            given = true
            inputStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, output.frameLength > 0 else { return nil }
        return output
    }
}

/// Mono samples of a take, written from the audio thread.
private final class SampleStore: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Float] = []
    private var rate: Double = 0
    /// At most this long a take is kept for pitch.
    private let limit: TimeInterval = 30

    var count: Int { lock.withLock { values.count } }
    /// Seconds kept so far.
    var seconds: TimeInterval { lock.withLock { rate > 0 ? Double(values.count) / rate : 0 } }

    func reset(rate: Double) {
        lock.withLock {
            values = []
            values.reserveCapacity(Int(rate * 8))
            self.rate = rate
        }
    }

    /// Appends the first channel and returns the buffer's level, 0...1.
    func append(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        var sum: Float = 0
        for index in 0..<count { sum += channel[index] * channel[index] }
        let rms = count > 0 ? (sum / Float(count)).squareRoot() : 0
        lock.withLock {
            if Double(values.count) < rate * limit {
                values.append(contentsOf: UnsafeBufferPointer(start: channel, count: count))
            }
        }
        let decibels = 20 * log10(max(rms, 0.000_01))
        return max(0, min(1, (decibels + 50) / 50))
    }

    func snapshot() -> (values: [Float], rate: Double) {
        lock.withLock { (values, rate) }
    }
}
