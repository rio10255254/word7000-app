import SwiftUI
import UIKit
import Word7000Core

@main
struct Word7000App: App {
    @State private var model: AppModel
    @State private var account: AccountModel
    @State private var liveActivities = LiveActivityManager()
    @State private var homeWidget = HomeWidgetBridge()
    @State private var plus: PlusModel
    @State private var refreshingReminders = false
    @State private var reminderRefreshPending = false
    @State private var registrations = ReminderRegistrationCoordinator()
    @State private var reminderBackground = ReminderBackgroundUpload()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        SpeakingRecorder.removeAbandonedTakes()
        let model = AppModel.launch()
        _model = State(initialValue: model)
        let plus = PlusModel()
        let account = AccountModel(app: model)
        account.plus = plus
        CloudAssistant.shared.account = account
        CloudAssistant.shared.plus = plus
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
                    account.beforeSignOut = { [weak account, registrations] owner, deviceId in
                        await registrations.revoke(owner: owner, deviceId: deviceId) { [weak account] row in
                            guard let account else { return false }
                            return await account.disableLiveActivityDevice(row)
                        }
                    }
                    await account.bootstrap()
                    await account.checkReminderSupport()
                    await refreshReminders()
                }
                .task {
                    await liveActivities.observePushToStartTokens { _ in
                        Task { await refreshReminders() }
                    }
                }
                .onChange(of: reminderInputs) { _, _ in Task { await refreshReminders() } }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    model.refreshToday()
                    account.heartbeat()
                    Task { await refreshReminders() }
                }
                .onChange(of: account.session?.user.id) { _, _ in
                    registrations.setOwner(account.session?.user.id)
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
                Task { await IntelligenceSettings.shared.refreshPolicy() }
                reminderBackground.stop()
                registrations.resume()
                model.refreshToday()
                scheduleRegistrationUpload()
                Task { await Speaker.shared.refreshVoices() }
                plus.refreshAccessState()
                account.heartbeat()
                Task {
                    await plus.refreshEntitlements()
                    // Picks up what other devices saved while this one was away.
                    await account.flush(pullingCloud: true)
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

    /// Everything the reminders and widgets show; one value keeps the scene's
    /// modifier chain short enough for the type checker.
    private struct ReminderInputs: Equatable {
        var userId: String?
        var localOwnerId: String?
        var lastStudyDate: String?
        var studiedToday: Int
        var dailyTarget: Int
        var streak: Int
        var streakFreezeDate: String?
        var enabled: Bool
        var reminderMinute: Int?
        var customTime: Bool
        var studyMode: StudyMode
    }

    private var reminderInputs: ReminderInputs {
        ReminderInputs(userId: account.session?.user.id, localOwnerId: model.settings.localOwnerId,
                       lastStudyDate: model.progress.lastStudyDate, studiedToday: model.progress.studiedToday,
                       dailyTarget: model.progress.dailyTarget, streak: model.progress.streak,
                       streakFreezeDate: model.progress.streakFreezeDate, enabled: model.reminderEnabled,
                       reminderMinute: model.settings.reminderMinute, customTime: account.supportsCustomReminderTime,
                       studyMode: model.studyMode)
    }

    /// Keeps the local streak card and the server's view of this iPhone in
    /// step with today's progress.
    private func refreshReminders() async {
        // Capture the account, progress and ordering timestamp before ActivityKit
        // or account authentication can suspend this refresh.
        scheduleRegistrationUpload()
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
    }

    /// The lock screen card is updated at once by `syncReminders`; the server's copy waits
    /// for a pause, so a study session sends one update instead of one per card.
    private func scheduleRegistrationUpload() {
        captureRegistration(delay: scenePhase == .active ? .seconds(10) : .zero)
    }

    /// Sends a waiting update before iOS suspends the app, so the server
    /// never nudges a learner who already reached today's goal.
    private func uploadRegistrationBeforeBackground() {
        captureRegistration(delay: .zero)
        reminderBackground.start(expiration: { registrations.suspend() }) {
            await registrations.flush()
        }
    }

    private func captureRegistration(delay: Duration) {
        let owner = account.session?.user.id
        registrations.setOwner(owner)
        // During account activation the session changes before its progress is
        // loaded. Never label the previous learner's progress as the new user's.
        guard let owner, model.settings.localOwnerId == owner else { return }
        if let row = liveActivities.registration(deviceId: model.settings.deviceSourceId, plan: model.streakPlan, enabled: model.reminderEnabled,
                                                 progress: model.progress, chineseInterface: model.studyMode == .english, today: model.today,
                                                 reminderMinute: account.supportsCustomReminderTime ? (model.settings.reminderMinute ?? 720) : nil) {
            registrations.submit(owner: owner, values: row, delay: delay) { row in
                guard account.session?.user.id == owner, model.settings.localOwnerId == owner, !Task.isCancelled else { return false }
                return await account.saveLiveActivityDevice(row)
            }
        }
    }
}

/// A lease protects the whole serialized batch. Completion and expiration can
/// race, so both paths release the same identifier exactly once.
@MainActor
private final class ReminderBackgroundUpload {
    private var identifier: UIBackgroundTaskIdentifier = .invalid
    private var task: Task<Void, Never>?
    private var generation = 0
    private var expiredGeneration: Int?

    func start(expiration: @escaping @MainActor () -> Void, operation: @escaping @MainActor () async -> Void) {
        guard identifier == .invalid else { return }
        generation &+= 1
        let current = generation
        identifier = UIApplication.shared.beginBackgroundTask(withName: "word7000-reminders") { [weak self] in
            // UIKit invokes expiration synchronously on the main thread. End
            // the lease here, not in a task that might run after suspension.
            MainActor.assumeIsolated {
                guard let self, self.generation == current, self.expiredGeneration != current else { return }
                self.expiredGeneration = current
                expiration()
                self.task?.cancel()
                self.finish(generation: current)
            }
        }
        if expiredGeneration == current {
            finish(generation: current)
            return
        }
        guard identifier != .invalid else {
            generation &+= 1
            expiration()
            return
        }
        task = Task { [weak self] in
            await operation()
            self?.finish(generation: current)
        }
    }

    private func finish(generation: Int) {
        guard self.generation == generation, identifier != .invalid else { return }
        let ending = identifier
        identifier = .invalid
        // Also invalidates an expiration callback queued before foregrounding.
        self.generation &+= 1
        task = nil
        UIApplication.shared.endBackgroundTask(ending)
    }

    func stop() {
        task?.cancel()
        finish(generation: generation)
    }
}
