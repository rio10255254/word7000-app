import SwiftUI
import Word7000Core

/// Ten short questions to answer out loud, each built around one word.
/// Recording and text reflection are optional; the original practice stays available.
struct SpeakingSessionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var words: [WordEntry] = []
    @State private var index = 0
    @State private var revealed = false
    @State private var answered = 0
    @State private var started = false
    @State private var availableCount = 0
    @State private var completedCurrent = false
    @State private var finishedBounce = 0
    @State private var filtersOpen = false
    @State private var previousFilter = FilterSelection()
    @State private var historyOwnerKey = ""
    @State private var coachOpen = false
    @State private var coachAnswer = ""
    @State private var coachTranscriptNeedsReview = false
    @State private var coachContextID = UUID()
    @State private var coachSession = SpeakingCoachSession { request in
        try await AppleSpeakingCoach.shared.generate(request)
    }

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
                            .accessibilityValue(L.t("已完成 \(answered) 題", "Completed: \(answered)"))
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
        .onAppear {
            AppleSpeakingCoach.shared.refreshAvailability()
            if !started { start() }
        }
        .onChange(of: activity) { _, _ in start() }
        .onChange(of: model.settings.activeBankId) { _, _ in start() }
        .onChange(of: model.studyMode) { _, _ in start() }
        .onChange(of: model.settings.speakingFilter) { _, _ in clearCoach() }
        .onChange(of: model.speakingHistoryOwnerKey) { _, _ in start() }
        .onDisappear { coachSession.cancel(); Speaker.shared.stop() }
        .sensoryFeedback(.success, trigger: completedCurrent) { _, new in new && (model.settings.hapticsEnabled ?? true) }
        .sheet(isPresented: $coachOpen, onDismiss: {
            coachSession.cancel()
            Speaker.shared.stop()
        }) {
            if index < words.count {
                let word = words[index]
                let card = practiceCard(word)
                let meaning = examplesOnly ? ChineseDisplay.conciseMeaning(word.meaningZh)
                    : (SpeakingPractice.entry(for: word)?.keywordZh ?? ChineseDisplay.conciseMeaning(word.meaningZh))
                let contextID = coachContextID
                // Ignore a late keyboard commit from a dismissed account/card.
                let draft = Binding<String>(
                    get: { contextID == coachContextID ? coachAnswer : "" },
                    set: { if contextID == coachContextID { coachAnswer = $0 } }
                )
                SpeakingCoachView(needsTranscriptReview: Binding(
                    get: { contextID == coachContextID && coachTranscriptNeedsReview },
                    set: { if contextID == coachContextID { coachTranscriptNeedsReview = $0 } }
                ), request: SpeakingCoach.Request(
                    keyword: card.keyword,
                    meaning: model.studyMode == .english ? meaning : word.word,
                    question: card.question,
                    context: examplesOnly ? card.referenceAnswer : "",
                    answer: "",
                    mode: model.studyMode == .english ? .english : .chinese
                ), referenceAnswer: card.referenceAnswer, referenceTranslation: card.referenceTranslation,
                    answer: draft, session: coachSession)
                .id(contextID)
            }
        }
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
            Text(examplesOnly
                 ? L.t("\(availableCount) 個單字", "\(availableCount) \(availableCount == 1 ? "word" : "words")")
                 : L.t("\(availableCount) 題", "\(availableCount) \(availableCount == 1 ? "question" : "questions")"))
                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                .accessibilityIdentifier("speaking-available-count")
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
        clearCoach()
        Speaker.shared.stop()
        historyOwnerKey = model.speakingHistoryOwnerKey
        let candidates = model.speakingCandidates
        let available = SpeakingPractice.candidates(from: candidates, activity: activity)
        availableCount = available.count
        words = SpeakingPractice.session(from: available, recent: model.recentSpeakingIds, count: 10)
        index = 0
        answered = 0
        revealed = false
        completedCurrent = false
        started = true
    }

    private func clearCoach() {
        coachContextID = UUID()
        coachSession.reset()
        coachAnswer = ""
        coachTranscriptNeedsReview = false
        coachOpen = false
        Speaker.shared.stop()
    }

    private func practiceCard(_ word: WordEntry) -> ConversationPromptCard {
        let mode: ConversationPromptMode = model.studyMode == .english ? .english : .chinese
        return examplesOnly ? SpeakingPractice.exampleExercise(for: word, mode: mode)
            : (SpeakingPractice.card(for: word, mode: mode) ?? SpeakingPractice.exampleExercise(for: word, mode: mode))
    }

    private func prompt(_ word: WordEntry) -> some View {
        let card = practiceCard(word)
        let face = model.face(word)
        return VStack(spacing: 16) {
            SessionBar(fraction: Double(index + (revealed ? 1 : 0)) / Double(max(1, words.count)))
                .padding(.top, 4)
            ScrollView {
              VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    // The practice type is already chosen right above the card.
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(card.keyword).font(.rounded(.title3, weight: .bold)).foregroundStyle(Palette.accent)
                            if !card.keywordPronunciation.isEmpty {
                                Text(card.keywordPronunciation).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if completedCurrent {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title3)
                                .foregroundStyle(Palette.known)
                                .transition(reduceMotion ? .opacity : .scale(scale: 0.3).combined(with: .opacity))
                                .accessibilityLabel(L.t("已練習", "Practised"))
                        }
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
                // Each new question slides in from the side.
                .modifier(PromptArrival())
                .id(index)
                coachEntry
                    .modifier(PromptArrival(delay: 0.08))
                    .id("coach-\(index)")
              }
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

    /// Recording is part of answering, so it reads as the next step under the
    /// question rather than one more equal-weight button.
    private var coachEntry: some View {
        let suggests = AppleSpeakingCoach.shared.availability == .ready
        return Button {
            Speaker.shared.stop()
            AppleSpeakingCoach.shared.refreshAvailability()
            coachOpen = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Palette.accent)
                    .symbolEffect(.bounce, value: reduceMotion ? 0 : index)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.t("錄下你的回答", "Record your answer")).font(.headline)
                    Text(suggests ? L.t("回放、轉成文字，並取得 AI 建議", "Replay it, see it as text, and get AI suggestions")
                         : L.t("回放、轉成文字，自己檢查一遍", "Replay it and check it as text"))
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .card(radius: Metrics.wordCardRadius, padding: 16)
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityIdentifier("speaking-coach-open")
    }

    private func reveal(completed: Bool) {
        guard historyOwnerKey == model.speakingHistoryOwnerKey else { start(); return }
        if completed, !completedCurrent {
            model.recordSpeaking(completed: true)
            answered += 1
            withAnimation(reduceMotion ? nil : Motion.pop) { completedCurrent = true }
        }
        withAnimation(reduceMotion ? nil : Motion.reveal) { revealed = true }
    }

    private func next() {
        guard historyOwnerKey == model.speakingHistoryOwnerKey else { start(); return }
        guard index < words.count else { return }
        clearCoach()
        if !completedCurrent { model.recordSpeaking(completed: false) }
        model.noteSpeakingPractised(words[index].id)
        Speaker.shared.stop()
        completedCurrent = false
        revealed = false
        index += 1
    }

    private var finished: some View {
        VStack(spacing: 18) {
            Spacer()
            Mascot(mood: answered > 0 ? .cheer : .encourage, size: 104, hop: finishedBounce)
                .popIn()
            Text(L.speakingFinished).font(.rounded(.title, weight: .bold))
                .entrance(1)
            Text(L.speakingScore(answered)).foregroundStyle(.secondary)
                .entrance(2)
            Spacer()
            VStack(spacing: 12) {
                Button { dismiss() } label: {
                    Text(L.done).font(.headline).frame(maxWidth: .infinity)
                }
                .prominentAction()
                Button { start() } label: {
                    Text(L.nextSession).font(.headline).frame(maxWidth: .infinity)
                }
                .secondaryAction()
                .accessibilityIdentifier("speaking-again")
            }
        }
        .overlay(alignment: .top) {
            // Every question answered out loud earns a shower of paper.
            if !reduceMotion, !words.isEmpty, answered == words.count { ConfettiBurst().allowsHitTesting(false) }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(450))
            if !reduceMotion { finishedBounce += 1 }
        }
    }
}

/// Slides a question's card in from the side. It never starts fully
/// transparent, so it stays readable to VoiceOver while it moves.
private struct PromptArrival: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var delay: Double = 0
    @State private var arrived = false

    func body(content: Content) -> some View {
        let settled = arrived || reduceMotion
        return content
            .opacity(settled ? 1 : 0.3)
            .offset(x: settled ? 0 : 28)
            .onAppear {
                guard !arrived, !reduceMotion else { return }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85).delay(delay)) { arrived = true }
            }
    }
}
