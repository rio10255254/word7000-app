import Foundation
import Observation
import StoreKit
import SwiftUI
import Word7000Core

/// Word7000 Plus: the subscription (StoreKit 2), the free trial and what is
/// unlocked right now.
///
/// Plus belongs to the Apple ID that bought it, and the learner's account is
/// that same Apple ID (Sign in with Apple; guests have no account). Only a
/// subscription unlocks Plus; the free week is the App Store's own trial
/// offer on the subscription, not something the app grants.
@MainActor
@Observable
final class PlusModel {
    static let productIDs = ["com.rio.word7000.plus.monthly", "com.rio.word7000.plus.yearly"]

    /// The App Store's subscription on this iPhone's Apple ID. It outlives
    /// the app's account (deleting the account doesn't cancel it), so
    /// Premium only opens once that Apple ID is signed in again.
    private(set) var storeSubscribed = false
    /// Premium is unlocked: subscribed, and signed in with Apple.
    var subscribed: Bool { storeSubscribed && (signedIn || AppRuntime.uiTesting) }
    /// Subscribed on this Apple ID, but nobody is signed in to use it (for
    /// instance after deleting the account): it still renews until cancelled.
    var subscriptionAwaitsSignIn: Bool { storeSubscribed && !signedIn && !AppRuntime.uiTesting }
    /// Apple's signed copy of the active subscription. The AI server checks it
    /// itself before giving the Plus model, so it cannot be faked by the app.
    private(set) var entitlementJWS: String?
    /// A trial start the UI tests use to see each state of the old in-app
    /// trial; learners have none (the App Store's trial is a subscription).
    private(set) var trialStartedAt: Date
    /// Signed in with Apple (not a guest).
    private(set) var signedIn = false
    /// The signed-in account's id, tied to purchases so a subscription is
    /// recorded against the Apple ID's own account.
    private(set) var accountId: String?
    private(set) var trialScansUsed: Int
    private(set) var plans: [PlusPlan] = []
    private(set) var plansState: PlansState = .loading
    /// The plan and the end of the current period while subscribed.
    private(set) var activePlanID: String?
    private(set) var periodEndsAt: Date?
    /// The App Store's id for Plus's subscription group, from the active
    /// subscription or the loaded plans, so Manage subscription opens on Plus
    /// alone instead of every subscription on the Apple ID.
    private(set) var subscriptionGroupID: String?
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
        if arguments.contains("-uiTestingPlus") { storeSubscribed = true }
        if arguments.contains("-uiTestingFakePlans") { entitlementsLoaded = true }
    }

    var policy: PlusPolicy {
        PlusPolicy(trialStartedAt: effectiveTrialStart, subscribed: subscribed, trialScansUsed: trialScansUsed)
    }

    private var effectiveTrialStart: Date {
        AppRuntime.uiTesting ? trialStartedAt : .distantPast
    }

    /// A guest signs in with Apple before subscribing, so Plus is tied to an
    /// account that keeps their progress.
    var needsSignIn: Bool { !signedIn && !AppRuntime.uiTesting }

    /// Called by the account whenever who is signed in changes.
    func setAccount(id: String?) {
        signedIn = id != nil
        accountId = id
        refreshAccessState()
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

    func refreshAccessState() {
        referenceDate = Date()
        if access.isActive {
            trialRecapPending = false
        } else if entitlementsLoaded, AppRuntime.uiTesting, !UserDefaults.standard.bool(forKey: Self.recapShownKey) {
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
        // The App Store's free trial, for an Apple ID that has not had one.
        let trialEligible = await products.first?.subscription?.isEligibleForIntroOffer ?? false
        if let group = products.compactMap({ $0.subscription?.subscriptionGroupID }).first { subscriptionGroupID = group }
        plans = products
            .sorted { $0.price > $1.price }
            .map { PlusPlan(product: $0, monthlyPrice: monthly?.price, trialEligible: trialEligible) }
        plansState = plans.isEmpty ? .unavailable : .loaded
    }

    enum PurchaseOutcome { case purchased, pending, cancelled, failed }

    func purchase(_ plan: PlusPlan, with action: PurchaseAction) async -> PurchaseOutcome {
        guard let product = plan.product else { return .failed }
        // The purchase carries the account's id, so the App Store's record of
        // it (and its renewals) points back to this learner's account.
        var options: Set<Product.PurchaseOption> = []
        if let accountId, let token = UUID(uuidString: accountId) { options.insert(.appAccountToken(token)) }
        do {
            switch try await action(product, options: options) {
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
        return storeSubscribed ? .restored : .noneFound
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
        storeSubscribed = active != nil
        entitlementJWS = activeJWS
        activePlanID = active?.productID
        if let group = active?.subscriptionGroupID { subscriptionGroupID = group }
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
    /// The App Store's free trial on this plan, in days, when this Apple ID
    /// can still have it (set up in App Store Connect as an introductory offer).
    var freeTrialDays: Int?
    let product: Product?

    init(product: Product, monthlyPrice: Decimal?, trialEligible: Bool = false) {
        if trialEligible, let offer = product.subscription?.introductoryOffer, offer.paymentMode == .freeTrial {
            let unitDays: Int
            switch offer.period.unit {
            case .day: unitDays = 1
            case .week: unitDays = 7
            case .month: unitDays = 30
            case .year: unitDays = 365
            @unknown default: unitDays = 1
            }
            freeTrialDays = offer.period.value * unitDays * max(1, offer.periodCount)
        }
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
        PlusPlan(id: PlusModel.productIDs[1], yearly: true, displayPrice: "NT$790", perMonth: "NT$65.83", monthsSaved: 2),
        PlusPlan(id: PlusModel.productIDs[0], yearly: false, displayPrice: "NT$79", perMonth: nil, monthsSaved: 0),
    ]
}

enum PaywallReason: Identifiable, Equatable {
    case general
    case locked(PlusFeature)
    case trialScansUsed
    case trialEnding(daysLeft: Int)
    /// Checking a speaking answer (the online AI is Premium).
    case speakingCoach

    var id: String {
        switch self {
        case .general: "general"
        case .speakingCoach: "speaking-coach"
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
        case .speakingCoach: .smartAI
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
