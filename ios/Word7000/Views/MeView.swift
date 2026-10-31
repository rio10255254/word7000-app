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
            Group {
                // Who you are and how far you have come, in one card.
                Section {
                    ProfileCard(mastered: stats.mastered, reviewing: stats.review)
                } footer: {
                    if model.progress.streak > 0 {
                        Label {
                            Text(streakProtectionText)
                        } icon: {
                            ShieldIcon(ready: model.streakProtectionReadyOn == nil)
                        }
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
    
                Section {
                    NavigationLink { SettingsView() } label: {
                        Label(L.settings, systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("me-settings")
                }
            }
            .listRowBackground(Palette.surface)
        }
        .warmList()
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let dailyTargetOptions = [10, 20, 30, 50]

    var body: some View {
        Form {
            Group {
                Section {
                    Picker(selection: Binding(
                        get: { model.studyMode },
                        set: { model.setStudyMode($0) }
                    )) {
                        ForEach(StudyMode.allCases) { mode in
                            Text(L.studyModeLabel(mode)).tag(mode)
                        }
                    } label: {
                        SettingsLabel(L.studyModeTitle, icon: "character.book.closed.fill", tint: Palette.accent,
                                      trigger: model.studyMode)
                    }
                    Picker(selection: Binding(
                        get: { model.progress.dailyTarget },
                        set: { model.setDailyTarget($0) }
                    )) {
                        ForEach(dailyTargetOptions, id: \.self) { value in
                            Text(L.wordsPerDay(value)).tag(value)
                        }
                    } label: {
                        SettingsLabel(L.dailyTargetTitle, icon: "target", tint: .orange, trigger: model.progress.dailyTarget)
                    }
                    Toggle(isOn: Binding(
                        get: { model.settings.studyAutoReveal ?? false },
                        set: { model.settings.studyAutoReveal = $0 }
                    )) {
                        SettingsLabel(L.autoReveal, icon: (model.settings.studyAutoReveal ?? false) ? "eye.fill" : "eye.slash.fill", tint: .teal)
                    }
                    .accessibilityIdentifier("settings-auto-reveal")
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
                        SettingsLabel(L.reminder, icon: model.reminderEnabled ? "bell.badge.fill" : "bell.slash.fill", tint: .red)
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
                        SettingsLabel(L.appearance, icon: appearanceIcon, tint: .indigo)
                    }
                    NavigationLink { StyleSettingsView() } label: {
                        SettingsLabel(L.t("App 風格", "App style"), icon: "paintpalette.fill", tint: .purple,
                                      value: (model.settings.appStyle ?? .leather).label)
                    }
                    .accessibilityIdentifier("settings-style")
                    Toggle(isOn: Binding(
                        get: { model.settings.hapticsEnabled ?? true },
                        set: { model.settings.hapticsEnabled = $0 }
                    )) {
                        SettingsLabel(L.t("觸覺回饋", "Haptic feedback"), icon: "hand.tap.fill", tint: .green,
                                      trigger: model.settings.hapticsEnabled ?? true)
                    }
                } header: {
                    Text(L.t("顯示與操作", "Display and feel"))
                }
    
                AccountSection(includeDeletion: true)
    
                Section {
                    Link(destination: URL(string: "https://word7000-app.rio10255254.workers.dev/privacy.html")!) {
                        SettingsLabel(L.privacyPolicy, icon: "hand.raised.fill", tint: .blue, external: true)
                    }
                    Link(destination: URL(string: "https://word7000-app.rio10255254.workers.dev/support.html")!) {
                        SettingsLabel(L.supportPage, icon: "questionmark.circle.fill", tint: .gray, external: true)
                    }
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
            .listRowBackground(Palette.surface)
        }
        .warmList()
        .navigationTitle(L.settings)
        .navigationBarTitleDisplayMode(.inline)
        .task { await account.checkReminderSupport() }
        .animation(reduceMotion ? nil : Motion.reveal, value: model.reminderEnabled)
        .sensoryFeedback(.selection, trigger: model.studyMode) { _, _ in haptics }
        .sensoryFeedback(.selection, trigger: model.progress.dailyTarget) { _, _ in haptics }
        .sensoryFeedback(.selection, trigger: model.settings.theme) { _, _ in haptics }
        // Turning haptics on answers with a tap, so the choice can be felt.
        .sensoryFeedback(.impact(weight: .medium), trigger: model.settings.hapticsEnabled ?? true) { _, new in new }
    }

    private var haptics: Bool { model.settings.hapticsEnabled ?? true }

    private var appearanceIcon: String {
        switch model.settings.theme {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
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
/// The icon morphs when it changes and bounces when the row's value does.
struct SettingsLabel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let icon: String
    let tint: Color
    var value: String? = nil
    var external = false
    /// What the row controls; the icon bounces each time it changes.
    var trigger: AnyHashable? = nil

    init(_ title: String, icon: String, tint: Color, value: String? = nil, external: Bool = false, trigger: AnyHashable? = nil) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.value = value
        self.external = external
        self.trigger = trigger
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: reduceMotion ? nil : (trigger ?? value.map { AnyHashable($0) }))
                .frame(width: 29, height: 29)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)
            Text(title).foregroundStyle(.primary)
            if value != nil || external { Spacer(minLength: 8) }
            if let value {
                Text(value).foregroundStyle(.secondary).lineLimit(1)
                    .contentTransition(.opacity)
            }
            if external {
                Image(systemName: "arrow.up.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// Who you are and how far you have come, in one card: the companion beside
/// your account and Plus membership, your level, three headline numbers, and
/// the one or two things to do next (signing in, Plus). Signing out and
/// deleting the account stay in Settings.
private struct ProfileCard: View {
    @Environment(AppModel.self) private var model
    @Environment(AccountModel.self) private var account
    @Environment(PlusModel.self) private var plus
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var mastered: Int
    var reviewing: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var signInOpen = false
    @State private var manageOpen = false
    /// What the companion is saying: shown in place of the name, never over it.
    @State private var spoken: String?
    /// Today's AI insight headline, once worked out; the companion says it.
    @State private var insightHeadline: String?
    @State private var chatOpen = false
    @State private var focusPractice: [String]?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                MascotBuddy(mood: model.progress.studiedToday > 0 ? .happy : .smug, size: 56, lines: buddyLines,
                            greeting: insightHeadline, tip: buddyTip, fidgets: true, speech: $spoken)
                    .accessibilityIdentifier("me-mascot")
                ZStack(alignment: .leading) {
                    identity
                        .opacity(spoken == nil ? 1 : 0)
                        .accessibilityHidden(spoken != nil)
                    if let spoken {
                        let actionable = spoken == buddyTip?.text
                        MascotBubble(text: spoken, pointing: .leading, actionable: actionable)
                            .padding(.leading, 6)
                            .transition(.scale(scale: 0.6, anchor: .leading).combined(with: .opacity))
                            .onTapGesture { if actionable { buddyTip?.action() } }
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(reduceMotion ? nil : Motion.pop, value: spoken)
            }
            LevelProgress(mastered: mastered)
            HStack(spacing: 0) {
                StatTile(value: model.progress.streak, label: L.streak, color: Palette.review)
                Divider().frame(height: 32)
                StatTile(value: mastered, label: L.mastered, color: Palette.known)
                Divider().frame(height: 32)
                StatTile(value: reviewing, label: L.reviewing, color: Palette.review)
            }
            actions
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $signInOpen) { SignInSheet() }
        .manageSubscriptionsSheet(isPresented: $manageOpen)
        .sheet(isPresented: $chatOpen, onDismiss: {
            insightHeadline = InsightsStore.today(mode: model.studyMode)?.headline
            guard let ids = focusPractice else { return }
            focusPractice = nil
            model.startStudySession(onlyIds: ids)
            PracticeLaunch.shared.requested = .study
        }) {
            MascotChatSheet(practise: { ids in
                focusPractice = ids
                chatOpen = false
            })
        }
        .onAppear { insightHeadline = InsightsStore.today(mode: model.studyMode)?.headline }
    }

    /// Name, membership and sync state.
    private var identity: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(name)
                    .font(.display(.title3, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                membershipBadge
            }
            Label(account.message, systemImage: syncSymbol)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .contentTransition(.opacity)
        }
    }

    /// Its AI note, as on Today: the day's insight headline (tap for the chat),
    /// or an offer to work it out. Nothing when online AI is off.
    private var buddyTip: MascotTip? {
        if let insightHeadline {
            return MascotTip(text: insightHeadline) { chatOpen = true }
        }
        guard CloudAssistant.shared.offered else { return nil }
        return MascotTip(text: L.t("要我看看你最近到底有多混嗎？", "Want to know how much you've been slacking?")) { chatOpen = true }
    }

    /// What the companion says when tapped here: how far you have come.
    private var buddyLines: [String] {
        let streak = model.progress.streak
        var lines = [L.t("熟記 \(mastered) 個。離 7000 還很遠，加油喔（棒讀）。", "\(mastered) mastered. Only \(max(0, 7000 - mastered)) to go. Yay. (Flatly.)")]
        if streak > 0 { lines.append(L.t("連續 \(streak) 天。斷掉的話，我會記一輩子。", "\(streak)-day streak. Break it and I'll never let it go.")) }
        if reviewing > 0 { lines.append(L.t("\(reviewing) 個字等你複習，它們開始懷疑人生了。", "\(reviewing) words waiting for review. They're questioning their existence.")) }
        lines.append(L.t("我會一直盯著你的進度。一直。", "I'll be watching your progress. Always."))
        let smacks = MascotGrudge.today
        if smacks > 0 { lines.append(L.t("今天被你扁了 \(smacks) 下，我記住了。", "You've hit me \(smacks) times today. I remember.")) }
        return lines
    }

    private var name: String {
        if !account.configured { return L.t("我的學習", "My learning") }
        if account.isPermanent { return account.displayName ?? L.t("已登入", "Signed in") }
        return L.t("訪客", "Guest")
    }

    private var syncSymbol: String {
        if case .error = account.status { return "exclamationmark.icloud" }
        return account.cloudSyncEnabled ? "checkmark.icloud" : "iphone"
    }

    /// The Plus membership, worn next to the name.
    @ViewBuilder
    private var membershipBadge: some View {
        switch plus.access {
        case .subscribed:
            Text("PLUS")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(PlusStyle.gradient, in: Capsule())
                .accessibilityLabel(P.memberTitle)
        case .trial(let daysLeft):
            Text(L.t("試用 \(daysLeft) 天", "Trial · \(daysLeft)d"))
                .font(.caption2.weight(.bold))
                .foregroundStyle(Palette.review)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Palette.review.opacity(0.15), in: Capsule())
        case .expired:
            EmptyView()
        }
    }

    @ViewBuilder
    private var actions: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        layout {
            if account.configured, !account.isPermanent {
                Button { signInOpen = true } label: {
                    Label(L.t("登入保留紀錄", "Sign in"), systemImage: "person.crop.circle.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .secondaryAction()
                .accessibilityIdentifier("me-sign-in")
            }
            plusButton
        }
        if case let .trial(daysLeft) = plus.access {
            Text("\(P.trialDaysMeter(daysLeft)) · \(P.scansLeft(plus.policy.trialScansLeft))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var plusButton: some View {
        let button = Button {
            if plus.subscribed { manageOpen = true } else { plus.paywallReason = .general }
        } label: {
            Label(plus.subscribed ? P.manage : plus.access == .expired ? P.unlockPlus : P.upgradePlus, systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        if plus.subscribed {
            button.secondaryAction().accessibilityIdentifier("me-plus")
        } else {
            button.prominentAction(tint: Palette.review).accessibilityIdentifier("me-plus")
        }
    }
}

/// The learner's level, earned by the words they know well, and how far it is
/// to the next one.
private struct LevelProgress: View {
    var mastered: Int
    static let wordsPerLevel = 50

    var body: some View {
        let level = mastered / Self.wordsPerLevel + 1
        let into = mastered % Self.wordsPerLevel
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text("Lv.\(level)")
                    .font(.display(.subheadline, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(level)))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(LinearGradient(colors: [Palette.accent, Palette.review], startPoint: .leading, endPoint: .trailing), in: Capsule())
                Text(Self.title(for: level))
                    .font(.display(.headline, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Text(L.t("再 \(Self.wordsPerLevel - into) 字升級", "\(Self.wordsPerLevel - into) to go"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            SessionBar(fraction: Double(into) / Double(Self.wordsPerLevel), tint: Palette.accent)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("me-level")
    }

    static func title(for level: Int) -> String {
        switch level {
        case ..<3: L.t("單字新手", "Word rookie")
        case 3..<6: L.t("單字學徒", "Word apprentice")
        case 6..<11: L.t("單字達人", "Word achiever")
        case 11..<21: L.t("單字專家", "Word expert")
        case 21..<41: L.t("單字大師", "Word master")
        default: L.t("單字傳奇", "Word legend")
        }
    }
}

/// The streak shield in "我": it settles with a bounce when the page opens
/// while protection is ready, and stays quiet while it recharges.
private struct ShieldIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var ready: Bool
    @State private var bounced = false

    var body: some View {
        Image(systemName: "shield.lefthalf.filled")
            .foregroundStyle(ready ? Palette.known : Palette.secondaryLabel)
            .symbolEffect(.bounce, value: bounced)
            .task {
                guard ready, !reduceMotion, !bounced else { return }
                try? await Task.sleep(for: .milliseconds(600))
                bounced = true
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
