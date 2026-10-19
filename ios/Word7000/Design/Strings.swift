import Foundation
import Word7000Core

/// What the learner is learning. `english` (the default) is the Chinese
/// interface for learning English words; `chinese` flips it: an English
/// interface for learning the Chinese meanings. One progress record serves
/// both, so knowing a word in either direction counts.
enum StudyMode: String, Codable, CaseIterable, Identifiable {
    case english, chinese

    var id: String { rawValue }
}

/// Interface copy. Short on purpose: a label says what a control does.
/// Every string has the Chinese (learning English) and English (learning
/// Chinese) wording side by side.
enum L {
    /// Set by the app model whenever the study mode changes.
    nonisolated(unsafe) static var mode: StudyMode = .english

    static var zh: Bool { mode == .english }
    static func t(_ zh: String, _ en: String) -> String { Self.zh ? zh : en }

    // Tabs
    static var tabToday: String { t("今天", "Today") }
    static var tabWords: String { t("單字", "Words") }
    static var tabMe: String { t("我", "Me") }

    // Today
    static func ofTarget(_ target: Int) -> String { t("/ \(target) 個", "of \(target)") }
    static var goalTitle: String { t("今天的單字", "Today's words") }
    static var goalDoneTitle: String { t("今天的目標完成了", "Today's goal is done") }
    static var primaryAction: String { t("開始學習", "Start") }
    static var continueAction: String { t("繼續學習", "Continue") }
    static var extraAction: String { t("再學一組", "One more set") }
    static func todayPlan(due: Int, fresh: Int) -> String { t("\(due) 個待複習 · \(fresh) 個新字", "\(due) to review · \(fresh) new") }
    static func streakDays(_ days: Int) -> String { "\(days)" }
    static var practice: String { t("練習", "Practice") }
    static var quickQuiz: String { t("小測驗", "Quick quiz") }
    static var quizLength: String { t("10 題", "10 questions") }
    static var practiceStruggling: String { t("複習不熟的字", "Review tricky words") }
    static var speaking: String { t("口說練習", "Speaking practice") }
    static func studyingBank(_ name: String) -> String { t("字庫：\(name)", "Word bank: \(name)") }

    // Study
    static var close: String { t("關閉", "Close") }
    static func cardCount(done: Int, total: Int) -> String { "\(min(done + 1, total)) / \(total)" }
    static var showAnswer: String { t("看答案", "Show answer") }
    static var tapToReveal: String { t("點一下看答案", "Tap to see the answer") }
    static var dontKnow: String { t("不熟", "Not yet") }
    static var knowIt: String { t("認識", "Know it") }
    static var undo: String { t("復原上一張", "Undo") }
    static var sessionCompleteTitle: String { t("這一組完成了", "Set complete") }
    static func sessionCompleteText(known: Int, review: Int) -> String { t("認識 \(known) 個 · 不熟 \(review) 個", "Knew \(known) · Not yet \(review)") }
    static var sessionGoalDone: String { t("今天的目標已達成", "Today's goal reached") }
    static func sessionGoalLeft(_ left: Int) -> String { t("今天還差 \(left) 個", "\(left) more for today") }
    static var done: String { t("完成", "Done") }
    static var nextSession: String { t("再一組", "Another set") }
    static var nothingToStudy: String { t("目前沒有要學的字", "Nothing to study") }
    static var nothingToStudyText: String { t("這個字庫都學完了，可以換一個字庫。", "You have finished this bank. Pick another one.") }
    static var englishWord: String { t("英文", "English") }

    // Quiz
    static var noQuizWords: String { t("這個字庫還沒有單字", "This bank has no words yet") }
    static var nextQuestion: String { t("下一題", "Next") }
    static var seeResults: String { t("看結果", "See results") }
    static var quizFinished: String { t("測驗完成", "Quiz complete") }
    static var quizPerfect: String { t("全部答對！", "All correct!") }
    static func quizMissedHint(_ count: Int) -> String { t("答錯的 \(count) 個字已經放進複習。", "The \(count) missed words were added to review.") }
    static func practiceMissed(_ count: Int) -> String { t("複習答錯的 \(count) 個字", "Review the \(count) missed words") }
    static var anotherQuiz: String { t("再測一次", "Quiz again") }

    // Speaking
    static var speakingPrompt: String { t("用英文回答", "Answer in Chinese") }
    static var spokeIt: String { t("我說完了", "I answered") }
    static var showSample: String { t("看參考回答", "Sample answer") }
    static var sampleAnswer: String { t("參考回答", "Sample answer") }
    static var speakingFinished: String { t("口說練習完成", "Speaking practice complete") }
    static func speakingScore(_ count: Int) -> String { t("完成 \(count) 張口說卡", "\(count) prompts answered") }

    // Words
    static var searchPlaceholder: String { t("搜尋英文、中文或例句", "Search English, Chinese or examples") }
    static var coreBankName: String { t("7000 單字", "7000 Words") }
    static func bankWordCount(_ count: Int) -> String { t("\(count) 個", "\(count)") }
    static var scanSheet: String { t("掃描單字表", "Scan a word list") }
    static var newBank: String { t("新字庫", "New bank") }
    static var newBankDefault: String { t("我的字庫", "My words") }
    static var renameBank: String { t("重新命名", "Rename") }
    static var deleteBank: String { t("刪除字庫", "Delete bank") }
    static var bankName: String { t("字庫名稱", "Bank name") }
    static var addToBank: String { t("加入字庫", "Add to bank") }
    static var removeFromBank: String { t("從這個字庫移除", "Remove from this bank") }
    static var addWord: String { t("新增單字", "Add a word") }
    static var cancel: String { t("取消", "Cancel") }
    static var save: String { t("儲存", "Save") }
    static var closeSheet: String { t("關閉", "Close") }
    static var noLibraryWords: String { t("沒有符合的單字", "No matching words") }
    static var filters: String { t("篩選", "Filter") }
    static var filterStatus: String { t("狀態", "Status") }
    static var filterLevel: String { t("分級", "Level") }
    static var filterSort: String { t("排序", "Sort") }
    static var sortDefault: String { t("原本順序", "Original order") }
    static var sortAlphabetical: String { t("A 到 Z", "A to Z") }
    static var allLevels: String { t("全部分級", "All levels") }
    static var favoriteWord: String { t("收藏", "Save") }
    static var unfavoriteWord: String { t("取消收藏", "Unsave") }
    static var pronounce: String { t("發音", "Pronounce") }
    static var meaning: String { t("意思", "Meaning") }
    static var example: String { t("例句", "Example") }
    static var status: String { t("狀態", "Status") }
    static var nextReviewTitle: String { t("下次複習", "Next review") }
    static var level: String { t("分級", "Level") }

    // Me
    static var streak: String { t("連續天數", "Day streak") }
    static var mastered: String { t("已會", "Known") }
    static var reviewing: String { t("複習中", "Reviewing") }
    static var thisWeek: String { t("這 7 天", "Last 7 days") }
    static func quizAccuracy(_ percent: Int) -> String { t("測驗答對率 \(percent)%", "Quiz accuracy \(percent)%") }
    static var settings: String { t("設定", "Settings") }
    static var studyModeTitle: String { t("學習內容", "Learning") }
    static func studyModeLabel(_ mode: StudyMode) -> String {
        switch mode {
        case .english: "學英文（中文介面）"
        case .chinese: "Learn Chinese (English)"
        }
    }
    static var dailyTargetTitle: String { t("每日目標", "Daily goal") }
    static var dailyTargetText: String { t("每天想學幾個字，也是每組學習卡的張數。", "How many words a day; also the size of each set.") }
    static func wordsPerDay(_ count: Int) -> String { t("\(count) 個", "\(count) words") }
    static var reminder: String { t("學習提醒", "Study reminder") }
    static var reminderText: String { t("每天中午提醒；連續天數快中斷時，鎖定畫面會倒數。", "A reminder at noon, and a lock screen countdown before a streak ends.") }
    static var appearance: String { t("外觀", "Appearance") }
    static var themeSystem: String { t("自動", "Automatic") }
    static var themeLight: String { t("淺色", "Light") }
    static var themeDark: String { t("深色", "Dark") }
    static var account: String { t("帳號", "Account") }
    static var privacyPolicy: String { t("隱私權政策", "Privacy Policy") }
    static var supportPage: String { t("支援", "Support") }
    static var version: String { t("版本", "Version") }

    static func filterLabel(_ filter: LibraryFilter) -> String {
        switch filter {
        case .all: t("全部", "All")
        case .favorites: t("收藏", "Saved")
        case .review: t("複習中", "Reviewing")
        case .mastered: t("已會", "Known")
        case .new: t("未學", "New")
        }
    }

    static func statusLabel(_ status: WordStatus) -> String {
        switch status {
        case .new: t("未學", "New")
        case .review: t("複習中", "Reviewing")
        case .mastered: t("已會", "Known")
        }
    }
}
