import Foundation
import Word7000Core

/// Plus copy, in both interface languages. Honest about what stays free.
enum P {
    static func headline(_ reason: PaywallReason) -> String {
        switch reason {
        case .general:
            return L.t("背單字永遠免費。Premium 再加上傻貓 AI 老師、掃描和模擬考。", "Studying words is always free. Premium adds Silly Cat's AI tutor, scanning and mock exams.")
        case .trialScansUsed:
            return L.t("試用期的 \(PlusPolicy.trialScanLimit) 次掃描已經用完，訂閱後就能無限掃描。", "You have used the \(PlusPolicy.trialScanLimit) trial scans. Subscribe for unlimited scanning.")
        case .speakingCoach:
            return L.t("訂閱 Premium，傻貓就能批改你的口說：改成更自然的說法、指出錯誤，再追問一題。不需要 Apple Intelligence，任何 iPhone 都能用。",
                       "With Premium, Silly Cat checks your speaking: a more natural version, what to fix, and a follow-up question. No Apple Intelligence needed; it works on any iPhone.")
        case let .officialBank(name):
            return L.t("「\(name)」是 Premium 字庫。訂閱後所有官方字庫都能學，之後上架的新字庫也一樣。",
                       "\u{201C}\(name)\u{201D} is a Premium word bank. Subscribe to study every official bank, including new ones as they arrive.")
        case let .trialEnding(days):
            return L.t("試用剩 \(days) 天。現在訂閱，到期後也不會中斷。", days == 1 ? "1 trial day left. Subscribe now and nothing stops when it ends." : "\(days) trial days left. Subscribe now and nothing stops when it ends.")
        case let .locked(feature):
            switch feature {
            case .scan: return L.t("掃描單字表和手寫筆記是 Premium 功能。", "Scanning word lists and handwriting is part of Premium.")
            case .sync: return L.t("用 Apple 登入就能同步進度。", "Sign in with Apple to sync your progress.")
            case .history: return L.t("看清楚自己這幾個月怎麼進步，哪些字一直忘。", "See how you have improved over months, and which words keep slipping.")
            case .examPractice: return L.t("考前來一場限時模擬考，找出還不熟的章。", "A timed mock exam shows which chapters still need work.")
            case .smartAI: return L.t("口說教練、單字解說和學習分析，AI 都會先深入思考再回答，每天 \(PlusAI.plusDaily) 次。", "The AI thinks deeper before the speaking coach, word explanations and learning insights answer, \(PlusAI.plusDaily) times a day.")
            }
        }
    }

    /// The learner's own progress, so the paywall talks about them.
    static func progressLine(mastered: Int, streak: Int) -> String? {
        guard mastered > 0 else { return nil }
        if streak > 1 { return L.t("你已經會 \(mastered) 個字，連續 \(streak) 天", "\(mastered) words known · \(streak)-day streak") }
        return L.t("你已經會 \(mastered) 個字", "\(mastered) words known so far")
    }

    static var benefitScan: String { L.t("無限掃描", "Unlimited scanning") }
    static var benefitScanDetail: String { L.t("單字表、講義、手寫筆記，拍一下就變成字庫", "Word lists, handouts and handwriting become a bank in one photo") }
    static var benefitSync: String { L.t("雲端同步", "Cloud sync") }
    static var benefitSyncDetail: String { L.t("換手機、重灌 App，進度都還在", "Change iPhones or reinstall and your progress is still there") }
    static var benefitHistory: String { L.t("完整學習紀錄", "Full learning history") }
    static var benefitHistoryDetail: String { L.t("30、90 天的學習趨勢和最常忘記的字", "30- and 90-day trends and the words you forget most") }
    static var benefitExam: String { L.t("限時模擬考", "Timed mock exams") }
    static var benefitExamDetail: String { L.t("50 題限時 15 分鐘，交卷看每一章的分數", "50 questions in 15 minutes, scored by chapter") }
    static var benefitSmartAI: String { L.t("深度思考 AI 老師", "A more thoughtful AI tutor") }
    static var benefitSmartAIDetail: String {
        L.t("聊天、單字解說、口說教練和學習分析，Claude 先深入思考再回答，每天 \(PlusAI.plusDaily) 次",
            "Chat, word explanations, the speaking coach and insights: Claude thinks before it answers, \(PlusAI.plusDaily) a day")
    }
    static var whyTitle: String { L.t("為什麼 Premium 要收費？", "Why does Premium cost money?") }
    static var whyBody: String {
        L.t("單字貓是獨立開發的小 App。背單字、複習、測驗都免費，也沒有廣告；但傻貓的 AI 老師每回答一次，都要付費給 AI 服務商。Premium 的費用就是用來支付這些成本，讓單字貓能一直更新下去。謝謝你的支持！",
            "WordCat is a small, independent app. Studying, reviews and quizzes are free, with no ads. But every answer from Silly Cat's AI tutor costs real money with the AI provider. Premium pays for that, and keeps WordCat improving. Thank you for your support!")
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
    static func saveMonths(_ months: Int) -> String { L.t("最划算 · 省 \(months) 個月", "Best value · \(months) months free") }
    static func perMonthAndDay(_ month: String, _ day: String) -> String { L.t("每月 \(month) · 每天只要 \(day)", "\(month) a month · just \(day) a day") }
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

    // Trial timeline
    static var timelineToday: String { L.t("今天", "Today") }
    static var timelineTodayDetail: String { L.t("AI 老師、掃描、模擬考、完整紀錄全部解鎖", "The AI tutor, scanning, mock exams and full history unlock") }
    static func timelineBefore(_ days: Int) -> String { L.t("第 \(max(1, days - 1)) 天", "Day \(max(1, days - 1))") }
    static var timelineBeforeDetail: String { L.t("試用快結束；不想續用，在「設定」取消就好", "The trial is nearly over; cancel in Settings if it's not for you") }
    static func timelineCharge(_ days: Int) -> String { L.t("第 \(days) 天", "Day \(days)") }
    static func timelineChargeDetail(_ price: String, yearly: Bool) -> String {
        yearly ? L.t("才開始收費 \(price)／年，之前取消不收任何錢", "The first charge, \(price) a year; nothing if cancelled before")
               : L.t("才開始收費 \(price)／月，之前取消不收任何錢", "The first charge, \(price) a month; nothing if cancelled before")
    }
    static func examCountdown(_ days: Int) -> String {
        L.t("離考試只剩 \(days) 天 · 模擬考找出最弱的章", days == 1 ? "1 day to the exam · find your weakest chapter" : "\(days) days to the exam · find your weakest chapter")
    }

    // The cat's goodbye, once a day, when the paywall is closed unbought
    static var goodbyeTitle: String { L.t("真的要走？", "Leaving already?") }
    static func goodbyeText(mastered: Int, trialDays: Int?) -> String {
        let trial = trialDays.map { L.t("前 \($0) 天免費，隨時可以取消。", "The first \($0) days are free; cancel anytime.") } ?? ""
        return mastered > 0
            ? L.t("你都已經會 \(mastered) 個字了，就差一個 AI 老師。\(trial)沒關係，我習慣被拋棄了。",
                  "You already know \(mastered) words; all you're missing is an AI tutor. \(trial)It's fine. I'm used to being left.")
            : L.t("我的 AI 腦袋就在這裡，你卻要走。\(trial)沒關係，我習慣被拋棄了。",
                  "My AI brain is right here and you're leaving. \(trial)It's fine. I'm used to being left.")
    }
    static var goodbyeStay: String { L.t("再看看", "Stay a bit") }
    static var goodbyeLeave: String { L.t("狠心離開", "Leave anyway") }

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
        case let .trialEnding(days): L.t("Premium 試用剩 \(days) 天", days == 1 ? "1 Premium trial day left" : "\(days) Premium trial days left")
        case .trialEnded: plusPitch.title
        }
    }
    static func nudgeText(_ nudge: PlusPolicy.Nudge) -> String {
        switch nudge {
        case .scansUsedUp, .lastScan: L.t("訂閱 Premium 就能無限掃描單字表和手寫筆記。", "Premium scans word lists and handwriting without limits.")
        case .trialEnding: L.t("到期後 AI 老師、掃描和模擬考都會鎖起來，你又要一個人背了。", "When it ends, the AI tutor, scanning and mock exams lock, and you're on your own again.")
        case .trialEnded: plusPitch.text
        }
    }

    /// Today's reason to try Plus: one benefit a day, in turn, so the
    /// reminder says something new each time.
    static var plusPitch: (title: String, text: String) {
        // In the cat's own voice: what it could do for you, if only you let it.
        let pitches: [(String, String)] = [
            (L.t("我可以當你的家教，只是你沒請", "I could be your tutor. You just never asked."),
             L.t("卡住的字直接問我：用法、例句、跟哪個字搞混。Premium 每天 \(PlusAI.plusDaily) 次。", "Ask me about any word: usage, examples, what it gets mixed up with. \(PlusAI.plusDaily) a day with Premium.")),
            (L.t("講義拍一下就變字庫，你還在手打？", "Still typing your word lists by hand?"),
             L.t("手寫筆記也讀得懂，詞性和翻譯我幫你補好。", "Snap a handout, handwriting too; I fill in parts of speech and meanings.")),
            (L.t("你的口說，我想改很久了", "I've been dying to fix your speaking."),
             L.t("AI 口說教練把你的句子改自然，再追問一題逼你多講。", "The AI coach makes your answer sound natural, then pushes you with a follow-up.")),
            (L.t("考前不模擬，考場見真章", "No mock exam? See you in the exam hall."),
             L.t("15 分鐘 50 題，交卷就知道哪一章最弱。", "50 questions in 15 minutes, and you'll know your weakest chapter.")),
            (L.t("你到底有沒有進步？我都有記", "Are you even improving? I've kept count."),
             L.t("30、90 天趨勢和你一直忘的字，Premium 才看得到。", "30- and 90-day trends and the words you keep forgetting, with Premium.")),
        ]
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return pitches[day % pitches.count]
    }

    // Locked previews
    static func lockedTitle(_ feature: PlusFeature) -> String {
        switch feature {
        case .history: L.t("完整學習紀錄是 Premium 功能", "Full history is part of Premium")
        case .examPractice: L.t("模擬考是 Premium 功能", "Mock exams are part of Premium")
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
        [L.t("背 7000 單字與複習", "Studying and reviews"), L.t("測驗和口說練習", "Quizzes and speaking"),
         L.t("登入後保存並同步進度", "Keeping and syncing progress when signed in"), L.t("最近 7 天的統計", "The last 7 days of stats")]
    }
    static var recapPlusTitle: String { L.t("訂閱 Premium 繼續使用", "Keep these with Premium") }
    static var recapLater: String { L.t("先繼續免費使用", "Continue for free") }

    // Scan
    static func scansLeft(_ scans: Int) -> String { L.t("試用還能掃描 \(scans) 次", "\(scans) trial scans left") }
}
