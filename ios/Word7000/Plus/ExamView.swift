import SwiftUI
import Word7000Core

/// Exam practice (Plus): 50 questions against the clock, no feedback until
/// the end, then a score by level and the missed words to review.
struct ExamView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var studyMissed: ([String]) -> Void

    static let questionCount = 50
    static let minutes = 15

    @State private var questions: [WordEntry] = []
    @State private var options: [[QuizOption]] = []
    @State private var answers: [Int: QuizOption] = [:]
    @State private var index = 0
    @State private var startedAt = Date()
    @State private var finished = false
    @State private var seed = SeededRandom.runtimeSeed()

    private var deadline: Date { startedAt.addingTimeInterval(Double(Self.minutes) * 60) }

    var body: some View {
        NavigationStack {
            Group {
                if questions.isEmpty {
                    ContentUnavailableView(L.noQuizWords, systemImage: "timer")
                } else if finished {
                    results
                } else {
                    question
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
                }
                ToolbarItem(placement: .principal) {
                    if !finished, !questions.isEmpty {
                        Text(timerInterval: startedAt...deadline, countsDown: true)
                            .font(.rounded(.subheadline, weight: .semibold))
                            .monospacedDigit()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !finished, !questions.isEmpty {
                        Button(L.t("交卷", "Submit")) { submit() }
                    }
                }
            }
        }
        .onAppear { if questions.isEmpty { start() } }
        .task(id: startedAt) {
            // Hand in automatically when time runs out.
            let remaining = deadline.timeIntervalSinceNow
            if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
            if !Task.isCancelled, !finished, !questions.isEmpty { submit() }
        }
    }

    private func start() {
        seed = SeededRandom.runtimeSeed()
        questions = QuizBuilder.session(words: model.bank.words, count: Self.questionCount, seed: seed)
        options = questions.map { QuizBuilder.options(vocabulary: model.bank, wordId: $0.id, seed: seed, mode: model.quizMode) }
        answers = [:]
        index = 0
        finished = false
        startedAt = Date()
    }

    // MARK: Question

    private var question: some View {
        let word = questions[index]
        let face = model.face(word)
        return VStack(spacing: 16) {
            SessionBar(fraction: Double(answers.count) / Double(max(1, questions.count)))
                .padding(.top, 4)
            Text("\(index + 1) / \(questions.count)")
                .font(.rounded(.footnote, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(face.prompt)
                .font(.roundedSize(38, weight: .bold))
                .minimumScaleFactor(0.4)
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .padding(.vertical, 16)
            VStack(spacing: 10) {
                ForEach(Array(options[index].enumerated()), id: \.element) { _, option in
                    let chosen = answers[index] == option
                    Button {
                        answers[index] = option
                        if index + 1 < questions.count {
                            withAnimation(.snappy) { index += 1 }
                        }
                    } label: {
                        HStack {
                            Text(option.text).font(.body.weight(.medium)).multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            if chosen { Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.accent) }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(chosen ? Palette.accent.opacity(0.14) : Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                Button { withAnimation(.snappy) { index = max(0, index - 1) } } label: {
                    Image(systemName: "chevron.left").font(.headline).frame(width: 30)
                }
                .secondaryAction(tint: .secondary)
                .disabled(index == 0)
                if index + 1 < questions.count {
                    Button { withAnimation(.snappy) { index += 1 } } label: {
                        Text(L.t("下一題", "Next")).font(.headline).frame(maxWidth: .infinity)
                    }
                    .secondaryAction()
                } else {
                    Button { submit() } label: {
                        Text(L.t("交卷", "Submit")).font(.headline).frame(maxWidth: .infinity)
                    }
                    .prominentAction()
                }
            }
        }
    }

    private func submit() {
        guard !finished else { return }
        for (i, word) in questions.enumerated() {
            if let answer = answers[i] {
                model.recordQuizAnswer(wordId: word.id, correct: answer.correct)
            }
        }
        withAnimation { finished = true }
    }

    // MARK: Results

    private var correctCount: Int { answers.values.filter(\.correct).count }

    private var missedIds: [String] {
        questions.enumerated().compactMap { i, word in answers[i]?.correct == true ? nil : word.id }
    }

    /// Accuracy per level, in level order.
    private var byLevel: [(level: String, correct: Int, total: Int)] {
        var totals: [String: (Int, Int)] = [:]
        for (i, word) in questions.enumerated() {
            var entry = totals[word.group] ?? (0, 0)
            entry.1 += 1
            if answers[i]?.correct == true { entry.0 += 1 }
            totals[word.group] = entry
        }
        let order = WordData.levels(in: model.bank.words)
        return totals.map { (level: $0.key, correct: $0.value.0, total: $0.value.1) }
            .sorted { (order.firstIndex(of: $0.level) ?? 99) < (order.firstIndex(of: $1.level) ?? 99) }
    }

    private var results: some View {
        let total = questions.count
        let score = Int((Double(correctCount) / Double(max(1, total)) * 100).rounded())
        return ScrollView {
            VStack(spacing: 18) {
                ProgressRing(fraction: Double(score) / 100, color: score >= 80 ? Palette.known : score >= 60 ? Palette.accent : Palette.review, lineWidth: 14) {
                    VStack(spacing: 0) {
                        Text("\(score)").font(.roundedSize(40, weight: .bold)).monospacedDigit()
                        Text(L.t("分", "points")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 140, height: 140)
                .padding(.top, 12)
                Text(L.t("答對 \(correctCount) / \(total) 題", "\(correctCount) of \(total) correct"))
                    .foregroundStyle(.secondary)
                VStack(spacing: 8) {
                    ForEach(byLevel, id: \.level) { row in
                        HStack {
                            Text(row.level).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(row.correct) / \(row.total)").monospacedDigit().foregroundStyle(.secondary)
                        }
                        ProgressView(value: Double(row.correct), total: Double(max(1, row.total)))
                            .tint(Palette.accent)
                    }
                }
                .card(padding: 16)
                if !missedIds.isEmpty {
                    Button { studyMissed(missedIds) } label: {
                        Text(L.t("複習答錯的 \(missedIds.count) 個字", "Review the \(missedIds.count) missed words")).font(.headline).frame(maxWidth: .infinity)
                    }
                    .prominentAction(tint: Palette.review)
                }
                Button { start() } label: {
                    Text(L.t("再考一次", "Take another")).font(.headline).frame(maxWidth: .infinity)
                }
                .secondaryAction()
            }
        }
        .scrollIndicators(.hidden)
    }
}
