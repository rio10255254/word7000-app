import SwiftUI

@main
struct Word7000App: App {
    @State private var model = AppModel.launch()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(model.settings.theme.colorScheme)
                .tint(Palette.accent)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.refreshToday()
            case .background, .inactive: model.saveNow()
            @unknown default: break
            }
        }
    }
}
