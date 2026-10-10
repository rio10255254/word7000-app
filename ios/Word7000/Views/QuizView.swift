import SwiftUI
import Word7000Core

struct QuizView: View {
    @Environment(AppModel.self) private var model
    var selectTab: (AppTab) -> Void
    var openBankPicker: () -> Void

    @State private var questions: [WordEntry] = []
    @State private var options: [QuizOption] = []
    @State private var index = 0
    @State private var chosen: QuizOption?
    @State private var correctCount = 0
    @State private var missedIds: [String] = []
    @State private var finished = false
    @State private var filtersOpen = false
    @State private var seed = SeededRandom.runtimeSeed()

    private var running: Bool { !questions.isEmpty && !finished }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if finished {
                    results
                } else if running, questions.indices.contains(index) {
                    question(questions[index])
                } else {
                    setup
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 24)
        }
        .background(Palette.background)
        .navigationTitle(L.tabQuiz)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if running {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.endQuiz) { reset() }
                        .accessibilityIdentifier("quiz-end")
                }
            } else {
                ToolbarItem(placement: .topBarLeading) {
                    BankButton(action: openBankPicker)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { filtersOpen = true } label: {
                        Image(systemName: model.settings.quizFilter.isActive
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel(L.filters)
                }
            }
        }
        .sheet(isPresented: $filtersOpen) {
            FilterSheet(selection: Binding(
                get: { model.settings.quizFilter },
                set: { model.settings.quizFilter = $0 }
            ), showsSort: false)
            .presentationDetents([.medium, .large])
        }
        .sensoryFeedback(trigger: chosen) { _, new in
            guard let new else { return nil }
            return new.correct ? .success : .error
        }
    }

    // MARK: Setup

    private var pool: [WordEntry] {
        model.bank.filter(state: model.progress, query: "", filter: model.settings.quizFilter.status, options: model.settings.quizFilter.options)
    }

    private var setup: some View {
        let count = pool.count
        return VStack(alignment: .leading, spacing: 14) {
            Text(L.questionCountTitle)
                .font(.rounded(.headline))
            Text(L.questionBank(count))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Picker(L.questionCountTitle, selection: Binding(
                get: { model.settings.quizQuestionCount },
                set: { model.settings.quizQuestionCount = $0 }
            )) {
                ForEach(QuizBuilder.questionCounts, id: \.self) { value in
                    Text(L.questionCount(value)).tag(value)
                }
            }
            .pickerStyle(.segmented)

            Button { start(from: pool) } label: {
                Label(L.startQuiz, systemImage: "checklist").font(.headline).frame(maxWidth: .infinity)
            }
            .prominentAction()
            .disabled(count == 0)
            .accessibilityIdentifier("quiz-start")

            if count == 0 {
                Text(L.noQuizWords)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .card(padding: 18)
        .padding(.top, 8)
    }

    private func start(from words: [WordEntry]) {
        seed = SeededRandom.runtimeSeed()
        questions = QuizBuilder.session(words: words, count: model.settings.quizQuestionCount, seed: seed)
        index = 0
        correctCount = 0
        missedIds = []
        finished = false
        loadOptions()
    }

    private func loadOptions() {
        chosen = nil
        guard questions.indices.contains(index) else { return }
        // Distractors come from the whole bank so a small filtered pool still
        // gets four real choices.
        options = QuizBuilder.options(vocabulary: model.bank, wordId: questions[index].id, seed: seed)
    }

    private func reset() {
        questions = []
        finished = false
        chosen = nil
    }

    // MARK: Question

    private func question(_ word: WordEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 8) {
                HStack {
                    Text("\(index + 1) / \(questions.count)")
                        .font(.rounded(.subheadline, weight: .bold))
                        .monospacedDigit()
                    Spacer()
                }
                SessionBar(fraction: Double(index + (chosen == nil ? 0 : 1)) / Double(max(1, questions.count)))
            }
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: 16) {
                Text(L.quizPrompt)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline) {
                    Text(word.word)
                        .font(.roundedSize(38, weight: .bold))
                        .minimumScaleFactor(0.5)
                        .lineLimit(2)
                    Spacer()
                    SpeakButton(text: word.word)
                }
                VStack(spacing: 10) {
                    ForEach(Array(options.enumerated()), id: \.element) { offset, option in
                        optionButton(option, letter: ["A", "B", "C", "D"][min(offset, 3)])
                            .accessibilityIdentifier("quiz-option-\(offset)")
                    }
                }
            }
            .card(radius: Metrics.wordCardRadius, padding: 20)

            if let chosen {
                feedback(word: word, correct: chosen.correct)
            }
        }
    }

    private func optionButton(_ option: QuizOption, letter: String) -> some View {
        let answered = chosen != nil
        let isChosen = chosen == option
        let tint: Color = !answered ? Palette.accent : option.correct ? Palette.known : isChosen ? Palette.miss : .secondary
        return Button { answer(option) } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(answered && (option.correct || isChosen) ? tint : tint.opacity(0.14))
                    if answered && option.correct {
                        Image(systemName: "checkmark").font(.caption.weight(.heavy)).foregroundStyle(.white)
                    } else if answered && isChosen {
                        Image(systemName: "xmark").font(.caption.weight(.heavy)).foregroundStyle(.white)
                    } else {
                        Text(letter).font(.caption.weight(.bold)).foregroundStyle(tint)
                    }
                }
                .frame(width: 28, height: 28)
                Text(option.text)
                    .font(.body.weight(.medium))
                    .foregroundStyle(answered && !option.correct && !isChosen ? .secondary : .primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                answered && (option.correct || isChosen) ? tint.opacity(0.14) : Palette.fill,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(answered)
    }

    private func answer(_ option: QuizOption) {
        guard chosen == nil, questions.indices.contains(index) else { return }
        withAnimation(.snappy) { chosen = option }
        let wordId = questions[index].id
        model.recordQuizAnswer(wordId: wordId, correct: option.correct)
        if option.correct { correctCount += 1 } else { missedIds.append(wordId) }
    }

    private func feedback(word: WordEntry, correct: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(correct ? L.correctResult : L.wrongResult, systemImage: correct ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill")
                .font(.rounded(.headline))
                .foregroundStyle(correct ? Palette.known : Palette.review)
            if !correct {
                WordAnswer(word: word)
            }
            Button {
                if index + 1 >= questions.count {
                    withAnimation { finished = true }
                } else {
                    index += 1
                    loadOptions()
                }
            } label: {
                Label(index + 1 >= questions.count ? L.seeResults : L.nextQuestion, systemImage: "chevron.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .prominentAction()
            .accessibilityIdentifier("quiz-next")
        }
        .card(padding: 18)
    }

    // MARK: Results

    private var results: some View {
        VStack(spacing: 16) {
            ProgressRing(fraction: Double(correctCount) / Double(max(1, questions.count)), color: Palette.known, lineWidth: 11) {
                Text("\(Int((Double(correctCount) / Double(max(1, questions.count)) * 100).rounded()))%")
                    .font(.roundedSize(26, weight: .heavy))
                    .monospacedDigit()
            }
            .frame(width: 104, height: 104)
            Text(L.quizFinished).font(.rounded(.title2, weight: .bold))
            Text(L.quizScore(correctCount, questions.count)).foregroundStyle(.secondary)

            if !missedIds.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.quizMissedTitle(missedIds.count)).font(.subheadline.weight(.semibold))
                    ForEach(missedIds, id: \.self) { id in
                        if let word = model.word(id: id) {
                            HStack {
                                Text(word.word).font(.body.weight(.semibold))
                                Spacer()
                                Text(word.meaningZh).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                }
                .padding(14)
                .background(Palette.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button {
                    model.startStudySession(onlyIds: missedIds)
                    selectTab(.study)
                } label: {
                    Label(L.practiceMissed(missedIds.count), systemImage: "rectangle.on.rectangle.angled")
                        .font(.headline).frame(maxWidth: .infinity)
                }
                .prominentAction(tint: Palette.review)
            }

            Button { reset() } label: {
                Label(L.restartQuiz, systemImage: "arrow.clockwise").font(.headline).frame(maxWidth: .infinity)
            }
            .secondaryAction()
            .accessibilityIdentifier("quiz-restart")
        }
        .card(radius: Metrics.wordCardRadius, padding: 22)
        .padding(.top, 8)
        .accessibilityIdentifier("quiz-results")
    }
}
