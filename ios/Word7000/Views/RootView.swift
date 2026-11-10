import SwiftUI
import Word7000Core

enum AppTab: Hashable {
    case today, practice, words, me
    /// The classic layout's chapters (LearningPathView), in place of Practice.
    case learning
}

/// What runs full screen on top of the tabs.
enum Activity: Identifiable, Hashable {
    case study
    case quiz
    /// A quiz already set up in the sheet on Today.
    case quizReady
    case speaking
    case spelling
    case exam
    case scan
    /// WordCat Next: today's round as fill-in-the-blank questions.
    case cloze
    /// WordCat Next: exam-style questions on learned words, from the word card.
    case quickExam
    /// WordCat Next: Sunday's quiz on the week's words.
    case weeklyExam

    var id: Self { self }
}

/// Three tabs, like Apple's own apps: today's practice, the words, and you.
/// Studying and quizzes take the whole screen so nothing competes with the card.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(AccountModel.self) private var account
    @Environment(PlusModel.self) private var plus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var announcements = AnnouncementStore.shared
    @State private var updateGate = UpdateGate.shared
    @State private var plusAfterAnnouncement = false
    @State private var tab: AppTab = .today
    @State private var activity: Activity?
    @State private var signInForScan = false
    @State private var pendingActivity: Activity?
    @State private var scanAfterSignIn = false
    @State private var plansAfterRecap = false
    @State private var welcomeOpen = false
    @State private var studyAfterWelcome = false
    /// WordCat Next: today's stamp, once words and speaking are done.
    @State private var dayCompleteOpen = false
    /// A new learner choosing classic or easy mode, after the first launch.
    @State private var layoutChoiceOpen = false
    /// The Me tab's pages, kept here so Settings stays open when changing the
    /// study mode rebuilds the tabs in the other language.
    @State private var mePath: [MeRoute] = []

    var body: some View {
        withFirstLaunch
        .task { welcomeOpen = model.settings.onboardingComplete != true; openRequestedPractice() }
        // Notifications are asked for once, as soon as the app opens, so the
        // developer's announcements reach every learner from the start.
        .task {
            try? await Task.sleep(for: .seconds(1))
            // WordCat Next tries asking after the first words routine instead,
            // once a time is picked (ReminderAskCard).
            guard !AppRuntime.labOnboarding else { return }
            await PushRegistration.shared.askOnce(model)
        }
        .onChange(of: PracticeLaunch.shared.requested) { _, _ in openRequestedPractice() }
        .task { await IntelligenceSettings.shared.refreshPolicy() }
        // The speech model for spoken answers arrives before the first take.
        .task(id: model.studyMode) {
            guard !AppRuntime.uiTesting else { return }
            let language = model.studyMode == .chinese ? "zh-TW" : "en-US"
            // The model that turns speech into text while speaking, too.
            LiveListener.prepareLiveModel(language: language)
            await SpeakingRecorder().refresh(language: language)
        }
        // The developer's messages to everyone: checked on launch and on
        // coming back, each shown once when nothing else is on screen.
        .task {
            await updateGate.refresh(account: account)
            try? await Task.sleep(for: .seconds(2))
            await announcements.refresh(account: account, plus: plus)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await updateGate.refresh(account: account)
                    await announcements.refresh(account: account, plus: plus)
                }
            }
        }
        // A retired version shows only the way to update, over everything:
        // whatever was open is closed first so nothing sits above it.
        // A retired version shows only the way to update, in a window above
        // everything; practice in progress is closed behind it.
        .onChange(of: updateGate.required, initial: true) { _, required in
            guard let required else { UpdateWindow.shared.hide(); return }
            activity = nil
            plus.paywallReason = nil
            UpdateWindow.shared.show(required, style: model.settings.appStyle ?? .standard,
                                     scheme: model.settings.theme.colorScheme)
        }
        .fullScreenCover(item: Binding(get: { (updateGate.required == nil && activity == nil && !welcomeOpen && !layoutChoiceOpen && !dayCompleteOpen && plus.paywallReason == nil && !plus.trialRecapPending
                                     && !model.styleChoiceDue && !signInForScan) ? announcements.current : nil },
                             set: { if $0 == nil, let shown = announcements.current { announcements.markSeen(shown) } }),
               onDismiss: {
            if plusAfterAnnouncement { plusAfterAnnouncement = false; plus.paywallReason = .general }
        }) { message in
            AnnouncementSheet(message: message, openPlus: { plusAfterAnnouncement = true })
        }
        .onOpenURL { url in
            guard url.scheme == "word7000", url.host == "study", !welcomeOpen else { return }
            if activity == nil { activity = .study }
        }
        .sensoryFeedback(.selection, trigger: tab) { _, _ in model.settings.hapticsEnabled ?? true }
        // The tabs are rebuilt when the study mode changes, so the switch's tick is felt here.
        .sensoryFeedback(.selection, trigger: model.studyMode) { _, _ in model.settings.hapticsEnabled ?? true }
        .safeAreaInset(edge: .top) {
            if model.storageFailed {
                HStack {
                    Label {
                        Text(A.saveFailed)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Palette.review)
                            .symbolEffect(.bounce, value: model.storageFailed)
                    }
                    .font(.footnote)
                    Button(L.t("重試", "Retry")) { model.saveNow() }
                }
                .padding(12)
                .background(Palette.surface)
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(Motion.reveal, value: model.storageFailed)
    }

    /// The tabs with their own reactions and the first sheets. `body` is
    /// split in three so the release build type-checks it in reasonable time.
    private var withSheets: some View {
        tabs
        // The interface language follows the study mode; rebuild on change.
        .id(model.studyMode)
        // WordCat Next: Silly Cat pops in from the edges now and then.
        .overlay { CatPeekHost() }
        .onChange(of: tab) { _, new in
            CatPeek.shared.poke(CatPeek.tabLines(new), mood: .smug, chance: 0.35, gap: 30)
        }
        // A tab the other layout does not have is left for Today.
        .onChange(of: model.classicLayout) { _, classic in
            if tab == (classic ? .practice : .learning) { tab = .today }
        }
        .task(id: scenePhase == .active && activity == nil) {
            guard scenePhase == .active, activity == nil else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 45...80)))
                guard !Task.isCancelled, !welcomeOpen, plus.paywallReason == nil else { continue }
                CatPeek.shared.poke(CatPeek.idleLines, mood: [.smug, .idle, .cheeky].randomElement() ?? .smug, chance: 0.6, gap: 40)
            }
        }
        .task { Feel.enabled = model.settings.hapticsEnabled ?? true }
        .onChange(of: model.settings.hapticsEnabled) { _, on in Feel.enabled = on ?? true }
        .environment(\.locale, Locale(identifier: L.zh ? "zh_Hant_TW" : "en_US"))
        .sheet(item: Binding(get: { plus.paywallReason }, set: { plus.paywallReason = $0 })) { reason in
            PaywallView(reason: reason)
        }
        .sheet(isPresented: Binding(get: { plus.trialRecapPending && plus.paywallReason == nil && activity == nil && !signInForScan && !welcomeOpen && model.settings.onboardingComplete == true },
                                    set: { if !$0 { plus.markTrialRecapShown() } }), onDismiss: {
            if plansAfterRecap { plansAfterRecap = false; plus.paywallReason = .general }
        }) {
            TrialRecapView(seePlans: { plansAfterRecap = true })
        }
        .sheet(isPresented: $signInForScan, onDismiss: {
            if scanAfterSignIn { scanAfterSignIn = false; plus.require(.scan) { activity = .scan } }
        }) {
            SignInSheet(reason: .scan, onSignedIn: {
                scanAfterSignIn = true
            })
        }
    }

    /// The full-screen activities, the day's stamp and the first launch.
    private var withCovers: some View {
        withSheets
        .onChange(of: activity) { _, new in
            if let new, let step = GuideStep(activity: new) { model.noteTried(step) }
        }
        .fullScreenCover(item: $activity, onDismiss: {
            guard let next = pendingActivity else {
                if model.dayCompleteDue { dayCompleteOpen = true } else { openRequestedPractice() }
                return
            }
            pendingActivity = nil
            activity = next
        }) { activity in
            Group {
            switch activity {
            case .study:
                StudySessionView(startQuiz: { switchTo(.quiz) })
            case .quiz, .quizReady:
                QuizSessionView(studyMissed: { ids in
                    model.startStudySession(onlyIds: ids)
                    switchTo(.study)
                }, skipSetup: activity == .quizReady)
            case .speaking:
                SpeakingSessionView()
            case .spelling:
                SpellingSessionView(studyMissed: { ids in
                    model.startStudySession(onlyIds: ids)
                    switchTo(.study)
                })
            case .exam:
                ExamView(studyMissed: { ids in
                    model.startStudySession(onlyIds: ids)
                    switchTo(.study)
                })
            case .scan:
                ScanView(onStudy: { switchTo(.study) })
            case .cloze:
                ClozeSessionView()
            case .quickExam, .weeklyExam:
                ExamRoundView(kind: activity == .weeklyExam ? .weekly : .quick, studyMissed: { ids in
                    model.startStudySession(onlyIds: ids)
                    switchTo(.study)
                })
            }
            }
            // The cat follows you into practice too, to comment on your answers.
            .overlay { CatPeekHost() }
        }
        .fullScreenCover(isPresented: $dayCompleteOpen, onDismiss: openRequestedPractice) {
            DayCompleteView()
        }
        .task {
            // The screenshot tests show the stamp straight away.
            if ProcessInfo.processInfo.arguments.contains("-uiTestingDayCompleteNow") { dayCompleteOpen = true }
        }
        .sheet(isPresented: Binding(get: { model.styleChoiceDue && activity == nil && !welcomeOpen && !layoutChoiceOpen && !signInForScan
                                           && plus.paywallReason == nil && !plus.trialRecapPending },
                                    set: { if !$0 { model.settings.stylePicked = true } })) {
            StyleChoiceSheet()
        }
    }

    /// The first launch, and the choice of classic or easy mode after it.
    private var withFirstLaunch: some View {
        withCovers
        .fullScreenCover(isPresented: $welcomeOpen, onDismiss: {
            // A new learner picks classic or easy mode before anything else.
            if model.settings.layoutChosen == nil, AppRuntime.layoutChoice {
                layoutChoiceOpen = true
            } else {
                afterWelcome()
            }
        }) {
            WelcomeView { mode, target, knownIds, learningIds, practice in
                model.settings.onboardingComplete = true
                model.settings.guideActive = true
                model.setStudyMode(mode)
                model.setDailyTarget(target)
                model.applyPlacement(knownIds: knownIds, learningIds: learningIds)
                if practice { model.startStudySession(limit: 5) }
                studyAfterWelcome = practice
                if !practice { tab = .words }
                welcomeOpen = false
                model.saveNow()
            }
        }
        .fullScreenCover(isPresented: $layoutChoiceOpen, onDismiss: afterWelcome) {
            LayoutChoiceView()
        }
        .task {
            // The UI tests of the choice open it straight away.
            if ProcessInfo.processInfo.arguments.contains("-uiTestingLayoutChoice") { layoutChoiceOpen = true }
        }
    }

    /// After the first launch (and the layout choice): the first cards, or
    /// whatever practice was asked for.
    private func afterWelcome() {
        if studyAfterWelcome {
            studyAfterWelcome = false
            PracticeLaunch.shared.requested = nil
            activity = .study
        } else { openRequestedPractice() }
    }

    /// The tabs: the layout's first two, then Words and Me. Split out of
    /// `body` so the release build type-checks it in reasonable time.
    private var tabs: some View {
        TabView(selection: $tab) {
            if model.classicLayout {
                classicTabs
            } else {
                pathTabs
            }

            NavigationStack {
                WordsView(scan: openScan, study: { activity = .study })
            }
            .tabItem { Label(L.tabWords, systemImage: "books.vertical.fill") }
            .tag(AppTab.words)

            NavigationStack(path: $mePath) {
                MeView()
            }
            .tabItem { Label(L.tabMe, systemImage: "person.crop.circle.fill") }
            .tag(AppTab.me)
        }
    }

    /// The classic layout: 2.0.2's Today with its practice tiles, and
    /// today's path as chapters in a tab of their own.
    @ViewBuilder
    private var classicTabs: some View {
        ClassicTodayView(start: startActivity)
            .tabItem { Label(L.tabToday, systemImage: "sun.max.fill") }
            .tag(AppTab.today)

        NavigationStack {
            LearningPathView(start: startActivity, showWords: { tab = .words })
        }
        .tabItem { Label(L.t("語言學習", "Language learning"), systemImage: "map.fill") }
        .tag(AppTab.learning)
    }

    /// Today's path, and every way to practise outside it.
    @ViewBuilder
    private var pathTabs: some View {
        // Today has no navigation bar: its own header takes that place, and
        // a hidden bar would still sit over it and swallow taps.
        TodayView(start: startActivity, showWords: { tab = .words })
            .tabItem { Label(L.tabToday, systemImage: "sun.max.fill") }
            .tag(AppTab.today)

        // WordCat Next: every way to practise outside today's path.
        NavigationStack {
            PracticeView(start: startActivity)
        }
        .tabItem { Label(L.t("練習", "Practice"), systemImage: "dumbbell.fill") }
        .tag(AppTab.practice)
    }

    /// Opens something full screen from a tab: the mock exam asks for
    /// Premium first, and scanning for an account.
    private func startActivity(_ next: Activity) {
        if next == .exam {
            plus.require(.examPractice) { activity = .exam }
        } else if next == .scan {
            openScan()
        } else {
            activity = next
        }
    }

    /// Scanned banks live in the learner's account, so scanning asks a guest
    /// to sign in first (when accounts are available at all).
    private func openScan() {
        if account.configured, !account.isPermanent {
            signInForScan = true
        } else {
            plus.require(.scan) { activity = .scan }
        }
    }

    private func openRequestedPractice() {
        if let requested = PracticeLaunch.shared.requested, requested == activity {
            PracticeLaunch.shared.requested = nil
            return
        }
        guard !welcomeOpen, model.settings.onboardingComplete == true, activity == nil,
              !signInForScan, plus.paywallReason == nil,
              let requested = PracticeLaunch.shared.requested else { return }
        PracticeLaunch.shared.requested = nil
        activity = requested
    }

    /// Closes the current full-screen activity and opens another.
    private func switchTo(_ next: Activity) {
        if next == .study, model.studySession == nil || model.studySession?.isComplete == true {
            model.startStudySession()
        }
        pendingActivity = next
        activity = nil
    }
}
