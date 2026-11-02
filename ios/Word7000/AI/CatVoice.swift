import SwiftUI

/// The companion saying something in a list or a card: its face beside a
/// rounded speech bubble whose corner points at it. Wherever the online AI
/// answers, the answer comes from the cat this way.
struct CatSays<Content: View>: View {
    var mood: Mascot.Mood = .idle
    var size: CGFloat = 28
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Mascot(mood: mood, size: size)
                .padding(.top, 2)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background {
                    UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 16,
                                           style: .continuous)
                        .fill(Palette.accent.opacity(0.09))
                }
        }
    }
}

/// What the learner asked, as their own bubble on the right.
struct LearnerSays: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 16, bottomTrailingRadius: 4, topTrailingRadius: 16,
                                       style: .continuous)
                    .fill(Palette.accent)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, 40)
    }
}

/// The cat's name, as it is shown in headings and buttons.
enum Cat {
    static var name: String { L.t("小笨貓", "Silly Cat") }

    /// What it says while the online AI works, one picked per wait.
    static func thinking(_ job: Job) -> String {
        switch job {
        case .explain:
            [L.t("小笨貓翻一下筆記……別催。", "Silly Cat's checking its notes… don't rush me."),
             L.t("等等，我在想怎麼講你才聽得懂。", "Hang on. Working out how to say it so you'll get it.")].pickedForNow
        case .explainAgain:
            L.t("好啦，換個講法……", "Fine, another way…")
        case .answer:
            [L.t("嗯……這題問得還可以。", "Hmm… not a bad question, actually."),
             L.t("讓我想一下，不要盯著我。", "Let me think. Stop staring.")].pickedForNow
        case .why:
            [L.t("讓我看看你錯在哪……", "Let's see where you went wrong…"),
             L.t("蛤，選這個？我來解釋。", "You picked that? Let me explain.")].pickedForNow
        case .insights:
            L.t("小笨貓在翻你的學習紀錄……", "Silly Cat is going through your records…")
        }
    }

    enum Job { case explain, explainAgain, answer, why, insights }
}

/// Where the cat's lines come from: what it knows about the learner, and
/// today's AI-written pack when there is one. Gather it once per screen, not
/// per line: the level estimate reads the whole word list.
struct CatLineSource {
    var context: CatContext?
    var pack: CloudAI.LinePack?

    static let none = CatLineSource()
}

extension CatLineSource {
    /// Things only this cat would nag this learner about, for when it is tapped.
    var contextLines: [String] {
        guard let context else { return [] }
        var lines: [String] = []
        if let nickname = context.nickname {
            lines.append(L.t("\(nickname)，我叫你叫得很親，你背字背得很遠。", "\(nickname), I call you so sweetly and you study so little."))
        }
        if let days = context.daysToExam {
            lines.append(L.t("學測剩 \(days) 天。我沒有要給你壓力，我只是一直數。", "\(days) days to the exam. No pressure. I'm just counting. Constantly."))
        }
        if let level = context.level {
            lines.append(L.t("你在 \(level) 欸，不往上爬嗎？我幫你挑好字了。", "You're at \(level). Not climbing? I already picked your words."))
        }
        if context.streak >= 3 {
            lines.append(L.t("連續 \(context.streak) 天了，斷掉的話我會傷心一整年。", "\(context.streak) days in a row. Break it and I'll be sad for a year."))
        }
        if context.hour >= 23 || context.hour < 5 {
            lines.append(L.t("半夜還醒著？要嘛背字，要嘛睡覺，不要滑手機。", "Up this late? Study or sleep. Not scrolling."))
        }
        return lines
    }
}

extension AppModel {
    @MainActor var catLines: CatLineSource {
        CatLineSource(context: catContext, pack: CatLinePackStore.today(mode: studyMode))
    }
}

/// What the cat says during and after practice: a quip beside the progress
/// bar after each answer, and a verdict on the results. Lines know the word
/// just answered, how often it has slipped, the exam countdown and what to
/// call the learner; one in three comes from today's AI pack when there is one.
enum CatQuips {
    static func right(_ index: Int, combo: Int, word: String? = nil, source: CatLineSource = .none) -> String {
        if index % 3 == 1, let line = source.pack?.right.pickedIfAny(index / 3) { return line }
        let call = source.context?.callout ?? ""
        var lines: [String]
        if combo >= 3 {
            lines = [L.t("連對 \(combo) 題？誰教你的？", "\(combo) in a row? Who taught you?"),
                     L.t("好啦，今天狀態不錯。", "Okay, you're on a roll."),
                     L.t("繼續啊，我看你能撐多久。", "Keep going. Let's see how long this lasts.")]
            if let days = source.context?.daysToExam {
                lines.append(L.t("連對 \(combo)。學測剩 \(days) 天，保持這樣我就不碎念。", "\(combo) straight. \(days) days to the exam. Keep this up and I'll stop nagging."))
            }
        } else {
            lines = [L.t("\(call)還可以嘛。", "\(call)not bad."),
                     L.t("矇的吧？", "Lucky guess?"),
                     L.t("哼，算你對。", "Fine. That's right."),
                     L.t("嗯，有在讀喔。", "Oh, you did study.")]
            if let word {
                lines.append(L.t("\(word) 對了。我就說你可以，雖然我沒說過。", "\(word), right. I always said you could. I never said that."))
            }
            if let level = source.context?.level {
                lines.append(L.t("\(level) 的人答對這題，剛好而已。", "Someone at \(level) should get that. Just saying."))
            }
        }
        return lines.picked(index)
    }

    /// After a wrong answer; `misses` is how many times this word has now slipped.
    static func wrong(_ index: Int, word: String? = nil, misses: Int = 0, source: CatLineSource = .none) -> String {
        if let word, misses >= 3, index % 2 == 0 {
            return [L.t("\(word) 第 \(misses) 次錯了。沒關係，我習慣了。", "\(word), wrong for the \(misses)th time. It's fine. I'm used to it."),
                    L.t("\(word) 錯 \(misses) 次，它都要不認你了。", "\(misses) misses on \(word). It's about to disown you."),
                    L.t("我為了你把 \(word) 排了 \(misses) 次，你就這樣對我？", "I've lined up \(word) \(misses) times for you. And this is the thanks I get?")].picked(index / 2)
        }
        if let word, misses == 2, index % 2 == 0 {
            return L.t("\(word) 上次也錯。你是故意要我擔心吧。", "You missed \(word) last time too. Are you trying to worry me?")
        }
        if index % 3 == 1, let line = source.pack?.wrong.pickedIfAny(index / 3) { return line }
        let call = source.context?.callout ?? ""
        var lines = [L.t("蛤？", "Huh?"),
                     L.t("這題我都會欸。", "Even I knew that one."),
                     L.t("沒關係，我會記得你錯了。", "It's fine. I'll remember."),
                     L.t("\(call)再錯我要哭給你看。", "\(call)one more and I'll cry. Really."),
                     L.t("你是認真的嗎？", "Are you serious?")]
        if let days = source.context?.daysToExam {
            lines.append(L.t("學測剩 \(days) 天，你還在這裡錯。我好擔心。", "\(days) days to the exam and you're missing this. I'm worried."))
        }
        return lines.picked(index)
    }

    static func studied(_ index: Int, known: Bool, word: String? = nil, misses: Int = 0, source: CatLineSource = .none) -> String {
        if !known, let word, misses >= 3, index % 2 == 0 {
            return [L.t("\(word) 第 \(misses) 次忘記。它在哭，我也在哭。", "\(word), forgotten \(misses) times. It's crying. So am I."),
                    L.t("又是 \(word)？我們是不是該好好談談。", "\(word) again? We need to talk.")].picked(index / 2)
        }
        if index % 3 == 1, let line = (known ? source.pack?.right : source.pack?.wrong)?.pickedIfAny(index / 3) { return line }
        return known
            ? [L.t("記得？真的假的。", "Remembered? Really?"),
               L.t("好，下一個。", "Fine. Next."),
               L.t("嗯哼。", "Mm-hm.")].picked(index)
            : [L.t("忘了喔？我就知道。", "Forgot? Knew it."),
               L.t("沒差，我會一直考你。", "No worries. I'll keep asking."),
               L.t("這個字在哭。", "That word is crying.")].picked(index)
    }

    /// On the results, from 0 (none right) to 1 (all right).
    static func verdict(_ score: Double, source: CatLineSource = .none) -> String {
        let call = source.context?.callout ?? ""
        if score >= 0.999 { return L.t("\(call)全對？……我不信，明天再考一次。", "\(call)all right? …I don't believe it. Again tomorrow.") }
        if score >= 0.8 { return L.t("還不錯，但不要以為我會誇你。", "Not bad. Don't expect praise.") }
        if score >= 0.5 {
            if let days = source.context?.daysToExam {
                return L.t("及格邊緣。學測剩 \(days) 天，你自己心裡有數。", "Borderline. \(days) days to the exam. You know it.")
            }
            return L.t("及格邊緣，你自己心裡有數。", "Borderline. You know it.")
        }
        return L.t("……我們假裝這次沒發生。我會一直陪你練，誰叫我心軟。", "…Let's pretend this never happened. I'll keep practising with you. I'm too soft.")
    }

    static func studyDone(reachedGoal: Bool, source: CatLineSource = .none) -> String {
        if let line = source.pack?.done.first, !reachedGoal { return line }
        return reachedGoal
            ? L.t("今天的目標達成了。好啦，准你休息。", "Today's goal: done. Fine, you may rest.")
            : L.t("就這樣？好吧，休息一下再回來。我會等。一直等。", "That's it? Fine. Take a break and come back. I'll wait. Forever.")
    }

    static func speakingDone(answered: Int) -> String {
        answered > 0
            ? L.t("講得還行。至少你有開口。", "Not bad. At least you said something.")
            : L.t("一句都沒講？害羞喔？", "Not a word? Shy, are we?")
    }
}

/// The cat's verdict on a finished practice, said under the score.
struct CatVerdict: View {
    var text: String
    var mood: Mascot.Mood = .smug

    var body: some View {
        CatSays(mood: mood, size: 26) {
            Text(text).font(.display(.footnote, weight: .semibold))
        }
        .frame(maxWidth: 360)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

private extension Array where Element == String {
    /// Today's AI lines may be missing or empty: nil then.
    func pickedIfAny(_ index: Int) -> String? {
        isEmpty ? nil : self[abs(index) % count]
    }

    /// The line for this turn: the same one whenever the view is redrawn.
    func picked(_ index: Int) -> String {
        self[abs(index) % count]
    }

    /// One of the lines, the same one for a minute at a time, so a waiting
    /// line does not change every time the view is redrawn.
    var pickedForNow: String {
        self[Int(Date().timeIntervalSince1970 / 60) % count]
    }
}
