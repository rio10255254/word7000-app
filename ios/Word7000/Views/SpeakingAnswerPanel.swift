import SwiftUI
import UIKit
import AVFoundation
import Word7000Core

/// Answering a speaking question on the question's own page. One big key
/// records; stopping turns the take into text on a notepad that can be
/// corrected in place; a Check key asks for the coach's suggestions, which
/// arrive below with a follow-up question to answer in the same spot.
/// Nothing opens a second screen.
@MainActor
struct SpeakingAnswerPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(PlusModel.self) private var plus
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appStyle) private var appStyle

    let request: SpeakingCoach.Request
    @Binding var answer: String
    @Binding var needsTranscriptReview: Bool
    let session: SpeakingCoachSession
    /// Scrolls the page to one of this panel's anchors.
    var scrollTo: (String) -> Void
    /// Called once something was said or written for this question.
    var onAttempt: () -> Void

    @State private var recording = LiveListener()
    /// This take was started from the notepad (record again), so its words
    /// go straight onto the notepad as they are heard.
    @State private var takeFromPad = false
    /// Words recognition got wrong and were put right, to show and undo.
    @State private var fixes: [TranscriptCorrection.Fix] = []
    @State private var typing = false
    @State private var answerFocused = false
    @State private var pendingSubmission = false
    @State private var askCloud = false
    @State private var inputCommitFailed = false
    @State private var submittedAnswer: String?
    @State private var reflection: SpeakingReflection?
    @State private var followUpQuestion: String?
    @State private var followUpTranslation: String?
    @State private var showsPrivacy = false
    @State private var checkAfterSubscribing = false
    @State private var paywall: PaywallReason?

    static let padAnchor = "answer-pad"
    static let feedbackAnchor = "answer-feedback"
    static let topAnchor = "answer-top"

    private var provider: AppleSpeakingCoach { .shared }
    private var collage: Bool { appStyle == .collage }
    private var chinese: Bool { request.mode == .chinese }
    /// The question being answered: the card's, or the coach's follow-up.
    private var question: String { followUpQuestion ?? request.question }
    private var answerLanguage: String { chinese ? "zh-TW" : "en-US" }
    private var hasText: Bool { !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var live: Bool { recording.listening }
    /// The notepad shows once there is something to show or to write on.
    private var showsPad: Bool {
        typing || hasText || recording.hasRecording
            || recording.state == .finishing
    }

    private var canSubmitAnswer: Bool {
        hasText && !pendingSubmission && !session.isBusy && !provider.isBusy && !recording.busy
            && answer.count <= SpeakingCoach.maximumAnswerCharacters
    }

    /// After suggestions arrive, the same key asks again for the same answer.
    private var askedForThisAnswer: Bool { session.feedback != nil && submittedAnswer == answer }

    private var transcriptionHints: [String] {
        var seen = Set<String>()
        let words = question.split(whereSeparator: { !$0.isLetter && $0 != "'" }).map(String.init)
        return ([request.keyword] + words.filter { $0.count >= 4 })
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
            .prefix(20).map { $0 }
    }

    private var answerEchoesQuestion: Bool {
        SpeakingCoach.echoesQuestion(answer: answer, question: question)
    }

    private var visibleFailure: String? {
        if inputCommitFailed {
            return L.t("輸入尚未完成，請再試一次。你的回答仍在。", "Editing did not finish. Try again; your answer is still here.")
        }
        return session.failure.map(failureMessage)
    }

    var body: some View {
        VStack(spacing: 16) {
            if let followUpQuestion { followUpBanner(followUpQuestion) }
            if showsPad { pad } else { recorderKey }
            if provider.availability == .ready, let message = visibleFailure {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.circle").accessibilityHidden(true)
                    Text(message).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("coach-error")
                }
                .font(.subheadline)
                .foregroundStyle(Palette.miss)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let feedback = session.feedback {
                suggestions(feedback)
                    .id(Self.feedbackAnchor)
                followUpOffer(feedback)
            }
            if showsPrivacy {
                Text(privacyNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("coach-privacy")
            }
        }
        .animation(reduceMotion ? nil : Motion.reveal, value: showsPad)
        .animation(reduceMotion ? nil : Motion.reveal, value: session.feedback != nil)
        .animation(reduceMotion ? nil : Motion.reveal, value: live)
        .onAppear {
            provider.refreshAvailability()
            // Where recordings and answers go, said once rather than on every question.
            if model.settings.coachPrivacySeen != true { showsPrivacy = true }
        }
        .onDisappear {
            if showsPrivacy { model.settings.coachPrivacySeen = true }
            pendingSubmission = false
            session.cancel()
            recording.clear()
        }
        .task { await recording.refresh(language: answerLanguage) }
        .task(id: answer) {
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            guard !Task.isCancelled else { return }
            if hasText { onAttempt() }
            guard answer.count <= SpeakingCoach.maximumAnswerCharacters else { reflection = nil; return }
            let text = answer, target = request.keyword, chinese = chinese
            let result = await Task.detached(priority: .utility) {
                SpeakingRecorder.reflection(answer: text, target: target, chinese: chinese)
            }.value
            guard !Task.isCancelled, answer == text else { return }
            reflection = result
        }
        // Words appear as they are said: on the notepad when recording again
        // from it, otherwise in a bubble over the big key until the take ends.
        .onChange(of: recording.text) { _, value in
            if takeFromPad, live || recording.state == .finishing { answer = value }
        }
        .onChange(of: recording.isFinal) { _, final in
            guard final else { return }
            onAttempt()
            // A new take is a new answer: its words replace the notepad's,
            // with what recognition plainly misheard put right (and shown).
            guard !recording.text.isEmpty else { return }
            let corrected = TranscriptCorrection.correct(recording.text, keyPhrase: request.keyword, chinese: chinese)
            fixes = corrected.fixes
            answer = corrected.text
            needsTranscriptReview = true
            session.reset()
            // A take that came back without punctuation gets it, where this
            // iPhone's model can add it without touching a word.
            let text = corrected.text
            Task {
                guard let punctuated = await DeviceAssist.punctuate(text, chinese: chinese), answer == text else { return }
                answer = punctuated
            }
        }
        // A long pause ends the take; so does the minute. A shorter pause
        // ends it where this iPhone's model reads the answer as finished.
        .task(id: live) {
            guard live else { return }
            var asked = ""
            while !Task.isCancelled, recording.listening {
                do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
                let text = recording.text
                let liveText = recording.support == .live
                if recording.seconds >= 60
                    || (liveText && !text.isEmpty && recording.quietFor > 5)
                    || (liveText && text.isEmpty && recording.quietFor > 15) {
                    recording.stop(); return
                }
                if !text.isEmpty, recording.quietFor > 1.4, text != asked {
                    asked = text
                    if await DeviceAssist.seemsFinished(text, question: question, chinese: chinese) == true,
                       recording.listening, recording.text == text {
                        recording.stop(); return
                    }
                }
            }
        }
        .onChange(of: plus.subscribed) { _, subscribed in
            provider.refreshAvailability()
            // Back from subscribing: the answer they wanted checked is checked.
            if subscribed, checkAfterSubscribing {
                checkAfterSubscribing = false
                if hasText, !answerFocused { submit() }
            }
        }
        // The page is a full-screen cover, so the paywall is presented from here.
        .sheet(item: $paywall, onDismiss: {
            if !plus.subscribed { checkAfterSubscribing = false }
        }) { reason in PaywallView(reason: reason) }
        .onChange(of: answerFocused) { _, focused in
            guard focused else { return }
            // The notepad comes up above the keyboard to write on.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                if answerFocused { scrollTo(Self.padAnchor) }
            }
        }
        .onChange(of: session.feedback) { _, feedback in
            guard feedback != nil else { return }
            scrollTo(Self.feedbackAnchor)
        }
        .onChange(of: IntelligenceSettings.shared.coachAllowed) { _, _ in provider.refreshAvailability() }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in recording.interrupt() }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { event in
            if let raw = event.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
               AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable { recording.interrupt() }
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
            if phase == .active {
                provider.refreshAvailability()
            }
            else if phase == .background { pendingSubmission = false; session.cancel(); recording.interrupt(); Speaker.shared.stop() }
        }
        .onChange(of: provider.availability) { _, availability in
            if availability != .ready { pendingSubmission = false; session.cancel(clearFeedback: true) }
        }
        .cloudConsentAlert(isPresented: $askCloud) { provider.refreshAvailability(); generateSuggestions() }
        .sensoryFeedback(.success, trigger: session.feedback) { _, feedback in
            feedback != nil && (model.settings.hapticsEnabled ?? true)
        }
        .sensoryFeedback(trigger: recording.state) { old, new in
            guard model.settings.hapticsEnabled ?? true else { return nil }
            if new == .listening { return .impact(weight: .medium) }
            if old == .listening { return .impact(weight: .light) }
            return nil
        }
    }

    // MARK: Recording

    /// Before anything is said: one big key, and a way to type instead.
    private var recorderKey: some View {
        VStack(spacing: 12) {
            if live, !recording.text.isEmpty {
                // What is being heard, as one's own chat message.
                HStack {
                    Spacer(minLength: 40)
                    Text(recording.text)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Palette.accent.opacity(0.12), in: BubbleShape(tail: .trailing))
                        .contentTransition(.opacity)
                        .accessibilityIdentifier("coach-live-text")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottomTrailing)))
            }
            ZStack {
                if live && !reduceMotion {
                    Circle()
                        .stroke(Palette.miss.opacity(0.3), lineWidth: 3)
                        .frame(width: 112, height: 112)
                        .scaleEffect(1.15 + CGFloat(recording.level) * 0.35)
                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: recording.level)
                }
                Button {
                    if live { recording.stop() } else { beginRecording() }
                } label: {
                    Image(systemName: live ? "stop.fill" : "mic.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(MicKeyStyle(live: live))
                .disabled((recording.busy && !live) || session.isBusy)
                .accessibilityLabel(live ? L.t("停止錄音", "Stop recording") : L.t("開始錄音", "Start recording"))
                .accessibilityIdentifier("coach-record")
            }
            .frame(height: 150)
            if live {
                CoachLevelMeter(level: Double(recording.level), reduceMotion: reduceMotion)
                    .accessibilityElement()
                    .accessibilityLabel(L.t("麥克風音量", "Microphone level"))
                    .accessibilityValue("\(Int((recording.level * 100).rounded()))%")
                Text("\(Int(recording.seconds)) / 60 \(L.t("秒", "s"))")
                    .font(.display(.title3, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.miss)
                    .contentTransition(.numericText(value: recording.seconds))
                    .accessibilityIdentifier("coach-recording-duration")
            }
            Text(live ? L.t("說完再按一下", "Tap again when you're done") : L.t("按一下開始說", "Tap and say your answer"))
                .font(.headline)
                .contentTransition(.opacity)
            if !live {
                Button {
                    typing = true
                    answerFocused = true
                } label: {
                    Text(L.t("不想說出來？改用打字", "Rather not speak? Type instead"))
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("coach-type-instead")
            }
            recorderMessages
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    /// Problems with the microphone, wherever the recorder is.
    @ViewBuilder
    private var recorderMessages: some View {
        if let message = recording.message {
            Text(message).font(.footnote).foregroundStyle(Palette.miss)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if recording.messageNeedsSettings {
                Button(L.t("系統設定", "System Settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func beginRecording() {
        pendingSubmission = false
        dismissKeyboard()
        session.cancel()
        Speaker.shared.stop()
        takeFromPad = showsPad
        fixes = []
        if takeFromPad { answer = "" }
        recording.start(hints: transcriptionHints)
    }

    // MARK: The notepad

    private var pad: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                CoachHeader(title: followUpQuestion == nil ? L.t("你的回答", "Your answer") : L.t("回答追問", "Your reply"), icon: "pencil.line")
                Spacer()
                if answerFocused {
                    // The keyboard hides the Check key below; it moves up here.
                    if provider.availability == .ready, hasText, !session.isWorking, !pendingSubmission {
                        Button {
                            guard canSubmitAnswer else { return }
                            needsTranscriptReview = false
                            submit()
                        } label: {
                            Label(L.t("批改", "Check"), systemImage: "sparkles")
                                .font(.subheadline.weight(.bold))
                        }
                        .buttonStyle(.borderless)
                        .disabled(!canSubmitAnswer)
                        .accessibilityIdentifier("coach-submit")
                    }
                    Button { dismissKeyboard() } label: { Image(systemName: "keyboard.chevron.compact.down") }
                        .buttonStyle(.borderless)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel(L.t("收起鍵盤", "Dismiss keyboard"))
                        .accessibilityIdentifier("coach-keyboard-done")
                }
            }
            notepad
            padTools
            padStatus
            checkArea
        }
        .modifier(AnswerPaper(kind: .sage, seed: 5))
        .id(Self.padAnchor)
    }

    private var notepad: some View {
        let font = UIFont.preferredFont(forTextStyle: .body)
        let editor = PracticeAnswerEditor(text: $answer, focused: $answerFocused,
                                          editable: !live && recording.state != .finishing,
                                          ruled: collage,
                                          onEdit: { text in
                                              if text != submittedAnswer { session.reset() }
                                              // Edited by hand: the fixes are theirs now.
                                              if !fixes.isEmpty { fixes = [] }
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
            .accessibilityLabel(L.t("你的回答", "Your answer"))
            .accessibilityIdentifier("coach-answer")
        let placeholder = live ? L.t("請說…", "Go ahead…")
            : chinese ? L.t("在這裡用中文寫下你的回答", "Write your answer in Chinese here")
            : L.t("在這裡用英文寫下你的回答", "Write your answer in English here")
        return VStack(spacing: 0) {
            if collage {
                // The glued top of the pad, with its row of punched holes.
                Rectangle()
                    .fill(Palette.accent)
                    .frame(height: 10)
                    .overlay {
                        HStack(spacing: 14) {
                            ForEach(0..<9, id: \.self) { _ in Circle().fill(Collage.ink.opacity(0.45)).frame(width: 4, height: 4) }
                        }
                    }
                    .accessibilityHidden(true)
            }
            editor
                .frame(minHeight: 96, maxHeight: 200)
                .overlay(alignment: .topLeading) {
                    if answer.isEmpty {
                        Text(placeholder)
                            .foregroundStyle(.tertiary)
                            .padding(.top, collage ? RuledTextView.firstLineTop(for: font) : 8)
                            .padding(.leading, collage ? RuledTextView.textLeft : 5)
                            .padding(.trailing, 10)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .background(collage ? PaperKind.ivory.color : Color.clear)
        }
        .overlay { if collage { Rectangle().strokeBorder(Collage.ink.opacity(0.55), lineWidth: 1) } }
    }

    /// Replay, record again, and whether the target word was used.
    private var padTools: some View {
        HStack(spacing: 10) {
            if recording.hasRecording {
                Button { recording.togglePlayback() } label: {
                    Image(systemName: recording.state == .playing ? "stop.fill" : "play.fill")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(CoachDiscStyle(tint: Palette.accent))
                .disabled(recording.busy && recording.state != .playing)
                .accessibilityLabel(recording.state == .playing ? L.t("停止回放", "Stop playback") : L.t("回放", "Play"))
                .accessibilityIdentifier("coach-play-recording")
            }
            Button {
                if live { recording.stop() }
                else { beginRecording() }
            } label: {
                Image(systemName: live ? "stop.fill" : (recording.hasRecording ? "arrow.counterclockwise" : "mic.fill"))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(CoachDiscStyle(tint: live ? Palette.miss : Palette.accent))
            .disabled((recording.busy && !live) || session.isBusy)
            .accessibilityLabel(live ? L.t("停止錄音", "Stop recording") : recording.hasRecording ? L.t("重錄", "Record again") : L.t("錄音", "Record"))
            .accessibilityIdentifier("coach-retake")
            if live {
                Text("\(Int(recording.seconds))s")
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(Palette.miss)
                    .accessibilityIdentifier("coach-recording-duration")
            }
            Spacer(minLength: 4)
            if let reflection, hasText {
                if answerEchoesQuestion {
                    Label(L.t("像是把題目念了一遍", "Sounds like the question"), systemImage: "exclamationmark.circle")
                        .font(.footnote.weight(.semibold)).foregroundStyle(Palette.review)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .accessibilityIdentifier("coach-echo")
                } else {
                    Label(reflection.containsTarget ? L.t("用到 \(request.keyword)", "Used \(request.keyword)")
                          : L.t("還沒用到 \(request.keyword)", "\(request.keyword) not used yet"),
                          systemImage: reflection.containsTarget ? "checkmark.circle.fill" : "circle.dashed")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(reflection.containsTarget ? Palette.known : Color.secondary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .sensoryFeedback(.selection, trigger: reflection.containsTarget) { _, used in
                            used && (model.settings.hapticsEnabled ?? true)
                        }
                        .accessibilityIdentifier("coach-answer-check")
                }
            }
        }
    }

    /// Progress and the rare manual step under the notepad.
    @ViewBuilder
    private var padStatus: some View {
        if recording.state == .requesting {
            HStack {
                ProgressView()
                Text(L.t("準備中…", "Getting ready…")).font(.subheadline)
                Spacer()
            }
        } else if recording.support == .recordOnly && recording.hasRecording && !hasText {
            Text(L.t("這部手機沒有離線辨識，可以回放後自己輸入。", "No offline transcription on this iPhone. Replay and type your answer."))
                .font(.footnote).foregroundStyle(.secondary)
        }
        if !fixes.isEmpty, hasText {
            // What recognition misheard and was put right, undone in one tap.
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars").foregroundStyle(Palette.accent)
                Text(fixes.map { "\($0.heard) → \($0.corrected)" }.joined(separator: "、"))
                    .font(.footnote.weight(.semibold))
                Text(L.t("已自動修正", "fixed")).font(.footnote).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Button(L.t("還原", "Undo")) {
                    answer = TranscriptCorrection.undo(fixes, in: answer)
                    fixes = []
                }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.borderless)
                .accessibilityIdentifier("coach-undo-fix")
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("coach-fixes")
        }
        if recording.hasRecording || hasText { recorderMessages }
        if needsTranscriptReview, hasText {
            Text(L.t("聽錯的字可以直接點上面的文字修改。", "Misheard a word? Tap the text above to fix it."))
                .font(.footnote).foregroundStyle(.secondary)
        }
        if answer.count > SpeakingCoach.maximumAnswerCharacters {
            Text(L.t("請將回答精簡至 600 字以內再批改。", "Shorten your answer to 600 characters to get it checked."))
                .font(.footnote).foregroundStyle(Palette.miss)
        }
    }

    // MARK: Checking

    @ViewBuilder
    private var checkArea: some View {
        if provider.availability == .ready {
            if session.isWorking || pendingSubmission {
                HStack(spacing: 8) {
                    if pendingSubmission || reduceMotion {
                        ProgressView()
                    } else {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Palette.accent)
                            .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
                            .accessibilityHidden(true)
                    }
                    Text(pendingSubmission ? L.t("正在完成輸入…", "Finishing input…") : L.t("小笨貓批改中…", "Silly Cat is checking…"))
                        .font(.subheadline)
                    Spacer()
                    Button(L.t("取消", "Cancel")) { pendingSubmission = false; session.cancel() }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("coach-cancel")
                }
                .frame(minHeight: 44)
            } else if hasText, !answerFocused {
                Button {
                    guard canSubmitAnswer else { return }
                    needsTranscriptReview = false
                    submit()
                } label: {
                    Label(askedForThisAnswer ? L.t("再批改一次", "Check again") : L.t("批改", "Check my answer"),
                          systemImage: askedForThisAnswer ? "arrow.clockwise" : "sparkles")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .modifier(CheckKey(again: askedForThisAnswer))
                .disabled(!canSubmitAnswer)
                .accessibilityIdentifier("coach-submit")
            }
        } else if premiumUnlocksChecking {
            if hasText, !answerFocused { premiumCheckKey }
        } else if hasText || recording.hasRecording {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Image(systemName: "info.circle").accessibilityHidden(true)
                    Text(unavailableMessage)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("coach-unavailable")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                if !unavailableIsSettled {
                    Button {
                        Task {
                            await IntelligenceSettings.shared.refreshPolicy(force: true)
                            provider.refreshAvailability()
                        }
                    } label: {
                        Label(L.t("再次檢查", "Check again"), systemImage: "arrow.clockwise").font(.subheadline)
                    }
                    .buttonStyle(.borderless)
                    .disabled(IntelligenceSettings.shared.checking)
                    .accessibilityIdentifier("coach-check-again")
                }
            }
        }
    }

    /// Checking is Premium's online AI, so for everyone else the Check key
    /// leads straight to subscribing.
    private var premiumUnlocksChecking: Bool {
        provider.availability != .paused && !plus.subscribed
            && IntelligenceSettings.shared.coachAllowed && IntelligenceSettings.shared.cloudOffered
    }

    private var premiumCheckKey: some View {
        VStack(spacing: 8) {
            Button {
                needsTranscriptReview = false
                checkAfterSubscribing = true
                Speaker.shared.stop()
                paywall = .speakingCoach
            } label: {
                HStack(spacing: 8) {
                    Label(L.t("批改", "Check my answer"), systemImage: "sparkles")
                    Text("Premium")
                        .font(.caption.weight(.heavy))
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(.white.opacity(0.25), in: Capsule())
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .prominentAction()
            .disabled(answer.count > SpeakingCoach.maximumAnswerCharacters)
            .accessibilityIdentifier("coach-premium-check")
            Text(premiumNote)
                .font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("coach-premium-note")
        }
        .frame(maxWidth: .infinity)
    }

    private var premiumNote: String {
        L.t("訂閱 Premium，小笨貓就幫你改成更自然的說法、指出錯誤，再追問一題。",
            "With Premium, Silly Cat rewrites it more naturally, points out what to fix and asks a follow-up.")
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
        guard provider.availability == .ready, canSubmitAnswer else { return }
        if provider.usesOnline, CloudAssistant.shared.needsConsent { askCloud = true; return }
        needsTranscriptReview = false
        submittedAnswer = answer
        let submitted = SpeakingCoach.Request(keyword: request.keyword, meaning: request.meaning,
            question: question, context: followUpQuestion == nil ? request.context : "", answer: answer, mode: request.mode)
        #if DEBUG
        if let timeout = provider.testingTimeout { session.submit(submitted, timeout: timeout); return }
        #endif
        // Room for the online model to answer.
        session.submit(submitted, timeout: provider.usesOnline ? .seconds(50) : .seconds(30))
    }

    private func dismissKeyboard() {
        answerFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: Suggestions

    /// The corrections, the natural version and one tip: in the collage a page
    /// marked up in red pen with the tip on a sticky note.
    private func suggestions(_ feedback: SpeakingCoach.Feedback) -> some View {
        let comparison = SpeakingCoach.comparison(answer: submittedAnswer ?? answer, rewrite: feedback.rewrite)
        return VStack(alignment: .leading, spacing: 12) {
            CoachHeader(title: L.t("更自然的說法", "More natural"), icon: "sparkles")
            HStack(alignment: .top) {
                Text(comparison.map { highlighted($0.rewrite) } ?? AttributedString(feedback.rewrite))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("coach-rewrite")
                Spacer(minLength: 8)
                SpeakButton(text: feedback.rewrite, language: answerLanguage).disabled(recording.busy)
            }
            .modifier(CoachArrival(order: 0))
            ForEach(Array(feedback.corrections.enumerated()), id: \.offset) { offset, correction in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "pencil.tip")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Palette.miss)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(correctionLine(correction))
                        Text(correction.reason).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .textSelection(.enabled)
                .modifier(CoachArrival(order: offset + 1))
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "lightbulb.fill").foregroundStyle(collage ? Collage.ink : Palette.review).accessibilityHidden(true)
                Text(feedback.tip).font(.subheadline).textSelection(.enabled)
                    .foregroundStyle(collage ? Collage.ink : Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("coach-tip")
            }
            .padding(collage ? 12 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { if collage { PaperSurface(kind: .mustard) } }
            .rotationEffect(.degrees(collage ? -0.8 : 0))
            .modifier(CoachArrival(order: feedback.corrections.count + 1))
        }
        .modifier(AnswerPaper(kind: .ivory, tilt: 0.4, torn: [.top], seed: 6))
    }

    private func followUpOffer(_ feedback: SpeakingCoach.Feedback) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(feedback.followUp).font(.headline).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("coach-follow-up")
                    if chinese {
                        let pinyin = ChineseDisplay.sentencePinyin(feedback.followUp)
                        if !pinyin.isEmpty {
                            Text(pinyin).font(.footnote).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if let translation = feedback.followUpTranslation {
                        Text(translation).font(.subheadline).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("coach-follow-up-translation")
                    }
                }
                Spacer(minLength: 8)
                SpeakButton(text: feedback.followUp, language: answerLanguage).disabled(recording.busy)
            }
            Button { answerFollowUp(feedback.followUp, translation: feedback.followUpTranslation) } label: {
                Label(L.t("回答這個追問", "Answer this follow-up"), systemImage: "mic.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .modifier(CheckKey(again: true))
            .fixedSize()
            .disabled(recording.busy || session.isBusy)
            .accessibilityIdentifier("coach-answer-follow-up")
        }
        .modifier(CoachArrival(order: feedback.corrections.count + 2))
        .modifier(AnswerPaper(kind: .peach, tilt: -0.5, torn: [.bottom], tape: true, seed: 8))
    }

    /// While a follow-up is being answered, it sits above the notepad.
    private func followUpBanner(_ followUp: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.t("追問", "Follow-up")).font(.caption.weight(.bold)).foregroundStyle(Palette.accent)
                    Text(followUp).font(.headline).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("coach-question")
                    if chinese {
                        let pinyin = ChineseDisplay.sentencePinyin(followUp)
                        if !pinyin.isEmpty { Text(pinyin).font(.footnote).foregroundStyle(.secondary) }
                    }
                    if let followUpTranslation, !followUpTranslation.isEmpty {
                        Text(followUpTranslation).font(.subheadline).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                SpeakButton(text: followUp, language: answerLanguage).disabled(recording.busy)
            }
            Button { answerFollowUp(nil) } label: {
                Label(L.t("回到原來的題目", "Back to the original question"), systemImage: "arrow.uturn.backward")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .disabled(recording.busy || session.isBusy)
            .accessibilityIdentifier("coach-original-question")
        }
        .modifier(AnswerPaper(kind: .peach, seed: 3))
        .id(Self.topAnchor)
    }

    /// Answering the follow-up turns one reply into a short conversation. Nil
    /// returns to the card's own question.
    private func answerFollowUp(_ followUp: String?, translation: String? = nil) {
        pendingSubmission = false
        dismissKeyboard()
        Speaker.shared.stop()
        recording.clear()
        session.reset()
        submittedAnswer = nil
        needsTranscriptReview = false
        inputCommitFailed = false
        answer = ""
        typing = false
        followUpQuestion = followUp
        followUpTranslation = followUp == nil ? nil : translation
        scrollTo(followUp == nil ? Self.padAnchor : Self.topAnchor)
        if let followUp, model.settings.speech?.autoReadQuestions ?? true {
            Speaker.shared.speak(followUp, language: answerLanguage, preferences: model.settings.speech ?? SpeechPreferences())
        }
    }

    private func highlighted(_ pieces: [SpeakingCoach.Piece]) -> AttributedString {
        pieces.reduce(into: AttributedString()) { result, piece in
            var part = AttributedString(piece.text)
            if piece.changed {
                part.swiftUI.foregroundColor = Palette.accent
                part.swiftUI.font = .body.weight(.semibold)
            }
            result += part
        }
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

    // MARK: Words

    private var privacyNote: String {
        if provider.usesOnline, IntelligenceSettings.shared.cloudConsent == true {
            return L.t("錄音只留在這部手機，離開即刪除。批改時，回答文字會傳送到 Anthropic 的 Claude 線上 AI 處理。AI 建議可能有誤，也不評分發音。",
                       "Recordings stay on this iPhone and are deleted when you leave. To check an answer, its text is sent to Anthropic's Claude online AI. AI suggestions may be wrong and do not score pronunciation.")
        }
        return L.t("錄音與回答只留在這部手機，離開即刪除錄音。",
                   "Recordings and answers stay on this iPhone; leaving deletes the recording.")
    }

    private var unavailableIsSettled: Bool {
        provider.availability == .unsupported || (provider.availability == .paused && !IntelligenceSettings.shared.enabled)
    }

    private var unavailableMessage: String {
        switch provider.availability {
        case .unsupported:
            L.t("AI 批改目前無法使用。錄音、回放和轉成文字都能照常使用。",
                "AI checking isn't available right now. Recording, playback and transcription still work.")
        case .paused where !IntelligenceSettings.shared.enabled:
            L.t("你已關閉 AI 建議，可在「設定 → AI 與錄音」重新開啟。", "You turned AI suggestions off. Turn them back on in Settings → AI and recording.")
        case .paused:
            L.t("AI 批改目前已關閉。錄音和文字仍可使用。", "AI checking is currently off. Recording and text still work.")
        default:
            L.t("這部裝置目前無法使用 AI 批改。", "AI checking is currently unavailable on this device.")
        }
    }

    private func failureMessage(_ failure: SpeakingCoach.Failure) -> String {
        switch failure {
        case .emptyAnswer: L.t("請先說或寫下回答。", "Say or write an answer first.")
        case .echoesQuestion:
            chinese
                ? L.t("這段回答和題目幾乎一樣，像是把題目念了一遍。試著用自己的話回答它。",
                      "This is almost the same as the question. Try answering it in your own words.")
                : L.t("這段回答和題目幾乎一樣，像是把題目念了一遍。試著回答它，例如用「I would…」或「I think…」開頭。",
                      "This is almost the same as the question. Try answering it, starting with \"I would…\" or \"I think…\".")
        case .tooLong: L.t("回答或題目背景太長。請縮短回答再試。", "The answer or question context is too long. Shorten your answer and try again.")
        case .busy: L.t("上一個請求尚未結束，請稍候再試。", "The previous request is still finishing. Try again shortly.")
        case .timedOut: L.t("這次等候太久，請再試一次。你的回答仍在。", "This took too long. Try again; your answer is still here.")
        case .unavailable: L.t("AI 批改暫時無法使用，請稍後再試。", "AI checking is temporarily unavailable. Try again later.")
        case .invalidFeedback, .wrongLanguage, .generationFailed: L.t("這次未能產生合適的建議，請調整回答或再試一次。", "No suitable suggestions were produced. Edit your answer or try again.")
        }
    }
}

/// The Check key: prominent the first time, quieter for "check again".
private struct CheckKey: ViewModifier {
    var again: Bool

    func body(content: Content) -> some View {
        if again { content.secondaryAction() } else { content.prominentAction() }
    }
}
