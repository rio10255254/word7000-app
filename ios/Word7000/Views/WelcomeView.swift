import AVFoundation
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
    /// The iPhone has only a standard voice for the language learned, so the
    /// last scene shows how to get the natural one. Settled before that scene,
    /// so it does not change under the learner while they download it.
    @State private var voicePlanned = false
    /// Whether the welcome asks about the daily reminder (and notifications).
    @State private var notifyPlanned = true
    @State private var remindAt = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    /// How the welcome ends, kept while the voice scene is shown.
    @State private var ending: (known: [String], learning: [String], practice: Bool)?
    /// WordCat Next: the exam being prepared for, and the level test.
    @State private var exam: WelcomeExam?
    @State private var test = PlacementTest()
    @State private var question: PlacementQuestion?
    @State private var picked: Int?
    @State private var vocabulary: PreparedVocabulary?
    @State private var testSeed = UUID().uuidString
    /// WordCat Next: who the learner is and what they want, and the words
    /// spelled after the level test.
    @State private var profile = LearnerProfile()
    @State private var spellWords: [WordEntry] = []
    @State private var spellIndex = 0
    @State private var spellAttempt: ClozeAttempt?
    @State private var spellInput = ""
    @State private var spellOutcomes: [String: ClozeRound.Outcome] = [:]
    @State private var spellMisses = 0
    @State private var thinkingLines = 0
    @FocusState private var spellFocused: Bool
    @Environment(\.dismiss) private var dismiss
    /// WordCat Next: only the level test and the plan again, from My
    /// learning plan; what is known about the learner is kept.
    let retest: Bool
    @State private var retestLoaded = false
    var finish: (_ mode: StudyMode, _ target: Int, _ knownIds: [String], _ learningIds: [String], _ practice: Bool) -> Void

    init(retest: Bool = false,
         finish: @escaping (_ mode: StudyMode, _ target: Int, _ knownIds: [String], _ learningIds: [String], _ practice: Bool) -> Void) {
        self.retest = retest
        self.finish = finish
        _step = State(initialValue: retest ? .testIntro : .hello)
    }

    enum Step: Int, CaseIterable { case hello, stage, exam, focus, goal, words, testIntro, test, spell, thinking, result, voice, notify }

    /// The scenes in order. WordCat Next gets to know the learner of English
    /// (school, exam, what to get better at, how much a day), tests the
    /// level by meanings and then by spelling, and ends with a plan; the
    /// older welcome has three scenes.
    private var flow: [Step] {
        if retest {
            return mode == .english ? [.testIntro, .test, .spell, .thinking, .result] : [.testIntro, .test, .thinking, .result]
        }
        var steps: [Step]
        if !AppRuntime.labOnboarding {
            steps = [.hello, .goal, .words]
        } else {
            steps = mode == .english
                ? [.hello, .stage, .exam, .focus, .goal, .notify, .testIntro, .test, .spell, .thinking, .result]
                : [.hello, .focus, .goal, .notify, .testIntro, .test, .thinking, .result]
            // Asked once only: a learner who has answered is not asked again.
            if !notifyPlanned { steps.removeAll { $0 == .notify } }
        }
        // Last, when the iPhone only has a standard voice: how to get the natural one.
        if voicePlanned { steps.append(.voice) }
        return steps
    }
    private var voiceLanguage: String { mode == .english ? "en-US" : "zh-TW" }

    /// Scenes that cannot be gone back from: a test under way, the result.
    private var lockedSteps: Set<Step> { [.hello, .test, .spell, .thinking, .result, .voice] }

    private var position: Int { flow.firstIndex(of: step) ?? 0 }

    private func advance() {
        let index = position + 1
        if flow.indices.contains(index) { go(flow[index]) }
    }

    /// Every one-answer question moves on by itself once a choice is tapped,
    /// after a beat to see it marked; questions with several answers have a
    /// Next button. A second tap in that beat does not skip a scene.
    private func pickThenAdvance() {
        let from = step
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 350))
            guard step == from else { return }
            advance()
        }
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
                        case .stage: stageQuestion
                        case .exam: examQuestion
                        case .focus: focusQuestion
                        case .goal: goal
                        case .notify: notifyStep
                        case .words: words
                        case .testIntro: testIntro
                        case .test: placementTest
                        case .spell: spellCheck
                        case .thinking: thinking
                        case .result: result
                        case .voice:
                            VoiceStep(language: voiceLanguage, chinese: chinese, hop: hop) {
                                let end = ending ?? (Array(known), [], true)
                                finish(mode, target, end.known, end.learning, end.practice)
                            }
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
            if retest, !retestLoaded {
                // The learner as they are: their language, goal, profile and exam.
                retestLoaded = true
                mode = model.studyMode
                target = model.progress.dailyTarget
                profile = model.settings.learnerProfile ?? LearnerProfile()
                exam = profile.exam.flatMap(WelcomeExam.init(rawValue:))
                test = PlacementTest(start: profile.stage?.testStart ?? 2)
            }
            if placement.isEmpty { placement = placementWords(for: mode) }
            if step == .hello { notifyPlanned = model.settings.pushAsked != true }
        }
        .task(id: mode) {
            await Speaker.shared.refreshVoices()
            guard step != .voice, !retest else { return }
            voicePlanned = SpeechVoiceSelection.canSoundBetter(Speaker.shared.voices, language: voiceLanguage,
                                                               enhancedQuality: AVSpeechSynthesisVoiceQuality.enhanced.rawValue)
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
            .opacity(lockedSteps.contains(step) ? 0 : 1)
            .disabled(lockedSteps.contains(step))
            .accessibilityLabel(text("上一步", "Back"))
            Spacer(minLength: 8)
            phaseBar
            Spacer(minLength: 8)
            // While the test runs: a quiet way out, in the corner.
            if step == .test {
                Button(text("跳過", "Skip"), action: skipTest)
                    .font(.subheadline.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityHint(text("從第 1 章開始", "Start at chapter 1"))
                    .accessibilityIdentifier("welcome-test-skip")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 8)
        .tint(Palette.accent)
    }

    /// The welcome in three parts, as a learner thinks of it (about you,
    /// your level, your plan), rather than a dot for each of eleven scenes:
    /// the part under way fills as it goes, question by question in the test.
    private enum Phase: Int, CaseIterable { case about, level, plan }

    private func phase(of step: Step) -> Phase {
        switch step {
        case .hello, .stage, .exam, .focus, .goal, .notify, .words: .about
        case .testIntro, .test, .spell, .thinking: .level
        case .result, .voice: .plan
        }
    }

    private func phaseTitle(_ phase: Phase) -> String {
        switch phase {
        case .about: text("認識你", "About you")
        case .level: text("測程度", "Your level")
        case .plan: text("你的計畫", "Your plan")
        }
    }

    /// How full a part's bar is: done parts full, the current one by its
    /// scenes so far (and the questions within the test and the spelling).
    private func phaseFill(_ item: Phase) -> Double {
        let current = phase(of: step)
        if item.rawValue < current.rawValue { return 1 }
        guard item == current else { return 0 }
        let scenes = flow.filter { phase(of: $0) == current }
        guard let index = scenes.firstIndex(of: step) else { return 0 }
        var within = 0.2
        if step == .test { within = max(within, Double(test.asked) / Double(PlacementTest.maxQuestions)) }
        if step == .spell, !spellWords.isEmpty { within = max(within, Double(spellIndex) / Double(spellWords.count)) }
        return min(1, (Double(index) + within) / Double(max(1, scenes.count)))
    }

    private var phaseBar: some View {
        let current = phase(of: step)
        let phases = Phase.allCases.filter { item in flow.contains { phase(of: $0) == item } }
        return HStack(alignment: .top, spacing: 6) {
            ForEach(phases, id: \.self) { item in
                VStack(spacing: 5) {
                    GeometryReader { proxy in
                        Capsule().fill(Palette.fill)
                            .overlay(alignment: .leading) {
                                Capsule().fill(Palette.accent)
                                    .frame(width: proxy.size.width * phaseFill(item))
                            }
                    }
                    .frame(height: 6)
                    Text(phaseTitle(item))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(item == current ? Palette.accent : Palette.tertiaryLabel)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: 260)
        .animation(reduceMotion ? nil : .snappy, value: step)
        .animation(reduceMotion ? nil : .snappy, value: test.asked)
        .animation(reduceMotion ? nil : .snappy, value: spellIndex)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(phaseTitle(current))
        .accessibilityValue("\(Int((phaseFill(current) * 100).rounded()))%")
    }

    private func skipTest() {
        test = PlacementTest()
        go(.thinking)
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
        profile = LearnerProfile()
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
                    text: text("一天想背幾個字？點一個就好，之後隨時能改。", "How many words a day? Tap one; you can change it any time."))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                ForEach(Self.goals, id: \.count) { item in
                    StickyNote(count: item.count, label: text(item.zh, item.en), unit: text("個／天", "a day"),
                               paper: item.paper, tilt: item.tilt, selected: target == item.count) {
                        withAnimation(reduceMotion ? nil : Motion.pop) { target = item.count }
                        pickThenAdvance()
                    }
                    .accessibilityIdentifier("welcome-goal-\(item.count)")
                }
            }
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
                Button { end(Array(known), [], practice: true) } label: {
                    Label(text("開始，先背 5 個", "Start with 5 words"), systemImage: "arrow.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .prominentAction()
                .accessibilityIdentifier("welcome-start")
                Button(text("先逛逛字庫", "Look around first")) { end(Array(known), [], practice: false) }
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
                        pickThenAdvance()
                    }
                    .accessibilityIdentifier("welcome-exam-\(choice.rawValue)")
                }
            }
            Text(text("日期不對的話，之後在「我 → 我的學習計畫」改。", "Wrong date? Change it later in Me → My learning plan."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: WordCat Next: who you are

    private static let stages: [(stage: LearnerProfile.Stage, icon: String, zh: String, en: String)] = [
        (.juniorHigh, "backpack.fill", "國中生", "Junior high"), (.senior1, "1.circle.fill", "高一", "Senior high, year 1"),
        (.senior2, "2.circle.fill", "高二", "Senior high, year 2"), (.senior3, "3.circle.fill", "高三", "Senior high, year 3"),
        (.university, "building.columns.fill", "大學生", "University"), (.working, "briefcase.fill", "上班族", "Working"),
    ]

    private var stageQuestion: some View {
        VStack(spacing: 18) {
            CatLine(mood: .happy, hop: hop,
                    text: text("先認識一下：你現在是？我會從適合你的程度開始考。", "First, who are you? I'll start the test at your level."))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Self.stages, id: \.stage) { item in
                    TileChoice(icon: item.icon, title: text(item.zh, item.en), selected: profile.stage == item.stage) {
                        withAnimation(reduceMotion ? nil : Motion.pop) { profile.stage = item.stage }
                        // The exam most at this stage prepare for, and a test that starts nearer their level.
                        if let suggested = WelcomeExam(rawValue: item.stage.suggestedExam) {
                            exam = suggested
                            CatMemory.shared.examDate = suggested.date(after: Date())
                        }
                        test = PlacementTest(start: item.stage.testStart)
                        question = nil
                        pickThenAdvance()
                    }
                    .accessibilityIdentifier("welcome-stage-\(item.stage.rawValue)")
                }
            }
        }
    }

    // MARK: WordCat Next: what to get better at

    private static let focuses: [(focus: LearnerProfile.Focus, icon: String, zh: String, zhDetail: String, en: String, enDetail: String)] = [
        (.vocabulary, "books.vertical.fill", "單字量", "每天多學一點新字", "More words", "A few more new words a day"),
        (.spelling, "pencil.line", "拼字", "翻卡後多抽幾個字拼給我看", "Spelling", "More words to spell after the cards"),
        (.exam, "checklist", "考試題型", "翻卡後多考幾題選擇題", "Exam questions", "More multiple choice after the cards"),
        (.speaking, "mic.fill", "口說", "每天先練口說", "Speaking", "Speaking first every day"),
    ]

    private var focusQuestion: some View {
        VStack(spacing: 18) {
            CatLine(mood: .thinking, hop: hop,
                    text: text("最想加強什麼？最多選兩個，我照這個排你每天的路線。", "What do you most want to get better at? Pick up to two; I'll plan your days around it."))
            VStack(spacing: 12) {
                ForEach(Self.focuses, id: \.focus) { item in
                    ChoiceCard(icon: item.icon, title: text(item.zh, item.en), detail: text(item.zhDetail, item.enDetail),
                               selected: profile.focus.contains(item.focus)) {
                        withAnimation(reduceMotion ? nil : Motion.pop) { profile.toggle(item.focus) }
                    }
                    .accessibilityIdentifier("welcome-focus-\(item.focus.rawValue)")
                }
            }
            Button {
                model.settings.homeLead = profile.lead
                target = profile.suggestedTarget
                advance()
            } label: {
                Label(profile.focus.isEmpty ? text("都可以，下一步", "Anything, next") : text("下一步", "Next"), systemImage: "arrow.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .prominentAction()
            .accessibilityIdentifier("welcome-focus-next")
        }
        .sensoryFeedback(.selection, trigger: profile.focus)
    }

    // MARK: WordCat Next: before the test

    private var testIntro: some View {
        VStack(spacing: 24) {
            CatLine(mood: .smug, hop: hop,
                    text: text("最後兩分鐘，讓我看看你的程度。答對就出難一點，答錯就簡單一點。",
                               "Two last minutes to see your level. Right, and it gets harder; wrong, and easier."))
            VStack(alignment: .leading, spacing: 0) {
                introRow(1, text("看字選意思", "Pick the meaning"), last: false)
                if mode == .english {
                    introRow(2, text("拼 3 個字", "Spell three words"), last: false)
                }
                introRow(mode == .english ? 3 : 2, text("排出你的路線", "Your plan"), last: true)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { HomeSurface(radius: 22) }
            VStack(spacing: 10) {
                Button { advance() } label: {
                    Label(text("開始測驗", "Start the check"), systemImage: "arrow.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .prominentAction()
                .accessibilityIdentifier("welcome-test-start")
                if retest {
                    Button(text("先不要", "Not now")) { dismiss() }
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("welcome-retest-cancel")
                } else {
                    Button(text("跳過，從第 1 章開始", "Skip it and start at chapter 1")) {
                        test = PlacementTest()
                        go(.thinking)
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("welcome-test-intro-skip")
                }
            }
        }
    }

    /// One part of the check: its number on a line to the next, and its name.
    private func introRow(_ number: Int, _ title: String, last: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Text("\(number)")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Palette.surface)
                    .frame(width: 30, height: 30)
                    .background(Palette.accent.gradient, in: Circle())
                if !last {
                    Capsule().fill(Palette.accent.opacity(0.25)).frame(width: 3, height: 18)
                }
            }
            Text(title)
                .font(.headline)
                .foregroundStyle(Palette.ink)
                .padding(.top, 4)
        }
    }

    // MARK: WordCat Next: the daily reminder

    /// Asked near the start, while the plan is being made: the time of the
    /// daily reminder, a preview of it, and only then the system's question.
    private var notifyStep: some View {
        VStack(spacing: 22) {
            CatLine(mood: .smug, hop: hop,
                    text: text("讓我每天提醒你。照經驗，沒人提醒的，第三天就把我忘了。",
                               "Let me remind you each day. Without it, people forget me by day three."))
            VStack(spacing: 16) {
                ReminderPreview(time: remindAt, target: target, chinese: chinese)
                DatePicker(text("每天提醒時間", "Remind me at"), selection: $remindAt, displayedComponents: .hourAndMinute)
                    .font(.headline)
                    .tint(Palette.accent)
                    .accessibilityIdentifier("welcome-notify-time")
            }
            .padding(18)
            .background { HomeSurface(radius: 22) }
            VStack(spacing: 10) {
                Button(action: allowReminders) {
                    Label(text("好，每天提醒我", "Yes, remind me"), systemImage: "bell.badge.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .prominentAction()
                .accessibilityIdentifier("welcome-notify-allow")
                Button(text("先不要", "Not now")) {
                    model.settings.reminderAskDeclinedOn = model.today
                    advance()
                }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
                .accessibilityIdentifier("welcome-notify-later")
            }
        }
    }

    private func allowReminders() {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: remindAt)
        let minute = (parts.hour ?? 20) * 60 + (parts.minute ?? 0)
        model.settings.reminderMinute = minute
        model.setReminderEnabled(true)
        Usage.log("reminder_time", "\(minute)")
        Task {
            // The system's own question, then on with the welcome either way.
            await PushRegistration.shared.askOnce(model)
            advance()
        }
    }

    // MARK: WordCat Next: the level test

    private var placementTest: some View {
        VStack(spacing: 18) {
            CatLine(mood: picked == nil ? .thinking : question.map { picked == $0.answerIndex } == true ? .cheer : .encourage, hop: hop,
                    text: testLine)
            if let question {
                VStack(spacing: 6) {
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
                                // Once picked: a tick on the right one, a cross on a wrong pick.
                                .overlay(alignment: .topTrailing) {
                                    if picked != nil, index == question.answerIndex || index == picked {
                                        Image(systemName: index == question.answerIndex ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(index == question.answerIndex ? Palette.known : Palette.miss)
                                            .background(Circle().fill(Palette.background))
                                            .offset(x: 6, y: -6)
                                            .transition(.scale(scale: 0.3).combined(with: .opacity))
                                    }
                                }
                                .scaleEffect(picked == index && !reduceMotion ? 1.04 : 1)
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
            } else {
                ProgressView().frame(minHeight: 200)
            }
        }
        .onAppear { if question == nil, !test.isFinished { nextQuestion() } }
        .sensoryFeedback(trigger: picked) { _, new in
            guard let new, let question else { return nil }
            return new == question.answerIndex ? .success : .error
        }
    }

    /// The cat follows the test as it moves: harder after a right answer,
    /// easier after a miss, as the level is found.
    private var testLine: String {
        guard let last = test.answers.last else {
            return text("這個字是什麼意思？不知道就選「不知道」，不扣分。", "What does this word mean? Pick \u{201C}Don't know\u{201D} if you don't; it costs nothing.")
        }
        if test.turns >= 2 { return text("差不多抓到你的程度了，再幾題。", "I've nearly got your level. A few more.") }
        return last.knew
            ? text("不錯喔，下一個難一點。", "Nice. The next one is harder.")
            : text("沒關係，換簡單一點的。", "That's fine. An easier one.")
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
        advance()
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
            advance()
        } else {
            nextQuestion()
        }
    }

    // MARK: WordCat Next: three words to spell

    private var spellCheck: some View {
        VStack(spacing: 16) {
            if spellWords.indices.contains(spellIndex), let attempt = spellAttempt,
               let sentence = Cloze.sentence(for: spellWords[spellIndex]) {
                let word = spellWords[spellIndex]
                CatLine(mood: attempt.solved ? .cheer : spellMisses > 0 ? .encourage : .thinking, hop: hop,
                        text: spellLine(word, attempt))
                Text(text("拼字 \(spellIndex + 1)/\(spellWords.count)", "Spelling \(spellIndex + 1)/\(spellWords.count)"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Palette.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Palette.accent.opacity(0.12), in: Capsule())
                    .accessibilityIdentifier("welcome-spell-position")
                ClozeCard(word: word, sentence: sentence, attempt: attempt, input: spellInput, comeBack: nil)
                    .id(word.id)
                TextField(text("輸入英文單字", "Type the English word"), text: Binding(
                    get: { spellInput },
                    set: { if !attempt.solved && !attempt.answerShown { spellInput = $0 } }
                ))
                .font(.title.weight(.semibold))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .submitLabel(.done)
                .focused($spellFocused)
                .onSubmit { checkSpelling() }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(spellFocused ? Palette.accent.opacity(0.45) : .clear, lineWidth: 2))
                .accessibilityIdentifier("welcome-spell-input")
                ButtonRow {
                    Button { giveUpSpelling() } label: {
                        Text(text("不會", "Don't know")).font(.headline).frame(maxWidth: .infinity)
                    }
                    .secondaryAction()
                    .disabled(attempt.solved || attempt.answerShown)
                    .accessibilityIdentifier("welcome-spell-unknown")
                    Button { checkSpelling() } label: {
                        Text(text("檢查", "Check")).font(.headline).frame(maxWidth: .infinity)
                    }
                    .prominentAction()
                    .disabled(spellInput.trimmed.isEmpty || attempt.solved || attempt.answerShown)
                    .accessibilityIdentifier("welcome-spell-check")
                }
            } else {
                ProgressView().frame(minHeight: 200)
            }
        }
        .onAppear {
            guard spellAttempt == nil else { return }
            let words = model.englishCoreWords
            spellWords = test.spellingWords(from: words, count: 3, seed: testSeed)
            spellOutcomes = [:]
            loadSpelling(0)
        }
        .sensoryFeedback(trigger: spellAttempt?.solved) { _, solved in solved == true ? .success : nil }
        .sensoryFeedback(.error, trigger: spellMisses)
    }

    private func spellLine(_ word: WordEntry, _ attempt: ClozeAttempt) -> String {
        if attempt.solved { return attempt.outcome == .knew ? text("拼對了！", "Spot on!") : text("對了，差一點點。", "Right, nearly.") }
        if attempt.answerShown { return text("是「\(attempt.answer)」，記一下。", "It's \u{201C}\(attempt.answer)\u{201D}. Remember it.") }
        if spellMisses > 0 { return text("不太對，再試一次。", "Not quite. Try again.") }
        let cue = Cloze.cue(for: word)?.cue ?? ChineseDisplay.conciseMeaning(word.meaningZh)
        return text("「\(cue)」英文怎麼拼？", "How do you spell \u{201C}\(cue)\u{201D}?")
    }

    private func loadSpelling(_ index: Int) {
        spellIndex = index
        spellInput = ""
        spellMisses = 0
        guard spellWords.indices.contains(index), let sentence = Cloze.sentence(for: spellWords[index]) else {
            spellAttempt = nil
            advance()
            return
        }
        spellAttempt = ClozeAttempt(answer: sentence.answer)
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            spellFocused = true
        }
    }

    /// Two tries: a slip the first time is fine, a second miss shows the word.
    private func checkSpelling() {
        guard var attempt = spellAttempt, !attempt.solved, !attempt.answerShown, !spellInput.trimmed.isEmpty else { return }
        attempt.submit(spellInput)
        if attempt.solved {
            withAnimation(reduceMotion ? nil : Motion.pop) { spellAttempt = attempt }
            finishSpelling(attempt.outcome ?? .missed)
        } else if attempt.misses >= 2 {
            while attempt.nextHelp != nil { attempt.takeHelp() }
            withAnimation(reduceMotion ? nil : Motion.reveal) { spellAttempt = attempt }
            spellMisses += 1
            finishSpelling(.missed)
        } else {
            withAnimation(reduceMotion ? nil : Motion.reveal) { spellAttempt = attempt }
            spellMisses += 1
            spellInput = ""
        }
    }

    private func giveUpSpelling() {
        guard var attempt = spellAttempt, !attempt.solved else { return }
        while attempt.nextHelp != nil { attempt.takeHelp() }
        withAnimation(reduceMotion ? nil : Motion.reveal) { spellAttempt = attempt }
        finishSpelling(.missed)
    }

    private func finishSpelling(_ outcome: ClozeRound.Outcome) {
        let word = spellWords[spellIndex]
        spellOutcomes[word.id] = outcome
        let index = spellIndex
        Task {
            try? await Task.sleep(for: .milliseconds(outcome == .missed ? 1400 : 700))
            guard spellIndex == index else { return }
            if index + 1 < spellWords.count {
                withAnimation(reduceMotion ? nil : Motion.reveal) { loadSpelling(index + 1) }
            } else {
                profile.recordSpelling(Array(spellOutcomes.values))
                spellFocused = false
                advance()
            }
        }
    }

    // MARK: WordCat Next: the cat works it out

    private var thinking: some View {
        let lines = mode == .english
            ? [text("看你認得哪些字", "Which words you know"), text("看你拼得出幾個", "How many you can spell"), text("排好你每天的路線", "Planning your days")]
            : [text("看你認得哪些字", "Which words you know"), text("排好你每天的路線", "Planning your days")]
        return VStack(spacing: 26) {
            Mascot(mood: .thinking, size: 120, hop: hop).popIn()
            Text(text("傻貓在算……", "Silly Cat is working it out…"))
                .font(.display(.title2, weight: .bold))
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    HStack(spacing: 12) {
                        ZStack {
                            if index < thinkingLines {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.known)
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                ProgressView().controlSize(.small)
                            }
                        }
                        .font(.title3)
                        .frame(width: 26)
                        Text(line)
                            .font(.headline)
                            .foregroundStyle(index < thinkingLines ? Palette.ink : Palette.secondaryLabel)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { HomeSurface(radius: 22) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("welcome-thinking")
        .task {
            thinkingLines = 0
            let pause: Duration = reduceMotion || AppRuntime.uiTesting ? .milliseconds(250) : .milliseconds(750)
            for count in 1...lines.count {
                try? await Task.sleep(for: pause)
                withAnimation(reduceMotion ? nil : Motion.pop) { thinkingLines = count }
            }
            try? await Task.sleep(for: pause)
            advance()
        }
    }

    // MARK: WordCat Next: the result

    private var plan: PersonalPlan {
        PersonalPlan(test: test, profile: profile, target: target, daysToExam: CatMemory.shared.daysToExam)
    }

    private var result: some View {
        let estimate = test.estimatedKnownWords
        let plan = plan
        let shares = test.answers.isEmpty ? Array(repeating: 0.0, count: PlacementTest.topLevel) : test.levelShares
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
                    if let spelling = profile.spelling {
                        Text(spellingVerdict(spelling, lowered: plan.startChapter < test.startChapter))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("welcome-result-spelling")
                    }
                }
                .popIn()
            } else {
                Mascot(mood: .happy, size: 96, hop: hop).popIn()
            }
            ResultShelf(shares: shares, current: plan.startChapter - 1)
                .entrance(1)
            planCard(plan)
                .entrance(2)
            VStack(spacing: 10) {
                Button { complete(practice: !retest) } label: {
                    Label(retest ? text("用這個新起點", "Use this new start") : text("開始今天的單字", "Start today's words"),
                          systemImage: retest ? "checkmark" : "arrow.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .prominentAction()
                .accessibilityIdentifier("welcome-start")
                if retest {
                    Button(text("維持原本的計畫", "Keep my plan")) { dismiss() }
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("welcome-retest-keep")
                } else {
                    Button(text("先逛逛", "Look around first")) { complete(practice: false) }
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("welcome-skip")
                }
            }
            .padding(.top, 4)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("welcome-result")
    }

    private func spellingVerdict(_ spelling: Double, lowered: Bool) -> String {
        switch spelling {
        case ..<0.34:
            lowered ? text("認得，但拼不太出來：先從低一章開始。", "You know them but can't spell them yet: we start a chapter lower.")
                    : text("拼字要多練，我會多抽幾個給你寫。", "Spelling needs work; I'll ask you to spell more.")
        case ..<0.8: text("拼字還可以，我會多抽幾個給你寫。", "Spelling is fair; I'll ask you to spell a few more.")
        default: text("拼字很穩，抽查會少一點。", "Your spelling is solid; fewer checks.")
        }
    }

    /// The plan in the learner's own numbers, each line from an answer they gave.
    private func planCard(_ plan: PersonalPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(text("你的學習路線", "Your plan"))
                .font(.display(.title3, weight: .heavy))
                .foregroundStyle(Palette.ink)
            planRow("book.fill", text("從第 \(plan.startChapter) 章開始", "Start at chapter \(plan.startChapter)"),
                    text("太簡單的字直接跳過", "Words too easy for you are skipped"))
            planRow("plus.circle.fill", text("每天 \(plan.wordsPerDay) 個字", "\(plan.wordsPerDay) words a day"),
                    text("新字和該複習的字一起算", "New words and reviews together"))
            if mode == .english {
                planRow("pencil.line", text("翻卡後拼 \(plan.spellChecks) 個、考 \(plan.examChecks) 題", "Then spell \(plan.spellChecks) and answer \(plan.examChecks)"),
                        text("拼字穩了就少抽，退步了就多抽", "Fewer when spelling holds, more when it slips"))
            }
            planRow(plan.lead == .speaking ? "mic.fill" : "rectangle.on.rectangle.angled",
                    plan.lead == .speaking ? text("每天先練口說", "Speaking first each day") : text("單字先，口說後", "Words first, then speaking"),
                    text("兩個每天都有", "Both, every day"))
            if let reach = plan.reachChapter, let exam, exam.date(after: Date()) != nil {
                planRow("graduationcap.fill", text("\(exam.title)前讀到第 \(reach) 章", "Chapter \(reach) by the \(exam.title)"),
                        text("照這個速度", "at this pace"))
                    .accessibilityIdentifier("welcome-plan-reach")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { HomeSurface(radius: 22) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("welcome-plan")
    }

    private func planRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Palette.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.headline).foregroundStyle(Palette.ink)
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Saves what was learned about the learner and starts. Words missed in
    /// the spelling start as words being learned.
    private func complete(practice: Bool) {
        var profile = profile
        // Only a test actually taken sets where new words start.
        profile.startChapter = test.answers.isEmpty ? nil : plan.startChapter
        profile.startMode = mode.rawValue
        profile.exam = exam?.rawValue
        model.settings.learnerProfile = profile
        // A new level check keeps the learner's own choice of what comes first.
        if !retest { model.settings.homeLead = profile.lead }
        let learning = spellOutcomes.filter { $0.value == .missed }.map(\.key)
        end(test.knownIds, learning, practice: practice)
    }

    /// On to the voice scene when it is wanted; otherwise the welcome is done.
    private func end(_ known: [String], _ learning: [String], practice: Bool) {
        guard voicePlanned else { finish(mode, target, known, learning, practice); return }
        ending = (known, learning, practice)
        go(.voice)
    }
}

// MARK: 4. A natural voice

/// How to download the iPhone's natural voice for what is learned (an app
/// cannot download it), the voice as it sounds now, and the switch noticed
/// the moment iOS has it: a tick, and the cat says hello in the new voice.
private struct VoiceStep: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var language: String
    var chinese: Bool
    var hop: Int
    var done: () -> Void
    @State private var switched = 0

    private func text(_ zh: String, _ en: String) -> String { chinese ? zh : en }
    private var preferences: SpeechPreferences { model.settings.speech ?? SpeechPreferences() }
    private var learningChinese: Bool { language.hasPrefix("zh") }
    private var upgraded: Bool {
        !SpeechVoiceSelection.canSoundBetter(Speaker.shared.voices, language: language,
                                             enhancedQuality: AVSpeechSynthesisVoiceQuality.enhanced.rawValue)
    }
    private var sample: String {
        learningChinese ? "很高興認識你，我們一起學幾個字吧。" : "Nice to meet you. Let's learn a few words together."
    }

    var body: some View {
        VStack(spacing: 20) {
            CatLine(mood: upgraded ? .cheer : .happy, hop: hop + switched,
                    text: upgraded ? text("換好了！聽聽看，是不是像真人多了？", "Done! Have a listen: more like a real person, right?")
                                   : text("最後一件事：我的聲音可以更像真人。iPhone 的好聲音要你自己下載一次，免費。",
                                          "One last thing: I can sound much more like a real person. The iPhone's natural voice is a free download you do once."))
            if upgraded { switchedCard.transition(.scale(scale: 0.92).combined(with: .opacity)) } else { stepsCard }
            Button {
                Speaker.shared.speak(sample, language: language, preferences: preferences)
            } label: {
                Label(upgraded ? text("再聽一次", "Hear it again") : text("聽聽現在的聲音", "Hear the voice now"),
                      systemImage: "speaker.wave.2.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .secondaryAction()
            .accessibilityIdentifier("welcome-voice-preview")
            VStack(spacing: 10) {
                if upgraded {
                    Button(action: done) {
                        Label(text("開始", "Start"), systemImage: "arrow.right")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .prominentAction()
                    .accessibilityIdentifier("welcome-voice-done")
                } else {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    } label: {
                        Label(text("打開設定", "Open Settings"), systemImage: "gear")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .prominentAction()
                    .accessibilityIdentifier("welcome-voice-settings")
                    Button(text("先開始，晚點再下載", "Start now, download later"), action: done)
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("welcome-voice-done")
                }
            }
            .padding(.top, 4)
        }
        .animation(reduceMotion ? nil : Motion.reveal, value: upgraded)
        // Back from Settings: look again, in case iOS has not said so yet.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await Speaker.shared.refreshVoices(fresh: true) } }
        }
        .onChange(of: upgraded) { _, now in
            guard now else { return }
            switched += 1
            Speaker.shared.stop()
            Speaker.shared.speak(sample, language: language, preferences: preferences)
        }
        .sensoryFeedback(.success, trigger: switched) { _, _ in model.settings.hapticsEnabled ?? true }
        .onDisappear { Speaker.shared.stop() }
    }

    /// The steps, drawn as the screens of Settings they happen on.
    private var stepsCard: some View {
        VoiceDownloadGuide(learningChinese: learningChinese, chinese: chinese)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityIdentifier("welcome-voice-steps")
    }

    /// The natural voice is in: which one now reads.
    private var switchedCard: some View {
        let name = Speaker.shared.selectedVoice(language: language, preferences: preferences)?.name
            ?? SpeechVoiceSelection.recommendedVoice(language: language).name
        return HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundStyle(Palette.known)
            VStack(alignment: .leading, spacing: 2) {
                Text(text("已經換成自然的聲音", "Now using the natural voice"))
                    .font(.headline)
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Palette.known.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("welcome-voice-switched")
    }
}

/// The daily reminder as it will look on the lock screen, at the time picked.
private struct ReminderPreview: View {
    var time: Date
    var target: Int
    var chinese: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Mascot(mood: .smug, size: 38, hop: 0)
                .frame(width: 42, height: 42)
                .background(Palette.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(chinese ? "單字貓" : "WordCat").font(.subheadline.weight(.bold))
                    Spacer(minLength: 6)
                    Text(time, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                Text(chinese ? "今天的 \(target) 個字還沒背。我等你，但我會記仇。"
                             : "Today's \(target) words are waiting. I'll wait too, and I'll remember.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Palette.fill, lineWidth: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("welcome-notify-preview")
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
            MascotBubble(text: text, pointing: .leading, large: true)
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

/// A short answer as a square tile, two to a row.
private struct TileChoice: View {
    var icon: String
    var title: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Palette.accent.gradient, in: Circle())
                Text(title)
                    .font(.display(.headline, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 128)
            .background { HomeSurface(radius: 22) }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(selected ? Palette.accent : .clear, lineWidth: 2.5)
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
