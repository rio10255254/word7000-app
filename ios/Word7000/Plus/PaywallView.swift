import StoreKit
import SwiftUI
import Word7000Core

/// Apple's subscription sheet with a short, honest list of what Plus adds.
struct PaywallView: View {
    @Environment(PlusModel.self) private var plus
    @Environment(\.dismiss) private var dismiss
    var reason: PaywallReason

    var body: some View {
        SubscriptionStoreView(productIDs: PlusModel.productIDs) {
            VStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(Palette.accent.gradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                Text("Word7000 Plus").font(.rounded(.title, weight: .bold))
                Text(P.headline(reason))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 10) {
                    benefit("doc.text.viewfinder", P.benefitScan)
                    benefit("icloud", P.benefitSync)
                    benefit("chart.bar.xaxis", P.benefitHistory)
                    benefit("timer", P.benefitExam)
                }
                .padding(.top, 4)
                Text(P.freeForever)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .subscriptionStoreControlStyle(.prominentPicker)
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .restorePurchases)
        .subscriptionStorePolicyDestination(url: URL(string: "https://word7000-app.rio10255254.workers.dev/privacy.html")!, for: .privacyPolicy)
        .subscriptionStorePolicyDestination(url: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!, for: .termsOfService)
        .onInAppPurchaseCompletion { _, result in
            if case .success(.success) = result {
                await plus.refreshEntitlements()
                dismiss()
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .accessibilityLabel(L.close)
        }
    }

    private func benefit(_ icon: String, _ text: String) -> some View {
        Label {
            Text(text).font(.subheadline)
        } icon: {
            Image(systemName: icon).foregroundStyle(Palette.accent)
        }
    }
}

/// Plus status and entry point in "我".
struct PlusSection: View {
    @Environment(PlusModel.self) private var plus
    @State private var manageOpen = false

    var body: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Palette.accent.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Word7000 Plus").font(.headline)
                    Text(statusText).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
            if plus.subscribed {
                Button(P.manage) { manageOpen = true }
            } else {
                Button(P.seePlans) { plus.paywallReason = .general }
                    .accessibilityIdentifier("me-plus")
            }
        }
        .manageSubscriptionsSheet(isPresented: $manageOpen)
    }

    private var statusText: String {
        switch plus.access {
        case .subscribed: return P.statusSubscribed
        case let .trial(daysLeft): return P.statusTrial(daysLeft, scansLeft: plus.policy.trialScansLeft)
        case .expired: return P.statusExpired
        }
    }
}

/// Plus copy (both interface languages).
enum P {
    static func headline(_ reason: PaywallReason) -> String {
        switch reason {
        case .general: return L.t("背單字永遠免費。Plus 讓掃描、同步和考前衝刺都沒有限制。", "Studying words is always free. Plus removes every limit on scanning, sync and exam practice.")
        case .trialScansUsed: return L.t("試用期的 \(PlusPolicy.trialScanLimit) 次掃描已經用完，訂閱後就能無限掃描。", "You have used the \(PlusPolicy.trialScanLimit) trial scans. Subscribe for unlimited scanning.")
        case let .locked(feature):
            switch feature {
            case .scan: return L.t("7 天試用已結束。訂閱後就能繼續掃描單字表和手寫筆記。", "Your 7-day trial has ended. Subscribe to keep scanning word lists and handwriting.")
            case .sync: return L.t("7 天試用已結束。進度仍保存在這支 iPhone，訂閱後就能繼續雲端同步。", "Your 7-day trial has ended. Progress stays on this iPhone; subscribe to keep syncing.")
            case .history: return L.t("訂閱後可以看完整的學習紀錄。", "Subscribe to see your full learning history.")
            case .examPractice: return L.t("訂閱後就能使用考前衝刺模擬。", "Subscribe to use timed exam practice.")
            }
        }
    }

    static var benefitScan: String { L.t("無限掃描單字表，手寫也能辨識整理", "Unlimited scans, including handwriting") }
    static var benefitSync: String { L.t("雲端同步，換手機進度也不會不見", "Cloud sync across iPhones") }
    static var benefitHistory: String { L.t("完整學習紀錄與弱點單字", "Full learning history and weak words") }
    static var benefitExam: String { L.t("考前衝刺模擬測驗", "Timed exam practice") }
    static var freeForever: String { L.t("背 7000 單字、複習、小測驗和口說練習永遠免費。", "Studying the 7000 words, reviews, quizzes and speaking stay free.") }
    static var seePlans: String { L.t("查看方案", "See plans") }
    static var manage: String { L.t("管理訂閱", "Manage subscription") }
    static var statusSubscribed: String { L.t("已訂閱，所有功能都已解鎖", "Subscribed. Everything is unlocked.") }
    static func statusTrial(_ days: Int, scansLeft: Int) -> String {
        L.t("免費試用剩 \(days) 天 · 還能掃描 \(scansLeft) 次", "Free trial: \(days) days left · \(scansLeft) scans left")
    }
    static var statusExpired: String { L.t("試用已結束，背單字仍可免費使用", "Trial ended. Studying stays free.") }
    static var syncLocked: String { L.t("雲端同步需要 Plus，進度先存在手機", "Sync needs Plus; progress is kept on this iPhone") }
    static var plusBadge: String { "Plus" }
}
