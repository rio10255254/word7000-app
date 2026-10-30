import SwiftUI
import Word7000Core

/// AI answers kept on this iPhone, newest last, so reopening a word or a quiz
/// question never spends the learner's daily allowance again, even after a relaunch.
@MainActor
final class SavedAnswers<Value: Codable> {
    private struct Item: Codable {
        let key: String
        let value: Value
    }

    private let url: URL?
    private let limit: Int
    private var items: [Item]?

    init(file: String, limit: Int) {
        url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("AIAnswers", isDirectory: true)
            .appendingPathComponent(file)
        self.limit = limit
    }

    subscript(key: String) -> Value? {
        get { loaded().last { $0.key == key }?.value }
        set {
            var all = loaded().filter { $0.key != key }
            if let newValue { all.append(Item(key: key, value: newValue)) }
            items = Array(all.suffix(limit))
            save()
        }
    }

    private func loaded() -> [Item] {
        if let items { return items }
        let saved = url.flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode([Item].self, from: $0) } ?? []
        items = saved
        return saved
    }

    private func save() {
        guard let url, let items, let data = try? JSONEncoder().encode(items) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}

@MainActor
enum CloudAnswerCache {
    /// Raise when the prompts change enough that saved answers should be asked for again.
    private static let version = 2
    static let explanations = SavedAnswers<CloudAI.Explanation>(file: "explanations-v\(version).json", limit: 300)
    static let quiz = SavedAnswers<CloudAI.QuizExplanation>(file: "quiz-v\(version).json", limit: 300)
    static let questions = SavedAnswers<[AskedQuestion]>(file: "questions-v1.json", limit: 200)
}

/// One question a learner asked about a word, with the tutor's answer.
struct AskedQuestion: Codable, Equatable {
    let question: String
    let reply: CloudAI.Answer
}

/// The AI explanation and questions for one word, opened from a study card
/// so a learner can ask the moment a word puzzles them.
struct AIWordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model
    let word: WordEntry

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    AIExplanationSection(word: word)
                    AskAISection(word: word)
                }
                .listRowBackground(Palette.surface)
            }
            .warmList()
            .navigationTitle(model.face(word).prompt)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("完成", "Done")) { dismiss() }
                        .accessibilityIdentifier("ai-sheet-done")
                }
            }
        }
    }
}

/// The learner's own questions about one word, answered by the AI tutor.
/// The last five answers per word stay on this iPhone.
struct AskAISection: View {
    @Environment(AppModel.self) private var model
    let word: WordEntry
    @State private var asked: [AskedQuestion] = []
    @State private var question = ""
    @State private var pending: String?
    @State private var loading = false
    @State private var failure: CloudAI.Failure?
    @State private var askCloud = false
    /// Bumped when a question fails, so the field gives a small shake.
    @State private var failures = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool

    private var cacheKey: String { "\(model.studyMode.rawValue):\(word.id):\(word.meaningZh)" }
    private var exampleLanguage: String { model.studyMode == .english ? "en-US" : "zh-TW" }
    private var suggestions: [String] {
        [L.t("常見的錯誤用法是什麼？", "What mistakes do learners make with it?"),
         L.t("跟意思相近的字有什麼不同？", "How is it different from similar words?"),
         L.t("口語和正式場合都能用嗎？", "Is it casual, formal or both?")]
    }

    var body: some View {
        if CloudAssistant.shared.offered || !asked.isEmpty {
            Section {
                ForEach(Array(asked.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.question)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.accent)
                        Text(item.reply.answer)
                    }
                    .padding(.vertical, 4)
                    .entrance(0, distance: 8)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("ai-ask-answer")
                    ForEach(Array(item.reply.examples.enumerated()), id: \.offset) { _, example in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(example.sentence)
                                if !example.translation.isEmpty {
                                    Text(example.translation).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 8)
                            SpeakButton(text: example.sentence, language: exampleLanguage)
                        }
                    }
                }
                if loading {
                    AIThinkingRow(text: L.t("AI 正在回答…", "AI is answering…"))
                        .accessibilityIdentifier("ai-ask-loading")
                } else if asked.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(Array(suggestions.enumerated()), id: \.element) { offset, suggestion in
                                Button { send(suggestion) } label: {
                                    Text(suggestion)
                                        .font(.footnote)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Palette.accent.opacity(0.12), in: Capsule())
                                }
                                .buttonStyle(SoftPressStyle())
                                .entrance(offset, distance: 8)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
                HStack(spacing: 8) {
                    TextField(L.t("問 AI 關於這個字的問題", "Ask AI about this word"), text: $question)
                        .submitLabel(.send)
                        .focused($focused)
                        .onSubmit { send() }
                        .accessibilityIdentifier("ai-ask-field")
                    Button { send() } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .symbolEffect(.bounce, value: reduceMotion ? 0 : asked.count)
                    }
                    .buttonStyle(.borderless)
                    .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loading)
                    .accessibilityLabel(L.t("送出問題", "Send question"))
                    .accessibilityIdentifier("ai-ask-send")
                }
                .shake(trigger: failures, enabled: !reduceMotion)
                if let failure { AIFailureNote(failure: failure) }
                // The explanation above already carries the Plus note; repeat it only when today's allowance ran out here.
                if failure == .quota { PlusAIUpsell() }
            } header: {
                Text(L.t("問 AI", "Ask AI"))
            } footer: {
                Text(L.t("只回答和這個字有關的問題，每問一次算一次線上 AI。由 Claude 產生，可能有誤。",
                         "Answers questions about this word; each one counts as one online AI request. By Anthropic's Claude, and may contain mistakes."))
            }
            .onAppear { asked = CloudAnswerCache.questions[cacheKey] ?? [] }
            .sensoryFeedback(.impact(weight: .light), trigger: loading) { _, new in new && (model.settings.hapticsEnabled ?? true) }
            .sensoryFeedback(.error, trigger: failures) { _, _ in model.settings.hapticsEnabled ?? true }
            .cloudConsentAlert(isPresented: $askCloud) {
                if IntelligenceSettings.shared.cloudConsent == true, let pending { send(pending) }
                pending = nil
            }
        }
    }

    private func send(_ text: String? = nil) {
        let asking = (text ?? question).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !asking.isEmpty, !loading else { return }
        if CloudAssistant.shared.needsConsent { pending = asking; askCloud = true; return }
        let key = cacheKey
        let input: [String: JSONValue] = [
            "word": .string(String(word.word.prefix(80))),
            "partOfSpeech": .string(String(word.partOfSpeech.prefix(40))),
            "meaning": .string(String(ChineseDisplay.conciseMeaning(word.meaningZh).prefix(240))),
            "question": .string(String(asking.prefix(200))),
            "mode": .string(model.studyMode.rawValue),
        ]
        loading = true
        failure = nil
        question = ""
        focused = false
        Task {
            defer { loading = false }
            do {
                let reply = try await CloudAssistant.shared.run(.ask, input, as: CloudAI.Answer.self).cleaned()
                let saved = Array(((CloudAnswerCache.questions[key] ?? []) + [AskedQuestion(question: asking, reply: reply)]).suffix(5))
                CloudAnswerCache.questions[key] = saved
                if key == cacheKey { withAnimation(Motion.reveal) { asked = saved } }
            } catch is CancellationError {
            } catch {
                failure = (error as? CloudAI.Failure) ?? .unavailable
                failures += 1
                // Give the learner their question back to try again.
                if question.isEmpty { question = asking }
            }
        }
    }
}

/// A tutor-style explanation of one word, on the word page.
struct AIExplanationSection: View {
    @Environment(AppModel.self) private var model
    let word: WordEntry
    @State private var explanation: CloudAI.Explanation?
    @State private var loading = false
    @State private var failure: CloudAI.Failure?
    @State private var askCloud = false

    private var cacheKey: String { "\(model.studyMode.rawValue):\(word.id):\(word.meaningZh)" }

    var body: some View {
        if CloudAssistant.shared.offered || explanation != nil {
            Section {
                if let explanation {
                    content(explanation)
                } else if loading {
                    AIThinkingRow(text: L.t("AI 正在整理這個字…", "AI is explaining this word…"))
                        .accessibilityIdentifier("ai-explain-loading")
                } else {
                    Button(action: start) {
                        Label(L.t("AI 解說：用法、搭配與例句", "AI explains: usage, collocations and examples"), systemImage: "sparkles")
                    }
                    .accessibilityIdentifier("ai-explain")
                    if let failure { AIFailureNote(failure: failure) }
                }
                if explanation != nil {
                    if loading {
                        AIThinkingRow(text: L.t("AI 正在換個方式解說…", "AI is explaining it another way…"), compact: true)
                    } else {
                        // Spends one more request; the current explanation stays until the new one arrives.
                        Button(action: start) {
                            Label(L.t("換一個解說", "Explain it differently"), systemImage: "arrow.clockwise")
                                .font(.footnote)
                        }
                        .accessibilityIdentifier("ai-explain-again")
                    }
                    if let failure { AIFailureNote(failure: failure) }
                }
                if explanation != nil || failure == .quota { PlusAIUpsell() }
            } header: {
                Text(L.t("AI 解說", "AI explanation"))
            } footer: {
                if explanation != nil { Text(L.t("由 Claude 線上 AI 產生，可能有誤。", "Generated by Claude, Anthropic's online AI, and may contain mistakes.")) }
            }
            .onAppear { explanation = CloudAnswerCache.explanations[cacheKey] }
            .cloudConsentAlert(isPresented: $askCloud) { if IntelligenceSettings.shared.cloudConsent == true { start() } }
        }
    }

    // Each part of the answer settles in a beat after the one above it.
    @ViewBuilder
    private func content(_ explanation: CloudAI.Explanation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(explanation.summary).font(.body.weight(.semibold))
            if !explanation.usage.isEmpty { Text(explanation.usage) }
        }
        .padding(.vertical, 4)
        .entrance(0, distance: 8)
        .accessibilityIdentifier("ai-explain-summary")
        if !explanation.collocations.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(L.t("常見搭配", "Common combinations")).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.accent)
                Text(explanation.collocations.joined(separator: " · "))
            }
            .padding(.vertical, 2)
            .entrance(1, distance: 8)
        }
        ForEach(Array(explanation.examples.enumerated()), id: \.offset) { offset, example in
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(example.sentence)
                    if !example.translation.isEmpty {
                        Text(example.translation).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                SpeakButton(text: example.sentence, language: model.studyMode == .english ? "en-US" : "zh-TW")
            }
            .padding(.vertical, 2)
            .entrance(2 + offset, distance: 8)
        }
        if !explanation.pitfall.isEmpty {
            Label { Text(explanation.pitfall) } icon: { Image(systemName: "exclamationmark.triangle").foregroundStyle(Palette.review) }
                .entrance(5, distance: 8)
        }
        if !explanation.memoryTip.isEmpty {
            Label { Text(explanation.memoryTip) } icon: { Image(systemName: "lightbulb").foregroundStyle(Palette.known) }
                .entrance(6, distance: 8)
        }
    }

    private func start() {
        guard !loading else { return }
        if CloudAssistant.shared.needsConsent { askCloud = true; return }
        let key = cacheKey
        // The example already on the page, so the AI writes new ones.
        let example = model.studyMode == .english ? word.example : word.exampleZh
        let input: [String: JSONValue] = [
            "word": .string(String(word.word.prefix(80))),
            "partOfSpeech": .string(String(word.partOfSpeech.prefix(40))),
            "meaning": .string(String(ChineseDisplay.conciseMeaning(word.meaningZh).prefix(240))),
            "example": .string(String(example.prefix(240))),
            "mode": .string(model.studyMode.rawValue),
        ]
        loading = true
        failure = nil
        Task {
            defer { loading = false }
            do {
                let value = try await CloudAssistant.shared.run(.explain, input, as: CloudAI.Explanation.self).cleaned()
                CloudAnswerCache.explanations[key] = value
                if key == cacheKey { withAnimation(Motion.reveal) { explanation = value } }
            } catch is CancellationError {
            } catch {
                failure = (error as? CloudAI.Failure) ?? .unavailable
            }
        }
    }
}

/// After a wrong quiz answer: why the chosen option does not fit.
struct QuizWhyView: View {
    @Environment(AppModel.self) private var model
    let word: WordEntry
    let question: String
    let correctAnswer: String
    let chosenAnswer: String
    @State private var reply: CloudAI.QuizExplanation?
    @State private var loading = false
    @State private var failure: CloudAI.Failure?
    @State private var askCloud = false

    private var cacheKey: String { "\(model.studyMode.rawValue):\(word.id):\(chosenAnswer)" }

    var body: some View {
        if CloudAssistant.shared.offered || reply != nil {
            VStack(alignment: .leading, spacing: 8) {
                if let reply {
                    Label(L.t("為什麼錯", "Why it's wrong"), systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.accent)
                        .entrance(0, distance: 8)
                    Text(reply.explanation)
                        .entrance(1, distance: 8)
                        .accessibilityIdentifier("quiz-why-text")
                    if !reply.memoryTip.isEmpty {
                        Label { Text(reply.memoryTip) } icon: { Image(systemName: "lightbulb").foregroundStyle(Palette.known) }
                            .font(.subheadline)
                            .entrance(2, distance: 8)
                    }
                    PlusAIUpsell()
                } else if loading {
                    AIThinkingRow(text: L.t("AI 解釋中…", "AI is explaining…"))
                } else {
                    Button(action: start) {
                        Label(L.t("AI 告訴我為什麼錯", "Ask AI why this is wrong"), systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                    }
                    .accessibilityIdentifier("quiz-why")
                    if let failure { AIFailureNote(failure: failure) }
                    if failure == .quota { PlusAIUpsell() }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onAppear { reply = CloudAnswerCache.quiz[cacheKey] }
            .cloudConsentAlert(isPresented: $askCloud) { if IntelligenceSettings.shared.cloudConsent == true { start() } }
        }
    }

    private func start() {
        guard !loading else { return }
        if CloudAssistant.shared.needsConsent { askCloud = true; return }
        let key = cacheKey
        let input: [String: JSONValue] = [
            "question": .string(String(question.prefix(120))),
            "correctAnswer": .string(String(correctAnswer.prefix(240))),
            "chosenAnswer": .string(String(chosenAnswer.prefix(240))),
            "word": .string(String(word.word.prefix(80))),
            "mode": .string(model.studyMode.rawValue),
        ]
        loading = true
        failure = nil
        Task {
            defer { loading = false }
            do {
                let value = try await CloudAssistant.shared.run(.quizWhy, input, as: CloudAI.QuizExplanation.self).cleaned()
                CloudAnswerCache.quiz[key] = value
                if key == cacheKey { withAnimation(Motion.reveal) { reply = value } }
            } catch is CancellationError {
            } catch {
                failure = (error as? CloudAI.Failure) ?? .unavailable
            }
        }
    }
}

/// The AI's read of the learner's recent numbers, on the Me tab. One analysis
/// a day is kept on this iPhone, so opening the tab again costs nothing.
struct AIInsightsSection: View {
    @Environment(AppModel.self) private var model
    @State private var insights: CloudAI.Insights?
    @State private var loading = false
    @State private var failure: CloudAI.Failure?
    @State private var askCloud = false

    private struct Saved: Codable {
        var day: String
        var mode: String
        var insights: CloudAI.Insights
    }
    private static let storageKey = "word7000.aiInsights"

    var body: some View {
        if CloudAssistant.shared.offered || insights != nil {
            Section {
                if let insights {
                    content(insights)
                } else if loading {
                    AIThinkingRow(text: L.t("AI 正在讀你的學習紀錄…", "AI is reading your progress…"))
                        .accessibilityIdentifier("ai-insights-loading")
                } else {
                    Button(action: start) {
                        ActionRow(icon: "sparkles", tint: Palette.chinese, title: L.t("分析我的學習", "Analyse my learning"),
                                  value: L.t("每天一次", "Once a day"))
                    }
                    .tint(.primary)
                    .accessibilityIdentifier("ai-insights-run")
                    if let failure { AIFailureNote(failure: failure) }
                }
            } header: {
                Text(L.t("AI 學習分析", "AI learning insights"))
            } footer: {
                if insights != nil {
                    Text(L.t("根據最近 14 天的紀錄，由 Claude 線上 AI 產生，可能有誤。明天會再更新。",
                             "Based on the last 14 days, by Anthropic's Claude, and may contain mistakes. Refreshes tomorrow."))
                } else {
                    Text(L.t("AI 會讀你的練習次數、測驗正確率和最常忘記的字，告訴你接下來怎麼練。",
                             "AI reads your practice, quiz accuracy and most-forgotten words, and suggests what to do next."))
                }
            }
            .onAppear(perform: restore)
            .onChange(of: model.studyMode) { _, _ in insights = nil; restore() }
            .cloudConsentAlert(isPresented: $askCloud) { if IntelligenceSettings.shared.cloudConsent == true { start() } }
        }
    }

    @ViewBuilder
    private func content(_ insights: CloudAI.Insights) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(insights.headline, systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(Palette.chinese)
                .accessibilityIdentifier("ai-insights-headline")
            Text(insights.summary)
        }
        .padding(.vertical, 4)
        .entrance(0, distance: 8)
        if !insights.strengths.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(L.t("做得好的地方", "Going well")).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.known)
                ForEach(insights.strengths, id: \.self) { line in
                    Label { Text(line) } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.known) }
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 2)
            .entrance(1, distance: 8)
        }
        if !insights.focusWords.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(L.t("要加強的字", "Words to focus on")).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.review)
                ForEach(insights.focusWords, id: \.word) { focus in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(focus.word).font(.body.weight(.semibold))
                        if !focus.tip.isEmpty { Text(focus.tip).font(.subheadline).foregroundStyle(.secondary) }
                    }
                }
            }
            .padding(.vertical, 2)
            .entrance(2, distance: 8)
        }
        let focusIds = model.wordIds(forPrompts: insights.focusWords.map(\.word))
        if !focusIds.isEmpty {
            Button {
                model.startStudySession(onlyIds: focusIds)
                PracticeLaunch.shared.requested = .study
            } label: {
                ActionRow(icon: "play.circle.fill", tint: Palette.review,
                          title: L.t("現在練習這 \(focusIds.count) 個字", "Practise these \(focusIds.count) words now"))
            }
            .tint(.primary)
            .accessibilityIdentifier("ai-insights-practice")
        }
        if !insights.plan.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(L.t("接下來幾天", "Next few days")).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.accent)
                ForEach(Array(insights.plan.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Palette.accent, in: Circle())
                            .popIn(delay: 0.3 + Double(index) * 0.1)
                        Text(step).font(.subheadline)
                    }
                }
            }
            .padding(.vertical, 2)
            .entrance(3, distance: 8)
        }
        PlusAIUpsell()
    }

    private func restore() {
        guard insights == nil,
              let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let saved = try? JSONDecoder().decode(Saved.self, from: data),
              saved.day == DayMath.today(), saved.mode == model.studyMode.rawValue else { return }
        insights = saved.insights
    }

    private func start() {
        guard !loading else { return }
        if CloudAssistant.shared.needsConsent { askCloud = true; return }
        let mode = model.studyMode.rawValue
        let input = model.insightsInput()
        loading = true
        failure = nil
        Task {
            defer { loading = false }
            do {
                let value = try await CloudAssistant.shared.run(.insights, input, as: CloudAI.Insights.self).cleaned()
                if let data = try? JSONEncoder().encode(Saved(day: DayMath.today(), mode: mode, insights: value)) {
                    UserDefaults.standard.set(data, forKey: Self.storageKey)
                }
                if mode == model.studyMode.rawValue {
                    withAnimation(Motion.reveal) { insights = value }
                }
            } catch is CancellationError {
            } catch {
                failure = (error as? CloudAI.Failure) ?? .unavailable
            }
        }
    }
}

/// Under a free learner's AI answer: what Plus would have answered with.
/// Hidden for Plus and the trial, and when online AI is off.
struct PlusAIUpsell: View {
    @State private var paywall: PaywallReason?

    var body: some View {
        let assistant = CloudAssistant.shared
        if assistant.showsUpgrade {
            Button { paywall = .locked(.smartAI) } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "sparkles").foregroundStyle(Palette.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(assistant.lastFailure == .quota
                             ? L.t("Plus 每天可問 \(PlusAI.plusDaily) 次", "Plus gets \(PlusAI.plusDaily) AI answers a day")
                             : L.t("想要更聰明的回答？", "Want sharper answers?"))
                            .font(.footnote.weight(.semibold))
                        Text(L.t("免費版是快速回答。Plus 會讓 AI 先深入思考，再回答口說、單字解說和學習分析，每天 \(PlusAI.plusDaily) 次。",
                                 "Free gives quick answers. With Plus the AI thinks deeper before coaching, explaining words and analysing your progress, \(PlusAI.plusDaily) times a day."))
                            .font(.caption).foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                        if let remaining = assistant.remainingText {
                            Text(remaining).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("ai-plus-upsell")
            .sheet(item: $paywall) { reason in PaywallView(reason: reason) }
        }
    }
}

/// "AI is thinking": twinkling sparkles, the status, and three dots that keep time.
private struct AIThinkingRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var text: String
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 8 : 10) {
            Image(systemName: "sparkles")
                .font(compact ? .footnote : .body)
                .foregroundStyle(PlusStyle.gradient)
                .symbolEffect(.variableColor.iterative.reversing, options: .repeating, isActive: !reduceMotion)
            Text(text)
                .font(compact ? .footnote : .body)
                .foregroundStyle(.secondary)
            ThinkingDots()
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ThinkingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    let wave = max(0, sin(t * 5 - Double(index) * 0.8))
                    Circle()
                        .fill(Palette.accent)
                        .frame(width: 4, height: 4)
                        .opacity(reduceMotion ? 0.6 : 0.3 + 0.7 * wave)
                        .offset(y: reduceMotion ? 0 : -2.5 * wave)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Why the AI could not answer, with its warning icon popping in.
private struct AIFailureNote: View {
    var failure: CloudAI.Failure

    var body: some View {
        Label {
            Text(failure.message)
        } icon: {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Palette.review)
                .popIn(delay: 0.05)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

extension CloudAI.Failure {
    var message: String {
        switch self {
        case .quota: L.t("今天的線上 AI 次數已用完，明天會再恢復。", "Today's online AI allowance is used up. It resets tomorrow.")
        case .busy: L.t("線上 AI 使用人數較多，請稍後再試。", "Online AI is busy right now. Try again shortly.")
        case .invalidInput: L.t("這個內容無法交給 AI 處理。", "This can't be sent to the AI.")
        case .unavailable, .signInRequired: L.t("線上 AI 暫時無法使用，請確認網路後再試。", "Online AI is unavailable. Check your connection and try again.")
        }
    }
}
