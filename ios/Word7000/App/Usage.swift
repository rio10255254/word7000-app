import Foundation
import Word7000Core

/// Counts feature use for the developer's "📈 使用數據" report: event names
/// and short details only (see UsageCounter), sent with the learner's
/// session by AccountModel.sendUsage(). Nothing is counted under UI tests.
@MainActor
enum Usage {
    private static let storageKey = "usage.pending"
    private static var counter: UsageCounter = {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode(UsageCounter.self, from: data) else { return UsageCounter() }
        return saved
    }()

    static func log(_ event: String, _ detail: String = "", count: Int = 1) {
        guard !AppRuntime.uiTesting else { return }
        counter.add(event, detail: detail, count: count)
        save()
    }

    /// Hands over everything counted so far; put it back with `restore` if
    /// it could not be sent.
    static func take() -> UsageCounter {
        let batch = counter.drain()
        save()
        return batch
    }

    static func restore(_ batch: UsageCounter) {
        counter.merge(batch)
        save()
    }

    private static func save() {
        if counter.isEmpty { UserDefaults.standard.removeObject(forKey: storageKey) }
        else if let data = try? JSONEncoder().encode(counter) { UserDefaults.standard.set(data, forKey: storageKey) }
    }
}
