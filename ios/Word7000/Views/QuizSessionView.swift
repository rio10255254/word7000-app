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
    @State private var finished = false
    @State private var seed = SeededRandom.runtimeSeed()
    @State private var configured = false

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
            .background(Palette.background)
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
                            .font(.rounded(.subheadline, weight: .semibold))
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
        .onDisappear { Speaker.shared.stop() }
        .sensoryFeedback(trigger: chosen) { _, new in
            guard let new, model.settings.hapticsEnabled ?? true else { return nil }
            return new.correct ? .success : .error
        }
    }

    private func start() {
        seed = SeededRandom.runtimeSeed()
        questions = model.quizQuestions(count: model.settings.quizQuestionCount, seed: seed)
        index = 0
        correctCount = 0
        missedIds = []
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
            SessionBar(fraction: Double(index + (chosen == nil ? 0 : 1)) / Double(max(1, questions.count)))
                .padding(.top, 4)

            VStack(spacing: 6) {
                Text(model.studyMode == .chinese ? (ChineseDisplay.meaningParts(word.meaningZh).first ?? face.prompt) : face.prompt)
                    .font(.roundedSize(42, weight: .bold))
                    .minimumScaleFactor(0.4)
                    .lineLimit(3)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .overlay(alignment: .topTrailing) { SpeakButton(text: face.speakText, language: face.speakLanguage) }

            VStack(spacing: 10) {
                ForEach(Array(options.enumerated()), id: \.element) { offset, option in
                    optionButton(option)
                        .accessibilityIdentifier("quiz-option-\(offset)")
                }
            }

            if let chosen {
                if !chosen.correct, let correct = options.first(where: \.correct) {
                    QuizWhyView(word: word,
                                question: model.studyMode == .chinese ? (ChineseDisplay.meaningParts(word.meaningZh).first ?? face.prompt) : face.prompt,
                                correctAnswer: correct.text, chosenAnswer: chosen.text)
                }
                if !face.examplePrimary.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(face.examplePrimary)
                        Text(face.exampleSecondary).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                .background(Palette.background)
            }
        }
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
                }
            }
            .foregroundStyle(answered && highlight == nil ? Color.secondary : Color.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                (highlight ?? Palette.surface).opacity(highlight == nil ? 1 : 0.16),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
        }
        .buttonStyle(SoftPressStyle())
        .allowsHitTesting(!answered)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    private func answer(_ option: QuizOption) {
        guard chosen == nil, questions.indices.contains(index) else { return }
        withAnimation(reduceMotion ? nil : Motion.reveal) { chosen = option }
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
                Text("\(correctCount)/\(questions.count)")
                    .font(.roundedSize(30, weight: .bold))
                    .monospacedDigit()
            }
            .frame(width: 130, height: 130)
            Text(L.quizFinished).font(.rounded(.title, weight: .bold))
            Text(missedIds.isEmpty ? L.quizPerfect : L.quizMissedHint(missedIds.count))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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
    }
}
