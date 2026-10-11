import SwiftUI

@main
struct Word7000App: App {
    @State private var model: AppModel
    @State private var account: AccountModel
    @State private var liveActivities = LiveActivityManager()
    @State private var plus: PlusModel
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
                .onChange(of: plus.subscribed) { _, _ in Task { await account.flush() } }
                .preferredColorScheme(model.settings.theme.colorScheme)
                .tint(Palette.accent)
                .task {
                    await account.bootstrap()
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
                .task {
                    // Counts the learner as active while the app is open.
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(300))
                        if scenePhase == .active { account.heartbeat() }
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                model.refreshToday()
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
        let plan = model.streakPlan
        if model.reminderEnabled {
            await liveActivities.sync(plan: plan, chineseInterface: model.studyMode == .english)
        } else {
            await liveActivities.endAll()
        }
        if let row = liveActivities.registration(deviceId: model.settings.deviceSourceId, plan: plan, enabled: model.reminderEnabled,
                                                 progress: model.progress, chineseInterface: model.studyMode == .english, today: model.today) {
            account.saveLiveActivityDevice(row)
        }
    }
}
