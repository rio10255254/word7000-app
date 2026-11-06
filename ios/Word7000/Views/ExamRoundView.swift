import SwiftUI
import Word7000Core

/// WordCat Next: a short exam-style quiz outside today's routine, from the
/// word card's 考考看 step or Sunday's weekly quiz. The same questions as the
/// routine's quiz step (a sentence with a blank, four look-alike words), then
/// a score and the words missed, with a way to flip them again.
struct ExamRoundView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var kind: ExamRoundKind
    var studyMissed: ([String]) -> Void

    @State private var ids: [String] = []
    @State private var index = 0
    @State private var question: ExamQuestion?
    @State private var chosen: Int?
    @State private var right = 0
    @State private var asked = 0
    @State private var missed: [String] = []
    @State private var meanings: [String: String] = [:]
    @State private var started = false
    @State private var noted = false
    /// A right answer moves on by itself after a moment (not the last one,
    /// whose score is worth a look first).
    @State private var advancing = false

    private var haptics: Bool { model.settings.hapticsEnabled ?? true }
    private var finished: Bool { started && index >= ids.count }

    var body: some View {
        NavigationStack {
            Group {
                if !started {
                    ProgressView()
                } else if ids.count < ExamRound.minimumWords {
                    empty
                } else if finished {
                    summary
                } else if let question, let word = model.word(id: question.wordId), question.wordId == ids[index] {
                    content(word, question)
                } else {
                    DelayedProgress()
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background { AmbientBackground() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(L.close)
                        .accessibilityIdentifier("exam-round-close")
                }
                ToolbarItem(placement: .principal) {
                    if started, !finished, ids.count >= ExamRound.minimumWords {
                        Text("\(min(index + 1, ids.count)) / \(ids.count)")
                            .font(.display(.subheadline, weight: .semibold))
                            .monospacedDigit()
                            .accessibilityIdentifier("exam-round-position")
                    }
                }
            }
        }
        .onAppear(perform: start)
        .task(id: started ? index : -1) { await load() }
        .onDisappear { Speaker.shared.stop() }
        .sensoryFeedback(trigger: chosen) { _, new in
            guard let new, let question, haptics else { return nil }
            return new == question.answerIndex ? .success : .error
        }
        .soundEffect(trigger: chosen) { (_: Int?, new: Int?) -> SoundEffect? in
            guard let new, let question else { return nil }
            return new == question.answerIndex ? .correct : .wrong
        }
        .soundEffect(trigger: finished) { (_: Bool, now: Bool) -> SoundEffect? in now && asked > 0 && right == asked ? .complete : nil }
        .task(id: advancing) {
            guard advancing else { return }
            do { try await Task.sleep(for: AutoAdvance.delay) } catch { return }
            guard advancing else { return }
            next()
        }
    }

    private var title: String {
        kind == .weekly ? L.t("週考", "Weekly quiz") : L.t("考考看", "Quiz")
    }

    private func start() {
        guard !started else { return }
        meanings = ExamQuestionBody.meanings(model.coreWords)
        ids = model.examRoundIds(kind, seed: SeededRandom.runtimeSeed())
        started = true
    }

    // MARK: Question

    private func content(_ word: WordEntry, _ question: ExamQuestion) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                BuddyProgressBar(fraction: Double(index + (chosen == nil ? 0 : 1)) / Double(max(1, ids.count)),
                                 mood: chosen == nil ? .thinking : chosen == question.answerIndex ? .happy : .encourage,
                                 hop: asked, remark: nil)
                RoutineCatLine(text: index == 0 && chosen == nil && kind == .weekly
                                   ? L.t("週考！這週學的字，看你記住幾個。", "Weekly quiz! This week's words: let's see what stuck.")
                                   : ExamQuestionBody.catLine(question, chosen: chosen),
                               mood: chosen == nil ? .thinking : chosen == question.answerIndex ? .cheer : .encourage)
                ExamQuestionBody(word: word, question: question, chosen: chosen, meanings: meanings) { choose($0, question) }
                    .id(index)
                    .transition(.questionSwap(reduceMotion))
            }
            .padding(.bottom, 16)
        }
        .safeAreaInset(edge: .bottom) {
            if chosen != nil {
                Button(action: next) {
                    Text(index + 1 >= ids.count ? L.t("看成績", "See the score") : L.nextQuestion)
                        .font(.title3.weight(.bold)).frame(maxWidth: .infinity)
                }
                .prominentAction(tint: Palette.known)
                .overlay { CountdownFillOverlay(active: advancing).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)) }
                .padding(.vertical, 8)
                .background { Palette.background.overlay { PaperGrain() } }
                .accessibilityIdentifier("routine-next")
            }
        }
    }

    private func choose(_ chosenIndex: Int, _ question: ExamQuestion) {
        guard chosen == nil else { return }
        withAnimation(reduceMotion ? nil : Motion.reveal) { chosen = chosenIndex }
        let correct = chosenIndex == question.answerIndex
        asked += 1
        if correct { right += 1 } else { missed.append(question.wordId) }
        model.recordQuizAnswer(wordId: question.wordId, correct: correct)
        advancing = AutoAdvance.enabled && correct && index + 1 < ids.count
    }

    private func next() {
        advancing = false
        Speaker.shared.stop()
        chosen = nil
        question = nil
        index += 1
    }

    private func load() async {
        guard started, index < ids.count else {
            if finished, !noted, asked > 0 {
                noted = true
                model.noteExamRound(kind, asked: asked, right: right)
            }
            return
        }
        chosen = nil
        question = nil
        let pool = await model.examPool()
        // A word with too few look-alikes has no question: it is passed over.
        var at = index
        while at < ids.count {
            if let word = model.word(id: ids[at]),
               let built = ExamQuestions.make(for: word, pool: pool, seed: "\(model.today):\(kind.rawValue):\(word.id)") {
                if at != index { index = at }
                withAnimation(reduceMotion ? nil : Motion.swap) { question = built }
                return
            }
            at += 1
        }
        index = ids.count
    }

    // MARK: End

    private var empty: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            Mascot(mood: .encourage, size: 120)
            Text(L.t("先翻幾張卡，我才有字考你。", "Flip a few cards first; then I'll have words to quiz you on."))
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            Button { dismiss() } label: {
                Text(L.done).font(.title3.weight(.bold)).frame(maxWidth: .infinity)
            }
            .prominentAction()
            .padding(.bottom, 8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("exam-round-empty")
    }

    private var summary: some View {
        let total = max(asked, 1)
        let perfect = asked > 0 && right == asked
        return VStack(spacing: 18) {
            Spacer(minLength: 0)
            Mascot(mood: perfect ? .cheer : right * 2 >= total ? .happy : .encourage, size: 110)
                .popIn()
            Text(L.t("\(title)完成！", "\(title) done!"))
                .font(.display(.largeTitle, weight: .bold))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(right)")
                    .font(.displaySize(64, weight: .bold))
                    .foregroundStyle(perfect ? Palette.known : Palette.accent)
                    .contentTransition(.numericText(value: Double(right)))
                Text("/ \(asked)")
                    .font(.display(.title, weight: .semibold))
                    .foregroundStyle(Palette.secondaryLabel)
            }
            .monospacedDigit()
            .accessibilityElement(children: .combine)
            .accessibilityLabel(L.t("答對 \(right) 題，共 \(asked) 題", "\(right) of \(asked) right"))
            if !missed.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.t("被抓包的字", "Caught out"))
                        .font(.headline)
                        .foregroundStyle(Palette.miss)
                    ForEach(missed.prefix(6), id: \.self) { id in
                        if let word = model.word(id: id) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(word.word).font(.title3.weight(.bold))
                                Spacer(minLength: 8)
                                Text(ChineseDisplay.conciseMeaning(word.meaningZh))
                                    .font(.body)
                                    .foregroundStyle(Palette.secondaryLabel)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                Text(L.t("全對。我沒話說了。", "All right. I have nothing to say."))
                    .font(.title3.weight(.semibold))
            }
            Spacer(minLength: 0)
            VStack(spacing: 12) {
                if !missed.isEmpty {
                    Button { studyMissed(missed) } label: {
                        Text(L.t("錯的字再翻一次", "Flip the missed words again")).font(.title3.weight(.bold)).frame(maxWidth: .infinity)
                    }
                    .prominentAction()
                    .accessibilityIdentifier("exam-round-again")
                }
                Button { dismiss() } label: {
                    Text(L.done).font(.headline).frame(maxWidth: .infinity)
                }
                .modifier(SummaryDoneStyle(prominent: missed.isEmpty))
                .accessibilityIdentifier("exam-round-done")
            }
            .padding(.bottom, 8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("exam-round-summary")
    }
}

/// The summary's done button: the main action when nothing is left to do.
private struct SummaryDoneStyle: ViewModifier {
    var prominent: Bool

    func body(content: Content) -> some View {
        if prominent {
            content.prominentAction(tint: Palette.known)
        } else {
            content.secondaryAction()
        }
    }
}
