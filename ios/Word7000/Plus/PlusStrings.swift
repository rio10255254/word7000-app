import Foundation
import Word7000Core

/// Plus copy, in both interface languages. Honest about what stays free.
enum P {
    static func headline(_ reason: PaywallReason) -> String {
        switch reason {
        case .general:
            return L.t("背單字永遠免費。Premium 打開小笨貓的 AI 老師、掃描和考前衝刺。", "Studying words is always free. Premium opens Silly Cat's AI tutor, scanning and exam practice.")
        case .trialScansUsed:
            return L.t("試用期的 \(PlusPolicy.trialScanLimit) 次掃描已經用完，訂閱後就能無限掃描。", "You have used the \(PlusPolicy.trialScanLimit) trial scans. Subscribe for unlimited scanning.")
        case let .trialEnding(days):
            return L.t("試用剩 \(days) 天。現在訂閱，到期後也不會中斷。", "\(days) trial days left. Subscribe now and nothing stops when it ends.")
        case let .locked(feature):
            switch feature {
            case .scan: return L.t("掃描單字表和手寫筆記是 Premium 功能。", "Scanning word lists and handwriting is part of Premium.")
            case .sync: return L.t("用 Apple 登入就能同步進度。", "Sign in with Apple to sync your progress.")
            case .history: return L.t("看清楚自己這幾個月怎麼進步，哪些字一直忘。", "See how you have improved over months, and which words keep slipping.")
            case .examPractice: return L.t("考前用限時模擬測驗，找出還不熟的級別。", "Timed mock exams show which levels still need work.")
            case .smartAI: return L.t("口說教練、單字解說和學習分析，AI 都會先深入思考再回答，每天 \(PlusAI.plusDaily) 次。", "The AI thinks deeper before the speaking coach, word explanations and learning insights answer, \(PlusAI.plusDaily) times a day.")
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
    static var benefitSmartAI: String { L.t("深度思考 AI 老師", "A more thoughtful AI tutor") }
    static var benefitSmartAIDetail: String {
        L.t("聊天、單字解說、口說教練和學習分析，Claude 先深入思考再回答，每天 \(PlusAI.plusDaily) 次",
            "Chat, word explanations, the speaking coach and insights: Claude thinks before it answers, \(PlusAI.plusDaily) a day")
    }
    static var freeForever: String { L.t("背 7000 單字、複習、小測驗和口說練習永遠免費。用 Apple 登入就能保存並同步進度。", "Studying the core words, reviews, quizzes and speaking stay free. Sign in with Apple to keep and sync your progress.") }
    /// The paywall's button for a guest: signing in starts the trial.
    static var signInForTrial: String { L.t("用 Apple 登入並訂閱", "Sign in with Apple to subscribe") }
    static var guestNudgeText: String { L.t("訪客的進度不會保存。登入就能保存，訂閱 Premium 還有 AI 老師和掃描。", "Guests' progress isn't kept. Sign in to keep it; Premium adds the AI tutor and scanning.") }
    static var signInForTrialNote: String { L.t("Premium 綁定你的 Apple ID：換手機登入就會回來，進度也會一起同步。", "Premium belongs to your Apple ID: sign in on a new iPhone and it is there, with your progress.") }

    // Plans
    static var yearly: String { L.t("年費方案", "Yearly") }
    static var monthly: String { L.t("月費方案", "Monthly") }
    static var monthlyDetail: String { L.t("隨時可以取消", "Cancel anytime") }
    static func perMonth(_ price: String) -> String { L.t("每月只要 \(price)", "Just \(price) a month") }
    static var perYear: String { L.t("每年", "per year") }
    static var perMonthUnit: String { L.t("每月", "per month") }
    static func saveMonths(_ months: Int) -> String { L.t("省 \(months) 個月", "\(months) months free") }
    static func cta(_ plan: PlusPlan?) -> String {
        guard let plan else { return L.t("訂閱 Premium", "Subscribe") }
        if let days = plan.freeTrialDays { return L.t("免費試用 \(days) 天", "Try free for \(days) days") }
        return plan.yearly ? L.t("訂閱年費方案", "Subscribe yearly") : L.t("訂閱月費方案", "Subscribe monthly")
    }
    static func renewalTerms(_ plan: PlusPlan?) -> String {
        guard let plan else { return L.t("訂閱會自動續訂，可隨時在「設定」取消。", "Subscriptions renew automatically. Cancel anytime in Settings.") }
        if let days = plan.freeTrialDays {
            return plan.yearly
                ? L.t("免費試用 \(days) 天，之後每年 \(plan.displayPrice)，自動續訂。試用期間在「設定」取消就不收費。", "\(days) days free, then \(plan.displayPrice) a year, renewing automatically. Cancel in Settings during the trial and you pay nothing.")
                : L.t("免費試用 \(days) 天，之後每月 \(plan.displayPrice)，自動續訂。試用期間在「設定」取消就不收費。", "\(days) days free, then \(plan.displayPrice) a month, renewing automatically. Cancel in Settings during the trial and you pay nothing.")
        }
        return plan.yearly
            ? L.t("每年 \(plan.displayPrice)，自動續訂，可隨時在「設定」取消。", "\(plan.displayPrice) a year, renews automatically. Cancel anytime in Settings.")
            : L.t("每月 \(plan.displayPrice)，自動續訂，可隨時在「設定」取消。", "\(plan.displayPrice) a month, renews automatically. Cancel anytime in Settings.")
    }
    static var restore: String { L.t("恢復購買", "Restore") }
    static var terms: String { L.t("使用條款", "Terms") }
    static var retry: String { L.t("再試一次", "Try again") }
    static var plansUnavailable: String { L.t("目前無法載入訂閱方案，請稍後再試。", "Subscription plans are unavailable right now. Please try again shortly.") }
    static var pending: String { L.t("購買等待核准中（例如家長同意），核准後會自動解鎖。", "The purchase is waiting for approval, e.g. from a parent. Premium unlocks once approved.") }
    static var failed: String { L.t("目前無法確認購買結果。若已完成付款，請使用「恢復購買」或稍後再試。", "We could not confirm the purchase. If payment completed, restore purchases or try again shortly.") }
    static var restoreFailed: String { L.t("目前無法恢復購買，請稍後再試。", "Purchases could not be restored right now. Please try again shortly.") }
    static var nothingToRestore: String { L.t("這個 Apple 帳號沒有可恢復的訂閱。", "No subscription to restore for this Apple Account.") }

    // Welcome
    static var welcomeTitle: String { L.t("歡迎加入 Premium", "Welcome to Premium") }
    static var welcomeText: String { L.t("所有功能都解鎖了，謝謝你支持單字貓。", "Everything is unlocked. Thank you for supporting WordCat.") }
    static var welcomeStart: String { L.t("開始使用", "Get started") }

    // Me
    static var seePlans: String { L.t("查看方案", "See plans") }
    static var manage: String { L.t("管理訂閱", "Manage subscription") }
    static var upgradePlus: String { L.t("升級 Premium", "Upgrade to Premium") }
    static var unlockPlus: String { L.t("解鎖 Premium", "Unlock Premium") }
    static func priceFrom(_ price: String) -> String { L.t("每月 \(price) 起", "From \(price) a month") }
    static var memberTitle: String { L.t("Premium 會員", "Premium member") }
    static func memberDetail(planYearly: Bool, endsAt: Date?) -> String {
        let plan = planYearly ? yearly : monthly
        guard let endsAt else { return plan }
        let date = L.zh ? endsAt.formatted(date: .numeric, time: .omitted)
            : endsAt.formatted(.dateTime.month(.abbreviated).day().year().locale(Locale(identifier: "en_US")))
        return L.t("\(plan) · 本期到 \(date)", "\(plan) · period ends \(date)")
    }
    static var trialTitle: String { L.t("Premium 免費試用中", "Premium free trial") }
    static var trialDetail: String { L.t("所有功能都能用，試用結束前訂閱就不會中斷", "Everything is on. Subscribe before it ends to keep it all.") }
    static func trialDaysMeter(_ days: Int) -> String { L.t("試用剩 \(days) 天", "\(days) days left") }
    static func trialScansMeter(_ scans: Int) -> String { L.t("試用掃描剩 \(scans) / \(PlusPolicy.trialScanLimit) 次", "\(scans) of \(PlusPolicy.trialScanLimit) trial scans left") }
    static var statusExpired: String { L.t("試用已結束，背單字仍可免費使用", "Trial ended. Studying stays free.") }
    static var syncLocked: String { L.t("訪客：進度不會保存，登入就能保存", "Guest: progress isn't kept; sign in to keep it") }
    static var plusBadge: String { "Premium" }
    static var lockedLabel: String { L.t("需要 Premium", "Needs Premium") }

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
        case let .trialEnding(days): L.t("Premium 試用剩 \(days) 天", "\(days) Premium trial days left")
        case .trialEnded: plusPitch.title
        }
    }
    static func nudgeText(_ nudge: PlusPolicy.Nudge) -> String {
        switch nudge {
        case .scansUsedUp, .lastScan: L.t("訂閱 Premium 就能無限掃描單字表和手寫筆記。", "Premium scans word lists and handwriting without limits.")
        case .trialEnding: L.t("到期後 AI、掃描和考前衝刺會鎖起來。", "When it ends, the AI, scanning and exam practice lock.")
        case .trialEnded: plusPitch.text
        }
    }

    /// Today's reason to try Plus: one benefit a day, in turn, so the
    /// reminder says something new each time.
    static var plusPitch: (title: String, text: String) {
        let pitches: [(String, String)] = [
            (L.t("讓小笨貓當你的 AI 老師", "Make Silly Cat your AI tutor"),
             L.t("卡住的字直接問：用法、例句、跟哪個字搞混，Premium 每天 \(PlusAI.plusDaily) 次。", "Ask about any word: usage, examples, what it gets mixed up with. \(PlusAI.plusDaily) a day with Premium.")),
            (L.t("課本單字表，拍一下就變字庫", "Snap a word list into a bank"),
             L.t("講義、手寫筆記都讀得懂，還幫你補詞性和翻譯。", "Handouts and handwriting too, with parts of speech and meanings filled in.")),
            (L.t("AI 口說教練幫你改句子", "An AI coach for your speaking"),
             L.t("說完一題，它幫你改得更自然，再追問一題讓你多練。", "Answer a prompt and it makes it sound natural, then asks a follow-up.")),
            (L.t("考前來場 15 分鐘模擬考", "A 15-minute mock exam"),
             L.t("交卷就知道哪一級還不熟，對症下藥。", "Hand it in and see which level still needs work.")),
            (L.t("看清楚自己進步多少", "See how far you've come"),
             L.t("30、90 天趨勢和一直忘的字，Premium 都幫你記著。", "30- and 90-day trends and the words you keep forgetting.")),
        ]
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return pitches[day % pitches.count]
    }

    // Locked previews
    static func lockedTitle(_ feature: PlusFeature) -> String {
        switch feature {
        case .history: L.t("完整學習紀錄是 Premium 功能", "Full history is part of Premium")
        case .examPractice: L.t("考前衝刺是 Premium 功能", "Exam practice is part of Premium")
        case .scan: L.t("掃描是 Premium 功能", "Scanning is part of Premium")
        case .sync: L.t("登入後就能同步", "Sign in to sync")
        case .smartAI: L.t("深度思考 AI 是 Premium 功能", "Deeper AI reasoning is part of Premium")
        }
    }
    static func lockedText(_ feature: PlusFeature) -> String {
        switch feature {
        case .history: L.t("你的紀錄一直都有保存，解鎖就能看 30、90 天的趨勢和弱點單字。", "Your history is kept. Unlock it to see 30- and 90-day trends and weak words.")
        case .examPractice: benefitExamDetail
        case .scan: benefitScanDetail
        case .sync: benefitSyncDetail
        case .smartAI: benefitSmartAIDetail
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
        [L.t("背 7000 單字與複習", "Studying and reviews"), L.t("小測驗和口說練習", "Quizzes and speaking"),
         L.t("登入後保存並同步進度", "Keeping and syncing progress when signed in"), L.t("最近 7 天的統計", "The last 7 days of stats")]
    }
    static var recapPlusTitle: String { L.t("訂閱 Premium 繼續使用", "Keep these with Premium") }
    static var recapLater: String { L.t("先繼續免費使用", "Continue for free") }

    // Scan
    static func scansLeft(_ scans: Int) -> String { L.t("試用還能掃描 \(scans) 次", "\(scans) trial scans left") }
}
