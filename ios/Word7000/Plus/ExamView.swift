import SwiftUI
import Word7000Core

/// Exam practice (Plus): 50 questions against the clock, no feedback until
/// the end, then a score by level and the missed words to review.
struct ExamView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    /// Which way the questions slide: forward after an answer or Next, back with the chevron.
    @State private var forward = true
    /// The last minute: the clock turns red and its icon pulses.
    @State private var hurry = false
    @State private var shownScore = 0
    @State private var barsFilled = false

    private var deadline: Date { startedAt.addingTimeInterval(Double(Self.minutes) * 60) }

    var body: some View {
        NavigationStack {
            Group {
                if questions.isEmpty {
                    ContentUnavailableView { MascotLabel(mood: .encourage, title: L.noQuizWords) }
                } else if finished {
                    results
                } else {
                    question
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background { AmbientBackground(tint: Palette.review) }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(L.close)
                        .accessibilityIdentifier("exam-close")
                }
                ToolbarItem(placement: .principal) {
                    if !finished, !questions.isEmpty {
                        Label {
                            Text(timerInterval: startedAt...deadline, countsDown: true)
                                .monospacedDigit()
                        } icon: {
                            Image(systemName: "timer")
                                .symbolEffect(.pulse, options: .repeating, isActive: hurry && !reduceMotion)
                        }
                        .labelStyle(.titleAndIcon)
                        .font(.display(.subheadline, weight: .semibold))
                        .foregroundStyle(hurry ? Palette.miss : Color.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background((hurry ? Palette.miss : Color.clear).opacity(0.12), in: Capsule())
                        .animation(reduceMotion ? nil : Motion.reveal, value: hurry)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !finished, !questions.isEmpty {
                        Button(L.t("交卷", "Submit")) { submit() }
                            .accessibilityIdentifier("exam-submit")
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
        .task(id: startedAt) {
            hurry = false
            let untilLastMinute = deadline.timeIntervalSinceNow - 60
            if untilLastMinute > 0 { try? await Task.sleep(for: .seconds(untilLastMinute)) }
            if !Task.isCancelled, !finished { hurry = true }
        }
        .sensoryFeedback(.warning, trigger: hurry) { _, new in new && (model.settings.hapticsEnabled ?? true) }
        .sensoryFeedback(.selection, trigger: answers.count) { old, new in new > old && (model.settings.hapticsEnabled ?? true) }
    }

    private func start() {
        seed = SeededRandom.runtimeSeed()
        questions = QuizBuilder.session(words: model.bank.words, count: Self.questionCount, seed: seed)
        options = questions.map { QuizBuilder.options(vocabulary: model.bank, wordId: $0.id, seed: seed, mode: model.quizMode, concise: true) }
        answers = [:]
        index = 0
        forward = true
        shownScore = 0
        barsFilled = false
        finished = false
        startedAt = Date()
    }

    // MARK: Question

    private var question: some View {
        let word = questions[index]
        let face = model.face(word)
        return VStack(spacing: 16) {
          ScrollView {
           VStack(spacing: 16) {
            BuddyProgressBar(fraction: Double(answers.count) / Double(max(1, questions.count)),
                             tint: Palette.review, mood: .thinking)
            Text("\(index + 1) / \(questions.count)")
                .font(.display(.footnote, weight: .semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText(value: Double(index)))
                .accessibilityIdentifier("exam-position")
            // The question and its options slide in together, from the side the learner is
            // heading; the ZStack lets the outgoing question overlap instead of stacking below.
            ZStack(alignment: .top) {
            VStack(spacing: 16) {
                Text(model.studyMode == .chinese ? (ChineseDisplay.meaningParts(word.meaningZh).first ?? face.prompt) : face.prompt)
                    .font(.displaySize(38, weight: .bold))
                    .minimumScaleFactor(0.4)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 16)
                    .accessibilityIdentifier("exam-prompt")
                VStack(spacing: 10) {
                    ForEach(Array(options[index].enumerated()), id: \.element) { offset, option in
                        let chosen = answers[index] == option
                        Button {
                            answers[index] = option
                            if index + 1 < questions.count {
                                forward = true
                                withAnimation(reduceMotion ? nil : .snappy) { index += 1 }
                            }
                        } label: {
                            HStack {
                                Text(option.text).font(.body.weight(.medium)).multilineTextAlignment(.leading)
                                Spacer(minLength: 8)
                                if chosen {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Palette.accent)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(chosen ? Palette.accent.opacity(0.14) : Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(chosen ? Palette.accent.opacity(0.5) : .clear, lineWidth: 1.5)
                            }
                        }
                        .buttonStyle(SoftPressStyle())
                        .accessibilityIdentifier("exam-option-\(offset)")
                    }
                }
            }
            .id(index)
            .transition(questionTransition)
            }
           }
           .padding(.bottom, 8)
          }
          .scrollIndicators(.hidden)
            HStack(spacing: 12) {
                Button {
                    forward = false
                    withAnimation(reduceMotion ? nil : .snappy) { index = max(0, index - 1) }
                } label: {
                    Image(systemName: "chevron.left").font(.headline).frame(width: 30)
                }
                .secondaryAction(tint: .secondary)
                .disabled(index == 0)
                if index + 1 < questions.count {
                    Button {
                        forward = true
                        withAnimation(reduceMotion ? nil : .snappy) { index += 1 }
                    } label: {
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

    private var questionTransition: AnyTransition {
        if reduceMotion { return .opacity }
        let edge: Edge = forward ? .trailing : .leading
        let exit: Edge = forward ? .leading : .trailing
        return .asymmetric(insertion: .move(edge: edge).combined(with: .opacity),
                           removal: .move(edge: exit).combined(with: .opacity))
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

    private func scoreColor(_ score: Int) -> Color {
        score >= 80 ? Palette.known : score >= 60 ? Palette.accent : Palette.review
    }

    /// A word of praise or encouragement to go with the score.
    private func grade(_ score: Int) -> (text: String, icon: String) {
        switch score {
        case 90...: (L.t("太強了！", "Outstanding!"), "trophy.fill")
        case 80..<90: (L.t("表現很好", "Great work"), "star.fill")
        case 60..<80: (L.t("及格了，繼續加油", "You passed, keep going"), "hand.thumbsup.fill")
        default: (L.t("再接再厲", "Keep at it"), "arrow.up.right")
        }
    }

    private var results: some View {
        let total = questions.count
        let score = Int((Double(correctCount) / Double(max(1, total)) * 100).rounded())
        let badge = grade(score)
        return ScrollView {
            VStack(spacing: 18) {
                ProgressRing(fraction: Double(score) / 100, color: scoreColor(score), lineWidth: 14) {
                    VStack(spacing: 0) {
                        Text("\(reduceMotion ? score : shownScore)")
                            .font(.displaySize(40, weight: .bold))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(shownScore)))
                            .accessibilityLabel("\(score)")
                        Text(L.t("分", "points")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 140, height: 140)
                .overlay(alignment: .topTrailing) {
                    Mascot(mood: Mascot.Mood(score: Double(score) / 100), size: 64)
                        .offset(x: 44, y: -22)
                        .popIn(delay: 0.5)
                }
                .padding(.top, 12)
                .entrance(0)
                Label(badge.text, systemImage: badge.icon)
                    .font(.display(.subheadline, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(scoreColor(score).gradient, in: Capsule())
                    .shadow(color: scoreColor(score).opacity(0.35), radius: 8, y: 3)
                    .popIn(delay: 0.9)
                Text(L.t("答對 \(correctCount) / \(total) 題", "\(correctCount) of \(total) correct"))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("exam-summary")
                VStack(spacing: 8) {
                    ForEach(Array(byLevel.enumerated()), id: \.offset) { _, row in
                        let ratio = Double(row.correct) / Double(max(1, row.total))
                        HStack {
                            Text(row.level).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(row.correct) / \(row.total)").monospacedDigit().foregroundStyle(.secondary)
                        }
                        SessionBarTinted(fraction: barsFilled || reduceMotion ? ratio : 0,
                                         tint: ratio >= 0.8 ? Palette.known : ratio >= 0.6 ? Palette.accent : Palette.review)
                    }
                }
                .card(padding: 16)
                .entrance(2)
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
        .overlay(alignment: .top) {
            if score >= 80, !reduceMotion { ConfettiBurst().allowsHitTesting(false) }
        }
        .sensoryFeedback(.success, trigger: shownScore) { old, new in
            old == 0 && new >= 80 && (model.settings.hapticsEnabled ?? true)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85)) { shownScore = score }
            barsFilled = true
        }
    }
}
