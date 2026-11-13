import SwiftUI
import Word7000Core

/// Where the Me tab can go by value: kept by the tab across a rebuild.
enum MeRoute: Hashable {
    case settings
}

/// How it is going, and the few settings there are.
struct MeView: View {
    @Environment(AppModel.self) private var model
    @Environment(PlusModel.self) private var plus
    @Environment(AccountModel.self) private var account
    @State private var historyOpen = false
    @State private var signInOpen = false
    @State private var reportOpen = false
    private let dailyTargetOptions = [10, 20, 30, 50]

    var body: some View {
        let stats = LearningEngine.stats(words: model.allWords, state: model.progress, today: model.today)

        List {
            Group {
                // Who you are and how far you have come, in one card.
                Section {
                    // Plain paper: on the ruled page the blue rules and red
                    // margin ran through the card's text and buttons.
                    ProfileCard(mastered: stats.mastered, reviewing: stats.review)
                        .listRowBackground(StyledRowBackground())
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

                // WordCat Next: a guest's progress lives only on this phone; say so plainly.
                if account.configured, !account.isPermanent, stats.mastered + stats.review > 0 {
                    Section {
                        GuestKeepCard(count: stats.mastered + stats.review) { signInOpen = true }
                            .accessibilityIdentifier("me-guest-warning")
                    }
                }

                // WordCat Next: the weeks as squares, darker on busier days.
                // Back to the week of the first practice, eight to twenty weeks.
                let weekCount = ActivityCalendar.weekCount(today: model.today, analytics: model.progress.analytics)
                Section {
                    ActivityCalendarView(weeks: ActivityCalendar.weeks(weekCount, today: model.today, analytics: model.progress.analytics),
                                         today: model.today)
                        .padding(.vertical, 4)
                    // The days in detail, and the week's counts, are one tap away.
                    Button { historyOpen = true } label: {
                        ActionRow(icon: "chart.bar.xaxis", tint: Palette.accent, title: L.t("完整學習紀錄", "Full history"))
                    }
                    .tint(.primary)
                    .accessibilityIdentifier("me-history")
                } header: {
                    Text(L.t("最近 \(weekCount) 週", "The last \(weekCount) weeks"))
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.t("今年學了 \(ActivityCalendar.activeDays(inYearOf: model.today, analytics: model.progress.analytics)) 天",
                                 "\(ActivityCalendar.activeDays(inYearOf: model.today, analytics: model.progress.analytics)) days this year"))
                            .accessibilityIdentifier("me-year-days")
                        if let accuracy = model.quizAccuracy {
                            Text(L.quizAccuracy(accuracy.percent, correct: accuracy.correct, total: accuracy.total))
                        }
                    }
                }

                LevelEstimateSection()

                AIInsightsSection()
    
                Section {
                    NavigationLink { CatMemoryView() } label: {
                        Label(L.t("傻貓記得的事", "What Silly Cat remembers"), systemImage: "pawprint")
                    }
                    .accessibilityIdentifier("me-cat-memory")
                    // By value, so Settings stays open when changing what is
                    // learnt rebuilds the app in the other language.
                    NavigationLink(value: MeRoute.settings) {
                        Label(L.settings, systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("me-settings")
                    Button { reportOpen = true } label: {
                        Label(L.t("回報問題", "Report a problem"), systemImage: "ladybug")
                    }
                    .tint(.primary)
                    .accessibilityIdentifier("me-report-row")
                }
            }
            .listRowBackground(StyledRowBackground())
        }
        .warmList()
        .navigationTitle(L.tabMe)
        // Reporting a problem is meant to be easy to find: up top, every visit.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // Words beside the icon (a toolbar would show the icon alone).
                Button { reportOpen = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "ladybug.fill")
                        Text(L.t("回報問題", "Report a problem"))
                    }
                    .font(.subheadline.weight(.semibold))
                    .fixedSize()
                }
                .accessibilityIdentifier("me-report")
            }
        }
        .sheet(isPresented: $reportOpen) { ReportProblemView() }
        .navigationDestination(isPresented: $historyOpen) { HistoryView() }
        .navigationDestination(for: MeRoute.self) { route in
            switch route {
            case .settings: SettingsView()
            }
        }
        .sheet(isPresented: $signInOpen) { SignInSheet(reason: .general) }
    }

    private var streakProtectionText: String {
        guard let ready = model.streakProtectionReadyOn else {
            return L.t("貓罐頭在你這：漏學 1 天也不會斷。", "You have a Cat Can: miss a day and your streak is safe.")
        }
        let parts = ready.split(separator: "-").compactMap { Int($0) }
        let date = parts.count == 3 ? "\(parts[1])/\(parts[2])" : ready
        return L.t("貓罐頭 \(date) 回來", "Your Cat Can is back on \(date)")
    }
}

/// The cat's estimate of the learner's level, from which words they knew on
/// sight, and where it is taking their new words from. The same estimate
/// that picks new words for study (`LearningEngine.estimateAbility`).
struct LevelEstimateSection: View {
    @Environment(AppModel.self) private var model
    private static let wordsNeeded = CatLevel.wordsNeeded
    private static let topLevel = CatLevel.top

    var body: some View {
        let estimate = LearningEngine.abilityEstimate(words: model.vocabularyWords, state: model.progress,
                                                      startLevel: model.placementStart)
        Section {
            // The level test is enough to go on, before many words are met.
            if estimate.seen < Self.wordsNeeded, model.placementStart == nil {
                CatSays(mood: .thinking, size: 28) {
                    Text(L.t("再多學幾個字，我就看得出你的程度。",
                             "Learn a few more words and I'll tell you your level."))
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
            } else {
                let favoured = LearningEngine.favouredLevels(ability: estimate.ability, top: Self.topLevel)
                VStack(alignment: .leading, spacing: 12) {
                    CatSays(mood: .smug, size: 28) {
                        Text(line(ability: estimate.ability, favoured: favoured))
                            .font(.subheadline)
                    }
                    LevelTrack(ability: estimate.ability, favoured: favoured, top: Self.topLevel)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text(L.t("\(Cat.name)估你的程度", "Your level, by \(Cat.name)"))
        }
        .accessibilityIdentifier("me-level-estimate")
    }

    private func levelName(_ ability: Int) -> String { CatLevel.name(ability) }

    private func line(ability: Int, favoured: ClosedRange<Int>) -> String {
        let band = L.levelRange(favoured.lowerBound, favoured.upperBound)
        if ability / 2 >= Self.topLevel {
            return L.t("你在\(levelName(ability))以上了……算你厲害。",
                       "\(levelName(ability)) or beyond… fine, I'm impressed.")
        }
        return L.t("你大概在\(levelName(ability))。新字多從\(band)挑，偶爾丟難的。",
                   "You're around \(levelName(ability)). New words mostly from \(band), plus the odd hard one.")
    }
}

/// Core 1 to 14 as a row of segments: the levels at or below the learner
/// filled, the ones new words mostly come from marked, the rest empty.
private struct LevelTrack: View {
    var ability: Int
    var favoured: ClosedRange<Int>
    var top: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                ForEach(1...top, id: \.self) { level in
                    Capsule()
                        .fill(color(for: level))
                        .frame(height: 8)
                }
            }
            HStack {
                Text(L.level(1))
                Spacer()
                Text(L.level(top))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.t("程度約\(L.level(max(1, ability / 2)))，新字多來自\(L.levelRange(favoured.lowerBound, favoured.upperBound))",
                                "About \(L.level(max(1, ability / 2))); new words mostly from \(L.levelRange(favoured.lowerBound, favoured.upperBound))"))
    }

    private func color(for level: Int) -> Color {
        if favoured.contains(level) { return Palette.review }
        if 2 * level <= ability { return Palette.accent }
        return Palette.fill
    }
}

/// Grouped the way the iPhone's own Settings app is: what you study, when
/// you are reminded, AI and voices, how the app looks and feels, the account,
/// and the fine print. Each row shows its current value, so the page reads at
/// a glance without opening anything.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(AccountModel.self) private var account
    @Environment(PlusModel.self) private var plus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var manageOpen = false
    @State private var timeOpen = false
    @State private var reportOpen = false
    private let dailyTargetOptions = [10, 20, 30, 50]

    /// "第 3 章 · 每天 20 個", or the goal alone outside the built-in words.
    private var planSummary: String {
        let goal = L.t("每天 \(model.progress.dailyTarget) 個", "\(model.progress.dailyTarget) a day")
        guard let chapter = model.placementStart ?? model.readingChapter.map({ $0 + 1 }) else { return goal }
        return L.t("第 \(chapter) 章 · ", "Ch. \(chapter) · ") + goal
    }

    var body: some View {
        Form {
            Group {
                Section {
                    // WordCat Next: the plan from the first launch, to read and change.
                    NavigationLink {
                        LearningPlanView()
                    } label: {
                        SettingsLabel(L.t("我的學習計畫", "My learning plan"), icon: "map.fill", tint: Palette.accent,
                                      value: planSummary)
                    }
                    .accessibilityIdentifier("settings-plan")
                    ChoiceRow(title: L.studyModeTitle, icon: "character.book.closed.fill", tint: Palette.accent,
                              options: [ChoiceOption(value: StudyMode.english, title: "學英文", detail: "中文介面", icon: "a.book.closed"),
                                        ChoiceOption(value: StudyMode.chinese, title: "Learn Chinese", detail: "English", icon: "character")],
                              selection: model.studyMode, identifier: "settings-study-mode") { mode in
                        // The app is rebuilt in the other language: a soft cross-fade, Settings stays open.
                        withAnimation(reduceMotion ? nil : Motion.reveal) { model.setStudyMode(mode) }
                    }
                    ChoiceRow(title: L.dailyTargetTitle, icon: "target", tint: Palette.accent,
                              options: dailyTargetOptions.map { ChoiceOption(value: $0, title: L.t("\($0) 個", "\($0)")) },
                              selection: model.progress.dailyTarget, identifier: "settings-daily-target") { model.setDailyTarget($0) }
                    Toggle(isOn: Binding(
                        get: { model.settings.studyAutoReveal ?? false },
                        set: { model.settings.studyAutoReveal = $0 }
                    )) {
                        SettingsLabel(L.autoReveal, icon: (model.settings.studyAutoReveal ?? false) ? "eye.fill" : "eye.slash.fill", tint: Palette.chinese)
                    }
                    .accessibilityIdentifier("settings-auto-reveal")
                    // WordCat Next: the speaking card on the home page.
                    Toggle(isOn: Binding(
                        get: { model.homeShowsSpeaking },
                        set: { model.settings.homeShowsSpeaking = $0 }
                    )) {
                        SettingsLabel(L.t("首頁顯示口說", "Speaking on Today"), icon: "mic.fill", tint: TodayView.speakingTint)
                    }
                    .accessibilityIdentifier("settings-home-speaking")
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
                        SettingsLabel(L.reminder, icon: model.reminderEnabled ? "bell.badge.fill" : "bell.slash.fill", tint: Palette.miss)
                    }
                    .accessibilityIdentifier("settings-reminder")
                    PushStatusRow()
                    if model.reminderEnabled && account.supportsCustomReminderTime {
                        Button { timeOpen = true } label: {
                            HStack {
                                SettingsLabel(L.t("提醒時間", "Reminder time"), icon: "clock.fill", tint: Palette.miss)
                                Spacer(minLength: 8)
                                ValueChip(text: ReminderTimeSheet.label(model.settings.reminderMinute ?? 720))
                            }
                        }
                        .accessibilityValue(ReminderTimeSheet.label(model.settings.reminderMinute ?? 720))
                        .accessibilityIdentifier("settings-reminder-time")
                    }
                } header: {
                    Text(L.t("提醒", "Reminders"))
                } footer: {
                    Text(L.reminderText)
                }
    
                Section {
                    NavigationLink { IntelligenceSettingsView() } label: {
                        SettingsLabel(L.t("AI 與錄音", "AI and recording"), icon: "sparkles", tint: Palette.review,
                                      value: CloudAssistant.shared.statusText)
                    }
                    .accessibilityIdentifier("settings-intelligence")
                    NavigationLink { SpeechSettingsView() } label: {
                        SettingsLabel(L.t("朗讀聲音", "Reading voice"), icon: "speaker.wave.2.fill", tint: Palette.accent,
                                      value: speedLabel)
                    }
                    .accessibilityIdentifier("settings-speech")
                } header: {
                    Text(L.t("AI 與聲音", "AI and voice"))
                }
    
                Section {
                    ChoiceRow(title: L.appearance, icon: appearanceIcon, tint: Palette.chinese,
                              options: [ChoiceOption(value: AppearancePreference.system, title: L.themeSystem, icon: "circle.lefthalf.filled"),
                                        ChoiceOption(value: AppearancePreference.light, title: L.themeLight, icon: "sun.max.fill"),
                                        ChoiceOption(value: AppearancePreference.dark, title: L.themeDark, icon: "moon.fill")],
                              selection: model.settings.theme, identifier: "settings-theme") { model.settings.theme = $0 }
                    NavigationLink { StyleSettingsView() } label: {
                        SettingsLabel(L.t("App 風格", "App style"), icon: "paintpalette.fill", tint: Palette.review,
                                      value: (model.settings.appStyle ?? .standard).label)
                    }
                    .accessibilityIdentifier("settings-style")
                    Toggle(isOn: Binding(
                        get: { model.settings.hapticsEnabled ?? true },
                        set: { model.settings.hapticsEnabled = $0 }
                    )) {
                        SettingsLabel(L.t("觸覺回饋", "Haptic feedback"), icon: "hand.tap.fill", tint: Palette.known,
                                      trigger: model.settings.hapticsEnabled ?? true)
                    }
                    Toggle(isOn: Binding(
                        get: { model.soundEffectsOn },
                        set: { on in
                            model.settings.soundEffectsEnabled = on
                            if on { SoundBoard.play(.correct) }
                        }
                    )) {
                        SettingsLabel(L.t("音效", "Sound effects"), icon: "speaker.wave.2.fill", tint: Palette.known,
                                      trigger: model.soundEffectsOn)
                    }
                    .accessibilityHint(L.t("手機切到靜音時不會響。", "Silent when the phone is set to silent."))
                    .accessibilityIdentifier("settings-sounds")
                } header: {
                    Text(L.t("顯示與操作", "Display and feel"))
                }

                // The classic layout, for learners who would rather pick what
                // to practise: 2.0.2's Today, and the chapters as their own tab.
                Section {
                    ChoiceRow(title: L.t("版面", "Layout"), icon: "rectangle.3.group.fill", tint: Palette.accent,
                              options: [ChoiceOption(value: true, title: L.t("經典模式", "Classic"), detail: L.t("自己挑練習", "Pick your practice"), icon: "square.grid.2x2.fill"),
                                        ChoiceOption(value: false, title: L.t("懶人模式", "Easy mode"), detail: L.t("每天幫你排好", "Planned for you"), icon: "wand.and.stars")],
                              selection: model.classicLayout, identifier: "settings-layout") { classic in
                        withAnimation(reduceMotion ? nil : Motion.reveal) { model.setClassicLayout(classic) }
                    }
                    if model.classicLayout {
                        Toggle(isOn: Binding(
                            get: { !model.skipsWriting },
                            set: { model.setWritingOff(!$0) }
                        )) {
                            SettingsLabel(model.studyMode == .english ? L.t("拼字練習", "Spelling practice") : L.t("寫字練習", "Writing practice"),
                                          icon: "pencil.line", tint: Palette.accent)
                        }
                        .accessibilityIdentifier("settings-writing")
                    }
                } header: {
                    Text(L.t("版面", "Layout"))
                } footer: {
                    Text(model.classicLayout
                         ? L.t("經典模式：首頁是練習磚塊，想練什麼自己挑；「語言學習」分頁照章節一章一章走。關掉拼字練習，翻卡後就不會再拼字。",
                               "Classic: Today has the practice tiles to pick from, and Language learning goes through the chapters in order. With writing off, no writing follows the cards.")
                         : L.t("懶人模式：每天幫你排好一條路，翻卡、寫字、考考看、口說照著走。換模式不會影響進度。",
                               "Easy mode: each day is laid out for you, cards, writing, quiz and speaking in order. Switching keeps your progress."))
                }
    
                // Premium's subscription, for those paying: out of the
                // profile card, where a big button took the eye every day.
                if plus.subscribed {
                    Section {
                        Button { manageOpen = true } label: {
                            SettingsLabel(P.manage, icon: "sparkles", tint: Palette.review)
                        }
                        .accessibilityIdentifier("settings-manage-subscription")
                    } header: {
                        Text("Premium")
                    }
                }

                AccountSection(includeDeletion: true)
    
                Section {
                    Button { reportOpen = true } label: {
                        SettingsLabel(L.t("回報問題", "Report a problem"), icon: "ladybug.fill", tint: Palette.miss)
                    }
                    .accessibilityIdentifier("settings-report")
                    Link(destination: URL(string: "https://word7000-app.rio10255254.workers.dev/privacy.html")!) {
                        SettingsLabel(L.privacyPolicy, icon: "hand.raised.fill", tint: Palette.secondaryLabel, external: true)
                    }
                    Link(destination: URL(string: "https://word7000-app.rio10255254.workers.dev/support.html")!) {
                        SettingsLabel(L.supportPage, icon: "questionmark.circle.fill", tint: Palette.secondaryLabel, external: true)
                    }
                    HStack {
                        SettingsLabel(L.version, icon: "info.circle.fill", tint: Palette.secondaryLabel)
                        Spacer()
                        Text(Bundle.main.versionLabel).foregroundStyle(.secondary).monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                } header: {
                    Text(L.t("關於", "About"))
                }
            }
            .listRowBackground(StyledRowBackground())
        }
        .warmList()
        .navigationTitle(L.settings)
        .sheet(isPresented: $timeOpen) {
            ReminderTimeSheet(minute: Binding(
                get: { model.settings.reminderMinute ?? 720 },
                set: { model.settings.reminderMinute = $0 }
            ))
        }
        .modifier(PlusManageSheet(isPresented: $manageOpen, groupID: plus.subscriptionGroupID))
        .sheet(isPresented: $reportOpen) { ReportProblemView() }
        .navigationBarTitleDisplayMode(.inline)
        .task { await account.checkReminderSupport() }
        .animation(reduceMotion ? nil : Motion.reveal, value: model.reminderEnabled)
        // Turning haptics on answers with a tap, so the choice can be felt.
        .sensoryFeedback(.impact(weight: .medium), trigger: model.settings.hapticsEnabled ?? true) { _, new in new }
    }

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
                // Ivory by day; dark at night, where the tints are lighter
                // and white on them is hard to read.
                .foregroundStyle(Palette.surface)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: reduceMotion ? nil : (trigger ?? value.map { AnyHashable($0) }))
                .frame(width: 29, height: 29)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)
            // Color.primary, not .primary: inside a Button the hierarchical
            // style takes the button's tint, which turned rows like
            // "Announcement pushes" red.
            // One line: a long title shrinks a little rather than wrapping,
            // and the value gives way first.
            Text(title).foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)
            if value != nil || external { Spacer(minLength: 8) }
            if let value {
                Text(value).foregroundStyle(Color.secondary).lineLimit(1)
                    .minimumScaleFactor(0.85)
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
                            greeting: insightHeadline, tip: buddyTip, fidgets: true, speech: $spoken,
                            onTap: { chatOpen = true })
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
        .modifier(PlusManageSheet(isPresented: $manageOpen, groupID: plus.subscriptionGroupID))
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
                    .fixedSize()
                    .layoutPriority(1)
            }
            // The symbol on the first line, not centred beside two lines.
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: syncSymbol)
                    .contentTransition(.symbolEffect(.replace))
                Text(account.message)
                    .lineLimit(2)
                    .contentTransition(.opacity)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .animation(reduceMotion ? nil : Motion.reveal, value: syncSymbol)
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
        let total = model.bank.words.count
        var lines = [mastered == 0
            ? L.t("一個字都還沒會？好，從今天開始盯你。", "Not one word known yet? Fine. I'm watching from today.")
            : L.t("已會 \(mastered) 個。離 \(total) 還很遠，加油喔（棒讀）。", "\(mastered) known. Only \(max(0, total - mastered)) to go. Yay. (Flatly.)")]
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
            Text("PREMIUM")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(PlusStyle.gradient, in: Capsule())
                .accessibilityLabel(P.memberTitle)
        case .trial(let daysLeft):
            Text(L.t("試用剩 \(daysLeft) 天", "Trial · \(daysLeft)d"))
                .font(.caption2.weight(.bold))
                .foregroundStyle(Palette.review)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Palette.review.opacity(0.15), in: Capsule())
        case .expired:
            if plus.subscriptionAwaitsSignIn {
                Text(L.t("PREMIUM · 待登入", "PREMIUM · sign in"))
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(Palette.review)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Palette.review.opacity(0.15), in: Capsule())
                    .accessibilityIdentifier("me-premium-awaits-sign-in")
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        ButtonRow(spacing: 8) {
            if account.configured, !account.isPermanent {
                Button { signInOpen = true } label: {
                    Label(L.t("Apple 登入", "Sign in"), systemImage: "apple.logo")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .secondaryAction()
                .accessibilityIdentifier("me-sign-in")
            }
            // Subscribers manage it in Settings; a still-paying Apple ID
            // not signed in keeps the button, to cancel it.
            if !plus.subscribed { plusButton }
        }
        if plus.subscriptionAwaitsSignIn {
            Text(L.t("這個 Apple ID 還有 Premium 訂閱：用 Apple 登入就能使用。不想續訂，請按「管理訂閱」取消。",
                     "This Apple ID still has Premium: sign in with Apple to use it. To stop renewing, cancel it under Subscription."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        // The trial days are on the badge by the name and the scans left on
        // the scan card in Words, so no extra line of small print here.
    }

    @ViewBuilder
    private var plusButton: some View {
        // Someone still paying can always reach the subscription to cancel it.
        let paying = plus.subscribed || plus.subscriptionAwaitsSignIn
        let button = Button {
            if paying { manageOpen = true } else { plus.paywallReason = .general }
        } label: {
            // "Manage subscription" was cut short beside Sign in: here it is
            // "Subscription" (the Chinese 管理訂閱 fits).
            Label(paying ? L.t("管理訂閱", "Subscription") : plus.access == .expired ? P.unlockPlus : P.upgradePlus, systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        if paying {
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

/// The App Store's Manage subscription sheet, opened on Plus's own group so
/// it does not list the learner's other apps' subscriptions too.
private struct PlusManageSheet: ViewModifier {
    @Binding var isPresented: Bool
    var groupID: String?

    func body(content: Content) -> some View {
        if let groupID {
            content.manageSubscriptionsSheet(isPresented: $isPresented, subscriptionGroupID: groupID)
        } else {
            content.manageSubscriptionsSheet(isPresented: $isPresented)
        }
    }
}

/// WordCat Next: the last weeks as a grid of squares, one column a week
/// (Monday on top), darker the more was practised that day.
struct ActivityCalendarView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var weeks: [[Int?]]
    var today: String
    @State private var width: CGFloat = 300
    @State private var selected: Cell?

    /// A square, by its week (column) and its weekday from Monday (row).
    struct Cell: Equatable { var week: Int; var day: Int }

    private let gap: CGFloat = 3
    private let labelWidth: CGFloat = 16
    private let monthHeight: CGFloat = 13
    /// Each day is short and wide: the weeks fill the width, the seven
    /// rows stay flat.
    private let rowHeight: CGFloat = 12

    /// As GitHub lays it out, a week to a column, Monday on top, but the
    /// columns stretched across the card.
    private var side: CGFloat {
        let count = CGFloat(max(1, weeks.count))
        return min(44, max(6, (width - labelWidth - gap * (count + 1)) / count))
    }
    private var gridWidth: CGFloat { labelWidth + gap + CGFloat(weeks.count) * (side + gap) - gap }

    var body: some View {
        let active = weeks.joined().compactMap { $0 }.filter { $0 > 0 }.count
        VStack(alignment: .leading, spacing: 8) {
            grid
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L.t("最近 \(weeks.count) 週學了 \(active) 天", "\(active) days in the last \(weeks.count) weeks"))
                .accessibilityIdentifier("me-calendar")
                .overlay(alignment: .topLeading) { tooltip }
            legend
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { width = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, new in width = new }
            }
        }
        .sensoryFeedback(.selection, trigger: selected) { _, _ in Feel.enabled }
    }

    private var grid: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: gap) {
                Color.clear.frame(width: labelWidth, height: monthHeight)
                ForEach(weeks.indices, id: \.self) { week in
                    Text(monthLabel(week) ?? "")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Palette.secondaryLabel)
                        .fixedSize()
                        .frame(width: side, height: monthHeight, alignment: .leading)
                }
            }
            HStack(alignment: .top, spacing: gap) {
                VStack(spacing: gap) {
                    ForEach(0..<7, id: \.self) { day in
                        Text(day % 2 == 0 && day < 6 ? weekdayInitial(day) : "")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(Palette.tertiaryLabel)
                            .frame(width: labelWidth, height: rowHeight, alignment: .leading)
                    }
                }
                ForEach(Array(weeks.enumerated()), id: \.offset) { week, days in
                    VStack(spacing: gap) {
                        ForEach(Array(days.enumerated()), id: \.offset) { day, actions in
                            square(Cell(week: week, day: day), actions: actions)
                        }
                    }
                }
            }
        }
        .frame(width: gridWidth, alignment: .leading)
    }

    private func square(_ cell: Cell, actions: Int?) -> some View {
        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(color(actions))
            .frame(width: side, height: rowHeight)
            .overlay {
                if selected == cell {
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous).stroke(Palette.ink, lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle().inset(by: -gap / 2))
            .onTapGesture {
                guard actions != nil else { return }
                withAnimation(reduceMotion ? nil : Animation.snappy(duration: 0.2)) { selected = selected == cell ? nil : cell }
            }
    }

    /// The day tapped, in a bubble above its square (below it for the top rows).
    @ViewBuilder private var tooltip: some View {
        if let selected, weeks.indices.contains(selected.week), weeks[selected.week].indices.contains(selected.day),
           let actions = weeks[selected.week][selected.day] {
            let x = labelWidth + gap + CGFloat(selected.week) * (side + gap) + side / 2
            let top = monthHeight + 2 + CGFloat(selected.day) * (rowHeight + gap)
            let y = selected.day >= 3 ? top - 22 : top + rowHeight + 22
            VStack(spacing: 1) {
                Text(dayTitle(selected)).font(.caption2.weight(.bold))
                Text(actions > 0 ? L.t("練習 \(actions) 次", "\(actions) practised") : L.t("沒有練習", "No practice"))
                    .font(.caption2)
            }
            .foregroundStyle(Palette.surface)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Palette.ink, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .fixedSize()
            .position(x: min(max(x, 56), max(56, gridWidth - 56)), y: y)
            .onTapGesture { withAnimation(reduceMotion ? nil : Animation.snappy(duration: 0.2)) { self.selected = nil } }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("me-calendar-detail")
        }
    }

    private var legend: some View {
        HStack(spacing: 3) {
            Text(L.t("點一格看那天", "Tap a day"))
                .font(.caption2)
                .foregroundStyle(Palette.secondaryLabel)
            Spacer(minLength: 8)
            Text(L.t("少", "Less")).font(.caption2).foregroundStyle(Palette.secondaryLabel)
            ForEach([0, 1, 10, 25, 50], id: \.self) { actions in
                RoundedRectangle(cornerRadius: 2, style: .continuous).fill(color(actions)).frame(width: 9, height: 9)
            }
            Text(L.t("多", "More")).font(.caption2).foregroundStyle(Palette.secondaryLabel)
        }
        .accessibilityHidden(true)
    }

    // MARK: Dates

    private var firstMonday: Int? {
        guard let number = DayMath.dayNumber(today), let weekday = WeekStamps.weekdayIndex(today) else { return nil }
        return number - weekday - 7 * (weeks.count - 1)
    }

    private func date(_ week: Int, _ day: Int) -> (month: Int, day: Int)? {
        guard let firstMonday else { return nil }
        let parts = DayMath.string(fromDayNumber: firstMonday + 7 * week + day).split(separator: "-").compactMap { Int($0) }
        return parts.count == 3 ? (parts[1], parts[2]) : nil
    }

    private static let englishMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// The month over the first week that starts in it; over the first
    /// column too, unless a new month starts within two weeks.
    private func monthLabel(_ week: Int) -> String? {
        guard let month = date(week, 0)?.month else { return nil }
        let starts = week == 0
            ? !(1...2).contains { $0 < weeks.count && date($0, 0)?.month != month }
            : date(week - 1, 0)?.month != month
        guard starts, (1...12).contains(month) else { return nil }
        return L.t("\(month)月", Self.englishMonths[month - 1])
    }

    /// One letter beside the rows, so it fits the narrow column in English too.
    private func weekdayInitial(_ day: Int) -> String {
        L.t(["一", "二", "三", "四", "五", "六", "日"][day], ["M", "T", "W", "T", "F", "S", "S"][day])
    }

    private func weekdayName(_ day: Int) -> String {
        L.t(["一", "二", "三", "四", "五", "六", "日"][day], ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][day])
    }

    private func dayTitle(_ cell: Cell) -> String {
        guard let date = date(cell.week, cell.day) else { return "" }
        return L.t("\(date.month)月\(date.day)日（\(weekdayName(cell.day))）", "\(weekdayName(cell.day)), \(Self.englishMonths[date.month - 1]) \(date.day)")
    }

    private func color(_ actions: Int?) -> Color {
        guard let actions else { return .clear }
        switch ActivityCalendar.shade(actions) {
        case 0: return Palette.fill
        case 1: return Palette.known.opacity(0.35)
        case 2: return Palette.known.opacity(0.6)
        case 3: return Palette.known.opacity(0.85)
        default: return Palette.known
        }
    }
}
