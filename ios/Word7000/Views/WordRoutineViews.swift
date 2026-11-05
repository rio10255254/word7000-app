import SwiftUI
import Word7000Core

// WordCat Next: today's words as one routine. The flip cards come first
// (StudySessionView, unchanged); these screens follow them in the same cover:
// a short hand-off, spelling for the young words marked known, exam-style
// questions for the older ones, and one summary. Big type throughout, and the
// cat says what to do instead of small captions.

/// The steps of today's words as chips: cards, spelling, quiz.
struct RoutineStepStrip: View {
    var routine: WordRoutine
    /// While the cards are being flipped: how far along.
    var flipped: (done: Int, total: Int)?

    private enum ChipState { case done, now, later }

    var body: some View {
        HStack(spacing: 6) {
            chip(icon: "rectangle.on.rectangle.angled", title: L.t("翻卡", "Cards"),
                 state: routine.step == .flip ? .now : .done,
                 count: routine.step == .flip ? flipped.map { "\($0.done)/\($0.total)" } : nil)
            // Before the checks are picked, both may still come.
            if routine.step == .flip || !routine.spellIds.isEmpty {
                arrow
                chip(icon: "pencil.line", title: L.t("拼字", "Spell"),
                     state: routine.step == .spell ? .now : routine.step == .flip ? .later : .done,
                     count: routine.step == .spell ? "\(routine.spellResults.count)/\(routine.spellIds.count)" : nil)
            }
            if routine.step == .flip || !routine.examIds.isEmpty {
                arrow
                chip(icon: "checklist", title: L.t("考考看", "Quiz"),
                     state: routine.step == .exam ? .now : routine.step == .done ? .done : .later,
                     count: routine.step == .exam ? "\(routine.examResults.count)/\(routine.examIds.count)" : nil)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("routine-steps")
    }

    private var arrow: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.bold))
            .foregroundStyle(Palette.tertiaryLabel)
            .accessibilityHidden(true)
    }

    private func chip(icon: String, title: String, state: ChipState, count: String?) -> some View {
        HStack(spacing: 5) {
            Image(systemName: state == .done ? "checkmark" : icon)
            Text(count.map { "\(title) \($0)" } ?? title)
                .monospacedDigit()
        }
        .font(.subheadline.weight(.bold))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .foregroundStyle(state == .now ? Color.white : state == .done ? Palette.known : Palette.secondaryLabel)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(state == .now ? Palette.accent : state == .done ? Palette.known.opacity(0.16) : Palette.fill, in: Capsule())
    }
}

/// After the flip cards, while checks are left: the hand-off into each
/// check step, then the step itself.
struct RoutineChecksView: View {
    @Environment(AppModel.self) private var model
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
                        line: L.t("你說認識 \(routine.knownIds.count) 個字。\n我抽 \(routine.spellIds.count) 個，寫給我看。",
                                  "You said you know \(routine.knownIds.count).\nI'll pick \(routine.spellIds.count). Spell them for me."),
                        action: L.t("開始拼字", "Start spelling"), step: .spell)
            }
        case .exam:
            if begun == .exam || !routine.examResults.isEmpty {
                RoutineExamView(routine: routine)
            } else {
                handOff(title: routine.spellIds.isEmpty ? L.t("翻卡完成！", "Cards done!") : L.t("拼字完成！", "Spelling done!"),
                        line: L.t("這 \(routine.examIds.count) 個字你學過一陣子了。\n用學測題型考考看。",
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
    }
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
    @FocusState private var focused: Bool

    private var haptics: Bool { model.settings.hapticsEnabled ?? true }

    var body: some View {
        Group {
            if let wordId, let word = model.word(id: wordId), let sentence = Cloze.sentence(for: word), let attempt {
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
        .sensoryFeedback(trigger: solves) { _, _ in haptics ? .success : nil }
        .sensoryFeedback(trigger: misses) { _, new in new > 0 && haptics ? .error : nil }
    }

    private func question(_ word: WordEntry, _ sentence: Cloze.Sentence, _ attempt: ClozeAttempt) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                RoutineStepStrip(routine: model.activeRoutine ?? routine)
                    .padding(.top, 4)
                RoutineCatLine(text: catLine(word, attempt), mood: attempt.solved ? (attempt.outcome == .missed ? .encourage : .cheer) : .thinking)
                ClozeCard(word: word, sentence: sentence, attempt: attempt, input: input, comeBack: comeBack)
                    .shake(trigger: misses, enabled: !reduceMotion)
                    .pulse(trigger: solves, scale: 1.02, enabled: !reduceMotion)
                    .id(word.id)
                if let message = ClozeCard.message(for: word, attempt: attempt) {
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
                TextField(L.t("輸入英文單字", "Type the English word"), text: Binding(
                    get: { input },
                    set: { if !attempt.solved { input = $0 } }
                ))
                .font(.title.weight(.semibold))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .submitLabel(attempt.solved ? .next : .done)
                .focused($focused)
                .onSubmit { attempt.solved ? next() : check() }
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(focused ? Palette.accent.opacity(0.45) : .clear, lineWidth: 2))
                .accessibilityIdentifier("routine-input")
            }
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.never)
        .safeAreaInset(edge: .bottom) { actions(attempt) }
    }

    /// The cat asks with the Chinese cue, never the word itself.
    private func catLine(_ word: WordEntry, _ attempt: ClozeAttempt) -> String {
        if attempt.solved {
            switch attempt.outcome {
            case .knew: return L.t("真的會，算你厲害。", "You really know it. Fine.")
            case .gotIt: return L.t("有點危險喔，明天再考你。", "A little shaky. Tomorrow again.")
            default: return L.t("抓到了！明天再來一次。", "Caught you! Again tomorrow.")
            }
        }
        let wanted = Cloze.cue(for: word)?.cue ?? ChineseDisplay.conciseMeaning(word.meaningZh)
        return L.t("「\(wanted)」你說你認識？寫給我看。", "You said you know \u{201C}\(wanted)\u{201D}? Spell it.")
    }

    private func actions(_ attempt: ClozeAttempt) -> some View {
        ButtonRow {
            if !attempt.solved {
                if let help = attempt.nextHelp {
                    Button(action: takeHelp) {
                        Label(help == .firstLetter ? L.t("第一個字母", "First letter") : L.t("看答案", "Show answer"),
                              systemImage: help == .firstLetter ? "lightbulb" : "eye")
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
                .accessibilityIdentifier("routine-next")
            }
        }
        .padding(.vertical, 8)
        .background { Palette.background.overlay { PaperGrain() } }
    }

    private func load(_ id: String?) {
        input = ""
        comeBack = nil
        wordId = id
        guard let id else { model.advanceRoutine(); return }
        guard let word = model.word(id: id), let sentence = Cloze.sentence(for: word) else {
            // A word that can no longer be asked (its sentence changed): let it pass.
            model.recordRoutineCheck(wordId: id, outcome: .knew, exam: false)
            load(model.activeRoutine?.spellLeft.first)
            return
        }
        attempt = ClozeAttempt(answer: sentence.answer)
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
        } else {
            misses += 1
            if current.answerShown { input = "" }
        }
        withAnimation(reduceMotion ? nil : Motion.reveal) { attempt = current }
    }

    private func next() {
        guard attempt?.solved == true else { return }
        Speaker.shared.stop()
        load(model.activeRoutine?.spellLeft.first)
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

    private var haptics: Bool { model.settings.hapticsEnabled ?? true }

    var body: some View {
        Group {
            if let question, let wordId, let word = model.word(id: wordId), question.wordId == wordId {
                content(word, question)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if meanings.isEmpty { meanings = ExamQuestionBody.meanings(model.coreWords) }
            if wordId == nil { wordId = routine.examLeft.first ?? "" }
        }
        .task(id: wordId) { await load() }
        .sensoryFeedback(trigger: chosen) { _, new in
            guard let new, let question, haptics else { return nil }
            return new == question.answerIndex ? .success : .error
        }
    }

    private func content(_ word: WordEntry, _ question: ExamQuestion) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                RoutineStepStrip(routine: model.activeRoutine ?? routine)
                    .padding(.top, 4)
                RoutineCatLine(text: ExamQuestionBody.catLine(question, chosen: chosen),
                               mood: chosen == nil ? .thinking : chosen == question.answerIndex ? .cheer : .encourage)
                ExamQuestionBody(word: word, question: question, chosen: chosen, meanings: meanings) { choose($0, question) }
            }
            .padding(.bottom, 16)
        }
        .safeAreaInset(edge: .bottom) {
            if chosen != nil {
                Button(action: next) {
                    Text(L.nextQuestion).font(.title3.weight(.bold)).frame(maxWidth: .infinity)
                }
                .prominentAction(tint: Palette.known)
                .padding(.vertical, 8)
                .background { Palette.background.overlay { PaperGrain() } }
                .accessibilityIdentifier("routine-next")
            }
        }
    }

    private func choose(_ index: Int, _ question: ExamQuestion) {
        guard chosen == nil, let wordId else { return }
        withAnimation(reduceMotion ? nil : Motion.reveal) { chosen = index }
        model.recordRoutineCheck(wordId: wordId, outcome: index == question.answerIndex ? .knew : .missed, exam: true)
    }

    private func load() async {
        chosen = nil
        question = nil
        guard let wordId else { return }
        guard !wordId.isEmpty, let word = model.word(id: wordId) else { model.advanceRoutine(); return }
        let pool = await model.examPool()
        guard let built = ExamQuestions.make(for: word, pool: pool, seed: "\(routine.day):\(wordId)") else {
            // Too few look-alikes for this one: let it pass.
            model.recordRoutineCheck(wordId: wordId, outcome: .knew, exam: true)
            self.wordId = model.activeRoutine?.examLeft.first ?? ""
            return
        }
        question = built
    }

    private func next() {
        Speaker.shared.stop()
        wordId = model.activeRoutine?.examLeft.first ?? ""
    }
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
    var choose: (Int) -> Void

    static func meanings(_ words: [WordEntry]) -> [String: String] {
        Dictionary(words.map { (Spelling.normalized($0.word), $0.meaningZh) }, uniquingKeysWith: { first, _ in first })
    }

    /// What the cat says above the question.
    static func catLine(_ question: ExamQuestion, chosen: Int?) -> String {
        guard let chosen else { return L.t("學測題型：選出最適合的字。", "Exam style: pick the word that fits.") }
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
                if chosen != nil, let cue = Cloze.cue(for: word) {
                    Text(marked(cue))
                        .font(.title3)
                        .foregroundStyle(Palette.secondaryLabel)
                        .transition(.opacity)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.wordCardRadius, style: .continuous))
            VStack(spacing: 10) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                    optionButton(index, option)
                }
            }
            if let chosen {
                explanation(chosen)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
            }
        }
    }

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
                    .foregroundStyle(chosen == nil ? Palette.accent : .white)
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
            let meaning = meanings[Spelling.normalized(option)].map(ChineseDisplay.conciseMeaning) ?? ""
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
                    .padding(.top, 12)
                Text(reachedGoal || model.goalDone ? L.goalReachedTitle : L.t("今天的單字完成！", "Today's words done!"))
                    .font(.display(.title, weight: .bold))
                    .multilineTextAlignment(.center)
                    .entrance(1)
                HStack(spacing: 10) {
                    tile(L.t("本來就會", "Knew"), summary.alreadyKnew, Palette.known)
                    tile(L.t("新學", "Learned"), summary.learned, Palette.accent)
                    tile(L.t("複習", "Reviewed"), summary.reviewed, Palette.chinese)
                }
                .entrance(2)
                if summary.caught > 0 {
                    Button {
                        model.startStudySession(onlyIds: routine.caughtIds)
                    } label: {
                        VStack(spacing: 4) {
                            Text(L.t("被抓包 \(summary.caught) 個", "\(summary.caught) caught")).font(.title3.weight(.bold))
                            Text(L.t("現在再翻一次", "Flip them again now")).font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .prominentAction(tint: Palette.review)
                    .entrance(3)
                    .accessibilityIdentifier("routine-caught")
                }
                RoutineCatLine(text: CatQuips.studyDone(reachedGoal: reachedGoal || model.goalDone, source: model.catLines),
                        mood: summary.caught == 0 ? .cheer : .smug)
                    .entrance(4)
                if account.configured, !account.isPermanent {
                    GuestKeepCard(count: routine.cardIds.count) { signInOpen = true }
                        .entrance(4)
                }
                VStack(spacing: 12) {
                    let doneButton = Button(action: done) {
                        Text(L.done).font(.title3.weight(.bold)).frame(maxWidth: .infinity)
                    }
                    if summary.caught > 0 {
                        doneButton.secondaryAction().accessibilityIdentifier("routine-done")
                    } else {
                        doneButton.prominentAction().accessibilityIdentifier("routine-done")
                    }
                    Button(action: again) {
                        Text(L.nextSession).font(.headline).frame(maxWidth: .infinity)
                    }
                    .secondaryAction()
                    .accessibilityIdentifier("routine-again")
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 16)
        }
        .overlay(alignment: .top) {
            if (reachedGoal || summary.caught == 0) && appeared && !reduceMotion { ConfettiBurst().allowsHitTesting(false) }
        }
        .sheet(isPresented: $signInOpen) { SignInSheet(reason: .general) }
        .onAppear { appeared = true }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("routine-summary")
    }

    private func tile(_ title: String, _ value: Int, _ tint: Color) -> some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.displaySize(40, weight: .bold))
                .monospacedDigit()
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
