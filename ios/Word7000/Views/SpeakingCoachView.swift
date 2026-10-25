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
    @State private var askCloud = false
    @State private var inputCommitFailed = false
    @State private var submittedAnswer: String?
    @State private var recording = SpeakingRecorder()
    @Binding var needsTranscriptReview: Bool
    @State private var retakeOpen = false
    @State private var reflection: SpeakingReflection?
    /// The coach's follow-up, once the learner chose to answer it here.
    @State private var followUpQuestion: String?
    @State private var scrollToTop = 0

    let request: SpeakingCoach.Request
    let referenceAnswer: String
    let referenceTranslation: String
    @Binding var answer: String
    let session: SpeakingCoachSession

    private var provider: AppleSpeakingCoach { .shared }
    private static let feedbackAnchor = "coach-feedback"
    private static let topAnchor = "coach-top"
    /// The question being answered: the card's, or the coach's follow-up.
    private var question: String { followUpQuestion ?? request.question }
    private var answerLanguage: String { request.mode == .english ? "en-US" : "zh-TW" }
    /// Ready to send, apart from confirming a transcript, which sending does.
    private var canSubmitAnswer: Bool {
        !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !pendingSubmission && !session.isBusy && !provider.isBusy
            && !recording.busy
            && answer.count <= SpeakingCoach.maximumAnswerCharacters
    }

    /// The keyword and the question's longer words, which a learner's answer
    /// usually reuses; short function words need no help being recognized.
    private var transcriptionHints: [String] {
        var seen = Set<String>()
        let words = question.split(whereSeparator: { !$0.isLetter && $0 != "'" }).map(String.init)
        return ([request.keyword] + words.filter { $0.count >= 4 })
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
            .prefix(20).map { $0 }
    }

    /// The question read back is not an answer; say so before the AI would
    /// politely "improve" it.
    private var answerEchoesQuestion: Bool {
        SpeakingCoach.echoesQuestion(answer: answer, question: question)
    }

    /// Apple's server model sees the answer text, so the promise changes with it.
    private var privacyNote: String {
        if provider.usesOnline, IntelligenceSettings.shared.cloudConsent == true {
            return L.t("錄音只留在這部手機，離開即刪除。取得建議時，回答文字會傳送到 Groq 的線上 AI 處理。AI 建議可能有誤，也不評分發音。",
                       "Recordings stay on this iPhone and are deleted when you leave. For suggestions, your answer text is sent to Groq's online AI. AI suggestions may be wrong and do not score pronunciation.")
        }
        return provider.usesCloud
            ? L.t("錄音只留在這部手機，離開即刪除。取得建議時，回答文字交給 Apple 的 Private Cloud Compute 處理，Apple 表示不會保存。AI 建議可能有誤，也不評分發音。",
                  "Recordings stay on this iPhone and are deleted when you leave. For suggestions, your answer text goes to Apple's Private Cloud Compute, which Apple says is not stored. AI suggestions may be wrong and do not score pronunciation.")
            : L.t("錄音與回答只留在這部手機，離開即刪除錄音。AI 建議可能有誤，也不評分發音。鍵盤聽寫依 Apple 設定，可能需要網路。",
                  "Recordings and answers stay on this iPhone; leaving deletes the recording. AI suggestions may be wrong and do not score pronunciation. Keyboard dictation follows Apple's settings and may use the network.")
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
                    .onChange(of: scrollToTop) { _, _ in
                        withAnimation(reduceMotion ? nil : Motion.reveal) { proxy.scrollTo(Self.topAnchor, anchor: .top) }
                    }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { provider.refreshAvailability() }
        .cloudConsentAlert(isPresented: $askCloud) { provider.refreshAvailability(); generateSuggestions() }
        .onDisappear {
            pendingSubmission = false; session.cancel(); recording.clear(); Speaker.shared.stop()
            // The draft is kept for the card's question; a follow-up answer would reopen under it.
            if followUpQuestion != nil { answer = ""; needsTranscriptReview = false }
        }
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
        .onChange(of: recording.state) { old, new in
            // Stopping a take is when the learner wants to see it as text; a
            // typed or edited answer is never replaced without asking.
            guard old == .recording, new == .ready, recording.support == .modern || recording.support == .legacy,
                  answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || answer == recording.transcript else { return }
            recording.transcribe(hints: transcriptionHints)
        }
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
            questionSection
            answerSection
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
            // After the learner's own attempt and the coach, not before: a model
            // answer read first gets repeated instead of answered. The card's
            // answer does not fit a follow-up.
            if !referenceAnswer.isEmpty && followUpQuestion == nil {
                Section {
                    DisclosureGroup(L.t("參考回答", "Reference answer")) {
                        HStack(alignment: .top) {
                            Text(referenceAnswer).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            SpeakButton(text: referenceAnswer, language: answerLanguage).disabled(recording.busy)
                        }
                        Text(referenceTranslation).font(.subheadline).foregroundStyle(.secondary)
                    }.accessibilityIdentifier("coach-reference")
                } footer: { Text(privacyNote) }
            } else {
                Section {} footer: { Text(privacyNote) }
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

    private var questionSection: some View {
        Section {
            HStack {
                Text(request.keyword)
                    .font(.rounded(.headline)).foregroundStyle(Palette.accent)
                if followUpQuestion != nil {
                    Spacer()
                    Text(L.t("接續提問", "Follow-up")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            .id(Self.topAnchor)
            HStack(alignment: .top) {
                Text(question).font(.headline).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("coach-question")
                Spacer(minLength: 8)
                // A follow-up comes from the coach in the practiced language.
                SpeakButton(text: question, language: followUpQuestion == nil ? "en-US" : answerLanguage)
                    .disabled(recording.busy)
            }
            if followUpQuestion != nil {
                Button { answerFollowUp(nil) } label: {
                    Label(L.t("回到原來的題目", "Back to the original question"), systemImage: "arrow.uturn.backward")
                }
                .disabled(recording.busy || session.isBusy)
                .accessibilityIdentifier("coach-original-question")
            }
        }
    }

    private func answerSummary(_ reflection: SpeakingReflection) -> String {
        let used = reflection.containsTarget
            ? L.t("用到 \(request.keyword)", "Used \(request.keyword)")
            : L.t("還沒用到 \(request.keyword)", "\(request.keyword) not used yet")
        let size = request.mode == .english
            ? L.t("\(reflection.unitCount) 個字", reflection.unitCount == 1 ? "1 word" : "\(reflection.unitCount) words")
            : L.t("\(reflection.unitCount) 個字元", reflection.unitCount == 1 ? "1 character" : "\(reflection.unitCount) characters")
        let sentences = L.t("約 \(reflection.sentenceCount) 句", reflection.sentenceCount == 1 ? "about 1 sentence" : "about \(reflection.sentenceCount) sentences")
        return "\(used) · \(size) · \(sentences)"
    }

    /// The rewrite with what it changed highlighted, and the learner's own
    /// words below with what it replaced struck through, so the lesson is
    /// visible without comparing two sentences by eye.
    @ViewBuilder
    private func rewriteRow(_ feedback: SpeakingCoach.Feedback, id: String) -> some View {
        let comparison = SpeakingCoach.comparison(answer: submittedAnswer ?? answer, rewrite: feedback.rewrite)
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L.t("更自然的說法", "More natural")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(comparison.map { highlighted($0.rewrite, removed: false) } ?? AttributedString(feedback.rewrite))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("coach-rewrite")
            }
            Spacer(minLength: 8)
            SpeakButton(text: feedback.rewrite, language: answerLanguage)
                .disabled(recording.busy)
        }
        .id(id)
        if let comparison, comparison.answer.contains(where: \.changed) || comparison.rewrite.contains(where: \.changed) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L.t("你的說法", "You said")).font(.caption).foregroundStyle(.secondary)
                Text(highlighted(comparison.answer, removed: true))
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("coach-your-words")
        }
    }

    private func highlighted(_ pieces: [SpeakingCoach.Piece], removed: Bool) -> AttributedString {
        pieces.reduce(into: AttributedString()) { result, piece in
            var part = AttributedString(piece.text)
            if piece.changed {
                if removed {
                    part.swiftUI.strikethroughStyle = .single
                    part.swiftUI.foregroundColor = Palette.miss
                } else {
                    part.swiftUI.foregroundColor = Palette.accent
                    part.swiftUI.font = .body.weight(.semibold)
                }
            }
            result += part
        }
    }

    /// Answering the follow-up turns one reply into a short conversation. Nil
    /// returns to the card's own question.
    private func answerFollowUp(_ followUp: String?) {
        pendingSubmission = false
        dismissKeyboard()
        Speaker.shared.stop()
        recording.clear()
        session.reset()
        submittedAnswer = nil
        needsTranscriptReview = false
        inputCommitFailed = false
        answer = ""
        followUpQuestion = followUp
        scrollToTop += 1
    }

    /// The answer and the take that produced it live in one card: record,
    /// replay and edit happen in the same place.
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
                .frame(minHeight: 96, maxHeight: 200)
                .overlay(alignment: .topLeading) {
                    if answer.isEmpty {
                        // UITextView has no placeholder; match its default text insets.
                        Text(request.mode == .english
                             ? L.t("按錄音說出你的回答，或直接用英文輸入", "Tap Record and say your answer, or type it in English")
                             : L.t("按錄音說出你的回答，或直接用中文輸入", "Tap Record and say your answer, or type it in Chinese"))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8).padding(.leading, 5)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel(L.t("你的回答", "Your answer"))
                .accessibilityIdentifier("coach-answer")
            recorderControls
            recorderStatus
            if needsTranscriptReview {
                Label(L.t("這是語音辨識的文字，送出前看看有沒有聽錯的字。", "This is a transcript. Check for misheard words before sending."),
                      systemImage: "text.magnifyingglass")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let reflection, !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if answerEchoesQuestion {
                    // The keyword is in the question, so finding it here proves nothing.
                    Label(L.t("這段和題目幾乎一樣，像是把題目念了一遍", "This is almost the same as the question"),
                          systemImage: "exclamationmark.circle")
                        .font(.footnote).foregroundStyle(Palette.review)
                        .accessibilityIdentifier("coach-echo")
                } else {
                    Label(answerSummary(reflection),
                          systemImage: reflection.containsTarget ? "checkmark.circle" : "circle.dashed")
                        .font(.footnote).foregroundStyle(reflection.containsTarget ? Palette.known : Color.secondary)
                        .accessibilityIdentifier("coach-answer-check")
                }
            }
            if answer.count > SpeakingCoach.maximumAnswerCharacters {
                Text(L.t("請將回答精簡至 600 字以內再取得建議。", "Shorten your answer to 600 characters before requesting suggestions."))
                    .font(.footnote).foregroundStyle(Palette.miss)
            }
        } header: {
            HStack {
                Text(L.t("你的回答", "Your answer"))
                Spacer()
                // Only worth a glance near the limit.
                if answer.count > SpeakingCoach.maximumAnswerCharacters - 100 {
                    Text("\(answer.count) / \(SpeakingCoach.maximumAnswerCharacters)").monospacedDigit()
                        .foregroundStyle(answer.count > SpeakingCoach.maximumAnswerCharacters ? Palette.miss : Palette.secondaryLabel)
                }
            }
        }
    }

    private var recorderControls: some View {
        HStack(spacing: 16) {
            Button {
                if recording.state == .recording { recording.stop() }
                else if recording.hasRecording { retakeOpen = true }
                else { beginRecording() }
            } label: {
                Label(recording.state == .recording ? L.t("停止", "Stop")
                      : recording.hasRecording ? L.t("重錄", "Record again") : L.t("錄音", "Record"),
                      systemImage: recording.state == .recording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.headline)
                    .foregroundStyle(recording.state == .recording ? Palette.miss : Palette.accent)
            }
            .disabled(recording.busy && recording.state != .recording || session.isBusy)
            .accessibilityIdentifier("coach-record")
            if recording.state == .recording || recording.hasRecording {
                Text("\(Int(recording.seconds)) / 60 \(L.t("秒", "s"))").font(.subheadline).monospacedDigit()
                    .foregroundStyle(recording.state == .recording ? Palette.miss : Color.secondary)
                    .accessibilityIdentifier("coach-recording-duration")
            }
            Spacer()
            if recording.hasRecording {
                Button { recording.togglePlayback() } label: {
                    Label(recording.state == .playing ? L.t("停止回放", "Stop playback") : L.t("回放", "Play"),
                          systemImage: recording.state == .playing ? "stop.fill" : "play.fill")
                        .labelStyle(.iconOnly)
                }
                .disabled(recording.busy && recording.state != .playing)
                .accessibilityIdentifier("coach-play-recording")
                Button { recording.clear() } label: { Image(systemName: "trash") }
                    .disabled(recording.busy)
                    .accessibilityLabel(L.t("刪除錄音", "Delete recording"))
            }
        }
        .buttonStyle(.borderless)
    }

    /// Only what needs the learner: a level while recording, progress, a
    /// way to transcribe when it did not happen on its own, and problems.
    @ViewBuilder
    private var recorderStatus: some View {
        if recording.state == .recording {
            ProgressView(value: Double(recording.level)).tint(Palette.miss)
                .accessibilityLabel(L.t("麥克風音量", "Microphone level"))
        }
        if recording.state == .transcribing || recording.state == .downloading || recording.state == .requesting {
            HStack {
                ProgressView()
                Text(recording.state == .downloading ? L.t("下載語言中…", "Downloading language…")
                     : recording.state == .transcribing ? L.t("轉成文字中…", "Transcribing…") : L.t("處理中…", "Processing…"))
                    .font(.subheadline)
                Spacer()
                Button(L.t("取消", "Cancel")) { recording.interrupt() }.buttonStyle(.borderless)
            }
        } else if recording.support == .download && recording.hasRecording {
            Button { recording.downloadLanguage() } label: {
                Label(L.t("下載離線辨識，把錄音轉成文字", "Download offline transcription"), systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderless)
        } else if recording.hasRecording, recording.transcript == nil,
                  recording.support == .modern || recording.support == .legacy {
            // Stopping a take transcribes it; this is for a take that would
            // have replaced a typed answer, or a failed attempt.
            Button { recording.transcribe(hints: transcriptionHints) } label: {
                Label(answer.isEmpty ? L.t("轉成文字", "Transcribe") : L.t("轉成文字（取代目前的回答）", "Transcribe (replaces your answer)"),
                      systemImage: "text.bubble")
            }
            .buttonStyle(.borderless)
            .disabled(recording.busy || session.isBusy)
            .accessibilityIdentifier("coach-transcribe")
        } else if recording.support == .unavailable && recording.hasRecording {
            Text(L.t("這部手機沒有離線辨識，可以回放後自己輸入。", "No offline transcription on this iPhone. Replay and type your answer."))
                .font(.footnote).foregroundStyle(.secondary)
        }
        if let message = recording.message {
            Text(message).font(.footnote).foregroundStyle(Palette.miss)
            if recording.messageNeedsSettings {
                Button(L.t("系統設定", "System Settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .buttonStyle(.borderless)
            }
        }
    }

    /// One card of suggestions, then one way to keep going. The corrections,
    /// the rewrite and the tip are a single lesson, so they share a card.
    @ViewBuilder
    private func feedbackSections(_ feedback: SpeakingCoach.Feedback) -> some View {
        Section {
            ForEach(Array(feedback.corrections.enumerated()), id: \.offset) { offset, correction in
                VStack(alignment: .leading, spacing: 4) {
                    Text(correctionLine(correction))
                    Text(correction.reason).font(.subheadline).foregroundStyle(.secondary)
                }
                .textSelection(.enabled)
                // Scroll targets are rows; a Section's own id is not reliably one.
                .id(offset == 0 ? Self.feedbackAnchor : "coach-correction-\(offset)")
            }
            rewriteRow(feedback, id: feedback.corrections.isEmpty ? Self.feedbackAnchor : "coach-rewrite")
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "lightbulb").foregroundStyle(Palette.review).accessibilityHidden(true)
                Text(feedback.tip).font(.subheadline).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("coach-tip")
            }
        } header: { Label(L.t("AI 建議", "AI suggestions"), systemImage: "sparkles") }
        Section {
            HStack(alignment: .top) {
                Text(feedback.followUp).font(.headline).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("coach-follow-up")
                Spacer(minLength: 8)
                SpeakButton(text: feedback.followUp, language: answerLanguage)
                    .disabled(recording.busy)
            }
            Button { answerFollowUp(feedback.followUp) } label: {
                Label(L.t("回答這題", "Answer this"), systemImage: "arrowshape.turn.up.left")
            }
            .disabled(recording.busy || session.isBusy)
            .accessibilityIdentifier("coach-answer-follow-up")
        } header: { Text(L.t("接著練", "Keep going")) }
    }

    /// "original → replacement", the original struck through.
    private func correctionLine(_ correction: SpeakingCoach.Correction) -> AttributedString {
        var original = AttributedString(correction.original)
        original.swiftUI.strikethroughStyle = .single
        original.swiftUI.foregroundColor = .secondary
        var replacement = AttributedString(correction.replacement)
        replacement.swiftUI.foregroundColor = Palette.accent
        replacement.swiftUI.font = .body.weight(.semibold)
        return original + AttributedString("  →  ") + replacement
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
                // One button. A fresh transcript is confirmed by sending it,
                // so no extra step; the label says the text is being accepted.
                Button {
                    guard canSubmitAnswer else { return }
                    needsTranscriptReview = false
                    submit()
                } label: {
                    Label(needsTranscriptReview ? L.t("文字沒問題，取得建議", "Looks right, get suggestions")
                          : askedForThisAnswer ? L.t("再給一次建議", "Suggest again") : L.t("取得建議", "Get suggestions"),
                          systemImage: askedForThisAnswer && !needsTranscriptReview ? "arrow.clockwise" : "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .prominentAction()
                .disabled(!canSubmitAnswer)
                .accessibilityIdentifier(needsTranscriptReview ? "coach-confirm-transcript" : "coach-submit")
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
        case .unavailable: L.t("AI 建議暫時無法使用，請稍後再試。", "AI suggestions are temporarily unavailable. Try again later.")
        case .invalidFeedback, .wrongLanguage, .generationFailed: L.t("這次未能產生合適的建議，請調整回答或再試一次。", "No suitable suggestions were produced. Edit your answer or try again.")
        }
    }

    private func submit() {
        guard canSubmitAnswer else { return }
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
        guard provider.availability == .ready, canSubmitAnswer, !needsTranscriptReview else { return }
        if provider.usesOnline, CloudAssistant.shared.needsConsent { askCloud = true; return }
        submittedAnswer = answer
        let submitted = SpeakingCoach.Request(keyword: request.keyword, meaning: request.meaning,
            question: question, context: followUpQuestion == nil ? request.context : "", answer: answer, mode: request.mode)
        #if DEBUG
        if let timeout = provider.testingTimeout { session.submit(submitted, timeout: timeout); return }
        #endif
        // Room for both online models and then the on-device one.
        session.submit(submitted, timeout: provider.usesOnline ? .seconds(50) : .seconds(30))
    }

    private func close() {
        pendingSubmission = false
        dismissKeyboard()
        session.cancel()
        recording.clear()
        Speaker.shared.stop()
        dismiss()
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
