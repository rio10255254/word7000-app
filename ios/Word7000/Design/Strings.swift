import Foundation
import Word7000Core

/// Interface copy for the English-word mode (Chinese interface). Wording
/// follows the React Native app so returning learners see familiar labels.
enum L {
    static let tabHome = "首頁"
    static let tabStudy = "學習"
    static let tabQuiz = "測驗"
    static let tabLibrary = "字庫"
    static let tabProfile = "我的"

    static func heroTitle(_ target: Int) -> String { "今天 \(target) 個\n剛剛好" }
    static let heroDoneTitle = "今天的目標\n完成了"
    static let primaryAction = "開始今日學習"
    static let continueAction = "繼續學習"
    static let extraAction = "再學一組"
    static func todayPlan(due: Int, fresh: Int) -> String { "\(due) 個待複習 · \(fresh) 個新字" }
    static func streakDays(_ days: Int) -> String { "\(days) 天" }
    static let streak = "連續天數"
    static let mastered = "已掌握"
    static let reviewDueToday = "今日待複習"
    static let reviewList = "複習清單"
    static let quickQuiz = "小測驗"
    static let searchPlaceholder = "搜尋英文、中文、例句或翻譯"

    static let bankLabel = "字庫"
    static let coreBankName = "7000 單字"
    static let builtInBank = "內建"
    static let scanBankTag = "掃描"
    static func bankWordCount(_ count: Int) -> String { "\(count) 個" }
    static let bankPickerTitle = "選擇字庫"
    static let bankPickerHint = "學習、測驗和字庫都會改用這個字庫"
    static let closeSheet = "關閉"
    static let filters = "篩選"

    static let showAnswer = "顯示答案"
    static let tapToReveal = "想一下，再點卡片看答案"
    static let dontKnow = "不熟"
    static let knowIt = "認識"
    static let undo = "復原上一張"
    static func sessionLabel(done: Int, total: Int) -> String { "第 \(min(done + 1, total)) / \(total) 張" }
    static func todayGoalLine(_ studied: Int, _ target: Int) -> String { "今日 \(studied) / \(target)" }
    static let sessionCompleteTitle = "這一組完成了"
    static func sessionCompleteText(known: Int, review: Int) -> String { "認識 \(known) 個 · 還不熟 \(review) 個" }
    static let sessionGoalDone = "今天的目標已達成，繼續加油！"
    static func sessionGoalLeft(_ left: Int) -> String { "距離今天的目標還差 \(left) 個字" }
    static let nextSession = "再來一組"
    static func reviewMissed(_ count: Int) -> String { "再練不熟的 \(count) 個" }
    static let goQuiz = "用測驗檢查記憶"
    static let noStudyWords = "沒有符合的學習單字"
    static let relaxFilters = "可以放寬狀態、分級或字首篩選。"
    static let supplementalMeanings = "補充意思"
    static let englishExample = "英文例句"
    static let chineseTranslation = "中文翻譯"

    static let quizPracticeTitle = "練習方式"
    static let questionCountTitle = "選擇題數"
    static func questionBank(_ count: Int) -> String { "目前題庫 \(count) 個英文單字" }
    static func questionCount(_ count: Int) -> String { "\(count) 題" }
    static let startQuiz = "開始測驗"
    static let quizPrompt = "選出正確的中文意思"
    static let correctResult = "答對了"
    static let wrongResult = "先放進複習"
    static let answer = "答案"
    static let nextQuestion = "下一題"
    static let seeResults = "看結果"
    static let endQuiz = "結束"
    static let quizFinished = "測驗完成"
    static func quizScore(_ correct: Int, _ total: Int) -> String { "答對 \(correct) / \(total) 題" }
    static let restartQuiz = "重新選題"
    static func quizMissedTitle(_ count: Int) -> String { "答錯的 \(count) 個字" }
    static func practiceMissed(_ count: Int) -> String { "用學習卡複習這 \(count) 個字" }
    static let noQuizWords = "沒有符合的測驗題目"

    static let libraryTitle = "完整字庫"
    static let noLibraryWords = "沒有符合的單字"
    static let filterStatus = "狀態"
    static let filterLevel = "分級"
    static let filterInitial = "字首"
    static let filterSort = "排序"
    static let sortDefault = "原本順序"
    static let sortAlphabetical = "英文字首 A-Z"
    static let allLevels = "全部分級"
    static let allInitials = "全部"
    static let resetFilters = "重設篩選"
    static let favoriteWord = "收藏"
    static let unfavoriteWord = "取消收藏"
    static let pronounce = "發音"
    static let statusNew = "未背"
    static let statusReview = "複習中"
    static let statusMastered = "已會"
    static func nextReview(_ date: String) -> String { "下次複習 \(date)" }

    static let profileIdle = "穩定累積中"
    static func profileProgress(percent: Int, mastered: Int) -> String { "今天完成 \(percent)%，目前掌握 \(mastered) 個單字。" }
    static let settings = "設定"
    static let dailyTargetTitle = "每日目標"
    static let dailyTargetText = "每天想學幾個單字，也決定每組學習卡的張數"
    static func dailyTargetOption(_ count: Int) -> String { "每日 \(count) 個單字" }
    static let appearance = "外觀"
    static let themeSystem = "跟隨系統"
    static let themeLight = "淺色"
    static let themeDark = "深色"
    static let account = "帳號"
    static let accountComing = "帳號登入與雲端同步會在下一階段加入，進度目前保存在這台 iPhone。"
    static let favoriteWords = "收藏單字"
    static let remainingWords = "尚未學過"
    static let privacyPolicy = "隱私權政策"
    static let supportPage = "支援頁面"
    static let version = "版本"

    static func filterLabel(_ filter: LibraryFilter) -> String {
        switch filter {
        case .all: "全部"
        case .favorites: "收藏"
        case .review: "複習"
        case .mastered: "已會"
        case .new: "未背"
        }
    }

    static func statusLabel(_ status: WordStatus) -> String {
        switch status {
        case .new: statusNew
        case .review: statusReview
        case .mastered: statusMastered
        }
    }
}
