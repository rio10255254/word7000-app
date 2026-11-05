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
        .sensoryFeedback(trigger: solves) { _, _ in haptics ? .success : nil }
        .sensoryFeedback(trigger: misses) { _, new in new > 0 && haptics ? .error : nil }
    }

    // MARK: Question

    private func question(_ word: WordEntry, _ sentence: Cloze.Sentence, _ attempt: ClozeAttempt) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                BuddyProgressBar(fraction: Double(round.done + (attempt.solved ? 1 : 0)) / Double(max(1, round.total)),
                                 mood: attempt.solved ? .happy : (attempt.misses > 0 ? .encourage : .thinking),
                                 hop: solves + misses,
                                 remark: nil)

                card(word, sentence, attempt)

                if let message = message(word, attempt) {
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
                .onSubmit { attempt.solved ? next() : check() }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(focused ? Palette.accent.opacity(0.45) : .clear, lineWidth: 2)
                )
                .accessibilityIdentifier("cloze-input")
            }
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.never)
        .safeAreaInset(edge: .bottom) { actions(word, attempt) }
    }

    /// The question card: the Chinese sentence, then the English one with
    /// the blank. It floods green when solved.
    private func card(_ word: WordEntry, _ sentence: Cloze.Sentence, _ attempt: ClozeAttempt) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.wordCardRadius, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    if round.isSecondLook {
                        Label(L.t("再考一次", "Once more"), systemImage: "arrow.counterclockwise")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.review)
                    }
                    Spacer(minLength: 0)
                    if attempt.solved, let comeBack {
                        Text(comeBack)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.known)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Palette.known.opacity(0.16), in: Capsule())
                            .popIn(delay: 0.15)
                            .accessibilityIdentifier("cloze-comes-back")
                    }
                }
                chineseSentence(word)
                    .font(.title3)
                    .accessibilityIdentifier("cloze-chinese")
                if Cloze.cue(for: word) == nil {
                    // No marked part: say which word is wanted.
                    Text(ChineseDisplay.conciseMeaning(word.meaningZh))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Palette.accent.opacity(0.12), in: Capsule())
                }
                if !word.partOfSpeech.isEmpty {
                    Text(word.partOfSpeech)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().padding(.horizontal, 18)

            HStack(alignment: .top) {
                englishSentence(sentence, attempt)
                    .font(.title3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("cloze-sentence")
                if attempt.solved {
                    SpeakButton(text: word.example)
                }
            }
            .padding(18)
        }
        .background {
            shape.fill(Palette.surface)
                .overlay(shape.fill(attempt.solved ? Palette.known.opacity(0.16) : .clear))
        }
        .overlay(shape.stroke(border(attempt), lineWidth: 2))
        .overlay(alignment: .topLeading) {
            if attempt.solved {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Palette.known)
                    .rotationEffect(.degrees(-12))
                    .offset(x: -8, y: -14)
                    .popIn(delay: 0)
                    .accessibilityHidden(true)
            }
        }
        .animation(reduceMotion ? nil : Motion.reveal, value: attempt.solved)
        .shake(trigger: misses, enabled: !reduceMotion)
        .pulse(trigger: solves, scale: 1.02, enabled: !reduceMotion)
        .entrance(0, distance: 10)
        .id(round.index)
    }

    /// The translation with the word's part marked like a highlighter.
    private func chineseSentence(_ word: WordEntry) -> Text {
        guard let cue = Cloze.cue(for: word) else { return Text(word.exampleZh) }
        var marked = AttributedString(cue.cue)
        marked.backgroundColor = Palette.review.opacity(0.35)
        marked.foregroundColor = Palette.ink
        return Text(AttributedString(cue.before) + marked + AttributedString(cue.after))
    }

    /// The English sentence; each blank shows what is typed, the letters
    /// given, the answer to copy, or the answer once solved.
    private func englishSentence(_ sentence: Cloze.Sentence, _ attempt: ClozeAttempt) -> Text {
        var text = AttributedString()
        for piece in sentence.pieces {
            switch piece {
            case .text(let part):
                text += AttributedString(part)
            case .blank:
                text += blank(sentence.answer, attempt)
            }
        }
        return Text(text)
    }

    private func blank(_ answer: String, _ attempt: ClozeAttempt) -> AttributedString {
        let nbsp = "\u{00A0}"
        let content: String
        var tint = Palette.ink
        var fill = Palette.accent.opacity(0.12)
        if attempt.solved {
            content = answer
            tint = Palette.known
            fill = Palette.known.opacity(0.2)
        } else if attempt.answerShown {
            // The answer to copy, faint until it is typed.
            content = input.trimmed.isEmpty ? answer : input.trimmed
            tint = input.trimmed.isEmpty ? Palette.tertiaryLabel : Palette.ink
        } else if !input.trimmed.isEmpty {
            content = input.trimmed
        } else {
            content = Spelling.pattern(answer, revealed: attempt.lettersShown)
                .replacingOccurrences(of: " ", with: nbsp)
            tint = Palette.secondaryLabel
        }
        var blank = AttributedString(nbsp + content + nbsp)
        blank.foregroundColor = tint
        blank.backgroundColor = fill
        blank.underlineStyle = Text.LineStyle.single
        return blank
    }

    private func border(_ attempt: ClozeAttempt) -> Color {
        if attempt.solved { return Palette.known }
        if let verdict = attempt.lastVerdict, !verdict.isCorrect { return Palette.miss.opacity(0.6) }
        return .clear
    }

    /// What to say after a try that was not right, or when the answer is up.
    private func message(_ word: WordEntry, _ attempt: ClozeAttempt) -> (text: String, tint: Color)? {
        guard !attempt.solved else { return nil }
        if attempt.answerShown {
            return (L.t("看一下答案，自己打一次。", "Look at the answer, then type it yourself."), Palette.review)
        }
        guard let verdict = attempt.lastVerdict else { return nil }
        let wanted = Cloze.cue(for: word)?.cue ?? ChineseDisplay.conciseMeaning(word.meaningZh)
        switch verdict {
        case .correct:
            return nil
        case .otherForm:
            return (L.t("字對了！但這句要用另一個形式。", "Right word, but this sentence needs another form of it."), Palette.review)
        case .almost:
            return (L.t("差一個字母，再看一下。", "One letter off. Look again."), Palette.review)
        case .otherWord(let other, let meaning):
            let gloss = ChineseDisplay.conciseMeaning(meaning)
            return (L.t("\(other) 是「\(gloss)」。「\(wanted)」是哪個字？",
                        "\(other) means \u{201C}\(gloss)\u{201D}. Which word is \u{201C}\(wanted)\u{201D}?"), Palette.miss)
        case .wrong:
            return (L.t("不是這個字。再想想「\(wanted)」。", "Not that one. Think of \u{201C}\(wanted)\u{201D} again."), Palette.miss)
        }
    }

    private func actions(_ word: WordEntry, _ attempt: ClozeAttempt) -> some View {
        ButtonRow {
            if !attempt.solved {
                if let help = attempt.nextHelp {
                    Button(action: takeHelp) {
                        Label(help == .firstLetter ? L.t("第一個字母", "First letter") : L.t("看答案", "Show answer"),
                              systemImage: help == .firstLetter ? "lightbulb" : "eye")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .secondaryAction()
                    .accessibilityIdentifier("cloze-help")
                }
                Button(action: check) {
                    Text(L.t("檢查", "Check")).font(.headline).frame(maxWidth: .infinity)
                }
                .prominentAction()
                .disabled(input.trimmed.isEmpty)
                .accessibilityIdentifier("cloze-check")
            } else {
                Button(action: next) {
                    Text(finishesRound ? L.seeResults : L.nextQuestion)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .prominentAction(tint: Palette.known)
                .accessibilityIdentifier("cloze-next")
            }
        }
        .padding(.vertical, 8)
        .background { Palette.background.overlay { PaperGrain() } }
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
        if preview.comesBack(wordId) { return L.t("等一下再考你", "Back in a few questions") }
        let days = Cloze.daysUntil(LearningEngine.reviewDueDate(model.progress(for: wordId)), today: model.today) ?? 0
        switch days {
        case 0: return L.t("今天稍後再複習", "Again later today")
        case 1: return L.t("明天見", "See you tomorrow")
        default: return L.t("\(days) 天後見", "Back in \(days) days")
        }
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
            VStack(spacing: 12) {
                Button { dismiss() } label: {
                    Text(L.done).font(.headline).frame(maxWidth: .infinity)
                }
                .prominentAction()
                .accessibilityIdentifier("cloze-done")
                Button { start() } label: {
                    Text(L.nextSession).font(.headline).frame(maxWidth: .infinity)
                }
                .secondaryAction()
                .accessibilityIdentifier("cloze-again")
            }
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
