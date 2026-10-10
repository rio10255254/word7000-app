import SwiftUI
import Word7000Core

/// How it is going, and the few settings there are.
struct MeView: View {
    @Environment(AppModel.self) private var model
    private let dailyTargetOptions = [10, 20, 30, 50]

    var body: some View {
        let stats = model.stats
        let week = model.lastSevenDays

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

            Section {
                WeekBars(days: week)
                    .frame(height: 120)
                    .padding(.vertical, 8)
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
    }
}

/// Words studied per day this week, today on the right.
struct WeekBars: View {
    var days: [(label: String, count: Int, isToday: Bool)]

    var body: some View {
        let maximum = max(1, days.map(\.count).max() ?? 1)
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 6) {
                    if day.count > 0 {
                        Text("\(day.count)").font(.caption2.weight(.semibold)).monospacedDigit().foregroundStyle(.secondary)
                    }
                    GeometryReader { proxy in
                        VStack {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(day.isToday ? Palette.accent : Palette.accent.opacity(0.35))
                                .frame(height: max(4, proxy.size.height * CGFloat(day.count) / CGFloat(maximum)))
                        }
                    }
                    Text(day.label).font(.caption2).foregroundStyle(day.isToday ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.label) \(day.count)")
            }
        }
    }
}

extension Bundle {
    var versionLabel: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
