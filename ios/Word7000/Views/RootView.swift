import SwiftUI
import Word7000Core

enum AppTab: Hashable {
    case today, words, me
}

/// What runs full screen on top of the tabs.
enum Activity: Identifiable, Hashable {
    case study
    case quiz
    case scan

    var id: Self { self }
}

/// Three tabs, like Apple's own apps: today's practice, the words, and you.
/// Studying and quizzes take the whole screen so nothing competes with the card.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: AppTab = .today
    @State private var activity: Activity?

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                TodayView(start: { activity = $0 })
            }
            .tabItem { Label(L.tabToday, systemImage: "sun.max.fill") }
            .tag(AppTab.today)

            NavigationStack {
                WordsView(scan: { activity = .scan }, study: { activity = .study })
            }
            .tabItem { Label(L.tabWords, systemImage: "books.vertical.fill") }
            .tag(AppTab.words)

            NavigationStack {
                MeView()
            }
            .tabItem { Label(L.tabMe, systemImage: "person.crop.circle.fill") }
            .tag(AppTab.me)
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
            case .scan:
                ScanView(onStudy: { switchTo(.study) })
            }
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
