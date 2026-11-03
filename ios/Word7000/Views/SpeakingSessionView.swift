import SwiftUI
import Word7000Core

/// Ten short questions to answer out loud, each built around one word. Each
/// question is one page: read it (it is read aloud too), tap the big key and
/// say the answer, see it as text, have it checked, go on.
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
    @State private var finishedBounce = 0
    @State private var filtersOpen = false
    @State private var previousFilter = FilterSelection()
    @State private var historyOwnerKey = ""
    /// Something was said or written for this question: Next counts it.
    @State private var attempted = false
    @State private var coachAnswer = ""
    @State private var coachTranscriptNeedsReview = false
    @State private var coachContextID = UUID()
    @State private var coachSession = SpeakingCoachSession { request in
        try await AppleSpeakingCoach.shared.generate(request)
    }

    /// Which kind of prompt each word of this practice gets: a reviewed
    /// conversation question, or building on its example sentence.
    @State private var kinds: [String: SpeakingPractice.Activity] = [:]

    private func isExample(_ word: WordEntry) -> Bool {
        kinds[word.id] == .examples || SpeakingPractice.entry(for: word) == nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
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
            .background { AmbientBackground(tint: Palette.known) }
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
                            .font(.display(.subheadline, weight: .semibold))
                            .monospacedDigit()
                            .accessibilityIdentifier("speaking-position")
                            .accessibilityValue(L.t("已完成 \(answered) 題", "Completed: \(answered)"))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        previousFilter = model.settings.speakingFilter ?? FilterSelection()
                        filtersOpen = true
                    } label: {
                        // A dot shows the practice is narrowed to a word list or a filter.
                        Image(systemName: "slider.horizontal.3")
                            .overlay(alignment: .topTrailing) {
                                if scopeNarrowed {
                                    Circle().fill(Palette.accent).frame(width: 8, height: 8).offset(x: 4, y: -3)
                                }
                            }
                    }
                    .accessibilityLabel(L.filters)
                    .accessibilityValue(scopeNarrowed ? model.bankName : "")
                    .accessibilityIdentifier("speaking-filters")
                }
            }
        }
        .onAppear {
            AppleSpeakingCoach.shared.refreshAvailability()
            if !started { start() }
        }
        .onChange(of: model.settings.activeBankId) { _, _ in start() }
        .onChange(of: model.studyMode) { _, _ in start() }
        .onChange(of: model.settings.speakingFilter) { _, _ in clearCoach() }
        .onChange(of: model.speakingHistoryOwnerKey) { _, _ in start() }
        .onDisappear { coachSession.cancel(); Speaker.shared.stop() }
        .sensoryFeedback(.success, trigger: attempted) { _, new in new && (model.settings.hapticsEnabled ?? true) }
        // Each new question is read aloud once (Settings → Reading voice).
        .task(id: "\(started)-\(index)-\(words.count)") {
            guard started, index < words.count, !AppRuntime.uiTesting,
                  model.settings.speech?.autoReadQuestions ?? true else { return }
            do { try await Task.sleep(for: .milliseconds(450)) } catch { return }
            let card = practiceCard(words[index])
            Speaker.shared.speak(card.question, language: card.questionGloss == nil ? "en-US" : "zh-TW",
                                 preferences: model.settings.speech ?? SpeechPreferences())
        }
        .sheet(isPresented: $filtersOpen, onDismiss: {
            if previousFilter != (model.settings.speakingFilter ?? FilterSelection()) { start() }
        }) {
            NavigationStack {
                Form {
                    Group {
                        // Which word list, kept here rather than above every question.
                        Section {
                            scopePicker
                        } footer: {
                            Text(L.t("可練習 \(availableCount) 個單字", "\(availableCount) \(availableCount == 1 ? "word" : "words") to practise"))
                                .monospacedDigit()
                                .accessibilityIdentifier("speaking-available-count")
                        }
                        Section {
                            FilterControls(selection: Binding(get: { model.settings.speakingFilter ?? FilterSelection() }, set: { model.settings.speakingFilter = $0 }))
                        }
                    }
                    .listRowBackground(StyledRowBackground())
                }
                .warmList()
                .navigationTitle(L.t("練習範圍", "Practice scope"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L.done) { filtersOpen = false }.accessibilityIdentifier("speaking-filters-done") } }
                .compactSheet()
            }
        }
        .catTip(.speaking, at: .top, inset: 60)
    }

    private var scopeNarrowed: Bool {
        model.activeSet != nil || (model.settings.speakingFilter ?? FilterSelection()).isActive
    }

    private var scopePicker: some View {
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
            HStack(spacing: 8) {
                Label(L.t("詞庫", "Word list"), systemImage: "books.vertical").foregroundStyle(.primary)
                Spacer(minLength: 8)
                Text(model.bankName).lineLimit(1).foregroundStyle(.secondary)
                Image(systemName: "chevron.up.chevron.down").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            }
            .frame(minHeight: 44)
        }
        .accessibilityIdentifier("speaking-bank")
    }

    private var emptyScope: some View {
        ContentUnavailableView {
            MascotLabel(mood: .encourage, title: L.noQuizWords)
        } description: {
            Text(model.bankName)
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
        }
    }

    private func start() {
        clearCoach()
        Speaker.shared.stop()
        historyOwnerKey = model.speakingHistoryOwnerKey
        let candidates = model.speakingCandidates
        // One practice: conversation questions and example sentences, mixed.
        availableCount = candidates.count
        let mixed = SpeakingPractice.mixedSession(from: candidates, recent: model.recentSpeakingIds, count: 10)
        words = mixed.map(\.word)
        kinds = Dictionary(mixed.map { ($0.word.id, $0.activity) }, uniquingKeysWith: { first, _ in first })
        index = 0
        answered = 0
        revealed = false
        attempted = false
        started = true
    }

    private func clearCoach() {
        coachContextID = UUID()
        coachSession.reset()
        coachAnswer = ""
        coachTranscriptNeedsReview = false
        Speaker.shared.stop()
    }

    private func practiceCard(_ word: WordEntry) -> ConversationPromptCard {
        let mode: ConversationPromptMode = model.studyMode == .english ? .english : .chinese
        return isExample(word) ? SpeakingPractice.exampleExercise(for: word, mode: mode)
            : (SpeakingPractice.card(for: word, mode: mode) ?? SpeakingPractice.exampleExercise(for: word, mode: mode))
    }

    private func prompt(_ word: WordEntry) -> some View {
        let card = practiceCard(word)
        let examplesOnly = isExample(word)
        let face = model.face(word)
        return VStack(spacing: 16) {
            BuddyProgressBar(fraction: Double(index + (attempted ? 1 : 0)) / Double(max(1, words.count)),
                             tint: Palette.known, mood: attempted ? .happy : .thinking, hop: index)
            ScrollViewReader { proxy in
            ScrollView {
              VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    // The practice type is already chosen right above the card.
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(card.keyword).font(.display(.title3, weight: .bold)).foregroundStyle(Palette.accent)
                            if !card.keywordPronunciation.isEmpty {
                                Text(card.keywordPronunciation).foregroundStyle(.secondary)
                            }
                            // Part of speech and meaning, so the word can be used right.
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                // The word's own part of speech (the face's label names the
                                // answer's language when learning Chinese).
                                if !word.partOfSpeech.isEmpty {
                                    Text(word.partOfSpeech).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.accent.opacity(0.85))
                                }
                                Text(face.answer).font(.subheadline).foregroundStyle(.secondary)
                            }
                            .padding(.top, 2)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("speaking-keyword-meaning")
                        }
                        Spacer()
                        if attempted {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title3)
                                .foregroundStyle(Palette.known)
                                .transition(reduceMotion ? .opacity : .scale(scale: 0.3).combined(with: .opacity))
                                .accessibilityLabel(L.t("已練習", "Practiced"))
                        }
                        SpeakButton(text: card.keyword, language: face.speakLanguage)
                    }
                    if examplesOnly, !card.referenceAnswer.isEmpty {
                        // The example with its translation at once: the task is to
                        // build on it, so it has to be understood first.
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.referenceAnswer).font(.title3).lineSpacing(4)
                                .accessibilityIdentifier("speaking-reference-answer")
                            if !card.referenceTranslation.isEmpty {
                                Text(card.referenceTranslation).font(.subheadline).foregroundStyle(.secondary)
                                    .accessibilityIdentifier("speaking-example-translation")
                            }
                        }
                    }
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.question).font(.title2.weight(.semibold)).lineSpacing(4)
                                .accessibilityIdentifier("speaking-question")
                            // Learners of Chinese get the pinyin, and the English to check.
                            if model.studyMode == .chinese {
                                let pinyin = ChineseDisplay.sentencePinyin(card.question)
                                if !pinyin.isEmpty {
                                    Text(pinyin).font(.footnote).foregroundStyle(.secondary)
                                        .accessibilityIdentifier("speaking-question-pinyin")
                                }
                                if let gloss = card.questionGloss {
                                    Text(gloss).font(.footnote).foregroundStyle(.tertiary)
                                        .accessibilityIdentifier("speaking-question-gloss")
                                }
                            }
                        }
                        Spacer(minLength: 0)
                        SpeakButton(text: card.question, language: card.questionGloss == nil ? "en-US" : "zh-TW")
                    }
                    Text(card.questionSupport)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if revealed, !card.referenceAnswer.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Divider().padding(.bottom, 6)
                            HStack {
                                Text(examplesOnly ? L.t("聽例句", "Listen to the example") : L.sampleAnswer)
                                    .font(.caption.weight(.semibold)).foregroundStyle(Palette.accent)
                                Spacer()
                                SpeakButton(text: card.referenceAnswer, language: face.speakLanguage)
                            }
                            if !examplesOnly {
                                Text(card.referenceAnswer).lineSpacing(4).accessibilityIdentifier("speaking-reference-answer")
                                Text(card.referenceTranslation).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 12)))
                    }
                }
                .card(radius: Metrics.wordCardRadius, padding: 20)
                // Each new question slides in from the side.
                .modifier(PromptArrival())
                .id(index)
                answerPanel(word, card: card, examplesOnly: examplesOnly, proxy: proxy)
                    .modifier(PromptArrival(delay: 0.08))
                    .id(coachContextID)
              }
              .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            }
            // Two keys only: the sample answer, and on to the next question
            // (which counts this one once something was said or written).
            ButtonRow {
                Button {
                    withAnimation(reduceMotion ? nil : Motion.reveal) { revealed.toggle() }
                } label: {
                    Text(revealed ? L.t("收起參考", "Hide sample")
                         : examplesOnly ? L.t("聽例句", "Hear it") : L.showSample)
                        .font(.headline).frame(maxWidth: .infinity)
                }
                .secondaryAction()
                .disabled(card.referenceAnswer.isEmpty)
                .accessibilityIdentifier("speaking-show-reference")
                Button(action: next) {
                    Text(attempted ? (index + 1 >= words.count ? L.seeResults : L.nextQuestion) : L.t("跳過", "Skip"))
                        .font(.headline).frame(maxWidth: .infinity)
                }
                .modifier(NextKey(attempted: attempted))
                .accessibilityIdentifier("speaking-next")
            }
        }
    }

    /// Recording, the notepad, checking and the follow-up, under the question.
    private func answerPanel(_ word: WordEntry, card: ConversationPromptCard, examplesOnly: Bool, proxy: ScrollViewProxy) -> some View {
        let meaning = examplesOnly ? ChineseDisplay.conciseMeaning(word.meaningZh)
            : (SpeakingPractice.entry(for: word)?.keywordZh ?? ChineseDisplay.conciseMeaning(word.meaningZh))
        let contextID = coachContextID
        // Ignore a late keyboard commit from a question already left.
        let draft = Binding<String>(
            get: { contextID == coachContextID ? coachAnswer : "" },
            set: { if contextID == coachContextID { coachAnswer = $0 } }
        )
        return SpeakingAnswerPanel(
            request: SpeakingCoach.Request(
                keyword: card.keyword,
                meaning: model.studyMode == .english ? meaning : word.word,
                question: card.question,
                context: examplesOnly ? card.referenceAnswer : "",
                answer: "",
                mode: model.studyMode == .english ? .english : .chinese
            ),
            answer: draft,
            needsTranscriptReview: Binding(
                get: { contextID == coachContextID && coachTranscriptNeedsReview },
                set: { if contextID == coachContextID { coachTranscriptNeedsReview = $0 } }
            ),
            session: coachSession,
            scrollTo: { id in withAnimation(reduceMotion ? nil : Motion.reveal) { proxy.scrollTo(id, anchor: .top) } },
            onAttempt: {
                guard contextID == coachContextID, !attempted else { return }
                withAnimation(reduceMotion ? nil : Motion.pop) { attempted = true }
            }
        )
    }

    private func next() {
        guard historyOwnerKey == model.speakingHistoryOwnerKey else { start(); return }
        guard index < words.count else { return }
        // Saying or writing an answer is the practice; skipping is not.
        model.recordSpeaking(completed: attempted)
        if attempted { answered += 1 }
        clearCoach()
        model.noteSpeakingPractised(words[index].id)
        Speaker.shared.stop()
        attempted = false
        revealed = false
        index += 1
    }

    private var finished: some View {
        VStack(spacing: 18) {
            Spacer()
            Mascot(mood: answered > 0 ? .cheer : .encourage, size: 104, hop: finishedBounce)
                .popIn()
            Text(L.speakingFinished).font(.display(.title, weight: .bold))
                .entrance(1)
            Text(L.speakingScore(answered)).foregroundStyle(.secondary)
                .entrance(2)
            CatVerdict(text: CatQuips.speakingDone(answered: answered), mood: answered > 0 ? .happy : .smug)
                .padding(.horizontal, Metrics.gutter)
                .entrance(3)
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

/// Next is the main key once the question was answered, a quiet Skip before.
private struct NextKey: ViewModifier {
    var attempted: Bool

    func body(content: Content) -> some View {
        if attempted { content.prominentAction(tint: Palette.known) } else { content.secondaryAction() }
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
