import Foundation
import Observation
import StoreKit
import SwiftUI
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
    private(set) var plans: [PlusPlan] = []
    private(set) var plansState: PlansState = .loading
    /// The plan and the end of the current period while subscribed.
    private(set) var activePlanID: String?
    private(set) var periodEndsAt: Date?

    enum PlansState: Equatable { case loading, loaded, unavailable }

    /// Shown once, on the first launch after the trial ends.
    var trialRecapPending = false
    private(set) var nudgeDismissedDay: String?

    /// Set by the paywall sheet's host to show it from anywhere.
    var paywallReason: PaywallReason?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    private static let trialKey = "plus-trial-started"
    private static let scansKey = "plus-trial-scans"
    private static let recapShownKey = "plus-trial-recap-shown"
    private static let nudgeDismissedKey = "plus-nudge-dismissed-day"

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestingReset") {
            Keychain.delete(Self.trialKey)
            Keychain.delete(Self.scansKey)
            UserDefaults.standard.removeObject(forKey: Self.recapShownKey)
            UserDefaults.standard.removeObject(forKey: Self.nudgeDismissedKey)
        }
        nudgeDismissedDay = UserDefaults.standard.string(forKey: Self.nudgeDismissedKey)
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

    /// The reminder for the home screen, unless it was closed today.
    var nudge: PlusPolicy.Nudge? {
        guard nudgeDismissedDay != Self.dayKey(Date()) else { return nil }
        return policy.nudge()
    }

    func dismissNudge() {
        let key = Self.dayKey(Date())
        nudgeDismissedDay = key
        UserDefaults.standard.set(key, forKey: Self.nudgeDismissedKey)
    }

    func markTrialRecapShown() {
        trialRecapPending = false
        UserDefaults.standard.set(true, forKey: Self.recapShownKey)
    }

    private static func dayKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
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
                for await update in StoreKit.Transaction.updates {
                    if case let .verified(transaction) = update { await transaction.finish() }
                    await self?.refreshEntitlements()
                }
            }
        }
        await refreshEntitlements()
        if access == .expired, !UserDefaults.standard.bool(forKey: Self.recapShownKey) {
            trialRecapPending = true
        }
        await loadPlans()
    }

    func loadPlans() async {
        if ProcessInfo.processInfo.arguments.contains("-uiTestingFakePlans") {
            plans = PlusPlan.samples
            plansState = .loaded
            return
        }
        plansState = .loading
        let products = (try? await Product.products(for: Self.productIDs)) ?? []
        let monthly = products.first { $0.id == Self.productIDs[0] }
        plans = products
            .sorted { $0.price > $1.price }
            .map { PlusPlan(product: $0, monthlyPrice: monthly?.price) }
        plansState = plans.isEmpty ? .unavailable : .loaded
    }

    enum PurchaseOutcome { case purchased, pending, cancelled, failed }

    func purchase(_ plan: PlusPlan, with action: PurchaseAction) async -> PurchaseOutcome {
        guard let product = plan.product else { return .failed }
        do {
            switch try await action(product) {
            case let .success(.verified(transaction)):
                await transaction.finish()
                await refreshEntitlements()
                return .purchased
            case .success(.unverified):
                return .failed
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .cancelled
            }
        } catch {
            return .failed
        }
    }

    /// Restores purchases; true when a subscription is active afterwards.
    func restore() async -> Bool {
        try? await AppStore.sync()
        await refreshEntitlements()
        return subscribed
    }

    func refreshEntitlements() async {
        if ProcessInfo.processInfo.arguments.contains("-uiTestingPlus") { return }
        var active: StoreKit.Transaction?
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            if case let .verified(transaction) = entitlement,
               Self.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = transaction
            }
        }
        subscribed = active != nil
        activePlanID = active?.productID
        periodEndsAt = active?.expirationDate
    }

    private static func write(_ value: Double, _ key: String, integer: Bool = false) {
        let text = integer ? String(Int(value)) : String(value)
        Keychain.write(Data(text.utf8), for: key)
    }
}

/// One subscription option as the paywall shows it.
struct PlusPlan: Identifiable {
    let id: String
    let yearly: Bool
    let displayPrice: String
    /// For the yearly plan: what it comes to per month, and the whole months
    /// it saves against paying monthly.
    let perMonth: String?
    let monthsSaved: Int
    let product: Product?

    init(product: Product, monthlyPrice: Decimal?) {
        id = product.id
        yearly = product.subscription?.subscriptionPeriod.unit == .year
        displayPrice = product.displayPrice
        perMonth = yearly ? (product.price / 12).formatted(product.priceFormatStyle) : nil
        monthsSaved = yearly ? monthlyPrice.map { PlusPolicy.monthsSaved(monthly: $0, yearly: product.price) } ?? 0 : 0
        self.product = product
    }

    private init(id: String, yearly: Bool, displayPrice: String, perMonth: String?, monthsSaved: Int) {
        self.id = id
        self.yearly = yearly
        self.displayPrice = displayPrice
        self.perMonth = perMonth
        self.monthsSaved = monthsSaved
        product = nil
    }

    /// Display-only plans for screenshots, where the App Store has no products.
    static let samples = [
        PlusPlan(id: PlusModel.productIDs[1], yearly: true, displayPrice: "NT$490", perMonth: "NT$40.83", monthsSaved: 2),
        PlusPlan(id: PlusModel.productIDs[0], yearly: false, displayPrice: "NT$49", perMonth: nil, monthsSaved: 0),
    ]
}

enum PaywallReason: Identifiable, Equatable {
    case general
    case locked(PlusFeature)
    case trialScansUsed
    case trialEnding(daysLeft: Int)

    var id: String {
        switch self {
        case .general: "general"
        case let .locked(feature): "locked-\(feature.rawValue)"
        case .trialScansUsed: "scans"
        case let .trialEnding(days): "ending-\(days)"
        }
    }

    /// The feature the learner reached for, if any.
    var feature: PlusFeature? {
        switch self {
        case let .locked(feature): feature
        case .trialScansUsed: .scan
        case .general, .trialEnding: nil
        }
    }

    init(_ nudge: PlusPolicy.Nudge) {
        switch nudge {
        case .scansUsedUp: self = .trialScansUsed
        case .lastScan: self = .general
        case let .trialEnding(days): self = .trialEnding(daysLeft: days)
        case .trialEnded: self = .general
        }
    }
}
