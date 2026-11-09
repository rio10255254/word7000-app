import Foundation
import Word7000Core

/// What the learner is learning. `english` (the default) is the Chinese
/// interface for learning English words; `chinese` flips it: an English
/// interface for learning the Chinese meanings. Each keeps its own word
/// progress (`ModeProgress`); the streak and daily goal are shared.
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
    static func todayPlan(due: Int, fresh: Int) -> String {
        // A half that is zero is left out ("20 個新字", not "0 個待複習 · 20 個新字").
        if due == 0, fresh == 0 { return t("這個範圍沒有要學的字", "Nothing to study in this range") }
        if due == 0 { return t("\(fresh) 個新字", "\(fresh) new") }
        if fresh == 0 { return t("\(due) 個待複習", "\(due) to review") }
        return t("\(due) 個待複習 · \(fresh) 個新字", "\(due) to review · \(fresh) new")
    }
    static func streakDays(_ days: Int) -> String { "\(days)" }
    static var practice: String { t("練習", "Practice") }
    static var quickQuiz: String { t("看字選意思", "Pick the meaning") }
    static var quizLength: String { t("10 題", "10 questions") }
    static var practiceStruggling: String { t("複習不熟的字", "Review tricky words") }
    static var speaking: String { t("口說練習", "Speaking practice") }
    static var spelling: String { t("拼字練習", "Writing") }
    static func studyingBank(_ name: String) -> String { t("字庫：\(name)", "Word bank: \(name)") }

    // Study
    static var close: String { t("關閉", "Close") }
    static func cardCount(done: Int, total: Int) -> String { "\(min(done + 1, total)) / \(total)" }
    static var showAnswer: String { t("看答案", "Show answer") }
    static var tapToReveal: String { t("點一下看答案", "Tap to see the answer") }
    // The answer is Chinese when learning English and English when learning Chinese.
    static var autoReveal: String { t("直接顯示中文", "Show English right away") }
    static var showPinyin: String { t("顯示拼音", "Show pinyin") }
    static var showPinyinHint: String { t("關掉後，拼音跟答案一起出現，先練認字", "When off, the pinyin comes with the answer, so you read the characters first") }
    static var autoRevealHint: String { t("卡片直接顯示中文，不用先點一下", "Cards show the English without a tap first") }
    static var dontKnow: String { t("不熟", "Not yet") }
    static var knowIt: String { t("認識", "Know it") }
    static var undo: String { t("復原上一張", "Undo") }
    /// Undoes something other than a card (a deleted bank).
    static var undoPlain: String { t("復原", "Undo") }
    static var sessionCompleteTitle: String { t("這一組完成了", "Set complete") }
    static func sessionCompleteText(known: Int, review: Int) -> String { t("認識 \(known) 個 · 不熟 \(review) 個", "Knew \(known) · Not yet \(review)") }
    static var sessionGoalDone: String { t("今天的目標已達成", "Today's goal reached") }
    static var goalReachedTitle: String { t("今天的目標達成了！", "You reached today's goal!") }
    static var goalReachedBanner: String { t("今天的目標達成了", "Today's goal reached") }
    static var quizTodaysWordsHint: String { t("趁記憶還新鮮，選選看今天這些字的意思。", "While they are fresh, pick the meanings of today's words.") }
    static var quizTodaysWords: String { t("複習今天的字", "Review today's words") }
    static func sessionGoalLeft(_ left: Int) -> String { t("今天還差 \(left) 個", "\(left) more for today") }
    static var done: String { t("完成", "Done") }
    /// An English line after the learner's name ("Alex, not bad."), or
    /// capitalised when there is no name ("Not bad.").
    static func named(_ call: String, _ line: String) -> String {
        guard call.isEmpty, let first = line.first else { return call + line }
        return first.uppercased() + line.dropFirst()
    }
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
    static func quizMissedHint(_ count: Int) -> String {
        t("答錯的 \(count) 個字已經放進複習。", count == 1 ? "The missed word was added to review." : "The \(count) missed words were added to review.")
    }
    static func practiceMissed(_ count: Int) -> String {
        t("複習答錯的 \(count) 個字", count == 1 ? "Review the missed word" : "Review the \(count) missed words")
    }
    static var anotherQuiz: String { t("再測一次", "Quiz again") }

    // Speaking
    static var speakingPrompt: String { t("用英文回答", "Answer in Chinese") }
    static var spokeIt: String { t("我說完了", "I answered") }
    static var showSample: String { t("看參考回答", "Sample answer") }
    static var sampleAnswer: String { t("參考回答", "Sample answer") }
    static var speakingFinished: String { t("口說練習完成", "Speaking practice complete") }
    static func speakingScore(_ count: Int) -> String { t("完成 \(count) 張口說卡", "\(count) prompts answered") }

    // Words
    static var searchPlaceholder: String { t("搜尋英文、中文或例句", "Search Chinese, pinyin, English or examples") }
    /// Taiwanese learners know the GSAT's 7000 words by that name; learners of
    /// Chinese study their own bank of everyday Taiwan Mandarin.
    static var coreBankName: String { t("7000 單字", "Taiwan Mandarin") }
    /// The word list files its levels as "Core 1"…"Core 14"; on screen they
    /// are 第 N 章 or Level N (WordCat Next: chapters, as on Today and in the
    /// level test). Other groups (a scanned bank's) show as they are.
    static func level(_ number: Int) -> String { t("第 \(number) 章", "Chapter \(number) · \(tocflBand(number))") }
    /// Learners of Chinese study the Taiwan Mandarin bank, whose fourteen
    /// levels spread over TOCFL's bands (see scripts/build-taiwan-words.py).
    static func tocflBand(_ level: Int) -> String {
        switch level {
        case ...5: "Novice"
        case 6...7: "A1"
        case 8...10: "A2"
        default: "B1"
        }
    }
    static func levelRange(_ low: Int, _ high: Int) -> String {
        low == high ? level(low) : t("第 \(low)–\(high) 章", "Chapters \(low)–\(high)")
    }
    /// The level filter in a few words: all, one level, a run, or a short list.
    static func levelSummary(_ groups: [String]) -> String {
        guard !groups.isEmpty else { return allLevels }
        if groups.count == 1 { return levelName(groups[0]) }
        let numbers = groups.compactMap(LearningEngine.coreLevel)
        if numbers.count == groups.count, let low = numbers.min(), let high = numbers.max(), high - low + 1 == numbers.count {
            return levelRange(low, high)
        }
        if numbers.count == groups.count, numbers.count <= 4 {
            return t("第 \(numbers.map(String.init).joined(separator: "、")) 章", "Chapters \(numbers.map(String.init).joined(separator: ", "))")
        }
        return t("\(groups.count) 個章節", "\(groups.count) chapters")
    }
    static func levelName(_ group: String) -> String {
        guard group.hasPrefix("Core "), let number = Int(group.dropFirst(5)) else { return group }
        return level(number)
    }
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
    static var filterLevel: String { t("章節", "Chapter") }
    static var filterSort: String { t("排序", "Sort") }
    static var sortDefault: String { t("原本順序", "Original order") }
    static var sortAlphabetical: String { t("A 到 Z", "A to Z") }
    static var allLevels: String { t("全部章節", "All chapters") }
    static var favoriteWord: String { t("收藏", "Save") }
    static var unfavoriteWord: String { t("取消收藏", "Unsave") }
    static var pronounce: String { t("發音", "Pronounce") }
    static var meaning: String { t("意思", "Meaning") }
    static var example: String { t("例句", "Example") }
    static var status: String { t("狀態", "Status") }
    static var nextReviewTitle: String { t("下次複習", "Next review") }
    static var level: String { t("章節", "Chapter") }

    // Me
    static var streak: String { t("連續天數", "Day streak") }
    static var mastered: String { t("已會", "Known") }
    static var reviewing: String { t("還不熟", "Still learning") }
    static var thisWeek: String { t("這 7 天", "Last 7 days") }
    static func quizAccuracy(_ percent: Int, correct: Int, total: Int) -> String {
        t("近 7 天答對率 \(percent)%（\(correct)/\(total) 題）", "Last 7 days: \(percent)% right (\(correct) of \(total))")
    }
    static var settings: String { t("設定", "Settings") }
    static var studyModeTitle: String { t("學習內容", "Learning") }
    static func studyModeLabel(_ mode: StudyMode) -> String {
        switch mode {
        case .english: "學英文（中文介面）"
        case .chinese: "Learn Chinese (English)"
        }
    }
    static var dailyTargetTitle: String { t("每日目標", "Daily goal") }
    static var dailyTargetText: String { t("每日目標也是每組卡片的張數。", "The daily goal is also the size of each set.") }
    static func wordsPerDay(_ count: Int) -> String { t("\(count) 個", "\(count) words") }
    static var reminder: String { t("學習提醒", "Study reminder") }
    static var reminderText: String { t("每天提醒一次；連續天數快斷時，鎖定畫面會倒數。", "One reminder a day; the lock screen counts down before your streak ends.") }
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
        case .review: t("還不熟", "Still learning")
        case .mastered: t("已會", "Known")
        case .new: t("新字", "New")
        }
    }

    static func statusLabel(_ status: WordStatus) -> String {
        switch status {
        case .new: t("新字", "New")
        case .review: t("還不熟", "Still learning")
        case .mastered: t("已會", "Known")
        }
    }
}
