import SwiftUI

@main
struct Word7000App: App {
    @State private var model: AppModel
    @State private var account: AccountModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let model = AppModel.launch()
        _model = State(initialValue: model)
        _account = State(initialValue: AccountModel(app: model))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(account)
                .preferredColorScheme(model.settings.theme.colorScheme)
                .tint(Palette.accent)
                .task { await account.bootstrap() }
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
                account.heartbeat()
            case .background:
                model.saveNow()
                account.flushBeforeBackground()
            case .inactive:
                model.saveNow()
            @unknown default:
                break
            }
        }
    }
}
