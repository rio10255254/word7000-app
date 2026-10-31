import SwiftUI
import Word7000Core

/// Ten meanings to type the English word for. Return checks the answer and
/// return again moves on, so the keyboard stays up the whole session.
struct SpellingSessionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var studyMissed: ([String]) -> Void

    @State private var words: [WordEntry] = []
    @State private var index = 0
    @State private var input = ""
    @State private var hints = 0
    @State private var result: Spelling.Result?
    @State private var correctCount = 0
    @State private var missedIds: [String] = []
    @State private var started = false
    /// Counts misses so the answer field shakes on each one.
    @State private var misses = 0
    @State private var shownScore = 0
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if !started {
                    ProgressView()
                } else if words.isEmpty {
                    ContentUnavailableView { MascotLabel(mood: .encourage, title: L.noQuizWords) }
                } else if index >= words.count {
                    results
                } else {
                    question(words[index])
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
                        .accessibilityIdentifier("spelling-close")
                }
                ToolbarItem(placement: .principal) {
                    if started, index < words.count {
                        Text("\(index + 1) / \(words.count)")
                            .font(.display(.subheadline, weight: .semibold))
                            .monospacedDigit()
                            .accessibilityIdentifier("spelling-position")
                    }
                }
            }
        }
        .onAppear { if !started { start() } }
        .onDisappear { Speaker.shared.stop() }
        .sensoryFeedback(trigger: result) { _, new in
            guard let new, model.settings.hapticsEnabled ?? true else { return nil }
            return new == .correct ? .success : .error
        }
        .sensoryFeedback(.selection, trigger: hints) { _, new in new > 0 && (model.settings.hapticsEnabled ?? true) }
    }

    // MARK: Question

    private func question(_ word: WordEntry) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                BuddyProgressBar(fraction: Double(index + (result == nil ? 0 : 1)) / Double(max(1, words.count)),
                                 mood: result.map { outcome -> Mascot.Mood in outcome == .correct ? .happy : .encourage } ?? .thinking,
                                 hop: correctCount + misses)

                VStack(spacing: 8) {
                    if !word.partOfSpeech.isEmpty {
                        Text(word.partOfSpeech)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.accent)
                    }
                    Text(ChineseDisplay.conciseMeaning(word.meaningZh))
                        .font(.display(.title, weight: .bold))
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("spelling-meaning")
                    if result == nil {
                        // Each hint flips the next letter into place.
                        Text(Spelling.pattern(word.word, revealed: hints))
                            .font(.system(.title3, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                            .accessibilityLabel(L.t("\(word.word.count) 個字母", "\(word.word.count) letters"))
                            .accessibilityIdentifier("spelling-pattern")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .entrance(0, distance: 10)
                .id(index)
                .overlay(alignment: .topTrailing) { SpeakButton(text: word.word, language: "en-US") }

                TextField(L.t("輸入英文單字", "Type the English word"), text: Binding(
                    get: { input },
                    set: { if result == nil { input = $0 } }
                ))
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .submitLabel(result == nil ? .done : .next)
                .focused($focused)
                .onSubmit { result == nil ? check() : next() }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(result.map(color) ?? (focused ? Palette.accent.opacity(0.45) : .clear), lineWidth: 2)
                )
                .shadow(color: (result.map(color) ?? .clear).opacity(0.35), radius: 10)
                .animation(reduceMotion ? nil : Motion.reveal, value: focused)
                // A miss shakes the field; getting it right makes it swell.
                .shake(trigger: misses, enabled: !reduceMotion)
                .pulse(trigger: correctCount, scale: 1.03, enabled: !reduceMotion)
                .accessibilityIdentifier("spelling-input")

                if let result {
                    feedback(result, word: word)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 12)))
                }
            }
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.never)
        .safeAreaInset(edge: .bottom) { actions(word) }
    }

    private func feedback(_ result: Spelling.Result, word: WordEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label {
                    Text(title(result))
                } icon: {
                    Image(systemName: symbol(result))
                        .popIn(delay: 0.1)
                }
                    .font(.headline)
                    .foregroundStyle(color(result))
                    .accessibilityIdentifier("spelling-result")
                Spacer()
                SpeakButton(text: word.word, language: "en-US")
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(word.word)
                    .font(.display(.title, weight: .bold))
                    .accessibilityIdentifier("spelling-answer")
                if !word.pronunciation.isEmpty {
                    Text(word.pronunciation).foregroundStyle(.secondary)
                }
                if result != .correct {
                    Text(L.t("你的答案：\(input.trimmed)", "You typed: \(input.trimmed)"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    if let note = WordNotes.note(for: word.word) {
                        Text(L.t(note.explanationZh, note.explanationEn)).font(.subheadline)
                    }
                }
            }
            if !word.example.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(word.example)
                    Text(word.exampleZh).font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 18, padding: 16)
    }

    private func actions(_ word: WordEntry) -> some View {
        HStack(spacing: 12) {
            if result == nil {
                Button {
                    withAnimation(reduceMotion ? nil : Motion.pop) { hints += 1 }
                } label: {
                    Label {
                        Text(L.t("提示", "Hint"))
                    } icon: {
                        Image(systemName: hints > 0 ? "lightbulb.fill" : "lightbulb")
                            .contentTransition(.symbolEffect(.replace))
                            .symbolEffect(.bounce, value: reduceMotion ? 0 : hints)
                    }
                    .font(.headline).frame(maxWidth: .infinity)
                }
                .secondaryAction()
                .disabled(hints >= Spelling.maxHints(word.word))
                .accessibilityIdentifier("spelling-hint")
                Button(action: check) {
                    Text(L.t("檢查", "Check")).font(.headline).frame(maxWidth: .infinity)
                }
                .prominentAction()
                .disabled(input.trimmed.isEmpty)
                .accessibilityIdentifier("spelling-check")
            } else {
                Button(action: next) {
                    Text(index + 1 >= words.count ? L.seeResults : L.nextQuestion).font(.headline).frame(maxWidth: .infinity)
                }
                .prominentAction(tint: result == .correct ? Palette.known : Palette.accent)
                .accessibilityIdentifier("spelling-next")
            }
        }
        .padding(.vertical, 8)
        .background { Palette.background.overlay { PaperGrain() } }
    }

    private func title(_ result: Spelling.Result) -> String {
        switch result {
        case .correct: hints >= 2 ? L.t("拼對了（用了提示）", "Correct, with hints") : L.t("拼對了！", "Correct!")
        case .almost: L.t("差一個字母", "One letter off")
        case .wrong: L.t("正確拼法", "The spelling is")
        }
    }

    private func symbol(_ result: Spelling.Result) -> String {
        switch result {
        case .correct: "checkmark.circle.fill"
        case .almost: "exclamationmark.circle.fill"
        case .wrong: "xmark.circle.fill"
        }
    }

    private func color(_ result: Spelling.Result) -> Color {
        switch result {
        case .correct: Palette.known
        case .almost: Palette.review
        case .wrong: Palette.miss
        }
    }

    // MARK: Flow

    private func start() {
        Speaker.shared.stop()
        words = model.spellingQuestions(seed: SeededRandom.runtimeSeed())
        index = 0
        input = ""
        hints = 0
        result = nil
        correctCount = 0
        missedIds = []
        shownScore = 0
        started = true
        Task {
            // The cover must finish presenting before the keyboard can rise.
            try? await Task.sleep(for: .milliseconds(450))
            focused = true
        }
    }

    private func check() {
        guard result == nil, words.indices.contains(index), !input.trimmed.isEmpty else { return }
        let word = words[index]
        let outcome = Spelling.check(input, word: word.word)
        withAnimation(reduceMotion ? nil : Motion.reveal) { result = outcome }
        model.recordSpellingAnswer(wordId: word.id, result: outcome, hints: hints)
        if outcome == .correct { correctCount += 1 } else { missedIds.append(word.id); misses += 1 }
    }

    private func next() {
        guard result != nil else { return }
        Speaker.shared.stop()
        input = ""
        hints = 0
        result = nil
        index += 1
        if index >= words.count { focused = false }
    }

    // MARK: Results

    private var results: some View {
        VStack(spacing: 18) {
            Spacer()
            ProgressRing(fraction: Double(correctCount) / Double(max(1, words.count)), color: Palette.known, lineWidth: 14) {
                Text("\(reduceMotion ? correctCount : shownScore)/\(words.count)")
                    .font(.displaySize(30, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(shownScore)))
                    .accessibilityLabel("\(correctCount)/\(words.count)")
            }
            .frame(width: 130, height: 130)
            .overlay(alignment: .topTrailing) {
                Mascot(mood: Mascot.Mood(score: Double(correctCount) / Double(max(1, words.count))), size: 64)
                    .offset(x: 44, y: -22)
                    .popIn(delay: 0.5)
            }
            .entrance(0)
            Text(L.t("拼字練習完成", "Spelling complete")).font(.display(.title, weight: .bold))
                .entrance(1)
            Text(missedIds.isEmpty ? L.quizPerfect : L.quizMissedHint(missedIds.count))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .entrance(2)
            Spacer()
            VStack(spacing: 12) {
                if missedIds.isEmpty {
                    Button { dismiss() } label: {
                        Text(L.done).font(.headline).frame(maxWidth: .infinity)
                    }
                    .prominentAction()
                } else {
                    Button { studyMissed(missedIds) } label: {
                        Text(L.practiceMissed(missedIds.count)).font(.headline).frame(maxWidth: .infinity)
                    }
                    .prominentAction(tint: Palette.review)
                }
                Button { start() } label: {
                    Text(L.nextSession).font(.headline).frame(maxWidth: .infinity)
                }
                .secondaryAction()
                .accessibilityIdentifier("spelling-again")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("spelling-results")
        .overlay(alignment: .top) {
            if missedIds.isEmpty, !reduceMotion { ConfettiBurst().allowsHitTesting(false) }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) { shownScore = correctCount }
        }
    }
}
