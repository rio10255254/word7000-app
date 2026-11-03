import SwiftUI
import Word7000Core

enum AppTab: Hashable {
    case today, words, me
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

    var body: some View {
        TabView(selection: $tab) {
            // Today has no navigation bar: its own header takes that place, and
            // a hidden bar would still sit over it and swallow taps.
            TodayView(start: { next in
                if next == .exam {
                    plus.require(.examPractice) { activity = .exam }
                } else if next == .scan {
                    openScan()
                } else {
                    activity = next
                }
            })
            .tabItem { Label(L.tabToday, systemImage: "sun.max.fill") }
            .tag(AppTab.today)

            NavigationStack {
                WordsView(scan: openScan, study: { activity = .study })
            }
            .tabItem { Label(L.tabWords, systemImage: "books.vertical.fill") }
            .tag(AppTab.words)

            NavigationStack {
                MeView()
            }
            .tabItem { Label(L.tabMe, systemImage: "person.crop.circle.fill") }
            .tag(AppTab.me)
        }
        // The interface language follows the study mode; rebuild on change.
        .id(model.studyMode)
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
        .onChange(of: activity) { _, new in
            if let new, let step = GuideStep(activity: new) { model.noteTried(step) }
        }
        .fullScreenCover(item: $activity, onDismiss: {
            guard let next = pendingActivity else { openRequestedPractice(); return }
            pendingActivity = nil
            activity = next
        }) { activity in
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
            }
        }
        .sheet(isPresented: Binding(get: { model.styleChoiceDue && activity == nil && !welcomeOpen && !signInForScan
                                           && plus.paywallReason == nil && !plus.trialRecapPending },
                                    set: { if !$0 { model.settings.stylePicked = true } })) {
            StyleChoiceSheet()
        }
        .fullScreenCover(isPresented: $welcomeOpen, onDismiss: {
            if studyAfterWelcome {
                studyAfterWelcome = false
                PracticeLaunch.shared.requested = nil
                activity = .study
            } else { openRequestedPractice() }
        }) {
            WelcomeView { mode, target, knownIds, practice in
                model.settings.onboardingComplete = true
                model.settings.guideActive = true
                model.setStudyMode(mode)
                model.setDailyTarget(target)
                model.applyPlacement(knownIds: knownIds)
                if practice { model.startStudySession(limit: 5) }
                studyAfterWelcome = practice
                if !practice { tab = .words }
                welcomeOpen = false
                model.saveNow()
            }
        }
        .task { welcomeOpen = model.settings.onboardingComplete != true; openRequestedPractice() }
        .onChange(of: PracticeLaunch.shared.requested) { _, _ in openRequestedPractice() }
        .task { await IntelligenceSettings.shared.refreshPolicy() }
        // The speech model for spoken answers arrives before the first take.
        .task(id: model.studyMode) {
            guard !AppRuntime.uiTesting else { return }
            await SpeakingRecorder().refresh(language: model.studyMode == .chinese ? "zh-TW" : "en-US")
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
        .fullScreenCover(item: Binding(get: { (updateGate.required == nil && activity == nil && !welcomeOpen && plus.paywallReason == nil && !plus.trialRecapPending
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
