import SwiftUI
import Word7000Core

/// Ten short questions to answer out loud, each built around one word.
/// Nothing is recorded; the learner answers, then compares with a sample.
struct SpeakingSessionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var words: [WordEntry] = []
    @State private var index = 0
    @State private var revealed = false
    @State private var answered = 0
    @State private var started = false
    @State private var completedCurrent = false
    @State private var filtersOpen = false
    @State private var previousFilter = FilterSelection()

    private var activity: SpeakingPractice.Activity { model.settings.speakingActivity ?? .questions }
    private var examplesOnly: Bool { activity == .examples }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker(L.t("練習方式", "Practice type"), selection: Binding(
                    get: { activity }, set: { model.settings.speakingActivity = $0 }
                )) {
                    Text(L.t("情境問答", "Questions")).tag(SpeakingPractice.Activity.questions)
                    Text(L.t("例句延伸", "Examples")).tag(SpeakingPractice.Activity.examples)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("speaking-activity")
                .padding(.top, 4)
                scopePicker
                Group {
                    if !started {
                        ProgressView()
                    } else if words.isEmpty {
                        emptyScope
                    } else if index >= words.count {
                        finished
                    } else {
                        prompt(words[index])
                    }
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
                        .accessibilityIdentifier("speaking-close")
                }
                ToolbarItem(placement: .principal) {
                    if index < words.count {
                        Text("\(index + 1) / \(words.count)")
                            .font(.rounded(.subheadline, weight: .semibold))
                            .monospacedDigit()
                            .accessibilityIdentifier("speaking-position")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        previousFilter = model.settings.speakingFilter ?? FilterSelection()
                        filtersOpen = true
                    } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel(L.filters)
                    .accessibilityIdentifier("speaking-filters")
                }
            }
        }
        .onAppear { if !started { start() } }
        .onChange(of: activity) { _, _ in start() }
        .onChange(of: model.settings.activeBankId) { _, _ in start() }
        .onDisappear { Speaker.shared.stop() }
        .sensoryFeedback(.success, trigger: completedCurrent) { _, new in new && (model.settings.hapticsEnabled ?? true) }
        .sheet(isPresented: $filtersOpen, onDismiss: {
            if previousFilter != (model.settings.speakingFilter ?? FilterSelection()) { start() }
        }) {
            NavigationStack {
                Form {
                    Section {
                        FilterControls(selection: Binding(get: { model.settings.speakingFilter ?? FilterSelection() }, set: { model.settings.speakingFilter = $0 }))
                    }
                }
                .navigationTitle(L.t("練習範圍", "Practice scope"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L.done) { filtersOpen = false } } }
            }
        }
    }

    private var scopePicker: some View {
        HStack {
            Menu {
                Button { model.selectBank(WordBanks.coreBankId) } label: {
                    Label(L.coreBankName, systemImage: model.activeSet == nil ? "checkmark" : "character.book.closed")
                }
                ForEach(model.customSets.sets) { set in
                    Button { model.selectBank(set.id) } label: {
                        Label(set.name, systemImage: model.settings.activeBankId == set.id ? "checkmark" : "folder")
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "books.vertical")
                    Text(model.bankName).lineLimit(1)
                    Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
                }
                .font(.subheadline.weight(.medium))
            }
            .accessibilityIdentifier("speaking-bank")
            Spacer(minLength: 8)
            if (model.settings.speakingFilter ?? FilterSelection()).isActive {
                Image(systemName: "line.3.horizontal.decrease.circle.fill").foregroundStyle(Palette.accent)
                    .accessibilityLabel(L.filters)
            }
        }
        .frame(minHeight: 32)
    }

    private var emptyScope: some View {
        ContentUnavailableView {
            Label(examplesOnly ? L.noQuizWords : L.t("此範圍沒有情境題目", "No questions in this scope"),
                  systemImage: "bubble.left.and.text.bubble.right")
        } description: {
            Text(examplesOnly ? model.bankName : L.t("這個字庫或篩選範圍尚未有配對完成的情境問答。", "No reviewed conversation questions match this bank and its filters."))
        } actions: {
            if model.activeSet != nil {
                Button(L.coreBankName) {
                    model.selectBank(WordBanks.coreBankId)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("speaking-use-core")
            }
            if (model.settings.speakingFilter ?? FilterSelection()).isActive {
                Button(L.t("清除篩選", "Clear filters")) { model.settings.speakingFilter = FilterSelection(); start() }
                    .accessibilityIdentifier("speaking-clear-filters")
            }
            if !examplesOnly {
                Button(L.t("例句延伸", "Build on examples")) { model.settings.speakingActivity = .examples }
                    .accessibilityIdentifier("speaking-use-examples")
            }
        }
    }

    private func start() {
        Speaker.shared.stop()
        let candidates = model.speakingCandidates
        words = QuizBuilder.session(words: SpeakingPractice.candidates(from: candidates, activity: activity), count: 10)
        index = 0
        answered = 0
        revealed = false
        completedCurrent = false
        started = true
    }

    private func prompt(_ word: WordEntry) -> some View {
        let mode: ConversationPromptMode = model.studyMode == .english ? .english : .chinese
        let card = examplesOnly ? SpeakingPractice.exampleExercise(for: word, mode: mode)
            : (SpeakingPractice.card(for: word, mode: mode) ?? SpeakingPractice.exampleExercise(for: word, mode: mode))
        let face = model.face(word)
        return VStack(spacing: 16) {
            SessionBar(fraction: Double(index + (revealed ? 1 : 0)) / Double(max(1, words.count)))
                .padding(.top, 4)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(examplesOnly ? L.t("例句延伸", "Build on an example") : L.t("情境問答", "Conversation"))
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(card.keyword).font(.rounded(.title3, weight: .bold)).foregroundStyle(Palette.accent)
                            if !card.keywordPronunciation.isEmpty {
                                Text(card.keywordPronunciation).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        SpeakButton(text: card.keyword, language: face.speakLanguage)
                    }
                    if examplesOnly, !card.referenceAnswer.isEmpty {
                        Text(card.referenceAnswer).font(.title3).lineSpacing(4)
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text(card.question).font(.title2.weight(.semibold)).lineSpacing(4)
                            .accessibilityIdentifier("speaking-question")
                        SpeakButton(text: card.question, language: "en-US")
                    }
                    Text(card.questionSupport)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if revealed, !card.referenceAnswer.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Divider().padding(.bottom, 6)
                            HStack {
                                Text(examplesOnly ? L.t("例句與翻譯", "Example and translation") : L.sampleAnswer)
                                    .font(.caption.weight(.semibold)).foregroundStyle(Palette.accent)
                                Spacer()
                                SpeakButton(text: card.referenceAnswer, language: face.speakLanguage)
                            }
                            if !examplesOnly {
                                Text(card.referenceAnswer).lineSpacing(4).accessibilityIdentifier("speaking-reference-answer")
                            }
                            Text(card.referenceTranslation).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 12)))
                    }
                }
                .card(radius: Metrics.wordCardRadius, padding: 20)
            }
            if revealed {
              HStack(spacing: 12) {
                Button(action: next) {
                    Text(completedCurrent ? (index + 1 >= words.count ? L.seeResults : L.nextQuestion) : L.t("略過", "Skip"))
                        .font(.headline).frame(maxWidth: .infinity)
                }
                .prominentAction()
                .accessibilityIdentifier("speaking-next")
                if !completedCurrent {
                    Button { reveal(completed: true); next() } label: {
                        Text(L.t("練習完成", "Done")).font(.headline).frame(maxWidth: .infinity)
                    }
                    .prominentAction(tint: Palette.known)
                    .accessibilityIdentifier("speaking-complete-after-reference")
                }
              }
            } else {
                HStack(spacing: 12) {
                    Button { reveal(completed: false) } label: {
                        Text(examplesOnly ? L.t("看翻譯", "Translation") : L.showSample).font(.headline).frame(maxWidth: .infinity)
                    }
                    .secondaryAction()
                    .disabled(card.referenceAnswer.isEmpty)
                    .accessibilityIdentifier("speaking-show-reference")
                    Button { reveal(completed: true) } label: {
                        Text(L.spokeIt).font(.headline).frame(maxWidth: .infinity)
                    }
                    .prominentAction(tint: Palette.known)
                    .accessibilityIdentifier("speaking-complete")
                }
            }
        }
    }

    private func reveal(completed: Bool) {
        if completed, !completedCurrent {
            model.recordSpeaking(completed: true)
            answered += 1
            completedCurrent = true
        }
        withAnimation(reduceMotion ? nil : Motion.reveal) { revealed = true }
    }

    private func next() {
        guard index < words.count else { return }
        if !completedCurrent { model.recordSpeaking(completed: false) }
        Speaker.shared.stop()
        completedCurrent = false
        revealed = false
        index += 1
    }

    private var finished: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.system(size: 44))
                .foregroundStyle(Palette.known)
            Text(L.speakingFinished).font(.rounded(.title, weight: .bold))
            Text(L.speakingScore(answered)).foregroundStyle(.secondary)
            Spacer()
            Button { dismiss() } label: {
                Text(L.done).font(.headline).frame(maxWidth: .infinity)
            }
            .prominentAction()
        }
    }
}
