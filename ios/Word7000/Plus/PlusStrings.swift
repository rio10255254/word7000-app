import Foundation
import Word7000Core

/// Plus copy, in both interface languages. Honest about what stays free.
enum P {
    static func headline(_ reason: PaywallReason) -> String {
        switch reason {
        case .general:
            return L.t("背單字永遠免費。Plus 讓掃描、同步和考前衝刺都沒有限制。", "Studying words is always free. Plus removes every limit on scanning, sync and exam practice.")
        case .trialScansUsed:
            return L.t("試用期的 \(PlusPolicy.trialScanLimit) 次掃描已經用完，訂閱後就能無限掃描。", "You have used the \(PlusPolicy.trialScanLimit) trial scans. Subscribe for unlimited scanning.")
        case let .trialEnding(days):
            return L.t("試用剩 \(days) 天。現在訂閱，到期後也不會中斷。", "\(days) trial days left. Subscribe now and nothing stops when it ends.")
        case let .locked(feature):
            switch feature {
            case .scan: return L.t("7 天試用已結束。訂閱後就能繼續掃描單字表和手寫筆記。", "Your 7-day trial has ended. Subscribe to keep scanning word lists and handwriting.")
            case .sync: return L.t("7 天試用已結束。進度仍保存在這支 iPhone，訂閱後就能繼續雲端同步。", "Your 7-day trial has ended. Progress stays on this iPhone; subscribe to keep syncing.")
            case .history: return L.t("看清楚自己這幾個月怎麼進步，哪些字一直忘。", "See how you have improved over months, and which words keep slipping.")
            case .examPractice: return L.t("考前用限時模擬測驗，找出還不熟的級別。", "Timed mock exams show which levels still need work.")
            }
        }
    }

    /// The learner's own progress, so the paywall talks about them.
    static func progressLine(mastered: Int, streak: Int) -> String? {
        guard mastered > 0 else { return nil }
        if streak > 1 { return L.t("你已經記住 \(mastered) 個字，連續 \(streak) 天", "\(mastered) words learned · \(streak)-day streak") }
        return L.t("你已經記住 \(mastered) 個字", "\(mastered) words learned so far")
    }

    static var benefitScan: String { L.t("無限掃描", "Unlimited scanning") }
    static var benefitScanDetail: String { L.t("單字表、講義、手寫筆記，拍一下就變成字庫", "Word lists, handouts and handwriting become a bank in one photo") }
    static var benefitSync: String { L.t("雲端同步", "Cloud sync") }
    static var benefitSyncDetail: String { L.t("換手機、重灌 App，進度都還在", "Change iPhones or reinstall and your progress is still there") }
    static var benefitHistory: String { L.t("完整學習紀錄", "Full learning history") }
    static var benefitHistoryDetail: String { L.t("30、90 天的學習趨勢和最常忘記的字", "30- and 90-day trends and the words you forget most") }
    static var benefitExam: String { L.t("考前衝刺模擬", "Exam practice") }
    static var benefitExamDetail: String { L.t("50 題限時 15 分鐘，交卷看各級分數", "50 questions in 15 minutes, scored by level") }
    static var freeForever: String { L.t("背 7000 單字、複習、小測驗和口說練習永遠免費。", "Studying the 7000 words, reviews, quizzes and speaking stay free.") }

    // Plans
    static var yearly: String { L.t("年費方案", "Yearly") }
    static var monthly: String { L.t("月費方案", "Monthly") }
    static var monthlyDetail: String { L.t("隨時可以取消", "Cancel anytime") }
    static func perMonth(_ price: String) -> String { L.t("每月只要 \(price)", "Just \(price) a month") }
    static var perYear: String { L.t("每年", "per year") }
    static var perMonthUnit: String { L.t("每月", "per month") }
    static func saveMonths(_ months: Int) -> String { L.t("省 \(months) 個月", "\(months) months free") }
    static func cta(_ plan: PlusPlan?) -> String {
        guard let plan else { return L.t("訂閱 Plus", "Subscribe") }
        return plan.yearly ? L.t("訂閱年費方案", "Subscribe yearly") : L.t("訂閱月費方案", "Subscribe monthly")
    }
    static func renewalTerms(_ plan: PlusPlan?) -> String {
        guard let plan else { return L.t("訂閱會自動續訂，可隨時在「設定」取消。", "Subscriptions renew automatically. Cancel anytime in Settings.") }
        return plan.yearly
            ? L.t("每年 \(plan.displayPrice)，自動續訂，可隨時在「設定」取消。", "\(plan.displayPrice) a year, renews automatically. Cancel anytime in Settings.")
            : L.t("每月 \(plan.displayPrice)，自動續訂，可隨時在「設定」取消。", "\(plan.displayPrice) a month, renews automatically. Cancel anytime in Settings.")
    }
    static var restore: String { L.t("恢復購買", "Restore") }
    static var terms: String { L.t("使用條款", "Terms") }
    static var retry: String { L.t("再試一次", "Try again") }
    static var plansUnavailable: String { L.t("目前無法載入方案，請確認網路後再試一次。", "Plans could not be loaded. Check your connection and try again.") }
    static var pending: String { L.t("購買等待核准中（例如家長同意），核准後會自動解鎖。", "The purchase is waiting for approval, e.g. from a parent. Plus unlocks once approved.") }
    static var failed: String { L.t("目前無法確認購買結果。若已完成付款，請使用「恢復購買」或稍後再試。", "We could not confirm the purchase. If payment completed, restore purchases or try again shortly.") }
    static var restoreFailed: String { L.t("目前無法恢復購買，請稍後再試。", "Purchases could not be restored right now. Please try again shortly.") }
    static var nothingToRestore: String { L.t("這個 Apple 帳號沒有可恢復的訂閱。", "No subscription to restore for this Apple Account.") }

    // Welcome
    static var welcomeTitle: String { L.t("歡迎加入 Plus", "Welcome to Plus") }
    static var welcomeText: String { L.t("所有功能都解鎖了，謝謝你支持 Word7000。", "Everything is unlocked. Thank you for supporting Word7000.") }
    static var welcomeStart: String { L.t("開始使用", "Get started") }

    // Me
    static var seePlans: String { L.t("查看方案", "See plans") }
    static var manage: String { L.t("管理訂閱", "Manage subscription") }
    static var upgradePlus: String { L.t("升級 Plus", "Upgrade to Plus") }
    static var unlockPlus: String { L.t("解鎖 Plus", "Unlock Plus") }
    static func priceFrom(_ price: String) -> String { L.t("每月 \(price) 起", "From \(price) a month") }
    static var memberTitle: String { L.t("Plus 會員", "Plus member") }
    static func memberDetail(planYearly: Bool, endsAt: Date?) -> String {
        let plan = planYearly ? yearly : monthly
        guard let endsAt else { return plan }
        return L.t("\(plan) · 本期到 \(endsAt.formatted(date: .numeric, time: .omitted))", "\(plan) · period ends \(endsAt.formatted(date: .abbreviated, time: .omitted))")
    }
    static var trialTitle: String { L.t("Plus 免費試用中", "Plus free trial") }
    static var trialDetail: String { L.t("所有功能都能用，試用結束前訂閱就不會中斷", "Everything is on. Subscribe before it ends to keep it all.") }
    static func trialDaysMeter(_ days: Int) -> String { L.t("試用剩 \(days) 天", "\(days) days left") }
    static func trialScansMeter(_ scans: Int) -> String { L.t("試用掃描剩 \(scans) / \(PlusPolicy.trialScanLimit) 次", "\(scans) of \(PlusPolicy.trialScanLimit) trial scans left") }
    static var statusExpired: String { L.t("試用已結束，背單字仍可免費使用", "Trial ended. Studying stays free.") }
    static var syncLocked: String { L.t("雲端同步需要 Plus，進度先存在手機", "Sync needs Plus; progress is kept on this iPhone") }
    static var plusBadge: String { "Plus" }
    static var lockedLabel: String { L.t("需要 Plus", "Needs Plus") }

    // Nudges
    static func nudgeIcon(_ nudge: PlusPolicy.Nudge) -> String {
        switch nudge {
        case .scansUsedUp, .lastScan: "doc.text.viewfinder"
        case .trialEnding: "hourglass"
        case .trialEnded: "sparkles"
        }
    }
    static func nudgeTitle(_ nudge: PlusPolicy.Nudge) -> String {
        switch nudge {
        case .scansUsedUp: L.t("試用掃描次數用完了", "Trial scans used up")
        case .lastScan: L.t("試用掃描只剩 1 次", "1 trial scan left")
        case let .trialEnding(days): L.t("Plus 試用剩 \(days) 天", "\(days) Plus trial days left")
        case .trialEnded: L.t("解鎖 Word7000 Plus", "Unlock Word7000 Plus")
        }
    }
    static func nudgeText(_ nudge: PlusPolicy.Nudge) -> String {
        switch nudge {
        case .scansUsedUp, .lastScan: L.t("訂閱 Plus 就能無限掃描單字表和手寫筆記。", "Plus scans word lists and handwriting without limits.")
        case .trialEnding: L.t("到期後掃描、同步和考前衝刺會鎖起來。", "Scanning, sync and exam practice lock when it ends.")
        case .trialEnded: L.t("繼續掃描、雲端同步、完整紀錄和考前衝刺。", "Keep scanning, syncing, your full history and exam practice.")
        }
    }

    // Locked previews
    static func lockedTitle(_ feature: PlusFeature) -> String {
        switch feature {
        case .history: L.t("完整學習紀錄是 Plus 功能", "Full history is part of Plus")
        case .examPractice: L.t("考前衝刺是 Plus 功能", "Exam practice is part of Plus")
        case .scan: L.t("掃描是 Plus 功能", "Scanning is part of Plus")
        case .sync: L.t("雲端同步是 Plus 功能", "Sync is part of Plus")
        }
    }
    static func lockedText(_ feature: PlusFeature) -> String {
        switch feature {
        case .history: L.t("你的紀錄一直都有保存，解鎖就能看 30、90 天的趨勢和弱點單字。", "Your history is kept. Unlock it to see 30- and 90-day trends and weak words.")
        case .examPractice: benefitExamDetail
        case .scan: benefitScanDetail
        case .sync: benefitSyncDetail
        }
    }

    // Trial recap
    static var recapTitle: String { L.t("7 天試用結束了", "Your 7-day trial is over") }
    static var recapText: String { L.t("這一週你的成果：", "Here is what your week added up to:") }
    static var recapCards: String { L.t("學習卡", "Cards") }
    static var recapDays: String { L.t("學習天數", "Days") }
    static var recapScans: String { L.t("掃描次數", "Scans") }
    static var recapKeepTitle: String { L.t("繼續免費使用", "Still free") }
    static var recapFreeItems: [String] {
        [L.t("背 7000 單字與複習", "Studying and reviews"), L.t("小測驗和口說練習", "Quizzes and speaking"), L.t("最近 7 天的統計", "The last 7 days of stats")]
    }
    static var recapPlusTitle: String { L.t("訂閱 Plus 繼續使用", "Keep these with Plus") }
    static var recapLater: String { L.t("先繼續免費使用", "Continue for free") }

    // Scan
    static func scansLeft(_ scans: Int) -> String { L.t("試用還能掃描 \(scans) 次", "\(scans) trial scans left") }
}
