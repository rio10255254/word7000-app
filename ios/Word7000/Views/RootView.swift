import SwiftUI
import Word7000Core

enum AppTab: Hashable {
    case today, words, me
}

/// What runs full screen on top of the tabs.
enum Activity: Identifiable, Hashable {
    case study
    case quiz
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
        .fullScreenCover(item: $activity, onDismiss: {
            guard let next = pendingActivity else { openRequestedPractice(); return }
            pendingActivity = nil
            activity = next
        }) { activity in
            switch activity {
            case .study:
                StudySessionView(startQuiz: { switchTo(.quiz) })
            case .quiz:
                QuizSessionView(studyMissed: { ids in
                    model.startStudySession(onlyIds: ids)
                    switchTo(.study)
                })
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
        .fullScreenCover(isPresented: $welcomeOpen, onDismiss: {
            if studyAfterWelcome {
                studyAfterWelcome = false
                PracticeLaunch.shared.requested = nil
                activity = .study
            } else { openRequestedPractice() }
        }) {
            WelcomeView { mode, target, practice in
                model.settings.onboardingComplete = true
                model.setStudyMode(mode)
                model.setDailyTarget(target)
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
        .onOpenURL { url in
            guard url.scheme == "word7000", url.host == "study", !welcomeOpen else { return }
            if activity == nil { activity = .study }
        }
        .sensoryFeedback(.selection, trigger: tab) { _, _ in model.settings.hapticsEnabled ?? true }
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
