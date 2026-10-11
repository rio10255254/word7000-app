import Foundation
import Observation
import StoreKit
import Word7000Core

/// Word7000 Plus: the subscription (StoreKit 2), the free trial and what is
/// unlocked right now.
@MainActor
@Observable
final class PlusModel {
    static let productIDs = ["com.rio.word7000.plus.monthly", "com.rio.word7000.plus.yearly"]

    private(set) var subscribed = false
    private(set) var trialStartedAt: Date
    private(set) var trialScansUsed: Int
    private(set) var products: [Product] = []

    /// Set by the paywall sheet's host to show it from anywhere.
    var paywallReason: PaywallReason?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    private static let trialKey = "plus-trial-started"
    private static let scansKey = "plus-trial-scans"

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestingReset") {
            Keychain.delete(Self.trialKey)
            Keychain.delete(Self.scansKey)
        }
        let stored = Keychain.read(Self.trialKey).flatMap { String(data: $0, encoding: .utf8) }.flatMap(Double.init)
        let start = stored.map { Date(timeIntervalSince1970: $0) } ?? Date()
        trialStartedAt = arguments.contains("-uiTestingTrialExpired") ? Date().addingTimeInterval(-8 * 86_400) : start
        trialScansUsed = Keychain.read(Self.scansKey).flatMap { String(data: $0, encoding: .utf8) }.flatMap(Int.init) ?? 0
        if stored == nil { Self.write(start.timeIntervalSince1970, Self.trialKey) }
        if arguments.contains("-uiTestingPlus") { subscribed = true }
    }

    var policy: PlusPolicy {
        PlusPolicy(trialStartedAt: trialStartedAt, subscribed: subscribed, trialScansUsed: trialScansUsed)
    }

    var access: PlusAccess { policy.access() }

    func decide(_ feature: PlusFeature) -> PlusPolicy.Decision { policy.decide(feature) }

    /// Runs `action` if the feature is unlocked, otherwise shows the paywall.
    func require(_ feature: PlusFeature, _ action: () -> Void) {
        switch decide(feature) {
        case .allowed: action()
        case .needsPlus: paywallReason = .locked(feature)
        case .trialLimitReached: paywallReason = .trialScansUsed
        }
    }

    func noteScanUsed() {
        guard !subscribed else { return }
        trialScansUsed += 1
        Self.write(Double(trialScansUsed), Self.scansKey, integer: true)
    }

    /// The account may remember an earlier trial (another iPhone, a
    /// reinstall); the earliest start wins.
    func mergeAccountTrialStart(_ date: Date?) {
        let earliest = PlusPolicy.trialStart([trialStartedAt, date])
        guard earliest != trialStartedAt else { return }
        trialStartedAt = earliest
        Self.write(earliest.timeIntervalSince1970, Self.trialKey)
    }

    // MARK: StoreKit

    func start() async {
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                for await update in Transaction.updates {
                    if case let .verified(transaction) = update { await transaction.finish() }
                    await self?.refreshEntitlements()
                }
            }
        }
        await refreshEntitlements()
        products = ((try? await Product.products(for: Self.productIDs)) ?? []).sorted { $0.price < $1.price }
    }

    func refreshEntitlements() async {
        if ProcessInfo.processInfo.arguments.contains("-uiTestingPlus") { return }
        var active = false
        for await entitlement in Transaction.currentEntitlements {
            if case let .verified(transaction) = entitlement,
               Self.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = true
            }
        }
        subscribed = active
    }

    private static func write(_ value: Double, _ key: String, integer: Bool = false) {
        let text = integer ? String(Int(value)) : String(value)
        Keychain.write(Data(text.utf8), for: key)
    }
}

enum PaywallReason: Identifiable, Equatable {
    case general
    case locked(PlusFeature)
    case trialScansUsed

    var id: String {
        switch self {
        case .general: "general"
        case let .locked(feature): "locked-\(feature.rawValue)"
        case .trialScansUsed: "scans"
        }
    }
}
