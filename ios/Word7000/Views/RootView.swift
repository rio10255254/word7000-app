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
    @State private var tab: AppTab = .today
    @State private var activity: Activity?
    @State private var signInForScan = false

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                TodayView(start: { next in
                    if next == .exam {
                        plus.require(.examPractice) { activity = .exam }
                    } else {
                        activity = next
                    }
                })
            }
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
        .sheet(item: Binding(get: { plus.paywallReason }, set: { plus.paywallReason = $0 })) { reason in
            PaywallView(reason: reason)
        }
        .sheet(isPresented: Binding(get: { plus.trialRecapPending && plus.paywallReason == nil && activity == nil && !signInForScan },
                                    set: { if !$0 { plus.markTrialRecapShown() } })) {
            TrialRecapView(seePlans: {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    plus.paywallReason = .general
                }
            })
        }
        .sheet(isPresented: $signInForScan) {
            SignInSheet(reason: .scan, onSignedIn: {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    plus.require(.scan) { activity = .scan }
                }
            })
        }
        .fullScreenCover(item: $activity) { activity in
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
            case .exam:
                ExamView(studyMissed: { ids in
                    model.startStudySession(onlyIds: ids)
                    switchTo(.study)
                })
            case .scan:
                ScanView(onStudy: { switchTo(.study) })
            }
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

    /// Closes the current full-screen activity and opens another.
    private func switchTo(_ next: Activity) {
        activity = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            if next == .study, model.studySession == nil || model.studySession?.isComplete == true {
                model.startStudySession()
            }
            activity = next
        }
    }
}
