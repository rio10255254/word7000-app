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
    // A constant: read from anywhere, not only the main actor.
    nonisolated static let productIDs = ["com.rio.word7000.plus.monthly", "com.rio.word7000.plus.yearly"]

    private(set) var subscribed = false
    /// Apple's signed copy of the active subscription. The AI server checks it
    /// itself before giving the Plus model, so it cannot be faked by the app.
    private(set) var entitlementJWS: String?
    private(set) var trialStartedAt: Date
    private(set) var trialScansUsed: Int
    private(set) var plans: [PlusPlan] = []
    private(set) var plansState: PlansState = .loading
    /// The plan and the end of the current period while subscribed.
    private(set) var activePlanID: String?
    private(set) var periodEndsAt: Date?
    private(set) var referenceDate = Date()

    enum PlansState: Equatable { case loading, loaded, unavailable }

    /// Shown once, on the first launch after the trial ends.
    var trialRecapPending = false
    private(set) var nudgeDismissedDay: String?

    /// Set by the paywall sheet's host to show it from anywhere.
    var paywallReason: PaywallReason?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var accessRefreshTimer: Timer?
    @ObservationIgnored private var entitlementsLoaded = false

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
        if arguments.contains("-uiTestingTrialEndsSoon") {
            trialStartedAt = Date().addingTimeInterval(-Double(PlusPolicy.trialDays) * 86_400 + 4)
        }
        trialScansUsed = Keychain.read(Self.scansKey).flatMap { String(data: $0, encoding: .utf8) }.flatMap(Int.init) ?? 0
        if stored == nil { Self.write(start.timeIntervalSince1970, Self.trialKey) }
        if arguments.contains("-uiTestingPlus") { subscribed = true }
        if arguments.contains("-uiTestingFakePlans") { entitlementsLoaded = true }
    }

    var policy: PlusPolicy {
        PlusPolicy(trialStartedAt: trialStartedAt, subscribed: subscribed, trialScansUsed: trialScansUsed)
    }

    var access: PlusAccess { policy.access(now: referenceDate) }

    func decide(_ feature: PlusFeature) -> PlusPolicy.Decision {
        policy.decide(feature, now: max(referenceDate, Date()))
    }

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
        guard nudgeDismissedDay != Self.dayKey(referenceDate) else { return nil }
        return policy.nudge(now: referenceDate)
    }

    func dismissNudge() {
        let key = Self.dayKey(Date())
        nudgeDismissedDay = key
        UserDefaults.standard.set(key, forKey: Self.nudgeDismissedKey)
    }

    /// Remembered as soon as the recap is on screen, so it never shows twice.
    func noteTrialRecapSeen() {
        UserDefaults.standard.set(true, forKey: Self.recapShownKey)
    }

    func markTrialRecapShown() {
        trialRecapPending = false
        noteTrialRecapSeen()
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
        refreshAccessState()
    }

    func refreshAccessState() {
        referenceDate = Date()
        if access.isActive {
            trialRecapPending = false
        } else if entitlementsLoaded, !UserDefaults.standard.bool(forKey: Self.recapShownKey) {
            trialRecapPending = true
        }
        suspendTimeUpdates()
        guard !subscribed else { return }
        let midnight = Calendar.current.date(byAdding: .day, value: 1,
                                             to: Calendar.current.startOfDay(for: referenceDate))
        let next = [midnight, policy.nextAccessChange(now: referenceDate)].compactMap { $0 }.min()
        guard let next else { return }
        let delay = max(1, next.timeIntervalSince(referenceDate))
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshAccessState() }
        }
        RunLoop.main.add(timer, forMode: .common)
        accessRefreshTimer = timer
    }

    func suspendTimeUpdates() {
        accessRefreshTimer?.invalidate()
        accessRefreshTimer = nil
    }

    // MARK: StoreKit

    func start() async {
        refreshAccessState()
        if updatesTask == nil, !ProcessInfo.processInfo.arguments.contains("-uiTestingFakePlans") {
            updatesTask = Task { [weak self] in
                for await update in StoreKit.Transaction.updates {
                    if case let .verified(transaction) = update { await transaction.finish() }
                    await self?.refreshEntitlements()
                }
            }
        }
        await refreshEntitlements()
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

    enum RestoreOutcome { case restored, noneFound, cancelled, failed }

    func restore() async -> RestoreOutcome {
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            return .cancelled
        } catch let error as SKError where error.code == .paymentCancelled {
            return .cancelled
        } catch {
            return .failed
        }
        await refreshEntitlements()
        return subscribed ? .restored : .noneFound
    }

    func refreshEntitlements() async {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestingPlus") || arguments.contains("-uiTestingFakePlans") {
            entitlementsLoaded = true
            refreshAccessState()
            return
        }
        var active: StoreKit.Transaction?
        var activeJWS: String?
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            if case let .verified(transaction) = entitlement,
               Self.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = transaction
                activeJWS = entitlement.jwsRepresentation
            }
        }
        subscribed = active != nil
        entitlementJWS = activeJWS
        activePlanID = active?.productID
        periodEndsAt = active?.expirationDate
        entitlementsLoaded = true
        refreshAccessState()
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
