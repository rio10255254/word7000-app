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
                let summary = LearningWeekSummary(days: model.activity(days: 7))
                if summary.activeDays > 0 {
                    Text(L.t("近 7 天練習 \(summary.activeDays) 天，完成 \(summary.words) 次單字練習、\(summary.speaking) 次口說。",
                             "In the last 7 days: \(summary.activeDays) active days, \(summary.words) word practices and \(summary.speaking) speaking practices."))
                        .font(.subheadline).foregroundStyle(.secondary)
                        .accessibilityIdentifier("me-week-summary")
                }
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

            AIInsightsSection()

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

/// Grouped the way the iPhone's own Settings app is: what you study, when
/// you are reminded, AI and voices, how the app looks and feels, the account,
/// and the fine print. Each row shows its current value, so the page reads at
/// a glance without opening anything.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(AccountModel.self) private var account
    private let dailyTargetOptions = [10, 20, 30, 50]

    var body: some View {
        Form {
            Section {
                Picker(selection: Binding(
                    get: { model.studyMode },
                    set: { model.setStudyMode($0) }
                )) {
                    ForEach(StudyMode.allCases) { mode in
                        Text(L.studyModeLabel(mode)).tag(mode)
                    }
                } label: {
                    SettingsLabel(L.studyModeTitle, icon: "character.book.closed.fill", tint: Palette.accent)
                }
                Picker(selection: Binding(
                    get: { model.progress.dailyTarget },
                    set: { model.setDailyTarget($0) }
                )) {
                    ForEach(dailyTargetOptions, id: \.self) { value in
                        Text(L.wordsPerDay(value)).tag(value)
                    }
                } label: {
                    SettingsLabel(L.dailyTargetTitle, icon: "target", tint: .orange)
                }
                Toggle(isOn: Binding(
                    get: { model.settings.studyAutoReveal ?? false },
                    set: { model.settings.studyAutoReveal = $0 }
                )) {
                    SettingsLabel(L.autoReveal, icon: "eye.fill", tint: .teal)
                }
                .accessibilityIdentifier("settings-auto-reveal")
                if model.studyMode == .chinese {
                    Toggle(isOn: Binding(
                        get: { model.settings.showPinyin ?? true },
                        set: { model.settings.showPinyin = $0 }
                    )) {
                        SettingsLabel("Show pinyin", icon: "character.phonetic", tint: .indigo)
                    }
                    .accessibilityIdentifier("settings-pinyin")
                }
            } header: {
                Text(L.t("學習", "Learning"))
            } footer: {
                Text(L.dailyTargetText)
            }

            Section {
                Toggle(isOn: Binding(
                    get: { model.reminderEnabled },
                    set: { model.setReminderEnabled($0) }
                )) {
                    SettingsLabel(L.reminder, icon: "bell.badge.fill", tint: .red)
                }
                .accessibilityIdentifier("settings-reminder")
                if model.reminderEnabled && account.supportsCustomReminderTime {
                    DatePicker(selection: Binding(
                        get: {
                            let minute = model.settings.reminderMinute ?? 720
                            return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
                        },
                        set: { date in
                            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                            model.settings.reminderMinute = (parts.hour ?? 12) * 60 + (parts.minute ?? 0)
                        }
                    ), displayedComponents: .hourAndMinute) {
                        SettingsLabel(L.t("每日學習時間", "Daily practice time"), icon: "clock.fill", tint: .red)
                    }
                }
            } header: {
                Text(L.t("提醒", "Reminders"))
            } footer: {
                Text(L.reminderText)
            }

            Section {
                NavigationLink { IntelligenceSettingsView() } label: {
                    SettingsLabel(L.t("AI 與錄音", "AI and recording"), icon: "sparkles", tint: .purple,
                                  value: CloudAssistant.shared.statusText)
                }
                .accessibilityIdentifier("settings-intelligence")
                NavigationLink { SpeechSettingsView() } label: {
                    SettingsLabel(L.t("朗讀聲音", "Reading voice"), icon: "speaker.wave.2.fill", tint: .pink,
                                  value: speedLabel)
                }
                .accessibilityIdentifier("settings-speech")
            } header: {
                Text(L.t("AI 與聲音", "AI and voice"))
            }

            Section {
                Picker(selection: Binding(
                    get: { model.settings.theme },
                    set: { model.settings.theme = $0 }
                )) {
                    ForEach(AppearancePreference.allCases) { option in
                        Text(option.label).tag(option)
                    }
                } label: {
                    SettingsLabel(L.appearance, icon: "circle.lefthalf.filled", tint: .indigo)
                }
                Toggle(isOn: Binding(
                    get: { model.settings.hapticsEnabled ?? true },
                    set: { model.settings.hapticsEnabled = $0 }
                )) {
                    SettingsLabel(L.t("觸覺回饋", "Haptic feedback"), icon: "hand.tap.fill", tint: .green)
                }
            } header: {
                Text(L.t("顯示與操作", "Display and feel"))
            }

            AccountSection(includeDeletion: true)

            Section {
                Link(destination: URL(string: "https://word7000-app.rio10255254.workers.dev/privacy.html")!) {
                    SettingsLabel(L.privacyPolicy, icon: "hand.raised.fill", tint: .blue, external: true)
                }
                Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                    SettingsLabel(L.t("使用條款", "Terms of Use"), icon: "doc.text.fill", tint: .gray, external: true)
                }
                Link(destination: URL(string: "https://word7000-app.rio10255254.workers.dev/support.html")!) {
                    SettingsLabel(L.supportPage, icon: "questionmark.circle.fill", tint: .gray, external: true)
                }
                Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                    SettingsLabel(L.t("管理訂閱", "Manage subscription"), icon: "creditcard.fill", tint: .orange, external: true)
                }
                .accessibilityIdentifier("settings-manage-subscription")
                HStack {
                    SettingsLabel(L.version, icon: "info.circle.fill", tint: .gray)
                    Spacer()
                    Text(Bundle.main.versionLabel).foregroundStyle(.secondary).monospacedDigit()
                }
                .accessibilityElement(children: .combine)
            } header: {
                Text(L.t("關於", "About"))
            }
        }
        .navigationTitle(L.settings)
        .navigationBarTitleDisplayMode(.inline)
        .task { await account.checkReminderSupport() }
    }

    private var speedLabel: String {
        switch (model.settings.speech ?? SpeechPreferences()).speed {
        case .slow: L.t("慢速", "Slow")
        case .natural: L.t("自然", "Natural")
        case .brisk: L.t("稍快", "Brisk")
        }
    }
}

/// A settings row title with a small coloured icon, like the iPhone's Settings app.
struct SettingsLabel: View {
    let title: String
    let icon: String
    let tint: Color
    var value: String? = nil
    var external = false

    init(_ title: String, icon: String, tint: Color, value: String? = nil, external: Bool = false) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.value = value
        self.external = external
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 29, height: 29)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)
            Text(title).foregroundStyle(.primary)
            if value != nil || external { Spacer(minLength: 8) }
            if let value {
                Text(value).foregroundStyle(.secondary).lineLimit(1)
            }
            if external {
                Image(systemName: "arrow.up.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
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
