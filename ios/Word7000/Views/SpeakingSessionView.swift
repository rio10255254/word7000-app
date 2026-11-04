import SwiftUI
import Word7000Core

/// One stage of the speaking path, five items in two steps each. First say a
/// model sentence after hearing it and see what came across; then answer out
/// loud in one's own words (read it, tap the big key, see it as text, have it
/// checked). The path runs through everyday scenarios (a restaurant, a shop,
/// the clinic…) as role-plays, where the item is what someone says to the
/// learner; the words of a word list can be practised the same way. A
/// cleared stage earns up to three stars, and the first of the day keeps the
/// streak going.
struct SpeakingSessionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// What a stage is made of: a scenario's role-play, or words from a list.
    enum Source: Equatable {
        case scenario(SpeakingScenarios.StageRef)
        case words
    }

    @State private var source: Source = .words
    @State private var words: [WordEntry] = []
    @State private var turns: [SpeakingScenarios.Turn] = []
    @State private var index = 0
    @State private var revealed = false
    @State private var answered = 0
    @State private var started = false
    @State private var availableCount = 0
    @State private var finishedBounce = 0
    @State private var filtersOpen = false
    @State private var scenariosOpen = false
    @State private var previousFilter = FilterSelection()
    @State private var historyOwnerKey = ""
    /// Something was said or written for this question: Next counts it.
    @State private var attempted = false
    /// The question was tapped for its translation in this practice, so the
    /// hint showing how is put away until the next practice.
    @State private var translationTried = false
    /// The current item is on its first step, saying the model sentence.
    @State private var shadowing = true
    /// Model sentences said well enough in this stage.
    @State private var shadowed = 0
    /// This item's model sentence was said, which counts as practice too.
    @State private var shadowedThisWord = false
    /// How the stage went, once it is over.
    @State private var stageResult: SpeakingPath.Result?
    @State private var bannerShown = false
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

    private var mode: ConversationPromptMode { model.studyMode == .english ? .english : .chinese }
    private var speakLanguage: String { model.studyMode == .english ? "en-US" : "zh-TW" }
    private var scenarioRef: SpeakingScenarios.StageRef? {
        if case .scenario(let ref) = source { ref } else { nil }
    }
    private var count: Int { scenarioRef == nil ? words.count : turns.count }

    /// "Stage 3 · Restaurant", or word practice.
    private var stageTitle: String {
        guard let ref = scenarioRef, let scenario = SpeakingScenarios.scenario(ref) else { return L.t("單字練習", "Word practice") }
        let number = SpeakingScenarios.number(ref)
        return L.t("第 \(number) 關 · \(scenario.title.zh)", "Stage \(number) · \(scenario.title.en)")
    }

    /// The stage's own name: "Getting a table and ordering".
    private var stageSubtitle: String {
        guard let ref = scenarioRef, let stage = SpeakingScenarios.stage(ref) else {
            return L.t("先跟著說，再用自己的話回答", "Say it after me, then in your own words")
        }
        return L.t(stage.title.zh, stage.title.en)
    }

    /// "Restaurant · Getting a table and ordering".
    private var stageCaption: String {
        guard let ref = scenarioRef, let scenario = SpeakingScenarios.scenario(ref) else { return stageSubtitle }
        return "\(L.t(scenario.title.zh, scenario.title.en)) · \(stageSubtitle)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Group {
                    if !started {
                        ProgressView()
                    } else if count == 0 {
                        emptyScope
                    } else if index >= count {
                        finished
                    } else {
                        prompt(at: index)
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
                    if index < count {
                        VStack(spacing: 0) {
                            Text(stageTitle)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Palette.accent)
                                .lineLimit(1)
                                .accessibilityIdentifier("speaking-stage")
                            Text("\(index + 1) / \(count)")
                                .font(.display(.subheadline, weight: .semibold))
                                .monospacedDigit()
                                .accessibilityIdentifier("speaking-position")
                                .accessibilityValue(L.t("已完成 \(answered) 題", "Completed: \(answered)"))
                        }
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if scenarioRef == nil {
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
                    Button { scenariosOpen = true } label: { Image(systemName: "map") }
                        .accessibilityLabel(L.t("所有情境", "All scenarios"))
                        .accessibilityIdentifier("speaking-scenarios")
                }
            }
        }
        .onAppear {
            AppleSpeakingCoach.shared.refreshAvailability()
            if !started { start(nil) }
        }
        .onChange(of: model.settings.activeBankId) { _, _ in if scenarioRef == nil { start(.words) } }
        .onChange(of: model.studyMode) { _, _ in start(source) }
        .onChange(of: model.settings.speakingFilter) { _, _ in clearCoach() }
        .onChange(of: model.speakingHistoryOwnerKey) { _, _ in start(nil) }
        .onDisappear { coachSession.cancel(); Speaker.shared.stop() }
        .sensoryFeedback(.success, trigger: attempted) { _, new in new && (model.settings.hapticsEnabled ?? true) }
        // Each new item is read aloud once (Settings → Reading voice): in a
        // role-play, what the other person says, then the reply to say after it.
        .task(id: "\(started)-\(index)-\(count)-\(shadowing)-\(String(describing: source))") {
            guard started, index < count, !AppRuntime.uiTesting,
                  model.settings.speech?.autoReadQuestions ?? true else { return }
            // The stage's opening banner goes first.
            do { try await Task.sleep(for: .milliseconds(index == 0 && shadowing ? 1500 : 450)) } catch { return }
            let card = card(at: index)
            let sentence = shadowSentence(card)
            let preferences = model.settings.speech ?? SpeechPreferences()
            let saying = shadowing && !sentence.isEmpty
            if scenarioRef != nil || !saying {
                Speaker.shared.speak(card.question, language: speakLanguage, preferences: preferences)
            }
            guard saying else { return }
            if scenarioRef != nil {
                // Wait for the line to finish (or be stopped) before the reply.
                for _ in 0..<60 {
                    do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
                    if Speaker.shared.activeText != card.question { break }
                }
                do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            }
            Speaker.shared.speak(sentence, language: speakLanguage, preferences: preferences)
        }
        .sheet(isPresented: $filtersOpen, onDismiss: {
            if previousFilter != (model.settings.speakingFilter ?? FilterSelection()) { start(.words) }
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
        .sheet(isPresented: $scenariosOpen) {
            ScenarioPickerView(progress: model.speakingPath, current: source) { picked in
                scenariosOpen = false
                start(picked)
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
                Button(L.t("清除篩選", "Clear filters")) { model.settings.speakingFilter = FilterSelection(); start(.words) }
                    .accessibilityIdentifier("speaking-clear-filters")
            }
        }
    }

    /// Starts a stage: the one given, or the path's next.
    private func start(_ requested: Source?) {
        clearCoach()
        Speaker.shared.stop()
        historyOwnerKey = model.speakingHistoryOwnerKey
        var next = requested ?? SpeakingScenarios.next(after: model.speakingPath).map(Source.scenario) ?? .words
        if case .scenario(let ref) = next, let stage = SpeakingScenarios.stage(ref) {
            turns = stage.turns
        } else {
            next = .words
            turns = []
            let candidates = model.speakingCandidates
            // Conversation questions and example sentences, mixed.
            availableCount = candidates.count
            let mixed = SpeakingPractice.mixedSession(from: candidates, recent: model.recentSpeakingIds, count: SpeakingPath.wordsPerStage)
            words = mixed.map(\.word)
            kinds = Dictionary(mixed.map { ($0.word.id, $0.activity) }, uniquingKeysWith: { first, _ in first })
        }
        source = next
        index = 0
        answered = 0
        revealed = false
        attempted = false
        translationTried = false
        shadowing = true
        shadowed = 0
        shadowedThisWord = false
        stageResult = nil
        bannerShown = false
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
        isExample(word) ? SpeakingPractice.exampleExercise(for: word, mode: mode)
            : (SpeakingPractice.card(for: word, mode: mode) ?? SpeakingPractice.exampleExercise(for: word, mode: mode))
    }

    private func card(at index: Int) -> ConversationPromptCard {
        scenarioRef == nil ? practiceCard(words[index]) : SpeakingScenarios.card(turns[index], mode: mode)
    }

    /// The model sentence said on an item's first step: the reply in a
    /// role-play, the opening of the sample answer, or the example sentence.
    private func shadowSentence(_ card: ConversationPromptCard) -> String {
        ShadowingCheck.sentence(from: card.referenceAnswer, chinese: model.studyMode == .chinese)
    }

    @ViewBuilder
    private func prompt(at index: Int) -> some View {
        let card = card(at: index)
        let sentence = shadowSentence(card)
        let turn = scenarioRef == nil ? nil : turns[index]
        if shadowing, !sentence.isEmpty {
            VStack(spacing: 16) {
                progressBar
                ShadowStepView(
                    keyword: card.keyword,
                    sentence: sentence,
                    translation: ShadowingCheck.sentence(from: card.referenceTranslation, chinese: model.studyMode != .chinese),
                    chinese: model.studyMode == .chinese,
                    partner: turn.map { ShadowStepView.Partner(role: $0.role.practised(mode), line: card.question, gloss: card.questionGloss ?? "") },
                    onDone: { said in
                        if said, !shadowedThisWord { shadowed += 1; shadowedThisWord = true }
                        withAnimation(reduceMotion ? nil : Motion.reveal) { shadowing = false }
                    }
                )
                .modifier(PromptArrival())
                .id("shadow-\(index)")
            }
            .overlay(alignment: .top) {
                if index == 0, !bannerShown {
                    StageBanner(title: scenarioRef.map { L.t("第 \(SpeakingScenarios.number($0)) 關", "Stage \(SpeakingScenarios.number($0))") } ?? stageTitle,
                                subtitle: stageCaption) { bannerShown = true }
                }
            }
        } else {
            answerPage(at: index, card: card, builtOnSentence: !sentence.isEmpty)
        }
    }

    /// Two steps an item: the bar moves half an item for each.
    private var progressBar: some View {
        let steps = Double(index * 2 + (shadowing ? 0 : 1) + (attempted ? 1 : 0))
        return BuddyProgressBar(fraction: steps / Double(max(1, count * 2)),
                                tint: Palette.known, mood: attempted || shadowedThisWord ? .happy : .thinking, hop: index)
    }

    /// What the item is about, above the question: the word with its meaning,
    /// or who is speaking in a role-play and the chunk the turn teaches.
    @ViewBuilder
    private func header(at index: Int, card: ConversationPromptCard) -> some View {
        if scenarioRef != nil {
            let turn = turns[index]
            VStack(alignment: .leading, spacing: 6) {
                Label(turn.role.practised(mode), systemImage: "person.wave.2.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.accent)
                    .accessibilityIdentifier("speaking-role")
                HStack(spacing: 6) {
                    Text(L.t("重點", "Key phrase")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(card.keyword).font(.subheadline.weight(.semibold))
                    if !card.keywordPronunciation.isEmpty {
                        Text(card.keywordPronunciation).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(turn.key.own(mode)).font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Palette.accent.opacity(0.1), in: Capsule())
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("speaking-keyword-meaning")
            }
        } else {
            let word = words[index]
            let face = model.face(word)
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
        }
    }

    private func answerPage(at index: Int, card: ConversationPromptCard, builtOnSentence: Bool) -> some View {
        let examplesOnly = scenarioRef == nil && isExample(words[index])
        return VStack(spacing: 16) {
            progressBar
            ScrollViewReader { proxy in
            ScrollView {
              VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        header(at: index, card: card)
                        Spacer()
                        if attempted {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title3)
                                .foregroundStyle(Palette.known)
                                .transition(reduceMotion ? .opacity : .scale(scale: 0.3).combined(with: .opacity))
                                .accessibilityLabel(L.t("已練習", "Practiced"))
                        }
                        if scenarioRef == nil { SpeakButton(text: card.keyword, language: speakLanguage) }
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
                        // Tapping the question turns it into the learner's own
                        // language and back; the first questions show how.
                        TranslatableQuestion(
                            question: card.question,
                            pinyin: model.studyMode == .chinese ? ChineseDisplay.sentencePinyin(card.question) : "",
                            translation: card.questionGloss,
                            showsHint: !translationTried,
                            onTranslate: { translationTried = true }
                        )
                        Spacer(minLength: 0)
                        SpeakButton(text: card.question, language: speakLanguage)
                    }
                    Text(card.questionSupport)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if builtOnSentence, !examplesOnly {
                        // The ladder's second rung: reuse the sentence just said.
                        Label(scenarioRef == nil
                              ? L.t("可以借用剛剛跟讀的句子，換成你自己的經驗。", "Borrow the sentence you just said and make it about you.")
                              : L.t("先用剛剛那句回答，再加上你自己的細節。", "Start from the reply you just said, then add your own details."),
                              systemImage: "arrow.turn.down.right")
                            .font(.footnote)
                            .foregroundStyle(Palette.accent)
                    }
                    if revealed, !card.referenceAnswer.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Divider().padding(.bottom, 6)
                            HStack {
                                Text(examplesOnly ? L.t("聽例句", "Listen to the example") : L.sampleAnswer)
                                    .font(.caption.weight(.semibold)).foregroundStyle(Palette.accent)
                                Spacer()
                                SpeakButton(text: card.referenceAnswer, language: speakLanguage)
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
                answerPanel(at: index, card: card, examplesOnly: examplesOnly, proxy: proxy)
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
                    Text(attempted ? (index + 1 >= count ? L.seeResults : L.nextQuestion) : L.t("跳過", "Skip"))
                        .font(.headline).frame(maxWidth: .infinity)
                }
                .modifier(NextKey(attempted: attempted))
                .accessibilityIdentifier("speaking-next")
            }
        }
    }

    /// Recording, the notepad, checking and the follow-up, under the question.
    private func answerPanel(at index: Int, card: ConversationPromptCard, examplesOnly: Bool, proxy: ScrollViewProxy) -> some View {
        // What the keyword means, for the coach: in the learner's language for
        // learners of English, the English for learners of Chinese.
        let meaning: String
        if scenarioRef != nil {
            meaning = turns[index].key.own(mode)
        } else {
            let word = words[index]
            let zh = examplesOnly ? ChineseDisplay.conciseMeaning(word.meaningZh)
                : (SpeakingPractice.entry(for: word)?.keywordZh ?? ChineseDisplay.conciseMeaning(word.meaningZh))
            meaning = model.studyMode == .english ? zh : word.word
        }
        let contextID = coachContextID
        // Ignore a late keyboard commit from a question already left.
        let draft = Binding<String>(
            get: { contextID == coachContextID ? coachAnswer : "" },
            set: { if contextID == coachContextID { coachAnswer = $0 } }
        )
        return SpeakingAnswerPanel(
            request: SpeakingCoach.Request(
                keyword: card.keyword,
                meaning: meaning,
                question: card.question,
                context: examplesOnly ? card.referenceAnswer : "",
                answer: "",
                mode: mode
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
        guard historyOwnerKey == model.speakingHistoryOwnerKey else { start(nil); return }
        guard index < count else { return }
        // Saying the model or answering is the practice; skipping is not.
        model.recordSpeaking(completed: attempted || shadowedThisWord)
        if attempted { answered += 1 }
        clearCoach()
        if scenarioRef == nil { model.noteSpeakingPractised(words[index].id) }
        Speaker.shared.stop()
        attempted = false
        revealed = false
        shadowing = true
        shadowedThisWord = false
        index += 1
        if index >= count {
            let result = SpeakingPath.Result(words: count, shadowed: shadowed, answered: answered)
            model.finishSpeakingStage(scenarioRef.map(SpeakingScenarios.key), result: result)
            stageResult = result
        }
    }

    private var finished: some View {
        let result = stageResult ?? SpeakingPath.Result(words: count, answered: answered)
        let path = model.speakingPath
        let streak = path.currentStreak(today: model.today)
        let ref = scenarioRef
        return VStack(spacing: 18) {
            Spacer()
            Mascot(mood: result.cleared ? .cheer : .encourage, size: 96, hop: finishedBounce)
                .popIn()
            VStack(spacing: 4) {
                Text(!result.cleared ? L.t("這關還沒過", "Not cleared yet")
                     : ref.map { L.t("第 \(SpeakingScenarios.number($0)) 關 過關！", "Stage \(SpeakingScenarios.number($0)) cleared!") }
                     ?? L.t("單字練習完成！", "Word practice done!"))
                    .font(.display(.title, weight: .bold))
                    .accessibilityIdentifier("speaking-stage-result")
                if ref != nil {
                    Text(stageCaption).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .entrance(1)
            StageStars(count: result.stars)
                .entrance(2)
            if result.cleared {
                if let ref { StagePathView(current: ref, progress: path).entrance(3) }
                Label(path.clearedToday(model.today)
                      ? L.t("今天的關卡完成 · 連續 \(streak) 天", "Today's stage done · \(streak)-day streak")
                      : L.t("連續 \(streak) 天", "\(streak)-day streak"),
                      systemImage: "flame.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Palette.accent.opacity(0.12), in: Capsule())
                    .entrance(4)
                    .accessibilityIdentifier("speaking-streak")
                Text(starHint(result)).font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .entrance(5)
            } else {
                CatVerdict(text: CatQuips.speakingDone(answered: 0), mood: .smug)
                    .padding(.horizontal, Metrics.gutter)
                    .entrance(3)
            }
            Spacer()
            VStack(spacing: 12) {
                Button {
                    // Next on the path; the same stage again when not cleared;
                    // another set of words in word practice.
                    let again: Source? = ref == nil ? .words : result.cleared ? nil : source
                    start(again)
                } label: {
                    Text(ref == nil ? L.nextSession : result.cleared ? L.t("下一關", "Next stage") : L.t("再試一次", "Try again"))
                        .font(.headline).frame(maxWidth: .infinity)
                }
                .prominentAction()
                .accessibilityIdentifier("speaking-again")
                Button { dismiss() } label: {
                    Text(result.cleared ? L.t("今天先到這裡", "That's it for today") : L.done)
                        .font(.headline).frame(maxWidth: .infinity)
                }
                .secondaryAction()
            }
        }
        .overlay(alignment: .top) {
            // Three stars earn a shower of paper.
            if !reduceMotion, result.stars == 3 { ConfettiBurst().allowsHitTesting(false) }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(450))
            if !reduceMotion { finishedBounce += 1 }
        }
    }

    /// How the stars missing from this stage are earned.
    private func starHint(_ result: SpeakingPath.Result) -> String {
        if result.stars == 3 { return L.t("滿分三顆星！", "All three stars!") }
        if result.shadowed < result.words {
            return L.t("每句都跟讀成功，可以多拿一顆星。", "Say every model sentence well for another star.")
        }
        return L.t("每題都開口回答，可以多拿一顆星。", "Answer every question for another star.")
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

/// The question, which turns over into the learner's own language when
/// tapped (and back on a second tap). Until the learner has tried it once in
/// a practice, a small tapping hand under the question shows how.
private struct TranslatableQuestion: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let question: String
    /// Shown under the question for learners of Chinese.
    let pinyin: String
    let translation: String?
    let showsHint: Bool
    let onTranslate: () -> Void

    @State private var translated = false

    private var canTranslate: Bool { !(translation ?? "").isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                if translated, let translation {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.t("中文翻譯", "In English"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.accent)
                        Text(translation).font(.title2.weight(.semibold)).lineSpacing(4)
                            .accessibilityIdentifier("speaking-question-gloss")
                            .accessibilityAction(named: L.t("看原文", "Show the original")) { toggle() }
                        Text(L.t("再點一下看英文原文", "Tap again for the Chinese"))
                            .font(.footnote).foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(flip(from: -90))
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(question).font(.title2.weight(.semibold)).lineSpacing(4)
                            .accessibilityIdentifier("speaking-question")
                            .accessibilityAction(named: L.t("看中文翻譯", "Show in English")) { toggle() }
                        if !pinyin.isEmpty {
                            Text(pinyin).font(.footnote).foregroundStyle(.secondary)
                                .accessibilityIdentifier("speaking-question-pinyin")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(flip(from: -90))
                }
            }
            .background {
                // A soft glow behind the question while the hint is showing.
                if hintVisible {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Palette.accent)
                        .padding(-6)
                        .phaseAnimator(reduceMotion ? [0.06] : [0.0, 0.1]) { glow, opacity in
                            glow.opacity(opacity)
                        } animation: { _ in .easeInOut(duration: 1.1) }
                        .accessibilityHidden(true)
                }
            }
            if hintVisible {
                hint.transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { toggle() }
        .sensoryFeedback(.selection, trigger: translated) { _, _ in model.settings.hapticsEnabled ?? true }
    }

    private var hintVisible: Bool { showsHint && canTranslate && !translated }

    /// A hand tapping, with what the tap does.
    private var hint: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.tap.fill")
                .phaseAnimator(reduceMotion ? [false] : [false, true, false]) { hand, pressed in
                    hand.scaleEffect(pressed ? 0.8 : 1).offset(y: pressed ? 2 : 0)
                } animation: { pressed in pressed ? .easeIn(duration: 0.18) : .spring(duration: 0.5) }
            Text(L.t("點一下題目，看中文翻譯", "Tap the question to read it in English"))
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Palette.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Palette.accent.opacity(0.12), in: Capsule())
        .accessibilityHidden(true)
    }

    private func toggle() {
        guard canTranslate else { return }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0.2)) {
            translated.toggle()
        }
        if translated { onTranslate() }
    }

    /// The face turns over like a card, both ways in the same direction; a
    /// plain fade with Reduce Motion.
    private func flip(from angle: Double) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .modifier(active: QuestionFlip(angle: angle), identity: QuestionFlip(angle: 0))
                .animation(.easeOut(duration: 0.2).delay(0.16)),
            removal: .modifier(active: QuestionFlip(angle: -angle), identity: QuestionFlip(angle: 0))
                .animation(.easeIn(duration: 0.16))
        )
    }
}

/// Turns a face about the horizontal axis, fading it as it goes edge-on.
private struct QuestionFlip: ViewModifier, Animatable {
    var angle: Double
    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
            .opacity(max(0, 1 - abs(angle) / 90))
    }
}
