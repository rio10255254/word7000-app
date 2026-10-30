import SwiftUI
import Word7000Core

/// Ten multiple-choice questions, started straight away.
struct QuizSessionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var studyMissed: ([String]) -> Void

    static let length = 10

    @State private var questions: [WordEntry] = []
    @State private var options: [QuizOption] = []
    @State private var index = 0
    @State private var chosen: QuizOption?
    @State private var correctCount = 0
    @State private var missedIds: [String] = []
    /// Right answers in a row; from three on the quiz cheers the run on.
    @State private var combo = 0
    /// The score on the results screen, counted up once it is shown.
    @State private var shownScore = 0
    @State private var finished = false
    @State private var seed = SeededRandom.runtimeSeed()
    @State private var configured = false
    /// A missed word opened for its AI explanation from the results.
    @State private var aiWord: WordEntry?

    var body: some View {
        NavigationStack {
            Group {
                if !configured {
                    QuizConfiguration(start: { start(); configured = true })
                } else if questions.isEmpty {
                    ContentUnavailableView(L.noQuizWords, systemImage: "checklist")
                } else if finished {
                    results
                } else if questions.indices.contains(index) {
                    question(questions[index])
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
                        .accessibilityIdentifier("quiz-close")
                }
                ToolbarItem(placement: .principal) {
                    if !finished, !questions.isEmpty {
                        Text("\(min(index + 1, questions.count)) / \(questions.count)")
                            .font(.display(.subheadline, weight: .semibold))
                            .monospacedDigit()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if chosen != nil, !finished {
                        Button(index + 1 >= questions.count ? L.seeResults : L.nextQuestion, action: next)
                            .fontWeight(.semibold)
                            .accessibilityIdentifier("quiz-next-toolbar")
                    }
                }
            }
        }
        .onDisappear {
            Speaker.shared.stop()
            model.cancelQuizOnTodaysWords()
        }
        .sensoryFeedback(trigger: chosen) { _, new in
            guard let new, model.settings.hapticsEnabled ?? true else { return nil }
            return new.correct ? .success : .error
        }
        .sensoryFeedback(.success, trigger: finished) { _, new in
            new && missedIds.isEmpty && (model.settings.hapticsEnabled ?? true)
        }
    }

    private func start() {
        seed = SeededRandom.runtimeSeed()
        questions = model.quizQuestions(count: model.settings.quizQuestionCount, seed: seed)
        index = 0
        correctCount = 0
        missedIds = []
        combo = 0
        shownScore = 0
        finished = false
        loadOptions()
    }

    private func loadOptions() {
        chosen = nil
        guard questions.indices.contains(index) else { return }
        options = QuizBuilder.options(vocabulary: model.bank, wordId: questions[index].id, seed: seed, mode: model.quizMode, concise: true)
    }

    // MARK: Question

    private func question(_ word: WordEntry) -> some View {
        let face = model.face(word)
        return ScrollView {
          VStack(spacing: 16) {
            SessionBar(fraction: Double(index + (chosen == nil ? 0 : 1)) / Double(max(1, questions.count)),
                       tint: combo >= 3 ? Palette.review : Palette.accent)
                // The run's badge floats just under the bar, clear of the question.
                .overlay(alignment: .topLeading) {
                    if combo >= 3 {
                        comboBadge
                            .offset(y: 12)
                            .transition(reduceMotion ? .opacity : .scale(scale: 0.5, anchor: .leading).combined(with: .opacity))
                    }
                }
                .padding(.top, 4)

            VStack(spacing: 6) {
                Text(model.studyMode == .chinese ? (ChineseDisplay.meaningParts(word.meaningZh).first ?? face.prompt) : face.prompt)
                    .font(.displaySize(42, weight: .bold))
                    .minimumScaleFactor(0.4)
                    .lineLimit(3)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .entrance(0, distance: 10)
            .overlay(alignment: .topTrailing) { SpeakButton(text: face.speakText, language: face.speakLanguage) }

            VStack(spacing: 10) {
                ForEach(Array(options.enumerated()), id: \.element) { offset, option in
                    optionButton(option)
                        .entrance(offset + 1, distance: 14)
                        .accessibilityIdentifier("quiz-option-\(offset)")
                }
            }

            if let chosen {
                if !chosen.correct, let correct = options.first(where: \.correct) {
                    QuizWhyView(word: word,
                                question: model.studyMode == .chinese ? (ChineseDisplay.meaningParts(word.meaningZh).first ?? face.prompt) : face.prompt,
                                correctAnswer: correct.text, chosenAnswer: chosen.text)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 12)))
                }
                if !face.examplePrimary.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(face.examplePrimary)
                        Text(face.exampleSecondary).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 12)))
                }
            }
          }
          .padding(.bottom, 16)
        }
        .id(index)
        .safeAreaInset(edge: .bottom) {
            if let chosen {
                Button(action: next) {
                    Text(index + 1 >= questions.count ? L.seeResults : L.nextQuestion)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .prominentAction(tint: chosen.correct ? Palette.known : Palette.accent)
                .accessibilityIdentifier("quiz-next")
                .padding(.vertical, 8)
                .background { Palette.background.overlay { PaperGrain() } }
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    /// "3 in a row", growing with each right answer while the run lasts.
    private var comboBadge: some View {
        Label {
            Text(L.t("連對 \(combo) 題", "\(combo) in a row"))
                .contentTransition(.numericText(value: Double(combo)))
        } icon: {
            Image(systemName: "flame.fill")
                .symbolEffect(.bounce, value: reduceMotion ? 0 : combo)
        }
        .font(.display(.caption, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(LinearGradient(colors: [Palette.review, Palette.miss], startPoint: .leading, endPoint: .trailing), in: Capsule())
        .shadow(color: Palette.review.opacity(0.4), radius: 6, y: 2)
        .fixedSize()
        .accessibilityIdentifier("quiz-combo")
    }

    private func optionButton(_ option: QuizOption) -> some View {
        let answered = chosen != nil
        let isChosen = chosen == option
        let highlight: Color? = !answered ? nil : option.correct ? Palette.known : isChosen ? Palette.miss : nil
        return Button { answer(option) } label: {
            HStack {
                Text(option.text)
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if let highlight {
                    Image(systemName: option.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(highlight)
                        .transition(.scale.combined(with: .opacity))
                        .symbolEffect(.bounce, value: reduceMotion ? false : answered)
                        // A right pick throws a little burst of light.
                        .overlay {
                            if isChosen, option.correct, !reduceMotion { SparkleBurst(color: Palette.known) }
                        }
                }
            }
            .foregroundStyle(answered && highlight == nil ? Color.secondary : Color.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if let highlight {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(highlight.opacity(0.16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(highlight.opacity(0.45), lineWidth: 1.5)
                        }
                } else {
                    PremiumSurface(radius: 18)
                }
            }
        }
        .buttonStyle(SoftPressStyle())
        // A wrong pick gives a small shake; the right answer swells a little either way.
        .shake(trigger: isChosen && !option.correct, enabled: !reduceMotion)
        .pulse(trigger: answered && option.correct, scale: 1.03, enabled: !reduceMotion)
        .allowsHitTesting(!answered)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    private func answer(_ option: QuizOption) {
        guard chosen == nil, questions.indices.contains(index) else { return }
        withAnimation(reduceMotion ? nil : Motion.reveal) {
            chosen = option
            combo = option.correct ? combo + 1 : 0
        }
        let wordId = questions[index].id
        model.recordQuizAnswer(wordId: wordId, correct: option.correct)
        if option.correct { correctCount += 1 } else { missedIds.append(wordId) }
    }

    private func next() {
        guard chosen != nil else { return }
        Speaker.shared.stop()
        if index + 1 >= questions.count {
            withAnimation { finished = true }
        } else {
            index += 1
            loadOptions()
        }
    }

    // MARK: Results

    private var results: some View {
        let fraction = Double(correctCount) / Double(max(1, questions.count))
        return VStack(spacing: 18) {
            Spacer()
            ProgressRing(fraction: fraction, color: Palette.known, lineWidth: 14) {
                Text("\(reduceMotion ? correctCount : shownScore)/\(questions.count)")
                    .font(.displaySize(30, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(shownScore)))
                    .accessibilityLabel("\(correctCount)/\(questions.count)")
            }
            .frame(width: 130, height: 130)
            .overlay(alignment: .topTrailing) {
                Mascot(mood: Mascot.Mood(score: fraction), size: 64)
                    .offset(x: 44, y: -22)
                    .popIn(delay: 0.5)
            }
            .entrance(0)
            Text(L.quizFinished).font(.display(.title, weight: .bold))
                .entrance(1)
            Text(missedIds.isEmpty ? L.quizPerfect : L.quizMissedHint(missedIds.count))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .entrance(2)
            if CloudAssistant.shared.offered, !missedIds.isEmpty {
                missedWordsForAI
                    .entrance(3)
            }
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
                    Text(L.anotherQuiz).font(.headline).frame(maxWidth: .infinity)
                }
                .secondaryAction()
                .accessibilityIdentifier("quiz-again")
            }
        }
        .accessibilityIdentifier("quiz-results")
        .overlay(alignment: .top) {
            // A clean sheet earns a shower of paper.
            if missedIds.isEmpty, !reduceMotion { ConfettiBurst().allowsHitTesting(false) }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) { shownScore = correctCount }
        }
        .sheet(item: $aiWord) { word in AIWordSheet(word: word) }
    }

    /// The words missed in this quiz, each opening its AI explanation.
    private var missedWordsForAI: some View {
        VStack(spacing: 8) {
            Label(L.t("點錯的字看 AI 解說", "Tap a missed word for its AI explanation"), systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.accent)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(missedIds.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }, id: \.self) { id in
                        if let word = model.word(id: id) {
                            Button { aiWord = word } label: {
                                Text(model.face(word).prompt)
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Palette.surface, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint(L.t("開啟 AI 解說", "Opens the AI explanation"))
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityIdentifier("quiz-missed-ai")
    }
}
