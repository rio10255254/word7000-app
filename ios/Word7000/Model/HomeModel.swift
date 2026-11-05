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

    /// The words a quiz outside today's routine asks about: the chosen bank's
    /// learned words, or for the weekly quiz everything studied this week.
    func examRoundIds(_ kind: ExamRoundKind, seed: String) -> [String] {
        refreshToday()
        let words = kind == .weekly ? vocabularyWords : bank.words
        return ExamRound.pick(kind, words: words, state: progress, today: today, seed: seed)
    }

    /// Words the quick quiz could ask now.
    var quickQuizWordCount: Int {
        ExamRound.available(.quick, words: bank.words, state: progress, today: today)
    }

    /// Sunday's weekly quiz is waiting (learners of English: the questions
    /// are English sentences).
    var weeklyQuizDue: Bool {
        guard studyMode == .english else { return false }
        if ProcessInfo.processInfo.arguments.contains("-uiTestingWeeklyQuiz") { return true }
        return ExamRound.weeklyDue(words: vocabularyWords, state: progress, today: today)
    }

    /// A finished quiz outside the routine, for the usage numbers.
    func noteExamRound(_ kind: ExamRoundKind, asked: Int, right: Int) {
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
        if used { recordSpeaking(completed: true) }
    }
}
