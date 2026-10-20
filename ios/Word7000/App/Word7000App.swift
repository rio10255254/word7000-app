import SwiftUI
import UIKit

@main
struct Word7000App: App {
    @State private var model: AppModel
    @State private var account: AccountModel
    @State private var liveActivities = LiveActivityManager()
    @State private var homeWidget = HomeWidgetBridge()
    @State private var plus: PlusModel
    @State private var refreshingReminders = false
    @State private var reminderRefreshPending = false
    @State private var registrationGeneration = 0
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let model = AppModel.launch()
        _model = State(initialValue: model)
        let plus = PlusModel()
        let account = AccountModel(app: model)
        account.plus = plus
        _account = State(initialValue: account)
        _plus = State(initialValue: plus)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(account)
                .environment(plus)
                .task { await plus.start() }
                .task { await Speaker.shared.refreshVoices() }
                .onChange(of: plus.subscribed) { _, _ in Task { await account.flush() } }
                .preferredColorScheme(model.settings.theme.colorScheme)
                .tint(Palette.accent)
                .task {
                    await account.bootstrap()
                    await account.checkReminderSupport()
                    await refreshReminders()
                }
                .task {
                    await liveActivities.observePushToStartTokens { _ in
                        Task { await refreshReminders() }
                    }
                }
                .onChange(of: model.progress.lastStudyDate) { _, _ in Task { await refreshReminders() } }
                .onChange(of: model.progress.studiedToday) { _, _ in Task { await refreshReminders() } }
                .onChange(of: model.reminderEnabled) { _, _ in Task { await refreshReminders() } }
                .onChange(of: model.settings.reminderMinute) { _, _ in Task { await refreshReminders() } }
                .onChange(of: account.supportsCustomReminderTime) { _, _ in Task { await refreshReminders() } }
                .onChange(of: model.studyMode) { _, _ in Task { await refreshReminders() } }
                .onChange(of: model.progress.dailyTarget) { _, _ in Task { await refreshReminders() } }
                .onChange(of: model.progress.streak) { _, _ in Task { await refreshReminders() } }
                .onChange(of: model.progress.streakFreezeDate) { _, _ in Task { await refreshReminders() } }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    model.refreshToday()
                    account.heartbeat()
                    Task { await refreshReminders() }
                }
                .onChange(of: account.session?.user.id) { _, _ in
                    liveActivities.forgetRegistration()
                    Task {
                        await liveActivities.endAll()
                        await account.checkReminderSupport()
                        await refreshReminders()
                    }
                }
                .task {
                    // Counts the learner as active while the app is open.
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(300))
                        guard !Task.isCancelled else { break }
                        if scenePhase == .active { model.refreshToday(); account.heartbeat(); await refreshReminders() }
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                model.refreshToday()
                Task { await Speaker.shared.refreshVoices() }
                plus.refreshAccessState()
                account.heartbeat()
                Task {
                    await plus.refreshEntitlements()
                    await account.flush()
                    await refreshReminders()
                }
            case .background:
                plus.suspendTimeUpdates()
                model.saveNow()
                account.flushBeforeBackground()
                uploadRegistrationBeforeBackground()
            case .inactive:
                model.saveNow()
            @unknown default:
                break
            }
        }
    }

    /// Keeps the local streak card and the server's view of this iPhone in
    /// step with today's progress.
    private func refreshReminders() async {
        if refreshingReminders { reminderRefreshPending = true; return }
        refreshingReminders = true
        defer { refreshingReminders = false }
        repeat {
            reminderRefreshPending = false
            await syncReminders()
        } while reminderRefreshPending && !Task.isCancelled
    }

    private func syncReminders() async {
        homeWidget.update(model: model)
        let plan = model.streakPlan
        if model.reminderEnabled {
            await liveActivities.sync(plan: plan, progress: model.progress, chineseInterface: model.studyMode == .english)
        } else {
            await liveActivities.endAll()
        }
        scheduleRegistrationUpload()
    }

    /// The lock screen card is updated at once by `syncReminders`; the server's copy waits
    /// for a pause, so a study session sends one update instead of one per card.
    private func scheduleRegistrationUpload() {
        registrationGeneration &+= 1
        let generation = registrationGeneration
        guard scenePhase == .active else {
            Task { await uploadRegistration() }
            return
        }
        Task {
            try? await Task.sleep(for: .seconds(10))
            guard generation == registrationGeneration else { return }
            await uploadRegistration()
        }
    }

    /// Sends a waiting update before iOS suspends the app, so the server
    /// never nudges a learner who already reached today's goal.
    private func uploadRegistrationBeforeBackground() {
        registrationGeneration &+= 1
        let identifier = UIApplication.shared.beginBackgroundTask(withName: "word7000-reminders")
        Task {
            await uploadRegistration()
            UIApplication.shared.endBackgroundTask(identifier)
        }
    }

    private func uploadRegistration() async {
        if let row = liveActivities.registration(deviceId: model.settings.deviceSourceId, plan: model.streakPlan, enabled: model.reminderEnabled,
                                                 progress: model.progress, chineseInterface: model.studyMode == .english, today: model.today,
                                                 reminderMinute: account.supportsCustomReminderTime ? (model.settings.reminderMinute ?? 720) : nil) {
            if await account.saveLiveActivityDevice(row) { liveActivities.acknowledgeRegistration(row) }
        }
    }
}
