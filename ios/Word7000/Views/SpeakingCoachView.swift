import SwiftUI
import UIKit
import AVFoundation
import Word7000Core

@MainActor
struct SpeakingCoachView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var answerFocused = false
    @State private var pendingSubmission = false
    @State private var inputCommitFailed = false
    @State private var submittedAnswer: String?
    @State private var recording = SpeakingRecorder()
    @Binding var needsTranscriptReview: Bool
    @State private var retakeOpen = false
    @State private var reflection: SpeakingReflection?
    @State private var helpful: Bool?

    let request: SpeakingCoach.Request
    let referenceAnswer: String
    let referenceTranslation: String
    @Binding var answer: String
    let session: SpeakingCoachSession

    private var provider: AppleSpeakingCoach { .shared }
    private static let feedbackAnchor = "coach-feedback"
    private var answerLanguage: String { request.mode == .english ? "en-US" : "zh-TW" }
    private var canSubmit: Bool {
        !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !pendingSubmission && !session.isBusy && !provider.isBusy
            && !recording.busy && !needsTranscriptReview
            && answer.count <= SpeakingCoach.maximumAnswerCharacters
    }

    /// The keyword and the question's longer words, which a learner's answer
    /// usually reuses; short function words need no help being recognized.
    private var transcriptionHints: [String] {
        var seen = Set<String>()
        let words = request.question.split(whereSeparator: { !$0.isLetter && $0 != "'" }).map(String.init)
        return ([request.keyword] + words.filter { $0.count >= 4 })
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
            .prefix(20).map { $0 }
    }

    /// The question read back is not an answer; say so before the AI would
    /// politely "improve" it.
    private var answerEchoesQuestion: Bool {
        SpeakingCoach.echoesQuestion(answer: answer, question: request.question)
    }

    /// Apple's server model sees the answer text, so the promise changes with it.
    private var privacyNote: String {
        provider.usesCloud
            ? L.t("錄音只留在這部手機，離開此頁便清除。取得建議時，回答文字會交給 Apple 的 Private Cloud Compute 處理，Apple 表示不會保存，也無法讀取。AI 建議可能有誤，不評分發音。系統鍵盤聽寫另依 Apple 設定，可能需要網路。",
                  "Recordings stay on this iPhone and are deleted when you leave this screen. For suggestions, your answer text is processed by Apple's Private Cloud Compute, which Apple says is not stored or accessible to it. AI suggestions may be wrong, and do not score pronunciation. System keyboard dictation follows Apple's settings and may use a network connection.")
            : L.t("錄音、回答與建議僅暫存於這次練習，離開此頁便清除錄音。App 不上傳音訊或回答。AI 建議可能有誤，不評分發音。系統鍵盤聽寫另依 Apple 設定，可能需要網路。",
                  "Recordings, answers and suggestions are temporary. Leaving this screen deletes the recording. The app does not upload audio or answers. AI suggestions may be wrong, and do not score pronunciation. System keyboard dictation follows Apple's settings and may use a network connection.")
    }

    /// After suggestions arrive, the same button asks again for the same answer.
    private var askedForThisAnswer: Bool { session.feedback != nil && submittedAnswer == answer }

    private var visibleFailure: String? {
        if inputCommitFailed {
            return L.t("輸入尚未完成，請再試一次。你的回答仍在。", "Editing did not finish. Try again; your answer is still here.")
        }
        return session.failure.map(failureMessage)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                coachForm
                    .onChange(of: session.feedback) { _, feedback in
                        // The suggestions arrive below the reference answer, often off screen.
                        guard feedback != nil else { return }
                        withAnimation(reduceMotion ? nil : Motion.reveal) { proxy.scrollTo(Self.feedbackAnchor, anchor: .top) }
                    }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { provider.refreshAvailability() }
        .onDisappear { pendingSubmission = false; session.cancel(); recording.clear(); Speaker.shared.stop() }
        .task { await recording.refresh(language: answerLanguage) }
        .task(id: answer) {
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            guard !Task.isCancelled else { return }
            guard answer.count <= SpeakingCoach.maximumAnswerCharacters else { reflection = nil; return }
            let text = answer, target = request.keyword, chinese = request.mode == .chinese
            let result = await Task.detached(priority: .utility) {
                SpeakingRecorder.reflection(answer: text, target: target, chinese: chinese)
            }.value
            guard !Task.isCancelled, answer == text else { return }
            reflection = result
        }
        .onChange(of: recording.transcript) { _, value in
            guard let value else { return }
            answer = value
            needsTranscriptReview = true
            session.reset()
        }
        .onChange(of: session.feedback) { _, _ in helpful = nil }
        .onChange(of: IntelligenceSettings.shared.coachAllowed) { _, _ in provider.refreshAvailability() }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in recording.interrupt() }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { event in
            if let raw = event.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
               AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable { recording.interrupt() }
        }
        .confirmationDialog(L.t("重新錄製會刪除上一段錄音", "A new take replaces the previous recording"), isPresented: $retakeOpen) {
            Button(L.t("重新錄製", "Record again"), role: .destructive) { beginRecording() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in
            finishInput(committedText: nil)
        }
        .task(id: pendingSubmission) {
            guard pendingSubmission else { return }
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            guard !Task.isCancelled, pendingSubmission else { return }
            pendingSubmission = false
            inputCommitFailed = true
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { provider.refreshAvailability() }
            else if phase == .background { pendingSubmission = false; session.cancel(); recording.interrupt(); Speaker.shared.stop() }
        }
        .onChange(of: provider.availability) { _, availability in
            if availability != .ready { pendingSubmission = false; session.cancel(clearFeedback: true) }
        }
        .sensoryFeedback(.success, trigger: session.feedback) { _, feedback in
            feedback != nil && (model.settings.hapticsEnabled ?? true)
        }
        .animation(reduceMotion ? nil : Motion.reveal, value: session.feedback != nil)
    }

    /// The form on its own keeps the body's modifier chain short enough to type-check.
    private var coachForm: some View {
        Form {
            Section {
                Text(request.keyword)
                    .font(.rounded(.headline)).foregroundStyle(Palette.accent)
                HStack(alignment: .top) {
                    Text(request.question).font(.headline).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("coach-question")
                    Spacer(minLength: 8)
                    SpeakButton(text: request.question, language: "en-US")
                        .disabled(recording.busy)
                }
            }

            recordingSection
            answerSection
            if let reflection, !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section {
                    if answerEchoesQuestion {
                        // The keyword is in the question, so finding it here proves nothing.
                        Label(L.t("這段和題目幾乎一樣，像是把題目念了一遍", "This is almost the same as the question"),
                              systemImage: "exclamationmark.circle")
                            .foregroundStyle(Palette.review)
                            .accessibilityIdentifier("coach-echo")
                    } else {
                        Label(reflection.containsTarget
                              ? L.t("找到目標詞：\(request.keyword)", "Target found: \(request.keyword)")
                              : L.t("尚未找到目標詞：\(request.keyword)", "Target not found: \(request.keyword)"),
                              systemImage: reflection.containsTarget ? "checkmark.circle" : "circle.dashed")
                    }
                    LabeledContent(L.t("句數（約）", "Sentences (approx.)"), value: "\(reflection.sentenceCount)")
                    LabeledContent(request.mode == .english ? L.t("字數", "Words") : L.t("字元數", "Characters"), value: "\(reflection.unitCount)")
                } header: { Text(L.t("回答檢視", "Your answer at a glance")) }
                footer: { Text(L.t("找到詞語不代表用法或發音正確，也不影響學習成績。", "Finding a word does not verify usage or pronunciation, and does not change your progress.")) }
            }
            if !referenceAnswer.isEmpty {
                Section {
                    DisclosureGroup(L.t("參考回答", "Reference answer")) {
                        HStack(alignment: .top) {
                            Text(referenceAnswer).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            SpeakButton(text: referenceAnswer, language: answerLanguage).disabled(recording.busy)
                        }
                        Text(referenceTranslation).font(.subheadline).foregroundStyle(.secondary)
                    }.accessibilityIdentifier("coach-reference")
                }
            }
            if provider.availability == .ready {
                if let message = visibleFailure {
                    Section {
                        HStack(alignment: .top) {
                            Image(systemName: "exclamationmark.circle").accessibilityHidden(true)
                            Text(message)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("coach-error")
                        }
                        .foregroundStyle(Palette.miss)
                    }
                }
                if let feedback = session.feedback {
                    feedbackSections(feedback)
                }
            } else {
                unavailableSection
            }

            Section {
                Label(provider.usesCloud ? L.t("錄音留在這部手機", "Recordings stay on this iPhone")
                      : L.t("錄音與回答留在這部手機", "Recordings and answers stay on this iPhone"), systemImage: "hand.raised")
                    .font(.footnote).foregroundStyle(.secondary)
            } footer: {
                Text(privacyNote)
            }
        }
        .accessibilityIdentifier("coach-form")
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.background)
        .navigationTitle(L.t("口說教練", "Speaking coach"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { close() } label: { Image(systemName: "xmark") }
                    .accessibilityLabel(L.close)
                    .accessibilityIdentifier("coach-close")
            }
            ToolbarItem(placement: .topBarTrailing) {
                if answerFocused {
                    Button { dismissKeyboard() } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                    }
                    .accessibilityLabel(L.t("收起鍵盤", "Dismiss keyboard"))
                    .accessibilityIdentifier("coach-keyboard-done")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if provider.availability == .ready { actions }
        }
    }

    private var answerSection: some View {
        Section {
            PracticeAnswerEditor(text: $answer, focused: $answerFocused,
                                 editable: recording.state != .recording && recording.state != .transcribing,
                                 onEdit: { text in
                                     if text != submittedAnswer { session.reset() }
                                     inputCommitFailed = false
                                     Speaker.shared.stop()
                                 }, onCommit: { finishInput(committedText: $0) },
                                 committedOverride: {
                                     #if DEBUG
                                     return pendingSubmission ? provider.testingCommittedAnswer : nil
                                     #else
                                     return nil
                                     #endif
                                 })
                .frame(minHeight: 120, maxHeight: 220)
                .overlay(alignment: .topLeading) {
                    if answer.isEmpty {
                        // UITextView has no placeholder; match its default text insets.
                        Text(request.mode == .english
                             ? L.t("用英文回答，或先錄音再轉成文字", "Answer in English, or record and transcribe")
                             : L.t("用中文回答，或先錄音再轉成文字", "Answer in Chinese, or record and transcribe"))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8).padding(.leading, 5)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel(L.t("你的回答", "Your answer"))
                .accessibilityIdentifier("coach-answer")
            if needsTranscriptReview {
                Text(L.t("先確認辨識文字，必要時可直接修改。", "Review the transcript and edit any misheard words."))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if answer.count > SpeakingCoach.maximumAnswerCharacters {
                Text(L.t("請將回答精簡至 600 字以內再取得建議。", "Shorten your answer to 600 characters before requesting suggestions."))
                    .font(.footnote).foregroundStyle(Palette.miss)
            }
            HStack {
                Spacer()
                Text("\(answer.count) / \(SpeakingCoach.maximumAnswerCharacters)")
                    .font(.caption).monospacedDigit()
                    .foregroundStyle(answer.count > SpeakingCoach.maximumAnswerCharacters ? Palette.miss : Palette.secondaryLabel)
            }
        } header: {
            Text(L.t("你的回答", "Your answer"))
        }
    }

    @ViewBuilder
    private func feedbackSections(_ feedback: SpeakingCoach.Feedback) -> some View {
        if !feedback.corrections.isEmpty {
            Section {
                ForEach(Array(feedback.corrections.enumerated()), id: \.offset) { offset, correction in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(correction.original).foregroundStyle(.secondary)
                        Label(correction.replacement, systemImage: "arrow.turn.down.right").foregroundStyle(Palette.accent)
                        Text(correction.reason).font(.subheadline)
                    }.textSelection(.enabled)
                    // Scroll targets are rows; a Section's own id is not reliably one.
                    .id(offset == 0 ? Self.feedbackAnchor : "coach-correction-\(offset)")
                }
            } header: { Text(L.t("可留意的地方", "Suggestions to consider")) }
            footer: { Text(L.t("這是 AI 建議，不是標準答案。", "AI suggestions, not an answer key.")) }
        }
        Section {
            HStack(alignment: .top) {
                Text(feedback.rewrite).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("coach-rewrite")
                Spacer(minLength: 8)
                SpeakButton(text: feedback.rewrite, language: answerLanguage)
                    .disabled(recording.busy)
            }
            .id(feedback.corrections.isEmpty ? Self.feedbackAnchor : "coach-rewrite")
        } header: { Text(L.t("更自然的說法", "A natural rewrite")) }
        Section {
            Text(feedback.tip).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("coach-tip")
        } header: { Text(L.t("一個小提示", "One tip")) }
        Section {
            HStack(alignment: .top) {
                Text(feedback.followUp).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("coach-follow-up")
                Spacer(minLength: 8)
                SpeakButton(text: feedback.followUp, language: answerLanguage)
                    .disabled(recording.busy)
            }
        } header: { Text(L.t("再想一想", "A follow-up")) }
        Section {
            HStack {
                Text(L.t("這次建議有幫助嗎？", "Was this helpful?"))
                Spacer()
                Button { helpful = true } label: { Image(systemName: helpful == true ? "hand.thumbsup.fill" : "hand.thumbsup") }
                    .accessibilityLabel(L.t("有幫助", "Helpful"))
                Button { helpful = false } label: { Image(systemName: helpful == false ? "hand.thumbsdown.fill" : "hand.thumbsdown") }
                    .accessibilityLabel(L.t("沒有幫助", "Not helpful"))
            }.buttonStyle(.borderless)
        } footer: { Text(L.t("回饋僅保留在本次畫面，不會傳送回答。", "Feedback stays in this screen. Your answer is not sent anywhere.")) }
    }

    private var actions: some View {
        VStack(spacing: 8) {
            if session.isWorking || pendingSubmission {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(pendingSubmission ? L.t("正在完成輸入…", "Finishing input…")
                         : L.t("正在整理建議…", "Preparing suggestions…")).font(.subheadline)
                }
                Button { pendingSubmission = false; session.cancel() } label: {
                    Label(L.t("取消", "Cancel"), systemImage: "stop.fill").frame(maxWidth: .infinity)
                }
                .secondaryAction()
                .accessibilityIdentifier("coach-cancel")
            } else {
                if session.isBusy || provider.isBusy {
                    Text(L.t("正在結束上一個請求…", "Finishing the previous request…"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                // Lives in the bar, not below the answer: on small iPhones the
                // answer section ends under this bar, hiding the one control
                // that unlocks suggestions.
                if needsTranscriptReview {
                    Button { needsTranscriptReview = false } label: {
                        Label(L.t("辨識文字已確認", "Transcript checked"), systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .secondaryAction()
                    .accessibilityIdentifier("coach-confirm-transcript")
                }
                Button { submit() } label: {
                    Label(askedForThisAnswer ? L.t("再給一次建議", "Suggest again") : L.t("取得建議", "Get suggestions"),
                          systemImage: askedForThisAnswer ? "arrow.clockwise" : "sparkles").frame(maxWidth: .infinity)
                }
                .prominentAction()
                .disabled(!canSubmit)
                .accessibilityIdentifier("coach-submit")
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, 10)
        .background(.bar)
    }

    /// Most learners' iPhones cannot run Apple Intelligence at all, and some
    /// turned suggestions off themselves. Neither is a temporary problem, so
    /// neither gets a "check again" button or an alarming header.
    private var unavailableIsSettled: Bool {
        provider.availability == .unsupported || (provider.availability == .paused && !IntelligenceSettings.shared.enabled)
    }

    private var unavailableSection: some View {
        Section {
            HStack(alignment: .top) {
                Image(systemName: "info.circle").accessibilityHidden(true)
                Text(unavailableMessage)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("coach-unavailable")
            }
            if !unavailableIsSettled { checkAgainButton }
        } header: {
            Text(unavailableIsSettled ? L.t("AI 建議", "AI suggestions") : L.t("暫時無法提供建議", "Suggestions unavailable"))
        }
    }

    @ViewBuilder
    private var checkAgainButton: some View {
        Button {
            Task {
                await IntelligenceSettings.shared.refreshPolicy(force: true)
                provider.refreshAvailability()
            }
        } label: {
            Label(L.t("再次檢查", "Check again"), systemImage: "arrow.clockwise")
        }
        .disabled(IntelligenceSettings.shared.checking)
        .accessibilityIdentifier("coach-check-again")
        if IntelligenceSettings.shared.checking { ProgressView() }
    }

    private var unavailableMessage: String {
        switch provider.availability {
        case .unsupported:
            L.t("這部 iPhone 不支援 Apple Intelligence，所以不會有 AI 建議。錄音、回放、轉成文字和回答檢視都能照常使用。",
                "This iPhone does not support Apple Intelligence, so there are no AI suggestions. Recording, playback, transcription and the answer check all still work.")
        case .paused where !IntelligenceSettings.shared.enabled:
            L.t("你已關閉 AI 建議，可在「設定 → AI 與錄音」重新開啟。錄音與文字檢視仍可使用。",
                "You turned AI suggestions off. Turn them back on in Settings → AI and recording. Recording and the answer check still work.")
        case .paused:
            L.t("AI 建議目前已關閉。錄音、文字檢視與原本的練習仍可使用。", "AI suggestions are currently off. Recording, text reflection and regular practice still work.")
        case .disabled:
            L.t("請在系統設定中開啟 Apple Intelligence，再回來檢查。原本的口說練習仍可使用。", "Turn on Apple Intelligence in Settings, then check again. Your regular speaking practice still works.")
        case .preparing:
            L.t("Apple Intelligence 的裝置模型尚未準備完成，請稍後再檢查。原本的口說練習仍可使用。", "The Apple Intelligence on-device model is not ready yet. Check again later. Your regular speaking practice still works.")
        case .unsupportedLanguage:
            L.t("這個裝置模型目前未同時支援英文與繁體中文。原本的口說練習仍可使用。", "This on-device model does not currently support both English and Traditional Chinese. Your regular speaking practice still works.")
        default:
            L.t("這部裝置目前無法使用 Apple Intelligence 建議。原本的口說練習仍可使用。", "Apple Intelligence suggestions are currently unavailable on this device. Your regular speaking practice still works.")
        }
    }

    private func failureMessage(_ failure: SpeakingCoach.Failure) -> String {
        switch failure {
        case .emptyAnswer: L.t("請先輸入回答。", "Enter an answer first.")
        case .echoesQuestion:
            request.mode == .english
                ? L.t("這段回答和題目幾乎一樣，像是把題目念了一遍。試著回答它，例如用「I would…」或「I think…」開頭。",
                      "This is almost the same as the question. Try answering it, starting with \"I would…\" or \"I think…\".")
                : L.t("這段回答和題目幾乎一樣，像是把題目念了一遍。試著用自己的話回答它。",
                      "This is almost the same as the question. Try answering it in your own words.")
        case .tooLong: L.t("回答或題目背景太長。請縮短回答，或改用背景較短的題目再試。", "The answer or question context is too long. Shorten your answer or try a question with less context.")
        case .busy: L.t("上一個請求尚未結束，請稍候再試。", "The previous request is still finishing. Try again shortly.")
        case .timedOut: L.t("這次等候太久，請再試一次。你的回答仍在。", "This took too long. Try again; your answer is still here.")
        case .unavailable: L.t("裝置上的建議暫時無法使用，請稍後再試。", "On-device suggestions are temporarily unavailable. Try again later.")
        case .invalidFeedback, .wrongLanguage, .generationFailed: L.t("這次未能產生合適的建議，請調整回答或再試一次。", "No suitable suggestions were produced. Edit your answer or try again.")
        }
    }

    private func submit() {
        guard canSubmit else { return }
        inputCommitFailed = false
        Speaker.shared.stop()
        if answerFocused {
            pendingSubmission = true
            dismissKeyboard()
        } else {
            generateSuggestions()
        }
    }

    private func finishInput(committedText: String?) {
        guard pendingSubmission else { return }
        pendingSubmission = false
        if let committedText { answer = committedText }
        generateSuggestions()
    }

    private func generateSuggestions() {
        provider.refreshAvailability()
        guard provider.availability == .ready, canSubmit else { return }
        submittedAnswer = answer
        let submitted = SpeakingCoach.Request(keyword: request.keyword, meaning: request.meaning,
            question: request.question, context: request.context, answer: answer, mode: request.mode)
        #if DEBUG
        if let timeout = provider.testingTimeout { session.submit(submitted, timeout: timeout); return }
        #endif
        session.submit(submitted)
    }

    private func close() {
        pendingSubmission = false
        dismissKeyboard()
        session.cancel()
        recording.clear()
        Speaker.shared.stop()
        dismiss()
    }

    private var recordingSection: some View {
        Section {
            HStack {
                // A status row, not a control: only the buttons below use the accent colour.
                Label(L.t("錄音", "Recording"), systemImage: recording.state == .recording ? "mic.fill" : "waveform")
                    .foregroundStyle(recording.state == .recording ? Palette.miss : Color.primary)
                Spacer()
                Text("\(Int(recording.seconds)) / 60 \(L.t("秒", "s"))").monospacedDigit().foregroundStyle(.secondary)
                    .accessibilityIdentifier("coach-recording-duration")
            }
            if recording.state == .recording {
                ProgressView(value: Double(recording.level)).tint(Palette.miss)
                    .accessibilityLabel(L.t("麥克風音量", "Microphone level"))
            }
            HStack {
                Button {
                    if recording.state == .recording { recording.stop() }
                    else if recording.hasRecording { retakeOpen = true }
                    else { beginRecording() }
                } label: {
                    Label(recording.state == .recording ? L.t("停止", "Stop")
                          : recording.hasRecording ? L.t("重錄", "Record again") : L.t("錄一段", "Record"),
                          systemImage: recording.state == .recording ? "stop.fill" : "mic.fill")
                }
                .disabled(recording.busy && recording.state != .recording || session.isBusy)
                .accessibilityIdentifier("coach-record")
                Spacer()
                if recording.hasRecording {
                    Button { recording.togglePlayback() } label: {
                        Label(recording.state == .playing ? L.t("停止回放", "Stop playback") : L.t("回放", "Play"),
                              systemImage: recording.state == .playing ? "stop.fill" : "play.fill")
                    }.disabled(recording.busy && recording.state != .playing)
                        .accessibilityIdentifier("coach-play-recording")
                    Button { recording.clear() } label: { Image(systemName: "trash") }
                        .disabled(recording.busy)
                        .accessibilityLabel(L.t("刪除錄音", "Delete recording"))
                }
            }.buttonStyle(.borderless)
            if recording.state == .transcribing || recording.state == .downloading || recording.state == .requesting {
                HStack {
                    ProgressView()
                    Text(recording.state == .downloading ? L.t("下載語言中…", "Downloading language…") : L.t("處理中…", "Processing…"))
                    Spacer()
                    Button(L.t("取消", "Cancel")) { recording.interrupt() }
                }
            } else if recording.support == .download {
                Button { recording.downloadLanguage() } label: {
                    Label(L.t("下載離線辨識語言", "Download transcription language"), systemImage: "arrow.down.circle")
                }
                Text(L.t("會向 Apple 下載語言資料，不會上傳錄音。", "Downloads language assets from Apple, without uploading your recording."))
                    .font(.footnote).foregroundStyle(.secondary)
            } else if recording.hasRecording && (recording.support == .modern || recording.support == .legacy) {
                Button { recording.transcribe(hints: transcriptionHints) } label: {
                    Label(L.t("轉成文字", "Transcribe"), systemImage: "text.bubble")
                }.disabled(recording.busy || session.isBusy)
                    .accessibilityIdentifier("coach-transcribe")
            } else if recording.support == .unavailable {
                Text(L.t("這部手機目前沒有可用的離線辨識。仍可錄音回放或自行輸入。", "Offline transcription is unavailable on this iPhone. You can still record, replay or type."))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let message = recording.message {
                Text(message).font(.footnote).foregroundStyle(Palette.miss)
                if recording.messageNeedsSettings {
                    Button(L.t("系統設定", "System Settings")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
            }
        } header: { Text(L.t("這次練習", "This take")) }
    }

    private func beginRecording() {
        pendingSubmission = false
        dismissKeyboard()
        session.cancel()
        Speaker.shared.stop()
        recording.start()
    }

    private func dismissKeyboard() {
        answerFocused = false
        // End the native edit as well: FocusState alone can leave a sheet's
        // TextEditor as first responder during a toolbar/layout update.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                       to: nil, from: nil, for: nil)
    }
}
