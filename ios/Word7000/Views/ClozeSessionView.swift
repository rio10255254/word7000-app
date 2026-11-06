import SwiftUI
import Word7000Core

/// WordCat Next: today's round as fill-in-the-blank questions. The Chinese
/// sentence sits on top with the word's part marked like a highlighter; the
/// English sentence below has the word blanked out, and the learner types it.
/// A miss is never a dead end: the first letter, then the answer, are on
/// offer, the answer still has to be typed, and a missed word comes back a
/// few questions later. Return checks and return again moves on, so the
/// keyboard stays up the whole round.
struct ClozeSessionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var round = ClozeRound(entries: [])
    @State private var words: [String: WordEntry] = [:]
    /// The learner's words by spelling, to say what a wrong word means.
    @State private var lookup: [String: WordEntry] = [:]
    @State private var attempt: ClozeAttempt?
    @State private var input = ""
    @State private var started = false
    /// When the word just solved comes back, e.g. "See you tomorrow".
    @State private var comeBack: String?
    /// The word just solved was the round's last question.
    @State private var finishesRound = false
    @State private var catLines = CatLineSource.none
    /// Triggers: a miss shakes the card, a solve makes it swell.
    @State private var misses = 0
    @State private var solves = 0
    @FocusState private var focused: Bool

    private var currentWord: WordEntry? { round.currentWordId.flatMap { words[$0] } }
    private var haptics: Bool { model.settings.hapticsEnabled ?? true }

    var body: some View {
        NavigationStack {
            Group {
                if !started {
                    ProgressView()
                } else if round.initialCount == 0 {
                    ContentUnavailableView {
                        MascotLabel(mood: .encourage, title: L.t("今天沒有可以挖空的單字", "No fill-in words for today"))
                    }
                } else if round.isComplete {
                    results
                } else if let word = currentWord, let sentence = Cloze.sentence(for: word), let attempt {
                    question(word, sentence, attempt)
                } else {
                    ProgressView()
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background { AmbientBackground() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(L.close)
                        .accessibilityIdentifier("cloze-close")
                }
                ToolbarItem(placement: .principal) {
                    if started, !round.isComplete, round.total > 0 {
                        Text("\(round.done + 1) / \(round.total)")
                            .font(.display(.subheadline, weight: .semibold))
                            .monospacedDigit()
                            .accessibilityIdentifier("cloze-position")
                    }
                }
            }
        }
        .onAppear { if !started { start() }; catLines = model.catLines }
        .onDisappear { Speaker.shared.stop() }
        .modifier(AnswerFeedback(solves: solves, misses: misses, haptics: haptics))
    }

    // MARK: Question

    private func question(_ word: WordEntry, _ sentence: Cloze.Sentence, _ attempt: ClozeAttempt) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                BuddyProgressBar(fraction: Double(round.done + (attempt.solved ? 1 : 0)) / Double(max(1, round.total)),
                                 mood: attempt.solved ? .happy : (attempt.misses > 0 ? .encourage : .thinking),
                                 hop: solves + misses,
                                 remark: nil)

                ClozeCard(word: word, sentence: sentence, attempt: attempt, input: input,
                          comeBack: comeBack, secondLook: round.isSecondLook)
                    .shake(trigger: misses, enabled: !reduceMotion)
                    .pulse(trigger: solves, scale: 1.02, enabled: !reduceMotion)
                    .entrance(0, distance: 10)
                    .id(round.index)

            }
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.never)
        // The hint and the answer box sit on the buttons, right above the keyboard.
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if let message = ClozeCard.message(for: word, attempt: attempt) {
                    Text(message.text)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(message.tint)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(message.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
                        .accessibilityIdentifier("cloze-message")
                }

                TextField(L.t("輸入英文單字", "Type the English word"), text: Binding(
                    get: { input },
                    set: { if !attempt.solved { input = $0 } }
                ))
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .submitLabel(attempt.solved ? .next : .done)
                .focused($focused)
                .onSubmit {
                    attempt.solved ? next() : check()
                    keepKeyboard()
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(focused ? Palette.accent.opacity(0.45) : .clear, lineWidth: 2)
                )
                .accessibilityIdentifier("cloze-input")
                actions(word, attempt)
            }
            .padding(.top, 8)
            .background { PaperBarBackground() }
        }
    }

    private func actions(_ word: WordEntry, _ attempt: ClozeAttempt) -> some View {
        ButtonRow {
            if !attempt.solved {
                if let help = attempt.nextHelp {
                    Button(action: takeHelp) {
                        Label(help == .firstLetter ? L.t("第一個字母", "First letter") : L.t("看答案", "Show answer"),
                              systemImage: help == .firstLetter ? "lightbulb" : "eye")
                            .font(.title3.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .secondaryAction()
                    .accessibilityIdentifier("cloze-help")
                }
                Button(action: check) {
                    Text(L.t("檢查", "Check")).font(.title3.weight(.bold)).frame(maxWidth: .infinity)
                }
                .prominentAction()
                .disabled(input.trimmed.isEmpty)
                .accessibilityIdentifier("cloze-check")
            } else {
                Button(action: next) {
                    Text(finishesRound ? L.seeResults : L.nextQuestion)
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .prominentAction(tint: Palette.known)
                .accessibilityIdentifier("cloze-next")
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: Flow

    private func start() {
        Speaker.shared.stop()
        let built = model.clozeRound(seed: SeededRandom.runtimeSeed())
        round = built.round
        words = Dictionary(built.words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        lookup = Dictionary(model.bank.words.map { (Spelling.normalized($0.word), $0) }, uniquingKeysWith: { first, _ in first })
        prepareCurrent()
        started = true
        Task {
            // The cover must finish presenting before the keyboard can rise.
            try? await Task.sleep(for: .milliseconds(450))
            focused = true
        }
    }

    private func prepareCurrent() {
        input = ""
        comeBack = nil
        finishesRound = false
        attempt = currentWord.flatMap { Cloze.sentence(for: $0) }.map { ClozeAttempt(answer: $0.answer) }
    }

    /// Return resigns the field; it is focused again so the keyboard stays
    /// up for the next try and the next word.
    private func keepKeyboard() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            if !round.isComplete { focused = true }
        }
    }

    private func takeHelp() {
        guard var current = attempt, !current.solved else { return }
        current.takeHelp()
        if current.answerShown { input = "" }
        withAnimation(reduceMotion ? nil : Motion.pop) { attempt = current }
    }

    private func check() {
        guard var current = attempt, !current.solved, let word = currentWord, !input.trimmed.isEmpty else { return }
        let verdict = current.submit(input, lookup: { lookup[$0] })
        if verdict.isCorrect, let outcome = current.outcome {
            model.recordClozeAnswer(wordId: word.id, outcome: outcome)
            var preview = round
            preview.record(outcome)
            comeBack = comeBackLabel(word.id, after: preview)
            finishesRound = preview.isComplete
            solves += 1
            if model.settings.speech?.autoSpeak == true {
                Speaker.shared.speak(word.example, language: "en-US", preferences: model.settings.speech ?? SpeechPreferences())
            }
        } else {
            misses += 1
            // Once the answer is up, it is typed fresh rather than fixed.
            if current.answerShown { input = "" }
        }
        withAnimation(reduceMotion ? nil : Motion.reveal) { attempt = current }
    }

    private func next() {
        guard let current = attempt, current.solved, let outcome = current.outcome else { return }
        Speaker.shared.stop()
        round.record(outcome)
        prepareCurrent()
        if round.isComplete { focused = false }
    }

    private func comeBackLabel(_ wordId: String, after preview: ClozeRound) -> String {
        let days = Cloze.daysUntil(LearningEngine.reviewDueDate(model.progress(for: wordId)), today: model.today) ?? 0
        return ClozeCard.comeBackLabel(days: days, inThisRound: preview.comesBack(wordId))
    }

    // MARK: Results

    private var results: some View {
        let summary = round.summary
        let right = round.firstOutcome.values.filter { $0 != .missed }.count
        let score = Double(right) / Double(max(1, round.initialCount))
        return VStack(spacing: 18) {
            Spacer()
            Mascot(mood: summary.missed == 0 ? .cheer : .happy, size: 96)
                .popIn(delay: 0.2)
            Text(L.t("這一輪完成！", "Round complete!"))
                .font(.display(.title, weight: .bold))
                .entrance(0)
            HStack(spacing: 10) {
                stat(L.t("本來就會", "Knew already"), summary.alreadyKnew, Palette.known)
                stat(L.t("新學", "Learned"), summary.learned, Palette.accent)
                stat(L.t("複習", "Reviewed"), summary.reviewed, Palette.chinese)
            }
            .entrance(1)
            if summary.alreadyKnew > 0 {
                Text(L.t("你本來就會的 \(summary.alreadyKnew) 個字，我直接幫你往後排了。",
                         "The \(summary.alreadyKnew) you already knew move further out."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .entrance(2)
            }
            if summary.missed > 0 {
                Text(L.t("有 \(summary.missed) 個字會比較快再出現。", "\(summary.missed) to see again soon."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .entrance(3)
            }
            Text(CatQuips.verdict(score, source: catLines))
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .entrance(4)
            Spacer()
            RoundEndActions(done: { dismiss() }, doneId: "cloze-done", again: { start() }, againId: "cloze-again")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cloze-results")
        .overlay(alignment: .top) {
            if summary.missed == 0, !reduceMotion { ConfettiBurst().allowsHitTesting(false) }
        }
    }

    private func stat(_ title: String, _ value: Int, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.displaySize(30, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(tint)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .card(radius: 18, padding: 14)
    }
}
