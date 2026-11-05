import SwiftUI
import Word7000Core

/// A fill-in-the-blank card: the Chinese sentence on top with the word's
/// part marked like a highlighter, the English sentence below with the
/// blank. The blank shows what is typed, the letters given or the answer to
/// copy; the card floods green once it is solved. Big type: this card is the
/// whole question, so nothing on it needs a caption.
struct ClozeCard: View {
    var word: WordEntry
    var sentence: Cloze.Sentence
    var attempt: ClozeAttempt
    var input: String
    /// When the word comes back, shown once solved ("See you tomorrow").
    var comeBack: String?
    /// The word was missed earlier in this round.
    var secondLook = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.wordCardRadius, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                if secondLook || (attempt.solved && comeBack != nil) {
                    HStack(spacing: 8) {
                        if secondLook {
                            Label(L.t("再考一次", "Once more"), systemImage: "arrow.counterclockwise")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Palette.review)
                        }
                        Spacer(minLength: 0)
                        if attempt.solved, let comeBack {
                            Text(comeBack)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Palette.known)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Palette.known.opacity(0.16), in: Capsule())
                                .popIn(delay: 0.15)
                                .accessibilityIdentifier("cloze-comes-back")
                        }
                    }
                }
                chineseSentence
                    .font(.title2)
                    .accessibilityIdentifier("cloze-chinese")
                if Cloze.cue(for: word) == nil {
                    // No marked part: say which word is wanted.
                    Text(ChineseDisplay.conciseMeaning(word.meaningZh))
                        .font(.headline)
                        .foregroundStyle(Palette.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Palette.accent.opacity(0.12), in: Capsule())
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().padding(.horizontal, 20)

            HStack(alignment: .top) {
                englishSentence
                    .font(.title2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("cloze-sentence")
                    // UI tests read the answer here to type it.
                    .accessibilityValue(AppRuntime.uiTesting ? sentence.answer : "")
                if attempt.solved {
                    SpeakButton(text: word.example)
                }
            }
            .padding(20)
        }
        .background {
            shape.fill(Palette.surface)
                .overlay(shape.fill(attempt.solved ? Palette.known.opacity(0.16) : .clear))
        }
        .overlay(shape.stroke(border, lineWidth: 2))
        .overlay(alignment: .topLeading) {
            if attempt.solved {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Palette.known)
                    .rotationEffect(.degrees(-12))
                    .offset(x: -8, y: -14)
                    .popIn(delay: 0)
                    .accessibilityHidden(true)
            }
        }
        .animation(reduceMotion ? nil : Motion.reveal, value: attempt.solved)
    }

    /// The translation with the word's part marked like a highlighter.
    private var chineseSentence: Text {
        guard let cue = Cloze.cue(for: word) else { return Text(word.exampleZh) }
        var marked = AttributedString(cue.cue)
        marked.backgroundColor = Palette.review.opacity(0.35)
        marked.foregroundColor = Palette.ink
        return Text(AttributedString(cue.before) + marked + AttributedString(cue.after))
    }

    private var englishSentence: Text {
        var text = AttributedString()
        for piece in sentence.pieces {
            switch piece {
            case .text(let part): text += AttributedString(part)
            case .blank: text += blank
            }
        }
        return Text(text)
    }

    private var blank: AttributedString {
        let nbsp = "\u{00A0}"
        let typed = input.trimmed
        let content: String
        var tint = Palette.ink
        var fill = Palette.accent.opacity(0.12)
        if attempt.solved {
            content = sentence.answer
            tint = Palette.known
            fill = Palette.known.opacity(0.2)
        } else if attempt.answerShown {
            // The answer to copy, faint until it is typed.
            content = typed.isEmpty ? sentence.answer : typed
            tint = typed.isEmpty ? Palette.tertiaryLabel : Palette.ink
        } else if !typed.isEmpty {
            content = typed
        } else {
            content = Spelling.pattern(sentence.answer, revealed: attempt.lettersShown).replacingOccurrences(of: " ", with: nbsp)
            tint = Palette.secondaryLabel
        }
        var blank = AttributedString(nbsp + content + nbsp)
        blank.foregroundColor = tint
        blank.backgroundColor = fill
        blank.underlineStyle = Text.LineStyle.single
        return blank
    }

    private var border: Color {
        if attempt.solved { return Palette.known }
        if let verdict = attempt.lastVerdict, !verdict.isCorrect { return Palette.miss.opacity(0.6) }
        return .clear
    }

    /// What to say after a try that was not right, or when the answer is up.
    static func message(for word: WordEntry, attempt: ClozeAttempt) -> (text: String, tint: Color)? {
        guard !attempt.solved else { return nil }
        if attempt.answerShown {
            return (L.t("看一下答案，自己打一次。", "Look at the answer, then type it yourself."), Palette.review)
        }
        guard let verdict = attempt.lastVerdict else { return nil }
        let wanted = Cloze.cue(for: word)?.cue ?? ChineseDisplay.conciseMeaning(word.meaningZh)
        switch verdict {
        case .correct:
            return nil
        case .otherForm:
            return (L.t("字對了！但這句要用另一個形式。", "Right word, but this sentence needs another form of it."), Palette.review)
        case .almost:
            return (L.t("差一個字母，再看一下。", "One letter off. Look again."), Palette.review)
        case .otherWord(let other, let meaning):
            let gloss = ChineseDisplay.conciseMeaning(meaning)
            return (L.t("\(other) 是「\(gloss)」。「\(wanted)」是哪個字？",
                        "\(other) means \u{201C}\(gloss)\u{201D}. Which word is \u{201C}\(wanted)\u{201D}?"), Palette.miss)
        case .wrong:
            return (L.t("不是這個字。再想想「\(wanted)」。", "Not that one. Think of \u{201C}\(wanted)\u{201D} again."), Palette.miss)
        }
    }

    /// When a word comes back, in a few words.
    static func comeBackLabel(days: Int, inThisRound: Bool) -> String {
        if inThisRound { return L.t("等一下再考你", "Back in a few questions") }
        switch days {
        case 0: return L.t("今天稍後再複習", "Again later today")
        case 1: return L.t("明天見", "See you tomorrow")
        default: return L.t("\(days) 天後見", "Back in \(days) days")
        }
    }
}

/// A line from the cat, big enough to read at a glance: the cat's face and
/// a bubble. Used in place of small captions to say what to do.
struct RoutineCatLine: View {
    var text: String
    var mood: Mascot.Mood = .happy

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Mascot(mood: mood, size: 48)
                .accessibilityHidden(true)
            Text(text)
                .font(.headline)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(MascotBubble.cream, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                .environment(\.colorScheme, .light)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
