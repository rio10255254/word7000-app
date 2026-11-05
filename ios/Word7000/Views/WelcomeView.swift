import SwiftUI
import Word7000Core

/// The first launch, as three small scenes on the desk with the cat: what to
/// learn, how much a day, and which of a few words are already known. Each is
/// one tap or a few; the known words set where new words start.
struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: Step = .hello
    @State private var forward = true
    @State private var mode: StudyMode = .english
    @State private var target = 20
    @State private var known: Set<String> = []
    @State private var placement: [WordEntry] = []
    @State private var hop = 0
    /// WordCat Next: the exam being prepared for, and the level test.
    @State private var exam: WelcomeExam?
    @State private var test = PlacementTest()
    @State private var question: PlacementQuestion?
    @State private var picked: Int?
    @State private var vocabulary: PreparedVocabulary?
    @State private var testSeed = UUID().uuidString
    var finish: (_ mode: StudyMode, _ target: Int, _ knownIds: [String], _ practice: Bool) -> Void

    enum Step: Int, CaseIterable { case hello, exam, goal, lead, words, test, result }

    /// The scenes in order. WordCat Next asks about the exam (learners of
    /// English) and which pillar comes first, then tests the level; the
    /// older welcome has three scenes.
    private var flow: [Step] {
        guard AppRuntime.labOnboarding else { return [.hello, .goal, .words] }
        return mode == .english ? [.hello, .exam, .goal, .lead, .test, .result] : [.hello, .goal, .lead, .test, .result]
    }

    private var position: Int { flow.firstIndex(of: step) ?? 0 }

    private func advance() {
        let index = position + 1
        if flow.indices.contains(index) { go(flow[index]) }
    }

    /// The interface speaks the learner's own language once they have chosen.
    private var chinese: Bool { mode == .english }
    private func text(_ zh: String, _ en: String) -> String { chinese ? zh : en }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            GeometryReader { proxy in
                ScrollView {
                    Group {
                        switch step {
                        case .hello: hello
                        case .exam: examQuestion
                        case .goal: goal
                        case .lead: leadQuestion
                        case .words: words
                        case .test: placementTest
                        case .result: result
                        }
                    }
                    .id(step)
                    .transition(transition)
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 560)
                    // Each scene sits a little above the middle of the screen
                    // rather than leaving the bottom half empty.
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height * 0.88)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .background { AmbientBackground() }
        .sensoryFeedback(.selection, trigger: target)
        .sensoryFeedback(.selection, trigger: known)
        .sensoryFeedback(.impact(weight: .light), trigger: step)
        .onAppear {
            if placement.isEmpty { placement = placementWords(for: mode) }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(450))
            if !reduceMotion { hop += 1 }
        }
    }

    private var transition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                           removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity))
    }

    private func go(_ next: Step) {
        forward = (flow.firstIndex(of: next) ?? 0) > position
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.4)) { step = next }
        if !reduceMotion { hop += 1 }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button {
                if position > 0 { go(flow[position - 1]) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            // No going back from the result, or into a test already under way.
            .opacity(step == .hello || step == .result ? 0 : 1)
            .disabled(step == .hello || step == .result)
            .accessibilityLabel(text("上一步", "Back"))
            Spacer()
            HStack(spacing: 6) {
                ForEach(flow, id: \.self) { item in
                    let index = flow.firstIndex(of: item) ?? 0
                    Capsule()
                        .fill(index <= position ? Palette.accent : Palette.fill)
                        .frame(width: item == step ? 22 : 8, height: 8)
                }
            }
            .animation(reduceMotion ? nil : .snappy, value: step)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text("第 \(position + 1) 步，共 \(flow.count) 步", "Step \(position + 1) of \(flow.count)"))
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .tint(Palette.accent)
    }

    // MARK: 1. What to learn

    private var hello: some View {
        VStack(spacing: 22) {
            VStack(spacing: 4) {
                Mascot(mood: .smug, size: 112, hop: hop)
                    .popIn()
                MascotBubble(text: "嗨，我是傻貓。\nHi, I'm Silly Cat.", pointing: .top)
                    .entrance(1)
            }
            Text("你想學什麼？\nWhat do you want to learn?")
                .font(.display(.title2, weight: .bold))
                .multilineTextAlignment(.center)
                .entrance(2)
            HStack(alignment: .top, spacing: 14) {
                LanguageChoice(title: "English", subtitle: "我想學英文", samples: ["brave", "journey", "bright"],
                               paper: .graph, tilt: -1.2) { choose(.english) }
                    .accessibilityIdentifier("welcome-learn-english")
                LanguageChoice(title: "中文", subtitle: "I want to learn Chinese", samples: ["勇敢", "旅程", "明亮"],
                               paper: .peach, tilt: 1.1) { choose(.chinese) }
                    .accessibilityIdentifier("welcome-learn-chinese")
            }
            .entrance(3)
        }
    }

    /// The check words come from the bank of what is being learned.
    private func placementWords(for language: StudyMode) -> [WordEntry] {
        let chinese = language == .chinese && !model.chineseCoreWords.isEmpty
        return Placement.words(from: chinese ? model.chineseCoreWords : model.englishCoreWords,
                               seed: model.settings.deviceSourceId, chinese: chinese)
    }

    private func choose(_ language: StudyMode) {
        mode = language
        placement = placementWords(for: language)
        known = []
        test = PlacementTest()
        question = nil
        vocabulary = nil
        advance()
    }

    // MARK: 2. How much a day

    private static let goals: [(count: Int, zh: String, en: String, paper: PaperKind, tilt: Double)] = [
        (10, "輕鬆", "Easy", .sage, -2), (20, "剛好", "Steady", .mustard, 1.5),
        (30, "認真", "Serious", .peach, 1), (50, "拼了", "All in", .graph, -1.5),
    ]

    private var goal: some View {
        VStack(spacing: 22) {
            CatLine(mood: .thinking, hop: hop,
                    text: text("一天想背幾個字？之後隨時能改。", "How many words a day? You can change it any time."))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                ForEach(Self.goals, id: \.count) { item in
                    StickyNote(count: item.count, label: text(item.zh, item.en), unit: text("個／天", "a day"),
                               paper: item.paper, tilt: item.tilt, selected: target == item.count) {
                        withAnimation(reduceMotion ? nil : Motion.pop) { target = item.count }
                    }
                    .accessibilityIdentifier("welcome-goal-\(item.count)")
                }
            }
            Button { advance() } label: {
                Label(text("下一步", "Next"), systemImage: "arrow.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .prominentAction()
            .accessibilityIdentifier("welcome-next")
        }
    }

    // MARK: 3. What you already know

    private var words: some View {
        VStack(spacing: 20) {
            CatLine(mood: known.isEmpty ? .idle : .happy, hop: hop, text: reaction)
                .animation(reduceMotion ? nil : Motion.reveal, value: reaction)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
                ForEach(Array(placement.enumerated()), id: \.element.id) { index, word in
                    WordTag(text: WordFace(word, mode: mode).prompt, known: known.contains(word.id), seed: index) {
                        withAnimation(reduceMotion ? nil : Motion.pop) {
                            if known.contains(word.id) { known.remove(word.id) } else { known.insert(word.id) }
                        }
                    }
                    .accessibilityIdentifier("welcome-word-\(word.id)")
                }
            }
            VStack(spacing: 10) {
                Button { finish(mode, target, Array(known), true) } label: {
                    Label(text("開始，先背 5 個", "Start with 5 words"), systemImage: "arrow.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .prominentAction()
                .accessibilityIdentifier("welcome-start")
                Button(text("先逛逛字庫", "Look around first")) { finish(mode, target, Array(known), false) }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("welcome-skip")
            }
            .padding(.top, 4)
        }
    }

    /// The cat's take on how many were tapped, so the tapping feels heard.
    private var reaction: String {
        switch known.count {
        case 0: text("這些字你認得哪幾個？點一下就好，不認得也沒關係。", "Which of these do you know? Just tap them. Not knowing is fine.")
        case 1...2: text("好，有底子。我從適合你的開始。", "Good, there's a base. I'll start where it suits you.")
        case 3...5: text("不錯嘛，太簡單的我就少給一點。", "Not bad. I'll go easy on the easy ones.")
        default: text("……好啦你很強，我把難的拿出來。", "…Fine, you're good. Out come the hard ones.")
        }
    }

    // MARK: WordCat Next: the exam

    private var examQuestion: some View {
        VStack(spacing: 18) {
            CatLine(mood: .thinking, hop: hop,
                    text: text("你在準備什麼考試？我幫你倒數、排好每天的量。", "What exam are you preparing for? I'll count down and plan each day."))
            VStack(spacing: 12) {
                ForEach(WelcomeExam.allCases, id: \.self) { choice in
                    ChoiceCard(icon: choice.icon, title: choice.title, detail: choice.detail(Date()), selected: exam == choice) {
                        withAnimation(reduceMotion ? nil : Motion.pop) { exam = choice }
                        CatMemory.shared.examDate = choice.date(after: Date())
                        Task {
                            try? await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 350))
                            advance()
                        }
                    }
                    .accessibilityIdentifier("welcome-exam-\(choice.rawValue)")
                }
            }
            Text(text("日期不對的話，之後在「我 → 傻貓記得的事」改。", "Wrong date? Change it later in Me → What Silly Cat remembers."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: WordCat Next: which pillar first

    private var leadQuestion: some View {
        VStack(spacing: 18) {
            CatLine(mood: .happy, hop: hop,
                    text: text("想先練單字，還是先練口說？兩個每天都會有，先選的排在今天的路最前面。",
                               "Words first, or speaking? You'll get both every day; the one you pick comes first on today's path."))
            HStack(spacing: 14) {
                PillarChoice(icon: "rectangle.on.rectangle.angled", title: text("先背單字", "Words first"),
                             detail: text("翻卡・拼字・考考看", "Cards, spelling, quiz"), tint: Palette.accent,
                             selected: model.settings.homeLead != .speaking) { lead(.words) }
                    .accessibilityIdentifier("welcome-lead-words")
                PillarChoice(icon: "mic.fill", title: text("先練口說", "Speaking first"),
                             detail: text("聽・跟讀・回答", "Listen, repeat, answer"), tint: TodayView.speakingTint,
                             selected: model.settings.homeLead == .speaking) { lead(.speaking) }
                    .accessibilityIdentifier("welcome-lead-speaking")
            }
        }
    }

    private func lead(_ pillar: Pillar) {
        withAnimation(reduceMotion ? nil : Motion.pop) { model.settings.homeLead = pillar }
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 350))
            advance()
        }
    }

    // MARK: WordCat Next: the level test

    private var placementTest: some View {
        VStack(spacing: 18) {
            CatLine(mood: picked == nil ? .thinking : question.map { picked == $0.answerIndex } == true ? .cheer : .encourage, hop: hop,
                    text: text("這個字是什麼意思？不知道就選「不知道」，不扣分。", "What does this word mean? Pick \u{201C}Don't know\u{201D} if you don't; it costs nothing."))
            if let question {
                VStack(spacing: 6) {
                    Text(text("第 \(question.level) 章・Core \(question.level)", "Chapter \(question.level) · Core \(question.level)"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Palette.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Palette.accent.opacity(0.12), in: Capsule())
                        .accessibilityIdentifier("welcome-test-chapter")
                    Text(question.prompt)
                        .font(.displaySize(44, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(Palette.ink)
                        .accessibilityIdentifier("welcome-test-word")
                    if !question.detail.isEmpty {
                        Text(question.detail).font(.title3).foregroundStyle(.secondary)
                    }
                }
                .id(question.word.id)
                .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                        Button { answer(index) } label: {
                            Text(option.text)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Palette.ink)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                                .padding(.horizontal, 10)
                                .frame(maxWidth: .infinity, minHeight: 76)
                                .background(optionFill(index, question), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(optionStroke(index, question), lineWidth: 2))
                        }
                        .buttonStyle(SoftPressStyle())
                        .disabled(picked != nil)
                        .accessibilityIdentifier("welcome-test-option-\(index)")
                    }
                }
                Button { answer(nil) } label: {
                    Text(text("不知道", "Don't know")).font(.headline).frame(maxWidth: .infinity)
                }
                .secondaryAction()
                .disabled(picked != nil)
                .accessibilityIdentifier("welcome-test-unknown")
                Text(text("第 \(test.asked + 1) 題，最多 \(PlacementTest.maxQuestions) 題", "Question \(test.asked + 1) of at most \(PlacementTest.maxQuestions)"))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                ProgressView().frame(minHeight: 200)
            }
            Button(text("跳過測驗，從第 1 章開始", "Skip the test and start at chapter 1")) {
                test = PlacementTest()
                go(.result)
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 44)
            .accessibilityIdentifier("welcome-test-skip")
        }
        .onAppear { if question == nil, !test.isFinished { nextQuestion() } }
        .sensoryFeedback(trigger: picked) { _, new in
            guard let new, let question else { return nil }
            return new == question.answerIndex ? .success : .error
        }
    }

    private func optionFill(_ index: Int, _ question: PlacementQuestion) -> Color {
        guard let picked else { return Palette.surface }
        if index == question.answerIndex { return Palette.known.opacity(0.18) }
        return index == picked ? Palette.miss.opacity(0.14) : Palette.surface
    }

    private func optionStroke(_ index: Int, _ question: PlacementQuestion) -> Color {
        guard let picked else { return Palette.separator }
        if index == question.answerIndex { return Palette.known }
        return index == picked ? Palette.miss : Palette.separator
    }

    /// A word from the chapter the test asks next, with four meanings.
    private func nextQuestion() {
        let words = mode == .chinese && !model.chineseCoreWords.isEmpty ? model.chineseCoreWords : model.englishCoreWords
        if vocabulary == nil { vocabulary = PreparedVocabulary(words) }
        guard let vocabulary else { return }
        let asked = Set(test.answers.map(\.wordId))
        // The asked chapter, or the nearest one with a word left.
        let levels = [test.level] + (1...PlacementTest.topLevel).sorted { abs($0 - test.level) < abs($1 - test.level) }
        for level in levels {
            guard let word = PlacementTest.word(at: level, from: words, asked: asked, seed: testSeed, chinese: mode == .chinese) else { continue }
            let options = QuizBuilder.options(vocabulary: vocabulary, wordId: word.id, seed: "\(testSeed):\(word.id)",
                                              mode: mode == .english ? .meaning : .word, concise: true)
            guard options.count >= 2, let answer = options.firstIndex(where: \.correct) else { continue }
            let face = WordFace(word, mode: mode)
            withAnimation(reduceMotion ? nil : Motion.reveal) {
                question = PlacementQuestion(word: word, level: level, prompt: face.prompt, detail: face.promptDetail,
                                             options: options, answerIndex: answer)
                picked = nil
            }
            return
        }
        go(.result)
    }

    /// An answer (nil: don't know): shown for a moment, then the next word.
    private func answer(_ index: Int?) {
        guard let question, picked == nil else { return }
        let knew = index == question.answerIndex
        test.record(wordId: question.word.id, level: question.level, knew: knew)
        guard let index else { advanceTest(); return }
        withAnimation(reduceMotion ? nil : Motion.pop) { picked = index }
        Task {
            try? await Task.sleep(for: .milliseconds(knew ? 450 : 900))
            advanceTest()
        }
    }

    private func advanceTest() {
        if test.isFinished {
            Usage.log("placement_test", "\(mode.rawValue).\(test.asked).\(test.startChapter)")
            go(.result)
        } else {
            nextQuestion()
        }
    }

    // MARK: WordCat Next: the result

    private var result: some View {
        let estimate = test.estimatedKnownWords
        let chapter = test.answers.isEmpty ? 1 : test.startChapter
        let shares = test.answers.isEmpty ? Array(repeating: 0.0, count: PlacementTest.topLevel) : test.levelShares
        let reach = CatMemory.shared.daysToExam.map { PlacementTest.chaptersReached(from: chapter, wordsPerDay: target, days: $0) }
        return VStack(spacing: 18) {
            if !test.answers.isEmpty {
                VStack(spacing: 2) {
                    Text(text("你大約認得", "You know about"))
                        .font(.title3.weight(.semibold))
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(estimate.formatted())
                            .font(.displaySize(64, weight: .heavy))
                            .foregroundStyle(Palette.accent)
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(estimate)))
                        Text(text("個字", "words"))
                            .font(.title2.weight(.bold))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("welcome-result-estimate")
                }
                .popIn()
            } else {
                Mascot(mood: .happy, size: 96, hop: hop).popIn()
            }
            ResultShelf(shares: shares, current: chapter - 1)
                .entrance(1)
            CatLine(mood: .cheer, hop: hop, text: resultLine(chapter: chapter, reach: reach))
                .entrance(2)
            VStack(spacing: 10) {
                Button { finish(mode, target, test.knownIds, true) } label: {
                    Label(text("開始今天的單字", "Start today's words"), systemImage: "arrow.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .prominentAction()
                .accessibilityIdentifier("welcome-start")
                Button(text("先逛逛字庫", "Look around first")) { finish(mode, target, test.knownIds, false) }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("welcome-skip")
            }
            .padding(.top, 4)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("welcome-result")
    }

    private func resultLine(chapter: Int, reach: Int?) -> String {
        let start = text("從第 \(chapter) 章開始。", "We start at chapter \(chapter).")
        guard let reach, let exam, exam.date(after: Date()) != nil else {
            return start + text("每天 \(target) 個，認得的字我就不再考你。", " \(target) a day; the ones you know, I won't ask again.")
        }
        return start + text("每天 \(target) 個，\(exam.title)前可以讀到第 \(reach) 章。", " At \(target) a day you'll reach chapter \(reach) before the \(exam.title).")
    }
}

/// The cat with what it says beside it.
private struct CatLine: View {
    var mood: Mascot.Mood
    var hop: Int
    var text: String

    var body: some View {
        HStack(spacing: 10) {
            Mascot(mood: mood, size: 72, hop: hop)
            MascotBubble(text: text, pointing: .leading)
                .padding(.leading, 6)
                .contentTransition(.opacity)
            Spacer(minLength: 0)
        }
    }
}

/// A language to learn, as a card cut from its own paper with a few sample
/// words on it.
private struct LanguageChoice: View {
    @Environment(\.appStyle) private var appStyle
    var title: String
    var subtitle: String
    var samples: [String]
    var paper: PaperKind
    var tilt: Double
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.display(.title, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text(subtitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                HStack(spacing: 4) {
                    ForEach(samples, id: \.self) { sample in
                        Text(sample)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Palette.accent)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Palette.accent.opacity(0.12), in: Capsule())
                    }
                }
                .minimumScaleFactor(0.7)
                .accessibilityHidden(true)
            }
            .padding(.vertical, 22)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .background { surface }
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
    }

    @ViewBuilder
    private var surface: some View {
        if appStyle == .collage {
            PaperSurface(kind: paper)
                .clipShape(TornEdgeShape(edges: [.bottom], depth: 4, seed: title.count + 3))
                .overlay(alignment: .top) { TapeStrip(width: 46, angle: tilt * 4).offset(y: -10) }
                .rotationEffect(.degrees(tilt))
        } else {
            PremiumSurface(radius: 24)
        }
    }
}

/// A daily goal on a sticky note; the chosen one is pressed flat and stamped.
private struct StickyNote: View {
    @Environment(\.appStyle) private var appStyle
    var count: Int
    var label: String
    var unit: String
    var paper: PaperKind
    var tilt: Double
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(count)")
                    .font(.displaySize(36, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                Text(unit).font(.caption).foregroundStyle(.secondary)
                Text(label)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(selected ? Palette.accent : Palette.ink.opacity(0.75))
                    .padding(.top, 2)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background { surface }
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Palette.accent)
                        .background(Circle().fill(.white).padding(3))
                        .offset(x: 8, y: -8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .rotationEffect(.degrees(selected ? 0 : tilt))
            .scaleEffect(selected ? 1.04 : 1)
            // The chosen note stands out; the others step back, so a bright
            // paper (the mustard 20) never reads as the choice.
            .saturation(selected ? 1 : 0.55)
            .opacity(selected ? 1 : 0.82)
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var surface: some View {
        if appStyle == .collage {
            PaperSurface(kind: paper)
                .shadow(color: .black.opacity(selected ? 0.16 : 0.06), radius: selected ? 8 : 2, y: selected ? 4 : 1)
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(selected ? Palette.accent.opacity(0.14) : Palette.surface)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        }
    }
}

/// A word on a small index card; tapped, it gets a green "known" stamp.
private struct WordTag: View {
    @Environment(\.appStyle) private var appStyle
    var text: String
    var known: Bool
    var seed: Int
    var action: () -> Void

    private var tilt: Double { [-2.0, 1.5, -1.0, 2.0, -1.5, 1.0, -2.5, 1.8, -0.8][seed % 9] }

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.display(.headline, weight: .semibold))
                .foregroundStyle(known ? Palette.known : Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background { surface }
                .overlay(alignment: .bottomTrailing) {
                    if known {
                        StampMark(color: Palette.known, size: 30, angle: -14) {
                            Image(systemName: "checkmark").font(.caption.weight(.heavy))
                        }
                        .offset(x: 6, y: 8)
                        .transition(.scale(scale: 1.6).combined(with: .opacity))
                    }
                }
                .rotationEffect(.degrees(known ? 0 : tilt))
                .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel(text)
        .accessibilityAddTraits(known ? .isSelected : [])
    }

    @ViewBuilder
    private var surface: some View {
        if appStyle == .collage {
            PaperSurface(kind: known ? .sage : .ivory)
                .overlay(alignment: .top) { Rectangle().fill(Collage.margin.opacity(0.6)).frame(height: 1.5).padding(.top, 12) }
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(known ? Palette.known.opacity(0.14) : Palette.surface)
                .shadow(color: .black.opacity(0.07), radius: 6, y: 2)
        }
    }
}

// MARK: WordCat Next

/// The exams the welcome asks about. 學測, 統測 and 會考 get a countdown to
/// their usual day (the learner can change it in Me).
enum WelcomeExam: String, CaseIterable {
    case gsat, tvee, cap, proficiency, none

    var icon: String {
        switch self {
        case .gsat: "graduationcap.fill"
        case .tvee: "wrench.and.screwdriver.fill"
        case .cap: "book.fill"
        case .proficiency: "rosette"
        case .none: "leaf.fill"
        }
    }

    /// Asked of learners of English only, so in Chinese.
    var title: String {
        switch self {
        case .gsat: "學測"
        case .tvee: "統測"
        case .cap: "會考"
        case .proficiency: "英檢・多益"
        case .none: "沒有考試，就是想變強"
        }
    }

    /// The exam's usual day on or after `now`: 學測 the third Saturday of
    /// January, 統測 the last Saturday of April, 會考 the third Saturday of May.
    func date(after now: Date) -> String? {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: now)
        let today = calendar.startOfDay(for: now)
        for candidate in [year, year + 1] {
            let parts: DateComponents
            switch self {
            case .gsat: parts = DateComponents(year: candidate, month: 1, weekday: 7, weekdayOrdinal: 3)
            case .tvee: parts = DateComponents(year: candidate, month: 4, weekday: 7, weekdayOrdinal: -1)
            case .cap: parts = DateComponents(year: candidate, month: 5, weekday: 7, weekdayOrdinal: 3)
            case .proficiency, .none: return nil
            }
            if let day = calendar.date(from: parts), day >= today { return DayMath.today(day) }
        }
        return nil
    }

    func detail(_ now: Date) -> String {
        guard let date = date(after: now) else {
            return self == .none ? "照自己的步調" : "依你報名的場次"
        }
        let parts = date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return date }
        return "約 \(parts[0]) 年 \(parts[1]) 月 \(parts[2]) 日"
    }
}

/// A question of the level test.
struct PlacementQuestion: Equatable {
    let word: WordEntry
    let level: Int
    let prompt: String
    let detail: String
    let options: [QuizOption]
    let answerIndex: Int
}

/// One answer to a welcome question, as a wide card.
private struct ChoiceCard: View {
    var icon: String
    var title: String
    var detail: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Palette.accent.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.display(.title3, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Palette.accent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { HomeSurface(radius: 20) }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(selected ? Palette.accent : .clear, lineWidth: 2.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Words or speaking first, as two tall cards.
private struct PillarChoice: View {
    var icon: String
    var title: String
    var detail: String
    var tint: Color
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 68, height: 68)
                    .background(tint.gradient, in: Circle())
                Text(title)
                    .font(.display(.title3, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 22)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 190)
            .background { HomeSurface(radius: 24) }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(selected ? tint : .clear, lineWidth: 3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The level test's result: fourteen books, each filled to how much of the
/// chapter the learner likely knows, the one to start in outlined.
private struct ResultShelf: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var shares: [Double]
    var current: Int
    @State private var filled = false

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(shares.enumerated()), id: \.offset) { index, share in
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Palette.fill)
                            .overlay(alignment: .bottom) {
                                GeometryReader { proxy in
                                    Rectangle()
                                        .fill(index == current ? Palette.accent : Palette.known)
                                        .frame(height: proxy.size.height * (filled ? min(1, max(0.04, share)) : 0))
                                        .frame(maxHeight: .infinity, alignment: .bottom)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            }
                            .overlay {
                                if index == current {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Palette.accent, lineWidth: 2)
                                }
                            }
                            .frame(height: 74 * (index % 3 == 1 ? 0.9 : index % 3 == 2 ? 0.95 : 1))
                        Text("\(index + 1)")
                            .font(.caption2.weight(index == current ? .heavy : .semibold))
                            .foregroundStyle(index == current ? Palette.accent : Palette.secondaryLabel)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Capsule()
                .fill(Color(red: 0.55, green: 0.38, blue: 0.25).opacity(0.75))
                .frame(height: 4)
        }
        .padding(16)
        .background { HomeSurface(radius: 22) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.t("十四章的書架，從第 \(current + 1) 章開始", "Fourteen chapters; starting at chapter \(current + 1)"))
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.9).delay(0.2)) { filled = true }
        }
    }
}
