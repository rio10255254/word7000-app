import SwiftUI
import Word7000Core

/// How it is going, and the few settings there are.
struct MeView: View {
    @Environment(AppModel.self) private var model
    @Environment(PlusModel.self) private var plus
    @State private var historyOpen = false
    private let dailyTargetOptions = [10, 20, 30, 50]

    var body: some View {
        let stats = LearningEngine.stats(words: model.allWords, state: model.progress, today: model.today)

        List {
            AccountSection()
            Section {
                HStack(spacing: 0) {
                    StatTile(value: model.progress.streak, label: L.streak, color: Palette.review)
                    Divider().frame(height: 36)
                    StatTile(value: stats.mastered, label: L.mastered, color: Palette.known)
                    Divider().frame(height: 36)
                    StatTile(value: stats.review, label: L.reviewing, color: Palette.review)
                }
                .padding(.vertical, 6)
            } footer: {
                // One short line, so the history row stays on screen on small iPhones.
                if model.progress.streak > 0 {
                    Label(streakProtectionText, systemImage: "shield.lefthalf.filled")
                        .accessibilityIdentifier("me-streak-protection")
                }
            }

            Section {
                HistoryActivityChart(activity: model.activity(days: 7), chartHeight: 120, compact: true)
                Button { historyOpen = true } label: {
                    ActionRow(icon: "chart.bar.xaxis", tint: Palette.accent, title: L.t("完整學習紀錄", "Full history"))
                }
                .tint(.primary)
                .accessibilityIdentifier("me-history")
            } header: {
                Text(L.thisWeek)
            } footer: {
                if let accuracy = model.quizAccuracy {
                    Text(L.quizAccuracy(accuracy.percent, correct: accuracy.correct, total: accuracy.total))
                }
            }

            PlusSection(compact: true)

            Section {
                NavigationLink { SettingsView() } label: {
                    Label(L.settings, systemImage: "gearshape")
                }
                .accessibilityIdentifier("me-settings")
            }
        }
        .navigationTitle(L.tabMe)
        .navigationDestination(isPresented: $historyOpen) { HistoryView() }
    }

    private var streakProtectionText: String {
        guard let ready = model.streakProtectionReadyOn else {
            return L.t("連勝保護已就緒，漏學 1 天不會中斷", "Streak protection on: one missed day is covered")
        }
        let parts = ready.split(separator: "-").compactMap { Int($0) }
        let date = parts.count == 3 ? "\(parts[1])/\(parts[2])" : ready
        return L.t("連勝保護 \(date) 起可再使用", "Streak protection returns on \(date)")
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(AccountModel.self) private var account
    private let dailyTargetOptions = [10, 20, 30, 50]

    var body: some View {
        Form {
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
                if model.reminderEnabled && account.supportsCustomReminderTime {
                    DatePicker(L.t("每日學習時間", "Daily practice time"), selection: Binding(
                        get: {
                            let minute = model.settings.reminderMinute ?? 720
                            return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
                        },
                        set: { date in
                            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                            model.settings.reminderMinute = (parts.hour ?? 12) * 60 + (parts.minute ?? 0)
                        }
                    ), displayedComponents: .hourAndMinute)
                }
                Toggle(L.t("觸覺回饋", "Haptic feedback"), isOn: Binding(
                    get: { model.settings.hapticsEnabled ?? true },
                    set: { model.settings.hapticsEnabled = $0 }
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

            Section {
                NavigationLink { SpeechSettingsView() } label: {
                    Label(L.t("朗讀聲音", "Reading voice"), systemImage: "speaker.wave.2")
                }
                .accessibilityIdentifier("settings-speech")
            }

            AccountSection(includeDeletion: true)

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
        .navigationTitle(L.settings)
        .navigationBarTitleDisplayMode(.inline)
        .task { await account.checkReminderSupport() }
    }
}

extension Bundle {
    var versionLabel: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
