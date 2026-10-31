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
    static var name: String { L.t("小字團", "Wordling") }

    /// What it says while the online AI works, one picked per wait.
    static func thinking(_ job: Job) -> String {
        switch job {
        case .explain:
            [L.t("小字團翻一下筆記……別催。", "Wordling's checking its notes… don't rush me."),
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
            L.t("小字團在翻你的學習紀錄……", "Wordling is going through your records…")
        }
    }

    enum Job { case explain, explainAgain, answer, why, insights }
}

/// What the cat says during and after practice: a quip beside the progress
/// bar after each answer, and a verdict on the results.
enum CatQuips {
    static func right(_ index: Int, combo: Int) -> String {
        if combo >= 3 {
            return [L.t("連對 \(combo) 題？誰教你的？", "\(combo) in a row? Who taught you?"),
                    L.t("好啦，今天狀態不錯。", "Okay, you're on a roll."),
                    L.t("繼續啊，我看你能撐多久。", "Keep going. Let's see how long this lasts.")].picked(index)
        }
        return [L.t("還可以嘛。", "Not bad."),
                L.t("矇的吧？", "Lucky guess?"),
                L.t("哼，算你對。", "Fine. That's right."),
                L.t("嗯，有在讀喔。", "Oh, you did study.")].picked(index)
    }

    static func wrong(_ index: Int) -> String {
        [L.t("蛤？", "Huh?"),
         L.t("這題我都會欸。", "Even I knew that one."),
         L.t("沒關係，我會記得你錯了。", "It's fine. I'll remember."),
         L.t("再錯我要笑了。", "One more and I'm laughing."),
         L.t("你是認真的嗎？", "Are you serious?")].picked(index)
    }

    static func studied(_ index: Int, known: Bool) -> String {
        known
            ? [L.t("記得？真的假的。", "Remembered? Really?"),
               L.t("好，下一個。", "Fine. Next."),
               L.t("嗯哼。", "Mm-hm.")].picked(index)
            : [L.t("忘了喔？我就知道。", "Forgot? Knew it."),
               L.t("沒差，我會一直考你。", "No worries. I'll keep asking."),
               L.t("這個字在哭。", "That word is crying.")].picked(index)
    }

    /// On the results, from 0 (none right) to 1 (all right).
    static func verdict(_ score: Double) -> String {
        if score >= 0.999 { return L.t("全對？……我不信，明天再考一次。", "All right? …I don't believe it. Again tomorrow.") }
        if score >= 0.8 { return L.t("還不錯，但不要以為我會誇你。", "Not bad. Don't expect praise.") }
        if score >= 0.5 { return L.t("及格邊緣，你自己心裡有數。", "Borderline. You know it.") }
        return L.t("……我們假裝這次沒發生。", "…Let's pretend this never happened.")
    }

    static func studyDone(reachedGoal: Bool) -> String {
        reachedGoal
            ? L.t("今天的目標達成了。好啦，准你休息。", "Today's goal: done. Fine, you may rest.")
            : L.t("就這樣？好吧，休息一下再回來。", "That's it? Fine. Take a break and come back.")
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
