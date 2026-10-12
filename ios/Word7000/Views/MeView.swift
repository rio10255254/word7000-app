import SwiftUI
import Word7000Core

/// How it is going, and the few settings there are.
struct MeView: View {
    @Environment(AppModel.self) private var model
    @Environment(PlusModel.self) private var plus
    @State private var historyOpen = false
    private let dailyTargetOptions = [10, 20, 30, 50]

    var body: some View {
        let stats = model.stats

        List {
            Section {
                HStack(spacing: 0) {
                    StatTile(value: model.progress.streak, label: L.streak, color: Palette.review)
                    Divider().frame(height: 36)
                    StatTile(value: stats.mastered, label: L.mastered, color: Palette.known)
                    Divider().frame(height: 36)
                    StatTile(value: stats.review, label: L.reviewing, color: Palette.accent)
                }
                .padding(.vertical, 6)
            }

            PlusSection()

            Section {
                HistoryActivityChart(activity: model.activity(days: 7), chartHeight: 120, compact: true)
                Button {
                    historyOpen = true
                } label: {
                    ActionRow(icon: "chart.bar.xaxis", tint: Palette.accent, title: L.t("完整學習紀錄", "Full history"))
                }
                .tint(.primary)
                .accessibilityIdentifier("me-history")
            } header: {
                Text(L.thisWeek)
            } footer: {
                if let accuracy = model.quizAccuracy {
                    Text(L.quizAccuracy(accuracy))
                }
            }

            Section {
                Picker(L.studyModeTitle, selection: Binding(
                    get: { model.studyMode },
                    set: { model.setStudyMode($0) }
                )) {
                    ForEach(StudyMode.allCases) { mode in
                        Text(L.studyModeLabel(mode)).tag(mode)
                    }
                }
                Picker(L.dailyTargetTitle, selection: Binding(
                    get: { model.progress.dailyTarget },
                    set: { model.setDailyTarget($0) }
                )) {
                    ForEach(dailyTargetOptions, id: \.self) { value in
                        Text(L.wordsPerDay(value)).tag(value)
                    }
                }
                Toggle(L.reminder, isOn: Binding(
                    get: { model.reminderEnabled },
                    set: { model.setReminderEnabled($0) }
                ))
                Picker(L.appearance, selection: Binding(
                    get: { model.settings.theme },
                    set: { model.settings.theme = $0 }
                )) {
                    ForEach(AppearancePreference.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
            } header: {
                Text(L.settings)
            } footer: {
                Text("\(L.dailyTargetText) \(L.reminderText)")
            }

            AccountSection()

            Section {
                Link(destination: URL(string: "https://word7000-app.rio10255254.workers.dev/privacy.html")!) {
                    Label(L.privacyPolicy, systemImage: "hand.raised")
                }
                Link(destination: URL(string: "https://word7000-app.rio10255254.workers.dev/support.html")!) {
                    Label(L.supportPage, systemImage: "questionmark.circle")
                }
                LabeledContent(L.version, value: Bundle.main.versionLabel)
            }
        }
        .navigationTitle(L.tabMe)
        .navigationDestination(isPresented: $historyOpen) { HistoryView() }
    }
}

extension Bundle {
    var versionLabel: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
