import SwiftUI
import Word7000Core

/// The cat's verdict under a practice's results. Its own line shows at once;
/// when the online AI is allowed it then looks at the real score and the
/// words that slipped, and says something about those instead, with one tip.
struct SessionVerdict: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var fallback: String
    var mood: Mascot.Mood = .smug
    /// study, quiz, spelling or exam.
    var kind: String
    var total: Int
    var correct: Int
    var missedIds: [String]
    @State private var verdict: CloudAI.Verdict?

    var body: some View {
        Group {
            if let verdict {
                CatSays(mood: mood, size: 26) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verdict.verdict).font(.display(.footnote, weight: .semibold))
                        if !verdict.tip.isEmpty {
                            Label { Text(verdict.tip) } icon: { Image(systemName: "lightbulb").foregroundStyle(Palette.known) }
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: 360)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("session-verdict-ai")
                .transition(.opacity)
            } else {
                CatVerdict(text: fallback, mood: mood)
            }
        }
        .animation(reduceMotion ? nil : Motion.reveal, value: verdict)
        .task { await load() }
    }

    private func load() async {
        guard verdict == nil, total >= 5, !AppRuntime.uiTesting,
              CloudAssistant.shared.ready, IntelligenceSettings.shared.cloudAllowed else { return }
        // Leave room for what the learner asks for themselves.
        if let usage = CloudAssistant.shared.usage, usage.remaining < 4 { return }
        let missed: [JSONValue] = missedIds.prefix(10).compactMap { model.word(id: $0) }.map { word in
            .object([
                "word": .string(String(model.face(word).prompt.prefix(80))),
                "meaning": .string(String(model.aiGloss(word).prefix(120))),
            ])
        }
        let input: [String: JSONValue] = [
            "mode": .string(model.studyMode.rawValue),
            "profile": model.catProfile(),
            "kind": .string(kind),
            "total": .number(Double(min(500, total))),
            "correct": .number(Double(min(500, correct))),
            "missed": .array(missed),
        ]
        if let value = try? await CloudAssistant.shared.run(.verdict, input, as: CloudAI.Verdict.self).cleaned() {
            verdict = value
        }
    }
}

/// When a word slips for the third time or more, the cat steps in with how to
/// remember it: the memory hook and the usual trap from its explanation (the
/// saved one, or a fresh one when the online AI is allowed), else the meaning
/// and example again from the word list.
struct StuckWordTip: View {
    @Environment(AppModel.self) private var model
    let word: WordEntry
    let misses: Int
    var dismiss: () -> Void
    @State private var explanation: CloudAI.Explanation?
    @State private var loading = false

    private var cacheKey: String { "\(model.studyMode.rawValue):\(word.id):\(word.meaningZh)" }

    var body: some View {
        let face = model.face(word)
        HStack(alignment: .top, spacing: 12) {
            Mascot(mood: .encourage, size: 40)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                Text(L.t("\(face.prompt)，第 \(misses) 次了", "\(face.prompt), \(misses) times now"))
                    .font(.display(.headline, weight: .bold))
                    .foregroundStyle(Palette.accent)
                Text(L.t("我不是生氣，我是失望。來，這樣記：", "I'm not angry, just disappointed. Here's how to remember it:"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Group {
                    if let explanation {
                        if !explanation.memoryTip.isEmpty {
                            Label { Text(explanation.memoryTip) } icon: { Image(systemName: "lightbulb.fill").foregroundStyle(Palette.known) }
                        }
                        if !explanation.pitfall.isEmpty {
                            Label { Text(explanation.pitfall).foregroundStyle(.secondary) } icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Palette.review) }
                        }
                    } else if loading {
                        Label { Text(Cat.thinking(.explain)).foregroundStyle(.secondary) } icon: { ProgressView().controlSize(.small) }
                    } else {
                        Text("\(face.prompt)  =  \(face.answer)").fontWeight(.semibold)
                        if !face.examplePrimary.isEmpty {
                            Text(face.examplePrimary).foregroundStyle(.secondary)
                        }
                    }
                }
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Palette.fill, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L.close)
        }
        .padding(14)
        .modifier(TipSurface())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("study-stuck-tip")
        .task(id: word.id) { await load() }
    }

    private func load() async {
        explanation = CloudAnswerCache.explanations[cacheKey]
        guard explanation == nil, !AppRuntime.uiTesting,
              CloudAssistant.shared.ready, IntelligenceSettings.shared.cloudAllowed else { return }
        let example = model.studyMode == .english ? word.example : word.exampleZh
        let input: [String: JSONValue] = [
            "word": .string(String(word.word.prefix(80))),
            "partOfSpeech": .string(String(word.partOfSpeech.prefix(40))),
            "meaning": .string(String(ChineseDisplay.conciseMeaning(word.meaningZh).prefix(240))),
            "example": .string(String(example.prefix(240))),
            "mode": .string(model.studyMode.rawValue),
        ]
        loading = true
        defer { loading = false }
        if let value = try? await CloudAssistant.shared.run(.explain, input, as: CloudAI.Explanation.self).cleaned() {
            CloudAnswerCache.explanations[cacheKey] = value
            explanation = value
        }
    }
}

/// A small card for the cat's tips: the surface with a soft shadow, or in the
/// collage a scrap of peach paper taped on at a slight angle.
private struct TipSurface: ViewModifier {
    @Environment(\.appStyle) private var appStyle

    func body(content: Content) -> some View {
        if appStyle == .collage {
            content.paperCard(.peach, tilt: -0.6, torn: [.bottom], tape: true, seed: 5)
        } else {
            content
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        }
    }
}

/// After a wrong quiz answer, at once and without the online AI: what the
/// chosen option really means, beside the right one, so the mix-up is plain.
struct QuizContrast: View {
    @Environment(AppModel.self) private var model
    let word: WordEntry
    let chosen: String
    let correct: String
    @State private var other: WordEntry?

    var body: some View {
        let face = model.face(word)
        CatSays(mood: .smug, size: 28) {
            VStack(alignment: .leading, spacing: 4) {
                if let other {
                    let otherFace = model.face(other)
                    Text(L.t("你選的「\(chosen)」是 \(otherFace.prompt) 的意思。",
                             "\u{201C}\(chosen)\u{201D} is what \(otherFace.prompt) means."))
                } else {
                    Text(L.t("不是「\(chosen)」。", "Not \u{201C}\(chosen)\u{201D}."))
                }
                Text(L.t("\(face.prompt) 是「\(correct)」。記好，我不想再說第二次。",
                         "\(face.prompt) means \u{201C}\(correct)\u{201D}. Remember it. I'm not saying it twice."))
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("quiz-contrast")
        .task(id: chosen) { other = match(chosen) }
    }

    /// The word whose meaning (or spelling) is the chosen option.
    private func match(_ text: String) -> WordEntry? {
        let target = text.trimmingCharacters(in: .whitespaces)
        return model.bank.words.first { entry in
            guard entry.id != word.id else { return false }
            let face = model.face(entry)
            return face.answer == target || face.prompt == target
                || ChineseDisplay.conciseMeaning(entry.meaningZh) == target || entry.word == target
        }
    }
}
