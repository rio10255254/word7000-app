import SwiftUI
import UIKit
import Word7000Core

@main
struct Word7000App: App {
    @UIApplicationDelegateAdaptor(PushAppDelegate.self) private var pushDelegate
    @State private var model: AppModel
    @State private var account: AccountModel
    @State private var liveActivities = LiveActivityManager()
    @State private var homeWidget = HomeWidgetBridge()
    @State private var plus: PlusModel
    @State private var refreshingReminders = false
    @State private var reminderRefreshPending = false
    @State private var registrations = ReminderRegistrationCoordinator()
    @State private var reminderBackground = ReminderBackgroundUpload()
    @State private var saveLease = SaveBeforeSuspend()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        WarmTone.styleSystemBars()
        SpeakingRecorder.removeAbandonedTakes()
        let model = AppModel.launch()
        _model = State(initialValue: model)
        let plus = PlusModel()
        let account = AccountModel(app: model)
        account.plus = plus
        CloudAssistant.shared.account = account
        CloudAssistant.shared.plus = plus
        PushRegistration.shared.account = account
        PushRegistration.shared.plus = plus
        _account = State(initialValue: account)
        _plus = State(initialValue: plus)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                // UI tests of the App Store art: the cat alone (see MascotPosterView).
                if let poster = AppRuntime.mascotPoster {
                    MascotPosterView(mood: poster.mood, white: poster.white)
                } else {
                    RootView()
                }
            }
                .environment(model)
                .environment(account)
                .environment(plus)
                .task { await plus.start() }
                .task { await Speaker.shared.refreshVoices() }
                .task { await PushRegistration.shared.refreshIfAllowed() }
                // Who the learner is decides which messages reach them. The
                // account itself is part of it: a new guest after deleting an
                // account, or a session restored after the token arrived,
                // registers the iPhone again.
                .task(id: "\(account.session?.user.id ?? "")|\(account.isPermanent)|\(plus.subscribed)|\(model.studyMode)") {
                    await PushRegistration.shared.upload()
                }
                .task { model.syncAppIcon() }
                // Which version this account runs, for the developer's status
                // check and version-limited messages.
                .task(id: account.session?.user.id) { await account.reportAppVersion() }
                .onChange(of: plus.subscribed) { _, _ in Task { await account.flush() } }
                .preferredColorScheme(model.settings.theme.colorScheme)
                .environment(\.appStyle, model.settings.appStyle ?? .standard)
                .tint(Palette.accent)
                .task {
                    account.beforeSignOut = { [weak account, registrations] owner, deviceId in
                        await registrations.revoke(owner: owner, deviceId: deviceId) { [weak account] row in
                            guard let account else { return false }
                            return await account.disableLiveActivityDevice(row)
                        }
                    }
                    await account.bootstrap()
                    await account.confirmAccountExists()
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
                        if scenePhase == .active { model.refreshToday(); account.heartbeat(); await refreshReminders(); await account.sendUsage() }
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
                Usage.log("app_open", model.studyMode.rawValue)
                Task {
                    await account.confirmAccountExists()
                    if let content = await account.fetchRemoteContent(cached: model.remoteContent) {
                        model.applyRemoteContent(content)
                        model.saveRemoteContent()
                    }
                    await account.sendUsage()
                    await plus.refreshEntitlements()
                    // Picks up what other devices saved while this one was away.
                    await account.flush(pullingCloud: true)
                    await refreshReminders()
                }
            case .background:
                plus.suspendTimeUpdates()
                model.saveNow()
                saveLease.hold(Persistence.live.store)
                account.flushBeforeBackground()
                account.sendUsageBeforeBackground()
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

/// Saves are written on a background queue that a busy iPhone can hold up
/// for seconds. Going to the background, the app stays awake until every
/// queued save is on disk, so being suspended and then closed loses nothing.
@MainActor
private final class SaveBeforeSuspend {
    private var identifier: UIBackgroundTaskIdentifier = .invalid
    private var generation = 0

    func hold(_ store: LearningFileStore) {
        guard identifier == .invalid else { return }
        generation &+= 1
        let current = generation
        identifier = UIApplication.shared.beginBackgroundTask(withName: "word7000-save") { [weak self] in
            // UIKit calls this synchronously on the main thread.
            MainActor.assumeIsolated { self?.release(current) }
        }
        guard identifier != .invalid else { return }
        // Waiting on the store's queue also raises its priority until it drains.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            store.finishPendingWrites()
            #if DEBUG && targetEnvironment(simulator)
            UITestingSaveSignal.post()
            #endif
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.release(current) } }
        }
    }

    /// Ends this hold only: a drain that finishes late never ends a later one.
    private func release(_ hold: Int) {
        guard hold == generation, identifier != .invalid else { return }
        let ending = identifier
        identifier = .invalid
        UIApplication.shared.endBackgroundTask(ending)
    }
}

#if DEBUG && targetEnvironment(simulator)
/// UI tests that relaunch the app close it only once this file appears,
/// written when going to the background has put every save on disk
/// (see `closeAfterSaving` in the UI tests). Under XCTest the simulator
/// keeps the app running in the background, so it never reads as suspended.
enum UITestingSaveSignal {
    static func post() {
        guard AppRuntime.uiTesting, let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] else { return }
        let directory = URL(fileURLWithPath: home).appendingPathComponent("word7000-ui-testing", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? Data().write(to: directory.appendingPathComponent("saves-on-disk"))
    }
}
#endif
