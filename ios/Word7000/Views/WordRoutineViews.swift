import SwiftUI
import Word7000Core

// WordCat Next: today's words as one routine. The flip cards come first
// (StudySessionView, unchanged); these screens follow them in the same cover:
// a short hand-off, spelling for the young words marked known, exam-style
// questions for the older ones, and one summary. Big type throughout, and the
// cat says what to do instead of small captions.

/// Where today's words are: "Step 2 of 3 · Spelling 1/6" above a bar of
/// equal parts, one per step. Steps done are green, the step under way fills
/// in the accent, the ones to come are empty.
struct RoutineStepStrip: View {
    /// The cat riding the part under way, as on a round's own bar.
    struct Rider {
        var mood: Mascot.Mood
        var hop: Int
        var remark: String?
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var routine: WordRoutine
    /// While the cards are being flipped: how far along.
    var flipped: (done: Int, total: Int)?
    /// While the cards are flipped, the cat rides their part of the strip, so
    /// the screen has one bar rather than the strip and a round's bar.
    var rider: Rider? = nil

    var body: some View {
        let parts = segments
        let current = parts.firstIndex { $0 < 1 } ?? max(0, parts.count - 1)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(L.t("第 \(current + 1) 步，共 \(parts.count) 步", "Step \(current + 1) of \(parts.count)"))
                    .foregroundStyle(Palette.secondaryLabel)
                Text("·").foregroundStyle(Palette.tertiaryLabel)
                Text(label).foregroundStyle(Palette.accent)
            }
            .font(.subheadline.weight(.bold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(parts.enumerated()), id: \.offset) { index, fill in
                    if index == current, let rider {
                        BuddyProgressBar(fraction: fill, mood: rider.mood, hop: rider.hop, size: 24,
                                         remark: rider.remark, barHeight: 8)
                            .frame(maxWidth: .infinity)
                            // The cat's remark runs past its part: over the parts after it, not under.
                            .zIndex(1)
                    } else {
                        GeometryReader { proxy in
                            Capsule().fill(Palette.fill)
                                .overlay(alignment: .leading) {
                                    Capsule().fill(fill >= 1 && index != current ? Palette.known : Palette.accent)
                                        .frame(width: max(fill > 0 ? 8 : 0, proxy.size.width * fill))
                                        // Each answer fills its part smoothly, as the cards' part does.
                                        .animation(reduceMotion ? nil : Motion.fill, value: fill)
                                }
                        }
                        .frame(height: 8)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.t("第 \(current + 1) 步，共 \(parts.count) 步，", "Step \(current + 1) of \(parts.count), ") + label)
        .accessibilityIdentifier("routine-steps")
    }

    /// How full each part is: cards, then spelling and the quiz when they come.
    private var segments: [Double] {
        let flip: Double = routine.step == .flip ? flipped.map { Double($0.done) / Double(max(1, $0.total)) } ?? 0 : 1
        var parts = [flip]
        if routine.step == .flip || !routine.spellIds.isEmpty {
            parts.append(routine.step == .spell ? Double(routine.spellResults.count) / Double(max(1, routine.spellIds.count))
                         : routine.step == .flip ? 0 : 1)
        }
        if routine.step == .flip || !routine.examIds.isEmpty {
            parts.append(routine.step == .exam ? Double(routine.examResults.count) / Double(max(1, routine.examIds.count))
                         : routine.step == .done ? 1 : 0)
        }
        return parts
    }

    private var label: String {
        switch routine.step {
        case .flip: return flipped.map { L.t("翻卡 \($0.done)/\($0.total)", "Cards \($0.done)/\($0.total)") } ?? L.t("翻卡", "Cards")
        case .spell: return L.t("拼字 \(routine.spellResults.count)/\(routine.spellIds.count)", "Writing \(routine.spellResults.count)/\(routine.spellIds.count)")
        case .exam: return L.t("考考看 \(routine.examResults.count)/\(routine.examIds.count)", "Quiz \(routine.examResults.count)/\(routine.examIds.count)")
        case .done: return L.t("完成", "Done")
        }
    }
}

/// After the flip cards, while checks are left: the hand-off into each
/// check step, then the step itself.
struct RoutineChecksView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    var routine: WordRoutine
    /// The step whose hand-off was tapped through.
    @State private var begun: WordRoutine.Step?

    var body: some View {
        switch routine.step {
        case .flip:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear { model.planRoutineChecks() }
        case .spell:
            if begun == .spell || !routine.spellResults.isEmpty {
                RoutineSpellView(routine: routine)
            } else {
                handOff(title: L.t("翻卡完成！", "Cards done!"),
                        line: model.learnsChinese
                            ? L.t("你說認識 \(routine.knownIds.count) 個字。\n我抽 \(routine.spellIds.count) 個，寫中文給我看。",
                                  "You said you know \(routine.knownIds.count).\nI'll pick \(routine.spellIds.count). Write them in Chinese.")
                            : L.t("你說認識 \(routine.knownIds.count) 個字。\n我抽 \(routine.spellIds.count) 個，寫給我看。",
                                  "You said you know \(routine.knownIds.count).\nI'll pick \(routine.spellIds.count). Spell them for me."),
                        action: model.learnsChinese ? L.t("開始寫字", "Start writing") : L.t("開始拼字", "Start spelling"), step: .spell)
            }
        case .exam:
            if begun == .exam || !routine.examResults.isEmpty {
                RoutineExamView(routine: routine)
            } else {
                handOff(title: routine.spellIds.isEmpty ? L.t("翻卡完成！", "Cards done!") : L.t("拼字完成！", "Spelling done!"),
                        line: L.t("這 \(routine.examIds.count) 個字你學過一陣子了。\n用\(model.examStyleName)考考看。",
                                  "You learned these \(routine.examIds.count) a while ago.\nTry them exam style."),
                        action: L.t("開始考考看", "Start the quiz"), step: .exam)
            }
        case .done:
            EmptyView()
        }
    }

    private func handOff(title: String, line: String, action: String, step: WordRoutine.Step) -> some View {
        VStack(spacing: 22) {
            RoutineStepStrip(routine: routine)
                .padding(.top, 8)
            Spacer(minLength: 0)
            Mascot(mood: .happy, size: 130)
                .popIn()
            Text(title)
                .font(.display(.largeTitle, weight: .bold))
                .entrance(1)
            Text(line)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .entrance(2)
            Spacer(minLength: 0)
            VStack(spacing: 12) {
                Button {
                    begun = step
                } label: {
                    Text(action).font(.title3.weight(.bold)).frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .prominentAction()
                // It starts by itself, the key filling meanwhile: one step
                // flows into the next as in a Duolingo lesson, and Not today
                // is still a tap away.
                .overlay { CountdownFillOverlay(active: autoStarts, seconds: Self.handOffSeconds) }
                .accessibilityIdentifier("routine-begin")
                Button {
                    model.skipRoutineChecks()
                } label: {
                    Text(L.t("今天先不考", "Not today")).font(.headline).frame(maxWidth: .infinity)
                }
                .secondaryAction()
                .accessibilityIdentifier("routine-skip")
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // A container: its buttons keep their own identifiers.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("routine-hand-off")
        .task(id: step) {
            guard autoStarts else { return }
            do { try await Task.sleep(for: .seconds(Self.handOffSeconds)) } catch { return }
            if begun != step { begun = step }
        }
    }

    private static let handOffSeconds = 2.6
    private var autoStarts: Bool { AutoAdvance.enabled && !voiceOver }
}

/// Spelling the young words marked known: the fill-in-the-blank card, one
/// word at a time, each answered once (a miss is caught, not repeated).
struct RoutineSpellView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var routine: WordRoutine

    @State private var wordId: String?
    @State private var attempt: ClozeAttempt?
    @State private var input = ""
    @State private var comeBack: String?
    @State private var lookup: [String: WordEntry] = [:]
    @State private var misses = 0
    @State private var solves = 0
    /// Right first time in a row, for the cat to notice.
    @State private var streak = 0
    /// A right answer moves on by itself after a moment; a touch holds it.
    @State private var advancing = false
    @FocusState private var focused: Bool

    private var haptics: Bool { model.settings.hapticsEnabled ?? true }

    var body: some View {
        Group {
            if let wordId, let word = model.word(id: wordId), let sentence = Cloze.sentence(for: word, chinese: model.learnsChinese), let attempt {
                question(word, sentence, attempt)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if lookup.isEmpty {
                lookup = Dictionary(model.vocabularyWords.map { (Spelling.normalized($0.word), $0) }, uniquingKeysWith: { first, _ in first })
            }
            if wordId == nil { load(routine.spellLeft.first) }
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                focused = true
            }
        }
        .modifier(AnswerFeedback(solves: solves, misses: misses, haptics: haptics))
        .task(id: advancing) {
            guard advancing else { return }
            do { try await Task.sleep(for: AutoAdvance.delay) } catch { return }
            guard advancing else { return }
            next()
        }
    }

    private func question(_ word: WordEntry, _ sentence: Cloze.Sentence, _ attempt: ClozeAttempt) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                RoutineCatLine(text: catLine(word, attempt), mood: attempt.solved ? (attempt.outcome == .missed ? .encourage : .cheer) : .thinking)
                ClozeCard(word: word, sentence: sentence, attempt: attempt, input: input, comeBack: comeBack, chinese: model.learnsChinese)
                    .shake(trigger: misses, enabled: !reduceMotion)
                    .pulse(trigger: solves, scale: 1.03, enabled: !reduceMotion)
                    .id(word.id)
                    .transition(.questionSwap(reduceMotion))
                    // A touch on the card holds the next question back.
                    .simultaneousGesture(TapGesture().onEnded { advancing = false })
            }
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.never)
        // The steps stay put above the question: in the scroll they slid
        // under the close key when the keyboard came up.
        .safeAreaInset(edge: .top, spacing: 12) {
            RoutineStepStrip(routine: model.activeRoutine ?? routine)
                .padding(.top, 4)
        }
        // The answer box sits on the buttons, right above the keyboard, so
        // it is never pushed under them.
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                // What was wrong sits right on the answer box, never scrolled under it.
                if let message = ClozeCard.message(for: word, attempt: attempt, chinese: model.learnsChinese) {
                    Text(message.text)
                        .font(.headline)
                        .foregroundStyle(message.tint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(message.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
                        .accessibilityIdentifier("routine-message")
                }
                inputField(attempt)
                actions(attempt)
            }
            .padding(.top, 8)
            .background { PaperBarBackground() }
        }
    }

    private func inputField(_ attempt: ClozeAttempt) -> some View {
        // A learner of Chinese writes the Chinese, on their own keyboard.
        TextField(model.learnsChinese ? L.t("輸入中文", "Type it in Chinese") : L.t("輸入英文單字", "Type the English word"), text: Binding(
            get: { input },
            set: { if !attempt.solved { input = $0 } }
        ))
        .font(.title.weight(.semibold))
        .multilineTextAlignment(.center)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .keyboardType(model.learnsChinese ? .default : .asciiCapable)
        .submitLabel(attempt.solved ? .next : .done)
        .focused($focused)
        .onSubmit {
            attempt.solved ? next() : check()
            keepKeyboard()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(focused ? Palette.accent.opacity(0.45) : .clear, lineWidth: 2))
        .accessibilityIdentifier("routine-input")
    }

    /// The cat asks with the Chinese cue, never the word itself.
    private func catLine(_ word: WordEntry, _ attempt: ClozeAttempt) -> String {
        if attempt.solved {
            if attempt.outcome == .knew, streak >= 3 {
                return L.t("連對 \(streak) 個！手感來了。", "\(streak) in a row! You're on a roll.")
            }
            switch attempt.outcome {
            case .knew: return L.t("真的會，算你厲害。", "You really know it. Fine.")
            case .gotIt: return L.t("有點危險喔，之後再考你。", "A little shaky. I'll check it again.")
            default: return L.t("抓到了！等一下再翻一次。", "Caught you! We'll flip it again.")
            }
        }
        if model.learnsChinese {
            // One gloss, the one marked in the sentence: not the whole entry.
            let gloss = ClozeCard.askedGloss(word)
            return L.t("「\(gloss)」你說你認識？寫中文給我看。", "You said you know \u{201C}\(gloss)\u{201D}? Write it in Chinese.")
        }
        let wanted = Cloze.cue(for: word)?.cue ?? ChineseDisplay.conciseMeaning(word.meaningZh)
        return L.t("「\(wanted)」你說你認識？寫給我看。", "You said you know \u{201C}\(wanted)\u{201D}? Spell it.")
    }

    private func helpTitle(_ help: ClozeAttempt.Help) -> String {
        guard help == .firstLetter else { return L.t("看答案", "Show answer") }
        return model.learnsChinese ? L.t("第一個字", "First character") : L.t("第一個字母", "First letter")
    }

    private func actions(_ attempt: ClozeAttempt) -> some View {
        ButtonRow {
            if !attempt.solved {
                if let help = attempt.nextHelp {
                    Button(action: takeHelp) {
                        Label(helpTitle(help), systemImage: help == .firstLetter ? "lightbulb" : "eye")
                            .font(.title3.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .secondaryAction()
                    .accessibilityIdentifier("routine-help")
                }
                Button(action: check) {
                    Text(L.t("檢查", "Check")).font(.title3.weight(.bold)).frame(maxWidth: .infinity)
                }
                .prominentAction()
                .disabled(input.trimmed.isEmpty)
                .accessibilityIdentifier("routine-check")
            } else {
                Button(action: next) {
                    Text(L.nextQuestion).font(.title3.weight(.bold)).frame(maxWidth: .infinity)
                }
                .prominentAction(tint: Palette.known)
                .overlay { CountdownFillOverlay(active: advancing) }
                .accessibilityIdentifier("routine-next")
            }
        }
        .padding(.bottom, 8)
    }

    private func load(_ id: String?) {
        input = ""
        comeBack = nil
        wordId = id
        guard let id else { model.advanceRoutine(); return }
        guard let word = model.word(id: id), let sentence = Cloze.sentence(for: word, chinese: model.learnsChinese) else {
            // A word that can no longer be asked (its sentence changed): the
            // next word marked known takes its place.
            model.replaceUnaskableCheck(id)
            load(model.activeRoutine?.spellLeft.first)
            return
        }
        attempt = ClozeAttempt(answer: sentence.answer)
    }

    /// Return resigns the field; it is focused again so the keyboard stays
    /// up for the next try and the next word.
    private func keepKeyboard() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            if wordId != nil { focused = true }
        }
    }

    private func takeHelp() {
        guard var current = attempt, !current.solved else { return }
        current.takeHelp()
        if current.answerShown { input = "" }
        withAnimation(reduceMotion ? nil : Motion.pop) { attempt = current }
    }

    private func check() {
        guard var current = attempt, !current.solved, let wordId, !input.trimmed.isEmpty else { return }
        let verdict = current.submit(input, lookup: { lookup[$0] })
        if verdict.isCorrect, let outcome = current.outcome {
            model.recordRoutineCheck(wordId: wordId, outcome: outcome, exam: false)
            let days = Cloze.daysUntil(LearningEngine.reviewDueDate(model.progress(for: wordId)), today: model.today) ?? 0
            comeBack = ClozeCard.comeBackLabel(days: days, inThisRound: false)
            solves += 1
            streak = outcome == .knew ? streak + 1 : 0
            // Right without the answer shown: on to the next by itself.
            advancing = AutoAdvance.enabled && outcome != .missed
        } else {
            misses += 1
            streak = 0
            if current.answerShown { input = "" }
        }
        withAnimation(reduceMotion ? nil : Motion.reveal) { attempt = current }
    }

    private func next() {
        guard attempt?.solved == true else { return }
        advancing = false
        Speaker.shared.stop()
        withAnimation(reduceMotion ? nil : Motion.swap) { load(model.activeRoutine?.spellLeft.first) }
    }
}

/// Exam-style questions on the older words marked known: the word's own
/// sentence with a blank and four look-alike words, the shape of the 學測
/// vocabulary section. One try each; the explanation shows what both the
/// chosen word and the answer mean.
struct RoutineExamView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var routine: WordRoutine

    @State private var wordId: String?
    @State private var question: ExamQuestion?
    @State private var chosen: Int?
    @State private var meanings: [String: String] = [:]
    @State private var advancing = false

    private var haptics: Bool { model.settings.hapticsEnabled ?? true }

    var body: some View {
        Group {
            if let question, let wordId, let word = model.word(id: wordId), question.wordId == wordId {
                content(word, question)
            } else {
                DelayedProgress()
            }
        }
        .onAppear {
            if meanings.isEmpty { meanings = ExamQuestionBody.meanings(model.coreWords, chinese: model.learnsChinese) }
            if wordId == nil { wordId = routine.examLeft.first ?? "" }
        }
        .task(id: wordId) { await load() }
        .sensoryFeedback(trigger: chosen) { _, new in
            guard let new, let question, haptics else { return nil }
            return new == question.answerIndex ? .success : .error
        }
        .soundEffect(trigger: chosen) { (_: Int?, new: Int?) -> SoundEffect? in
            guard let new, let question else { return nil }
            return new == question.answerIndex ? .correct : .wrong
        }
        .task(id: advancing) {
            guard advancing else { return }
            do { try await Task.sleep(for: AutoAdvance.delay) } catch { return }
            guard advancing else { return }
            next()
        }
    }

    private func content(_ word: WordEntry, _ question: ExamQuestion) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                RoutineCatLine(text: ExamQuestionBody.catLine(question, chosen: chosen, style: model.examStyleName),
                               mood: chosen == nil ? .thinking : chosen == question.answerIndex ? .cheer : .encourage)
                ExamQuestionBody(word: word, question: question, chosen: chosen, meanings: meanings,
                                 chinese: model.learnsChinese) { choose($0, question) }
                    .id(question.wordId)
                    .transition(.questionSwap(reduceMotion))
                if let chosen, chosen != question.answerIndex {
                    AskCatChip(word: word)
                        .transition(.opacity)
                }
            }
            .padding(.bottom, 16)
        }
        .revealsExplanation(after: chosen)
        .safeAreaInset(edge: .top, spacing: 12) {
            RoutineStepStrip(routine: model.activeRoutine ?? routine)
                .padding(.top, 4)
        }
        .safeAreaInset(edge: .bottom) {
            if chosen != nil {
                Button(action: next) {
                    Text(L.nextQuestion).font(.title3.weight(.bold)).frame(maxWidth: .infinity)
                }
                .prominentAction(tint: Palette.known)
                .overlay { CountdownFillOverlay(active: advancing) }
                .padding(.vertical, 8)
                .background { PaperBarBackground() }
                .accessibilityIdentifier("routine-next")
            }
        }
    }

    private func choose(_ index: Int, _ question: ExamQuestion) {
        guard chosen == nil, let wordId else { return }
        withAnimation(reduceMotion ? nil : Motion.reveal) { chosen = index }
        model.recordRoutineCheck(wordId: wordId, outcome: index == question.answerIndex ? .knew : .missed, exam: true)
        // Right: on to the next by itself. Wrong: wait, so the explanation is read.
        advancing = AutoAdvance.enabled && index == question.answerIndex
    }

    private func load() async {
        chosen = nil
        question = nil
        guard let wordId else { return }
        guard !wordId.isEmpty, let word = model.word(id: wordId) else { model.advanceRoutine(); return }
        let pool = await model.examPool()
        guard let built = ExamQuestions.make(for: word, pool: pool, seed: "\(routine.day):\(wordId)", style: model.examStyle) else {
            // Too few words could stand in for this one: the next word
            // marked known takes its place rather than it being waved through.
            model.replaceUnaskableCheck(wordId)
            self.wordId = model.activeRoutine?.examLeft.first ?? ""
            return
        }
        withAnimation(reduceMotion ? nil : Motion.swap) { question = built }
    }

    private func next() {
        advancing = false
        Speaker.shared.stop()
        wordId = model.activeRoutine?.examLeft.first ?? ""
    }
}

/// Once an answer is chosen, scrolls its explanation into view above the
/// Next key; on a small phone it would otherwise sit under it.
struct RevealsExplanation: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var chosen: Int?

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content.onChange(of: chosen) { _, now in
                guard now != nil else { return }
                Task { @MainActor in
                    // Once the explanation has come in.
                    try? await Task.sleep(for: .milliseconds(200))
                    withAnimation(reduceMotion ? nil : Motion.reveal) {
                        proxy.scrollTo(ExamQuestionBody.explanationId, anchor: .bottom)
                    }
                }
            }
        }
    }
}

extension View {
    func revealsExplanation(after chosen: Int?) -> some View { modifier(RevealsExplanation(chosen: chosen)) }
}

/// One exam-style question: the sentence with its blank, four big options
/// and, once one is chosen, what the answer and the chosen word mean. Used
/// by the routine's quiz step and by the quizzes outside it.
struct ExamQuestionBody: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var word: WordEntry
    var question: ExamQuestion
    var chosen: Int?
    /// Meanings by normalized spelling, for the explanation.
    var meanings: [String: String]
    /// A learner of Chinese: Chinese options, and the English sentence shown
    /// from the start, so the one word it says is the answer.
    var chinese = false
    var choose: (Int) -> Void

    /// For a learner of English the Chinese meaning of each word; for a
    /// learner of Chinese the English gloss of each Chinese word.
    static func meanings(_ words: [WordEntry], chinese: Bool = false) -> [String: String] {
        if chinese {
            return Dictionary(words.map { (Spelling.normalized(ExamQuestions.chineseForm($0)), $0.word) }, uniquingKeysWith: { first, _ in first })
        }
        return Dictionary(words.map { (Spelling.normalized($0.word), $0.meaningZh) }, uniquingKeysWith: { first, _ in first })
    }

    /// What the cat says above the question.
    static func catLine(_ question: ExamQuestion, chosen: Int?, style: String) -> String {
        guard let chosen else {
            if question.wordForm {
                return L.t("\(style)：這句要哪種詞性？選對的形式。", "\(style): which form does the sentence need?")
            }
            return L.t("\(style)：選出最適合的字。", "\(style): pick the word that fits.")
        }
        return chosen == question.answerIndex
            ? L.t("對！這種題目考試最愛。", "Right! Exams love this one.")
            : L.t("抓到了！這兩個字常被拿來一起考。", "Caught you! These two often come up together.")
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                sentence
                    .font(.title2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("routine-exam-sentence")
                if chinese {
                    Text(word.example)
                        .font(.title3)
                        .foregroundStyle(Palette.secondaryLabel)
                        .accessibilityIdentifier("routine-exam-english")
                } else if chosen != nil, let cue = Cloze.cue(for: word) {
                    Text(marked(cue))
                        .font(.title3)
                        .foregroundStyle(Palette.secondaryLabel)
                        .transition(.opacity)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(QuestionCardSurface())
            VStack(spacing: 10) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                    optionButton(index, option)
                }
            }
            if let chosen {
                explanation(chosen)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
                    .id(Self.explanationId)
            }
        }
    }

    static let explanationId = "exam-explanation"

    private var sentence: Text {
        var text = AttributedString()
        for piece in question.sentence.pieces {
            switch piece {
            case .text(let part): text += AttributedString(part)
            case .blank:
                var blank = AttributedString(chosen == nil ? "\u{00A0}______\u{00A0}" : "\u{00A0}\(question.answer)\u{00A0}")
                blank.foregroundColor = chosen == nil ? Palette.secondaryLabel : Palette.known
                blank.backgroundColor = chosen == nil ? Palette.accent.opacity(0.12) : Palette.known.opacity(0.2)
                text += blank
            }
        }
        return Text(text)
    }

    private func marked(_ cue: Cloze.Cue) -> AttributedString {
        var mark = AttributedString(cue.cue)
        mark.backgroundColor = Palette.review.opacity(0.35)
        mark.foregroundColor = Palette.ink
        return AttributedString(cue.before) + mark + AttributedString(cue.after)
    }

    private func optionButton(_ index: Int, _ option: String) -> some View {
        let letter = ["A", "B", "C", "D"][min(index, 3)]
        let isAnswer = index == question.answerIndex
        let tint: Color = chosen == nil ? Palette.accent : isAnswer ? Palette.known : index == chosen ? Palette.miss : Palette.secondaryLabel
        return Button {
            choose(index)
        } label: {
            HStack(spacing: 14) {
                Text(letter)
                    .font(.headline)
                    .foregroundStyle(chosen == nil ? Palette.accent : Palette.surface)
                    .frame(width: 36, height: 36)
                    .background(chosen == nil ? Palette.accent.opacity(0.12) : tint, in: Circle())
                Text(option)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
                if chosen != nil, isAnswer || index == chosen {
                    Image(systemName: isAnswer ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(tint)
                        .popIn()
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(chosen != nil && (isAnswer || index == chosen) ? tint.opacity(0.14) : Palette.surface,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(chosen != nil && (isAnswer || index == chosen) ? tint : Palette.separator, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .disabled(chosen != nil)
        .accessibilityLabel("\(letter). \(option)")
        .accessibilityIdentifier("routine-option-\(index)")
    }

    /// What the chosen word and the answer mean, so the difference sticks.
    private func explanation(_ chosen: Int) -> some View {
        let lines = (chosen == question.answerIndex ? [question.answerIndex] : [question.answerIndex, chosen]).map { index -> String in
            let option = question.options[index]
            let meaning = meanings[Spelling.normalized(option)].map { chinese ? $0 : ChineseDisplay.conciseMeaning($0) } ?? ""
            return meaning.isEmpty ? option : "\(option)\u{3000}\(meaning)"
        }
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(lines, id: \.self) { line in
                Text(line).font(.title3.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Palette.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier("routine-explanation")
    }
}

/// The end of today's words: what the learner already knew, learned and
/// reviewed, and the words a check caught, with a way to flip them again.
struct RoutineSummaryView: View {
    @Environment(AppModel.self) private var model
    @Environment(AccountModel.self) private var account
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var routine: WordRoutine
    var reachedGoal: Bool
    var done: () -> Void
    var again: () -> Void
    @State private var signInOpen = false
    @State private var appeared = false

    var body: some View {
        let summary = routine.summary
        ScrollView {
            VStack(spacing: 20) {
                Mascot(mood: summary.caught == 0 ? .cheer : .happy, size: 120, hop: appeared ? 1 : 0)
                    .popIn()
                    .background {
                        // A win gets rays turning behind the cat.
                        if reachedGoal || summary.caught == 0 {
                            Sunburst(color: (reachedGoal ? Palette.review : Palette.known).opacity(0.22), size: 300)
                                .opacity(appeared ? 1 : 0)
                                .animation(reduceMotion ? nil : .easeOut(duration: 0.8), value: appeared)
                        }
                    }
                    .padding(.top, 12)
                    // Nothing caught: a stamp thumps down beside the cat.
                    .overlay(alignment: .topTrailing) {
                        if summary.caught == 0, summary.alreadyKnew + summary.learned + summary.reviewed > 0 {
                            StampMark(color: Palette.known, size: 76, angle: -12) {
                                Text(L.t("全對", "Spot on")).font(.display(.headline, weight: .heavy))
                            }
                            .modifier(StampSlam(delay: 0.9))
                            .offset(x: 70, y: 4)
                            .accessibilityLabel(L.t("全部答對", "All right"))
                        }
                    }
                let left = reachedGoal ? 0 : model.wordsLeftForGoal
                VStack(spacing: 6) {
                    Text(reachedGoal || model.goalDone ? L.goalReachedTitle
                         : left > 0 ? L.t("這組完成！", "Set done!") : L.t("今天的單字完成！", "Today's words done!"))
                        .font(.display(.title, weight: .bold))
                        .multilineTextAlignment(.center)
                    if left > 0 {
                        Text(L.t("再 \(left) 個就達成今天的目標", "\(left) more for today's goal"))
                            .font(.headline)
                            .foregroundStyle(Palette.secondaryLabel)
                    }
                }
                .entrance(1)
                HStack(spacing: 10) {
                    tile(L.t("本來就會", "Knew"), summary.alreadyKnew, Palette.known)
                    tile(L.t("新學", "Learned"), summary.learned, Palette.accent)
                    tile(L.t("複習", "Reviewed"), summary.reviewed, Palette.chinese)
                }
                .entrance(2)
                RoutineCatLine(text: CatQuips.studyDone(reachedGoal: reachedGoal || model.goalDone, source: model.catLines),
                        mood: summary.caught == 0 ? .cheer : .smug)
                    .entrance(4)
                if AppRuntime.labOnboarding, model.reminderAskDue {
                    ReminderAskCard()
                        .entrance(4)
                }
                if account.configured, !account.isPermanent {
                    GuestKeepCard(count: routine.cardIds.count) { signInOpen = true }
                        .entrance(4)
                }
                buttons(left: left, caught: summary.caught)
                    .padding(.top, 8)
            }
            .padding(.vertical, 16)
        }
        .overlay(alignment: .top) {
            if (reachedGoal || summary.caught == 0) && appeared && !reduceMotion { ConfettiBurst().allowsHitTesting(false) }
        }
        .sheet(isPresented: $signInOpen) { SignInSheet(reason: .general) }
        .onAppear { appeared = true }
        .soundEffect(trigger: appeared) { (_: Bool, now: Bool) -> SoundEffect? in now ? .complete : nil }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("routine-summary")
    }

    /// The keys in the order every round ends with (RoundEndActions): the
    /// words caught leading when there are any, Done, another set as a link.
    /// Short of the goal, the next set leads instead.
    @ViewBuilder
    private func buttons(left: Int, caught: Int) -> some View {
        if left > 0 {
            VStack(spacing: 12) {
                Button(action: again) {
                    Text(L.t("繼續：再 \(left) 個", "Keep going: \(left) more")).font(.title3.weight(.bold)).frame(maxWidth: .infinity)
                }
                .prominentAction()
                .accessibilityIdentifier("routine-again")
                if caught > 0 {
                    Button(action: flipCaught) {
                        Text(caughtTitle(caught)).font(.title3.weight(.bold)).frame(maxWidth: .infinity)
                    }
                    .secondaryAction(tint: Palette.review)
                    .accessibilityIdentifier("routine-caught")
                }
                Button(action: done) {
                    Text(L.done).font(.title3.weight(.bold)).frame(maxWidth: .infinity)
                }
                .secondaryAction()
                .accessibilityIdentifier("routine-done")
            }
        } else {
            RoundEndActions(missed: caught, reviewMissed: flipCaught, reviewTitle: caughtTitle(caught), reviewId: "routine-caught",
                            done: done, doneId: "routine-done", again: again, againId: "routine-again")
        }
    }

    private func caughtTitle(_ caught: Int) -> String {
        L.t("被抓包 \(caught) 個，再翻一次", "\(caught) caught: flip them again")
    }

    private func flipCaught() {
        model.startStudySession(onlyIds: routine.caughtIds)
    }

    private func tile(_ title: String, _ value: Int, _ tint: Color) -> some View {
        VStack(spacing: 6) {
            CountUpText(value: value, delay: 0.35)
                .font(.displaySize(40, weight: .bold))
                .foregroundStyle(tint)
            Text(title)
                .font(.headline)
                .foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

extension AppModel {
    /// The summary offers a daily reminder until notifications have been
    /// asked about, at most once a week after a "not now".
    var reminderAskDue: Bool {
        guard settings.pushAsked != true else { return false }
        guard let declined = settings.reminderAskDeclinedOn.flatMap(DayMath.dayNumber),
              let now = DayMath.dayNumber(today) else { return true }
        return now - declined >= 7
    }
}

/// WordCat Next: after a words routine, until it has been asked, the
/// learner picks a time for the daily reminder; only then does the system
/// ask about notifications (master asks as the app opens).
struct ReminderAskCard: View {
    @Environment(AppModel.self) private var model
    @State private var time = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var answered = false

    var body: some View {
        if !answered {
            VStack(alignment: .leading, spacing: 12) {
                Label(L.t("明天幾點提醒你？", "When should I remind you?"), systemImage: "bell.badge.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Palette.ink)
                DatePicker(L.t("每天", "Every day at"), selection: $time, displayedComponents: .hourAndMinute)
                    .font(.headline)
                    .accessibilityIdentifier("reminder-time")
                Button(action: set) {
                    Text(L.t("每天這個時間提醒我", "Remind me at this time")).font(.headline).frame(maxWidth: .infinity)
                }
                .prominentAction()
                .accessibilityIdentifier("reminder-set")
                Button(L.t("先不用", "Not now")) {
                    model.settings.reminderAskDeclinedOn = model.today
                    withAnimation { answered = true }
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 36)
                .accessibilityIdentifier("reminder-later")
            }
            .padding(16)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .transition(.opacity)
        }
    }

    private func set() {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        let minute = (parts.hour ?? 20) * 60 + (parts.minute ?? 0)
        model.settings.reminderMinute = minute
        model.setReminderEnabled(true)
        Usage.log("reminder_time", "\(minute)")
        withAnimation { answered = true }
        Task { await PushRegistration.shared.askOnce(model) }
    }
}

/// A tap and a sound for each answer typed: right (`solves` up) or wrong
/// (`misses` up). Its own modifier, so a view's body stays quick to compile.
struct AnswerFeedback: ViewModifier {
    var solves: Int
    var misses: Int
    var haptics: Bool

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(trigger: solves) { (_: Int, _: Int) -> SensoryFeedback? in haptics ? .success : nil }
            .sensoryFeedback(trigger: misses) { (_: Int, new: Int) -> SensoryFeedback? in new > 0 && haptics ? .error : nil }
            .soundEffect(trigger: solves) { (old: Int, new: Int) -> SoundEffect? in new > old ? .correct : nil }
            .soundEffect(trigger: misses) { (old: Int, new: Int) -> SoundEffect? in new > old ? .wrong : nil }
    }
}
