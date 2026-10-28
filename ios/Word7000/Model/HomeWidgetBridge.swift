import Foundation
import WidgetKit
import Word7000Core

/// Keeps the home and lock screen widgets in step with today's progress.
/// Widgets are only reloaded when what they show actually changed.
@MainActor
final class HomeWidgetBridge {
    private let store = HomeWidgetStore()

    func update(model: AppModel) {
        let snapshot = HomeWidgetSnapshot.make(progress: model.progress, today: model.today,
                                               chineseInterface: model.studyMode == .english,
                                               words: model.studyMode == .chinese ? model.coreBankWords : model.coreWords, previous: store.load())
        if store.save(snapshot) {
            WidgetCenter.shared.reloadTimelines(ofKind: HomeWidgetStore.kind)
        }
    }
}
