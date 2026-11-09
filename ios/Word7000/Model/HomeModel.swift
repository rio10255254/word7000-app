import Foundation
import Word7000Core

// WordCat Next: what the home page shows, from the rules in Word7000Core.
extension AppModel {
    /// Today's stage on the speaking path is cleared.
    var speakingDoneToday: Bool { speakingPath.clearedToday(today) }

    var homeShowsSpeaking: Bool { settings.homeShowsSpeaking ?? true }

    /// The pillar shown as the big card.
    var homeLead: Pillar {
        HomeLayout.lead(preferred: settings.homeLead ?? .words, wordsDone: goalDone,
                        speakingDone: speakingDoneToday, speakingShown: homeShowsSpeaking)
    }

    /// The learner chose which card to do first.
    func setHomeLead(_ pillar: Pillar) {
        settings.homeLead = pillar
        scheduleSave()
        Usage.log("home_lead", pillar.rawValue)
    }

    /// Monday to Sunday of this week, stamped where studied.
    var weekStamps: [WeekStamp] {
        WeekStamps.week(today: today, analytics: progress.analytics, coveredDay: progress.streakFreezeDate)
    }

    /// Streak protection is ready to cover a missed day: the cat's can is full.
    var catCanReady: Bool { streakProtectionReadyOn == nil }

    /// The built-in list as fourteen chapters, with the words mastered in each.
    var shelfChapters: [ShelfChapter] { MasteryShelf.chapters(words: coreWords, state: progress) }

    /// What the exam-style questions are called, after the exam the learner
    /// said they prepare for (學測 by default).
    var examStyleName: String {
        // Learners of Chinese prepare for no exam here: a plain fill-in-the-gap.
        if learnsChinese { return L.t("句子填空", "Fill the gap") }
        return switch settings.learnerProfile?.exam {
        case "tvee": L.t("統測題型", "Exam style")
        case "cap": L.t("會考題型", "Exam style")
        case "proficiency": L.t("檢定題型", "Test style")
        case "none": L.t("句子填空", "Fill the gap")
        default: L.t("學測題型", "Exam style")
        }
    }

    /// Words still to do today after the current set, for a set shorter than
    /// the goal (the first one after the welcome); 0 once the goal is met, or
    /// once every word the study range holds has been studied today (five
    /// favourites cannot make a goal of twenty).
    var wordsLeftForGoal: Int {
        guard !goalDone else { return 0 }
        let left = studyCandidates.lazy.filter { [today, progress] in progress.words[$0.id]?.lastStudied != today }.count
        return min(progress.dailyTarget - progress.studiedToday, left)
    }

    /// The chapter of the built-in words being read (0-based), from where
    /// the level test placed the learner; nil while another bank is studied.
    var readingChapter: Int? {
        guard settings.activeBankId == WordBanks.coreBankId else { return nil }
        return MasteryShelf.current(shelfChapters, from: placementStart)
    }

    /// The words a quiz outside today's routine asks about: the chosen bank's
    /// learned words, or for the weekly quiz everything studied this week.
    func examRoundIds(_ kind: ExamRoundKind, seed: String) -> [String] {
        refreshToday()
        let words = kind == .weekly ? vocabularyWords : bank.words
        return ExamRound.pick(kind, words: words, state: progress, today: today, seed: seed, chinese: learnsChinese)
    }

    /// Words the quick quiz could ask now.
    var quickQuizWordCount: Int {
        ExamRound.available(.quick, words: bank.words, state: progress, today: today, chinese: learnsChinese)
    }

    /// Sunday's weekly quiz is waiting (in the language being learned).
    var weeklyQuizDue: Bool {
        if ProcessInfo.processInfo.arguments.contains("-uiTestingWeeklyQuiz") { return true }
        guard settings.weeklyQuizDoneOn != today else { return false }
        return ExamRound.weeklyDue(words: vocabularyWords, state: progress, today: today, chinese: learnsChinese)
    }

    /// A finished quiz outside the routine, for the usage numbers.
    func noteExamRound(_ kind: ExamRoundKind, asked: Int, right: Int) {
        if kind == .weekly {
            settings.weeklyQuizDoneOn = today
            scheduleSave()
        }
        Usage.log("exam_round", "\(kind.rawValue).\(asked).\(right)")
    }

    /// The words to offer at the end of a speaking stage: today's, those
    /// marked known in today's cards first. Learners of English.
    func todaysWordChoices() -> [String] {
        guard studyMode == .english else { return [] }
        refreshToday()
        let preferred = wordRoutine?.day == today ? (wordRoutine?.cardIds ?? []) : []
        // Words whose example has them in it, so the example can show how.
        let words = vocabularyWords.filter { Cloze.sentence(for: $0) != nil }
        return TodaysWordUse.pick(words: words, state: progress, today: today, preferred: preferred)
    }

    /// Today's word said in a sentence at the end of a speaking stage (or skipped).
    func recordTodaysWordUse(wordId: String?, used: Bool) {
        Usage.log("speaking_word_use", used ? "used" : "skipped")
        if used {
            recordSpeaking(completed: true)
            if let wordId { creditWordUse(wordId) }
        }
    }

    /// Today's words and speaking are both done and the stamp not shown yet.
    var dayCompleteDue: Bool {
        guard AppRuntime.dayComplete, goalDone, speakingDoneToday || !homeShowsSpeaking else { return false }
        return settings.dayCompleteShownOn != today
    }

    func noteDayCompleteShown() {
        settings.dayCompleteShownOn = today
        scheduleSave()
        Usage.log("day_complete", "\(progress.streak)")
    }
}
