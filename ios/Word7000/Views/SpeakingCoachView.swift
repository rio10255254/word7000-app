import SwiftUI
import UIKit
import Word7000Core

@MainActor
struct SpeakingCoachView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var answerFocused: Bool
    @State private var pendingSubmission = false
    @State private var inputCommitFailed = false
    @State private var submittedAnswer: String?

    let request: SpeakingCoach.Request
    @Binding var answer: String
    let session: SpeakingCoachSession

    private var provider: AppleSpeakingCoach { .shared }
    private var answerLanguage: String { request.mode == .english ? "en-US" : "zh-TW" }
    private var canSubmit: Bool {
        !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !pendingSubmission && !session.isBusy && !provider.isBusy
    }

    private var visibleFailure: String? {
        if inputCommitFailed {
            return L.t("輸入尚未完成，請再試一次。你的回答仍在。", "Editing did not finish. Try again; your answer is still here.")
        }
        return session.failure.map(failureMessage)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(request.keyword)
                        .font(.rounded(.headline)).foregroundStyle(Palette.accent)
                    HStack(alignment: .top) {
                        Text(request.question).font(.headline).fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("coach-question")
                        Spacer(minLength: 8)
                        SpeakButton(text: request.question, language: "en-US")
                    }
                }

                if provider.availability == .ready {
                    answerSection
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
                    Label(L.t("由 Apple Intelligence 在裝置上提供建議", "Suggestions from Apple Intelligence on this device"), systemImage: "apple.intelligence")
                        .font(.footnote).foregroundStyle(.secondary)
                } footer: {
                    Text(L.t(
                        "AI 建議可能有誤，不評分發音。教練僅在裝置處理文字，不儲存回答或建議。鍵盤聽寫可能需要網路。",
                        "AI suggestions may be wrong. No pronunciation scoring. The coach processes text on-device without saving answers or suggestions. Keyboard dictation may need a network connection."
                    ))
                }
            }
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
                        Button { answerFocused = false } label: {
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { provider.refreshAvailability() }
        .onDisappear { pendingSubmission = false; session.cancel(); Speaker.shared.stop() }
        .onChange(of: answer) { _, text in
            // SwiftUI may deliver the final keyboard correction after its native
            // end-editing notification. The captured text is already current.
            if text != submittedAnswer { session.reset() }
            inputCommitFailed = false
            Speaker.shared.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: UITextView.textDidEndEditingNotification)) { notification in
            guard pendingSubmission, let editor = notification.object as? UITextView else { return }
            #if DEBUG
            // Force a final native edit in the UI regression, independently of
            // the simulator's keyboard language/autocorrection preferences.
            if let correction = provider.testingCommittedAnswer { editor.text = correction }
            #endif
            finishInput(committedText: editor.text)
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
            else { pendingSubmission = false; session.cancel(); Speaker.shared.stop() }
        }
        .onChange(of: provider.availability) { _, availability in
            if availability != .ready { pendingSubmission = false; session.cancel(clearFeedback: true) }
        }
        .sensoryFeedback(.success, trigger: session.feedback) { _, feedback in
            feedback != nil && (model.settings.hapticsEnabled ?? true)
        }
        .animation(reduceMotion ? nil : Motion.reveal, value: session.feedback != nil)
    }

    private var answerSection: some View {
        Section {
            TextEditor(text: $answer)
                .focused($answerFocused)
                .frame(minHeight: 120, maxHeight: 220)
                .accessibilityLabel(L.t("你的回答", "Your answer"))
                .accessibilityIdentifier("coach-answer")
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
        Section {
            HStack(alignment: .top) {
                Text(feedback.rewrite).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("coach-rewrite")
                Spacer(minLength: 8)
                SpeakButton(text: feedback.rewrite, language: answerLanguage)
            }
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
            }
        } header: { Text(L.t("再想一想", "A follow-up")) }
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
                Button { submit() } label: {
                    Label(L.t("取得建議", "Get suggestions"), systemImage: "sparkles").frame(maxWidth: .infinity)
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

    private var unavailableSection: some View {
        Section {
            HStack(alignment: .top) {
                Image(systemName: "info.circle").accessibilityHidden(true)
                Text(unavailableMessage)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("coach-unavailable")
            }
            Button { provider.refreshAvailability() } label: {
                Label(L.t("再次檢查", "Check again"), systemImage: "arrow.clockwise")
            }
            .accessibilityIdentifier("coach-check-again")
        } header: { Text(L.t("暫時無法提供建議", "Suggestions unavailable")) }
    }

    private var unavailableMessage: String {
        switch provider.availability {
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
        case .tooLong: L.t("回答或題目背景太長。請縮短回答，或改用背景較短的題目再試。", "The answer or question context is too long. Shorten your answer or try a question with less context.")
        case .busy: L.t("上一個請求尚未結束，請稍候再試。", "The previous request is still finishing. Try again shortly.")
        case .timedOut: L.t("這次等候太久，請再試一次。你的回答仍在。", "This took too long. Try again; your answer is still here.")
        case .unavailable: L.t("裝置上的建議暫時無法使用，請稍後再試。", "On-device suggestions are temporarily unavailable. Try again later.")
        case .invalidFeedback, .generationFailed: L.t("這次未能產生合適的建議，請調整回答或再試一次。", "No suitable suggestions were produced. Edit your answer or try again.")
        }
    }

    private func submit() {
        guard canSubmit else { return }
        inputCommitFailed = false
        Speaker.shared.stop()
        if answerFocused {
            pendingSubmission = true
            answerFocused = false
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
        answerFocused = false
        session.cancel()
        Speaker.shared.stop()
        dismiss()
    }
}
