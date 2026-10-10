import Foundation
import Word7000Core

/// Interface copy for the English-word mode (Chinese interface). Short on
/// purpose: a label says what a control does, nothing more.
enum L {
    // Tabs
    static let tabToday = "今天"
    static let tabWords = "單字"
    static let tabMe = "我"

    // Today
    static func ofTarget(_ target: Int) -> String { "/ \(target) 個" }
    static let goalTitle = "今天的單字"
    static let goalDoneTitle = "今天的目標完成了"
    static let primaryAction = "開始學習"
    static let continueAction = "繼續學習"
    static let extraAction = "再學一組"
    static func todayPlan(due: Int, fresh: Int) -> String { "\(due) 個待複習 · \(fresh) 個新字" }
    static func streakDays(_ days: Int) -> String { "\(days)" }
    static let practice = "練習"
    static let quickQuiz = "小測驗"
    static let quizLength = "10 題"
    static let practiceStruggling = "複習不熟的字"
    static func studyingBank(_ name: String) -> String { "字庫：\(name)" }

    // Study
    static let close = "關閉"
    static func cardCount(done: Int, total: Int) -> String { "\(min(done + 1, total)) / \(total)" }
    static let showAnswer = "看答案"
    static let tapToReveal = "點一下看答案"
    static let dontKnow = "不熟"
    static let knowIt = "認識"
    static let undo = "復原上一張"
    static let sessionCompleteTitle = "這一組完成了"
    static func sessionCompleteText(known: Int, review: Int) -> String { "認識 \(known) 個 · 不熟 \(review) 個" }
    static let sessionGoalDone = "今天的目標已達成"
    static func sessionGoalLeft(_ left: Int) -> String { "今天還差 \(left) 個" }
    static let done = "完成"
    static let nextSession = "再一組"
    static let nothingToStudy = "目前沒有要學的字"
    static let nothingToStudyText = "這個字庫都學完了，可以換一個字庫。"

    // Quiz
    static let noQuizWords = "這個字庫還沒有單字"
    static let nextQuestion = "下一題"
    static let seeResults = "看結果"
    static let quizFinished = "測驗完成"
    static let quizPerfect = "全部答對！"
    static func quizMissedHint(_ count: Int) -> String { "答錯的 \(count) 個字已經放進複習。" }
    static func practiceMissed(_ count: Int) -> String { "複習答錯的 \(count) 個字" }
    static let anotherQuiz = "再測一次"

    // Words
    static let searchPlaceholder = "搜尋英文、中文或例句"
    static let coreBankName = "7000 單字"
    static func bankWordCount(_ count: Int) -> String { "\(count) 個" }
    static let scanSheet = "掃描單字表"
    static let renameBank = "重新命名"
    static let deleteBank = "刪除字庫"
    static let bankName = "字庫名稱"
    static let cancel = "取消"
    static let save = "儲存"
    static let closeSheet = "關閉"
    static let noLibraryWords = "沒有符合的單字"
    static let filters = "篩選"
    static let filterStatus = "狀態"
    static let filterLevel = "分級"
    static let filterSort = "排序"
    static let sortDefault = "原本順序"
    static let sortAlphabetical = "A 到 Z"
    static let allLevels = "全部分級"
    static let favoriteWord = "收藏"
    static let unfavoriteWord = "取消收藏"
    static let pronounce = "發音"
    static let meaning = "意思"
    static let example = "例句"
    static let status = "狀態"
    static let nextReviewTitle = "下次複習"
    static let level = "分級"

    // Me
    static let streak = "連續天數"
    static let mastered = "已會"
    static let reviewing = "複習中"
    static let thisWeek = "這 7 天"
    static func quizAccuracy(_ percent: Int) -> String { "測驗答對率 \(percent)%" }
    static let settings = "設定"
    static let dailyTargetTitle = "每日目標"
    static let dailyTargetText = "每天想學幾個字，也是每組學習卡的張數。"
    static func wordsPerDay(_ count: Int) -> String { "\(count) 個" }
    static let appearance = "外觀"
    static let themeSystem = "自動"
    static let themeLight = "淺色"
    static let themeDark = "深色"
    static let account = "帳號"
    static let accountComing = "登入與雲端同步即將推出。進度目前保存在這支 iPhone。"
    static let privacyPolicy = "隱私權政策"
    static let supportPage = "支援"
    static let version = "版本"

    static func filterLabel(_ filter: LibraryFilter) -> String {
        switch filter {
        case .all: "全部"
        case .favorites: "收藏"
        case .review: "複習中"
        case .mastered: "已會"
        case .new: "未學"
        }
    }

    static func statusLabel(_ status: WordStatus) -> String {
        switch status {
        case .new: "未學"
        case .review: "複習中"
        case .mastered: "已會"
        }
    }
}
