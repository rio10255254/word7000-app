import SwiftUI
import Word7000Core

/// Today's AI learning insights, kept for the day so the Me page and the
/// companion share one request.
enum InsightsStore {
    private struct Saved: Codable {
        var day: String
        var mode: String
        var insights: CloudAI.Insights
    }
    private static let key = "word7000.aiInsights"

    static func today(mode: StudyMode) -> CloudAI.Insights? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode(Saved.self, from: data),
              saved.day == DayMath.today(), saved.mode == mode.rawValue else { return nil }
        return saved.insights
    }

    static func save(_ insights: CloudAI.Insights, mode: String) {
        guard let data = try? JSONEncoder().encode(Saved(day: DayMath.today(), mode: mode, insights: insights)) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

/// One turn of a chat with the cat, kept for the day.
struct ChatTurn: Codable, Equatable, Identifiable {
    enum Role: String, Codable { case learner, cat }
    var id = UUID()
    var role: Role
    var text: String
    /// Words the cat suggested practising (ids the app sent it).
    var practiceIds: [String] = []
    /// What it noted down from this turn, to show.
    var remembered: [String] = []
}

/// Today's chat with the cat, per study mode, so closing the sheet keeps it.
enum ChatStore {
    private struct Saved: Codable {
        var day: String
        var mode: String
        var turns: [ChatTurn]
    }
    private static let key = "word7000.catChat"
    static let maxTurns = 40

    static func today(mode: StudyMode) -> [ChatTurn] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode(Saved.self, from: data),
              saved.day == DayMath.today(), saved.mode == mode.rawValue else { return [] }
        return saved.turns
    }

    static func save(_ turns: [ChatTurn], mode: StudyMode) {
        let saved = Saved(day: DayMath.today(), mode: mode.rawValue, turns: Array(turns.suffix(maxTurns)))
        if let data = try? JSONEncoder().encode(saved) { UserDefaults.standard.set(data, forKey: key) }
    }
}

/// The companion telling you, in its own words, how your learning is going:
/// the day's AI insights as a short chat. It thinks for a moment (or reads
/// what it worked out earlier today), then its messages type in one by one:
/// the headline, the summary, what is going well, the words to work on with a
/// tip for each, and the next few days. The words can be practised at once.
struct MascotChatSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Called with the focus words' ids when the learner wants to practise them.
    var practise: ([String]) -> Void

    @State private var insights: CloudAI.Insights?
    @State private var loading = false
    @State private var failure: CloudAI.Failure?
    @State private var askCloud = false
    /// How many of the messages have typed in so far.
    @State private var shown = 0
    @State private var revealTask: Task<Void, Never>?
    /// The conversation after the analysis.
    @State private var turns: [ChatTurn] = []
    @State private var draft = ""
    @State private var replying = false
    @State private var chatFailure: CloudAI.Failure?
    /// A message waiting for the learner to agree to the online AI.
    @State private var pendingMessage: String?
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .bottom, spacing: 10) {
                        Mascot(mood: mood, size: 60, hop: shown)
                        ChatLine(text: insights == nil
                                 ? L.t("讓我看看你最近有多混……", "Let's see how much you've been slacking…")
                                 : L.t("看完了。嗯……我們需要談談。", "Done. Hmm… we need to talk."))
                    }
                    .padding(.bottom, 4)

                    if let insights {
                        let lines = messages(insights)
                        ForEach(Array(lines.prefix(shown).enumerated()), id: \.offset) { _, line in
                            line.view
                                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        }
                        if shown < lines.count { TypingDots() }
                        if shown >= lines.count {
                            practiceButton(insights)
                            Text(L.t("由 Claude 線上 AI 根據最近 14 天的紀錄產生，可能有誤。明天會再更新。",
                                     "Written by Anthropic's Claude from the last 14 days, and may contain mistakes. Refreshes tomorrow."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 6)
                            PlusAIUpsell()
                        }
                    } else if loading {
                        TypingDots()
                    } else if let failure {
                        AIFailureNote(failure: failure)
                        Button(L.t("再試一次", "Try again"), action: start)
                            .secondaryAction()
                    }
                    if chatReady { conversation }
                }
                .padding(Metrics.gutter)
                .animation(reduceMotion ? nil : Motion.reveal, value: shown)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                if chatReady && CloudAssistant.shared.offered { inputBar }
            }
            .background { AmbientBackground() }
            .navigationTitle(L.t("小笨貓說", "Silly Cat says"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L.done) { dismiss() } }
            }
        }
        .compactSheet()
        .task {
            turns = ChatStore.today(mode: model.studyMode)
            if let saved = InsightsStore.today(mode: model.studyMode) {
                present(saved)
            } else {
                start()
            }
        }
        .onDisappear { revealTask?.cancel() }
        .cloudConsentAlert(isPresented: $askCloud) {
            if IntelligenceSettings.shared.cloudConsent == true {
                if let pendingMessage { self.pendingMessage = nil; send(pendingMessage) } else { start() }
            } else {
                pendingMessage = nil
                dismiss()
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: shown) { _, new in
            new > 0 && (model.settings.hapticsEnabled ?? true)
        }
    }

    private var mood: Mascot.Mood {
        if loading || replying { return .thinking }
        if failure != nil { return .encourage }
        return insights == nil ? .idle : .happy
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
                InsightsStore.save(value, mode: mode)
                present(value)
            } catch is CancellationError {
            } catch {
                failure = (error as? CloudAI.Failure) ?? .unavailable
            }
        }
    }

    /// Shows the insights, typing the messages in one after another.
    private func present(_ value: CloudAI.Insights) {
        insights = value
        let total = messages(value).count
        guard !reduceMotion else { shown = total; return }
        revealTask?.cancel()
        revealTask = Task { @MainActor in
            for step in 1...max(1, total) {
                try? await Task.sleep(for: .milliseconds(step == 1 ? 350 : 650))
                guard !Task.isCancelled else { return }
                shown = step
            }
        }
    }

    private struct Message {
        var view: AnyView
    }

    private func messages(_ insights: CloudAI.Insights) -> [Message] {
        var list: [Message] = []
        list.append(Message(view: AnyView(ChatLine(text: insights.headline, emphasis: true))))
        if !insights.summary.isEmpty { list.append(Message(view: AnyView(ChatLine(text: insights.summary)))) }
        if !insights.strengths.isEmpty {
            list.append(Message(view: AnyView(ChatCard(title: L.t("做得好的地方", "Going well"), tint: Palette.known, symbol: "checkmark.circle.fill") {
                ForEach(insights.strengths, id: \.self) { Text($0).font(.subheadline) }
            })))
        }
        if !insights.focusWords.isEmpty {
            list.append(Message(view: AnyView(ChatCard(title: L.t("這幾個字要加油", "Words to work on"), tint: Palette.review, symbol: "target") {
                ForEach(insights.focusWords, id: \.word) { focus in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(focus.word).font(.display(.headline, weight: .bold))
                        if !focus.tip.isEmpty { Text(focus.tip).font(.subheadline).foregroundStyle(.secondary) }
                    }
                }
            })))
        }
        if !insights.plan.isEmpty {
            list.append(Message(view: AnyView(ChatCard(title: L.t("接下來幾天", "Next few days"), tint: Palette.accent, symbol: "calendar") {
                ForEach(Array(insights.plan.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Palette.accent, in: Circle())
                        Text(step).font(.subheadline)
                    }
                }
            })))
        }
        return list
    }

    // MARK: Chat

    /// The chat opens once the analysis has typed in, failed, or is not coming.
    private var chatReady: Bool {
        if let insights { return shown >= messages(insights).count }
        return !loading
    }

    private static var starters: [String] {
        [L.t("今天練什麼？", "What should I practise today?"),
         L.t("考我幾個字", "Test me on a few words"),
         L.t("幫我排這週", "Plan my week"),
         L.t("罵我一下", "Give me a scolding"),
         L.t("我好累不想讀", "I'm tired, I don't want to study")]
    }

    @ViewBuilder
    private var conversation: some View {
        ForEach(turns) { turn in
            switch turn.role {
            case .learner:
                LearnerSays(text: turn.text)
            case .cat:
                VStack(alignment: .leading, spacing: 6) {
                    ChatLine(text: turn.text)
                    if !turn.remembered.isEmpty {
                        Label(L.t("記住了：\(turn.remembered.joined(separator: "、"))", "Noted: \(turn.remembered.joined(separator: ", "))"),
                              systemImage: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !turn.practiceIds.isEmpty {
                        Button { practise(turn.practiceIds) } label: {
                            Label(L.t("開始練這 \(turn.practiceIds.count) 個字", "Practise these \(turn.practiceIds.count) words"), systemImage: "play.fill")
                                .font(.subheadline.weight(.semibold))
                        }
                        .secondaryAction()
                        .accessibilityIdentifier("mascot-chat-turn-practice")
                    }
                }
            }
        }
        if replying { TypingDots() }
        if let chatFailure { AIFailureNote(failure: chatFailure) }
        if chatFailure == .quota { PlusAIUpsell() }
        if !CloudAssistant.shared.offered, turns.isEmpty {
            ChatLine(text: L.t("我現在連不上線上 AI，聊天要等一下。你可以先去背字，我等你。一直等。",
                               "I can't reach the online AI right now, so no chatting. Go study; I'll wait. Forever."))
        }
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            if turns.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(Self.starters.enumerated()), id: \.offset) { index, starter in
                            Button { send(starter) } label: {
                                Text(starter).font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Palette.accent.opacity(0.12), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Palette.accent)
                            .disabled(replying)
                            .accessibilityIdentifier("mascot-chat-chip-\(index)")
                        }
                    }
                    .padding(.horizontal, Metrics.gutter)
                }
            }
            HStack(spacing: 8) {
                TextField(L.t("跟小笨貓說…", "Say something to Silly Cat…"), text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit { send(draft) }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .accessibilityIdentifier("mascot-chat-input")
                Button { send(draft) } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || replying)
                .accessibilityLabel(L.t("送出", "Send"))
                .accessibilityIdentifier("mascot-chat-send")
            }
            .padding(.horizontal, Metrics.gutter)
        }
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func send(_ raw: String) {
        let text = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(400))
        guard !text.isEmpty, !replying else { return }
        if CloudAssistant.shared.needsConsent { pendingMessage = text; askCloud = true; return }
        draft = ""
        chatFailure = nil
        let mode = model.studyMode
        withAnimation(reduceMotion ? nil : Motion.reveal) { turns.append(ChatTurn(role: .learner, text: text)) }
        ChatStore.save(turns, mode: mode)
        // The cat sees the last few turns, with its analysis as context when there is one.
        var history: [JSONValue] = []
        if let insights {
            history.append(.object(["role": .string("cat"), "text": .string(String("\(insights.headline) \(insights.summary)".prefix(400)))]))
        }
        history += turns.suffix(11).map { turn in
            .object(["role": .string(turn.role.rawValue), "text": .string(String(turn.text.prefix(400)))])
        }
        let words = model.catWordsInput(limit: 20)
        let allowed: Set<String> = {
            guard case let .array(items) = words else { return [] }
            return Set(items.compactMap { item -> String? in
                guard case let .object(fields) = item, case let .string(id)? = fields["id"] else { return nil }
                return id
            })
        }()
        let input: [String: JSONValue] = [
            "mode": .string(mode.rawValue),
            "profile": model.catProfile(),
            "words": words,
            "messages": .array(Array(history.suffix(12))),
        ]
        replying = true
        Task {
            defer { replying = false }
            do {
                let reply = try await CloudAssistant.shared.run(.chat, input, as: CloudAI.ChatReply.self).cleaned(allowedIds: allowed)
                let remembered = CatMemory.shared.apply(reply.memory)
                withAnimation(reduceMotion ? nil : Motion.reveal) {
                    turns.append(ChatTurn(role: .cat, text: reply.reply, practiceIds: reply.practiceWordIds, remembered: remembered))
                }
                ChatStore.save(turns, mode: mode)
            } catch is CancellationError {
            } catch {
                chatFailure = (error as? CloudAI.Failure) ?? .unavailable
            }
        }
    }

    @ViewBuilder
    private func practiceButton(_ insights: CloudAI.Insights) -> some View {
        let ids = model.wordIds(forPrompts: insights.focusWords.map(\.word))
        if !ids.isEmpty {
            Button { practise(ids) } label: {
                Label(L.t("現在練習這 \(ids.count) 個字", "Practise these \(ids.count) words now"), systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .prominentAction()
            .padding(.top, 6)
            .accessibilityIdentifier("mascot-chat-practice")
        }
    }
}

/// One message from the companion: a cream bubble with a tail on its left.
private struct ChatLine: View {
    var text: String
    var emphasis = false

    var body: some View {
        Text(text)
            .font(emphasis ? .display(.headline, weight: .bold) : .body)
            .foregroundStyle(emphasis ? Palette.accent : Color.primary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 6, bottomTrailingRadius: 18, topTrailingRadius: 18,
                                       style: .continuous)
                    .fill(MascotBubble.cream)
                    .shadow(color: PremiumSurface.umber.opacity(0.12), radius: 6, y: 3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A longer message with a small heading: what's going well, words, the plan.
private struct ChatCard<Content: View>: View {
    var title: String
    var tint: Color
    var symbol: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 6, bottomTrailingRadius: 18, topTrailingRadius: 18,
                                   style: .continuous)
                .fill(MascotBubble.cream)
                .shadow(color: PremiumSurface.umber.opacity(0.12), radius: 6, y: 3)
        }
    }
}

/// Three dots bouncing in turn: the companion is typing.
private struct TypingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary.opacity(0.6))
                        .frame(width: 7, height: 7)
                        .offset(y: reduceMotion ? 0 : -CGFloat(abs(sin(t * 6 - Double(index) * 0.7))) * 4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(MascotBubble.cream, in: Capsule())
        .accessibilityLabel(L.t("小笨貓正在想", "Silly Cat is thinking"))
    }
}
